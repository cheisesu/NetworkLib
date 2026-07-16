import Testing
import Foundation
import Network
@testable import NetworkLib

extension Tag {
    enum RawSocket {
        @Tag static var connect: Tag
    }
    @Tag static var rawSocketAll: Tag
}

struct RawSocketConnectTests {
    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, TimeInterval(0), nil as String?),
        (RawSocketTransport.tcp, TimeInterval(0), "localhost"),
        (RawSocketTransport.tcp, TimeInterval(1), nil as String?),
        (RawSocketTransport.tcp, TimeInterval(1), "localhost"),
        (RawSocketTransport.udp, TimeInterval(0), nil as String?),
        (RawSocketTransport.udp, TimeInterval(0), "localhost"),
        (RawSocketTransport.udp, TimeInterval(1), nil as String?),
        (RawSocketTransport.udp, TimeInterval(1), "localhost"),
    ])
    func connectSuccess(_ transport: RawSocketTransport, _ timeout: TimeInterval, _ sni: String?) async throws {
        let isSecure = sni != nil
        let server = try ServerMock(transport: transport, isSecure: isSecure)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let info = try await withAsyncTimeoutCancelationContinuation(.seconds(2)) { continuation in
            socket.connect { result in
                continuation.resume(with: result)
            }
        } onCancel: {
            socket.cancel(nil)
        }

        try #require(info.transport == transport)
        try #require(info.interface?.name == "lo0")
        try #require(info.remoteEndpoint == .hostPort(host: "127.0.0.1", port: port))
        switch info.localEndpoint {
        case let .hostPort(host, _): try #require(host.asString == "127.0.0.1")
        default: Issue.record("Unexpected local endpoint")
        }
    }

    @available(swift, introduced: 6.2)
    @Test(.tags(.RawSocket.connect, .rawSocketAll))
    func connectThenCancel_ConnectCallback_CalledOnlyOnce() async throws {
        try await #require(processExitsWith: .success) {
            let server = try ServerMock(transport: .tcp, isSecure: false)
            defer { server.stop() }
            let port = try await server.start()
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: false, sni: nil, transport: .tcp,
                                                maxDataBlock: 256, timeout: 0)
            let socket = try RawSocket(config)
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

    @Test(.tags(.RawSocket.connect, .rawSocketAll))
    func whenServerSecureAndSocketInsecure_Success() async throws {
        let server = try ServerMock(transport: .tcp, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: false, sni: nil, transport: .tcp,
                                            maxDataBlock: 256, timeout: 0.2)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        let info = try await withAsyncTimeoutCancelationContinuation(.seconds(2)) { continuation in
            socket.connect { result in
                continuation.resume(with: result)
            }
        } onCancel: {
            socket.cancel(nil)
        }

        try #require(info.transport == .tcp)
        try #require(info.interface?.name == "lo0")
        try #require(info.remoteEndpoint == .hostPort(host: "127.0.0.1", port: port))
    }

    // MARK: ERRORS TIMEOUTS

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, nil as String?),
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, "localhost"),
    ])
    func zeroTimeout_UnableToConnect_NotFails(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let config = RawSocketConfiguration("127.0.0.10", 65535, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch is AsyncTimeoutError {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, nil as String?),
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, "localhost"),
    ])
    func nonZeroTimeout_UnableToConnect_FailsWithTimeoutError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let config = RawSocketConfiguration("127.0.0.10", 65535, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0.5)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, "localhost"),
    ])
    func zeroTimeout_whenServerInsecureAndSocketSecure_CallbackNotCalled(_ transport: RawSocketTransport, _ sni: String) async throws {
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch is AsyncTimeoutError {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, "localhost"),
    ])
    func nonZeroTimeout_whenServerInsecureAndSocketSecure_FailsWithTimeoutError(_ transport: RawSocketTransport, _ sni: String) async throws {
        let server = try ServerMock(transport: transport, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0.5)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }

    // MARK: ERRORS ON DIFFERENT STATES

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, nil as String?),
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, nil as String?),
        (RawSocketTransport.udp, "localhost"),
    ])
    func whenConnecting_FailsWithAlreadyConnectingError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let server = try ServerMock(transport: transport, isSecure: isSecure)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { _ in
                }
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.EALREADY) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, nil as String?),
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, nil as String?),
        (RawSocketTransport.udp, "localhost"),
    ])
    func whenConnected_FailsWithConnectedError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let server = try ServerMock(transport: transport, isSecure: isSecure)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { _ in
                    socket.connect { result in
                        continuation.resume(with: result)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.EISCONN) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, nil as String?),
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, nil as String?),
        (RawSocketTransport.udp, "localhost"),
    ])
    func whenCancelling_FailsWithCancelledError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let server = try ServerMock(transport: transport, isSecure: isSecure)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { _ in
                    socket.cancel(nil)
                    socket.connect { result in
                        continuation.resume(with: result)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, nil as String?),
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, nil as String?),
        (RawSocketTransport.udp, "localhost"),
    ])
    func whenCancelling_NotProducesNewConnect(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let server = try ServerMock(transport: transport, isSecure: isSecure)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { _ in
                    socket.cancel(nil)
                    socket.connect { result in
                        continuation.resume(with: result)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, nil as String?),
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, nil as String?),
        (RawSocketTransport.udp, "localhost"),
    ])
    func whenCancelled_FailsWithCancelledError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let server = try ServerMock(transport: transport, isSecure: isSecure)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.cancel {
                    socket.connect { result in
                        continuation.resume(with: result)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, nil as String?),
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, nil as String?),
        (RawSocketTransport.udp, "localhost"),
    ])
    func whenCancelledAfterConnect_FailsWithCancelledError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let server = try ServerMock(transport: transport, isSecure: isSecure)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { _ in
                    socket.cancel {
                        socket.connect { result in
                            continuation.resume(with: result)
                        }
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, nil as String?),
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, nil as String?),
        (RawSocketTransport.udp, "localhost"),
    ])
    func whenCancelledBeforeConnect_ConnectInsideCancelCallback_FailsWithCancelledError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let server = try ServerMock(transport: transport, isSecure: isSecure)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.cancel {
                    socket.connect { result in
                        continuation.resume(with: result)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, nil as String?),
        (RawSocketTransport.tcp, "localhost"),
        (RawSocketTransport.udp, nil as String?),
        (RawSocketTransport.udp, "localhost"),
    ])
    func whenCancelledBeforeConnect_FailsWithCancelledError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let server = try ServerMock(transport: transport, isSecure: isSecure)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.cancel(nil)
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    // MARK: ENDPOINT ERRORS

    @Test(.tags(.RawSocket.connect, .rawSocketAll))
    func whenAddressIsNotAvailable_FailsWithError() async throws {
        let config = RawSocketConfiguration("127-0-0-1", 65535, isSecure: false, sni: nil, transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(3)) { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.dns(-65554) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll))
    func whenIpIsWrong_FailsWithError() async throws {
        let config = RawSocketConfiguration("127.0.0.256", 65535, isSecure: false, sni: nil, transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(3)) { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.dns(-65554) {
        }
    }

    // MARK: ERRORS BY SERVER BEHAVIOUR

    @Test(.tags(.RawSocket.connect, .rawSocketAll), arguments: [
        (RawSocketTransport.tcp, "localhost"),
    ])
    func whenServerNotAcceptsConnection_FailsWithResetError(_ transport: RawSocketTransport, _ sni: String?) async throws {
        let isSecure = sni != nil
        let server = try ServerMock(transport: .tcp, isSecure: isSecure, flow: .cancel)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: isSecure, sni: sni, transport: transport,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECONNRESET) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll))
    func whenServerNoExists_FailsWithRefusedError() async throws {
        let config = RawSocketConfiguration("127.0.0.1", 65535, isSecure: true, sni: "localhost", transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECONNREFUSED) {
        }
    }

    @Test(.tags(.RawSocket.connect, .rawSocketAll))
    func differentTransports_FailsWithRefusedError() async throws {
        let server = try ServerMock(transport: .udp, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }

        do {
            try await withAsyncTimeoutCancelationContinuation(.seconds(1)) { continuation in
                socket.connect { result in
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECONNREFUSED) {
        }
    }

    // MARK: ON LEAKS

    @Test(.tags(.RawSocket.connect, .rawSocketAll))
    func nillifyVariableAfterConnectStart_CallbackSuccess() async throws {
        struct _CallbackWasNotCalledError: Error {}
        let server = try ServerMock(transport: .tcp, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let box = _SocketBox()
        try box.set(RawSocket(config))
        defer { box.get()?.cancel(nil) }

        box.get()?.onInternalStateChange = { _, newState in
            guard newState == .connecting else { return }
            box.set(nil)
        }
        let connectTask = Task {
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                box.get()?.connect { result in
                    cancel()
                    continuation.resume(with: result)
                }
            } onCancel: {
                box.get()?.cancel(nil)
            }
        }
        _ = try await connectTask.value
    }

    // MARK: CALLBACKS CALLED ON PROVIDED DELEGATE QUEUE

    @Test(.tags(.RawSocket.connect, .rawSocketAll))
    func callbacksOnProvidedDelegateQueue() async throws {
        let server = try ServerMock(transport: .tcp, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: false, sni: nil, transport: .tcp,
                                            maxDataBlock: 256, timeout: 0)
        let delegateQueue = DispatchQueue(label: "delegate." + #function)
        let key = DispatchSpecificKey<Int>()
        delegateQueue.setSpecific(key: key, value: -12)
        let socket = try RawSocket(config, delegateQueue: delegateQueue)
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
