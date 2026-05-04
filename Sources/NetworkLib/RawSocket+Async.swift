import Foundation

extension RawSocket {
    @discardableResult
    public func connect() async throws -> ConnectionInfo {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                connect { result in
                    continuation.resume(with: result)
                }
            }
        } onCancel: { [weak self] in
            self?.cancel(nil)
        }
    }
    
    public func send(_ data: Data) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                send(data) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } onCancel: { [weak self] in
            self?.cancel(nil)
        }
    }
    
    public func sendMessage<M: RawSocketSendMessage>(_ message: M) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                sendMessage(message) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } onCancel: { [weak self] in
            self?.cancel(nil)
        }
    }
    
    public func receiveNext() async throws -> Data? {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                receiveNext { result in
                    continuation.resume(with: result)
                }
            }
        } onCancel: { [weak self] in
            self?.cancel(nil)
        }
    }
    
    public func receiveNextMessage<M: RawSocketReceiveMessage>(of type: M.Type = M.self) async throws -> M {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                receiveNextMessage(of: M.self) { result in
                    continuation.resume(with: result)
                }
            }
        } onCancel: { [weak self] in
            self?.cancel(nil)
        }
    }
    
    public func cancel() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            cancel {
                continuation.resume()
            }
        }
    }
}

