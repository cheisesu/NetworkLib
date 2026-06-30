import Foundation

extension URLRequest {
    func httpStartLine(_ version: HTTPVersion) -> String {
        let method = httpMethod?.uppercased() ?? "GET"
        let path = url?.wrappedPath ?? "/"
        let query = url?.wrappedQuery
        let target = [path, query].compactMap { $0 }.joined(separator: "?")
        let version = ["HTTP", version.rawValue].joined(separator: "/")
        return [method, target, version].joined(separator: " ")
    }
    
    func httpHostLine() -> String? {
        let hostOriginal = url?.wrappedHost
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
        return [HTTPHeaderKey.host.rawValue + ":", hostPort].joined(separator: " ")
    }
}
