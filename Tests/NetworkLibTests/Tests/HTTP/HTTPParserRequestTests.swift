import Testing
import Foundation
import Network
@testable import NetworkLib

extension Tag {
    @Tag static var httpParser: Self
}

struct HTTPParserRequestTests {
    @Test(.tags(.httpParser), arguments: [
        (nil as String?, "GET", HTTPVersion.v1_0),
        ("_GET", "_GET", HTTPVersion.v1_0),
        (nil as String?, "GET", HTTPVersion.v1_1),
        ("_GET", "_GET", HTTPVersion.v1_1),
    ])
    func shortestRequest_Correct(_ method: String?, _ expectedMethod: String, _ version: HTTPVersion) throws {
        let url = try #require(URL(string: "http://localhost/path1?q1=query1"))
        var request = URLRequest(url: url)
        request.httpMethod = method
        let expectedLines = [
            "\(expectedMethod) /path1?q1=query1 HTTP/\(version.rawValue)",
            "Connection: close",
            version == .v1_1 ? "Host: localhost" : nil,
            "",
            ""
        ]
        let expectedData = Data(expectedLines.compactMap { $0 }.joined(separator: "\r\n").utf8)
        let parsed = HTTPRequestParser(request, version: version)
        try #require(parsed.parsedData == expectedData)
    }
    
    @Test(.tags(.httpParser), arguments: [
        (nil as String?, "GET", HTTPVersion.v1_0),
        ("_GET", "_GET", HTTPVersion.v1_0),
        (nil as String?, "GET", HTTPVersion.v1_1),
        ("_GET", "_GET", HTTPVersion.v1_1),
    ])
    func withHeaders_Correct(_ method: String?, _ expectedMethod: String, _ version: HTTPVersion) throws {
        let headers: [(String, String)] = [
            ("Header1", "Lorem ¡psum"),
            version == .v1_1 ? ("Host", "localhost") : nil,
            ("DateTime", "\(Date())"),
            ("Connection", "close"),
        ]
            .compactMap { $0 }
            .sorted(by: { $0.0 < $1.0 })
        let url = try #require(URL(string: "http://localhost/path1?q1=query1"))
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        var expectedStrings = ["\(expectedMethod) /path1?q1=query1 HTTP/\(version.rawValue)"]
        for (key, value) in headers {
            expectedStrings.append("\(key): \(value)")
        }
        expectedStrings.append("")
        expectedStrings.append("")
        let expectedData = Data(expectedStrings.joined(separator: "\r\n").utf8)
        let parsed = HTTPRequestParser(request, version: version)
        try #require(parsed.parsedData == expectedData)
    }
    
    @Test(.tags(.httpParser), arguments: [
        (nil as String?, "GET", HTTPVersion.v1_0),
        ("_GET", "_GET", HTTPVersion.v1_0),
        (nil as String?, "GET", HTTPVersion.v1_1),
        ("_GET", "_GET", HTTPVersion.v1_1),
    ])
    func withBodyOnly_Correct(_ method: String?, _ expectedMethod: String, _ version: HTTPVersion) throws {
        let body = Data("Lorem ipsum\nindepidsum!".utf8)
        let url = try #require(URL(string: "http://localhost/path1?q1=query1"))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        
        let headerStrings = [
            "\(expectedMethod) /path1?q1=query1 HTTP/\(version.rawValue)",
            "Connection: close",
            ["Content-Length", String(body.count)].joined(separator: ": "),
            version == .v1_1 ? "Host: localhost" : nil,
            "",
            "",
        ].compactMap { $0 }
        let headerData = Data(headerStrings.joined(separator: "\r\n").utf8)
        let expectedData = Data(headerData + body)
        let parsed = HTTPRequestParser(request, version: version)
        try #require(parsed.parsedData == expectedData)
    }
    
    @Test(.tags(.httpParser), arguments: [
        (nil as String?, "GET", HTTPVersion.v1_0),
        ("_GET", "_GET", HTTPVersion.v1_0),
        (nil as String?, "GET", HTTPVersion.v1_1),
        ("_GET", "_GET", HTTPVersion.v1_1),
    ])
    func withHeadersAndBody_Correct(_ method: String?, _ expectedMethod: String, _ version: HTTPVersion) throws {
        let body = Data("Lorem ipsum\nindepidsum!".utf8)
        let headers: [(String, String)] = [
            ("Header1", "Lorem ¡psum"),
            ("DateTime", "\(Date())"),
            ("Content-Length", String(body.count)),
            version == .v1_1 ? ("Host", "localhost") : nil,
            ("Connection", "close"),
        ]
            .compactMap { $0 }
            .sorted(by: { $0.0 < $1.0 })
        let url = try #require(URL(string: "http://localhost/path1?q1=query1"))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        var headerStrings = ["\(expectedMethod) /path1?q1=query1 HTTP/\(version.rawValue)"]
        for (key, value) in headers {
            headerStrings.append("\(key): \(value)")
        }
        headerStrings.append(contentsOf: ["", ""])
        let headerData = Data(headerStrings.joined(separator: "\r\n").utf8)
        let expectedData = Data(headerData + body)
        let parsed = HTTPRequestParser(request, version: version)
        try #require(parsed.parsedData == expectedData)
    }
}

