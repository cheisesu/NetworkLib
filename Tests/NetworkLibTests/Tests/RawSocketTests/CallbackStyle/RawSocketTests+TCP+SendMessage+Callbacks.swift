import XCTest
import Network
@testable import NetworkLib

class RawSocketTests_TCP_SendMessage_Callbacks: XCTestCase {
    private let transport: RawSocketTransport = .tcp

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: SUCCESS IN DIFFERENT STATES

    func test_SendMessage_WhenConnecting_CallbackSuccess() async throws {
        struct _SomeSendMessage: RawSocketSendMessage {
            let context: NWConnection.ContentContext = .defaultMessage
            let content: Data? = Data("Hello".utf8)
        }
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
        }
        socket.connect { _, _ in
            socket.sendMessage(_SomeSendMessage()) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    func test_SendMessage_WhenConnected_CallbackSuccess() async throws {
        struct _SomeSendMessage: RawSocketSendMessage {
            let context: NWConnection.ContentContext = .defaultMessage
            let content: Data? = Data("Hello".utf8)
        }
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.sendMessage(_SomeSendMessage()) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    // MARK: ERRORS IN DIFFERENT STATES

    func test_SendMessage_WhenNotConnected_CallbackReturnsError() async throws {
        struct _SomeSendMessage: RawSocketSendMessage {
            let context: NWConnection.ContentContext = .defaultMessage
            let content: Data? = Data("Hello".utf8)
        }
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let sendExpect = expectation(description: "Send callback called")
        socket.sendMessage(_SomeSendMessage()) { error in
            XCTAssertNotNil(error)
            guard let error else { return XCTFail("Expecting non-nil error") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ENOTCONN)
            sendExpect.fulfill()
        }
        await fulfillment(of: [sendExpect], timeout: 1)
    }

    func test_SendMessage_WhenCancelling_CallbackReturnsError() async throws {
        struct _SomeSendMessage: RawSocketSendMessage {
            let context: NWConnection.ContentContext = .defaultMessage
            let content: Data? = Data("Hello".utf8)
        }
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel(nil)
            socket.sendMessage(_SomeSendMessage()) { error in
                XCTAssertNotNil(error)
                guard let error else { return XCTFail("Expecting non-nil error") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    func test_SendMessage_WhenCancelledAfterConnect_CallbackReturnsError() async throws {
        struct _SomeSendMessage: RawSocketSendMessage {
            let context: NWConnection.ContentContext = .defaultMessage
            let content: Data? = Data("Hello".utf8)
        }
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel {
                socket.sendMessage(_SomeSendMessage()) { error in
                    XCTAssertNotNil(error)
                    guard let error else { return XCTFail("Expecting non-nil error") }
                    guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                    XCTAssertEqual(code, .ECANCELED)
                    sendExpect.fulfill()
                }
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    func test_SendMessage_WhenCancelledInitially_CallbackReturnsError() async throws {
        struct _SomeSendMessage: RawSocketSendMessage {
            let context: NWConnection.ContentContext = .defaultMessage
            let content: Data? = Data("Hello".utf8)
        }
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let sendExpect = expectation(description: "Send callback called")
        socket.cancel {
            socket.sendMessage(_SomeSendMessage()) { error in
                XCTAssertNotNil(error)
                guard let error else { return XCTFail("Expecting non-nil error") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    // MARK: DEINITS

    func test_SendMessage_Deinited_CallbackReturnsError() async throws {
        struct _SomeSendMessage: RawSocketSendMessage {
            let context: NWConnection.ContentContext = .defaultMessage
            let content: Data? = Data("Hello".utf8)
        }
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        var socket: RawSocket? = try RawSocket(config)
        defer { socket?.cancel(nil) }

        let connectExpect = expectation(description: "Connect callback called")
        socket?.connect { _, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
        let sendExpect = expectation(description: "Send callback called")
        socket?.sendMessage(_SomeSendMessage()) { error in
            XCTAssertNotNil(error)
            guard let error else { return XCTFail("Expecting non-nil error") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ECANCELED)
            sendExpect.fulfill()
        }
        socket = nil
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    // MARK: TIMEOUTS

    func test_SendMessage_TimeOutSet_CallbackReturnsError() async throws {
        struct _SomeSendMessage: RawSocketSendMessage {
            let context: NWConnection.ContentContext = .defaultMessage
            let content: Data? = Data(repeating: 0xde, count: 16 * 1024 * 1024)
        }
        let timeout: TimeInterval = 0.5
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.sendMessage(_SomeSendMessage()) { error in
                XCTAssertNotNil(error)
                guard let error else { return XCTFail("Expecting non-nil error") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ETIMEDOUT)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    // MARK: ERRORS BY SERVER BEHAVIOUR

    func test_SendMessage_WhenServerCancelsConnection_CallbackReturnsError() async throws {
        throw XCTSkip("Not working")
//        struct _SomeSendMessage: RawSocketSendMessage {
//            let context: NWConnection.ContentContext = .defaultMessage
//            let content: Data? = Data(repeating: 0xde, count: 16 * 1024 * 1024)
//        }
//        let timeout: TimeInterval = 0
//        let server = try ServerMock(transport: transport, isSecure: true)
//        defer { server.stop() }
//        let port = try await server.start()
//        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
//                                            maxDataBlock: 256, timeout: timeout)
//        let socket = try RawSocket(config)
//        defer { socket.cancel(nil) }
//
//        let connectExpect = expectation(description: "Callback callback called")
//        socket.connect { _, error in
//            XCTAssertNil(error)
//            connectExpect.fulfill()
//        }
//        await fulfillment(of: [connectExpect], timeout: 3)
//        let sendExpect = expectation(description: "Send callback called")
//        server.forceStop()
//        socket.sendMessage(_SomeSendMessage()) { error in
//            XCTAssertNotNil(error)
//            guard let error else { return XCTFail("Expecting non-nil error") }
//            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
//            XCTAssertTrue([.EPIPE, .ENOTCONN, .ECONNRESET].contains(code), "\(code)")
//            sendExpect.fulfill()
//        }
//        await fulfillment(of: [sendExpect], timeout: 2)
    }

    func test_SendMessage_MultipleAfterServerCancelsConnection_CallbackReturnsError() async throws {
        throw XCTSkip("Fails some times")
    }

    // MARK: PROTOCOL ERRORS

    func test_SendMessage_LargeData_CallbackSuccess() async throws {
        struct _SomeSendMessage: RawSocketSendMessage {
            let context: NWConnection.ContentContext = .defaultMessage
            let content: Data? = Data(repeating: 0xde, count: 4 * 1024 * 1024)
        }
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.sendMessage(_SomeSendMessage()) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }

    // MARK: ENDPOINT ERRORS

    func test_SendMessage_EndpointUnavailable_CallbackReturnsError() async throws {
        throw XCTSkip("Not applicable on TCP")
    }

    func test_SendMessage_ServerInsecureAndSocketSecure_CallbackReturnsError() async throws {
        throw XCTSkip("Not applicable on TCP")
    }

    func test_SendMessage_ServerSecureAndSocketInsecure_CallbackSuccess() async throws {
        struct _SomeSendMessage: RawSocketSendMessage {
            let context: NWConnection.ContentContext = .defaultMessage
            let content: Data? = Data("Hello".utf8)
        }
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: false, sni: nil, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.sendMessage(_SomeSendMessage()) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }
}
