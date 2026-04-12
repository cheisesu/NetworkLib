import Foundation
import Testing
@testable import NetworkLib

struct RawHTTPResponseParserTests {
    @Test(.tags(.httpParser))
    func incompleteBuffer_ReturnsNil() throws {
        let httpData = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let result = RawHTTPResponseParser.parse(httpData)
        try #require(result == nil)
    }

    @Test(.tags(.httpParser))
    func withNoBody_ReturnsCorrectResultWithEmptyLeftBuffer() throws {
        let httpData = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let result = try #require(RawHTTPResponseParser.parse(httpData))

        try #require(result.status == 201)
        try #require(result.versionRaw == "HTTP/1.1")
        try #require(result.headers["Content-Type"] == "application/json")
        try #require(result.headers["Location"] == "http://example.com/users/123")
        try #require(result.rawSize == httpData.count)
        try #require(result.leftBuffer.isEmpty)
    }

    @Test(.tags(.httpParser))
    func appendByPortions_ReturnsCorrectResult() throws {
        let httpData1 = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let httpData2 = [
            "",
            "Location: http://example.com/users/123",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        var parser = RawHTTPResponseParser()
        parser.append(httpData1)
        try #require(parser.tryParse() == nil)
        try #require(!parser.isCompleted)
        parser.append(httpData2)
        let parsed = parser.tryParse()
        let result = try #require(parsed)

        try #require(parser.isCompleted)
        try #require(result.status == 201)
        try #require(result.versionRaw == "HTTP/1.1")
        try #require(result.headers["Content-Type"] == "application/json")
        try #require(result.headers["Location"] == "http://example.com/users/123")
        try #require(result.rawSize == httpData1.count + httpData2.count)
        try #require(result.leftBuffer.isEmpty)
    }

    @Test(.tags(.httpParser))
    func onlyMessagetWithNoHeaders_ReturnsCorrectResultWithEmptyHeaders() throws {
        let httpData = [
            "HTTP/1.1 201 Created",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let result = try #require(RawHTTPResponseParser.parse(httpData))
        try #require(result.status == 201)
        try #require(result.versionRaw == "HTTP/1.1")
        try #require(result.headers.isEmpty)
        try #require(result.rawSize == httpData.count)
        try #require(result.leftBuffer.isEmpty)
    }

    @Test(.tags(.httpParser))
    func appendingEmptyData_DoesNothing() throws {
        let httpData = [
            "HTTP/1.1 201 Created",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        var parser = RawHTTPResponseParser()
        parser.append(httpData)
        parser.append(Data())
        let parsed = parser.tryParse()
        let result = try #require(parsed)
        try #require(result.status == 201)
        try #require(result.versionRaw == "HTTP/1.1")
        try #require(result.headers.isEmpty)
        try #require(result.rawSize == httpData.count)
        try #require(result.leftBuffer.isEmpty)
    }

    @Test(.tags(.httpParser))
    func appendingDataWithBuffer_ParseReturnsCorrect() throws {
        let httpMessageData = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let httpBody = [
            """
{
  "message": "New user created",
  "user": {
    "id": 123,
    "firstName": "Example",
    "lastName": "Person",
    "email": "bsmth@example.com"
  }
}
""",
        ].joined(separator: "\r\n").data(using: .utf8)!
        var parser = RawHTTPResponseParser()
        parser.append(httpMessageData)
        parser.append(httpBody)

        let parsed = parser.tryParse()
        let result = try #require(parsed)

        try #require(result.status == 201)
        try #require(result.versionRaw == "HTTP/1.1")
        try #require(result.headers["Content-Type"] == "application/json")
        try #require(result.headers["Location"] == "http://example.com/users/123")
        try #require(result.rawSize == httpMessageData.count)
        try #require(result.leftBuffer == httpBody)
    }
}

