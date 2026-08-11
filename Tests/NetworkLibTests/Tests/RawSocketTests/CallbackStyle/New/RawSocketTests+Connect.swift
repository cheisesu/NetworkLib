import Testing
import Foundation
import Network
@testable import NetworkLib

extension Tag {
    enum RawSocket {
        @Tag static var connect: Tag
        @Tag static var all: Tag
    }
}

struct RawSocketConnectTests {
    // MARK: TIMEOUT ERRORS

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func timeoutNonZero_UnableToConnect_ThrowsTimeoutError() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0.5
        let underlyingConnection = NWConnectionMock(overridedState: .preparing)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func timeoutZero_UnableToConnect_CallbackNotCalled() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(overridedState: .preparing)
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withAsyncTimeoutCancelationContinuation(.milliseconds(500), block: { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            }, onCancel: {
                socket.cancel(nil)
            })
            Issue.record("Unexpected entrance")
        } catch is AsyncTimeoutError {
        }
    }

    // MARK: SUCCESS ON STATES

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func whenNotConnected_CallbackSuccess() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        let info = try await withCheckedThrowingContinuation { continuation in
            socket.connect { result in
                continuation.resume(with: result)
            }
        }
        try #require(info == underlyingConnection.connectionInfo(with: transport))
    }

    // MARK: ERRORS ON STATES

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func whenConnecting_ThrowsAlreadyError() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.onInternalStateChange = { _, newState in
                    guard newState == .connecting else { return }
                    socket.connect { result in
                        continuation.resume(with: result)
                    }
                }
                socket.connect { _ in }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.EALREADY) {
        }
    }

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func whenConnected_ThrowsConnectedError() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.connect { result in
                        continuation.resume(with: result)
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.EISCONN) {
        }
    }

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func whenCancelling_ThrowsCanceledError() async throws {
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
                    socket.connect { result in
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

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func whenClosed_ThrowsCanceledError() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { _ in
                    socket.cancel {
                        socket.connect { result in
                            continuation.resume(with: result)
                        }
                    }
                }
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    // MARK: ENDPOINT ERRORS

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func whenAddressIsNotAvailable_FailsWithError() async throws {
        let config = RawSocketConfiguration("127-0-0-1", 65535, isSecure: false, sni: nil, transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
            Issue.record("Unexpected entrance")
        } catch NWError.dns(-65554) {
        }
    }

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func whenIpIsWrong_FailsWithError() async throws {
        let config = RawSocketConfiguration("127.0.0.256", 65535, isSecure: false, sni: nil, transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
            Issue.record("Unexpected entrance")
        } catch NWError.dns(-65554) {
        }
    }

    // MARK: ERRORS BY SERVER BEHAVIOUR

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func connectionGoesToFailedState_ThrowsErrorFromTheState() async throws {
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let expectedError = NWError.posix(.ECONNREFUSED)
        let underlyingConnection = NWConnectionMock(overridedState: .failed(expectedError))
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            }
            Issue.record("Unexpected entrance")
        } catch let error where error == expectedError {
        }
    }

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func whenServerNoExists_FailsWithRefusedError() async throws {
        let config = RawSocketConfiguration("127.0.0.1", 65535, isSecure: true, sni: "localhost", transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECONNREFUSED) {
        }
    }

    // MARK: CALLBACK CALLS

    @available(swift, introduced: 6.2)
    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func connectCallbackCalledOnlyOnce() async throws {
        try await #require(processExitsWith: .success) {
            let transport = RawSocketTransport.tcp
            let timeout: TimeInterval = 0
            let underlyingConnection = NWConnectionMock()
            let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                       maxDataBlock: 256, transport: transport)
            defer { socket.cancel(nil) }

            _ = try await withAsyncTimeoutCancelationContinuation(.seconds(2)) { continuation in
                socket.connect { result in
                    socket.cancel {
                    }
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }

            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: REFERENCE STORING

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func afterConnect_ReferenceStored() async throws {
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
            box.get()?.onInternalStateChange = { _, newState in
                guard newState == .connecting else { return }
                box.set(nil)
            }
            box.get()?.connect { result in
                continuation.resume(with: result)
            }
        }
        try #require(ReferencesCounter.shared.count(of: address) == 1)
    }

    // MARK: DELEGATE QUEUE

    @Test(.tags(.RawSocket.connect, .RawSocket.all), .timeLimit(.minutes(1)))
    func callbackCalledOnProvidedQueue() async throws {
        let delegateQueue = DispatchQueue(label: "delegate." + #function)
        let key = DispatchSpecificKey<Int>()
        delegateQueue.setSpecific(key: key, value: -12)
        let transport = RawSocketTransport.tcp
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: delegateQueue, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }

        let result = try await withAsyncTimeoutCancelationContinuation(.seconds(2)) { continuation in
            socket.connect { _ in
                continuation.resume(returning: DispatchQueue.getSpecific(key: key) == -12)
            }
        } onCancel: {
            socket.cancel(nil)
        }

        try #require(result)
    }
}
