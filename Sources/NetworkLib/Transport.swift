import Foundation

/// The transport protocol used by a ``RawSocket`` connection.
public enum RawSocketTransport: Sendable {
    /// Transmission Control Protocol.
    case tcp

    /// User Datagram Protocol.
    case udp
}
