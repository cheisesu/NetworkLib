import Testing
import Foundation
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var internalState: Tag
}

struct RawSocketInternalStateTests {
    @Test(.tags(.RawSocket.internalState, .rawSocketAll))
    func correctSequenceOfConnectThenCancel() async throws {
        let server = try ServerMock(transport: .tcp, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: false, sni: nil, transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let (sequence, seqContinuation) = AsyncStream.makeStream(of: RawSocket._InternalState.self)
        socket.onInternalStateChange = { oldState, newState in
            seqContinuation.yield(newState)
        }
        let _: Void = try await withAsyncTimeoutCancelationContinuation(.seconds(2)) { continuation in
            socket.connect { _ in
                socket.cancel {
                    seqContinuation.finish()
                    continuation.resume()
                }
            }
        } onCancel: {
            socket.cancel(nil)
            seqContinuation.finish()
        }
        let states = await sequence.reduce(into: []) { partialResult, state in
            partialResult.append(state)
        }
        try #require(states == [.connecting, .connected, .cancelling, .closed])
    }

    @Test(.tags(.RawSocket.internalState, .rawSocketAll))
    func oldStateIsLessThanNewState() async throws {
        let server = try ServerMock(transport: .tcp, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: false, sni: nil, transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let (sequence, seqContinuation) = AsyncStream.makeStream(of: (RawSocket._InternalState, RawSocket._InternalState).self)
        socket.onInternalStateChange = { oldState, newState in
            seqContinuation.yield((oldState, newState))
        }
        let _: Void = try await withAsyncTimeoutCancelationContinuation(.seconds(2)) { continuation in
            socket.connect { _ in
                socket.cancel {
                    seqContinuation.finish()
                    continuation.resume()
                }
            }
        } onCancel: {
            socket.cancel(nil)
            seqContinuation.finish()
        }
        try await #require(sequence.allSatisfy { $0.0 < $0.1 })
    }
}
