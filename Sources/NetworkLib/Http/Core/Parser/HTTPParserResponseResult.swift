import Foundation

struct HTTPParserResponseResult: Sendable, Equatable {
    let versionRaw: String
    let status: Int
    let headers: [HTTPHeaderKey: String]
    let rawSize: Int
    let leftBuffer: Data

    func urlResponse(with url: URL) -> HTTPURLResponse? {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: versionRaw,
            headerFields: headers.rawFields
        )
    }
}
