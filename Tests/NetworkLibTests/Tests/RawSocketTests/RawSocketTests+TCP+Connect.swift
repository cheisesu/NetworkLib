import XCTest
import Network
@testable import NetworkLib

class RawSocketTests_TCP_Connect: XCTestCase {
    private let transport: NetTransport = .tcp

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: URL INIT

    /// Checks initialization with connection url from ip and port, and https
    func test_Connect_WithUrlIpHttps_BothSecure_SuccessConnect() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let url = try XCTUnwrap(URL(string: "https://127.0.0.1:\(port)"))

        let socket = try RawSocket(url: url, maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    /// Checks initialization with connection with url from ip and port, and http
    func test_Connect_WithUrlIpHttp_BothSecure_SuccessConnect() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)"))

        let socket = try RawSocket(url: url, maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    /// Checks initialization with connection with url from ip and port, without scheme
    func test_Connect_WithUrlIpNoScheme_BothSecure_SuccessConnect() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let url = try XCTUnwrap(URL(string: "://127.0.0.1:\(port)"))

        let socket = try RawSocket(url: url, maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    /// Checks initialization with connection with url by domain name with port
    func test_Connect_WithUrlName_BothSecure_SuccessConnect() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let url = try XCTUnwrap(URL(string: "https://localhost:\(port)"))

        let socket = try RawSocket(url: url, maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    // MARK: SUCCESS CONNECTS

    func test_Connect_BothSecure_SuccessConnect() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }
    
    func test_Connect_BothInsecure_SuccessConnect() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: nil)
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }
    
    func test_Connect_Success_BothSecure_ThenCancel_ConnectCallbackIsCalledOnlyOnce() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called the second time must fail")
        let cancelExpect = expectation(description: "Cancel callback called to check")
        socket.connect { info, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
            socket.cancel {
                cancelExpect.fulfill()
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
        await fulfillment(of: [connectExpect], timeout: 4)
    }
    
    func test_Connect_Success_BothInsecure_ThenCancel_ConnectCallbackIsCalledOnlyOnce() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: nil)
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called the second time must fail")
        let cancelExpect = expectation(description: "Cancel callback called to check")
        socket.connect { info, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
            socket.cancel {
                cancelExpect.fulfill()
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
        await fulfillment(of: [connectExpect], timeout: 4)
    }

    // MARK: TIMEOUTS

    func test_Connect_TimeOutSet_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0.2
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called with error")
        socket.connect { info, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ETIMEDOUT)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenIpNotAvailableAndTimeOutSet_CallbackNotCalled() async throws {
        let timeout: TimeInterval = 0.2
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.10", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback not called")
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ETIMEDOUT)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    // MARK: DEINITS

