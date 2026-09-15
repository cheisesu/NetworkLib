import Foundation
import Network

extension NWError {
    var urlErrorCode: URLError.Code {
        switch self {
        case let .posix(code): return code.urlErrorCode
        case .dns: return .cannotFindHost
        case .tls: return .secureConnectionFailed
        default: return .unknown
        }
    }
}
