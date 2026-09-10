import Foundation
import Testing
@testable import NetworkLibHttpCore

extension Tag {
    enum HTTP {
        @Tag static var all: Tag
    }
}

@Suite(.tags(.HTTP.all))
struct HTTPAuthorizationTests {
    @Test
    func authorizationHeader() throws {
        let expected = "Basic Zm9vOnBhcykwMQ=="
        let auth = HTTPAuthorization.basic(userName: "foo", password: "pas)01")
        let header = auth.httpHeader
        try #require(header == expected)
    }
}
