import Foundation

extension HTTPResponseParser {
    /// Events emitted while incrementally parsing an HTTP response.
    ///
    /// For example, switch over events returned from ``HTTPResponseParser/append(_:)``:
    ///
    /// ```swift
    /// for event in events {
    ///     switch event {
    ///     case .response(let response): print(response.status)
    ///     case .data(let data): print(data.count)
    ///     case .end: print("complete")
    ///     }
    /// }
    /// ```
    public enum Event: Sendable {
        /// The response head, including status, version, and headers, has been parsed.
        case response(HTTPParserResponseResult)

        /// A body data fragment has been parsed.
        case data(Data)

        /// The parser reached the end of the response body.
        case end

        /// A Boolean value indicating whether this event marks the end of the response body.
        public var isEnd: Bool {
            switch self {
            case .end: return true
            default: return false
            }
        }

        /// The parsed response head when this event is ``response(_:)``.
        public var response: HTTPParserResponseResult? {
            guard case let .response(response) = self else { return nil }
            return response
        }

        /// The parsed body fragment when this event is ``data(_:)``.
        public var data: Data? {
            guard case let .data(data) = self else { return nil }
            return data
        }
    }

    /// Errors that can occur while parsing an HTTP response body.
    public enum Error: Swift.Error, Sendable {
        /// A chunked-transfer chunk size line could not be parsed as hexadecimal.
        case invalidChunkSize

        /// A chunk body was not followed by the required CRLF terminator.
        case invalidChunkTerminator

        /// Additional data was appended after the parser had already emitted an end event.
        case parsingCompleted
    }
}

extension HTTPResponseParser.Event: CustomStringConvertible {
    /// A short debug description of the parser event.
    public var description: String {
        switch self {
        case let .response(response): return "RESPONSE: \(response)"
        case let .data(data): return "DATA: \(data.count)"
        case .end: return "END"
        }
    }
}

/// - warning: This class must be used synchronously.
final class HTTPResponseParser: @unchecked Sendable {
    private enum BodyKind {
        case none
        case plain
        case chunked
        case finished
    }

    private var currentBuffer: Data
    private var fullDataBuffer: Data
    private var parsedResponse: HTTPParserResponseResult?
    private var bodyKind: BodyKind

    /// Creates an empty incremental HTTP response parser.
    public init() {
        currentBuffer = Data()
        fullDataBuffer = Data()
        bodyKind = .none
    }

    /// Appends bytes and returns every parser event that can be produced from the current buffer.
    ///
    /// The parser first emits a response event after the full response head is available. It then emits data events for either
    /// `Content-Length` bodies or `Transfer-Encoding: chunked` bodies, followed by an end event when the body is complete.
    ///
    /// For example, feed bytes as they arrive and handle every produced event:
    ///
    /// ```swift
    /// let parser = HTTPResponseParser()
    /// let events = try parser.append(receivedData)
    /// for event in events where event.isEnd {
    ///     print("response complete")
    /// }
    /// ```
    ///
    /// - Parameter data: The next bytes received from the connection.
    /// - Returns: Parser events produced by the appended bytes. The array is empty when more bytes are needed.
    /// - Throws: ``HTTPResponseParser/Error`` when the response body framing is invalid or parsing has already completed.
    public func append(_ data: Data) throws(HTTPResponseParser.Error) -> [Event] {
        guard bodyKind != .finished else { throw .parsingCompleted }
        currentBuffer.append(data)
        var result: [Event] = []
        while let nextEvent = try parseNext() {
            result.append(nextEvent)
        }
        return result
    }

    private func parseNext() throws(HTTPResponseParser.Error) -> Event? {
        guard bodyKind != .finished else { return nil }
        guard let parsedResponse else {
            guard let response = parseResponse() else { return nil }
            self.parsedResponse = response
            return .response(response)
        }
        if isChunked() {
            return try parseChunkedEncoding()
        } else {
            return try parsePlainEncoding(parsedResponse)
        }
    }

    private func parseResponse() -> HTTPParserResponseResult? {
        guard var result = RawHTTPResponseParser.parse(currentBuffer) else { return nil }
        currentBuffer = result.leftBuffer
        result = HTTPParserResponseResult(
            versionRaw: result.versionRaw,
            status: result.status,
            headers: result.headers,
            rawSize: result.rawSize,
            leftBuffer: Data()
        )
        return result
    }

    private func parseChunkedEncoding() throws(HTTPResponseParser.Error) -> Event? {
        bodyKind = .chunked
        guard let sizeRange = currentBuffer.range(of: .crlf) else { return nil }
        let sizeData = currentBuffer.subdata(in: currentBuffer.startIndex..<sizeRange.lowerBound)
        guard let sizeString = String(data: sizeData, encoding: .utf8), let size = Int(sizeString, radix: 16) else {
            throw .invalidChunkSize
        }
        let leftChunkBuffer = currentBuffer.suffix(from: sizeRange.upperBound)
        guard leftChunkBuffer.count >= size + Data.crlf.count else { return nil }
        let chunkData = leftChunkBuffer.subdata(in: leftChunkBuffer.startIndex..<(leftChunkBuffer.startIndex + size))
        let leftBuffer = Data(leftChunkBuffer[(leftChunkBuffer.startIndex + size)...])
        guard leftBuffer.prefix(Data.crlf.count) == .crlf else { throw .invalidChunkTerminator }
        currentBuffer = leftBuffer.dropFirst(Data.crlf.count)
        if size == 0 {
            bodyKind = .finished
            return .end
        }
        fullDataBuffer.append(contentsOf: chunkData)
        return .data(Data(chunkData))
    }

    private func parsePlainEncoding(_ response: HTTPParserResponseResult) throws(HTTPResponseParser.Error) -> Event? {
        bodyKind = .plain
        let contentLength = if let lengthRaw = response.headers[.contentLength] {
            Int(lengthRaw) ?? 0
        } else {
            0
        }
        guard contentLength > 0 else {
            bodyKind = .finished
            return .end
        }
        let alreadySentData = fullDataBuffer
        guard contentLength > alreadySentData.count else {
            bodyKind = .finished
            return .end
        }
        guard !currentBuffer.isEmpty else { return nil }
        let leftToSendCount = contentLength - alreadySentData.count
        if leftToSendCount >= currentBuffer.count {
            fullDataBuffer.append(contentsOf: currentBuffer)
            let data = currentBuffer
            currentBuffer = Data()
            return .data(data)
        } else {
            let cuttedCurrentBuffer = Data(currentBuffer.prefix(leftToSendCount))
            fullDataBuffer.append(contentsOf: cuttedCurrentBuffer)
            currentBuffer = currentBuffer.dropFirst(leftToSendCount)
            return .data(cuttedCurrentBuffer)
        }
    }

    private func isChunked() -> Bool {
        parsedResponse?.transferEncodings.contains("chunked") == true
    }
}

private extension HTTPParserResponseResult {
    var transferEncodings: [String] {
        guard let header = headers[.transferEncoding] else { return [] }
        return header
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}
