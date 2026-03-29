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
        if let v4 = IPv4Address(self) {
            return v4.asString
        } else if let v6 = IPv6Address(self) {
            return v6.asString
        }
        return nil
    }
}
