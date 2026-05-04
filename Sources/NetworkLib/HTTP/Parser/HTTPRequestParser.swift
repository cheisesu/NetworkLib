import Foundation
import Network

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
        if version == .v1_1, urlRequest.value(forHTTPHeaderField: "Host") == nil {
            urlRequest.setValue(urlRequest.url?.wrappedHost, forHTTPHeaderField: "Host")
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

    public init(connectTo host: NWEndpoint.Host, _ port: NWEndpoint.Port?, headers: [String: String]) {
        let target = if let port {
            [host.asUrlString, String(port.rawValue)].joined(separator: ":")
        } else {
            host.asUrlString
        }
        let version = ["HTTP", HTTPVersion.v1_1.rawValue].joined(separator: "/")
        let startLine = ["CONNECT", target, version].joined(separator: " ")
        var headers = headers
        headers["Host"] = target
        let headersPairs = headers
            .map { ($0.key, $0.value) }
            .sorted(by: { $0.0 < $1.0 })
            .map { [$0.0, $0.1].joined(separator: ": ") }
        let lines = [startLine] + headersPairs + ["", ""]
        parsedData = Data(lines.joined(separator: "\r\n").utf8)
    }
}
