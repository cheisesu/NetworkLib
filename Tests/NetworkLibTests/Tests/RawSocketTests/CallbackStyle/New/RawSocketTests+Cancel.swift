import Testing
import Foundation
import Network
@testable import NetworkLib

struct RawSocketCancelTests {
    struct OneCallback {
        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenNotConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let config = RawSocketConfiguration("127.0.0.1", 65535, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.cancel {
                    cancel()
                    continuation.resume()
                }
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenConnecting_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .connecting else { return }
                    socket.cancel {
                        cancel()
                        continuation.resume()
                    }
                }
                socket.connect { _ in }
            } onCancel: {
                socket.cancel(nil)
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.connect { result in
                    switch result {
                    case .success:
                        socket.cancel {
                            cancel()
                            continuation.resume()
                        }
                    case let .failure(error):
                        cancel()
                        continuation.resume(throwing: error)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenCancelling_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.cancel {
                        cancel()
                        continuation.resume()
                    }
                }
                socket.connect { result in
                    do {
                        let _ = try result.get()
                        socket.cancel(nil)
                    } catch {
                        cancel()
                        continuation.resume(throwing: error)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenCancelled_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let config = RawSocketConfiguration("127.0.0.1", 65535, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.cancel {
                    socket.cancel {
                        cancel()
                        continuation.resume()
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
        }
    }

    struct WithoutThenWithCallback {
        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenNotConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let config = RawSocketConfiguration("127.0.0.1", 65535, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.cancel(nil)
                socket.cancel {
                    cancel()
                    continuation.resume()
                }
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenConnecting_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .connecting else { return }
                    socket.cancel(nil)
                    socket.cancel {
                        cancel()
                        continuation.resume()
                    }
                }
                socket.connect { _ in }
            } onCancel: {
                socket.cancel(nil)
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.connect { result in
                    switch result {
                    case .success:
                        socket.cancel(nil)
                        socket.cancel {
                            cancel()
                            continuation.resume()
                        }
                    case let .failure(error):
                        cancel()
                        continuation.resume(throwing: error)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenCancelling_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.cancel(nil)
                    socket.cancel {
                        cancel()
                        continuation.resume()
                    }
                }
                socket.connect { result in
                    do {
                        let _ = try result.get()
                        socket.cancel(nil)
                    } catch {
                        cancel()
                        continuation.resume(throwing: error)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenCancelled_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let config = RawSocketConfiguration("127.0.0.1", 65535, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.cancel {
                    socket.cancel(nil)
                    socket.cancel {
                        cancel()
                        continuation.resume()
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
        }
    }

    struct WithThenWithoutCallback {
        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenNotConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let config = RawSocketConfiguration("127.0.0.1", 65535, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.cancel {
                    cancel()
                    continuation.resume()
                }
                socket.cancel(nil)
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenConnecting_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .connecting else { return }
                    socket.cancel {
                        cancel()
                        continuation.resume()
                    }
                    socket.cancel(nil)
                }
                socket.connect { _ in }
            } onCancel: {
                socket.cancel(nil)
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.connect { result in
                    switch result {
                    case .success:
                        socket.cancel {
                            cancel()
                            continuation.resume()
                        }
                        socket.cancel(nil)
                    case let .failure(error):
                        cancel()
                        continuation.resume(throwing: error)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenCancelling_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.cancel {
                        cancel()
                        continuation.resume()
                    }
                    socket.cancel(nil)
                }
                socket.connect { result in
                    do {
                        let _ = try result.get()
                        socket.cancel(nil)
                    } catch {
                        cancel()
                        continuation.resume(throwing: error)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenCancelled_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let config = RawSocketConfiguration("127.0.0.1", 65535, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.cancel {
                    socket.cancel {
                        cancel()
                        continuation.resume()
                    }
                    socket.cancel(nil)
                }
            } onCancel: {
                socket.cancel(nil)
            }
        }
    }

    struct MultipleCallbacks {
        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenNotConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()
            socket.cancel {
                continuation.yield(1)
            }
            socket.cancel {
                continuation.yield(2)
                continuation.finish()
            }
            let result = try await withAsyncTimeout(.seconds(2)) {
                try await stream.values
            }
            try #require(result == [1, 2])
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenConnecting_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()
            socket.onInternalStateChange = { _, newState in
                guard newState == .connecting else { return }
                socket.cancel {
                    continuation.yield(1)
                }
                socket.cancel {
                    continuation.yield(2)
                    continuation.finish()
                }
            }
            socket.connect { _ in }
            let result = try await withAsyncTimeout(.seconds(2)) {
                try await stream.values
            }
            try #require(result == [1, 2])
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenCancelling_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()
            socket.onInternalStateChange = { _, newState in
                guard newState == .cancelling else { return }
                socket.cancel {
                    continuation.yield(2)
                }
                socket.cancel {
                    continuation.yield(3)
                    continuation.finish()
                }
            }
            socket.connect { result in
                do {
                    _ = try result.get()
                    socket.cancel { continuation.yield(1) }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            let result = try await withAsyncTimeout(.seconds(2)) {
                try await stream.values
            }
            try #require(result == [1, 2, 3])
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()
            socket.connect { result in
                do {
                    let _ = try result.get()
                    socket.cancel {
                        continuation.yield(1)
                    }
                    socket.cancel {
                        continuation.yield(2)
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            let result = try await withAsyncTimeout(.seconds(1)) {
                try await stream.values
            }
            try #require(result == [1, 2])
        }

        @Test(.tags(.RawSocket.cancel, .rawSocketAll), arguments: [
            (RawSocketTransport.tcp),
            (RawSocketTransport.udp),
        ])
        func whenCancelled_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let server = try ServerMock(transport: transport, isSecure: true)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()
            socket.connect { result in
                do {
                    let _ = try result.get()
                    socket.cancel {
                        socket.cancel {
                            continuation.yield(1)
                        }
                        socket.cancel {
                            continuation.yield(2)
                            continuation.finish()
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            let result = try await withAsyncTimeout(.seconds(1)) {
                try await stream.values
            }
            try #require(result == [1, 2])
        }
    }
}