extension HTTPParserRequestTests {
    @Suite
    struct HTTPConnectTests {
        @Test(.tags(.httpParser), arguments: [
            (NWEndpoint.Host.name("example.com", nil), nil as NWEndpoint.Port?, "CONNECT example.com HTTP/1.1"),
            (NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!), nil, "CONNECT 127.0.0.1 HTTP/1.1"),
            (NWEndpoint.Host.ipv6(IPv6Address("2001:0db8:85a3:0000:0000:8a2e:0370:7334")!), nil, "CONNECT [2001:db8:85a3::8a2e:370:7334] HTTP/1.1"),
            ("example.com" as NWEndpoint.Host, nil, "CONNECT example.com HTTP/1.1"),
            ("127.0.0.1" as NWEndpoint.Host, nil, "CONNECT 127.0.0.1 HTTP/1.1"),
            ("2001:0db8:85a3:0000:0000:8a2e:0370:7334" as NWEndpoint.Host, nil, "CONNECT [2001:db8:85a3::8a2e:370:7334] HTTP/1.1"),
            
            (NWEndpoint.Host.name("example.com", nil), 80 as NWEndpoint.Port?, "CONNECT example.com:80 HTTP/1.1"),
            (NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!), 80, "CONNECT 127.0.0.1:80 HTTP/1.1"),
            (NWEndpoint.Host.ipv6(IPv6Address("2001:0db8:85a3:0000:0000:8a2e:0370:7334")!), 80, "CONNECT [2001:db8:85a3::8a2e:370:7334]:80 HTTP/1.1"),
            ("example.com" as NWEndpoint.Host, 80, "CONNECT example.com:80 HTTP/1.1"),
            ("127.0.0.1" as NWEndpoint.Host, 80, "CONNECT 127.0.0.1:80 HTTP/1.1"),
            ("2001:0db8:85a3:0000:0000:8a2e:0370:7334" as NWEndpoint.Host, 80, "CONNECT [2001:db8:85a3::8a2e:370:7334]:80 HTTP/1.1"),
            
