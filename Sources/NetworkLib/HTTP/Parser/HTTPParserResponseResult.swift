import Foundation

/// The parsed HTTP response head produced from raw response bytes.
///
/// For example, convert a parsed response head into Foundation's response type:
///
/// ```swift
/// func handle(_ parsed: HTTPParserResponseResult, url: URL) {
///     if let response = parsed.urlResponse(with: url) {
///         print(response.statusCode)
///     }
/// }
/// ```
public struct HTTPParserResponseResult: Sendable, Equatable {
    /// The raw HTTP version string returned by `CFHTTPMessage`, such as `HTTP/1.1`.
    public let versionRaw: String

    /// The numeric HTTP response status code.
    public let status: Int

    /// The parsed response headers keyed by typed HTTP header names.
    public let headers: [HTTPHeaderKey: String]

    /// Size of HTTP message with `\r\n\r\n` terminator in raw data.
    public let rawSize: Int

    /// Bytes that were received after the response header terminator and were not consumed by the raw header parser.
    public let leftBuffer: Data

    /// Creates a Foundation response value for the supplied URL.
    ///
    /// - Parameter url: The URL associated with the parsed response.
    /// - Returns: An `HTTPURLResponse` built from the parsed status, version, and headers, or `nil` if Foundation rejects the values.
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
    /// A multiline debug representation of the parsed response head and any remaining buffered bytes.
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
