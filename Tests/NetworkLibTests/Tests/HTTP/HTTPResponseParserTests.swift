import Foundation
import Testing
@testable import NetworkLib

struct HTTPResponseParserTests {
    // MARK: - FULL BUFFER

    @Test(.tags(.httpParser))
    func incompleteBuffer_ReturnsEmptyEvents() throws {
        let _data = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
        ].joined(separator: "\r\n").data(using: .utf8)
        let httpData = try #require(_data)
        let parser = HTTPResponseParser()
        let events = try parser.append(httpData)
        try #require(events.isEmpty)
    }

    @Test(.disabled("Not working"), .tags(.httpParser))
    func appendingIncorrectData_ReturnsEmptyEvents() throws {
    }

    @Test(.tags(.httpParser))
    func withNoBody_ReturnsHTTPResponseEvent() throws {
        let _data = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)
        let httpData = try #require(_data)
        let parser = HTTPResponseParser()
        let events = try parser.append(httpData)
        try #require(events.count == 2)
        var event = events[0]
        switch event {
        case let .response(response):
            try #require(response.status == 201)
            try #require(response.headers["Content-Type"] == "application/json")
            try #require(response.headers["Location"] == "http://example.com/users/123")
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case .end: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    @Test(.tags(.httpParser))
    func onlyMessagetWithNoHeaders_ReturnsHTTPResponseEvent() throws {
        let _data = [
            "HTTP/1.1 201 Created",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)
        let httpData = try #require(_data)
        let parser = HTTPResponseParser()
        let events = try parser.append(httpData)
        try #require(events.count == 2)
        var event = events[0]
        switch event {
        case .response: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case .end: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    @Test(.tags(.httpParser))
    func withExistedBodyInOneBuffer_ReturnsBothEvents() throws {
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
        let httpMessage = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "Content-Length: \(httpBody.count)",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let httpData = httpMessage + httpBody
        let parser = HTTPResponseParser()
        let events = try parser.append(httpData)
        try #require(events.count == 3)
        var event = events[0]
        switch event {
        case let .response(response):
            try #require(response.status == 201)
            try #require(response.headers["Content-Type"] == "application/json")
            try #require(response.headers["Location"] == "http://example.com/users/123")
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case let .data(data): try #require(data == httpBody)
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[2]
        switch event {
        case .end: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    @Test(.tags(.httpParser))
    func wrongContentLengthHeaderValue_NotRetunsData() throws {
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
        let httpMessage = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "Content-Length: foo\(httpBody.count)",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let httpData = httpMessage + httpBody
        let parser = HTTPResponseParser()
        let events = try parser.append(httpData)
        try #require(events.count == 2)
        var event = events[0]
        switch event {
        case .response: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case .end: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    // MARK: - SMALL PORTIONS

    @Test(.tags(.httpParser))
    func withSmallSizedAppending_OnlyHTTPMessage_ReturnsEmptyAndThenHTTPResponseEvent() throws {
        let httpMessage1 = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            ""
        ].joined(separator: "\r\n").data(using: .utf8)!
        let httpMessage2 = [
            "Location: http://example.com/users/123",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let parser = HTTPResponseParser()
        var events = try parser.append(httpMessage1)
        try #require(events.isEmpty)
        events = try parser.append(httpMessage2)
        try #require(events.count == 2)
        var event = events[0]
        switch event {
        case let .response(response):
            try #require(response.status == 201)
            try #require(response.headers["Content-Type"] == "application/json")
            try #require(response.headers["Location"] == "http://example.com/users/123")
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case .end: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    @Test(.tags(.httpParser))
    func withSmallSizedAppending_HTTPMessageWithData_ReturnsEmptyAndThenHTTPResponseEventWithCorrectData() throws {
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
        let httpMessage1 = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            ""
        ].joined(separator: "\r\n").data(using: .utf8)!
        let httpMessage2 = [
            "Location: http://example.com/users/123",
            "Content-Length: \(httpBody.count)",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let parser = HTTPResponseParser()
        var events = try parser.append(httpMessage1)
        try #require(events.isEmpty)
        events = try parser.append(httpMessage2 + httpBody)
        try #require(events.count == 3)
        var event = events[0]
        switch event {
        case let .response(response):
            try #require(response.status == 201)
            try #require(response.headers["Content-Type"] == "application/json")
            try #require(response.headers["Location"] == "http://example.com/users/123")
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case let .data(data): try #require(data == httpBody)
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[2]
        switch event {
        case .end: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    // MARK: - ENDING

    @Test(.tags(.httpParser))
    func contentLengthZero_ReturnsEndEventAfterResponse() throws {
        let httpData = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "",
            "",
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
"""
        ].joined(separator: "\r\n").data(using: .utf8)!
        let parser = HTTPResponseParser()
        let events = try parser.append(httpData)
        try #require(events.count == 2)
        var event = events[0]
        switch event {
        case .response: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case .end: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    @Test(.tags(.httpParser))
    func appendingLessDataThanContentLength_NotReturnsEndEvent() throws {
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
        let httpMessageData = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "Content-Length: \(httpBody.count)",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let actualBody = httpBody.suffix(50)
        let httpData = httpMessageData + actualBody
        let parser = HTTPResponseParser()
        let events = try parser.append(httpData)
        try #require(events.count == 2)
        var event = events[0]
        switch event {
        case .response: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case let .data(data): try #require(data == actualBody)
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    @Test(.tags(.httpParser))
    func appendingEqualDataAsContentLength_ReturnsEndEvent() throws {
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
        let httpMessageData = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "Content-Length: \(httpBody.count)",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let httpData = httpMessageData + httpBody
        let parser = HTTPResponseParser()
        let events = try parser.append(httpData)
        try #require(events.count == 3)
        var event = events[0]
        switch event {
        case .response: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case let .data(data): try #require(data == httpBody)
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[2]
        switch event {
        case .end: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    @Test(.tags(.httpParser))
    func appendingMoreDataAsContentLength_ReturnsEndEventAndResultedDataIsCorrect() throws {
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
        let httpMessageData = [
            "HTTP/1.1 201 Created",
            "Content-Type: application/json",
            "Location: http://example.com/users/123",
            "Content-Length: \(httpBody.count)",
            "",
            "",
        ].joined(separator: "\r\n").data(using: .utf8)!
        let httpData = httpMessageData + httpBody + Data("blablabla".utf8)
        let parser = HTTPResponseParser()
        let events = try parser.append(httpData)
        try #require(events.count == 3)
        var event = events[0]
        switch event {
        case .response: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[1]
        switch event {
        case let .data(data): try #require(data == httpBody)
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
        event = events[2]
        switch event {
        case .end: break
        default: try #require(Bool(false), "Wrong event type: \(event)")
        }
    }

    // MARK: - TRANSFER-ENCODING: CHUNKED

    @Suite
    struct Chunked {
        @Test(.tags(.httpParser))
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
            let parser = HTTPResponseParser()
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

        @Test(.tags(.httpParser))
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
            let parser = HTTPResponseParser()
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

        @Test(.tags(.httpParser))
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
            let parser = HTTPResponseParser()
            var events = try parser.append(httpMessageData)
            try #require(events.count == 1)
            try #require(events[0].response != nil)
            do {
                events = try parser.append(httpChunk1)
                throw TestError.unexpectedEntrance
            } catch HTTPResponseParser.Error.invalidChunkSize {
            } catch { throw error }
        }

        @Test(.tags(.httpParser))
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
            let parser = HTTPResponseParser()
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

        @Test(.tags(.httpParser))
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
            let parser = HTTPResponseParser()
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

        @Test(.tags(.httpParser))
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
            let parser = HTTPResponseParser()
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

        @Test(.tags(.httpParser))
        func newChunksAfterEndOne_Splitted_ThrowsParsingCompletedError() throws {
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
            let parser = HTTPResponseParser()
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

        @Test(.tags(.httpParser))
        func newChunksAfterEndOne_Full_NotThrowsError() throws {
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
            let data = httpMessageData + httpChunk1 + httpChunk2 + httpChunk3
            let parser = HTTPResponseParser()
            let events = try parser.append(data)
            try #require(events.count == 3)
            try #require(events[0].response != nil)
            try #require(events[1].data != nil)
            try #require(events[2].isEnd)
        }
    }

    struct Entities {
        @Test(.tags(.httpParser))
        func eventNonEnd_IsEndProperty_ReturnsFalse() throws {
            let event = HTTPResponseParser.Event.data(Data())
            try #require(event.isEnd == false)
        }

        @Test(.tags(.httpParser))
        func eventEnd_IsEndProperty_ReturnsTrue() throws {
            let event = HTTPResponseParser.Event.end
            try #require(event.isEnd == true)
        }

        @Test(.tags(.httpParser))
        func eventNonData_DataProperty_ReturnsNil() throws {
            let event = HTTPResponseParser.Event.end
            try #require(event.data == nil)
        }

        @Test(.tags(.httpParser))
        func eventData_DataProperty_ReturnsCorrectValue() throws {
            let data = Data("Hello".utf8)
            let event = HTTPResponseParser.Event.data(data)
            try #require(event.data == data)
        }

        @Test(.tags(.httpParser))
        func eventNonResponse_ResponseProperty_ReturnsNil() throws {
            let event = HTTPResponseParser.Event.end
            try #require(event.response == nil)
        }

        @Test(.tags(.httpParser))
        func eventResponse_ResponseProperty_ReturnsCorrectValue() throws {
            let response = HTTPParserResponseResult(
                versionRaw: "HTTP/1.1",
                status: 301,
                headers: ["Content": "123"],
                rawSize: 123,
                leftBuffer: Data("heelo".utf8)
            )
            let event = HTTPResponseParser.Event.response(response)
            try #require(event.response == response)
        }
    }
}

