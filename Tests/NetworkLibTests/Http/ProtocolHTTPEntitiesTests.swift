import Foundation
import Testing
@testable import NetworkLib

@Suite(.disabled(), .tags(.httpProtocol))
struct ProtocolHTTPEntitiesTests {
    struct MessageKind {
        @Test(arguments: [
            (HTTPMessageKind.response, "Response"),
            (HTTPMessageKind.body, "Body"),
            (HTTPMessageKind.end, "End"),
        ])
        func description(_ value: HTTPMessageKind, _ expected: String) throws {
            try #require(value.description == expected)
        }
    }
}
