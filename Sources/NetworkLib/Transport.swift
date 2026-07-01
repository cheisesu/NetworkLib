import Foundation

/// The transport protocol used by a ``RawSocket`` connection.
///
/// For example, pass `.udp` when configuring a datagram socket:
///
/// ```swift
/// let configuration = RawSocketConfiguration("example.com", 443, transport: .udp)
/// ```
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public enum RawSocketTransport: Sendable {
    /// Transmission Control Protocol.
    case tcp

    /// User Datagram Protocol.
    case udp
}