            (NWEndpoint.Host.name("example.com", nil), NWEndpoint.Port(rawValue: 80), "CONNECT example.com:80 HTTP/1.1"),
            (NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!), NWEndpoint.Port(rawValue: 80), "CONNECT 127.0.0.1:80 HTTP/1.1"),
            (NWEndpoint.Host.ipv6(IPv6Address("2001:0db8:85a3:0000:0000:8a2e:0370:7334")!), NWEndpoint.Port(rawValue: 80), "CONNECT [2001:db8:85a3::8a2e:370:7334]:80 HTTP/1.1"),
            ("example.com" as NWEndpoint.Host, NWEndpoint.Port(rawValue: 80), "CONNECT example.com:80 HTTP/1.1"),
            ("127.0.0.1" as NWEndpoint.Host, NWEndpoint.Port(rawValue: 80), "CONNECT 127.0.0.1:80 HTTP/1.1"),
            ("2001:0db8:85a3:0000:0000:8a2e:0370:7334" as NWEndpoint.Host, NWEndpoint.Port(rawValue: 80), "CONNECT [2001:db8:85a3::8a2e:370:7334]:80 HTTP/1.1"),
        ])
        func withoutHeaders(_ host: NWEndpoint.Host, _ port: NWEndpoint.Port?, _ expectedString: String) throws {
            let parser = HTTPRequestParser(connectTo: host, port, headers: [:])
            let target = if let port {
                [host.asUrlString, String(port.rawValue)].joined(separator: ":")
            } else {
                host.asUrlString
            }
            let expectedLines = [
                expectedString,
                "Connection: close",
                "Host: \(target)",
                "",
                ""
            ]
            let expectedData = Data(expectedLines.joined(separator: "\r\n").utf8)
            try #require(parser.parsedData == expectedData)
        }
        
        @Test(.tags(.httpParser), arguments: [
            (NWEndpoint.Host.name("example.com", nil), nil as NWEndpoint.Port?, "CONNECT example.com HTTP/1.1"),
            (NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!), nil, "CONNECT 127.0.0.1 HTTP/1.1"),
            (NWEndpoint.Host.ipv6(IPv6Address("2001:0db8:85a3:0000:0000:8a2e:0370:7334")!), nil, "CONNECT [2001:db8:85a3::8a2e:370:7334] HTTP/1.1"),
            ("example.com" as NWEndpoint.Host, nil, "CONNECT example.com HTTP/1.1"),
            ("127.0.0.1" as NWEndpoint.Host, nil, "CONNECT 127.0.0.1 HTTP/1.1"),
            ("2001:0db8:85a3:0000:0000:8a2e:0370:7334" as NWEndpoint.Host, nil, "CONNECT [2001:db8:85a3::8a2e:370:7334] HTTP/1.1"),
            
            (NWEndpoint.Host.name("example.com", nil), 80 as NWEndpoint.Port?, "CONNECT example.com:80 HTTP/1.1"),
            (NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!), 80, "CONNECT 127.0.0.1:80 HTTP/1.1"),
            (NWEndpoint.Host.ipv6(IPv6Address("2001:0db8:85a3:0000:0000:8a2e:0370:7334")!), 80, "CONNECT [2001:db8:85a3::8a2e:370:7334]:80 HTTP/1.1"),
            ("example.com" as NWEndpoint.Host, 80, "CONNECT example.com:80 HTTP/1.1"),
            ("127.0.0.1" as NWEndpoint.Host, 80, "CONNECT 127.0.0.1:80 HTTP/1.1"),
            ("2001:0db8:85a3:0000:0000:8a2e:0370:7334" as NWEndpoint.Host, 80, "CONNECT [2001:db8:85a3::8a2e:370:7334]:80 HTTP/1.1"),
            
            (NWEndpoint.Host.name("example.com", nil), NWEndpoint.Port(rawValue: 80), "CONNECT example.com:80 HTTP/1.1"),
            (NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!), NWEndpoint.Port(rawValue: 80), "CONNECT 127.0.0.1:80 HTTP/1.1"),
            (NWEndpoint.Host.ipv6(IPv6Address("2001:0db8:85a3:0000:0000:8a2e:0370:7334")!), NWEndpoint.Port(rawValue: 80), "CONNECT [2001:db8:85a3::8a2e:370:7334]:80 HTTP/1.1"),
            ("example.com" as NWEndpoint.Host, NWEndpoint.Port(rawValue: 80), "CONNECT example.com:80 HTTP/1.1"),
            ("127.0.0.1" as NWEndpoint.Host, NWEndpoint.Port(rawValue: 80), "CONNECT 127.0.0.1:80 HTTP/1.1"),
            ("2001:0db8:85a3:0000:0000:8a2e:0370:7334" as NWEndpoint.Host, NWEndpoint.Port(rawValue: 80), "CONNECT [2001:db8:85a3::8a2e:370:7334]:80 HTTP/1.1"),
        ])
        func witHeaders(_ host: NWEndpoint.Host, _ port: NWEndpoint.Port?, _ expectedString: String) throws {
            let target = if let port {
                [host.asUrlString, String(port.rawValue)].joined(separator: ":")
            } else {
                host.asUrlString
            }
            let headers = [
                "Header3": "Header value 3",
                "Header2": "Header value 2",
                "Host": target,
            ]
            let parser = HTTPRequestParser(connectTo: host, port, headers: headers)
            let expectedLines = [
                expectedString,
                "Connection: close",
                "Header2: Header value 2",
                "Header3: Header value 3",
                "Host: \(target)",
                "",
                ""
            ]
            let expectedData = Data(expectedLines.joined(separator: "\r\n").utf8)
            try #require(parser.parsedData == expectedData)
        }
        
        @Test(.tags(.httpParser))
        func containsHostHeader() throws {
            let host: NWEndpoint.Host = .name("example.com", nil)
            let port: NWEndpoint.Port = 90
            let parser = HTTPRequestParser(connectTo: host, port, headers: [:])
            let expectedLines = [
                "CONNECT example.com:90 HTTP/1.1",
                "Connection: close",
                "Host: example.com:90",
                "",
                ""
            ]
            let expectedData = Data(expectedLines.joined(separator: "\r\n").utf8)
            try #require(parser.parsedData == expectedData)
        }
    }
}
