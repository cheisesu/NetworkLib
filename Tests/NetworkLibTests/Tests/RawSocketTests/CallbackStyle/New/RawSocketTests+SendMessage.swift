import Testing
import Foundation
import Network
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var sendMessage: Tag
}

@Suite(.tags(.RawSocket.sendMessage, .RawSocket.all), .timeLimit(.minutes(1)))
struct RawSocketSendMessageTests {
    // MARK: - ENTITIES

    private struct _SendMessage: RawSocketSendMessage {
        let context: NWConnection.ContentContext
        let content: Data?

        init(context: NWConnection.ContentContext = .defaultMessage, content: Data?) {
            self.context = context
            self.content = content
        }
    }

    // MARK: - TESTS

    // MARK: SUCCESS ON STATES

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenConnecting_ConnectionSendCalled(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil,
                                                   timeout: timeout, maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            socket.onInternalStateChange = { _, newState in
                guard newState == .connecting else { return }
                socket.sendMessage(message) { result in
                    continuation.resume()
                }
            }
            socket.connect { _ in
            }
        }
        try #require(underlyingConnection.sendIsComplete == true)
        try #require(underlyingConnection.sendContext.identifier == context.identifier)
        try #require(underlyingConnection.sendContext.isFinal == context.isFinal)
        try #require(underlyingConnection.sendDataFull == data)
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenConnected_ConnectionSendCalled(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil,
                                                   timeout: timeout, maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            socket.connect { _ in
                socket.sendMessage(message) { result in
                    continuation.resume()
                }
            }
        }
        try #require(underlyingConnection.sendIsComplete == true)
        try #require(underlyingConnection.sendContext.identifier == context.identifier)
        try #require(underlyingConnection.sendContext.isFinal == context.isFinal)
        try #require(underlyingConnection.sendDataFull == data)
    }

    // MARK: ERROR ON INTERNAL STATES

//#error("Not implemented this section, others are done")

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenNotConnected_ThrowsNotConnectedError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil,
                                   timeout: timeout, maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.sendMessage(message) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ENOTCONN) {
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenCancelling_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil,
                                   timeout: timeout, maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.sendMessage(message) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                socket.connect { _ in
                    socket.cancel(nil)
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenCancelled_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil,
                                   timeout: timeout, maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.cancel {
                        socket.sendMessage(message) { error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenCallCancelDuringSend_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock(overridedSendError: .posix(.EINVAL), mode: [.methodSend, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil,
                                   timeout: timeout, maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.sendMessage(message) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                    socket.cancel(nil)
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenCancelledByServerAfterConnect_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock(overridedStates: [.preparing, .ready, .failed(.posix(.EINVAL))])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.sendMessage(message) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                socket.connect { _ in
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenCancellingByTimeout_CallSend_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0.5
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock(overridedStates: [.preparing])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.sendMessage(message) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                socket.connect { _ in
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }

    // MARK: TIMEOUT ERRORS

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func timeoutZero_CallbackNotCalled(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock(mode: [.methodSend, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil,
                                   timeout: timeout, maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withAsyncTimeoutCancelationContinuation(.milliseconds(500)) { continuation in
                socket.connect { _ in
                    socket.sendMessage(message) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch is AsyncTimeoutError {
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func timeoutNonZero_ThrowsTimeoutError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0.5
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let underlyingConnection = NWConnectionMock(mode: [.methodSend, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil,
                                   timeout: timeout, maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.sendMessage(message) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }

    // MARK: ERRORS BY SERVER SIDE

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func serverReturnsError_ThrowsRelatedError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let context = NWConnection.ContentContext(identifier: "BLABLA")
        let message = _SendMessage(context: context, content: data)
        let expectedError = NWError.posix(.ECONNRESET)
        let underlyingConnection = NWConnectionMock(overridedSendError: expectedError)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.sendMessage(message) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch let error as NWError where error == expectedError {
        }
    }

    // MARK: REFERNENCE COUNTING

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenSourceReferencesAllNil_ConnectionKeepsSelf(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let data = Data("Hello".utf8)
        let message = _SendMessage(content: data)
        let underlyingConnection = NWConnectionMock()
        var tempSocket: RawSocket? = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil,
                                                   timeout: timeout, maxDataBlock: 256, transport: transport)
        let address = ReferencesCounter.shared.address(of: tempSocket)
        let box = _SocketBox()
        box.set(tempSocket)
        tempSocket = nil
        defer { box.get()?.cancel(nil) }
        try #require(ReferencesCounter.shared.count(of: address) == 1)
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            box.get()?.connect { _ in
                box.get()?.sendMessage(message) { result in
                    continuation.resume()
                }
                box.set(nil)
            }
        }
        try #require(ReferencesCounter.shared.count(of: address) == 1)
    }

    // MARK: DELEGATE QUEUE

    @Test
    func callbackCalledOnProvidedQueue() async throws {
        let data = Data("Hello".utf8)
        let message = _SendMessage(content: data)
        let delegateQueue = DispatchQueue(label: "raw-socket.delegate.receive-message")
        let probe = DelegateQueueProbe()
        probe.install(on: delegateQueue)
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: delegateQueue, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        let check = await withCheckedContinuation { continuation in
            socket.connect { _ in
                socket.sendMessage(message) { result in
                    continuation.resume(returning: probe.isCurrentQueue)
                }
            }
        }
        try #require(check == true)
    }
}
