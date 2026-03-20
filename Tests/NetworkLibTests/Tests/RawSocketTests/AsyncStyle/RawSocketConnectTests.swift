import Foundation
import Testing
import Network
@testable import NetworkLib

extension Tag {
    enum RawSocketConnect {
        @Tag static var connect: Tag
    }
}

struct RawSocketConnectTests {
    @Test("When continuation is called multiple times it will fall with fatal error and test fail",
          .tags(.RawSocketConnect.connect), arguments: [NetTransport.tcp, .udp], [nil, "localhost"])
    func continuationCalledOnlyOnce(_ transport: NetTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: sni)
        defer { socket.cancel(nil) }
        try await socket.connect()
        await socket.cancel()
    }
    
    @Test("When timeout of socket is reached it throws NWError.posix(.ETIMEDOUT)",
          .tags(.RawSocketConnect.connect), arguments: [NetTransport.tcp, .udp])
    func timeoutThrowsError(_ transport: NetTransport) async throws {
        let timeout: TimeInterval = 0.2
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel(nil) }

        try await withAsyncTimeout(.seconds(3)) {
            do {
                try await socket.connect()
            } catch NWError.posix(.ETIMEDOUT) {
            } catch { throw error }
        }
    }
    
    @Test("When socket is connecting and called cancel in different thread it throws NWError.posix(.ECANCELED)",
          .tags(.RawSocketConnect.connect), arguments: [NetTransport.tcp, .udp])
    func cancelSeparatelyThrowsError(_ transport: NetTransport) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel(nil) }

        try await withAsyncTimeout(.seconds(3)) {
            do {
                Task {
                    socket.cancel(nil)
                }
                try await socket.connect()
                throw TestError.unexpectedEntrance
            } catch NWError.posix(.ECANCELED) {
            } catch { throw error }
        }
    }
    
    @Test("Cancelled a task during connect",
          .tags(.RawSocketConnect.connect), arguments: [NetTransport.tcp, .udp])
    func cancelDuringConnectThrowsError(_ transport: NetTransport) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel(nil) }

        try await withAsyncTimeout(.seconds(3)) {
            let task = Task {
                do {
                    try await socket.connect()
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
