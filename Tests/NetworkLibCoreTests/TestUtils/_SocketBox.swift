import Foundation
@testable import NetworkLibCore

final class _SocketBox: @unchecked Sendable {
    private let lock: NSLock = NSLock()
    private var _socket: RawSocket?

    func set(_ socket: RawSocket?) {
        lock.withLock {
            _socket = socket
        }
    }

    func get() -> RawSocket? {
        lock.withLock {
            _socket
        }
    }
}
