import Foundation

struct RawHTTPResponseParser: Sendable {
    public struct Result: Sendable {
        public let versionRaw: String
        public let status: Int
        public let headers: [String: String]
        /// Size of HTTP message with `\r\n\r\n` terminator in raw data.
        public let rawSize: Int
        public let leftBuffer: Data
    }
    private var buffer: Data
    private var lastResult: Result?

    public var isCompleted: Bool { lastResult != nil }

    public init() {
        buffer = Data()
        lastResult = nil
    }

    public mutating func append(_ data: Data) {
        guard !isCompleted else { return }
        buffer.append(contentsOf: data)
    }

    public mutating func tryParse() -> Result? {
        guard let crlfEndIndex = findCRLF()?.upperBound else { return nil }
        let http = buffer.subdata(in: buffer.startIndex..<crlfEndIndex)
        let message = createHTTPMesage(from: http)
        let headers = parseHeaders(from: message)
        let status = CFHTTPMessageGetResponseStatusCode(message)
        let versionRaw = CFHTTPMessageCopyVersion(message).takeRetainedValue() as String
        let leftBuffer = Data(buffer.dropFirst(http.count))
        lastResult = Result(versionRaw: versionRaw, status: status, headers: headers, rawSize: http.count, leftBuffer: leftBuffer)
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

    private func parseHeaders(from message: CFHTTPMessage) -> [String: String] {
        let nsHeaders = CFHTTPMessageCopyAllHeaderFields(message)?.takeRetainedValue() as? NSDictionary ?? [:]
        var result: [String: String] = [:]
        for (key, value) in nsHeaders {
            guard let key = key as? String, let value = value as? String else { continue }
            result[key] = value
        }
        return result
    }
}

extension RawHTTPResponseParser {
    static func parse(_ data: Data) -> Result? {
        var parser = RawHTTPResponseParser()
        parser.append(data)
        return parser.tryParse()
    }
}

extension Data {
    static let crlf: Data = Data("\r\n".utf8)
    static let headerTerminator: Data = Data(Data.crlf + Data.crlf)
}
