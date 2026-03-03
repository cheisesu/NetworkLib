import XCTest
import Network
@testable import NetworkLib

/*
 + success connect
 + multiple cancels with callbacks
 + provided connection info has correct values
 - when socket class deallocated
 + error
   + force cancel during connect (for reset by peer)
   + server cancels incomming connections on connect
 + timeouts
   + connect ready, timeout not triggerring
 */

class RawSocketTests_TCP_Connect: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func test_SuccessConnect_BothSecure_ThenCancel_ConnectCallbackIsCalledOnlyOnce() async throws {
        // TODO: when connection not sets sni it still works but should fail?
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called the second time must fail")
        let cancelExpect = expectation(description: "Cancel callback called to check")
        cancelExpect.expectedFulfillmentCount = 1
        socket.connect { info, error in
            connectExpect.fulfill()
            socket.cancel {
                cancelExpect.fulfill()
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
        await fulfillment(of: [connectExpect], timeout: 4)
    }
    
    func test_Connect_WithUrl_Success_InfoCorrect() async throws {
        let transport: NetTransport = .tcp
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
        await fulfillment(of: [connectExpect], timeout: 4)
    }

    func test_Connect_Success_InfoCorrect() async throws {
        let transport: NetTransport = .tcp
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
        await fulfillment(of: [connectExpect], timeout: 4)
    }

    func test_SuccessConnect_BothInsecure_ThenCancel_ConnectCallbackIsCalledOnlyOnce() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: nil)
        defer { socket.cancel() }

