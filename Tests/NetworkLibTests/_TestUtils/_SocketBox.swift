import Foundation
@testable import NetworkLib

final class _WeakSocketBox {
    weak var socket: RawSocket?

    init(_ socket: RawSocket?) {
        self.socket = socket
    }
}

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
