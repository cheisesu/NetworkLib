import Foundation
import Network

extension IPv4Address {
    /// The canonical presentation string for this IPv4 address.
    ///
    /// For example, display a parsed IPv4 address:
    ///
    /// ```swift
    /// if let address = "192.0.2.1".asIPv4 {
    ///     print(address.asString)
    /// }
    /// ```
    public var asString: String {
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        let cIpString = rawValue.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            bytes.withMemoryRebound(to: in_addr.self) {
                return inet_ntop(AF_INET, $0.baseAddress, &buffer, socklen_t(INET_ADDRSTRLEN))
            }
        }!
        return String(cString: cIpString)
    }
}

extension IPv6Address {
    /// The canonical presentation string for this IPv6 address, without URL host brackets.
    public var asString: String {
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        let cIpString = rawValue.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            bytes.withMemoryRebound(to: in6_addr.self) {
                return inet_ntop(AF_INET6, $0.baseAddress, &buffer, socklen_t(INET6_ADDRSTRLEN))
            }
        }!
        return String(cString: cIpString)
    }
    
    /// The IPv6 address formatted for use as a URL host, including square brackets.
    ///
    /// For example, use the formatted value in a `Host` header or URL authority:
    ///
    /// ```swift
    /// if let address = "2001:db8::1".asIPv6 {
    ///     print(address.asURLHostString)
    /// }
    /// ```
    public var asURLHostString: String {
        ["[", asString, "]"].joined()
    }
}
