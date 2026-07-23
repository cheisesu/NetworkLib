import Foundation
import Network
@testable import NetworkLib

typealias ReceiveCycleBlock = @Sendable (_ result: Result<Data?, NWError>, _ shouldContinue: inout Bool) -> Void

extension RawSocket {
    @discardableResult
    func testableConnect(_ timeout: Duration = .seconds(1),
                         forceTimeout: Duration = .milliseconds(1500)) async throws -> ConnectionInfo
    {
        try await withAsyncTimeoutForceThrowingContinuation(timeout, forceTimeout: forceTimeout) { continuation, cancel in
            self.connect { result in
                cancel()
                continuation.resume(with: result)
            }
        } onCancel: {
            self.cancel(nil)
        }
    }

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

    func receiveCycle(_ onNext: @escaping ReceiveCycleBlock) {
        self.receiveNext { (result: Result<Data?, NWError>) in
            var shouldContinue: Bool = true
            onNext(result, &shouldContinue)
            if shouldContinue {
                self.receiveCycle(onNext)
            }
        }
    }
}
