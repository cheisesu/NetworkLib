import Foundation

public struct RawHTTPResponseParser: Sendable {
    private var buffer: Data
    private var lastResult: HTTPParserResponseResult?

    public var isCompleted: Bool { lastResult != nil }

    public init() {
        buffer = Data()
        lastResult = nil
    }

    public mutating func append(_ data: Data) {
        guard !isCompleted else { return }
        buffer.append(contentsOf: data)
    }

    public mutating func tryParse() -> HTTPParserResponseResult? {
        guard let crlfEndIndex = findCRLF()?.upperBound else { return nil }
        let http = buffer.subdata(in: buffer.startIndex..<crlfEndIndex)
        let message = createHTTPMesage(from: http)
        let headers = parseHeaders(from: message)
        let status = CFHTTPMessageGetResponseStatusCode(message)
        let versionRaw = CFHTTPMessageCopyVersion(message).takeRetainedValue() as String
        let leftBuffer = Data(buffer.dropFirst(http.count))
        lastResult = HTTPParserResponseResult(versionRaw: versionRaw, status: status, headers: headers,
                                              rawSize: http.count, leftBuffer: leftBuffer)
        return lastResult
    }

    private func findCRLF() -> Range<Data.Index>? {
        buffer.firstRange(of: Data.headerTerminator)
    }

    private func createHTTPMesage(from http: Data) -> CFHTTPMessage {
        return http.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            let count = pointer.count
            let bytesPointer = pointer.bindMemory(to: UInt8.self).baseAddress!
            let message = CFHTTPMessageCreateEmpty(nil, false).takeRetainedValue()
            CFHTTPMessageAppendBytes(message, bytesPointer, count)
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
    public static func parse(_ data: Data) -> HTTPParserResponseResult? {
        var parser = RawHTTPResponseParser()
        parser.append(data)
        return parser.tryParse()
    }
}

extension Data {
    static let crlf: Data = Data("\r\n".utf8)
    static let headerTerminator: Data = Data(Data.crlf + Data.crlf)
}
