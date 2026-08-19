import Foundation

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
extension RawSocket {
    /// Starts the underlying network connection and returns connection details when it becomes ready.
    ///
    /// If the surrounding task is cancelled while this operation is suspended, the socket is cancelled.
    ///
    /// For example, connect and inspect the selected endpoint:
    ///
    /// ```swift
    /// let info = try await socket.connect()
    /// print(info.remoteEndpoint)
    /// ```
    ///
    /// - Returns: Information about the established connection.
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

    /// Sends raw bytes on the socket.
    ///
    /// If the surrounding task is cancelled while this operation is suspended, the socket is cancelled.
    ///
    /// For example, send a small payload:
    ///
    /// ```swift
    /// try await socket.send(Data("hello".utf8))
    /// ```
    ///
    /// - Parameter data: The bytes to send.
    public func send(_ data: Data) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                send(data) { result in
                    continuation.resume(with: result)
                }
            }
        } onCancel: { [weak self] in
            self?.cancel(nil)
        }
    }

    /// Sends a typed message with protocol metadata.
    ///
    /// If the surrounding task is cancelled while this operation is suspended, the socket is cancelled.
    ///
    /// - Parameter message: The typed message that supplies content and context.
    public func sendMessage<M: RawSocketSendMessage>(_ message: M) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                sendMessage(message) { result in
                    continuation.resume(with: result)
                }
            }
        } onCancel: { [weak self] in
            self?.cancel(nil)
        }
    }

    /// Receives the next available raw data block.
    ///
    /// If the surrounding task is cancelled while this operation is suspended, the socket is cancelled.
    ///
    /// For example, receive one block of data:
    ///
    /// ```swift
    /// if let data = try await socket.receiveNext() {
    ///     print(data.count)
    /// }
    /// ```
    ///
    /// - Returns: The next data block, or `nil` when the connection completes cleanly with no more data.
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

    /// Receives and decodes the next typed message.
    ///
    /// If the surrounding task is cancelled while this operation is suspended, the socket is cancelled.
    ///
    /// - Parameter type: The typed message to decode. The default is inferred from the return type.
    /// - Returns: The decoded message.
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

    /// Cancels the socket and suspends until cancellation callbacks have been drained.
    public func cancel() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            cancel {
                continuation.resume()
            }
        }
    }
}
