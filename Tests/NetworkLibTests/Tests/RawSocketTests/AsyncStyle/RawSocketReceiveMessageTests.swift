import Foundation
import Testing
import Network
@testable import NetworkLib

extension Tag.RawSocketConnect {
    @Tag static var receiveMessage: Tag
}

struct RawSocketReceiveMessageTests {
    private struct _ReceiveMessage: RawSocketReceiveMessage {
        let data: Data?
        init?(from context: NWConnection.ContentContext, with content: Data?) {
            data = content
        }
    }

    @Test("When continuation is called multiple times it will fall with fatal error and test fail",
          .tags(.RawSocketConnect.receiveMessage), arguments: [nil, "localhost"])
    func continuationCalledOnlyOnce(_ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: .udp, isSecure: sni != nil, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: .udp,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.connect()
        try await socket.send(dataToSend)
        let received = try await socket.receiveNextMessage() as _ReceiveMessage
        await socket.cancel()
        try #require(received.data == dataToSend)
    }
    
    @Test("When timeout of socket is reached it throws NWError.posix(.ETIMEDOUT)",
          .tags(.RawSocketConnect.receiveMessage), arguments: [nil, "localhost"])
    func timeoutThrowsError(_ sni: String?) async throws {
        let timeout: TimeInterval = 1
        let dataToSend: Data = Data("Hello".utf8)
        let server = try ServerMock(transport: .udp, isSecure: sni != nil, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: .udp,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        try await withAsyncTimeout(.seconds(2)) {
            try await socket.connect()
            try await socket.send(dataToSend)
            do {
                _ = try await socket.receiveNextMessage() as _ReceiveMessage
                throw TestError.unexpectedEntrance
            } catch NWError.posix(.ETIMEDOUT) {
            } catch { throw error }
        }
    }
    
    @Test("When socket is receiving data and called cancel in different thread result is nil",
          .tags(.RawSocketConnect.receiveMessage), arguments: [nil, "localhost"])
    func cancelSeparatelyThrowsError(_ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let dataToSend: Data = Data("Hello".utf8)
        let server = try ServerMock(transport: .udp, isSecure: sni != nil, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: .udp,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        try await withAsyncTimeout(.seconds(3)) {
            try await socket.connect()
            try await socket.send(dataToSend)
            Task {
                try await Task.sleep(for: .milliseconds(200))
                socket.cancel(nil)
            }
            let received = try await socket.receiveNextMessage() as _ReceiveMessage
            try #require(received.data == nil)
        }
    }
    
    @Test("Cancelled a task during receiving",
          .tags(.RawSocketConnect.receiveMessage), arguments: [nil, "localhost"])
    func cancelDuringSendThrowsError(_ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let dataToSend: Data = Data("Hello".utf8)
        let server = try ServerMock(transport: .udp, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: .udp,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        try await withAsyncTimeout(.seconds(3)) {
            try await socket.connect()
            try await socket.send(dataToSend)
            let task = Task {
                do {
                    _ = try await socket.receiveNextMessage() as _ReceiveMessage
                    throw TestError.unexpectedEntrance
                } catch NWError.posix(.ECANCELED) {
                } catch { throw error }
            }
            task.cancel()
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        }
    }
}
