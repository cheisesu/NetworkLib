import Foundation
import Testing
@testable import NetworkLib

struct HTTPResponseParserTests {
    // MARK: - FULL BUFFER

    @Test
    func incompleteBuffer_ReturnsEmptyEvents() throws {
        let _data = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
        ].joined(separator: "\r\n").data(using: .utf8)
        let url = try #require(URL(string: "http://example.com/users/123"))
        let httpData = try #require(_data)
        let parser = HTTPResponseParser(with: url)
        let events = parser.append(httpData)
        try #require(events.isEmpty)
    }

    @Test(.disabled("Not working"))
    func appendingIncorrectData_ReturnsEmptyEvents() throws {
    }

    @Test
    func withNoBody_ReturnsHTTPResponseEvent() throws {
        let _data = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)
        let url = try #require(URL(string: "http://example.com/users/123"))
        let httpData = try #require(_data)
        let parser = HTTPResponseParser(with: url)
        let events = parser.append(httpData)
        try #require(events.count == 1)
        let event = events[0]
        switch event {
        case let .response(response):
            try #require(response.statusCode == 201)
            try #require(response.url == url)
            try #require(response.value(forHTTPHeaderField: "Content-Type") == "application/json")
            try #require(response.value(forHTTPHeaderField: "Location") == "http://example.com/users/123")
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    @Test
    func onlyMessagetWithNoHeaders_ReturnsHTTPResponseEvent() throws {
        let _data = [
            "HTTP/1.1 201 Created",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)
        let url = try #require(URL(string: "http://example.com/users/123"))
        let httpData = try #require(_data)
        let parser = HTTPResponseParser(with: url)
        let events = parser.append(httpData)
        try #require(events.count == 1)
        let event = events[0]
        switch event {
        case .response: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    @Test
    func withExistedBodyInOneBuffer_ReturnsBothEvents() throws {
        let _httpMessageData = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)
        let _httpBody = [
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
        ].joined(separator: "\r\n").data(using: .utf8)
        let httpMessage = try #require(_httpMessageData)
        let httpBody = try #require(_httpBody)
        let url = try #require(URL(string: "http://example.com/users/123"))
        let httpData = httpMessage + httpBody
        let parser = HTTPResponseParser(with: url)
        let events = parser.append(httpData)
        try #require(events.count == 2)
        var event = events[0]
        switch event {
        case let .response(response):
            try #require(response.statusCode == 201)
            try #require(response.url == url)
            try #require(response.value(forHTTPHeaderField: "Content-Type") == "application/json")
            try #require(response.value(forHTTPHeaderField: "Location") == "http://example.com/users/123")
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case let .data(data): try #require(data == httpBody)
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    // MARK: - SMALL PORTIONS

    @Test
    func withSmallSizedAppending_OnlyHTTPMessage_ReturnsEmptyAndThenHTTPResponseEvent() throws {
        let _httpMessageData1 = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            ""
        ].joined(separator: "\r\n").data(using: .utf8)
        let _httpMessageData2 = [
            "Location: http://example.com/users/123",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)
        let httpMessage1 = try #require(_httpMessageData1)
        let httpMessage2 = try #require(_httpMessageData2)
        let url = try #require(URL(string: "http://example.com/users/123"))
        let parser = HTTPResponseParser(with: url)
        var events = parser.append(httpMessage1)
        try #require(events.isEmpty)
        events = parser.append(httpMessage2)
        try #require(events.count == 1)
        let event = events[0]
        switch event {
        case let .response(response):
            try #require(response.statusCode == 201)
            try #require(response.url == url)
            try #require(response.value(forHTTPHeaderField: "Content-Type") == "application/json")
            try #require(response.value(forHTTPHeaderField: "Location") == "http://example.com/users/123")
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    @Test
    func withSmallSizedAppending_HTTPMessageWithData_ReturnsEmptyAndThenHTTPResponseEventWithCorrectData() throws {
        let _httpMessageData1 = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            ""
        ].joined(separator: "\r\n").data(using: .utf8)
        let _httpMessageData2 = [
            "Location: http://example.com/users/123",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)
        let _httpBody = [
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
        ].joined(separator: "\r\n").data(using: .utf8)
        let httpMessage1 = try #require(_httpMessageData1)
        let httpMessage2 = try #require(_httpMessageData2)
        let httpBody = try #require(_httpBody)
        let url = try #require(URL(string: "http://example.com/users/123"))
        let parser = HTTPResponseParser(with: url)
        var events = parser.append(httpMessage1)
        try #require(events.isEmpty)
        events = parser.append(httpMessage2 + httpBody)
        try #require(events.count == 2)
        var event = events[0]
        switch event {
        case let .response(response):
            try #require(response.statusCode == 201)
            try #require(response.url == url)
            try #require(response.value(forHTTPHeaderField: "Content-Type") == "application/json")
            try #require(response.value(forHTTPHeaderField: "Location") == "http://example.com/users/123")
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case let .data(data): try #require(data == httpBody)
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    // MARK: - CHUNKED
}

