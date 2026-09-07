import Foundation
import Network
import Testing
@testable import NetworkLibUtils

extension Tag.LibUtils {
    @Tag static var endpointHost: Tag
}

@Suite(.tags(.LibUtils.all, .LibUtils.endpointHost))
struct NWEndpointHostTests {
    @Test(arguments: [
        (NWEndpoint.Host.name("example.com", nil), "example.com"),
        (NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!), "127.0.0.1"),
        (NWEndpoint.Host.ipv6(IPv6Address("2001:0db8:85a3:0000:0000:8a2e:0370:7334")!), "2001:db8:85a3::8a2e:370:7334"),
        ("example.com" as NWEndpoint.Host, "example.com"),
        ("127.0.0.1" as NWEndpoint.Host, "127.0.0.1"),
        ("2001:0db8:85a3:0000:0000:8a2e:0370:7334" as NWEndpoint.Host, "2001:db8:85a3::8a2e:370:7334"),
    ])
    func asString(_ host: NWEndpoint.Host, _ expected: String) throws {
        try #require(host.asString == expected)
    }

    @Test(arguments: [
        (NWEndpoint.Host.name("example.com", nil), "example.com"),
        (NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!), "127.0.0.1"),
        (NWEndpoint.Host.ipv6(IPv6Address("2001:0db8:85a3:0000:0000:8a2e:0370:7334")!), "[2001:db8:85a3::8a2e:370:7334]"),
        ("example.com" as NWEndpoint.Host, "example.com"),
        ("127.0.0.1" as NWEndpoint.Host, "127.0.0.1"),
        ("2001:0db8:85a3:0000:0000:8a2e:0370:7334" as NWEndpoint.Host, "[2001:db8:85a3::8a2e:370:7334]"),
    ])
    func asUrlString(_ host: NWEndpoint.Host, _ expected: String) throws {
        try #require(host.asUrlString == expected)
    }

    @Test(arguments: [
        (NWEndpoint.Host.name("example.com", nil), false),
        (NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!), true),
        (NWEndpoint.Host.ipv6(IPv6Address("2001:0db8:85a3:0000:0000:8a2e:0370:7334")!), true),
        ("example.com" as NWEndpoint.Host, false),
        ("127.0.0.1" as NWEndpoint.Host, true),
        ("2001:0db8:85a3:0000:0000:8a2e:0370:7334" as NWEndpoint.Host, true),
    ])
    func isIpAddress(_ host: NWEndpoint.Host, _ expected: Bool) throws {
        try #require(host.isIPAddress == expected)
    }
}
