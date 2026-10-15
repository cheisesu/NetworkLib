import Foundation
import Network

/// A snapshot of the path and endpoints selected for an established ``RawSocket`` connection.
///
/// NetworkLib creates this value when the underlying Network framework connection enters the ready state. Optional path
/// information can be unavailable when the current path doesn't expose a local endpoint or interface.
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public struct ConnectionInfo: Sendable, Equatable {
    /// The transport protocol used by the socket.
    public let transport: RawSocketTransport

    /// The remote endpoint to which the underlying connection is connected.
    public let remoteEndpoint: NWEndpoint

    /// The local endpoint selected by the system, or `nil` when it isn't available from the current network path.
    public let localEndpoint: NWEndpoint?

    /// The network interface selected by the system, or `nil` when it isn't available from the current network path.
    public let interface: NWInterface?
}
