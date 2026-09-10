import Foundation
import Testing
import Network
@testable import NetworkLibCore

@Suite(.tags(.core, .RawSocket.send, .RawSocket.all), .timeLimit(.minutes(1)))
struct RawSocketAsyncSendTests {
    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func onSuccess(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("hello".utf8)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        try await socket.connect()
        try await socket.send(data)
        try #require(underlyingConnection.sendDataFull == data)
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func onError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let expectedError = NWError.posix(.EINVAL)
        let data = Data("hello".utf8)
        let underlyingConnection = NWConnectionMock(overridedSendError: expectedError)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            try await socket.connect()
            try await socket.send(data)
            Issue.record("Unexpected entrance")
        } catch let error where error == expectedError {
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenTaskCancelled_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("hello".utf8)
        let underlyingConnection = NWConnectionMock(mode: [.methodSend, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            try await socket.connect()
            let task = Task {
                try await socket.send(data)
            }
            task.cancel()
            _ = try await task.value
        } catch NWError.posix(.ECANCELED) {
        }
    }
}
