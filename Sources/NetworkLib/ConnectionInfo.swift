import Foundation
import Network

/// Information reported when a ``RawSocket`` successfully establishes a connection.
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public struct ConnectionInfo: Sendable, Equatable {
    /// The transport protocol used by the connection.
    public let transport: RawSocketTransport
    /// The remote endpoint that the socket was configured to connect to.
    public let remoteEndpoint: NWEndpoint
    /// The local endpoint selected by the system, when it is available from the current network path.
    public let localEndpoint: NWEndpoint?
    /// The network interface selected by the system, when it is available from the current network path.
    public let interface: NWInterface?
}
