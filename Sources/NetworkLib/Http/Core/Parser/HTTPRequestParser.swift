import Foundation
import Network

final class HTTPRequestParser: Sendable {
    let parsedData: Data

    init(_ urlRequest: URLRequest, version: HTTPVersion = .v1_1) {
        var urlRequest = urlRequest
        let startLine = urlRequest.httpStartLine(version)
        var lines = [startLine]
        let body = urlRequest.httpBody ?? Data()
        if !body.isEmpty {
            urlRequest.setValue(String(body.count), forHTTPHeaderField: .contentLength)
        }
        if version == .v1_1, urlRequest.value(forHTTPHeaderField: .host) == nil {
            urlRequest.setValue(urlRequest.url?.wrappedHost, forHTTPHeaderField: .host)
        }
        urlRequest.setValue("close", forHTTPHeaderField: .connection)
        // as headers are already set, fail on unwrap is unexpected and must be recorded
        let headers = urlRequest.allHTTPHeaderFields!.map { (key: String, value: String) in
            (key, value)
        }.sorted { lhs, rhs in
            let lhsIsHost = lhs.0.caseInsensitiveCompare(HTTPHeaderKey.host.rawValue) == .orderedSame
            let rhsIsHost = rhs.0.caseInsensitiveCompare(HTTPHeaderKey.host.rawValue) == .orderedSame
            return lhsIsHost == rhsIsHost ? lhs.0 < rhs.0 : lhsIsHost
        }
        for (key, value) in headers {
            let line = [key, value].joined(separator: ": ")
            lines.append(line)
        }
        lines.append("")
        lines.append("")
        let headerData = Data(lines.joined(separator: "\r\n").utf8)
        parsedData = Data([headerData, urlRequest.httpBody].compactMap { $0 }.joined())
    }

    convenience init(connectTo host: NWEndpoint.Host, _ port: NWEndpoint.Port?, headers: [String: String]) {
        let headers = headers.reduce(into: [HTTPHeaderKey: String]()) { partialResult, keyValue in
            partialResult[HTTPHeaderKey(keyValue.key)] = keyValue.value
        }
        self.init(connectTo: host, port, headerKeys: headers)
    }

    init(connectTo host: NWEndpoint.Host, _ port: NWEndpoint.Port?, headerKeys headers: [HTTPHeaderKey: String]) {
        let target = if let port {
            [host.asUrlString, String(port.rawValue)].joined(separator: ":")
        } else {
            host.asUrlString
        }
        let version = ["HTTP", HTTPVersion.v1_1.rawValue].joined(separator: "/")
        let startLine = ["CONNECT", target, version].joined(separator: " ")
        var headers = headers
        headers[.host] = target
        headers[.connection] = "close"
        let headersPairs = headers
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                let lhsIsHost = lhs.0 == .host
                let rhsIsHost = rhs.0 == .host
                return lhsIsHost == rhsIsHost ? lhs.0.rawValue < rhs.0.rawValue : lhsIsHost
            }
            .map { [$0.0.rawValue, $0.1].joined(separator: ": ") }
        let lines = [startLine] + headersPairs + ["", ""]
        parsedData = Data(lines.joined(separator: "\r\n").utf8)
    }
}
