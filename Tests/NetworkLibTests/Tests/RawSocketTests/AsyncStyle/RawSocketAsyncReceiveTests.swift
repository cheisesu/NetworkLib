import Foundation
import Testing
import Network
@testable import NetworkLib

struct RawSocketAsyncReceiveTests {
    @Test(.tags(.RawSocket.receive, .RawSocket.all), .timeLimit(.minutes(1)), arguments: [RawSocketTransport.tcp, .udp])
    func onSuccess(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let expectedData = Data("hello".utf8)
        let underlyingConnection = NWConnectionMock(dataForReceive: expectedData)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        try await socket.connect()
        let data = try await socket.receiveNext()
        try #require(data == expectedData)
    }

    @Test(.tags(.RawSocket.receive, .RawSocket.all), .timeLimit(.minutes(1)), arguments: [RawSocketTransport.tcp, .udp])
    func onError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let expectedError = NWError.posix(.EINVAL)
        let underlyingConnection = NWConnectionMock(overridedReceiveError: expectedError)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            try await socket.connect()
            _ = try await socket.receiveNext()
            Issue.record("Unexpected entrance")
        } catch let error where error == expectedError {
        }
    }

    @Test(.tags(.RawSocket.receive, .RawSocket.all), .timeLimit(.minutes(1)), arguments: [RawSocketTransport.tcp, .udp])
    func whenTaskCancelled_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(mode: [.methodReceive, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            try await socket.connect()
            let task = Task {
                try await socket.receiveNext()
            }
            task.cancel()
            _ = try await task.value
        } catch NWError.posix(.ECANCELED) {
        }
    }
}
