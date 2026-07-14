import Foundation
import Testing
import Network
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var cancel: Tag
}

struct RawSocketCancelTests {
    @Test("When continuation is called multiple times it will fall with fatal error and test fail",
          .tags(.RawSocket.cancel), arguments: [RawSocketTransport.tcp, .udp], [nil, "localhost"])
    func continuationCalledOnlyOnce(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        await socket.cancel()
        _ = try? await socket.connect()
    }
    
    @Test("When cancel, socket closes",
          .tags(.RawSocket.cancel), arguments: [RawSocketTransport.tcp, .udp], [nil, "localhost"])
    func cancelCancelsOperation(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: sni != nil)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: sni != nil, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        await socket.cancel()
        do {
            try await socket.connect()
            throw TestError.unexpectedEntrance
        } catch NWError.posix(.ECANCELED) {
        } catch { throw error }
    }
}
