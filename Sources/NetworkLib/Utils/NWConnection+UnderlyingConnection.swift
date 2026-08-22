import Foundation
import Network

extension NWConnection: UnderlyingConnection {
    func connectionInfo(with transport: RawSocketTransport) -> ConnectionInfo {
        return ConnectionInfo(transport: transport, remoteEndpoint: endpoint,
                              localEndpoint: currentPath?.localEndpoint,
                              interface: currentPath?.availableInterfaces.first)
    }
}
