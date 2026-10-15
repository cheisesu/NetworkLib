import Network
import Testing
@testable import NetworkLib

@Suite(.tags(.core))
struct NWConnectionUnderlyingConnectionTests {
    @Test
    func connectionInfoBeforeConnecting_ReturnsAvailableProperties() {
        let endpoint = NWEndpoint.hostPort(host: "example.com", port: 443)
        let connection = NWConnection(to: endpoint, using: .tcp)

        let info = connection.connectionInfo(with: .tcp)

        #expect(info.transport == .tcp)
        #expect(info.remoteEndpoint == endpoint)
        // TODO: Verify localEndpoint and interface when tests use a real connection that reaches the ready state.
        #expect(info.localEndpoint == nil)
        #expect(info.interface == nil)
    }
}
