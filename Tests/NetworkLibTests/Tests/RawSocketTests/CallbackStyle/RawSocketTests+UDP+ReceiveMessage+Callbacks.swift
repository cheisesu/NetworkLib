import XCTest
import Network
@testable import NetworkLib

class RawSocketTests_UDP_ReceiveMessage_Callbacks: XCTestCase {
    private struct _ReceiveMessage: RawSocketReceiveMessage {
        let data: Data?
        init?(from context: NWConnection.ContentContext, with content: Data?) {
            data = content
        }
    }
    private let transport: RawSocketTransport = .udp

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: SUCCESS DATA BY PORTIONS

    func test_Receive_SmallPortion_CallbackReturnsFull() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("HELLO".utf8)
        let maxDataBlock: Int = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
                switch result {
                case let .success(message):
                    let data = message.data
                    XCTAssertEqual(data, dataToSend)
                    receiveExpect.fulfill()
                case let .failure(error): XCTFail("Unexpected entrance with error: \(error)")
                }
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_BigPortion_CallbackReturnsFull() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data(repeating: 0xde, count: 315)
        let maxDataBlock: Int = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
                switch result {
                case let .success(message):
                    let data = message.data
                    XCTAssertEqual(data, dataToSend)
                    receiveExpect.fulfill()
                case let .failure(error): XCTFail("Unexpected entrance with error: \(error)")
                }
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_BigPortion_MultipleCalls_CallbackReturnsRelatedDataAndNextNotCalled() async throws {
        let timeout: TimeInterval = 0
        let dataToSend1 = Data(repeating: 0xde, count: 256)
        let dataToSend2 = Data(repeating: 0xde, count: 129)
        let dataToSend = dataToSend1 + dataToSend2
        let maxDataBlock: Int = 256
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive called")
        let notReceiveExpect = expectation(description: "For callback on receive not called")
        notReceiveExpect.isInverted = true
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
                switch result {
                case let .success(message):
                    let data = message.data
                    XCTAssertEqual(data, dataToSend)
                    receiveExpect.fulfill()
                    socket.receiveNextMessage(of: _ReceiveMessage.self) { _ in
                        notReceiveExpect.fulfill()
                    }
                case let .failure(error): XCTFail("Unexpected entrance with error: \(error)")
                }
            }
        }
        await fulfillment(of: [receiveExpect, notReceiveExpect], timeout: 3, enforceOrder: true)
    }

    // MARK: TIMEOUTS

    func test_Receive_TimeOutSet_ServerNotEchos_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0.5
        let dataToSend = Data("Hello".utf8)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
                switch result {
                case let .success(message): XCTFail("Unexpected entrance with message: \(message)")
                case let .failure(error):
                    guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                    XCTAssertEqual(code, .ETIMEDOUT)
                    receiveExpect.fulfill()
                }
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    // MARK: COMMON ERRORS

    func test_Receive_FailCreatingMessage_CallbackReturnsBadMessageError() async throws {
        struct _ReceiveMessage: RawSocketReceiveMessage {
            init?(from context: NWConnection.ContentContext, with content: Data?) {
                return nil
            }
        }
        let timeout: TimeInterval = 0
        let dataToSend = Data("HELLO".utf8)
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { info, error in
            socket.send(dataToSend, nil)
            socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
                switch result {
                case let .success(message): XCTFail("Unexpected entrance with message: \(message)")
                case let .failure(error):
                    guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                    XCTAssertEqual(code, .EBADMSG)
                    receiveExpect.fulfill()
                }
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
            switch result {
            case let .success(message): XCTFail("Unexpected entrance with message: \(message)")
            case let .failure(error):
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ENOTCONN)
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 1, enforceOrder: true)
    }

    func test_Receive_WhenCancelling_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel(nil)
            socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
                switch result {
                case let .success(message): XCTFail("Unexpected entrance with message: \(message)")
                case let .failure(error):
                    guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                    XCTAssertEqual(code, .ECANCELED)
                    receiveExpect.fulfill()
                }
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.cancel(nil)
        socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
            switch result {
            case let .success(message): XCTFail("Unexpected entrance with message: \(message)")
            case let .failure(error):
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                receiveExpect.fulfill()
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_WhenCancelledWhenConnected_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel {
                socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
                    switch result {
                    case let .success(message): XCTFail("Unexpected entrance with message: \(message)")
                    case let .failure(error):
                        guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                        XCTAssertEqual(code, .ECANCELED)
                        receiveExpect.fulfill()
                    }
                }
            }
        }
        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }

    func test_Receive_WhenCancelledWhenWaitingReceive_CallbackReturnsError() async throws {
        throw XCTSkip("Fails some times with nil error in receive")
    }

    // MARK: SUCCESS IN DIFFERENT STATE

    func test_Receive_WhenConnecting_CallbackSuccess() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, _ in
            socket.send(dataToSend, nil)
        }
        socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
            switch result {
            case let .success(message):
                let data = message.data
                XCTAssertEqual(data, dataToSend)
                receiveExpect.fulfill()
            case let .failure(error): XCTFail("Unexpected entrance with error: \(error)")
            }
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        receiveExpect.isInverted = true
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.receiveNextMessage(of: _ReceiveMessage.self) { _ in
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
                switch result {
                case let .success(message):
                    let data = message.data
                    XCTAssertNil(data)
                    receiveExpect.fulfill()
                case let .failure(error): XCTFail("Unexpected entrance with error: \(error)")
                }
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.send(dataToSend, nil)
            socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
                switch result {
                case let .success(message):
                    let data = message.data
                    XCTAssertNil(data)
                    receiveExpect.fulfill()
                case let .failure(error): XCTFail("Unexpected entrance with error: \(error)")
                }
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let receiveExpect = expectation(description: "For callback on receive")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.receiveNextMessage(of: _ReceiveMessage.self) { result in
                switch result {
                case let .success(message):
                    let data = message.data
                    XCTAssertNil(data)
                    receiveExpect.fulfill()
                case let .failure(error): XCTFail("Unexpected entrance with error: \(error)")
                }
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
        let maxDataBlock: Int = .max
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let box = _SocketBox()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        try box.set(RawSocket(config))
        defer { box.get()?.cancel(nil) }

        let connectExpect = expectation(description: "For callback on connect")
        let receiveExpect = expectation(description: "For callback on receive")
        box.get()?.connect { _, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3, enforceOrder: true)
        box.get()?.receiveNextMessage(of: _ReceiveMessage.self) { result in
            switch result {
            case let .success(message): XCTFail("Unexpected entrance with message: \(message)")
            case let .failure(error):
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                receiveExpect.fulfill()
            }
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
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        try box.set(RawSocket(config))
        defer { box.get()?.cancel(nil) }

        let connectExpect = expectation(description: "For callback on connect")
        let receiveExpect = expectation(description: "For callback on receive")
        box.get()?.connect { _, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3, enforceOrder: true)
        box.get()?.receiveNextMessage(of: _ReceiveMessage.self) { result in
            switch result {
            case let .success(message): XCTFail("Unexpected entrance with message: \(message)")
            case let .failure(error):
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                receiveExpect.fulfill()
            }
        }
        box.get()?.send(dataToSend) { _ in
            box.set(nil)
        }

        await fulfillment(of: [receiveExpect], timeout: 3, enforceOrder: true)
    }
}
