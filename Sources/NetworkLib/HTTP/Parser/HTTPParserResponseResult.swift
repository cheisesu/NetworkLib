import Foundation

struct HTTPParserResponseResult: Sendable, Equatable {
    public let versionRaw: String
    public let status: Int
    public let headers: [HTTPHeaderKey: String]
    public let rawSize: Int
    public let leftBuffer: Data

    public func urlResponse(with url: URL) -> HTTPURLResponse? {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: versionRaw,
            headerFields: headers.rawFields
        )
    }
}

extension HTTPParserResponseResult: CustomStringConvertible {
    public var description: String {
        var lines: [String] = [
            "HTTPParserResponseResult (" + String(rawSize) + "b) {",
            ["\tVersion", versionRaw].joined(separator: ": "),
            ["\tStatus", String(status)].joined(separator: ": "),
        ]
        if !headers.isEmpty {
            lines.append("\tHeaders:")
            for (key, value) in headers {
                lines.append("\t\t" + key.rawValue + ": " + value)
            }
        }
        lines.append("\tLeft buffer: " + String(leftBuffer.count) + "b")
        lines.append("}")
        return lines.joined(separator: "\n")
    }
}
