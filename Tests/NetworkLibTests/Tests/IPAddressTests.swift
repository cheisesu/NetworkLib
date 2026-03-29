import Testing
import Network
@testable import NetworkLib

extension Tag {
    @Tag static var ipAddress: Self
}

struct IPAddressTests {
    @Test("IPv4 string converting", .tags(.ipAddress), arguments: [
        // ===== VALID =====
        ("0.0.0.0", IPv4Address("0.0.0.0")),
        ("127.0.0.1", IPv4Address("127.0.0.1")),
        ("192.168.0.1", IPv4Address("192.168.0.1")),
        ("255.255.255.255", IPv4Address("255.255.255.255")),
        ("8.8.8.8", IPv4Address("8.8.8.8")),
        ("192.168.0", IPv4Address("192.168.0.0")),
        ("01.02.03.04", IPv4Address("1.2.3.4")),
        ("1.1.1.01", IPv4Address("1.1.1.1")),
        (" 192.168.0.1", IPv4Address("192.168.0.1")),
        ("192.168.0.1 ", IPv4Address("192.168.0.1")),
        (" 192.168.0.1 ", IPv4Address("192.168.0.1")),
        // ===== INVALID =====
        ("192.168.0.1.1", nil),
        ("192.168..1", nil),
        ("192.168.0.a", nil),
        ("256.0.0.1", nil),
        ("192.168.0.256", nil),
        ("999.999.999.999", nil),
        ("", nil),
        ("...", nil),
        ("abc.def.ghi.jkl", nil),
        ("192.168. 0.1", nil),
    ])
    func asIpV4(_ ip: String, _ expected: IPv4Address?) throws {
        try #require(ip.asIPv4 == expected)
        try #require(ip.isIPv4 == (expected != nil))
    }
    
    @Test("IPv6 string converting", .tags(.ipAddress), arguments: [
        // ===== VALID =====
        ("::1", IPv6Address("::1")),
        ("::", IPv6Address("::")),
        ("2001:db8::1", IPv6Address("2001:db8::1")),
        ("fe80::1", IPv6Address("fe80::1")),
        ("[fe80::1]", IPv6Address("fe80::1")),
        ("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff", IPv6Address("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff")),
        ("2001:0db8:0000:0000:0000:ff00:0042:8329", IPv6Address("2001:0db8:0000:0000:0000:ff00:0042:8329")),
        ("2001:db8:0:0:0:ff00:42:8329", IPv6Address("2001:db8:0:0:0:ff00:42:8329")),
        ("2001:db8::ff00:42:8329", IPv6Address("2001:db8::ff00:42:8329")),
        ("1::", IPv6Address("1::")),
        ("::1:2:3", IPv6Address("::1:2:3")),
        ("1:2:3:4:5:6:7:8", IPv6Address("1:2:3:4:5:6:7:8")),
        ("2001:db8:00000::1", IPv6Address("2001:db8:00000::1")),
        ("::ffff:192.168.0.1", IPv6Address("::ffff:192.168.0.1")),
        ("2001:db8::192.168.0.1", IPv6Address("2001:db8::192.168.0.1")),
        ("[2001:db8::192.168.0.1]", IPv6Address("2001:db8::192.168.0.1")),
        (" ::1", IPv6Address("::1")),
        ("::1 ", IPv6Address("::1")),
        (" [::1]", IPv6Address("::1")),
        ("[::1] ", IPv6Address("::1")),
        ("[ ::1]", IPv6Address("::1")),
        ("[::1 ]", IPv6Address("::1")),
        ("[::1 ] ", IPv6Address("::1")),
        (" [::1 ]", IPv6Address("::1")),
        (" [ ::1 ] ", IPv6Address("::1")),
        // ===== INVALID =====
        ("2001::db8::1", nil),
        ("::ffff::192.168.0.1", nil),
        ("1:2:3:4:5:6:7:8:9", nil),
        ("2001:db8:0:0:0:ff00:42:8329:1", nil),
        ("1:2:3:4:5:6:7", nil),
        ("2001:db8:0:0:ff00:42:8329", nil),
        ("2001:db8::gggg", nil),
        ("zzzz::1", nil),
        ("12345::", nil),
        ("2001-db8::1", nil),
        ("2001.db8::1", nil),
        (":2001:db8::1", nil),
        ("2001:db8::1:", nil),
        ("", nil),
        ("not-an-ip", nil),
        ("::::", nil),
        ("2001: db8::1", nil),
    ])
    func asIpV4(_ ip: String, _ expected: IPv6Address?) throws {
        try #require(ip.asIPv6 == expected)
        try #require(ip.isIPv6 == (expected != nil))
    }
    
