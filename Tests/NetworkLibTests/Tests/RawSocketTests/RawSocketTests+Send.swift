import XCTest
import Network
@testable import NetworkLib

// TODO: - send when deallocated

class RawSocketTests_Send: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func test_SendCompletedWithoutError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "For callback on send")
        socket.connect { info, error in
            socket.send(Data("HELLO".utf8)) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }
    
    func test_Send_NoTimeOutAndLargeData_CallbackCalled() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 16 * 1024 * 1024)
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "For callback on send")
        sendExpect.isInverted = true
        socket.connect { info, error in
            socket.send(dataToSend) { error in
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 2, enforceOrder: true)
    }

    func test_Send_WhenCancelledAfterConnect_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "For callback on send")
        socket.connect { info, error in
            socket.cancel {
                socket.send(Data("HELLO".utf8)) { error in
                    XCTAssertNotNil(error)
                    guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
                    guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
                    XCTAssertEqual(code, .ECANCELED)
                    sendExpect.fulfill()
                }
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }

    func test_Send_WhenNotConnected_CalledWithError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "For callback on send called")
        socket.send(Data("HELLO".utf8)) { error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
            XCTAssertEqual(code, .ENOTCONN)
            sendExpect.fulfill()
        }
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }

    func test_Send_WhenCancelledInitially_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 1
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        socket.cancel()

        let sendExpect = expectation(description: "For callback on send called")
        socket.send(Data("HELLO".utf8)) { error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
            XCTAssertEqual(code, .ECANCELED)
            sendExpect.fulfill()
        }
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }

    func test_Send_DuringCanceling_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 1
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "For callback on send called when cancelling")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel()
            socket.send(Data("HELLO".utf8)) { error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
                XCTAssertEqual(code, .ECANCELED)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }

    func test_Send_WhenConnectedAndTimeOutSet_CallbackReturnsTimeOutError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0.5
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let dataToSend = Data(repeating: 0xde, count: 16 * 1024 * 1024)

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "For callback on send called by timeout")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.send(dataToSend) { error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
                XCTAssertEqual(code, .ETIMEDOUT)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }

    func test_SendMultiple_WhenConnectedAndTimeOutSet_CallbacksReturnTimeOutError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0.5
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let dataToSend = Data(repeating: 0xde, count: 4 * 1024 * 1024)

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "For callbacks on send called by timeout")
        sendExpect.expectedFulfillmentCount = 2
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.send(dataToSend) { error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
                XCTAssertEqual(code, .ETIMEDOUT)
                sendExpect.fulfill()
            }
            socket.send(dataToSend) { error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
                XCTAssertEqual(code, .ETIMEDOUT)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }

    func test_Send_AfterConnect_ThenRemoteDisconnected_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 4 * 1024 * 1024)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "For callback on connect called")
        let sendExpect = expectation(description: "For callback on send called")
        socket.connect { _, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 2, enforceOrder: true)
        server.stop() // broken pipe
        socket.send(dataToSend) { error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
            XCTAssertTrue([.EPIPE, .ECONNRESET].contains(code))
            sendExpect.fulfill()
        }
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }

    func test_Send_AfterConnect_ThenRemoteForceDisconnected_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 4 * 1024 * 1024)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "For callback on connect called")
        let sendExpect = expectation(description: "For callback on send called")
        socket.connect { _, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 2, enforceOrder: true)
        server.forceStop() // reset
        socket.send(dataToSend) { error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
            XCTAssertTrue([.EPIPE, .ENOTCONN].contains(code))
            sendExpect.fulfill()
        }
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }

    func test_Send_DurringConnecting_CallbackSuccess() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "For callback on send called")
        socket.connect { _, error in
            XCTAssertNil(error)
        }
        socket.send(Data("HELLO".utf8)) { error in
            XCTAssertNil(error)
            sendExpect.fulfill()
        }
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }

    func test_Send_DeinitSocket_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        var socket: RawSocket? = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                               transport: transport, timeout: timeout, sni: "localhost")
        defer { socket?.cancel() }

        let connectExpect = expectation(description: "For socket connected")
        let sendExpect = expectation(description: "For callback on send called")
        socket?.connect { _, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 1)
        socket?.send(Data("HELLO".utf8)) { error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
            XCTAssertEqual(code, .EPERM)
            sendExpect.fulfill()
        }
        socket = nil
        await fulfillment(of: [sendExpect], timeout: 3, enforceOrder: true)
    }
}
