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
        let events = try parser.append(httpData)
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
        let events = try parser.append(httpData)
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
        let events = try parser.append(httpData)
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
        let events = try parser.append(httpData)
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
        var events = try parser.append(httpMessage1)
        try #require(events.isEmpty)
        events = try parser.append(httpMessage2)
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
        var events = try parser.append(httpMessage1)
        try #require(events.isEmpty)
        events = try parser.append(httpMessage2 + httpBody)
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

    // MARK: - TRANSFER-ENCODING: CHUNKED

    @Suite
    struct Chunked {
        @Test
        func fullChunkDataPortions_ReturnsResponsePortionsDataAndEndEvents() throws {
            let httpMessageData = [
                "HTTP/1.1 201 Created",
                "Transfer-Encoding: chunked",
                "",
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let chunk1String = """
{
  "message": "New user created",
  "user": {
    "id": 123,
    "firstName": "Example",
    "lastName": "Person 👀",
    "email": "bsmth@example.com"
  }
}
"""
            let httpChunk1 = [
                String(format: "%X", chunk1String.utf8.count),
                chunk1String,
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let httpChunk2 = "0\r\n\r\n".data(using: .utf8)!
            let url = try #require(URL(string: "http://example.com/users/123"))
            let parser = HTTPResponseParser(with: url)
            var events = try parser.append(httpMessageData)
            try #require(events.count == 1)
            try #require(events[0].response != nil)
            events = try parser.append(httpChunk1)
            try #require(events.count == 1)
            let chunkData = try #require(events[0].data)
            try #require(chunkData == Data(chunk1String.utf8))
            events = try parser.append(httpChunk2)
            try #require(events.count == 1)
            try #require(events[0].isEnd)
        }

        @Test
        func notFullChunkDataPortions_ReturnsEmptyEventsInside() throws {
            let httpMessageData = [
                "HTTP/1.1 201 Created",
                "Transfer-Encoding: chunked",
                "",
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let chunk1String1 = """
{
  "message": "New user created",
  "user": {
    "id": 123,
    "firstName": "Examp
"""
            let chunk1String2 = """
le",
    "lastName": "Person 👀",
    "email": "bsmth@example.com"
  }
}
"""
            let httpChunk1Data1 = [
                String(format: "%X", (chunk1String1 + chunk1String2).utf8.count),
                chunk1String1,
            ].joined(separator: "\r\n").data(using: .utf8)!
            let httpChunk1Data2 = [
                chunk1String2,
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let httpChunk3 = "0\r\n\r\n".data(using: .utf8)!
            let url = try #require(URL(string: "http://example.com/users/123"))
            let parser = HTTPResponseParser(with: url)
            var events = try parser.append(httpMessageData)
            try #require(events.count == 1)
            try #require(events[0].response != nil)
            events = try parser.append(httpChunk1Data1)
            try #require(events.isEmpty)
            events = try parser.append(httpChunk1Data2)
            try #require(events.count == 1)
            let chunkData = try #require(events[0].data)
            try #require(chunkData == Data(chunk1String1.utf8) + Data(chunk1String2.utf8))
            events = try parser.append(httpChunk3)
            try #require(events.count == 1)
            try #require(events[0].isEnd)
        }

        @Test
        func wrongChunkSizeString_ThrowsInvalidChunkSizeError() throws {
            let httpMessageData = [
                "HTTP/1.1 201 Created",
                "Transfer-Encoding: chunked",
                "",
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let chunk1String = """
{
  "message": "New user created",
  "user": {
    "id": 123,
    "firstName": "Example",
    "lastName": "Person 👀",
    "email": "bsmth@example.com"
  }
}
"""
            let httpChunk1 = [
                String(format: "h%X", chunk1String.utf8.count),
                chunk1String,
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let url = try #require(URL(string: "http://example.com/users/123"))
            let parser = HTTPResponseParser(with: url)
            var events = try parser.append(httpMessageData)
            try #require(events.count == 1)
            try #require(events[0].response != nil)
            do {
                events = try parser.append(httpChunk1)
                throw TestError.unexpectedEntrance
            } catch HTTPResponseParser.Error.invalidChunkSize {
            } catch { throw error }
        }

        @Test
        func splittedChunkSizeAndCRLFPortions_ReturnsEmptyEvents() throws {
            let httpMessageData = [
                "HTTP/1.1 201 Created",
                "Transfer-Encoding: chunked",
                "",
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let chunk1String = """
{
  "message": "New user created",
  "user": {
    "id": 123,
    "firstName": "Example",
    "lastName": "Person 👀",
    "email": "bsmth@example.com"
  }
}
"""
            let httpChunk1Data1 = String(format: "%X", chunk1String.utf8.count).data(using: .utf8)!
            let httpChunk1Data2 = "\r\n".data(using: .utf8)!
            let httpChunk1Data3 = [
                chunk1String,
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let httpChunk2 = "0\r\n\r\n".data(using: .utf8)!
            let url = try #require(URL(string: "http://example.com/users/123"))
            let parser = HTTPResponseParser(with: url)
            var events = try parser.append(httpMessageData)
            try #require(events.count == 1)
            try #require(events[0].response != nil)
            events = try parser.append(httpChunk1Data1)
            try #require(events.isEmpty)
            events = try parser.append(httpChunk1Data2)
            try #require(events.isEmpty)
            events = try parser.append(httpChunk1Data3)
            try #require(events.count == 1)
            let chunkData = try #require(events[0].data)
            try #require(chunkData == Data(chunk1String.utf8))
            events = try parser.append(httpChunk2)
            try #require(events.count == 1)
            try #require(events[0].isEnd)
        }

        @Test
        func splittedChunkAndCRLFPortions_ReturnsEmptyAndDataEvent() throws {
            let httpMessageData = [
                "HTTP/1.1 201 Created",
                "Transfer-Encoding: chunked",
                "",
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let chunkString = """
{
  "message": "New user created",
  "user": {
    "id": 123,
    "firstName": "Example",
    "lastName": "Person 👀",
    "email": "bsmth@example.com"
  }
}
"""
            let httpChunk1 = [
                String(format: "%X", chunkString.utf8.count),
                chunkString,
            ].joined(separator: "\r\n").data(using: .utf8)!
            let httpChunk2 = "\r\n".data(using: .utf8)!
            let httpChunk3 = "0\r\n\r\n".data(using: .utf8)!
            let url = try #require(URL(string: "http://example.com/users/123"))
            let parser = HTTPResponseParser(with: url)
            var events = try parser.append(httpMessageData)
            try #require(events.count == 1)
            try #require(events[0].response != nil)
            events = try parser.append(httpChunk1)
            try #require(events.isEmpty)
            events = try parser.append(httpChunk2)
            try #require(events.count == 1)
            let chunkData = try #require(events[0].data)
            try #require(chunkData == Data(chunkString.utf8))
            events = try parser.append(httpChunk3)
            try #require(events.count == 1)
            try #require(events[0].isEnd)
        }

        @Test
        func trashDataBetweenChunkDataAndItsCRLF_ThrowsInvalidChunkTerminatorError() throws {
            let httpMessageData = [
                "HTTP/1.1 201 Created",
                "Transfer-Encoding: chunked",
                "",
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let chunkString = """
{
  "message": "New user created",
  "user": {
    "id": 123,
    "firstName": "Example",
    "lastName": "Person 👀",
    "email": "bsmth@example.com"
  }
}
"""
            let httpChunk1 = [
                String(format: "%X", chunkString.utf8.count),
                chunkString,
            ].joined(separator: "\r\n").data(using: .utf8)!
            let httpChunk2 = "<trash_data>\r\n".data(using: .utf8)!
            let url = try #require(URL(string: "http://example.com/users/123"))
            let parser = HTTPResponseParser(with: url)
            var events = try parser.append(httpMessageData)
            try #require(events.count == 1)
            try #require(events[0].response != nil)
            events = try parser.append(httpChunk1)
            try #require(events.isEmpty)
            do {
                events = try parser.append(httpChunk2)
                throw TestError.unexpectedEntrance
            } catch HTTPResponseParser.Error.invalidChunkTerminator {
            } catch { throw error }
        }

        @Test
        func newChunksAfterEndOne_ThrowsParsingCompletedError() throws {
            let httpMessageData = [
                "HTTP/1.1 201 Created",
                "Transfer-Encoding: chunked",
                "",
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let chunk1String = """
{
  "message": "New user created",
  "user": {
    "id": 123,
    "firstName": "Example",
    "lastName": "Person 👀",
    "email": "bsmth@example.com"
  }
}
"""
            let httpChunk1 = [
                String(format: "%X", chunk1String.utf8.count),
                chunk1String,
                "",
            ].joined(separator: "\r\n").data(using: .utf8)!
            let httpChunk2 = "0\r\n\r\n".data(using: .utf8)!
            let httpChunk3 = httpChunk1
            let url = try #require(URL(string: "http://example.com/users/123"))
            let parser = HTTPResponseParser(with: url)
            var events = try parser.append(httpMessageData)
            try #require(events.count == 1)
            try #require(events[0].response != nil)
            events = try parser.append(httpChunk1)
            try #require(events.count == 1)
            try #require(events[0].data != nil)
            events = try parser.append(httpChunk2)
            try #require(events.count == 1)
            try #require(events[0].isEnd)
            do {
                events = try parser.append(httpChunk3)
                throw TestError.unexpectedEntrance
            } catch HTTPResponseParser.Error.parsingCompleted {
            } catch { throw error }
        }
    }
}

