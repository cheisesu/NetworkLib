import Foundation
import Network

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
    public func connect() async throws(NWError) -> ConnectionInfo {
        try await withSocketCancellation { done in
            connect(done)
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
    public func send(_ data: Data) async throws(NWError) {
        try await withSocketCancellation { done in
            send(data, done)
        }
    }

    /// Sends a typed message with protocol metadata.
    ///
    /// If the surrounding task is cancelled while this operation is suspended, the socket is cancelled.
    ///
    /// - Parameter message: The typed message that supplies content and context.
    public func sendMessage<M: RawSocketSendMessage>(_ message: M) async throws(NWError) {
        try await withSocketCancellation { done in
            sendMessage(message, done)
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
    public func receiveNext() async throws(NWError) -> Data? {
        try await withSocketCancellation { done in
            receiveNext(done)
        }
    }

    /// Receives and decodes the next typed message.
    ///
    /// If the surrounding task is cancelled while this operation is suspended, the socket is cancelled.
    ///
    /// - Parameter type: The typed message to decode. The default is inferred from the return type.
    /// - Returns: The decoded message.
    public func receiveNextMessage<M: RawSocketReceiveMessage>(of type: M.Type = M.self) async throws(NWError) -> M {
        try await withSocketCancellation { done in
            receiveNextMessage(of: M.self, done)
        }
    }

    /// Cancels the socket and suspends until cancellation callbacks have been drained.
    public func cancel() async {
        await withCheckedContinuation { continuation in
            cancel {
                continuation.resume()
            }
        }
    }
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
private extension RawSocket {
    func withSocketCancellation<T: Sendable>(
        _ operation: (@escaping @Sendable (_ done: Result<T, NWError>) -> Void) -> Void
    ) async throws(NWError) -> T {
        try await withTaskCancellationHandler { () async throws(NWError) -> T in
            try await withCheckedThrowingContinuation { continuation in
                operation { result in
                    continuation.resume(with: result)
                }
            }
        } onCancel: { [weak self] in
            self?.cancel(nil)
        }
    }
}
