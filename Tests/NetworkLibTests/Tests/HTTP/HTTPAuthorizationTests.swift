import Foundation
import Testing
@testable import NetworkLib

extension Tag {
    @Tag static var httpAuth: Tag
}

struct HTTPAuthorizationTests {
    @Test(.tags(.httpAuth))
    func authorizationHeader() throws {
        let expected = "Basic Zm9vOnBhcykwMQ=="
        let auth = HTTPAuthorization.basic(userName: "foo", password: "pas)01")
        let header = auth.httpHeader
        try #require(header == expected)
    }
}
