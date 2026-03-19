import Foundation
import Network

public enum NetTransport: Sendable {
    case tcp
    case udp
}

public struct ConnectionInfo: Sendable, Equatable {
    public let transport: NetTransport
    public let remoteEndpoint: NWEndpoint
    public let localEndpoint: NWEndpoint?
    public let interface: NWInterface?
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
    private let transport: NetTransport
    private var internalState: _InternalState {
        didSet {
            printDebug("[socket] internal state changed", internalState)
        }
    }
    private let timeoutEvent: TimeoutRecursiveEvent?
    private var cancellingError: NWError?
    private var connectingCallback: (@Sendable (Result<ConnectionInfo, Error>) -> Void)?
    private var cancellingCallbacks: [(@Sendable () -> Void)]

    // MARK: - INITIALIZATION

    public convenience init(url: URL, maxDataBlock: Int = .max, transport: NetTransport = .tcp,
                            timeout: TimeInterval, sni: String?) throws
    {
        try self.init(endpoint: .url(url), maxDataBlock: maxDataBlock, transport: transport, timeout: timeout, sni: sni)
    }

    public init(endpoint: NWEndpoint, maxDataBlock: Int = .max, transport: NetTransport = .tcp,
                timeout: TimeInterval = 10, sni: String?) throws
    {
        internalState = .none
        let accessQueue = DispatchQueue(label: "com.network.lib.raw-socket", target: .global())
        accessKey = DispatchSpecificKey()
        accessQueue.setSpecific(key: accessKey, value: ObjectIdentifier(accessQueue))
        self.accessQueue = accessQueue
        cancellingCallbacks = []
        timeoutEvent = TimeoutRecursiveEvent(timeout: timeout, on: accessQueue)
        self.maxDataBlock = maxDataBlock
        self.transport = transport
        let tls: NWProtocolTLS.Options? = {
            let isSecure = sni != nil
            guard isSecure else { return nil }
            let tls = NWProtocolTLS.Options()
            if let sni {
                sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, sni)
            }
            return tls
        }()
        let parameters = {
            switch transport {
            case .tcp:
                let tcp = NWProtocolTCP.Options()
                return NWParameters(tls: tls, tcp: tcp)
            case .udp:
                let udp = NWProtocolUDP.Options()
                return NWParameters(dtls: tls, udp: udp)
            }
        }()
        connection = NWConnection(to: endpoint, using: parameters)
        connection.stateUpdateHandler = { [weak self] state in
            self?.stateUpdateHandler(state)
        }

        // - after init
        timeoutEvent?.setHandler { [weak self] event in
            printDebug("[socket] timeout event handler")
            self?.cancellingError = NWError.posix(.ETIMEDOUT)
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

    public func connect(_ block: @escaping @Sendable (Result<ConnectionInfo, Error>) -> Void) {
        accessQueue.async { [weak self] in
            printDebug("[socket] queue async connect with timeout")
            guard let self else {
                block(.failure(NWError.posix(.ECANCELED)))
                return
            }
            self.connectUnsafeNoTimer { [weak self] result in
                self?.timeoutEvent?.detouch()
                block(result)
            }
        }
    }

    public func cancel(_ handler: (@Sendable () -> Void)? = nil) {
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

    public func send(_ data: Data, _ completion: (@Sendable (Error?) -> Void)?) {
        accessQueue.async { [weak self] in
            guard let self else {
                completion?(NWError.posix(.ECANCELED))
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

    public func receiveNext(_ completion: @escaping @Sendable (Data?, Error?) -> Void) {
        accessQueue.async { [weak self, maxDataBlock] in
            guard let self else { return completion(nil, NWError.posix(.ECANCELED)) }
            printDebug("[socket] receive next")
            
            if let error = activeOperationCheckErrorUnsafe() {
                completion(nil, error)
                return
            }
            
            timeoutEvent?.touch()
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxDataBlock) { [weak self] content, contentContext, isComplete, error in
                guard let self else {
                    completion(nil, NWError.posix(.ECANCELED))
                    return
                }
                self.timeoutEvent?.detouch()
                if let content {
                    completion(content, nil)
                } else if let error {
                    self.cancelUnsafe()
                    completion(nil, error)
                } else if isComplete {
                    completion(nil, self.cancellingError)
                } else {
                    assertionFailure("Unexpected receive state: content=nil, isComplete=false, error=nil")
                    completion(nil, NWError.posix(.EIO))
                }
            }
        }
    }

    // MARK: - PRIVATE METHODS

    private func connectUnsafeNoTimer(_ block: @escaping @Sendable (Result<ConnectionInfo, Error>) -> Void) {
        timeoutEvent?.touch()
        if internalState == .closed || internalState == .cancelling {
            return block(.failure(NWError.posix(.ECANCELED)))
        }
        if internalState == .connecting { return block(.failure(NWError.posix(.EALREADY))) }
        if internalState == .connected { return block(.failure(NWError.posix(.EISCONN))) }
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
        finishConnectionUnsafe(.failure(NWError.posix(code)))
    }
    
    private func finishConnectionUnsafe(_ result: Result<ConnectionInfo, Error>) {
        let callback = connectingCallback
        connectingCallback = nil
        callback?(result)
    }
    
    private func activeOperationCheckErrorUnsafe() -> NWError? {
        if internalState == .none {
            return .posix(.ENOTCONN)
        }
        if ![.connected, .connecting].contains(internalState) {
            return cancellingError ?? NWError.posix(.ECANCELED)
        }
        return nil
    }
}
