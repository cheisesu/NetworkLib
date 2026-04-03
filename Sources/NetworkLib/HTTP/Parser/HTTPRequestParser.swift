import Foundation

final class HTTPRequestParser: Sendable {
    public let parsedData: Data

    public init(_ urlRequest: URLRequest, version: HTTPVersion = .v1_1) {
        var urlRequest = urlRequest
        let startLine = urlRequest.httpStartLine(version)
        var lines = [startLine]
        let body = urlRequest.httpBody ?? Data()
        if !body.isEmpty {
            urlRequest.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        }
        let headers = urlRequest.allHTTPHeaderFields?.map { (key: String, value: String) in
            (key, value)
        }.sorted(by: { $0.0 < $1.0 }) ?? []
        for (key, value) in headers {
            let line = [key, value].joined(separator: ": ")
            lines.append(line)
        }
        lines.append("")
        lines.append("")
        let headerData = Data(lines.joined(separator: "\r\n").utf8)
        parsedData = Data([headerData, urlRequest.httpBody].compactMap { $0 }.joined())
    }
}
