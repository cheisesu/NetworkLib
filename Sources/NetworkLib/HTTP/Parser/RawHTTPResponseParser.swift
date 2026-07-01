import Foundation

struct RawHTTPResponseParser: Sendable {
    private var buffer: Data
    private var lastResult: HTTPParserResponseResult?

    /// A Boolean value indicating whether this parser has already produced a response result.
    public var isCompleted: Bool { lastResult != nil }

    /// Creates an empty raw HTTP response-head parser.
    ///
    /// For example, create a parser before feeding response bytes from a connection:
    ///
    /// ```swift
    /// var parser = RawHTTPResponseParser()
    /// parser.append(responseBytes)
    /// let response = parser.tryParse()
    /// ```
    public init() {
        buffer = Data()
        lastResult = nil
    }

    /// Appends bytes to the parser buffer while parsing is incomplete.
    ///
    /// Bytes appended after a response has been parsed are ignored.
    ///
    /// - Parameter data: Raw bytes received from the connection.
    public mutating func append(_ data: Data) {
        guard !isCompleted else { return }
        buffer.append(contentsOf: data)
    }

    /// Attempts to parse the buffered bytes as an HTTP response head.
    ///
    /// Parsing succeeds only after the buffer contains the `\r\n\r\n` header terminator. Any bytes after that terminator are
    /// returned as ``HTTPParserResponseResult/leftBuffer``.
    ///
    /// For example, keep appending bytes until a response head is available:
    ///
    /// ```swift
    /// parser.append(nextChunk)
    /// if let response = parser.tryParse() {
    ///     print(response.headers)
    /// }
    /// ```
    ///
    /// - Returns: The parsed response head, or `nil` when more bytes are needed.
    public mutating func tryParse() -> HTTPParserResponseResult? {
        guard let crlfEndIndex = findCRLF()?.upperBound else { return nil }
        let http = buffer.subdata(in: buffer.startIndex..<crlfEndIndex)
        let message = createHTTPMesage(from: http)
        let headers = parseHeaders(from: message)
        let status = CFHTTPMessageGetResponseStatusCode(message)
        let versionRaw = CFHTTPMessageCopyVersion(message).takeRetainedValue() as String
        let leftBuffer = Data(buffer.dropFirst(http.count))
        lastResult = HTTPParserResponseResult(versionRaw: versionRaw, status: status, headers: headers, rawSize: http.count, leftBuffer: leftBuffer)
        return lastResult
    }

    private func findCRLF() -> Range<Data.Index>? {
        buffer.firstRange(of: Data.headerTerminator)
    }

    private func createHTTPMesage(from http: Data) -> CFHTTPMessage {
        return http.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            let count = pointer.count
            let p = pointer.bindMemory(to: UInt8.self).baseAddress!
            let message = CFHTTPMessageCreateEmpty(nil, false).takeRetainedValue()
            CFHTTPMessageAppendBytes(message, p, count)
            return message
        }
    }

    private func parseHeaders(from message: CFHTTPMessage) -> [HTTPHeaderKey: String] {
        let nsHeaders = CFHTTPMessageCopyAllHeaderFields(message)?.takeRetainedValue() as? NSDictionary ?? [:]
        var result: [HTTPHeaderKey: String] = [:]
        for (key, value) in nsHeaders {
            guard let rawKey = key as? String, let value = value as? String else { continue }
            result[.init(rawKey)] = value
        }
        return result
    }
}

extension RawHTTPResponseParser {
    static func parse(_ data: Data) -> HTTPParserResponseResult? {
        var parser = RawHTTPResponseParser()
        parser.append(data)
        return parser.tryParse()
    }
}

extension Data {
    static let crlf: Data = Data("\r\n".utf8)
    static let headerTerminator: Data = Data(Data.crlf + Data.crlf)
}
