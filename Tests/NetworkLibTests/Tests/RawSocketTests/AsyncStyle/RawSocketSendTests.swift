import Foundation
import Testing
import Network
@testable import NetworkLib

struct RawSocketSendTests {
    @Test("When continuation is called multiple times it will fall with fatal error and test fail",
          .tags(.RawSocketConnect.connect),
          arguments: [NetTransport.tcp, .udp], [nil, "localhost"])
    func continuationCalledOnlyOnce(_ transport: NetTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: sni)
        defer { socket.cancel(nil) }
        try await socket.connect()
        try await socket.send(dataToSend)
        await socket.cancel()
    }
    
    @Test("When timeout of socket is reached it throws NWError.posix(.ETIMEDOUT)",
          .tags(.RawSocketConnect.connect),
          arguments: [nil, "localhost"])
    func timeoutThrowsError(_ sni: String?) async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0.5
        let dataToSend = Data(repeating: 0xde, count: 16 * 1024 * 1024)
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: sni)
        defer { socket.cancel(nil) }

        try await withAsyncTimeout(.seconds(2)) {
            try await socket.connect()
            do {
                try await socket.send(dataToSend)
            } catch NWError.posix(.ETIMEDOUT) {
            } catch { throw error }
        }
    }
    
    /// - note: UDP is not applicable here as it can call completion really fast
    @Test("When socket is sending data and called cancel in different thread it throws NWError.posix(.ECANCELED)",
          .tags(.RawSocketConnect.connect),
          arguments: [
            (NetTransport.tcp, Data(repeating: 0xde, count: 16 * 1024 * 1024), nil as String?),
            (NetTransport.tcp, Data(repeating: 0xde, count: 16 * 1024 * 1024), "localhost"),
          ])
    func cancelSeparatelyThrowsError(_ transport: NetTransport, _ dataToSend: Data, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: sni)
        defer { socket.cancel(nil) }

        try await withAsyncTimeout(.seconds(3)) {
            try await socket.connect()
            do {
                Task {
                    socket.cancel(nil)
                }
                try await socket.send(dataToSend)
                throw TestError.unexpectedEntrance
            } catch NWError.posix(.ECANCELED) {
            } catch { throw error }
        }
    }
    
    @Test("Cancelled a task during sending",
          .tags(.RawSocketConnect.connect),
          arguments: [
            (NetTransport.tcp, Data(repeating: 0xde, count: 16 * 1024 * 1024), nil as String?),
            (NetTransport.tcp, Data(repeating: 0xde, count: 16 * 1024 * 1024), "localhost"),
            (NetTransport.udp, Data("Hello".utf8), nil),
            (NetTransport.udp, Data("Hello".utf8), "localhost"),
          ])
    func cancelDuringSendThrowsError(_ transport: NetTransport, _ dataToSend: Data, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: sni)
        defer { socket.cancel(nil) }

        try await withAsyncTimeout(.seconds(3)) {
            try await socket.connect()
            let task = Task {
                do {
                    try await socket.send(dataToSend)
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
