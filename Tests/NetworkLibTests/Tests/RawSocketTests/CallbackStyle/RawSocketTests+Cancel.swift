import Testing
import Foundation
import Network
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var cancel: Tag
}

@Suite(.tags(.RawSocket.cancel, .RawSocket.all), .timeLimit(.minutes(1)))
struct RawSocketCancelTests {
    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func callbackCalledOnDelegateQueue(_ transport: RawSocketTransport) async throws {
        let delegateQueue = DispatchQueue(label: "raw-socket.delegate.cancel")
        let probe = DelegateQueueProbe()
        probe.install(on: delegateQueue)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: delegateQueue, timeout: 0,
                                   maxDataBlock: 256, transport: transport)
        let result = await withCheckedContinuation { continuation in
            socket.cancel {
                continuation.resume(returning: probe.isCurrentQueue)
            }
        }

        try #require(result)
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenCancelled_AndSourceReferencesAllNil_NoReferences(_ transport: RawSocketTransport) async throws {
        let underlyingConnection = NWConnectionMock()
        var tempSocket: RawSocket? = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil,
                                                   timeout: 0, maxDataBlock: 256, transport: transport)
        let address = ReferencesCounter.shared.address(of: tempSocket)
        let box = _SocketBox()
        box.set(tempSocket)
        tempSocket = nil
        defer { box.get()?.cancel(nil) }
        try #require(ReferencesCounter.shared.count(of: address) == 1)
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            box.get()?.connect { _ in
                box.get()?.cancel {
                    continuation.resume()
                }
                box.set(nil)
            }
        }
        try #require(ReferencesCounter.shared.count(of: address) == 0)
    }

    struct OneCallback {
        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenNotConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)

            // if it doesn't call callback it will not call continuation
            await withCheckedContinuation { continuation in
                socket.cancel {
                    continuation.resume()
                }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenConnecting_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            await withCheckedContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .connecting else { return }
                    socket.cancel {
                        continuation.resume()
                    }
                }
                socket.connect { _ in }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.connect { result in
                    switch result {
                    case .success:
                        socket.cancel {
                            continuation.resume()
                        }
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenCancelling_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.cancel {
                        continuation.resume()
                    }
                }
                socket.connect { result in
                    do {
                        let _ = try result.get()
                        socket.cancel(nil)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenCancelled_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.cancel {
                    socket.cancel {
                        continuation.resume()
                    }
                }
            }
        }
    }

    struct WithoutThenWithCallback {
        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenNotConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.cancel(nil)
                socket.cancel {
                    continuation.resume()
                }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenConnecting_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .connecting else { return }
                    socket.cancel(nil)
                    socket.cancel {
                        continuation.resume()
                    }
                }
                socket.connect { _ in }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.connect { result in
                    switch result {
                    case .success:
                        socket.cancel(nil)
                        socket.cancel {
                            continuation.resume()
                        }
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenCancelling_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.cancel(nil)
                    socket.cancel {
                        continuation.resume()
                    }
                }
                socket.connect { result in
                    do {
                        let _ = try result.get()
                        socket.cancel(nil)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenCancelled_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.cancel {
                    socket.cancel(nil)
                    socket.cancel {
                        continuation.resume()
                    }
                }
            }
        }
    }

    struct WithThenWithoutCallback {
        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenNotConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.cancel {
                    continuation.resume()
                }
                socket.cancel(nil)
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenConnecting_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .connecting else { return }
                    socket.cancel {
                        continuation.resume()
                    }
                    socket.cancel(nil)
                }
                socket.connect { _ in }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.connect { result in
                    switch result {
                    case .success:
                        socket.cancel {
                            continuation.resume()
                        }
                        socket.cancel(nil)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenCancelling_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.cancel {
                        continuation.resume()
                    }
                    socket.cancel(nil)
                }
                socket.connect { result in
                    do {
                        let _ = try result.get()
                        socket.cancel(nil)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenCancelled_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }
            try await withCheckedThrowingContinuation { continuation in
                socket.cancel {
                    socket.cancel {
                        continuation.resume()
                    }
                    socket.cancel(nil)
                }
            }
        }
    }

    struct MultipleCallbacks {
        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenNotConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
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

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenConnecting_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
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

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenCancelling_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
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

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenConnected_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
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

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func whenCancelled_CallbackCalled(_ transport: RawSocketTransport) async throws {
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                       maxDataBlock: 256, transport: transport)
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
