import Foundation

/// - warning: This class must be used synchronously.
final class HTTPResponseParser: @unchecked Sendable {
    public enum Event: Sendable {
        case response(HTTPURLResponse)
        case data(Data)
    }

    private let url: URL
    private var buffer: Data
    private var parsedResponse: HTTPURLResponse?

    public init(with url: URL) {
        self.url = url
        buffer = Data()
    }

    public func append(_ data: Data) -> [Event] {
        buffer.append(data)
        var result: [Event] = []
        while let nextEvent = tryParseNext() {
            result.append(nextEvent)
        }
        return result
    }

    private func tryParseNext() -> Event? {
        if parsedResponse == nil {
            guard let response = parseResponse() else { return nil }
            parsedResponse = response
            return .response(response)
        }
        guard !buffer.isEmpty else { return nil }
        let data = buffer
        buffer = Data()
        return .data(data)
    }

    private func parseResponse() -> HTTPURLResponse? {
        guard let crlfEndIndex = findCRLF() else { return nil }
        let http = buffer.subdata(in: buffer.startIndex..<crlfEndIndex)
        buffer = buffer.dropFirst(http.count)
        return http.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            guard let message = createHTTPMesage(from: pointer) else { return nil }
            let headers = parseHeaders(from: message)
            let code = CFHTTPMessageGetResponseStatusCode(message)
            let versionRaw = CFHTTPMessageCopyVersion(message).takeRetainedValue() as String
            return HTTPURLResponse(url: url, statusCode: code, httpVersion: versionRaw, headerFields: headers)
        }
    }

    private func createHTTPMesage(from pointer: UnsafeRawBufferPointer) -> CFHTTPMessage? {
        let count = pointer.count
        guard let p = pointer.bindMemory(to: UInt8.self).baseAddress else { return nil }
        let message = CFHTTPMessageCreateEmpty(nil, false).takeRetainedValue()
        guard CFHTTPMessageAppendBytes(message, p, count) else { return nil }
        return message
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

    private func findCRLF() -> Data.Index? {
        guard let range = buffer.firstRange(of: Data.headerTerminator) else { return nil }
        return range.upperBound
    }
}

private extension Data {
    static let headerTerminator: Data = Data("\r\n\r\n".utf8)
}
