import Foundation
import Testing
import Network
@testable import NetworkLib

@Suite(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
struct RawSocketAsyncConnectTests {
    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func onSuccess(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        let info = try await socket.connect()
        try #require(info == underlyingConnection.connectionInfo(with: transport))
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func onError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let expectedError = NWError.posix(.EINVAL)
        let underlyingConnection = NWConnectionMock(overridedStates: [.preparing, .failed(expectedError)])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            try await socket.connect()
            Issue.record("Unexpected entrance")
        } catch let error where error == expectedError {
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenTaskCancelled_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(overridedStates: [.preparing])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let task = Task {
                try await socket.connect()
            }
            await withCheckedContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .connecting else { return }
                    task.cancel()
                    continuation.resume()
                }
            }
            _ = try await task.value
        } catch NWError.posix(.ECANCELED) {
        }
    }
}
