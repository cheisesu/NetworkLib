import Foundation
import Testing
import Network
@testable import NetworkLib

struct RawSocketAsyncSendMessageTests {
    private struct _SendMessage: RawSocketSendMessage {
        let context: NWConnection.ContentContext
        let content: Data?

        init(context: NWConnection.ContentContext = .defaultMessage, content: Data?) {
            self.context = context
            self.content = content
        }
    }

    @Test(.tags(.RawSocket.sendMessage, .RawSocket.all), .timeLimit(.minutes(1)), arguments: [RawSocketTransport.tcp, .udp])
    func onSuccess(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        try await socket.connect()
        try await socket.sendMessage(message)
        try #require(underlyingConnection.sendDataFull == data)
        try #require(underlyingConnection.sendContext.identifier == context.identifier)
        try #require(underlyingConnection.sendContext.isFinal == context.isFinal)
    }

    @Test(.tags(.RawSocket.sendMessage, .RawSocket.all), .timeLimit(.minutes(1)), arguments: [RawSocketTransport.tcp, .udp])
    func onError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let expectedError = NWError.posix(.EINVAL)
        let underlyingConnection = NWConnectionMock(overridedSendError: expectedError)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            try await socket.connect()
            try await socket.sendMessage(message)
            Issue.record("Unexpected entrance")
        } catch let error where error == expectedError {
        }
    }

    @Test(.tags(.RawSocket.sendMessage, .RawSocket.all), .timeLimit(.minutes(1)), arguments: [RawSocketTransport.tcp, .udp])
    func whenTaskCancelled_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock(mode: [.methodSend, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            try await socket.connect()
            let task = Task {
                try await socket.sendMessage(message)
            }
            task.cancel()
            _ = try await task.value
        } catch NWError.posix(.ECANCELED) {
        }
    }
}
