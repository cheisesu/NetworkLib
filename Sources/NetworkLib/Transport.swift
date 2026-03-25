import Foundation

/// Protocol of transport layer used in ``RawSocket``
public enum RawSocketTransport: Sendable {
    /// TCP protocol
    case tcp
    /// UDP protocol
    case udp
}
