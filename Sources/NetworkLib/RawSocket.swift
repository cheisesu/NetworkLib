import Foundation
import Network

/// Information reported when a ``RawSocket`` successfully establishes a connection.
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public struct ConnectionInfo: Sendable, Equatable {
    /// The transport protocol used by the connection.
    public let transport: RawSocketTransport

    /// The remote endpoint that the socket was configured to connect to.
    public let remoteEndpoint: NWEndpoint

    /// The local endpoint selected by the system, when it is available from the current network path.
    public let localEndpoint: NWEndpoint?

    /// The network interface selected by the system, when it is available from the current network path.
    public let interface: NWInterface?
}

/// A typed outbound message that can be sent through a ``RawSocket`` message send operation.
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public protocol RawSocketSendMessage: Sendable {
    /// The Network framework content context that carries protocol metadata for the message.
    var context: NWConnection.ContentContext { get }

    /// The optional payload bytes to send with the context.
    var content: Data? { get }
}

/// A typed inbound message that can be decoded from a Network framework content context and payload.
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public protocol RawSocketReceiveMessage: Sendable {
    /// Creates a typed message from received protocol metadata and optional payload bytes.
    ///
    /// Return `nil` when the context or payload does not describe a valid message of this type.
    ///
    /// - Parameters:
    ///   - context: The received Network framework content context.
    ///   - content: The optional payload bytes delivered with the context.
    init?(from context: NWConnection.ContentContext, with content: Data?)
}

