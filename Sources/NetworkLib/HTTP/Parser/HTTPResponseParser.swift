import Foundation

/// - warning: This class must be used synchronously.
final class HTTPResponseParser: @unchecked Sendable {
    public enum Event: Sendable {
        case response(HTTPURLResponse)
        case data(Data)
        case end

        public var isEnd: Bool {
            switch self {
            case .end: return true
            default: return false
            }
        }

        public var response: HTTPURLResponse? {
            guard case let .response(response) = self else { return nil }
            return response
        }

        public var data: Data? {
            guard case let .data(data) = self else { return nil }
            return data
        }
    }

    public enum Error: Swift.Error, Sendable {
        case invalidChunkSize
        case invalidChunkTerminator
        case parsingCompleted
    }

    private enum BodyKind {
        case none
        case plain
        case chunked
        case finished
    }

    private let url: URL
    private var buffer: Data
    private var parsedResponse: HTTPURLResponse?
    private var bodyKind: BodyKind

    public init(with url: URL) {
        self.url = url
        buffer = Data()
        bodyKind = .none
    }

    public func append(_ data: Data) throws(Error) -> [Event] {
        guard bodyKind != .finished else { throw .parsingCompleted }
        buffer.append(data)
        var result: [Event] = []
        while let nextEvent = try parseNext() {
            result.append(nextEvent)
        }
        return result
    }

    private func parseNext() throws(Error) -> Event? {
        guard bodyKind != .finished else { return nil }
        if parsedResponse == nil {
            guard let response = parseResponse() else { return nil }
            parsedResponse = response
            return .response(response)
        }
        guard !buffer.isEmpty else { return nil }
        if isChunked() {
            return try parseChunkedEncoding()
        }
        bodyKind = .plain
        let data = buffer
        buffer = Data()
        return .data(data)
    }

    private func parseResponse() -> HTTPURLResponse? {
        guard let result = RawHTTPResponseParser.parse(buffer) else { return nil }
        buffer = result.leftBuffer
        return HTTPURLResponse(url: url, statusCode: result.status, httpVersion: result.versionRaw, headerFields: result.headers)
    }

    private func parseChunkedEncoding() throws(Error) -> Event? {
        bodyKind = .chunked
        guard let sizeRange = buffer.range(of: .crlf) else { return nil }
        let sizeData = buffer.subdata(in: buffer.startIndex..<sizeRange.lowerBound)
        guard let sizeString = String(data: sizeData, encoding: .utf8), let size = Int(sizeString, radix: 16) else {
            throw .invalidChunkSize
        }
        let leftChunkBuffer = buffer.suffix(from: sizeRange.upperBound)
        guard leftChunkBuffer.count >= size + Data.crlf.count else { return nil }
        let chunkData = leftChunkBuffer.subdata(in: leftChunkBuffer.startIndex..<(leftChunkBuffer.startIndex + size))
        let leftBuffer = Data(leftChunkBuffer[(leftChunkBuffer.startIndex + size)...])
        guard leftBuffer.prefix(Data.crlf.count) == .crlf else { throw .invalidChunkTerminator }
        buffer = leftBuffer.dropFirst(Data.crlf.count)
        if size == 0 {
            bodyKind = .finished
            return .end
        }
        return .data(Data(chunkData))
    }

    private func isChunked() -> Bool {
        parsedResponse?.transferEncodings.contains("chunked") == true
    }
}

private extension HTTPURLResponse {
    var transferEncodings: [String] {
        guard let header = value(forHTTPHeaderField: "Transfer-Encoding") else { return [] }
        return header
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}
