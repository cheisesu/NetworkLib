import Foundation

extension POSIXErrorCode {
    var urlErrorCode: URLError.Code {
        switch self {
        case .ECANCELED: return .cancelled
        case .ETIMEDOUT: return .timedOut
        case .ECONNREFUSED, .EHOSTUNREACH, .ENETUNREACH: return .cannotConnectToHost
        case .ECONNRESET, .ECONNABORTED, .EPIPE: return .networkConnectionLost
        case .ENOTCONN: return .notConnectedToInternet
        case .EAUTH, .EACCES: return .userAuthenticationRequired
        case .EBADMSG, .EPROTO, .EIO, .EINVAL: return .cannotParseResponse
        case .ENOTSUP: return .unsupportedURL
        default: return .unknown
        }
    }
}
