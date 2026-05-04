import XCTest
import Network
@testable import NetworkLib

class RawSocketTests_TCP_Send_Callbacks: XCTestCase {
    private let transport: RawSocketTransport = .tcp
    
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
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
    
    func test_Send_WhenConnected_CallbackSuccess() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        let sendExpect = expectation(description: "Send callback called")
        socket.send(dataToSend) { error in
            XCTAssertNotNil(error)
            guard let error else { return XCTFail("Expecting non-nil error") }
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel(nil)
            socket.send(dataToSend) { error in
                XCTAssertNotNil(error)
                guard let error else { return XCTFail("Expecting non-nil error") }
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        let sendExpect = expectation(description: "Send callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel {
                socket.send(dataToSend) { error in
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
    
    func test_Send_WhenCancelledInitially_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        let sendExpect = expectation(description: "Send callback called")
        socket.cancel {
            socket.send(dataToSend) { error in
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
    
    func test_Send_Deinited_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
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
        socket?.send(dataToSend) { error in
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
    
    func test_Send_TimeOutSet_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0.5
        let dataToSend = Data(repeating: 0xde, count: 16 * 1024 * 1024)
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
            socket.send(dataToSend) { error in
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
    
    func test_Send_WhenServerCancelsConnection_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 16 * 1024 * 1024)
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        let connectExpect = expectation(description: "Callback callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
        let sendExpect = expectation(description: "Send callback called")
        server.forceStop()
        socket.send(dataToSend) { error in
            XCTAssertNotNil(error)
            guard let error else { return XCTFail("Expecting non-nil error") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
            XCTAssertTrue([.EPIPE, .ENOTCONN].contains(code), "\(code)")
            sendExpect.fulfill()
        }
        await fulfillment(of: [sendExpect], timeout: 2)
    }
    
    func test_Send_MultipleAfterServerCancelsConnection_CallbackReturnsError() async throws {
        throw XCTSkip("Fails some times")
        //        let timeout: TimeInterval = 0
        //        let dataToSend = Data(repeating: 0xde, count: 16 * 1024 * 1024)
        //        let server = try ServerMock(transport: transport, isSecure: true)
        //        defer { server.stop() }
        //        let port = try await server.start()
        //
        //        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
        //                                   transport: transport, timeout: timeout, sni: "localhost")
        //        defer { socket.cancel(nil) }
        //
        //        let connectExpect = expectation(description: "Callback callback called")
        //        socket.connect { _, error in
        //            XCTAssertNil(error)
        //            connectExpect.fulfill()
        //            server.forceStop()
        //        }
        //        await fulfillment(of: [connectExpect], timeout: 3)
        //        let sendExpect = expectation(description: "Send callback called")
        //        sendExpect.expectedFulfillmentCount = 2
        //        socket.send(dataToSend) { error in
        //            XCTAssertNotNil(error)
        //            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error, default: "??")") }
        //            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
        //            XCTAssertTrue([.EPIPE, .ENOTCONN].contains(code), "Posix code \(code)")
        //            sendExpect.fulfill()
        //        }
        //        socket.send(dataToSend) { error in
        //            XCTAssertNotNil(error)
        //            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error, default: "??")") }
        //            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
        //            XCTAssertTrue([.EPIPE, .ENOTCONN].contains(code), "Posix code \(code)")
        //            sendExpect.fulfill()
        //        }
        //        await fulfillment(of: [sendExpect], timeout: 2)
    }
    
    // MARK: PROTOCOL ERRORS
    
    func test_Send_LargeData_CallbackSuccess() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 4 * 1024 * 1024)
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
            socket.send(dataToSend) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }
    
    // MARK: ENDPOINT ERRORS
    
    func test_Send_EndpointUnavailable_CallbackReturnsError() async throws {
        throw XCTSkip("Not applicable on TCP")
    }
    
    func test_Send_ServerInsecureAndSocketSecure_CallbackReturnsError() async throws {
        throw XCTSkip("Not applicable on TCP")
    }
    
    func test_Send_ServerSecureAndSocketInsecure_CallbackSuccess() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
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
            socket.send(dataToSend) { error in
                XCTAssertNil(error)
                sendExpect.fulfill()
            }
        }
        await fulfillment(of: [sendExpect], timeout: 3)
    }
}
