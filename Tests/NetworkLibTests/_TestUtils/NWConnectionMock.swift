import Foundation
import Network
@testable import NetworkLib

final class NWConnectionMock: @unchecked Sendable, UnderlyingConnection {
    struct Mode: OptionSet, Sendable {
        let rawValue: Int

        static let dontCallCallback: Mode = .init(rawValue: 0x01_0000_0000 << 1)
        static let methodSend: Mode = .init(rawValue: 0x01 << 1)
        static let methodReceive: Mode = .init(rawValue: 0x01 << 2)
    }
    private let lock: NSLock
    private var _state: NWConnection.State {
        didSet {
            eventsQueue?.async { [_state] in
                if oldValue != _state {
                    self.stateUpdateHandler?(_state)
                }
            }
        }
    }
    private var _stateUpdateHandler: (@Sendable (NWConnection.State) -> Void)?
    private var eventsQueue: DispatchQueue?
    private var _pendingCallbacks: [@Sendable () -> Void]
    private let overridedStates: [NWConnection.State]
    private let overridedSendError: NWError?
    private let overridedReceiveError: NWError?
    private let mode: Mode
    private let dataForReceive: Data?
    private let overridedReceiveContext: NWConnection.ContentContext?
    private let overridedReceiveComplete: Bool

    private(set) var state: NWConnection.State {
        get { lock.withLock { _state } }
        set { lock.withLock { _state = newValue } }
    }
    var stateUpdateHandler: (@Sendable (NWConnection.State) -> Void)? {
        get { lock.withLock { _stateUpdateHandler } }
        set { lock.withLock { _stateUpdateHandler = newValue } }
    }
    let mockRemoteEndpoint: NWEndpoint
    let mockLocalEndpoint: NWEndpoint
    let mockInterface: NWInterface?

    private var _sentDataPortions: [Data]
    private(set) var sendDataPortions: [Data] {
        get { lock.withLock { _sentDataPortions } }
        set { lock.withLock { _sentDataPortions = newValue } }
    }
    var sendDataFull: Data { lock.withLock { Data(_sentDataPortions.joined()) } }

    private var _sendContext: NWConnection.ContentContext = .defaultMessage
    private(set) var sendContext: NWConnection.ContentContext {
        get { lock.withLock { _sendContext } }
        set { lock.withLock { _sendContext = newValue } }
    }
    private var _sendIsComplete: Bool = false
    private(set) var sendIsComplete: Bool {
        get { lock.withLock { _sendIsComplete } }
        set { lock.withLock { _sendIsComplete = newValue } }
    }

    init(overridedStates: [NWConnection.State] = [], overridedSendError: NWError? = nil, mode: Mode = [],
         dataForReceive: Data? = nil, overridedReceiveError: NWError? = nil,
         overridedReceiveContext: NWConnection.ContentContext? = nil, overridedReceiveComplete: Bool = true)
    {
        lock = NSLock()
        _sentDataPortions = []
        _state = .setup
        _pendingCallbacks = []
        self.overridedStates = overridedStates
        self.overridedSendError = overridedSendError
        self.mode = mode
        mockRemoteEndpoint = .hostPort(host: "127.0.0.1", port: 65535)
        mockLocalEndpoint = .hostPort(host: "127.0.0.1", port: 65534)
        mockInterface = nil
        self.dataForReceive = dataForReceive
        self.overridedReceiveError = overridedReceiveError
        self.overridedReceiveContext = overridedReceiveContext
        self.overridedReceiveComplete = overridedReceiveComplete
    }

    func connectionInfo(with transport: RawSocketTransport) -> ConnectionInfo {
        ConnectionInfo(
            transport: transport,
            remoteEndpoint: mockRemoteEndpoint,
            localEndpoint: mockLocalEndpoint,
            interface: mockInterface
        )
    }

    func start(queue: DispatchQueue) {
        lock.withLock { eventsQueue = queue }
        if overridedStates.isEmpty {
            state = .preparing
            state = .ready
        } else {
            for overridedState in overridedStates {
                state = overridedState
            }
        }
    }

    func cancel() {
        callPendingCallbacks()
        state = .cancelled
    }

    func forceCancel() {
        callPendingCallbacks()
        state = .cancelled
    }

    func receive(
        minimumIncompleteLength: Int,
        maximumLength: Int,
        completion: @escaping @Sendable (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void
    ) {
        if mode.contains(.methodReceive) {
            if mode.contains(.dontCallCallback) {
                lock.withLock {
                    _pendingCallbacks.append {
                        completion(nil, nil, true, self.overridedReceiveError)
                    }
                }
            } else {
                completion(dataForReceive, nil, true, overridedReceiveError)
            }
        } else {
            completion(dataForReceive, nil, true, overridedReceiveError)
        }
    }

    func receiveMessage(completion: @escaping @Sendable (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void) {
        if mode.contains(.methodReceive) {
            if mode.contains(.dontCallCallback) {
                lock.withLock {
                    _pendingCallbacks.append {
                        completion(nil, nil, true, self.overridedReceiveError)
                    }
                }
            } else {
                completion(dataForReceive, overridedReceiveContext, overridedReceiveComplete, overridedReceiveError)
            }
        } else {
            completion(dataForReceive, overridedReceiveContext, overridedReceiveComplete, overridedReceiveError)
        }
    }

    func send(
        content: Data?,
        contentContext: NWConnection.ContentContext,
        isComplete: Bool,
        completion: NWConnection.SendCompletion
    ) {
        lock.withLock {
            if let content {
                _sentDataPortions.append(content)
            }
            _sendContext = contentContext
            _sendIsComplete = isComplete
        }

        switch completion {
        case let .contentProcessed(callback):
            if mode.contains(.methodSend) {
                if mode.contains(.dontCallCallback) {
                    lock.withLock {
                        _pendingCallbacks.append {
                            callback(self.overridedSendError)
                        }
                    }
                } else {
                    callback(overridedSendError)
                }
            } else {
                callback(overridedSendError)
            }
        case .idempotent: break
        @unknown default: break
        }
    }

    private func callPendingCallbacks() {
        let pending = lock.withLock {
            let result = _pendingCallbacks
            _pendingCallbacks = []
            return result
        }
        for callback in pending {
            eventsQueue?.async(execute: callback)
        }
    }
}
