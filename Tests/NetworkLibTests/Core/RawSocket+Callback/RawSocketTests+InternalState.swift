import Testing
import Foundation
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
        try await #require(sequence.allSatisfy { $0.0 < $0.1 })
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
            box.get()?.connect { _ in
                box.get()?.cancel {
                    seqContinuation.finish()
                    continuation.resume()
                }
                box.set(nil)
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
        try #require(weakSocket.socket == nil)
    }
}
