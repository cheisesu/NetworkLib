import XCTest
import Network
@testable import NetworkLib

class RawSocketTests_TCP_Cancel: XCTestCase {
    private let transport: NetTransport = .tcp

    override func setUp() {
        continueAfterFailure = false
    }

    func test_Cancel_WhenNotConnected_OneBlock_CallbackCalled() async throws {
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
        await fulfillment(of: [cancelExpect], timeout: 1)
    }

    func test_Cancel_WhenConnecting_OneBlock_CallbackCalled() async throws {
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
        await fulfillment(of: [cancelExpect], timeout: 1)
    }

    func test_Cancel_WhenConnected_OneBlock_CallbackCalled() async throws {
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
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }

    func test_Cancel_WhenNotConnected_WithoutAndWithBlock_CallbackCalled() async throws {
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
            socket.cancel()
            socket.cancel {
                cancelExpect.fulfill()
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }

    func test_Cancel_WhenCancelled_WithoutAndWithBlock_CallbackCalled() async throws {
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
            socket.cancel()
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }

    func test_Cancel_WhenCancelled_WithAndWithoutBlock_CallbackCalled() async throws {
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

    func test_Cancel_WhenNotConnected_MultipleCallbacks_CallbacksCalledInOrder() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")

        let cancel1Expect = expectation(description: "First callback called")
        let cancel2Expect = expectation(description: "Second callback called")
        socket.cancel {
            cancel1Expect.fulfill()
        }
        socket.cancel {
            cancel2Expect.fulfill()
        }
        await fulfillment(of: [cancel1Expect, cancel2Expect], timeout: 1, enforceOrder: true)
    }

    func test_Cancel_WhenConnecting_MultipleCallbacks_CallbacksCalledInOrder() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")

        let cancel1Expect = expectation(description: "First callback called")
        let cancel2Expect = expectation(description: "Second callback called")
        socket.connect { _, _ in
        }
        socket.cancel {
            cancel1Expect.fulfill()
        }
        socket.cancel {
            cancel2Expect.fulfill()
        }
        await fulfillment(of: [cancel1Expect, cancel2Expect], timeout: 1, enforceOrder: true)
    }

    func test_Cancel_WhenConnected_MultipleCallbacks_CallbacksCalledInOrder() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let cancel1Expect = expectation(description: "First callback called")
        let cancel2Expect = expectation(description: "Second callback called")
        socket.connect { _, error in
            XCTAssertNil(error)
            socket.cancel {
                cancel1Expect.fulfill()
            }
            socket.cancel {
                cancel2Expect.fulfill()
            }
        }
        await fulfillment(of: [cancel1Expect, cancel2Expect], timeout: 1, enforceOrder: true)
    }

    func test_Cancel_WhenCancelled_MultipleCallbacks_CallbacksCalledInOrder() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let cancel1Expect = expectation(description: "First callback called")
        let cancel2Expect = expectation(description: "Second callback called")
        socket.cancel {
            socket.cancel {
                cancel1Expect.fulfill()
            }
            socket.cancel {
                cancel2Expect.fulfill()
            }
        }
        await fulfillment(of: [cancel1Expect, cancel2Expect], timeout: 1, enforceOrder: true)
    }

    func test_Cancel_WhenDeinited_CallbacksCalled() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let box = _SocketBox()
        box.set(try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                              transport: transport, timeout: timeout, sni: "localhost"))
        defer { box.get()?.cancel() }

        let cancelExpect = expectation(description: "Callback called")
        box.get()?.cancel {
            cancelExpect.fulfill()
        }
        box.set(nil)
        await fulfillment(of: [cancelExpect], timeout: 1)
    }

    func test_Cancel_DeinitOnSameQueue_CallbacksCalled() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let box = _SocketBox()
        box.set(try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                              transport: transport, timeout: timeout, sni: "localhost"))
        defer { box.get()?.cancel() }

        let cancelExpect = expectation(description: "Callback called")
        box.get()?.connect { _, error in
            XCTAssertNil(error)
            box.get()?.cancel {
                cancelExpect.fulfill()
            }
            box.get()?.connect { _, _ in
                box.set(nil)
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }

    func test_Cancel_DeinitOnDifferentQueue_CallbacksCalled() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let box = _SocketBox()
        box.set(try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                              transport: transport, timeout: timeout, sni: "localhost"))
        defer { box.get()?.cancel() }

        let cancelExpect = expectation(description: "Callback called")
        box.get()?.connect { _, error in
            XCTAssertNil(error)
            box.get()?.cancel {
                cancelExpect.fulfill()
            }
            box.get()?.connect { _, _ in
                DispatchQueue.global().async {
                    box.set(nil)
                }
            }
        }
        await fulfillment(of: [cancelExpect], timeout: 3)
    }
}
