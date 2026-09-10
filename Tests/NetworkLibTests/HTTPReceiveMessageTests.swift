import Foundation
import Testing
import Network
@testable import NetworkLibHttpCore

extension Tag {
    @Tag static var httpProtocol: Self
}

struct HTTPReceiveMessageTests {
    @Test(.tags(.httpProtocol))
    func contextDoesntHaveHTTPMetadata_ReturnsNil() throws {
        let context = NWConnection.ContentContext(identifier: #function)
        let message = HTTPReceiveMessage(from: context, with: nil)
        try #require(message == nil)
    }

    @Test(.tags(.httpProtocol))
    func metadataDoesntHaveValueKind_ReturnsNil() throws {
        let meta = NWProtocolFramer.Message(definition: .http)
        let context = NWConnection.ContentContext(identifier: #function, metadata: [meta])
        let message = HTTPReceiveMessage(from: context, with: nil)
        try #require(message == nil)
    }

    @Test(.tags(.httpProtocol))
    func kindEnd_ResultsEndValue() throws {
        let meta = NWProtocolFramer.Message(definition: .http)
        meta.httpKind = .end
        let context = NWConnection.ContentContext(identifier: #function, metadata: [meta])
        let message = try #require(HTTPReceiveMessage(from: context, with: nil))
        switch message {
        case .end: break
        default: try #require(false as Bool, "Expected .end")
        }
    }

    @Test(.tags(.httpProtocol))
    func kindResponse_NoValueResponse_ReturnsNil() throws {
        let meta = NWProtocolFramer.Message(definition: .http)
        meta.httpKind = .response
        let context = NWConnection.ContentContext(identifier: #function, metadata: [meta])
        let message = HTTPReceiveMessage(from: context, with: nil)
        try #require(message == nil)
    }

    @Test(.tags(.httpProtocol))
    func kindResponse_WithValueResponse_ResultsResponseValue() throws {
        let response = HTTPParserResponseResult(
            versionRaw: "HTTP/1.1",
            status: 200,
            headers: ["Content": "qwe"],
            rawSize: 123,
            leftBuffer: Data("hello".utf8)
        )
        let meta = NWProtocolFramer.Message(definition: .http)
        meta.httpKind = .response
        meta.httpResponse = response
        let context = NWConnection.ContentContext(identifier: #function, metadata: [meta])
        let message = try #require(HTTPReceiveMessage(from: context, with: nil))
        switch message {
        case let .response(_response): try #require(_response == response)
        default: try #require(false as Bool, "Expected .response")
        }
    }

    @Test(.tags(.httpProtocol))
    func kindBody_NoValueContent_ReturnsNil() throws {
        let meta = NWProtocolFramer.Message(definition: .http)
        meta.httpKind = .body
        let context = NWConnection.ContentContext(identifier: #function, metadata: [meta])
        let message = HTTPReceiveMessage(from: context, with: nil)
        try #require(message == nil)
    }

    @Test(.tags(.httpProtocol))
    func kindBody_WithValueContent_ResultsBodyValue() throws {
        let data = Data("hello, world!".utf8)
        let meta = NWProtocolFramer.Message(definition: .http)
        meta.httpKind = .body
        let context = NWConnection.ContentContext(identifier: #function, metadata: [meta])
        let message = try #require(HTTPReceiveMessage(from: context, with: data))
        switch message {
        case let .data(_data): try #require(_data == data)
        default: try #require(false as Bool, "Expected .data")
        }
    }
}
