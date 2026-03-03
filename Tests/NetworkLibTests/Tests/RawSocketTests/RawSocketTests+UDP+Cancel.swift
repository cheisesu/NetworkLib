import XCTest
import Network
@testable import NetworkLib

class RawSocketTests_UDP_Cancel: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test_Cancel_WhenNotConnected_OneBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let cancelExpect = expectation(description: "Callback called")
        socket.cancel {
            cancelExpect.fulfill()
        }
        await fulfillment(of: [cancelExpect], timeout: 1)
    }

    func test_Cancel_WhenConnecting_OneBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let cancelExpect = expectation(description: "Callback called")
        socket.connect { _, _ in
        }
        socket.cancel {
            cancelExpect.fulfill()
        }
        await fulfillment(of: [cancelExpect], timeout: 1)
    }

    func test_Cancel_WhenConnected_OneBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let cancelExpect = expectation(description: "Callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel {
                cancelExpect.fulfill()
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }

    func test_Cancel_WhenCancelled_OneBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let cancelExpect = expectation(description: "Callback called")
        socket.cancel {
            socket.cancel {
                cancelExpect.fulfill()
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }

    func test_Cancel_WhenNotConnected_WithoutAndWithBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")

        let cancelExpect = expectation(description: "Callback called")
        socket.cancel()
        socket.cancel {
            cancelExpect.fulfill()
        }
        await fulfillment(of: [cancelExpect], timeout: 1)
    }

    func test_Cancel_WhenConnecting_WithoutAndWithBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")

        let cancelExpect = expectation(description: "Callback called")
        socket.connect { _, _ in
        }
        socket.cancel()
        socket.cancel {
            cancelExpect.fulfill()
        }
        await fulfillment(of: [cancelExpect], timeout: 1)
    }

    func test_Cancel_WhenConnected_WithoutAndWithBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")

        let cancelExpect = expectation(description: "Callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel()
            socket.cancel {
                cancelExpect.fulfill()
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }

    func test_Cancel_WhenCancelled_WithoutAndWithBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")

        let cancelExpect = expectation(description: "Callback called")
        socket.cancel {
            socket.cancel()
            socket.cancel {
                cancelExpect.fulfill()
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }

    func test_Cancel_WhenNotConnected_WithAndWithoutBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")

        let cancelExpect = expectation(description: "Callback called")
        socket.cancel {
            cancelExpect.fulfill()
        }
        socket.cancel()
        await fulfillment(of: [cancelExpect], timeout: 1)
    }

    func test_Cancel_WhenConnecting_WithAndWithoutBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")

        let cancelExpect = expectation(description: "Callback called")
        socket.connect { _, _ in
        }
        socket.cancel {
            cancelExpect.fulfill()
        }
        socket.cancel()
        await fulfillment(of: [cancelExpect], timeout: 1)
    }

    func test_Cancel_WhenConnected_WithAndWithoutBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")

        let cancelExpect = expectation(description: "Callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel {
                cancelExpect.fulfill()
            }
            socket.cancel()
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }

    func test_Cancel_WhenCancelled_WithAndWithoutBlock_CallbackCalled() async throws {
        let transport: NetTransport = .udp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")

        let cancelExpect = expectation(description: "Callback called")
        socket.cancel {
            socket.cancel {
                cancelExpect.fulfill()
            }
            socket.cancel()
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }

    func test_Cancel_WhenNotConnected_MultipleCallbacks_CallbacksCalled() async throws {
        throw XCTSkip("Not implemented")
    }

    func test_Cancel_WhenConnecting_MultipleCallbacks_CallbacksCalled() async throws {
        throw XCTSkip("Not implemented")
    }

    func test_Cancel_WhenConnected_MultipleCallbacks_CallbacksCalled() async throws {
        throw XCTSkip("Not implemented")
    }

    func test_Cancel_WhenCancelled_MultipleCallbacks_CallbacksCalled() async throws {
        throw XCTSkip("Not implemented")
    }

    func test_Cancel_DeinitOnSameQueue_CallbacksCalled() async throws {
        throw XCTSkip("Not implemented")
    }

    func test_Cancel_DeinitOnDifferentQueue_CallbacksCalled() async throws {
        throw XCTSkip("Not implemented")
    }
}
