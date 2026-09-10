import Testing
import Foundation
import Network
@testable import NetworkLibCore

extension Tag.RawSocket {
    @Tag static var receiveMessage: Tag
}

@Suite(.tags(.core, .RawSocket.receiveMessage, .RawSocket.all), .timeLimit(.minutes(1)))
struct RawSocketReceiveMessageTests {
    // MARK: - ENTITIES

    private struct _NilMessage: RawSocketReceiveMessage, Equatable {
        init?(from context: NWConnection.ContentContext, with content: Data?) {
            nil
        }
    }

    private struct _OnlyDataMessage: RawSocketReceiveMessage, Equatable {
        let data: Data?
        init?(from context: NWConnection.ContentContext, with content: Data?) {
            data = content
        }
    }

    // MARK: - TESTS

    // MARK: SUCCESS

    @Test
    func receivedData_Context_ConvertsMessageOk_CallbackReturnsConvertedMessage() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let expectedData = Data("Hello".utf8)
        let expectedMessage = _OnlyDataMessage(from: .defaultMessage, with: expectedData)
        let underlyingConnection = NWConnectionMock(
            dataForReceive: expectedData,
            overridedReceiveContext: .defaultMessage,
            overridedReceiveComplete: true
        )
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        let result = try await withCheckedThrowingContinuation { continuation in
            socket.connect { result in
                socket.receiveNextMessage(of: _OnlyDataMessage.self) { result in
                    continuation.resume(with: result)
                }
            }
        }
        try #require(result == expectedMessage)
    }

    // MARK: ERRORS ON CONVERTING MESSAGE

    @Test
    func messageConvertsToNil_ThrowsBadMessageError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(overridedReceiveContext: .defaultMessage)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.receiveNextMessage(of: _NilMessage.self) { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.EBADMSG) {
        }
    }

    @Test
    func messageConvertsToNil_FinalContext_ThrowsBadMessageError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(overridedReceiveContext: .finalMessage)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.receiveNextMessage(of: _NilMessage.self) { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.EBADMSG) {
        }
    }

    // MARK: ERROR ON INTERNAL STATES

    @Test
    func whenNotConnected_ThrowsCancelledError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.receiveNextMessage(of: _OnlyDataMessage.self) { result in
                    continuation.resume(with: result)
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ENOTCONN) {
        }
    }

    @Test
    func whenCancellingByTimeout_CallReceive_ThrowsCancelledError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0.5
        let underlyingConnection = NWConnectionMock(overridedStates: [.preparing])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.receiveNextMessage(of: _NilMessage.self) { result in
                        continuation.resume(with: result)
                    }
                }
                socket.connect { _ in
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }

    @Test
    func whenCancellingManually_ThrowsCancelledError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.receiveNextMessage(of: _OnlyDataMessage.self) { result in
                        continuation.resume(with: result)
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

    @Test
    func whenCancelledByServerAfterConnect_ThrowsCancelledError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(overridedStates: [.preparing, .ready, .failed(.posix(.EINVAL))])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.receiveNextMessage(of: _OnlyDataMessage.self) { result in
                        continuation.resume(with: result)
                    }
                }
                socket.connect { _ in
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test
    func whenCancelledDuringReceive_FinalContext_MessageConvertsToNil_ThrowsCancelledError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(
            mode: [.methodReceive, .dontCallCallback],
            overridedReceiveContext: .finalMessage
        )
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.receiveNextMessage(of: _NilMessage.self) { result in
                        continuation.resume(with: result)
                    }
                    socket.cancel(nil)
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    // MARK: TIMEOUT ERRORS

    @Test
    func timeoutZero_AndReceiveCallbackNotCalled() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(
            mode: [.methodReceive, .dontCallCallback],
            overridedReceiveContext: .finalMessage
        )
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withAsyncTimeoutCancelationContinuation(.milliseconds(500), block: { continuation in
                socket.connect { result in
                    socket.receiveNextMessage(of: _NilMessage.self) { result in
                        continuation.resume(with: result)
                    }
                }
            }, onCancel: {
                socket.cancel(nil)
            })
            Issue.record("Unexpected entrance")
        } catch is AsyncTimeoutError {
        }
    }

    @Test
    func timeoutNotZero_ThrowsTimeoutError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0.5
        let underlyingConnection = NWConnectionMock(
            mode: [.methodReceive, .dontCallCallback],
            overridedReceiveContext: .finalMessage
        )
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { result in
                    socket.receiveNextMessage(of: _NilMessage.self) { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }

    // MARK: ERRORS BY SERVER SIDE

    @Test
    func serverReturnsError_ThrowsTheError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let expectedError = NWError.posix(.EINVAL)
        let underlyingConnection = NWConnectionMock(overridedReceiveError: expectedError)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { result in
                    socket.receiveNextMessage(of: _NilMessage.self) { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch where error == expectedError {
        }
    }

    @Test
    func responseIsNotComplete_ThrowsInOutError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(overridedReceiveContext: .defaultMessage, overridedReceiveComplete: false)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { result in
                    socket.receiveNextMessage(of: _NilMessage.self) { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.EIO) {
        }
    }

    @Test
    func noContextButIsComplete_ThrowsInOutError() async throws {
        let transport = RawSocketTransport.udp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(overridedReceiveContext: nil, overridedReceiveComplete: true)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { result in
                    socket.receiveNextMessage(of: _NilMessage.self) { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.EIO) {
        }
    }

    // MARK: REFERNENCE COUNTING

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenSourceReferencesAllNil_ConnectionKeepsSelf(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
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
                box.get()?.receiveNextMessage(of: _NilMessage.self) { result in
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
                socket.receiveNextMessage(of: _NilMessage.self) { result in
                    continuation.resume(returning: probe.isCurrentQueue)
                }
            }
        }
        try #require(check == true)
    }
}
