import Foundation
import Testing
@testable import NetworkLib

struct ProtocolHTTPEntitiesTests {
    @Suite
    struct MessageKind {
        @Test(.tags(.httpProtocol), arguments: [
            (HTTPMessageKind.response, "Response"),
            (HTTPMessageKind.body, "Body"),
            (HTTPMessageKind.end, "End"),
        ])
        func description(_ value: HTTPMessageKind, _ expected: String) throws {
            try #require(value.description == expected)
        }
    }
}
