import Foundation

/// HTTP authorization credentials that can be rendered into an HTTP authentication header.
///
/// For example, use a basic credential when configuring an HTTP CONNECT proxy:
///
/// ```swift
/// let authorization = HTTPAuthorization.basic(userName: "user", password: "secret")
/// let proxy = RawSocketConfiguration.Proxy(
///     host: "proxy.example.com",
///     port: 8080,
///     authorization: authorization
/// )
/// ```
public enum HTTPAuthorization: Sendable, Equatable {
    /// Basic authentication credentials encoded as `username:password` using Base64.
    case basic(userName: String, password: String)

    var httpHeader: String {
        switch self {
        case let .basic(username, password):
            let encoded = Data("\(username):\(password)".utf8).base64EncodedString()
            return ["Basic", encoded].joined(separator: " ")
        }
    }
}
