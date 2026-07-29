import Testing
import Foundation
import Network
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var receive: Tag
}

struct RawSocketReceiveTests {
    // MARK: SUCCESS BY DATA PORTIONS

    @Test(.tags(.RawSocket.all, .RawSocket.receive), arguments: [
        (RawSocketTransport.tcp, 243, Data.random(of: 797).byChunks(of: 243)),
        (RawSocketTransport.tcp, .max, [Data.random(of: 797)]),
        (RawSocketTransport.udp, 243, Data.random(of: 797).byChunks(of: 243)),
        (RawSocketTransport.udp, .max, [Data.random(of: 797)]),
    ])
    func byChunkSize_ReceivedAppropriatePortions(_ transport: RawSocketTransport, _ maxDataBlock: Int, _ portions: [Data]) async throws {
        let timeout: TimeInterval = 0
        let dataToReceive = Data(portions.joined())
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: maxDataBlock, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
        try await server.sendToConnection(data: dataToReceive)
        let (stream, seqContinuation) = AsyncThrowingStream<Data, Error>.makeStream()
        socket.receiveCycle { result, shouldContinue in
            do {
                if let value = try result.get() {
                    shouldContinue = true
                    seqContinuation.yield(value)
                } else {
                    shouldContinue = false
                    seqContinuation.finish()
                }
            } catch {
                shouldContinue = false
                seqContinuation.finish(throwing: error)
            }
        }
        server.stop()
        let resultPortions = try await withAsyncTimeout(.seconds(1)) {
            try await stream.values
        }

        try #require(resultPortions == portions)
    }

    // MARK: SUCCESS IN DIFFERENT STATE

    @Test(.tags(.RawSocket.all, .RawSocket.receive), arguments: [RawSocketTransport.tcp, .udp])
    func whenConnecting_ReceivedCorrectData(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let dataToReceive = Data.random(of: 800)
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: .max, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        socket.onInternalStateChange = { _, newState in
            guard newState == .connecting else { return }
            _ = Task {
                await server.waitForConnectionAppeared()
                try await server.sendToConnection(data: dataToReceive)
            }
        }
        try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
        let receivedData = try await withAsyncTimeoutForceThrowingContinuation(
            .seconds(2), forceTimeout: .milliseconds(2500)
        ) { continuation, cancel in
            socket.receiveNext { result in
                cancel()
                continuation.resume(with: result)
            }
        } onCancel: {
            socket.cancel(nil)
        }
        try #require(receivedData == dataToReceive)
    }

    // MARK: ERRORS IN DIFFERENT STATE

