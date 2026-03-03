import XCTest
import Network
@testable import NetworkLib

/*
 + receives by block size
 + receive time out
 + cancel during receive
 + when not connected
 + during connecting
 + when cancelled after connect
 + when cancelled initially
 + server cancels connection during receive
 */

class RawSocketTests_Receive: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func test_ReceiveNext_SmallPortion_CallbackSuccess() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let dataToSend = Data("HELLO".utf8)
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
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
    
    func test_ReceiveNext_NoTimeOutAndServerNotEchos_CallbackNotFails() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let dataToSend = Data("HELLO".utf8)
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        receiveExpect.isInverted = true
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNext { data, error in
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_ReceiveNext_LargerThanBlockData_CallbackSuccess() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxBlockSize = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxBlockSize,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNext { data, error in
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                XCTAssertEqual(data?.count, maxBlockSize)
                XCTAssertEqual(data, dataToSend[0..<maxBlockSize])
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_ReceiveNext_ByBlocksData_NeedsSeveralCalls() async throws {
        actor _Box {
            private(set) var data: Data = Data()

            func append(_ data: Data) {
                self.data.append(data)
            }
        }
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxBlockSize = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxBlockSize,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        receiveExpect.expectedFulfillmentCount = 2
        let box = _Box()
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNext { data, error in
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                Task {
                    await box.append(data ?? Data())
                }
                receiveExpect.fulfill()

                socket.receiveNext { data, error in
                    XCTAssertNotNil(data)
                    XCTAssertNil(error)
                    Task {
                        await box.append(data ?? Data())
                    }
                    receiveExpect.fulfill()
                }
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
        let data = await box.data
        XCTAssertEqual(data, dataToSend)
    }

    func test_ReceiveNext_ServerNotEchos_ReceivedTimeOutError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0.5
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxBlockSize = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxBlockSize,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNext { data, error in
                XCTAssertNil(data)
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
                XCTAssertEqual(code, .ETIMEDOUT)
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_ReceiveNext_ServerClosesConnection_ReceivedFinalCallback() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0.5
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxBlockSize = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxBlockSize,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            server.stop()
            socket.receiveNext { data, error in
                XCTAssertNil(data)
                XCTAssertNil(error)
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_ReceiveNext_ServerForceClosesConnection_ReceivedError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxBlockSize = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxBlockSize,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            server.forceStop()
            socket.receiveNext { data, error in
                XCTAssertNil(data)
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
                XCTAssertEqual(code, .ECONNRESET)
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_ReceiveNext_WhenInitiallyCancelled_ReceivedError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0.5
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxBlockSize = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxBlockSize,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.cancel {
            socket.receiveNext { data, error in
                XCTAssertNil(data)
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
                XCTAssertEqual(code, .ECANCELED)
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_ReceiveNext_WhenInitiallyNotConnected_ReceivedError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0.5
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxBlockSize = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxBlockSize,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.receiveNext { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
            XCTAssertEqual(code, .ENOTCONN)
            receiveExpect.fulfill()
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_ReceiveNext_DuringConnecting_CallbackSuccess() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0.5
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxBlockSize = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxBlockSize,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.send(dataToSend, nil)
        }
        socket.receiveNext { data, error in
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            XCTAssertEqual(data, Data(dataToSend[0..<(data?.count ?? 0)]))
            receiveExpect.fulfill()
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_ReceiveNext_DeinitSocket_CallbackFails() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxBlockSize = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        var socket: RawSocket? = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: maxBlockSize,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket?.cancel() }

        let connectExpect = expectation(description: "For callback on connect")
        socket?.connect { [weak socket] _, error in
            XCTAssertNil(error)
            socket?.send(dataToSend, nil)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 2, enforceOrder: true)
        let receiveExpect = expectation(description: "For callback on receive")
        socket?.receiveNext { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
            XCTAssertEqual(code, .EPERM)
            receiveExpect.fulfill()
        }
        socket = nil
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }
}
