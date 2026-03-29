import Testing
import Network
@testable import NetworkLib

extension Tag {
    @Tag static var ipAddress: Self
}

struct IPAddressTests {
    @Test("Checks if string is IPv4", .tags(.ipAddress), arguments: [
        // valid
        ("0.0.0.0", true),
        ("127.0.0.1", true),
        ("192.168.0.1", true),
        ("255.255.255.255", true),
        ("8.8.8.8", true),
        
        // invalid — out of range
        ("256.0.0.1", false),
        ("192.168.0.256", false),
        ("999.999.999.999", false),

        // valid — wrong format
        ("192.168.0", true),
        
        // invalid — wrong format
        ("192.168.0.1.1", false),
        ("192.168..1", false),
        ("192.168.0.a", false),
        
        // invalid — empty / garbage
        ("", false),
        ("...", false),
        ("abc.def.ghi.jkl", false),
        
        // edge-ish
        ("01.02.03.04", true),
        ("1.1.1.01", true),
        
        // spaces
        (" 192.168.0.1", false),
        ("192.168.0.1 ", false),
        ("192.168. 0.1", false),
    ])
    func isIpV4(_ ip: String, _ expected: Bool) async throws {
        try #require(ip.isIPv4 == expected)
    }
    
    @Test("Checks if string is IPv6", .tags(.ipAddress), arguments: [
        // ===== VALID =====
        ("::1", true),
        ("::", true),
        ("2001:db8::1", true),
        ("fe80::1", true),
        ("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff", true),
        ("2001:0db8:0000:0000:0000:ff00:0042:8329", true),
        ("2001:db8:0:0:0:ff00:42:8329", true),
        ("2001:db8::ff00:42:8329", true),
        ("1::", true),
        ("::1:2:3", true),
        ("1:2:3:4:5:6:7:8", true),
        ("2001:db8:00000::1", true),

        // IPv4-mapped / mixed
        ("::ffff:192.168.0.1", true),
        ("2001:db8::192.168.0.1", true),

        // ===== INVALID =====
        // double ::
        ("2001::db8::1", false),
        ("::ffff::192.168.0.1", false),

        // too many groups
        ("1:2:3:4:5:6:7:8:9", false),
        ("2001:db8:0:0:0:ff00:42:8329:1", false),

        // too few without ::
        ("1:2:3:4:5:6:7", false),
        ("2001:db8:0:0:ff00:42:8329", false),

        // bad hex
        ("2001:db8::gggg", false),
        ("zzzz::1", false),

        // oversized group
        ("12345::", false),

        // wrong format
        ("2001-db8::1", false),
        ("2001.db8::1", false),
        (":2001:db8::1", false),
        ("2001:db8::1:", false),

        // garbage
        ("", false),
        ("not-an-ip", false),
        ("::::", false),

        // spaces
        (" ::1", false),
        ("::1 ", false),
        ("2001: db8::1", false),
    ])
    func isIpV6(_ ip: String, _ expected: Bool) async throws {
        try #require(ip.isIPv6 == expected, "ip \(ip)")
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
    
    @Test(.tags(.ipAddress), arguments: [
        // IPv4 valid
        ("0.0.0.0", "0.0.0.0"),
        ("127.0.0.1", "127.0.0.1"),
        ("192.168.0.1", "192.168.0.1"),
        ("255.255.255.255", "255.255.255.255"),
        ("192.168.0", "192.168.0.0"),
        
        // IPv6 valid, already normalized
        ("::", "::"),
        ("::", "::"),
        ("::1", "::1"),
        ("2001:db8::1", "2001:db8::1"),
        ("fe80::1", "fe80::1"),
        ("1:2:3:4:5:6:7:8", "1:2:3:4:5:6:7:8"),
        ("[fe80::1]", "fe80::1"),
        ("[1:2:3:4:5:6:7:8]", "1:2:3:4:5:6:7:8"),
        
        // IPv6 valid, should normalize
        ("2001:0db8:0000:0000:0000:ff00:0042:8329", "2001:db8::ff00:42:8329"),
        ("2001:db8:0:0:0:ff00:42:8329", "2001:db8::ff00:42:8329"),
        ("0000:0000:0000:0000:0000:0000:0000:0001", "::1"),
        ("0:0:0:0:0:0:0:0", "::"),
        
        // IPv6 with embedded IPv4
        ("::ffff:192.168.0.1", "::ffff:192.168.0.1"),
        
        // invalid
        ("", nil),
        ("abc", nil),
        ("not-an-ip", nil),
        ("256.0.0.1", nil),
        ("192.168.0.1.2", nil),
        ("2001::db8::1", nil),
        ("1:2:3:4:5:6:7", nil),
        ("1:2:3:4:5:6:7:8:9", nil),
        ("2001:db8::gggg", nil),
        ("12345::", nil),
        
        // invalid, but valid when normalized and trimmed
        (" 192.168.0.1", "192.168.0.1"),
        ("192.168.0.1 ", "192.168.0.1"),
        (" ::1", "::1"),
        ("::1 ", "::1"),
        ("[ ::1]", "::1"),
        ("[::1 ]", "::1"),
        (" [::1]", "::1"),
        ("[::1] ", "::1"),
        ("[::1]", "::1"),
    ])
    func normalized(ip: String, expected: String?) throws {
        try #require(ip.normalized == expected)
    }
}
