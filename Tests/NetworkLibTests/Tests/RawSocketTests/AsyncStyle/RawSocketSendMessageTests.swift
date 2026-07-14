import Foundation
import Testing
import Network
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var sendMessage: Tag
}

struct RawSocketSendMessageTests {
    private struct _SendMessage: RawSocketSendMessage {
        let context: NWConnection.ContentContext = .defaultMessage
        let content: Data?
    }

    @Test("When continuation is called multiple times it will fall with fatal error and test fail",
          .tags(.RawSocket.sendMessage),
          arguments: [RawSocketTransport.tcp, .udp], [nil, "localhost"])
    func continuationCalledOnlyOnce(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let message = _SendMessage(content: Data("Hello".utf8))
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.connect()
        try await socket.sendMessage(message)
        await socket.cancel()
    }
    
    @Test("When timeout of socket is reached it throws NWError.posix(.ETIMEDOUT)",
          .tags(.RawSocket.sendMessage),
          arguments: [nil, "localhost"])
    func timeoutThrowsError(_ sni: String?) async throws {
        let transport: RawSocketTransport = .tcp
        let timeout: TimeInterval = 1
        let message = _SendMessage(content: Data(repeating: 0xde, count: 16 * 1024 * 1024))
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        try await withAsyncTimeout(.seconds(2)) {
            try await socket.connect()
            do {
                try await socket.sendMessage(message)
            } catch NWError.posix(.ETIMEDOUT) {
            } catch { throw error }
        }
    }
    
    /// - note: UDP is not applicable here as it can call completion really fast
    @Test("When socket is sending data and called cancel in different thread it throws NWError.posix(.ECANCELED)",
          .tags(.RawSocket.sendMessage),
          arguments: [
            (RawSocketTransport.tcp, Data(repeating: 0xde, count: 16 * 1024 * 1024), nil as String?),
            (RawSocketTransport.tcp, Data(repeating: 0xde, count: 16 * 1024 * 1024), "localhost"),
          ])
    func cancelSeparatelyThrowsError(_ transport: RawSocketTransport, _ dataToSend: Data, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let message = _SendMessage(content: dataToSend)
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        try await withAsyncTimeout(.seconds(3)) {
            try await socket.connect()
            do {
                Task {
                    socket.cancel(nil)
                }
                try await socket.sendMessage(message)
                throw TestError.unexpectedEntrance
            } catch NWError.posix(.ECANCELED) {
            } catch { throw error }
        }
    }
    
    @Test("Cancelled a task during sending",
          .tags(.RawSocket.sendMessage),
          arguments: [
            (RawSocketTransport.tcp, Data(repeating: 0xde, count: 16 * 1024 * 1024), nil as String?),
            (RawSocketTransport.tcp, Data(repeating: 0xde, count: 16 * 1024 * 1024), "localhost"),
            (RawSocketTransport.udp, Data("Hello".utf8), nil),
            (RawSocketTransport.udp, Data("Hello".utf8), "localhost"),
          ])
    func cancelDuringSendThrowsError(_ transport: RawSocketTransport, _ dataToSend: Data, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let message = _SendMessage(content: dataToSend)
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        try await withAsyncTimeout(.seconds(3)) {
            try await socket.connect()
            let task = Task {
                do {
                    try await socket.sendMessage(message)
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
