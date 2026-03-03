import XCTest
import Network
@testable import NetworkLib

class RawSocketTests_UDP_Connect: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func test_Connect_Success_BothSecure_SuccessConnect() async throws {
        let transport: NetTransport = .udp
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
    
    func test_Connect_Success_BothInsecure_SuccessConnect() async throws {
        let transport: NetTransport = .udp
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
        let transport: NetTransport = .udp
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
        let transport: NetTransport = .udp
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
    
    func test_Connect_TimeOut_CallbackReturnsError() async throws {
        let transport: NetTransport = .udp
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
    
    func test_Connect_DeinitBeforeConnect_CallbackReturnsError() async throws {
        let transport: NetTransport = .udp
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
        let transport: NetTransport = .udp
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
        let transport: NetTransport = .udp
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
    
    func test_Connect_WhenConnecting_CallbackReturnsError() async throws {
        let transport: NetTransport = .udp
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
        let transport: NetTransport = .udp
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
        let transport: NetTransport = .udp
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

    func test_Connect_WhenCancelledAfterConnect_CallbackReturnsError() async throws {
        let transport: NetTransport = .udp
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
        let transport: NetTransport = .udp
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
        let transport: NetTransport = .udp
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
}
