import Foundation

struct AsyncTimeoutError: Error {}

@discardableResult
func withAsyncTimeout<T: Sendable>(_ timeout: Duration, block: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup { group in
        group.addTask {
            try await block()
        }
        group.addTask {
            try await Task.sleep(until: .now + timeout)
            throw AsyncTimeoutError()
        }

        defer { group.cancelAll() }
        return try await group.next()!
    }
}

@discardableResult
func withAsyncTimeoutCancelationContinuation<T: Sendable>(
    _ timeout: Duration,
    block: @escaping @Sendable (_ continuation: CheckedContinuation<T, Error>) -> Void,
    onCancel: @escaping @Sendable () -> Void
) async throws -> T {
    try await withThrowingTaskGroup { group in
        group.addTask {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    block(continuation)
                }
            } onCancel: {
                onCancel()
            }
        }
        group.addTask {
            try await Task.sleep(until: .now + timeout)
            throw AsyncTimeoutError()
        }

        defer { group.cancelAll() }
        guard let result = try await group.next() else { throw AsyncTimeoutError() }
        return result
    }
}

struct CallbackWasNotCalledError: Error {}

@discardableResult
func withAsyncTimeoutForceThrowingContinuation<T: Sendable>(
    _ timeout: Duration, forceTimeout: Duration,
    block: @escaping @Sendable (_ continuation: CheckedContinuation<T, Error>, _ cancel: @escaping @Sendable () -> Void) -> Void,
    onCancel: (@Sendable () -> Void)? = nil
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
                    let cancel = createForceCancel(for: continuation, after: forceTimeout)
                    block(continuation, cancel)
                }
            } onCancel: {
                onCancel?()
            }
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw AsyncTimeoutError()
        }

        defer { group.cancelAll() }
        var errors: [Error] = []
        while let next = await group.nextResult() {
            switch next {
            case let .success(value): return value
            case let .failure(error): errors.append(error)
            }
        }
        guard let last = errors.last else { throw AsyncTimeoutError() }
        throw last
    }
}

private func createForceCancel<T: Sendable>(for continuation: CheckedContinuation<T, Error>,
                                            after forceTimeout: Duration) -> @Sendable () -> Void
{
    let scheduleTask = Task {
        try await Task.sleep(for: forceTimeout)
        print("==>> shceduled force cancel")
        continuation.resume(throwing: CallbackWasNotCalledError())
    }
    return { scheduleTask.cancel() }
}
