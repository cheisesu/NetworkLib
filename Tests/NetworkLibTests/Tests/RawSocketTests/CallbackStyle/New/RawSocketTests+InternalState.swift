import Testing
import Foundation
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var internalState: Tag
}

struct RawSocketInternalStateTests {
    @Test(.timeLimit(.minutes(1)), .tags(.RawSocket.internalState, .RawSocket.all),
          arguments: [RawSocketTransport.tcp, .udp])
    func connectThenCancel_CorrectSequence(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
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
}
