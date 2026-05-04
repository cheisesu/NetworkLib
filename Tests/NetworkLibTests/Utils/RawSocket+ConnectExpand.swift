import Foundation
@testable import NetworkLib

extension RawSocket {
    func connect(_ block: @escaping @Sendable (ConnectionInfo?, Error?) -> Void) {
        self.connect { result in
            switch result {
            case let .failure(error): block(nil, error)
            case let .success(info): block(info, nil)
            }
        }
    }

    func receiveNext(_ block: @escaping @Sendable (Data?, Error?) -> Void) {
        self.receiveNext { result in
            switch result {
            case let .failure(error): block(nil, error)
            case let .success(data): block(data, nil)
            }
        }
    }
}
