import Foundation
import Network

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
extension IPv4Address {
    /// The canonical presentation string for this IPv4 address.
    ///
    /// For example, display a parsed IPv4 address:
    ///
    /// ```swift
    /// if let address = "192.0.2.1".asIPv4 {
    ///     print(address.asString)
    ///     // Prints "192.0.2.1".
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

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
extension IPv6Address {
    /// The canonical presentation string for this IPv6 address, without URL host brackets.
    ///
    /// For example, display a parsed IPv6 address:
    ///
    /// ```swift
    /// if let address = "2001:db8::1".asIPv6 {
    ///     print(address.asString)
    ///     // Prints "2001:db8::1".
    /// }
    /// ```
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
    /// Use this form when an IPv6 literal appears in a URL authority or an HTTP `Host` header. The unbracketed value from
    /// ``asString`` is valid as an address string, but URL hosts require brackets so colons are not confused with port separators.
    ///
    /// For example, compare the raw address with the URL-host representation:
    ///
    /// ```swift
    /// if let address = "2001:db8::1".asIPv6 {
    ///     print(address.asString)
    ///     // Prints "2001:db8::1".
    ///
    ///     print(address.asURLHostString)
    ///     // Prints "[2001:db8::1]".
    /// }
    /// ```
    ///
    /// Use the bracketed output when constructing a host-and-port string:
    ///
    /// ```swift
    /// if let address = "::1".asIPv6 {
    ///     let hostPort = "\(address.asURLHostString):8080"
    ///     print(hostPort)
    ///     // Prints "[::1]:8080".
    /// }
    /// ```
    public var asURLHostString: String {
        ["[", asString, "]"].joined()
    }
}
