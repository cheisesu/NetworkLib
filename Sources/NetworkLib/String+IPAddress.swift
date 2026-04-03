import Foundation
import Network

extension String {
    public var asIPv4: IPv4Address? {
        let trimmed = trimmingCharacters(in: Self.trimmingSet)
        return IPv4Address(trimmed)
    }
    
    public var asIPv6: IPv6Address? {
        let trimmed = trimmingCharacters(in: Self.trimmingSet)
        return IPv6Address(trimmed)
    }
    
    public var isIPv4: Bool {
        asIPv4 != nil
    }

    public var isIPv6: Bool {
        asIPv6 != nil
    }

    private static let trimmingSet: CharacterSet = .whitespacesAndNewlines.union(CharacterSet(charactersIn: "[]"))
}