        let connectMultExpect = expectation(description: "Connect callback called the second time must fail")
        connectMultExpect.expectedFulfillmentCount = 2
        connectMultExpect.isInverted = true
        let cancelExpect = expectation(description: "Cancel callback called to check")
        cancelExpect.expectedFulfillmentCount = 1
        socket.connect { info, error in
            connectMultExpect.fulfill()
            socket.cancel {
                cancelExpect.fulfill()
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
        await fulfillment(of: [connectMultExpect], timeout: 4)
    }

    func test_TimeOutConnect_WhenServersNonTlsAndConnectionTls() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 1
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback called only once")
        connectExpect.expectedFulfillmentCount = 1
        socket.connect { info, error in
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ETIMEDOUT)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: timeout + 2)
    }

    func test_Connect_WrongSni_CallbackFails() async throws {
        throw XCTSkip("Not working server side")
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost_wrong")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback fails")
        socket.connect { info, error in
            guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
            guard case .tls = error else { return XCTFail("Error is not tls") }
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: timeout + 2)
    }

    func test_Connect_WhenServersNonTlsAndConnectionTlsAndNoTimeOut_CallbackNotCalled() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback not called")
        connectExpect.isInverted = true
        socket.connect { info, error in
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3)
    }

    func test_ConnectsInRaw_SecondConnectReturnsError_AndFirstSuccess() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectSuccessExpect = expectation(description: "First connect callback should be success")
        let connectFailExpect = expectation(description: "Second connect callback should fail")
        socket.connect { info, error in
            connectSuccessExpect.fulfill()
        }
        socket.connect { info, error in
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EALREADY)
            connectFailExpect.fulfill()
        }
        await fulfillment(of: [connectSuccessExpect, connectFailExpect], timeout: 3)
    }

    func test_ConnectWhenConnected_SecondConnectReturnsError_AndFirstSuccess() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectSuccessExpect = expectation(description: "First connect callback should be success")
        let connectFailExpect = expectation(description: "Second connect callback should fail")
        socket.connect { info, error in
            connectSuccessExpect.fulfill()
            socket.connect { info, error in
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .EISCONN)
                connectFailExpect.fulfill()
            }
        }
        await fulfillment(of: [connectSuccessExpect, connectFailExpect], timeout: 3, enforceOrder: true)
    }

    func test_ConnectWhenUnderlyingConnectionCancelledAlready_SecondConnectReturnsError_AndFirstSuccess() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectSuccessExpect = expectation(description: "First connect callback should be success")
        let connectFailExpect = expectation(description: "Second connect callback should fail")
        socket.connect { info, error in
            connectSuccessExpect.fulfill()
            socket.cancel {
                socket.connect { info, error in
                    guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                    guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                    XCTAssertEqual(code, .ECANCELED)
                    connectFailExpect.fulfill()
                }
            }
        }
        await fulfillment(of: [connectSuccessExpect, connectFailExpect], timeout: 3, enforceOrder: true)
    }

    func test_ConnectWhenCancelling_SecondConnectReturnsError_AndFirstSuccess() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectSuccessExpect = expectation(description: "First connect callback should be success")
        let connectFailExpect = expectation(description: "Second connect callback should fail")
        socket.connect { info, error in
            connectSuccessExpect.fulfill()
            socket.cancel()
            socket.connect { info, error in
                guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
                XCTAssertEqual(code, .ECANCELED)
                connectFailExpect.fulfill()
            }
        }
        await fulfillment(of: [connectSuccessExpect, connectFailExpect], timeout: 3, enforceOrder: true)
    }

    func test_ConnectAfterCancelInitial_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback must fail")
        socket.cancel()
        socket.connect { info, error in
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ECANCELED)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3, enforceOrder: true)
    }

    func test_ConnectWhenResourceUnavailable_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback must fail")
        socket.connect { info, error in
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            switch error {
            case .posix(let code): XCTAssertEqual(code, .ECONNREFUSED)
            case .tls(let status): XCTAssertEqual(status, errSSLClosedNoNotify)
            default: XCTFail("Unexpected error \(error)")
            }
            connectExpect.fulfill()
        }
        server.stop()
        await fulfillment(of: [connectExpect], timeout: 3, enforceOrder: true)
    }

    func test_Connect_ServerCancels_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true, flow: .waitConnect)
        let port = try await server.start()
        defer { server.stop() }

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback must fail")
        socket.connect { info, error in
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            switch error {
            case .posix(let code): XCTAssertEqual(code, .ECONNREFUSED)
            case .tls(let status): XCTAssertEqual(status, errSSLClosedNoNotify)
            default: XCTFail("Unexpected error \(error)")
            }
            connectExpect.fulfill()
        }
        server.stop()
        await fulfillment(of: [connectExpect], timeout: 3, enforceOrder: true)
    }

    func test_Connect_ServerForceCancels_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        let port = try await server.start()
        defer { server.stop() }

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback must fail")
        socket.connect { info, error in
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            switch error {
            case .posix(let code): XCTAssertEqual(code, .ECONNREFUSED)
            case .tls(let status): XCTAssertEqual(status, errSSLClosedNoNotify)
            default: XCTFail("Unexpected error \(error)")
            }
            connectExpect.fulfill()
        }
        server.forceStop()
        await fulfillment(of: [connectExpect], timeout: 3, enforceOrder: true)
    }

    func test_Connect_ServerCancelsIncomming_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true, flow: .cancel)
        let port = try await server.start()
        defer { server.stop() }

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let connectExpect = expectation(description: "Connect callback must fail")
        socket.connect { info, error in
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .ECONNRESET)
            connectExpect.fulfill()
        }
        await fulfillment(of: [connectExpect], timeout: 3, enforceOrder: true)
    }
    
    func test_Connect_ThenDeinitBeforePhysicalConnect_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true, flow: .waitConnect)
        let port = try await server.start()
        defer { server.stop() }

        var socket: RawSocket? = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                               transport: transport, timeout: timeout, sni: "localhost")

        let connectExpect = expectation(description: "Connect callback must fail")
        socket?.connect { info, error in
            guard let error = error as? NWError else { return XCTFail("Error is not NWError \(error)") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix \(error)") }
            XCTAssertEqual(code, .EPERM)
            connectExpect.fulfill()
        }
        socket = nil
        await fulfillment(of: [connectExpect], timeout: 3, enforceOrder: true)
    }
    
    func test_Connect_DeinitAfterConnectAndCancelFromSameQueue_CallbackReturnsError() async throws {
        throw XCTSkip("Not working")
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true, flow: .waitConnect)
        let port = try await server.start()
        defer { server.stop() }

        let box: _SocketBox? = _SocketBox()
        try box?.set(RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                           transport: transport, timeout: timeout, sni: "localhost"))

        let cancelExpect = expectation(description: "Connect callback must fail")
        box?.get()?.connect { info, error in
            XCTAssertNil(error)
            weak let socket = box?.get()
            defer { box?.set(nil) }
            socket?.cancel { // ref count + 1
                cancelExpect.fulfill()
            }
            socket?.cancel { // ref count + 1
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3, enforceOrder: true)
    }
}
