import Foundation
import Network

extension IPv4Address {
    var asString: String {
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
    var asString: String {
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        let cIpString = rawValue.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            bytes.withMemoryRebound(to: in6_addr.self) {
                return inet_ntop(AF_INET6, $0.baseAddress, &buffer, socklen_t(INET6_ADDRSTRLEN))
            }
        }!
        return String(cString: cIpString)
    }
}
