import Foundation

extension URLRequest {
    func startLine(_ version: HTTPVersion) -> String {
        let method = httpMethod?.uppercased() ?? "GET"
        let path = if #available(macOS 13.0, *) {
            url?.path() ?? "/"
        } else {
            url?.path ?? "/"
        }
        let query = if #available(macOS 13.0, *) {
            url?.query()
        } else {
            url?.query
        }
        let target = [path, query].compactMap { $0 }.joined(separator: "?")
        let version = ["HTTP", version.rawValue].joined(separator: "/")
        return [method, target, version].joined(separator: " ")
    }
}
