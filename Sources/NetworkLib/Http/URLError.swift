import Foundation
import Network

extension URLError {
    enum Phase: String, Sendable {
        case common
        case scheduling
        case connecting
        case sending
        case receiving
        case parsing
    }

    init(orUpdate anyError: Error, for request: URLRequest, phase: Phase = .common) {
        if let error = anyError as? URLError {
            self = error._updating(with: request, phase: phase, underlyingError: nil)
        } else if let error = anyError as? NWError {
            self = URLError(error.urlErrorCode)._updating(with: request, phase: phase, underlyingError: error)
        } else {
            self = URLError(.unknown)._updating(with: request, phase: phase, underlyingError: anyError)
        }
    }

    private func _updating(with request: URLRequest, phase: Phase, underlyingError: Error?) -> URLError {
        var userInfo = self.userInfo
        if let url = request.url {
            userInfo[NSURLErrorFailingURLErrorKey] = url as NSURL
            userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString
            userInfo[NSURLErrorKey] = url as NSURL
        }
        if let underlyingError {
            userInfo[NSUnderlyingErrorKey] = underlyingError
        }
        userInfo[HTTPTaskErrorInfoKey.phase] = phase.rawValue
        return URLError(code, userInfo: userInfo)
    }
}
