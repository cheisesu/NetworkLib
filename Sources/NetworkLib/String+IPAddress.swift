import Foundation
import Network

extension String {
    /// An IPv4 address parsed from this string after trimming whitespace, newlines, and URL host brackets.
    ///
    /// For example, validate user input before creating a socket host:
    ///
    /// ```swift
    /// if let address = "192.0.2.1".asIPv4 {
    ///     let host = NWEndpoint.Host.ipv4(address)
    /// }
    /// ```
    public var asIPv4: IPv4Address? {
        let trimmed = trimmingCharacters(in: Self.trimmingSet)
        return IPv4Address(trimmed)
    }
    
    /// An IPv6 address parsed from this string after trimming whitespace, newlines, and URL host brackets.
    ///
    /// For example, bracketed URL hosts are accepted:
    ///
    /// ```swift
    /// let address = "[2001:db8::1]".asIPv6
    /// ```
    public var asIPv6: IPv6Address? {
        let trimmed = trimmingCharacters(in: Self.trimmingSet)
        return IPv6Address(trimmed)
    }
    
    /// A Boolean value indicating whether this string can be parsed as an IPv4 address.
    public var isIPv4: Bool {
        asIPv4 != nil
    }

    /// A Boolean value indicating whether this string can be parsed as an IPv6 address.
    public var isIPv6: Bool {
        asIPv6 != nil
    }

    private static let trimmingSet: CharacterSet = .whitespacesAndNewlines.union(CharacterSet(charactersIn: "[]"))
}