    @Test(.tags(.RawSocket.all, .RawSocket.receive), arguments: [RawSocketTransport.tcp, .udp])
    func whenNotConnected_ReturnsNotConnectedError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: .tcp, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                            maxDataBlock: .max, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        do {
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1), forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.receiveNext { result in
                    cancel()
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entry")
        } catch NWError.posix(.ENOTCONN) {
        }
    }

    @Test(.tags(.RawSocket.all, .RawSocket.receive), arguments: [RawSocketTransport.tcp, .udp])
    func whenCancelling_ReturnsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: .tcp, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                            maxDataBlock: .max, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
        do {
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1), forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.cancel(nil)
                socket.receiveNext { result in
                    cancel()
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entry")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.RawSocket.all, .RawSocket.receive), arguments: [RawSocketTransport.tcp, .udp])
    func whenCancelledInitially_ReturnsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: .tcp, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                            maxDataBlock: .max, timeout: timeout)
        let socket = try RawSocket(config)
        socket.cancel(nil)
        do {
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1), forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.receiveNext { result in
                    cancel()
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entry")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.RawSocket.all, .RawSocket.receive), arguments: [RawSocketTransport.tcp, .udp])
    func whenCancelledDuringReceiveFullData_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: .max, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
        do {
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1),
                                                                forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.receiveNext { result in
                    cancel()
                    continuation.resume(with: result)
                }
                socket.cancel(nil)
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECANCELED) {
        }
    }

    // MARK: ERROR BY SERVER STATE

    @Test(.tags(.RawSocket.all, .RawSocket.receive), arguments: [RawSocketTransport.tcp, .udp])
    func serverClosesConnection_CallbackCalledFinal(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: .max, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
        server.stop()
        let receivedData = try await withAsyncTimeoutForceThrowingContinuation(
            .seconds(1), forceTimeout: .milliseconds(1500)
        ) { continuation, cancel in
            socket.receiveNext { result in
                cancel()
                continuation.resume(with: result)
            }
        } onCancel: {
            socket.cancel(nil)
        }
        try #require(receivedData == nil)
    }

    @Test(.tags(.RawSocket.all, .RawSocket.receive), arguments: [RawSocketTransport.tcp])
    func serverClosesConnectionWhenSendsData_ReturnsConnectionResetError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data.random(of: 1000)
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 1000, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
        try await server.sendToConnection(data: dataToSend)
        server.forceStop()
        do {
            try await withAsyncTimeoutForceThrowingContinuation(
                .seconds(1), forceTimeout: .milliseconds(1500)
            ) { continuation, cancel in
                socket.receiveNext { result in
                    do {
                        _ = try result.get()
                        socket.receiveNext { result in
                            cancel()
                            continuation.resume(with: result)
                        }
                    } catch {
                        cancel()
                        continuation.resume(throwing: error)
                    }
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch NWError.posix(.ECONNRESET) {
        }
    }

    @Test(.tags(.RawSocket.all, .RawSocket.receive))
    func udpServerClosesConnectionWhenSendsData_ReceivesDataAndWaitsForNextDatagram() async throws {
        let timeout: TimeInterval = 0
        let dataToSend = Data.random(of: 1000)
        let server = try ServerMock(transport: .udp, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .udp,
                                            maxDataBlock: 1000, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
        try await server.sendToConnection(data: dataToSend)
        server.forceStop()

        let receivedData = try await withAsyncTimeoutForceThrowingContinuation(
            .seconds(1), forceTimeout: .milliseconds(1500)
        ) { continuation, cancel in
            socket.receiveNext { result in
                cancel()
                continuation.resume(with: result)
            }
        } onCancel: {
            socket.cancel(nil)
        }
        try #require(receivedData == dataToSend)

        do {
            try await withAsyncTimeoutForceThrowingContinuation(
                .milliseconds(300), forceTimeout: .milliseconds(800)
            ) { continuation, cancel in
                socket.receiveNext { result in
                    cancel()
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entrance")
        } catch is AsyncTimeoutError {
        }
    }

    @Test(.tags(.RawSocket.all, .RawSocket.receive))
    func serverForceClosesConnection_ReturnsConnectionResetError() async throws {
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: .tcp, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                            maxDataBlock: .max, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.testableConnect(.seconds(1), forceTimeout: .milliseconds(1500))
        server.forceStop()
        do {
            try await withAsyncTimeoutForceThrowingContinuation(.seconds(1), forceTimeout: .milliseconds(1500)) { continuation, cancel in
                socket.receiveNext { result in
                    cancel()
                    continuation.resume(with: result)
                }
            } onCancel: {
                socket.cancel(nil)
            }
            Issue.record("Unexpected entry")
        } catch NWError.posix(.ECONNRESET) {
        }
    }

    // MARK: ERRORS ON TIMEOUT

    @Test(.tags(.RawSocket.all, .RawSocket.receive), arguments: [RawSocketTransport.tcp, .udp])
    func nonZeroTimeout_ServerNotEchos_ReceivedTimeoutError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 1
        let server = try ServerMock(transport: transport, isSecure: true, flow: .none)
        defer { server.stop() }
        let port = try await server.start()
        let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: transport,
                                            maxDataBlock: 250, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.testableConnect(.seconds(2), forceTimeout: .milliseconds(2500))
        let (stream, seqContinuation) = AsyncThrowingStream<Data, Error>.makeStream()
        socket.receiveCycle { result, shouldContinue in
            do {
                if let value = try result.get() {
                    shouldContinue = true
                    seqContinuation.yield(value)
                } else {
                    shouldContinue = false
                    seqContinuation.finish()
                }
            } catch {
                shouldContinue = false
                seqContinuation.finish(throwing: error)
            }
        }
        do {
            _ = try await withAsyncTimeout(.seconds(2)) {
                try await stream.values
            }
            Issue.record("Unexpected entry")
        } catch NWError.posix(.ETIMEDOUT) {
        }
    }
}
