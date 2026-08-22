import Testing
import Foundation
import Network
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var send: Tag
}

struct RawSocketSendTests {
    @Test(.tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp], [Data("Hello".utf8)])
    func underlyingConnection_MethodSendCalled(_ transport: RawSocketTransport, _ dataToSend: Data) async throws {
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(overridedStates: [.preparing])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        socket.connect { _ in }
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            socket.send(dataToSend) { result in
                continuation.resume(with: result)
            }
        }
        try #require(underlyingConnection.sendDataPortions.count == 1)
    }

    // MARK: SUCCESS IN DIFFERENT STATES

    @Test(.tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func whenConnecting_CallbackSuccess(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock(overridedStates: [.preparing])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        socket.connect { _ in }
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            socket.send(dataToSend) { result in
                continuation.resume(with: result)
            }
        }
        try #require(underlyingConnection.sendDataFull == dataToSend)
    }

    @Test(.tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func whenConnected_CallbackSuccess(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        socket.connect { _ in }
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            socket.send(dataToSend) { result in
                continuation.resume(with: result)
            }
        }
        try #require(underlyingConnection.sendDataFull == dataToSend)
    }

    // MARK: ERRORS IN DIFFERENT STATES

    @Test(.disabled("when state is connecting and operationCancellError not nil - probably not possible"),
          .tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func whenConnecting_SentRightAfter_BeforeCancel_ReturnesCancelledError(_ transport: RawSocketTransport) async throws {
    }

    @Test(.disabled("when state is connected and operationCancellError not nil - probably not possible"),
          .tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func whenConnected_SentRightAfter_BeforeCancel_ReturnesCancelledError(_ transport: RawSocketTransport) async throws {
    }

    @Test(.tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func whenNotConnected_ReturnsNotConnectedError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.send(dataToSend) { result in
                    continuation.resume(with: result)
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ENOTCONN) {
        }
    }

    @Test(.tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func whenCancelling_ReturnsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    
                    socket.send(dataToSend) { result in
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

    @Test(.tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func whenClosed_ReturnsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.cancel {
                    socket.send(dataToSend) { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func whenClosedDuringSend_ReturnsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock(overridedSendError: .posix(.EINVAL), mode: [.methodSend, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.send(dataToSend) { result in
                        continuation.resume(with: result)
                    }
                    socket.cancel(nil)
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func sendWhenTimeoutHappened_ReturnsTimeoutError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0.5
        let dataToSend = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock(overridedSendError: .posix(.EINVAL), mode: [.methodSend, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.send(dataToSend) { result in
                        switch result {
                        case let .failure(error) where error == .posix(.ETIMEDOUT):
                            socket.send(dataToSend) { result in
                                continuation.resume(with: result)
                            }
                        default: continuation.resume(with: result)
                        }
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }

    // MARK: TIMEOUTS

    @Test(.tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func timeoutNotZero_SendNotCompleted_ThrowsTimeoutError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0.5
        let dataToSend = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock(mode: [.methodSend, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.send(dataToSend) { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }

    // MARK: OTHER ERRORS

    @Test(.tags(.RawSocket.send, .RawSocket.all),arguments: [RawSocketTransport.tcp, .udp], [NWError.posix(.ECONNRESET)])
    func sendReturnsError_ThrowsTheSameError(_ transport: RawSocketTransport, _ expectedError: NWError) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock(overridedSendError: expectedError)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.send(dataToSend) { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch where error == expectedError {
        }
    }

    // MARK: REFERENCE CYCLES

    @Test(.tags(.RawSocket.send, .RawSocket.all), .timeLimit(.minutes(1)), arguments: [RawSocketTransport.tcp, .udp])
    func whenSourceReferencesAllNil_ConnectionKeepsSelf(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data("Hello".utf8)
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
            box.get()?.onInternalStateChange = { _, newState in
                guard newState == .connecting else { return }
                box.set(nil)
            }
            box.get()?.connect { _ in
            }
            box.get()?.send(dataToSend) { result in
                continuation.resume(with: result)
            }
        }
        try #require(ReferencesCounter.shared.count(of: address) == 1)
    }

    // MARK: DELEGATE QUEUE

    @Test(.tags(.RawSocket.send, .RawSocket.all), arguments: [RawSocketTransport.tcp, .udp])
    func connectCallbackRunsOnDelegateQueue(_ transport: RawSocketTransport) async throws {
        let dataToSend = Data("Hello".utf8)
        let delegateQueue = DispatchQueue(label: "raw-socket.delegate.\(#function)")
        let probe = DelegateQueueProbe()
        probe.install(on: delegateQueue)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: delegateQueue, timeout: 0,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }

        let result = await withCheckedContinuation { continuation in
            socket.connect { _ in
                socket.send(dataToSend) { _ in
                    continuation.resume(returning: probe.isCurrentQueue)
                }
            }
        }

        try #require(result)
    }
}
