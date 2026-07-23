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
    enum _InternalState: Int, Sendable, Equatable, Comparable {
        case initial
        case connecting
        case connected
        case cancelling
        case closed

        static func < (lhs: borrowing RawSocket._InternalState, rhs: borrowing RawSocket._InternalState) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var onInternalStateChange: (@Sendable (_ oldState: _InternalState, _ newState: _InternalState) -> Void)?

    private let connection: NWConnection
    private let accessQueue: DispatchQueue
    private let maxDataBlock: Int
    private let accessKey: DispatchSpecificKey<ObjectIdentifier>
    private let transport: RawSocketTransport
    private let callbackDelivery: CallbackDelivery
    private var selfKeeper: RawSocket?
    private var internalState: _InternalState {
        didSet {
            printDebug("[socket] internal state changed", oldValue, "->" , internalState)
            onInternalStateChange?(oldValue, internalState)
        }
    }
    private let timeoutEvent: TimeoutRecursiveEvent?
    private var pendingError: NWError?
    private var connectingCallback: (@Sendable (Result<ConnectionInfo, NWError>) -> Void)?
    private var cancellingCallbacks: [(@Sendable () -> Void)]

    // MARK: - INITIALIZATION

    /// Creates a socket from the supplied configuration.
    ///
    /// The socket is not connected until ``connect(_:)`` or ``connect()`` is called. Callback-based APIs deliver their callbacks
    /// on `delegateQueue`, or on the socket's default delegate queue when `delegateQueue` is `nil`.
    ///
    /// - Parameters:
    ///   - configuration: The destination, transport, security, proxy, and timeout settings.
    ///   - delegateQueue: Optional queue used to deliver callback-based API completions.
    /// - Throws: An `NWError` if the underlying `NWConnection` cannot be created from the configuration.
    public convenience init(_ configuration: RawSocketConfiguration, delegateQueue: DispatchQueue? = nil) throws(NWError) {
        try self.init(configuration, accessQueue: nil, delegateQueue: delegateQueue)
    }

    init(_ configuration: RawSocketConfiguration, accessQueue: DispatchQueue?, delegateQueue: DispatchQueue?) throws(NWError) {
        internalState = .initial
        self.accessQueue = accessQueue ?? .RawSocket.access
        accessKey = DispatchSpecificKey()
        self.accessQueue.setSpecific(key: accessKey, value: ObjectIdentifier(self.accessQueue))
        callbackDelivery = CallbackDelivery(queue: delegateQueue ?? .RawSocket.delegate)
        cancellingCallbacks = []
        timeoutEvent = TimeoutRecursiveEvent(timeout: configuration.timeout, on: self.accessQueue)
        maxDataBlock = configuration.maxDataBlock
        transport = configuration.transport
        connection = try configuration.makeNWConnection()

        // - after init
        afterInitSetup()
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
    public func connect(_ block: @escaping @Sendable (_ result: Result<ConnectionInfo, NWError>) -> Void) { // done
        accessQueue.async {
            self.connectUnsafe { result in
                block(result)
            }
        }
    }

    /// Cancels the socket and invokes an optional handler after cancellation is observed.
    ///
    /// Calling this method is idempotent. Pending operations complete with the cancellation error when possible.
    ///
    /// - Parameter handler: A closure called after the socket cancellation callbacks are drained.
    public func cancel(_ handler: (@Sendable () -> Void)?) { // done
        accessQueue.async {
            printDebug("[socket] queue async close")
            if let handler {
                self.cancellingCallbacks.append(handler)
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
        let completion = delivered(completion)
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
                completion?(self?.pendingError ?? error)
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
        let completion = delivered(completion)
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
                completion?(self?.pendingError ?? error)
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
        let completion = delivered(completion)
        accessQueue.async {
            printDebug("[socket] receive next")

            if let error = self.activeOperationCheckErrorUnsafe() {
                return completion(.failure(error))
            }

            self.timeoutEvent?.touch()
            self.connection.receive(minimumIncompleteLength: 1,
                                    maximumLength: self.maxDataBlock) { content, _, isComplete, error in
                self.receiveNextHandler(content, isComplete, error, completion: completion)
            }
        }
    }

    private func receiveNextHandler(_ content: Data?, _ isComplete: Bool, _ error: NWError?,
                                    completion: @escaping @Sendable (_ result: Result<Data?, NWError>) -> Void)
    {
        timeoutEvent?.detouch()
        if let content {
            completion(.success(content))
        } else if let error {
            cancelUnsafe()
            completion(.failure(error))
        } else if isComplete {
            if let cancellingError = pendingError {
                completion(.failure(cancellingError))
            } else {
                completion(.success(nil))
            }
        } else {
            assertionFailure("Unexpected receive state: content=nil, isComplete=false, error=nil")
            completion(.failure(.posix(.EIO)))
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
        let completion = delivered(completion)
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

                if let error = error ?? self.pendingError {
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
}

// MARK: - PRIVATE METHODS

extension RawSocket {
    private func afterInitSetup() {
        timeoutEvent?.setHandler { _ in
            printDebug("[socket] timeout event handler")
            self.pendingError = .posix(.ETIMEDOUT)
            self.cancelUnsafe()
        }
    }

    private func connectUnsafe(_ block: @escaping @Sendable (Result<ConnectionInfo, NWError>) -> Void) { // done
        printDebug("[socket] queue async connect with timeout")
        guard internalState < .closed else { return callbackDelivery.call(.failure(.posix(.ECANCELED)), block) }
        guard internalState < .cancelling else { return callbackDelivery.call(.failure(.posix(.ECANCELED)), block) }
        guard internalState < .connected else { return callbackDelivery.call(.failure(.posix(.EISCONN)), block) }
        guard internalState < .connecting else { return callbackDelivery.call(.failure(.posix(.EALREADY)), block) }

        timeoutEvent?.touch()
        connectingCallback = block
        internalState = .connecting
        connection.stateUpdateHandler = { state in
            self.stateUpdateHandler(state)
        }
        selfKeeper = self
        connection.start(queue: accessQueue)
    }

    private func cancelUnsafe() { // done
        printDebug("[socket] cancel unsafe")
        timeoutEvent?.cancel()
        if internalState == .initial { // cause state update may not be called
            internalState = .closed
            connection.cancel()
            callAllCancelsUnsafe()
            clearResourcesUnsafe()
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
            // TODO: check and reorder to remove timeoutevent cancel from here
            timeoutEvent?.cancel()
            notifyConnectingComplete(.failure(error))
            cancelUnsafe()
        case .preparing: break
        case .ready:
            timeoutEvent?.detouch()
            internalState = .connected
            let info = ConnectionInfo(transport: transport, remoteEndpoint: connection.endpoint,
                                      localEndpoint: connection.currentPath?.localEndpoint,
                                      interface: connection.currentPath?.availableInterfaces.first)
            notifyConnectingComplete(.success(info))
        case let .failed(error):
            // TODO: check and reorder to remove timeoutevent cancel from here
            timeoutEvent?.cancel()
            notifyConnectingComplete(.failure(error))
            cancelUnsafe()
        case .cancelled:
            // TODO: check and reorder to remove timeoutevent cancel from here
            timeoutEvent?.cancel()
            internalState = .closed
            notifyConnectingComplete(.failure(pendingError ?? .posix(.ECANCELED)))
            callAllCancelsUnsafe()
            clearResourcesUnsafe()
        @unknown default: break
        }
    }

    private func callAllCancelsUnsafe() {
        let callbacks = cancellingCallbacks
        cancellingCallbacks = []
        for callback in callbacks {
            callbackDelivery.call(callback)
        }
    }

    private func notifyConnectingComplete(_ result: Result<ConnectionInfo, NWError>) {
        let callback = connectingCallback
        connectingCallback = nil
        if let callback {
            callbackDelivery.call(result, callback)
        }
    }

    private func activeOperationCheckErrorUnsafe() -> NWError? {
        if internalState == .initial {
            return .posix(.ENOTCONN)
        }
        if ![.connected, .connecting].contains(internalState) {
            return pendingError ?? .posix(.ECANCELED)
        }
        return nil
    }

    private func clearResourcesUnsafe() {
        timeoutEvent?.cancel()
        timeoutEvent?.setHandler { _ in }
        connection.stateUpdateHandler = nil
        connection.pathUpdateHandler = nil
        connection.viabilityUpdateHandler = nil
        selfKeeper = nil
    }
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
private extension RawSocket {
    func delivered(_ callback: (@Sendable () -> Void)?) -> (@Sendable () -> Void)? {
        guard let callback else { return nil }
        return { [callbackDelivery, callback] in
            callbackDelivery.call(callback)
        }
    }

    func delivered<Value: Sendable>(
        _ callback: @Sendable @escaping (_ value: Value) -> Void
    ) -> @Sendable (_ value: Value) -> Void {
        { [callbackDelivery, callback] value in
            callbackDelivery.call(value, callback)
        }
    }

    func delivered<Value: Sendable>(
        _ callback: (@Sendable (_ value: Value) -> Void)?
    ) -> (@Sendable (_ value: Value) -> Void)? {
        guard let callback else { return nil }
        return { [callbackDelivery, callback] value in
            callbackDelivery.call(value, callback)
        }
    }
}
