import Foundation

public enum HTTPAuthorization: Sendable, Equatable {
    case basic(userName: String, password: String)

    var httpHeader: String {
        switch self {
        case let .basic(username, password):
            let encoded = Data("\(username):\(password)".utf8).base64EncodedString()
            return ["Basic", encoded].joined(separator: " ")
        }
    }
}
