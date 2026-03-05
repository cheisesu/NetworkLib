import XCTest
import Network
@testable import NetworkLib

class RawSocketTests_UDP_Receive: XCTestCase {
    private let transport: NetTransport = .udp

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: SUCCESS DATA BY PORTIONS

    func test_Receive_SmallMaxSize_SmallPortion_CallbackReturnsFull() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("HELLO".utf8)
        let maxDataBlock: Int = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNext { data, error in
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                XCTAssertLessThanOrEqual(data?.count ?? .max, maxDataBlock)
                XCTAssertEqual(data, dataToSend)
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_SmallMaxSize_BigPortion_CallbackReturnsOnlyMaxSize() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxDataBlock: Int = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNext { data, error in
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                XCTAssertLessThanOrEqual(data?.count ?? .max, maxDataBlock)
                XCTAssertEqual(data, dataToSend[dataToSend.startIndex..<(dataToSend.startIndex + maxDataBlock)])
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_BigMaxSize_BigPortion_CallbackReturnsFull() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 2048)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNext { data, error in
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                XCTAssertEqual(data, dataToSend)
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    // MARK: TIMEOUTS

    func test_Receive_TimeOutSet_ServerNotEchos_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0.5
        let dataToSend = Data("Hello".utf8)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNext { data, error in
                XCTAssertNil(data)
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ETIMEDOUT)
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    // MARK: ERRORS IN DIFFERENT STATE

    func test_Receive_WhenNotConnected_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.receiveNext { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ENOTCONN)
            receiveExpect.fulfill()
        }
        await fulfillment(of: [receiveExpect], timeout: 1, enforceOrder: true)
    }

    func test_Receive_WhenCancelling_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel()
            socket.receiveNext { data, error in
                XCTAssertNil(data)
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_WhenCancelledInitially_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.cancel()
        socket.receiveNext { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ECANCELED)
            receiveExpect.fulfill()
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_WhenCancelledWhenConnected_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel {
                socket.receiveNext { data, error in
                    XCTAssertNil(data)
                    XCTAssertNotNil(error)
                    guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                    guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                    XCTAssertEqual(code, .ECANCELED)
                    receiveExpect.fulfill()
                }
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_WhenCancelledWhenWaitingReceive_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let maxDataBlock: Int = .max
        let dataToSend = Data(repeating: 0xde, count: 2048)
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.send(dataToSend, nil)
            socket.receiveNext { data, error in
                XCTAssertNil(data)
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                receiveExpect.fulfill()
            }
            socket.cancel()
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    // MARK: SUCCESS IN DIFFERENT STATE

    func test_Receive_WhenConnecting_CallbackSuccess() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, _ in
            socket.send(dataToSend, nil)
        }

        socket.receiveNext { data, error in
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            XCTAssertEqual(data, dataToSend)
            receiveExpect.fulfill()
        }
        await fulfillment(of: [receiveExpect], timeout: 1, enforceOrder: true)
    }

    func test_Receive_Connected_CallbackSuccess() async throws {
        throw XCTSkip("Redudant")
    }

    // MARK: ERROR BY SERVER STATE

    func test_Receive_AfterSendData_Echo_ServerForceClosesConnection_CallbackNotCalled() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        receiveExpect.isInverted = true
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.receiveNext { _, _ in
                receiveExpect.fulfill()
            }
            socket.send(dataToSend) { _ in
                server.forceStop()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    // MARK: SUCCESS BY SERVER STATE

    func test_Receive_WithoutData_ServerClosesConnection_CallbackCalledFinal() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.receiveNext { data, error in
                XCTAssertNil(data)
                XCTAssertNil(error)
                receiveExpect.fulfill()
            }
            socket.send(dataToSend) { _ in
                server.stop()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_AfterSendData_NoEcho_ServerClosesConnection_CallbackCalledFinal() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.send(dataToSend, nil)
            socket.receiveNext { data, error in
                XCTAssertNil(data)
                XCTAssertNil(error)
                receiveExpect.fulfill()
            }
            socket.send(dataToSend) { _ in
                server.stop()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_AfterSendData_Echo_ServerClosesConnection_CallbackCalledFinal() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.receiveNext { data, error in
                XCTAssertNil(data)
                XCTAssertNil(error)
                receiveExpect.fulfill()
            }
            socket.send(dataToSend) { _ in
                server.stop()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    // MARK: DEINITS

    func test_Receive_DeinitDuringScheduling_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let box = _SocketBox()
        box.set(try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                              transport: transport, timeout: timeout, sni: "localhost"))
        defer { box.get()?.cancel() }

        let connectExpect = expectation(description: "For callback on receive")
        let receiveExpect = expectation(description: "For callback on receive")
        box.get()?.connect { _, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3, enforceOrder: true)
        box.get()?.receiveNext { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EPERM)
            receiveExpect.fulfill()
        }
        box.set(nil)
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_DeinitWhenWaitingReceive_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let box = _SocketBox()
        box.set(try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxDataBlock,
                              transport: transport, timeout: timeout, sni: "localhost"))
        defer { box.get()?.cancel() }

        let connectExpect = expectation(description: "For callback on receive")
        let receiveExpect = expectation(description: "For callback on receive")
        box.get()?.connect { _, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3, enforceOrder: true)
        box.get()?.receiveNext { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EPERM)
            receiveExpect.fulfill()
        }
        box.get()?.send(dataToSend) { _ in
            box.set(nil)
        }

        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }
}
