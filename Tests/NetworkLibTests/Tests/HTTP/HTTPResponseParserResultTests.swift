import Foundation
import Testing
@testable import NetworkLib

struct HTTPParserResponseResultTests {
    @Test(.tags(.httpParser))
    func creatingUrlResponse() throws {
        let headers: [HTTPHeaderKey: String] = ["Content": "123"]
        let result = HTTPParserResponseResult(versionRaw: "HTTP/1.1", status: 302, headers: headers,
                                              rawSize: 123, leftBuffer: Data())
        let url = try #require(URL(string: "https://example.com/some-page"))
        let response = try #require(result.urlResponse(with: url))
        try #require(response.url == url)
        try #require(response.statusCode == result.status)
        let responseHeaders = try #require(response.allHeaderFields as? [String: String])
        try #require(responseHeaders == headers.rawFields)
    }
}
