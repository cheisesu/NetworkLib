import Foundation

/// HTTP authorization credentials that can be rendered into an HTTP authentication header.
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
