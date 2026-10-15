import Foundation

/// HTTP authorization credentials that NetworkLib can apply to an HTTP CONNECT proxy.
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
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public enum HTTPAuthorization: Sendable, Equatable {
    /// Basic authentication credentials rendered as `Basic ` followed by Base64-encoded `userName:password` bytes.
    ///
    /// - Parameters:
    ///   - userName: The user name included in the credential.
    ///   - password: The password included in the credential.
    ///
    /// Basic authentication encodes credentials but doesn't encrypt them. Use a secure proxy connection when credentials need
    /// transport confidentiality.
    case basic(userName: String, password: String)

    var httpHeader: String {
        switch self {
        case let .basic(username, password):
            let encoded = Data("\(username):\(password)".utf8).base64EncodedString()
            return ["Basic", encoded].joined(separator: " ")
        }
    }
}