/// A lightweight wrapper around `NWConnection` that exposes callback and async socket operations.
///
/// For example, connect and receive data asynchronously:
///
/// ```swift
/// let socket = try RawSocket(configuration)
/// try await socket.connect()
/// let data = try await socket.receiveNext()
/// await socket.cancel()
/// ```
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public class RawSocket: @unchecked Sendable {
    private enum _InternalState: Sendable, Equatable {
        case none
        case connecting
        case connected
        case cancelling
        case closed
    }

    private let connection: NWConnection
    private let accessQueue: DispatchQueue
    private let maxDataBlock: Int
    private let accessKey: DispatchSpecificKey<ObjectIdentifier>
    private let transport: RawSocketTransport
    private var internalState: _InternalState {
        didSet {
            printDebug("[socket] internal state changed", internalState)
        }
    }
    private let timeoutEvent: TimeoutRecursiveEvent?
    private var cancellingError: NWError?
    private var connectingCallback: (@Sendable (Result<ConnectionInfo, NWError>) -> Void)?
    private var cancellingCallbacks: [(@Sendable () -> Void)]

    // MARK: - INITIALIZATION

    /// Creates a socket from the supplied configuration.
    ///
    /// The socket is not connected until ``connect(_:)`` or ``connect()`` is called.
    ///
    /// - Parameter configuration: The destination, transport, security, proxy, and timeout settings.
    /// - Throws: An `NWError` if the underlying `NWConnection` cannot be created from the configuration.
    public convenience init(_ configuration: RawSocketConfiguration) throws(NWError) {
        try self.init(configuration, accessQueue: nil)
    }

    init(_ configuration: RawSocketConfiguration, accessQueue: DispatchQueue?) throws(NWError) {
        internalState = .none
        self.accessQueue = accessQueue ?? DispatchQueue(label: "com.network.lib.raw-socket", target: .global())
        accessKey = DispatchSpecificKey()
        self.accessQueue.setSpecific(key: accessKey, value: ObjectIdentifier(self.accessQueue))
        cancellingCallbacks = []
        timeoutEvent = TimeoutRecursiveEvent(timeout: configuration.timeout, on: self.accessQueue)
        maxDataBlock = configuration.maxDataBlock
        transport = configuration.transport
        connection = try configuration.makeNWConnection()
        connection.stateUpdateHandler = { [weak self] state in
            self?.stateUpdateHandler(state)
        }

        // - after init
        timeoutEvent?.setHandler { [weak self] event in
            printDebug("[socket] timeout event handler")
            self?.cancellingError = .posix(.ETIMEDOUT)
            self?.cancelUnsafe()
        }
    }

    deinit {
        printDebug("[socket] deinit")
        if DispatchQueue.getSpecific(key: accessKey) == ObjectIdentifier(accessQueue) {
            cancelUnsafe()
            finishConnectionUnsafe(code: .ECANCELED)
            callAllCancelsUnsafe()
        } else {
            accessQueue.sync {
                printDebug("[socket] queue sync on deinit")
                cancelUnsafe()
                finishConnectionUnsafe(code: .ECANCELED)
                callAllCancelsUnsafe()
            }
        }
    }

    // MARK: - PUBLIC METHODS

    /// Starts the underlying network connection.
    ///
    /// Only one connection attempt may be active at a time. The callback receives `.success` with connection details once the
    /// connection becomes ready, or `.failure` with the `NWError` reported by the underlying connection.
    ///
    /// For example, start a callback-based connection:
    ///
    /// ```swift
    /// socket.connect { result in
    ///     if case .success(let info) = result {
    ///         print(info.remoteEndpoint)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter block: A callback invoked when the connection succeeds or fails.
    public func connect(_ block: @escaping @Sendable (_ result: Result<ConnectionInfo, NWError>) -> Void) {
        accessQueue.async { [weak self] in
            printDebug("[socket] queue async connect with timeout")
            guard let self else {
                block(.failure(.posix(.ECANCELED)))
                return
            }
            self.connectUnsafeNoTimer { [weak self] result in
                self?.timeoutEvent?.detouch()
                block(result)
            }
        }
    }

    /// Cancels the socket and invokes an optional handler after cancellation is observed.
    ///
    /// Calling this method is idempotent. Pending operations complete with the cancellation error when possible.
    ///
    /// - Parameter handler: A closure called after the socket cancellation callbacks are drained.
    public func cancel(_ handler: (@Sendable () -> Void)?) {
        accessQueue.async { [weak self] in
            printDebug("[socket] queue async close")
            guard let self else {
                handler?()
                return
            }
            if let handler {
                cancellingCallbacks.append(handler)
            }
            self.cancelUnsafe()
        }
    }

    /// Sends raw bytes on the socket.
    ///
    /// The socket must be connecting or connected. The completion receives `nil` on success or the `NWError` that prevented the
    /// send from completing.
    ///
    /// For example, send UTF-8 bytes:
    ///
    /// ```swift
    /// socket.send(Data("ping".utf8)) { error in
    ///     if let error { print(error) }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - data: The bytes to send.
    ///   - completion: A closure invoked when the send is processed.
    public func send(_ data: Data, _ completion: (@Sendable (_ error: NWError?) -> Void)?) {
        accessQueue.async { [weak self] in
            guard let self else {
                completion?(.posix(.ECANCELED))
                return
            }
            printDebug("[socket] send", data)
            if let error = activeOperationCheckErrorUnsafe() {
                completion?(error)
                return
            }
            timeoutEvent?.touch()
            connection.send(content: data, completion: .contentProcessed({ [weak self] error in
                self?.timeoutEvent?.detouch()
                completion?(self?.cancellingError ?? error)
            }))
        }
    }

    /// Sends a typed message with protocol metadata.
    ///
    /// Use this when an application protocol is installed in the `NWConnection` stack and data must be sent with a content
    /// context, such as a custom `NWProtocolFramer.Message`.
    ///
    /// - Parameters:
    ///   - message: The typed message that supplies content and context.
    ///   - completion: A closure invoked when the send is processed.
    public func sendMessage<M: RawSocketSendMessage>(_ message: M, _ completion: (@Sendable (_ error: NWError?) -> Void)?) {
        accessQueue.async { [weak self] in
            guard let self else {
                completion?(.posix(.ECANCELED))
                return
            }
            printDebug("[socket] send", message)
            if let error = activeOperationCheckErrorUnsafe() {
                completion?(error)
                return
            }
            timeoutEvent?.touch()
            connection.send(content: message.content, contentContext: message.context, isComplete: true,
                            completion: .contentProcessed({ [weak self] error in
                self?.timeoutEvent?.detouch()
                completion?(self?.cancellingError ?? error)
            }))
        }
    }

    /// Receives the next available raw data block.
    ///
    /// The result is `.success(data)` when bytes are received, `.success(nil)` when the connection completes cleanly with no
    /// more data, or `.failure` when the receive fails.
    ///
    /// For example, read the next block and handle end-of-stream:
    ///
    /// ```swift
    /// socket.receiveNext { result in
    ///     if case .success(let data?) = result {
    ///         print(data.count)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter completion: A callback invoked with the next raw data block or receive error.
    public func receiveNext(_ completion: @escaping @Sendable (_ result: Result<Data?, NWError>) -> Void) {
        accessQueue.async { [weak self, maxDataBlock] in
            guard let self else { return completion(.failure(.posix(.ECANCELED))) }
            printDebug("[socket] receive next")

            if let error = activeOperationCheckErrorUnsafe() {
                return completion(.failure(error))
            }

            timeoutEvent?.touch()
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxDataBlock)
            { [weak self] content, contentContext, isComplete, error in
                guard let self else { return completion(.failure(.posix(.ECANCELED))) }
                self.timeoutEvent?.detouch()
                if let content {
                    completion(.success(content))
                } else if let error {
                    self.cancelUnsafe()
                    completion(.failure(error))
                } else if isComplete {
                    if let cancellingError = self.cancellingError {
                        completion(.failure(cancellingError))
                    } else {
                        completion(.success(nil))
                    }
                } else {
                    assertionFailure("Unexpected receive state: content=nil, isComplete=false, error=nil")
                    completion(.failure(.posix(.EIO)))
                }
            }
        }
    }

    /// Receives and decodes the next typed message.
    ///
    /// The socket receives a Network framework message and asks `M` to initialize itself from the delivered content context and
    /// payload. If decoding fails, the completion receives `EBADMSG` unless the connection is already closing.
    ///
    /// - Parameters:
    ///   - type: The typed message to decode. The default is inferred from the completion result type.
    ///   - completion: A callback invoked with the decoded message or receive error.
    public func receiveNextMessage<M: RawSocketReceiveMessage>(
        of type: M.Type = M.self,
        _ completion: @escaping @Sendable (_ result: Result<M, NWError>) -> Void
    ) {
        accessQueue.async { [weak self] in
            guard let self else { return completion(.failure(.posix(.ECANCELED))) }
            printDebug("[socket] receive next message")

            if let error = activeOperationCheckErrorUnsafe() {
                completion(.failure(error))
                return
            }

            timeoutEvent?.touch()
            connection.receiveMessage { [weak self] content, contentContext, isComplete, error in
                guard let self else { return completion(.failure(.posix(.ECANCELED))) }
                self.timeoutEvent?.detouch()

                if let error = error ?? self.cancellingError {
                    self.cancelUnsafe()
                    completion(.failure(error))
                } else if let contentContext {
                    if !isComplete {
                        return completion(.failure(.posix(.EIO)))
                    }

                    if let message = M.init(from: contentContext, with: content) {
                        completion(.success(message))
                    } else if contentContext.isFinal, internalState == .closed || internalState == .cancelling {
                        completion(.failure(.posix(.ECANCELED)))
                    } else {
                        completion(.failure(.posix(.EBADMSG)))
                    }
                } else if isComplete {
                    completion(.failure(.posix(.EIO)))
                } else {
                    assertionFailure("Unexpected receive state: content=nil, contentContext=nil, isComplete=false, error=nil")
                    completion(.failure(.posix(.EIO)))
                }
            }
        }
    }

    // MARK: - PRIVATE METHODS

    private func connectUnsafeNoTimer(_ block: @escaping @Sendable (Result<ConnectionInfo, NWError>) -> Void) {
        timeoutEvent?.touch()
        if internalState == .closed || internalState == .cancelling {
            return block(.failure(.posix(.ECANCELED)))
        }
        if internalState == .connecting { return block(.failure(.posix(.EALREADY))) }
        if internalState == .connected { return block(.failure(.posix(.EISCONN))) }
        connectingCallback = block
        internalState = .connecting
        connection.start(queue: accessQueue)
    }

    private func cancelUnsafe() {
        printDebug("[socket] cancel unsafe")
        timeoutEvent?.cancel()
        if internalState == _InternalState.none { // cause state update may not be called
            internalState = .closed
            connection.cancel()
            callAllCancelsUnsafe()
            return
        }
        if [.closed].contains(internalState) {
            callAllCancelsUnsafe()
            return
        }
        if internalState == .cancelling {
            return
        }
        internalState = .cancelling
        connection.cancel()
    }

    private func stateUpdateHandler(_ newState: NWConnection.State) {
        printDebug("[socket] new state", newState)
        switch newState {
        case .setup: break
        case let .waiting(error):
            timeoutEvent?.cancel()
            finishConnectionUnsafe(.failure(error))
            cancelUnsafe()
        case .preparing: break
        case .ready:
            internalState = .connected
            let info = ConnectionInfo(transport: transport, remoteEndpoint: connection.endpoint,
                                      localEndpoint: connection.currentPath?.localEndpoint,
                                      interface: connection.currentPath?.availableInterfaces.first)
            finishConnectionUnsafe(.success(info))
        case let .failed(error):
            timeoutEvent?.cancel()
            finishConnectionUnsafe(.failure(error))
            cancelUnsafe()
        case .cancelled:
            timeoutEvent?.cancel()
            finishConnectionUnsafe(.failure(cancellingError ?? .posix(.ECANCELED)))
            callAllCancelsUnsafe()
            internalState = .closed
        @unknown default: break
        }
    }

    private func callAllCancelsUnsafe() {
        let callbacks = cancellingCallbacks
        cancellingCallbacks = []
        for callback in callbacks {
            callback()
        }
    }

    private func finishConnectionUnsafe(code: POSIXErrorCode) {
        finishConnectionUnsafe(.failure(.posix(code)))
    }

    private func finishConnectionUnsafe(_ result: Result<ConnectionInfo, NWError>) {
        let callback = connectingCallback
        connectingCallback = nil
        callback?(result)
    }

    private func activeOperationCheckErrorUnsafe() -> NWError? {
        if internalState == .none {
            return .posix(.ENOTCONN)
        }
        if ![.connected, .connecting].contains(internalState) {
            return cancellingError ?? .posix(.ECANCELED)
        }
        return nil
    }
}
