import Foundation
import Testing
@testable import NetworkLib

extension Tag.Utils {
    @Tag static var urlProperties: Tag
}

@Suite(.tags(.Utils.all, .Utils.urlProperties))
struct URLPropertiesTests {
    @Test("Wrapped host", arguments: [
        ("https://example.com/path", "example.com"),
        ("https://user:password@example.com:8443/path", "example.com"),
        ("https://subdomain.example.com", "subdomain.example.com"),
        ("/relative/path", nil),
        ("mailto:person@example.com", nil),
    ] as [(String, String?)])
    func wrappedHost(_ urlString: String, _ expected: String?) throws {
        let url = try #require(URL(string: urlString))
        #expect(url.wrappedHost == expected)
    }

    @Test("Wrapped path", arguments: [
        ("https://example.com", ""),
        ("https://example.com/", "/"),
        ("https://example.com/some/path", "/some/path"),
        ("https://example.com/a%20path/file", "/a%20path/file"),
        ("/relative/path", "/relative/path"),
    ] as [(String, String?)])
    func wrappedPath(_ urlString: String, _ expected: String?) throws {
        let url = try #require(URL(string: urlString))
        #expect(url.wrappedPath == expected)
    }

    @Test("Opaque URL path follows Foundation")
    func opaquePathMatchesFoundation() throws {
        let url = try #require(URL(string: "mailto:person@example.com"))
        // Foundation's path for opaque URLs differs between OS releases.
        // This wrapper preserves the platform accessor's behavior.
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            #expect(url.wrappedPath == url.path())
        } else {
            #expect(url.wrappedPath == url.path)
        }
    }

    @Test("Wrapped query", arguments: [
        ("https://example.com/path", nil),
        ("https://example.com/path?", ""),
        ("https://example.com/path?name=value", "name=value"),
        ("https://example.com/path?name=hello%20world&flag", "name=hello%20world&flag"),
        ("/relative/path?key=value", "key=value"),
    ] as [(String, String?)])
    func wrappedQuery(_ urlString: String, _ expected: String?) throws {
        let url = try #require(URL(string: urlString))
        #expect(url.wrappedQuery == expected)
    }
}