    @Test(.tags(.ipAddress), arguments: [
        // valid
        ("0.0.0.0", "0.0.0.0"),
        ("127.0.0.1", "127.0.0.1"),
        ("192.168.0.1", "192.168.0.1"),
        ("255.255.255.255", "255.255.255.255"),
        ("8.8.8.8", "8.8.8.8"),
        ("192.168.0", "192.168.0.0"),
        
        // valid, but normalized by parser
        ("001.002.003.004", "1.2.3.4"),
        ("192.168.001.010", "192.168.1.10"),
        
        // invalid
        ("", nil),
        ("abc", nil),
        ("256.0.0.1", nil),
        ("192.168.0.1.2", nil),
        ("192.168..1", nil),
        (" 192.168.0.1", nil),
        ("192.168.0.1 ", nil),
    ])
    func ipV4AsString(ip: String, expected: String?) throws {
        try #require(IPv4Address(ip)?.asString == expected)
    }
    
    @Test(.tags(.ipAddress), arguments: [
        // ===== VALID (canonical stays same) =====
        ("::1", "::1"),
        ("::", "::"),
        ("2001:db8::1", "2001:db8::1"),
        ("fe80::1", "fe80::1"),
        ("1:2:3:4:5:6:7:8", "1:2:3:4:5:6:7:8"),
        
        // ===== VALID (will be normalized) =====
        ("2001:0db8:0000:0000:0000:ff00:0042:8329", "2001:db8::ff00:42:8329"),
        ("2001:db8:0:0:0:ff00:42:8329", "2001:db8::ff00:42:8329"),
        ("0000:0000:0000:0000:0000:0000:0000:0001", "::1"),
        ("0:0:0:0:0:0:0:0", "::"),
        
        // ===== VALID (IPv4-mapped) =====
        ("::ffff:192.168.0.1", "::ffff:192.168.0.1"),
        
        // ===== EDGE (если Apple проглотит — нормализует) =====
        ("2001:db8:00000::1", "2001:db8::1"), // см. обсуждение выше
        
        // ===== INVALID =====
        ("", nil),
        ("not-an-ip", nil),
        ("::::", nil),
        ("2001::db8::1", nil),
        ("1:2:3:4:5:6:7", nil),
        ("1:2:3:4:5:6:7:8:9", nil),
        ("2001:db8::gggg", nil),
        ("12345::", nil),
        ("2001-db8::1", nil),
        (" 2001:db8::1", nil),
        ("2001:db8::1 ", nil),
    ])
    func ipV6AsString(ip: String, expected: String?) throws {
        try #require(IPv6Address(ip)?.asString == expected)
    }
    
    @Test("IPv6 url format", .tags(.ipAddress), arguments: [
        ("::1", "[::1]"),
        ("::", "[::]"),
        ("2001:db8::1", "[2001:db8::1]"),
        ("2001:0db8:0000:0000:0000:ff00:0042:8329", "[2001:db8::ff00:42:8329]"),
        (" ::1", "[::1]"),
        ("::1 ", "[::1]"),
        (" [::1]", "[::1]"),
        ("[::1] ", "[::1]"),
        ("[ ::1]", "[::1]"),
        ("[::1 ]", "[::1]"),
        ("[::1 ] ", "[::1]"),
        (" [::1 ]", "[::1]"),
        (" [ ::1 ] ", "[::1]"),
    ])
    func asURLHostString(_ ip: String, _ expected: String) throws {
        let ip = try #require(ip.asIPv6)
        try #require(ip.asURLHostString == expected)
    }
}
