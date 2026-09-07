import Foundation
import Network

extension NWEndpoint.Host {
    /// A textual representation of the host without URL-specific delimiters.
    ///
    /// Named hosts are returned unchanged, while IPv4 and IPv6 addresses use their canonical string representations.
    public var asString: String {
        switch self {
        case let .name(name, _): return name
        case let .ipv4(address): return address.asString
        case let .ipv6(address): return address.asString
        @unknown default: return "\(self)"
        }
    }

    /// A textual representation suitable for use as the host component of a URL or HTTP request target.
    ///
    /// IPv6 addresses are enclosed in square brackets to keep their colons distinct from a port separator.
    /// Named hosts and IPv4 addresses are returned without additional delimiters.
    public var asUrlString: String {
        switch self {
        case let .name(name, _): return name
        case let .ipv4(address): return address.asString
        case let .ipv6(address): return address.asURLHostString
        @unknown default: return "\(self)"
        }
    }

    /// A Boolean value that indicates whether the host is an IPv4 or IPv6 address.
    ///
    /// This property is `false` for named hosts.
    public var isIPAddress: Bool {
        switch self {
        case .ipv4, .ipv6: return true
        default: return false
        }
    }
}
