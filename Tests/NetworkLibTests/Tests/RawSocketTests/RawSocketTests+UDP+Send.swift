import XCTest
import Network
@testable import NetworkLib

class RawSocketTests_UDP_Send: XCTestCase {
    private let transport: NetTransport = .udp

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: SUCCESS IN DIFFERENT STATES

    func test_Send_WhenConnecting_CallbackSuccess() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
        }
        socket.connect { _, _ in
            socket.send(dataToSend) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    func test_Send_WhenConnected_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.send(dataToSend) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    // MARK: ERRORS IN DIFFERENT STATES

    func test_Send_WhenNotConnected_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "Send callback called")
        socket.send(dataToSend) { error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ENOTCONN)
            sendExpect.fulfill()
        }
        await fulfillment(of: [sendExpect], timeout: 1)
    }

    func test_Send_WhenCancelling_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel()
            socket.send(dataToSend) { error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    func test_Send_WhenCancelledAfterConnect_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel {
                socket.send(dataToSend) { error in
                    XCTAssertNotNil(error)
                    guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                    guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                    XCTAssertEqual(code, .ECANCELED)
                    sendExpect.fulfill()
                }
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    func test_Send_WhenCancelledInitially_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "Send callback called")
        socket.cancel {
            socket.send(dataToSend) { error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    // MARK: DEINITS

    func test_Send_Deinited_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        var socket: RawSocket? = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                               transport: transport, timeout: timeout, sni: "localhost")
        defer { socket?.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket?.connect { _, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
        let sendExpect = expectation(description: "Send callback called")
        socket?.send(dataToSend) { error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EPERM)
            sendExpect.fulfill()
        }
        socket = nil
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    // MARK: TIMEOUTS

    func test_Send_TimeOutSet_CallbackReturnsError() async throws {
        throw XCTSkip("Not applicable for UDP")
    }

    // MARK: ERRORS BY SERVER BEHAVIOUR

    func test_Send_WhenServerCancelsConnection_CallbackSuccess() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            server.forceStop()
            socket.send(dataToSend) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    // MARK: PROTOCOL ERRORS

    func test_Send_LargeData_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 1024 * 1024)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.send(dataToSend) { error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .EMSGSIZE)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    // MARK: ENDPOINT ERRORS

    func test_Send_EndpointUnavailable_CallbackReturnsError() async throws {
        throw XCTSkip("Possibly not applicable on UDP")
    }

    func test_Send_ServerInsecureAndSocketSecure_CallbackReturnsError() async throws {
        throw XCTSkip("Possibly not applicable on UDP")
    }

    func test_Send_ServerSecureAndSocketInsecure_CallbackSuccess() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: nil)
        defer { socket.cancel() }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.send(dataToSend) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }
}
