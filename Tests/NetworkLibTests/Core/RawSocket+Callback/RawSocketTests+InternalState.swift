import Testing
import Foundation
import Network
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var internalState: Tag
}

@Suite(.tags(.core, .RawSocket.all, .RawSocket.internalState), .timeLimit(.minutes(1)))
struct RawSocketInternalStateTests {
    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func connectThenCancel_CorrectSequence(_ transport: RawSocketTransport) async throws {
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: 0,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }

        let (sequence, seqContinuation) = AsyncStream.makeStream(of: (RawSocket._InternalState, RawSocket._InternalState).self)
        socket.onInternalStateChange = { oldState, newState in
            seqContinuation.yield((oldState, newState))
        }
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            socket.connect { _ in
                socket.cancel {
                    seqContinuation.finish()
                    continuation.resume()
                }
            }
        }

        let pairs = await sequence.values
        let states = pairs.map(\.1)
        try #require(states == [.connecting, .connected, .cancelling, .closed])
        try #require(pairs.allSatisfy { $0.0 < $0.1 })
    }


    @Test
    func notDeinitsUntilClosed() async throws {
        let underlyingConnection = NWConnectionMock()
        let accessQueue = DispatchQueue(label: "raw-socket.deallocation")
        let box = _SocketBox()
        // Keep setup temporaries out of the async test's lifetime.
        let _: Void = try {
            let socket = try RawSocket(underlyingConnection, accessQueue: accessQueue, delegateQueue: nil,
                                       timeout: 0, maxDataBlock: 256, transport: .tcp)
            box.set(socket)
        }()
        defer { box.get()?.cancel(nil) }
        let traceID = try #require(box.get()?.diagnosticsID)
        SocketDiagnostics.record(traceID, "test notDeinitsUntilClosed begin mock=\(underlyingConnection.diagnosticsID)")
        let weakSocket = _WeakSocketBox(box.get())
        try #require(weakSocket.socket != nil)

        let (sequence, seqContinuation) = AsyncStream.makeStream(of: (RawSocket._InternalState, RawSocket._InternalState).self)
        // End the temporary strong reference before awaiting cancellation.
        let _: Void = {
            box.get()?.onInternalStateChange = { oldState, newState in
                seqContinuation.yield((oldState, newState))
            }
        }()
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            SocketDiagnostics.record(traceID, "test connect.request")
            box.get()?.connect { result in
                SocketDiagnostics.record(traceID, "test connect.callback result=\(result)")
                box.get()?.cancel {
                    SocketDiagnostics.record(traceID, "test cancel.callback")
                    seqContinuation.finish()
                    continuation.resume()
                }
                box.set(nil)
                SocketDiagnostics.record(traceID, "test source.released")
            }
        }
        let pairs = await sequence.values
        let states = pairs.map(\.1)
        try #require(states == [.connecting, .connected, .cancelling, .closed])
        // Cancellation callbacks can run before the access queue finishes releasing the socket.
        await withCheckedContinuation { continuation in
            accessQueue.async {
                continuation.resume()
            }
        }
        // A weak reference tracks this instance even if another test reuses its address.
        SocketDiagnostics.record(traceID, "test accessQueue.barrier.completed")
        try #require(weakSocket.socket == nil)
    }
}

@Suite(.tags(.core, .RawSocket.cancel), .timeLimit(.minutes(1)))
struct RawSocketCancellationOrderingTests {
    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func parallelReceiveAndRepeatedCancellation_AllComplete(_ transport: RawSocketTransport) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<64 {
                group.addTask {
                    for _ in 0..<4 {
                        let mock = NWConnectionMock(overridedReceiveComplete: false)
                        let socket = try RawSocket(mock, accessQueue: nil, delegateQueue: nil,
                                                   timeout: 0, maxDataBlock: 256, transport: transport)
                        defer { socket.cancel(nil) }
                        try await socket.connect()
                        do {
                            _ = try await socket.receiveNext()
                            Issue.record("Empty incomplete receive must fail with EIO")
                        } catch {
                            #expect((error as? NWError) == .posix(.EIO))
                        }
                        async let first: Void = socket.cancel()
                        async let second: Void = socket.cancel()
                        _ = await (first, second)
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func readyQueuedBeforeCancellationCannotReconnectSocket(_ transport: RawSocketTransport) async throws {
        let accessQueue = DispatchQueue(label: "raw-socket.cancel-before-ready")
        let socket = try RawSocket(NWConnectionMock(), accessQueue: accessQueue, delegateQueue: nil,
                                   timeout: 0, maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        let (states, stateContinuation) = AsyncStream.makeStream(of: RawSocket._InternalState.self)
        let (results, resultContinuation) = AsyncStream.makeStream(of: Result<ConnectionInfo, NWError>.self)
        socket.onInternalStateChange = { _, state in
            stateContinuation.yield(state)
        }

        // start() queues ready behind cancel: force this ordering without sleeps or scheduler luck.
        accessQueue.sync {
            socket.connect { result in
                resultContinuation.yield(result)
                resultContinuation.finish()
            }
            socket.cancel {
                stateContinuation.finish()
            }
        }

        let observedStates = await states.values
        let observedResults = await results.values
        #expect(observedStates == [.connecting, .cancelling, .closed])
        let result = try #require(observedResults.first)
        switch result {
        case .success:
            Issue.record("A queued ready event completed connect successfully after cancellation began")
        case .failure(let error):
            #expect(error == .posix(.ECANCELED))
        }
        #expect(observedResults.count == 1)
    }
}
