import Foundation
import Network

extension String {
    /// An IPv4 address parsed from this string after trimming whitespace, newlines, and URL host brackets.
    public var asIPv4: IPv4Address? {
        let trimmed = trimmingCharacters(in: Self.trimmingSet)
        return IPv4Address(trimmed)
    }
    
    /// An IPv6 address parsed from this string after trimming whitespace, newlines, and URL host brackets.
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
