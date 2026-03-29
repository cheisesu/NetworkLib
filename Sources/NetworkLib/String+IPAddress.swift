import Foundation
import Network

extension String {
    public var isIPv4: Bool {
        IPv4Address(self) != nil
    }

    public var isIPv6: Bool {
        IPv6Address(self) != nil
    }

    public var normalized: String? {
        let str = trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "[]")))
        if let v4 = IPv4Address(str) {
            return v4.asString
        } else if let v6 = IPv6Address(str) {
            return v6.asString
        }
        return nil
    }
}
