import Testing
import Foundation
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
        let expectedString = "\(expectedMethod) /path1?q1=query1 HTTP/\(version.rawValue)\r\n\r\n"
        let expectedData = Data(expectedString.utf8)
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
            ("DateTime", "\(Date())"),
        ]
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
            ["Content-Length", String(body.count)].joined(separator: ": "),
            "",
            "",
        ]
        let headerData = Data(headerStrings.joined(separator: "\r\n").utf8)
        let expectedData = Data(headerData + body + Data([0x0d, 0x0a, 0x0d, 0x0a]))
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
            ("Content-Length", String(body.count))
        ]
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
        let expectedData = Data(headerData + body + Data([0x0d, 0x0a, 0x0d, 0x0a]))
        let parsed = HTTPRequestParser(request, version: version)
        try #require(parsed.parsedData == expectedData)
    }
}