    func test_Connect_DeinitBeforeConnect_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let box = _SocketBox()
        box.set(try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                              transport: transport, timeout: timeout, sni: "localhost"))
        defer { box.get()?.cancel() }

        let connectExpect = expectation(description: "Connect callback called with error")
        box.get()?.connect { info, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EPERM)
            connectExpect.fulfill()
        }
        box.set(nil)
        await fulfillment(of: [connectExpect], timeout: 3)
    }
    
    func test_Connect_DeinitOnSameQueue_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let box = _SocketBox()
        box.set(try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                              transport: transport, timeout: timeout, sni: "localhost"))
        defer { box.get()?.cancel() }

        let connectExpect = expectation(description: "Connect callback called with error")
        box.get()?.connect { info, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EPERM)
            connectExpect.fulfill()
        }
        box.get()?.connect { _, _ in
            box.set(nil)
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }
    
    func test_Connect_DeinitOnDifferentQueue_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let box = _SocketBox()
        box.set(try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                              transport: transport, timeout: timeout, sni: "localhost"))
        defer { box.get()?.cancel() }

        let connectExpect = expectation(description: "Connect callback called with error")
        box.get()?.connect { info, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EPERM)
            connectExpect.fulfill()
        }
        let flagExpect = expectation(description: "Flag")
        box.get()?.connect { _, _ in
            flagExpect.fulfill()
        }
        await fulfillment(of: [flagExpect], timeout: 1)
        box.set(nil)
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    // MARK: ERRORS IN DIFFERENT STATES

    func test_Connect_WhenConnecting_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let flagExpect = expectation(description: "Flag")
        socket.connect { info, error in
            flagExpect.fulfill()
        }
        let connectExpect = expectation(description: "Connect callback called with error")
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EALREADY)
            connectExpect.fulfill()
        }
        await fulfillment(of: [flagExpect], timeout: 1)
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenConnected_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called with error")
        socket.connect { info, error in
            XCTAssertNil(error)
            socket.connect { _, error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .EISCONN)
                connectExpect.fulfill()
            }
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenCancelling_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called with error")
        socket.connect { info, error in
            XCTAssertNil(error)
            socket.cancel()
            socket.connect { _, error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                connectExpect.fulfill()
            }
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenCancelling_NotProducesConnectAnymore_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called with error")
        connectExpect.expectedFulfillmentCount = 2
        socket.connect { info, error in
            XCTAssertNil(error)
            socket.cancel()
            socket.connect { _, error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                connectExpect.fulfill()
            }
            // if there's no check for .cancelling state, it may change it to .connecting and start connection again.
            // But in state update handler when nw state changes on cancelled, callback will be called with cancelled error.
            // So there's the second check for propied state
            socket.connect { _, error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                connectExpect.fulfill()
            }
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenCancelledAfterConnect_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called with error")
        socket.connect { info, error in
            XCTAssertNil(error)
            socket.cancel {
                socket.connect { _, error in
                    XCTAssertNotNil(error)
                    guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                    guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                    XCTAssertEqual(code, .ECANCELED)
                    connectExpect.fulfill()
                }
            }
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenCancelledBeforeConnect_InCancelCallback_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called with error")
        socket.cancel {
            socket.connect { _, error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                connectExpect.fulfill()
            }
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenCancelledBeforeConnect_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called with error")
        socket.cancel()
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ECANCELED)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    // MARK: ENDPOINT ERRORS

    func test_Connect_WhenWrongIp_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.256", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNotNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenIpNotAvailable_CallbackNotCalled() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.10", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback not called")
        connectExpect.isInverted = true
        socket.connect { _, _ in
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    // MARK: ERRORS BY SERVER BEHAVIOUR

    func test_Connect_WhenServerNotAcceptsConnection_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true, flow: .cancel)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ECONNRESET)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_BothSecure_WhenServerDisconnectsConnectionRightAfterAccept_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true, flow: .acceptAndCancel)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .tls(let status) = error else { return XCTFail("Error is not tls \(error)") }
            XCTAssertEqual(status, errSSLClosedNoNotify)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_BothInsecure_WhenServerDisconnectsConnectionRightAfterAccept_CallbackReturnsError() async throws {
        throw XCTSkip("Problems on server side")
    }

    func test_Connect_WhenServerIsUdp_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: .udp, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ECONNREFUSED)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenServerSecureAndSocketInsecure_CallbackSuccess() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: nil)
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { info, error in
            XCTAssertNil(error)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenServerInsecureAndSocketSecure_CallbackNotCalled() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        connectExpect.isInverted = true
        socket.connect { _, _ in
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenServerStoppedRightAfterItsStart_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        server.stop()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ECONNREFUSED)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_WhenServerNotExists_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: 65535), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ECONNREFUSED)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_BothSecure_WhenConnecting_ServerStops_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .tls(let status) = error else { return XCTFail("Error is not tls \(error)") }
            XCTAssertEqual(status, errSSLClosedNoNotify)
            connectExpect.fulfill()
        }
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EALREADY)
            server.stop()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_BothInsecure_WhenConnecting_ServerStops_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: nil)
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ECONNREFUSED)
            connectExpect.fulfill()
        }
        server.stop()
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_ServerInsecureAndSocketSecure_WhenConnecting_ServerStops_CallbackReturnsError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .tls(let status) = error else { return XCTFail("Error is not tls \(error)") }
            XCTAssertEqual(status, errSSLClosedNoNotify)
            connectExpect.fulfill()
        }
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EALREADY)
            server.stop()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_ServerSecureAndSocketInsecure_WhenConnecting_ServerStops_CallbackReturnsError() async throws {
        throw XCTSkip("Problems on server side")
    }

    // MARK: CONNECTION INFO

    func test_Connect_WithUrl_Success_InfoCorrect() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let url = try XCTUnwrap(URL(string: "https://127.0.0.1:\(port)"))
        let socket = try RawSocket(url: url, maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { [transport] info, error in
            XCTAssertNil(error)
            XCTAssertEqual(info?.transport, transport)
            XCTAssertEqual(info?.internface?.name, "lo0")
            XCTAssertEqual(info?.remoteEndpoint, .url(url))
            switch info?.localEndpoint {
            case .hostPort(let host, _):
                switch host {
                case .ipv4(let ip):
                    XCTAssertEqual(ip, IPv4Address("127.0.0.1"))
                default: XCTFail("Incorrect local host")
                }
            default: XCTFail("Incorrect local endpoint")
            }
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_Connect_Success_InfoCorrect() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called")
        socket.connect { [transport] info, error in
            XCTAssertNil(error)
            XCTAssertEqual(info?.transport, transport)
            XCTAssertEqual(info?.internface?.name, "lo0")
            XCTAssertEqual(info?.remoteEndpoint, NWEndpoint.hostPort(host: "127.0.0.1", port: port))
            switch info?.localEndpoint {
            case .hostPort(let host, _):
                switch host {
                case .ipv4(let ip):
                    XCTAssertEqual(ip, IPv4Address("127.0.0.1"))
                default: XCTFail("Incorrect local host")
                }
            default: XCTFail("Incorrect local endpoint")
            }
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }
}
