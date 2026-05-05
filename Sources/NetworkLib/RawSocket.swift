import Foundation
import Network

public struct ConnectionInfo: Sendable, Equatable {
    public let transport: RawSocketTransport
    public let remoteEndpoint: NWEndpoint
    public let localEndpoint: NWEndpoint?
    public let interface: NWInterface?
}

public protocol RawSocketSendMessage: Sendable {
    var context: NWConnection.ContentContext { get }
    var content: Data? { get }
}

public protocol RawSocketReceiveMessage: Sendable {
    init?(from context: NWConnection.ContentContext, with content: Data?)
}

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
    
    public init(_ configuration: RawSocketConfiguration) throws(NWError) {
        internalState = .none
        let accessQueue = DispatchQueue(label: "com.network.lib.raw-socket", target: .global())
        accessKey = DispatchSpecificKey()
        accessQueue.setSpecific(key: accessKey, value: ObjectIdentifier(accessQueue))
        self.accessQueue = accessQueue
        cancellingCallbacks = []
        timeoutEvent = TimeoutRecursiveEvent(timeout: configuration.timeout, on: accessQueue)
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
                    guard let message = M.init(from: contentContext, with: content) else {
                        return completion(.failure(.posix(.EBADMSG)))
                    }
                    completion(.success(message))
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
