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
