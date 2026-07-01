import Foundation
import Network

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
extension String {
    /// An IPv4 address parsed from this string after trimming whitespace, newlines, and URL host brackets.
    ///
    /// The parser uses the trimmed string directly with `IPv4Address`. Values that are valid IPv6 addresses, host names,
    /// partial IPv4 addresses, or IPv4 addresses with out-of-range octets return `nil`.
    ///
    /// For example, parse plain and padded IPv4 input:
    ///
    /// ```swift
    /// let loopback = "127.0.0.1".asIPv4
    /// let padded = "  192.0.2.1\n".asIPv4
    /// let invalid = "192.0.2.999".asIPv4
    ///
    /// print(loopback != nil) // true
    /// print(padded != nil)   // true
    /// print(invalid == nil)  // true
    /// ```
    ///
    /// Use the parsed address when creating a Network framework host:
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
    /// The parser removes surrounding square brackets before passing the value to `IPv6Address`, which makes URL host strings
    /// such as `[2001:db8::1]` valid input. IPv4 addresses and host names return `nil`.
    ///
    /// For example, parse compressed and bracketed IPv6 input:
    ///
    /// ```swift
    /// let compressed = "2001:db8::1".asIPv6
    /// let bracketed = "[2001:db8::1]".asIPv6
    /// let invalid = "example.com".asIPv6
    ///
    /// print(compressed != nil) // true
    /// print(bracketed != nil)  // true
    /// print(invalid == nil)    // true
    /// ```
    public var asIPv6: IPv6Address? {
        let trimmed = trimmingCharacters(in: Self.trimmingSet)
        return IPv6Address(trimmed)
    }
    
    /// A Boolean value indicating whether this string can be parsed as an IPv4 address.
    ///
    /// This is equivalent to checking whether ``asIPv4`` is non-`nil`. The same trimming rules apply: leading and trailing
    /// whitespace, newlines, and square brackets are ignored before parsing.
    ///
    /// ```swift
    /// "192.0.2.1".isIPv4        // true
    /// " 192.0.2.1 ".isIPv4      // true
    /// "[192.0.2.1]".isIPv4      // true
    /// "2001:db8::1".isIPv4      // false
    /// "example.com".isIPv4      // false
    /// ```
    public var isIPv4: Bool {
        asIPv4 != nil
    }

    /// A Boolean value indicating whether this string can be parsed as an IPv6 address.
    ///
    /// This is equivalent to checking whether ``asIPv6`` is non-`nil`. The same trimming rules apply: leading and trailing
    /// whitespace, newlines, and square brackets are ignored before parsing.
    ///
    /// ```swift
    /// "2001:db8::1".isIPv6      // true
    /// "[2001:db8::1]".isIPv6    // true
    /// " ::1\n".isIPv6           // true
    /// "192.0.2.1".isIPv6        // false
    /// "example.com".isIPv6      // false
    /// ```
    public var isIPv6: Bool {
        asIPv6 != nil
    }

    private static let trimmingSet: CharacterSet = .whitespacesAndNewlines.union(CharacterSet(charactersIn: "[]"))
}
