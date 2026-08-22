import Testing
import Foundation
import Network
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var receive: Tag
}

struct RawSocketReceiveTests {
    // MARK: TIMEOUT ERRORS

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func timeoutNonZero_ThrowsTimeoutError() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0.5
        let underlyingConnection = NWConnectionMock(mode: [.methodReceive, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.receiveNext { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected error")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func timeoutZero_CallbackNotCalled() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(mode: [.methodReceive, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            try await withAsyncTimeoutCancelationContinuation(.milliseconds(500)) { continuation in
                socket.connect { _ in
                    socket.receiveNext { result in
                        continuation.resume(with: result)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected error")
        } catch is AsyncTimeoutError {
        }
    }

    // MARK: SUCCESS BY STATE

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func whenConnecting_CallbackSuccess() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let expectedData = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock(dataForReceive: expectedData)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        let result = try await withCheckedThrowingContinuation { continuation in
            socket.onInternalStateChange = { _, newState in
                guard newState == .connecting else { return }
                socket.receiveNext { result in
                    continuation.resume(with: result)
                }
            }
            socket.connect { _ in
                socket.cancel(nil)
            }
        }
        try #require(result == expectedData)
    }

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func whenConnected_CallbackSuccess() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let expectedData = Data("Hello".utf8)
        let underlyingConnection = NWConnectionMock(dataForReceive: expectedData)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        let result = try await withCheckedThrowingContinuation { continuation in
            socket.connect { _ in
                socket.receiveNext { result in
                    continuation.resume(with: result)
                }
            }
        }
        try #require(result == expectedData)
    }

    // MARK: ERROR BY STATE

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func whenNotConnecthed_ThrowsNotConnectedError() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.receiveNext { result in
                    continuation.resume(with: result)
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ENOTCONN) {
        }
    }

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func whenCancelling_ThrowsCancelledError() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .cancelling else { return }
                    socket.receiveNext { result in
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

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func whenCancelled_ThrowsCancelledError() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.cancel {
                    socket.receiveNext { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func closeDuringReceive_ThrowsCancelledError() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(mode: [.methodReceive, .dontCallCallback])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.receiveNext { result in
                        continuation.resume(with: result)
                    }
                    socket.cancel(nil)
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    // MARK: ERROR BY SERVER SIDE

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func serverReturnsError_ThrowsRelatedError() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let expectedError = NWError.posix(.ECONNRESET)
        let underlyingConnection = NWConnectionMock(overridedReceiveError: expectedError)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.receiveNext { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch where error == expectedError {
        }
    }

    // MARK: REFERENCE SELF KEEPING

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func whenSourceReferencesAllNil_ConnectionKeepsSelf() async throws {
        let transport = RawSocketTransport.tcp
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
        _ = try await withCheckedThrowingContinuation { continuation in
            box.get()?.connect { _ in
                box.get()?.receiveNext { result in
                    continuation.resume(with: result)
                }
                box.set(nil)
            }
        }
        try #require(ReferencesCounter.shared.count(of: address) == 1)
    }

    // MARK: CALLBACK CALLED ON QUEUE

    @Test(.tags(.RawSocket.all, .RawSocket.receive), .timeLimit(.minutes(1)))
    func callbackCalledOnDelegateQueue() async throws {
        let transport = RawSocketTransport.tcp
        let delegateQueue = DispatchQueue(label: "raw-socket.delegate.\(#function)")
        let probe = DelegateQueueProbe()
        probe.install(on: delegateQueue)
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: delegateQueue, timeout: 0,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }

        let result = await withCheckedContinuation { continuation in
            socket.connect { _ in
                socket.receiveNext { _ in
                    continuation.resume(returning: probe.isCurrentQueue)
                }
            }
        }

        try #require(result)
    }
}
