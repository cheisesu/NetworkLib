import Foundation
import Testing
import Network
@testable import NetworkLib

struct RawSocketReceiveTests {
    @Test("When continuation is called multiple times it will fall with fatal error and test fail",
          .tags(.RawSocketConnect.connect),
          arguments: [NetTransport.tcp, .udp], [nil, "localhost"])
    func continuationCalledOnlyOnce(_ transport: NetTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: sni != nil, flow: .echo)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: sni)
        defer { socket.cancel(nil) }
        try await socket.connect()
        try await socket.send(dataToSend)
        let received = try await socket.receiveNext()
        await socket.cancel()
        try #require(received == dataToSend)
    }
    
    @Test("When timeout of socket is reached it throws NWError.posix(.ETIMEDOUT)",
          .tags(.RawSocketConnect.connect),
          arguments: [NetTransport.tcp, .udp], [nil, "localhost"])
    func timeoutThrowsError(_ transport: NetTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0.7
        let dataToSend: Data = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: sni != nil, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: sni)
        defer { socket.cancel(nil) }

        try await withAsyncTimeout(.seconds(2)) {
            try await socket.connect()
            try await socket.send(dataToSend)
            do {
                _ = try await socket.receiveNext()
            } catch NWError.posix(.ETIMEDOUT) {
            } catch { throw error }
        }
    }
    
    @Test("When socket is receiving data and called cancel in different thread result is nil",
          .tags(.RawSocketConnect.connect),
          arguments: [NetTransport.tcp, .udp], [nil, "localhost"])
    func cancelSeparatelyThrowsError(_ transport: NetTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let dataToSend: Data = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: sni != nil, flow: .none)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: sni)
        defer { socket.cancel(nil) }

        try await withAsyncTimeout(.seconds(3)) {
            try await socket.connect()
            try await socket.send(dataToSend)
            Task {
                try await Task.sleep(for: .milliseconds(200))
                socket.cancel(nil)
            }
            let received = try await socket.receiveNext()
            try #require(received == nil)
        }
    }
    
    @Test("Cancelled a task during receiving",
          .tags(.RawSocketConnect.connect),
          arguments: [NetTransport.tcp, .udp], [nil, "localhost"])
    func cancelDuringSendThrowsError(_ transport: NetTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let dataToSend: Data = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: sni)
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
