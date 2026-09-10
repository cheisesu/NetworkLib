import Foundation
import Testing
import Network
@testable import NetworkLibCore

struct HTTPSendMessageTests {
    @Test(.tags(.httpProtocol))
    func correctValues() throws {
        let url = try #require(URL(string: "https://example.com"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("qwe", forHTTPHeaderField: "Content")

        let message = HTTPSendMessage(request)

        try #require(message.content == nil)
        try #require(message.context.identifier == "ProtocolHTTP.Message.Request")
        try #require(message.context.isFinal == false)
        let metaRaw = try #require(message.context.protocolMetadata(definition: .http))
        let framerMessage = try #require(metaRaw as? NWProtocolFramer.Message)
        try #require(framerMessage.httpRequest == request)
    }
}
