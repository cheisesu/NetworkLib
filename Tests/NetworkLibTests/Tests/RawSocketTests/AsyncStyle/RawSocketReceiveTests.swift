import Foundation
import Testing
import Network
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var receive: Tag
}

struct RawSocketReceiveTests {
    @Test("When continuation is called multiple times it will fall with fatal error and test fail",
          .tags(.RawSocket.receive),
          arguments: [RawSocketTransport.tcp, .udp], [nil, "localhost"])
    func continuationCalledOnlyOnce(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: sni != nil, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.connect()
        try await socket.send(dataToSend)
        let received = try await socket.receiveNext()
        await socket.cancel()
        try #require(received == dataToSend)
    }
    
    @Test("When timeout of socket is reached it throws NWError.posix(.ETIMEDOUT)",
          .tags(.RawSocket.receive),
          arguments: [RawSocketTransport.tcp, .udp], [nil, "localhost"])
    func timeoutThrowsError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 1
        let dataToSend: Data = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: sni != nil, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        try await withAsyncTimeout(.seconds(2)) {
            try await socket.connect()
            try await socket.send(dataToSend)
            do {
                _ = try await socket.receiveNext()
                throw TestError.unexpectedEntrance
            } catch NWError.posix(.ETIMEDOUT) {
            } catch { throw error }
        }
    }
    
    @Test("When socket is receiving data and called cancel in different thread result is nil",
          .tags(.RawSocket.receive),
          arguments: [RawSocketTransport.tcp, .udp], [nil, "localhost"])
    func cancelSeparatelyThrowsError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let dataToSend: Data = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: sni != nil, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        try await withAsyncTimeout(.seconds(3)) {
            try await socket.connect()
            try await socket.send(dataToSend)
            _ = Task {
                try await Task.sleep(for: .milliseconds(200))
                socket.cancel(nil)
            }
            let received = try await socket.receiveNext()
            try #require(received == nil)
        }
    }
    
    @Test("Cancelled a task during receiving",
          .tags(.RawSocket.receive),
          arguments: [RawSocketTransport.tcp, .udp], [nil, "localhost"])
    func cancelDuringSendThrowsError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let dataToSend: Data = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        
        try await withAsyncTimeout(.seconds(3)) {
            try await socket.connect()
            try await socket.send(dataToSend)
            let task = Task {
                do {
                    _ = try await socket.receiveNext()
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
