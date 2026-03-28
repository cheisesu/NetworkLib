import Testing
import Foundation
@testable import NetworkLib

extension Tag {
    @Tag static var urlRequest: Self
}

struct URLRequestToHTTPTests {
    @Test(.tags(.urlRequest), arguments: [
        ("http://localhost/", nil as String?, HTTPVersion.v1_0, "GET / HTTP/1.0"),
        ("http://localhost/?", nil as String?, HTTPVersion.v1_0, "GET /? HTTP/1.0"),
        ("http://localhost/path1", nil as String?, HTTPVersion.v1_0, "GET /path1 HTTP/1.0"),
        ("http://localhost/path1/path2", nil as String?, HTTPVersion.v1_0, "GET /path1/path2 HTTP/1.0"),
        ("http://localhost/path1/?", nil as String?, HTTPVersion.v1_0, "GET /path1/? HTTP/1.0"),
        ("http://localhost/path1?", nil as String?, HTTPVersion.v1_0, "GET /path1? HTTP/1.0"),
        ("http://localhost/path1/?q1=query1", nil as String?, HTTPVersion.v1_0, "GET /path1/?q1=query1 HTTP/1.0"),
        ("http://localhost/path1?q1=query1", nil as String?, HTTPVersion.v1_0, "GET /path1?q1=query1 HTTP/1.0"),
        ("http://localhost/path1/?q1=query1&q2=query2", nil as String?, HTTPVersion.v1_0, "GET /path1/?q1=query1&q2=query2 HTTP/1.0"),
        ("http://localhost/path1?q1=query1&q2=query2", nil as String?, HTTPVersion.v1_0, "GET /path1?q1=query1&q2=query2 HTTP/1.0"),
        ("http://localhost/path1/?q1=query1&q2=query2&", nil as String?, HTTPVersion.v1_0, "GET /path1/?q1=query1&q2=query2& HTTP/1.0"),
        ("http://localhost/path1?q1=query1&q2=query2&", nil as String?, HTTPVersion.v1_0, "GET /path1?q1=query1&q2=query2& HTTP/1.0"),
        
        ("http://localhost/", "METHOD", HTTPVersion.v1_0, "METHOD / HTTP/1.0"),
        ("http://localhost/?", "METHOD", HTTPVersion.v1_0, "METHOD /? HTTP/1.0"),
        ("http://localhost/path1", "METHOD", HTTPVersion.v1_0, "METHOD /path1 HTTP/1.0"),
        ("http://localhost/path1/path2", "METHOD", HTTPVersion.v1_0, "METHOD /path1/path2 HTTP/1.0"),
        ("http://localhost/path1/?", "METHOD", HTTPVersion.v1_0, "METHOD /path1/? HTTP/1.0"),
        ("http://localhost/path1?", "METHOD", HTTPVersion.v1_0, "METHOD /path1? HTTP/1.0"),
        ("http://localhost/path1/?q1=query1", "METHOD", HTTPVersion.v1_0, "METHOD /path1/?q1=query1 HTTP/1.0"),
        ("http://localhost/path1?q1=query1", "METHOD", HTTPVersion.v1_0, "METHOD /path1?q1=query1 HTTP/1.0"),
        ("http://localhost/path1/?q1=query1&q2=query2", "METHOD", HTTPVersion.v1_0, "METHOD /path1/?q1=query1&q2=query2 HTTP/1.0"),
        ("http://localhost/path1?q1=query1&q2=query2", "METHOD", HTTPVersion.v1_0, "METHOD /path1?q1=query1&q2=query2 HTTP/1.0"),
        ("http://localhost/path1/?q1=query1&q2=query2&", "METHOD", HTTPVersion.v1_0, "METHOD /path1/?q1=query1&q2=query2& HTTP/1.0"),
        ("http://localhost/path1?q1=query1&q2=query2&", "METHOD", HTTPVersion.v1_0, "METHOD /path1?q1=query1&q2=query2& HTTP/1.0"),
        
        ("http://localhost/", nil as String?, HTTPVersion.v1_1, "GET / HTTP/1.1"),
        ("http://localhost/?", nil as String?, HTTPVersion.v1_1, "GET /? HTTP/1.1"),
        ("http://localhost/path1", nil as String?, HTTPVersion.v1_1, "GET /path1 HTTP/1.1"),
        ("http://localhost/path1/path2", nil as String?, HTTPVersion.v1_1, "GET /path1/path2 HTTP/1.1"),
        ("http://localhost/path1/?", nil as String?, HTTPVersion.v1_1, "GET /path1/? HTTP/1.1"),
        ("http://localhost/path1?", nil as String?, HTTPVersion.v1_1, "GET /path1? HTTP/1.1"),
        ("http://localhost/path1/?q1=query1", nil as String?, HTTPVersion.v1_1, "GET /path1/?q1=query1 HTTP/1.1"),
        ("http://localhost/path1?q1=query1", nil as String?, HTTPVersion.v1_1, "GET /path1?q1=query1 HTTP/1.1"),
        ("http://localhost/path1/?q1=query1&q2=query2", nil as String?, HTTPVersion.v1_1, "GET /path1/?q1=query1&q2=query2 HTTP/1.1"),
        ("http://localhost/path1?q1=query1&q2=query2", nil as String?, HTTPVersion.v1_1, "GET /path1?q1=query1&q2=query2 HTTP/1.1"),
        ("http://localhost/path1/?q1=query1&q2=query2&", nil as String?, HTTPVersion.v1_1, "GET /path1/?q1=query1&q2=query2& HTTP/1.1"),
        ("http://localhost/path1?q1=query1&q2=query2&", nil as String?, HTTPVersion.v1_1, "GET /path1?q1=query1&q2=query2& HTTP/1.1"),
        
        ("http://localhost/", "METHOD", HTTPVersion.v1_1, "METHOD / HTTP/1.1"),
        ("http://localhost/?", "METHOD", HTTPVersion.v1_1, "METHOD /? HTTP/1.1"),
        ("http://localhost/path1", "METHOD", HTTPVersion.v1_1, "METHOD /path1 HTTP/1.1"),
        ("http://localhost/path1/path2", "METHOD", HTTPVersion.v1_1, "METHOD /path1/path2 HTTP/1.1"),
        ("http://localhost/path1/?", "METHOD", HTTPVersion.v1_1, "METHOD /path1/? HTTP/1.1"),
        ("http://localhost/path1?", "METHOD", HTTPVersion.v1_1, "METHOD /path1? HTTP/1.1"),
        ("http://localhost/path1/?q1=query1", "METHOD", HTTPVersion.v1_1, "METHOD /path1/?q1=query1 HTTP/1.1"),
        ("http://localhost/path1?q1=query1", "METHOD", HTTPVersion.v1_1, "METHOD /path1?q1=query1 HTTP/1.1"),
        ("http://localhost/path1/?q1=query1&q2=query2", "METHOD", HTTPVersion.v1_1, "METHOD /path1/?q1=query1&q2=query2 HTTP/1.1"),
        ("http://localhost/path1?q1=query1&q2=query2", "METHOD", HTTPVersion.v1_1, "METHOD /path1?q1=query1&q2=query2 HTTP/1.1"),
        ("http://localhost/path1/?q1=query1&q2=query2&", "METHOD", HTTPVersion.v1_1, "METHOD /path1/?q1=query1&q2=query2& HTTP/1.1"),
        ("http://localhost/path1?q1=query1&q2=query2&", "METHOD", HTTPVersion.v1_1, "METHOD /path1?q1=query1&q2=query2& HTTP/1.1"),
    ])
    func transformsCorrectly(_ urlString: String, _ method: String?, _ version: HTTPVersion, _ expected: String) throws {
        let url = try #require(URL(string: urlString))
        var request = URLRequest(url: url)
        request.httpMethod = method
        let result = request.startLine(version)
        try #require(result == expected)
    }
}
