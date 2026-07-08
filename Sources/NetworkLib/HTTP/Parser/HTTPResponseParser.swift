import Foundation

extension HTTPResponseParser {
    enum Event: Sendable {
        case response(HTTPParserResponseResult)
        case data(Data)
        case end

        var isEnd: Bool {
            switch self {
            case .end: return true
            default: return false
            }
        }

        var response: HTTPParserResponseResult? {
            guard case let .response(response) = self else { return nil }
            return response
        }

        var data: Data? {
            guard case let .data(data) = self else { return nil }
            return data
        }
    }

    enum Error: Swift.Error, Sendable {
        case invalidChunkSize
        case invalidChunkTerminator
        case parsingCompleted
    }
}

extension HTTPResponseParser.Event: CustomStringConvertible {
    var description: String {
        switch self {
        case let .response(response): return "RESPONSE: \(response)"
        case let .data(data): return "DATA: \(data.count)"
        case .end: return "END"
        }
    }
}

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

    init() {
        currentBuffer = Data()
        fullDataBuffer = Data()
        bodyKind = .none
    }

    func append(_ data: Data) throws(HTTPResponseParser.Error) -> [Event] {
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
