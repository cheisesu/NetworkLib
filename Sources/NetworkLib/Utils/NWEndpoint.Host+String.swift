import Foundation
import Network

extension NWEndpoint.Host {
    var asString: String {
        switch self {
        case let .name(name, _): return name
        case let .ipv4(address): return address.asString
        case let .ipv6(address): return address.asString
        @unknown default: return "\(self)"
        }
    }

    var asUrlString: String {
        switch self {
        case let .name(name, _): return name
        case let .ipv4(address): return address.asString
        case let .ipv6(address): return address.asURLHostString
        @unknown default: return "\(self)"
        }
    }

    var isIPAddress: Bool {
        switch self {
        case .ipv4, .ipv6: return true
        default: return false
        }
    }
}
