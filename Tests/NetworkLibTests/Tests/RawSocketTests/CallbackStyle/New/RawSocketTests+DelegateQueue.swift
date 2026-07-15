import Foundation
import Network
import Testing
@testable import NetworkLib

extension Tag.RawSocket {
    @Tag static var rawSocketDelegateQueue: Tag
}

struct RawSocketDelegateQueueTests {
    @Test(.tags(.RawSocket.rawSocketDelegateQueue))
    func connectCallbackRunsOnDelegateQueue() async throws {
        let delegateQueue = DispatchQueue(label: "raw-socket.delegate.connect")
        let probe = DelegateQueueProbe()
        probe.install(on: delegateQueue)
        let server = try ServerMock(transport: .tcp, isSecure: false)
        defer { server.stop() }
        let port = try await server.start()
        let socket = try RawSocket(makeConfiguration(port: port), delegateQueue: delegateQueue)
        defer { socket.cancel(nil) }

        let check = try await withAsyncTimeout(.seconds(3)) { () async throws -> CallbackCheck in
            await withCheckedContinuation { continuation in
                socket.connect { result in
                    continuation.resume(returning: CallbackCheck(
                        isOnDelegateQueue: probe.isCurrentQueue,
                        isExpectedResult: result.isSuccess
                    ))
                }
            }
        }

        #expect(check.isOnDelegateQueue)
        #expect(check.isExpectedResult)
    }

    @Test(.tags(.RawSocket.rawSocketDelegateQueue))
    func cancelCallbackRunsOnDelegateQueue() async throws {
        let delegateQueue = DispatchQueue(label: "raw-socket.delegate.cancel")
        let probe = DelegateQueueProbe()
        probe.install(on: delegateQueue)
        let socket = try RawSocket(makeConfiguration(), delegateQueue: delegateQueue)

        let isOnDelegateQueue = try await withAsyncTimeout(.seconds(1)) { () async throws -> Bool in
            await withCheckedContinuation { continuation in
                socket.cancel {
                    continuation.resume(returning: probe.isCurrentQueue)
                }
            }
        }

        #expect(isOnDelegateQueue)
    }

    @Test(.tags(.RawSocket.rawSocketDelegateQueue))
    func sendCallbackRunsOnDelegateQueue() async throws {
        let delegateQueue = DispatchQueue(label: "raw-socket.delegate.send")
        let probe = DelegateQueueProbe()
        probe.install(on: delegateQueue)
        let socket = try RawSocket(makeConfiguration(), delegateQueue: delegateQueue)
        defer { socket.cancel(nil) }

        let check = try await withAsyncTimeout(.seconds(1)) { () async throws -> CallbackCheck in
            await withCheckedContinuation { continuation in
                socket.send(Data("Hello".utf8)) { error in
                    continuation.resume(returning: CallbackCheck(
                        isOnDelegateQueue: probe.isCurrentQueue,
                        isExpectedResult: error.isPOSIX(.ENOTCONN)
                    ))
                }
            }
        }

        #expect(check.isOnDelegateQueue)
        #expect(check.isExpectedResult)
    }

    @Test(.tags(.RawSocket.rawSocketDelegateQueue))
    func sendMessageCallbackRunsOnDelegateQueue() async throws {
        let delegateQueue = DispatchQueue(label: "raw-socket.delegate.send-message")
        let probe = DelegateQueueProbe()
        probe.install(on: delegateQueue)
        let socket = try RawSocket(makeConfiguration(), delegateQueue: delegateQueue)
        defer { socket.cancel(nil) }

        let check = try await withAsyncTimeout(.seconds(1)) { () async throws -> CallbackCheck in
            await withCheckedContinuation { continuation in
                socket.sendMessage(DelegateQueueSendMessage()) { error in
                    continuation.resume(returning: CallbackCheck(
                        isOnDelegateQueue: probe.isCurrentQueue,
                        isExpectedResult: error.isPOSIX(.ENOTCONN)
                    ))
                }
            }
        }

        #expect(check.isOnDelegateQueue)
        #expect(check.isExpectedResult)
    }

    @Test(.tags(.RawSocket.rawSocketDelegateQueue))
    func receiveNextCallbackRunsOnDelegateQueue() async throws {
        let delegateQueue = DispatchQueue(label: "raw-socket.delegate.receive")
        let probe = DelegateQueueProbe()
        probe.install(on: delegateQueue)
        let socket = try RawSocket(makeConfiguration(), delegateQueue: delegateQueue)
        defer { socket.cancel(nil) }

        let check = try await withAsyncTimeout(.seconds(1)) { () async throws -> CallbackCheck in
            await withCheckedContinuation { continuation in
                socket.receiveNext { result in
                    continuation.resume(returning: CallbackCheck(
                        isOnDelegateQueue: probe.isCurrentQueue,
                        isExpectedResult: result.isPOSIXFailure(.ENOTCONN)
                    ))
                }
            }
        }

        #expect(check.isOnDelegateQueue)
        #expect(check.isExpectedResult)
    }

    @Test(.tags(.RawSocket.rawSocketDelegateQueue))
    func receiveNextMessageCallbackRunsOnDelegateQueue() async throws {
        let delegateQueue = DispatchQueue(label: "raw-socket.delegate.receive-message")
        let probe = DelegateQueueProbe()
        probe.install(on: delegateQueue)
        let socket = try RawSocket(makeConfiguration(), delegateQueue: delegateQueue)
        defer { socket.cancel(nil) }

        let check = try await withAsyncTimeout(.seconds(1)) { () async throws -> CallbackCheck in
            await withCheckedContinuation { continuation in
                socket.receiveNextMessage(of: DelegateQueueReceiveMessage.self) { result in
                    continuation.resume(returning: CallbackCheck(
                        isOnDelegateQueue: probe.isCurrentQueue,
                        isExpectedResult: result.isPOSIXFailure(.ENOTCONN)
                    ))
                }
            }
        }

        #expect(check.isOnDelegateQueue)
        #expect(check.isExpectedResult)
    }

    private func makeConfiguration(port: NWEndpoint.Port? = nil) throws -> RawSocketConfiguration {
        let port = try port ?? #require(NWEndpoint.Port(rawValue: 1))
        return RawSocketConfiguration("127.0.0.1", port, isSecure: false, sni: nil, transport: .tcp,
                                      maxDataBlock: 256, timeout: 0)
    }
}

private struct CallbackCheck: Sendable {
    let isOnDelegateQueue: Bool
    let isExpectedResult: Bool
}

private struct DelegateQueueSendMessage: RawSocketSendMessage {
    let context: NWConnection.ContentContext = .defaultMessage
    let content: Data? = Data("Hello".utf8)
}

private struct DelegateQueueReceiveMessage: RawSocketReceiveMessage {
    init?(from context: NWConnection.ContentContext, with content: Data?) {}
}

private final class DelegateQueueProbe: @unchecked Sendable {
    private let key = DispatchSpecificKey<Int>()
    private let value = 1

    var isCurrentQueue: Bool {
        DispatchQueue.getSpecific(key: key) == value
    }

    func install(on queue: DispatchQueue) {
        queue.setSpecific(key: key, value: value)
    }
}

private extension Optional where Wrapped == NWError {
    func isPOSIX(_ code: POSIXErrorCode) -> Bool {
        guard case let .some(.posix(errorCode)) = self else { return false }
        return errorCode == code
    }
}

private extension Result where Failure == NWError {
    var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }

    func isPOSIXFailure(_ code: POSIXErrorCode) -> Bool {
        guard case let .failure(.posix(errorCode)) = self else { return false }
        return errorCode == code
    }
}
