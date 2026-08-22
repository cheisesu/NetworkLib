import Foundation
import Testing
import Network
@testable import NetworkLib

@Suite(.tags(.RawSocket.cancel, .RawSocket.all), .timeLimit(.minutes(1)))
struct RawSocketAsyncCancelTests {
    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func onSuccess(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        try await socket.connect()
        await socket.cancel()
        do {
            try await socket.connect()
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func multipleCancels_AllComplete(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        try await socket.connect()
        async let cancel1 = socket.cancel()
        async let cancel2 = socket.cancel()
        _ = await [cancel1, cancel2]
        do {
            try await socket.connect()
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }
}
