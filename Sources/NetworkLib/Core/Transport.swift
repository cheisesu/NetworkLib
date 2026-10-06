import Foundation

/// The transport protocol used by a ``RawSocket`` connection.
///
/// Security is configured separately by ``RawSocketConfiguration/isSecure``: TCP uses TLS and UDP uses DTLS when security is
/// enabled.
///
/// For example, pass `.udp` when configuring a datagram socket:
///
/// ```swift
/// let configuration = RawSocketConfiguration("example.com", 443, transport: .udp)
/// ```
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public enum RawSocketTransport: Sendable {
    /// Transmission Control Protocol, which provides an ordered byte stream.
    case tcp

    /// User Datagram Protocol, which preserves datagram message boundaries.
    case udp
}
