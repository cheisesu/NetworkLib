import Foundation
import Network

extension Error {
    var urlErrorCode: URLError.Code {
        if let error = self as? URLError { return error.code }
        guard let error = self as? NWError else { return .unknown }
        return error.urlErrorCode
    }
}
