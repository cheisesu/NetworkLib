import Foundation

final class TimeoutRecursiveEvent: @unchecked Sendable {
    private let syncLock: NSLock
    private let timer: DispatchSourceTimer
    private var token: Int64
    private let timeout: TimeInterval
    private let queue: DispatchQueue

    init?(timeout: TimeInterval, on queue: DispatchQueue) {
        guard timeout > 0 else { return nil }
        self.timeout = timeout
        self.queue = queue
        timer = DispatchSource.makeTimerSource(queue: queue)
        syncLock = NSLock()
        token = 0
        // dispatch source must be activated before cancel or exc_bad_instruction will be produced
        // https://github.com/apple-oss-distributions/libdispatch/blob/libdispatch-187.7/src/source.c#L175
        timer.activate()
    }

    deinit {
        cancel()
    }

    func setHandler(_ handler: @escaping @Sendable (TimeoutRecursiveEvent) -> Void) {
        syncLock.lock()
        defer { syncLock.unlock() }

        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let (timer, token) = self.syncLock.withLock { (self.timer, self.token) }
            guard !timer.isCancelled, token > 0 else { return }
            handler(self)
        }
    }

    func touch(from: String = #function) {
        syncLock.lock()
        defer { syncLock.unlock() }
        guard !timer.isCancelled else { return }
        token &+= 1
        timer.schedule(deadline: .now() + timeout)
        timer.activate()
    }

    func detouch(from: String = #function) {
        syncLock.lock()
        defer { syncLock.unlock() }
        guard !timer.isCancelled else { return }
        token = max(0, token - 1)
        timer.schedule(deadline: .now() + timeout)
        timer.activate()
    }

    func cancel(from: String = #function) {
        syncLock.lock()
        defer { syncLock.unlock() }
        cancelUnsafe(from: from)
    }

    private func cancelUnsafe(from: String = #function) {
        token = 0
        timer.setEventHandler(handler: nil)
        timer.cancel()
    }
}
