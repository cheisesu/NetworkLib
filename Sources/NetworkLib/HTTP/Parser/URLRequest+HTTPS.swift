import Foundation

extension URLRequest {
    func httpStartLine(_ version: HTTPVersion) -> String {
        let method = httpMethod?.uppercased() ?? "GET"
        let path = if #available(macOS 13.0, iOS 16.0, *) {
            url?.path() ?? "/"
        } else {
            url?.path ?? "/"
        }
        let query = if #available(macOS 13.0, iOS 16.0, *) {
            url?.query()
        } else {
            url?.query
        }
        let target = [path, query].compactMap { $0 }.joined(separator: "?")
        let version = ["HTTP", version.rawValue].joined(separator: "/")
        return [method, target, version].joined(separator: " ")
    }
    
    func httpHostLine() -> String? {
        let hostOriginal = if #available(macOS 13.0, iOS 16.0, *) {
            url?.host()
        } else {
            url?.host
        }
        let host = if let ipV6 = hostOriginal?.asIPv6 {
            ipV6.asURLHostString
        } else if let ipV4 = hostOriginal?.asIPv4 {
            ipV4.asString
        } else {
            hostOriginal
        }
        guard let host else { return nil }
        let port = url?.port.map { String($0) }
        let hostPort = [host, port].compactMap { $0 }.joined(separator: ":")
        return ["Host:", hostPort].joined(separator: " ")
    }
}
