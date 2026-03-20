import Foundation

struct AsyncTimeoutError: Error {}

func withAsyncTimeout<T: Sendable>(_ timeout: Duration, block: @escaping @Sendable () async throws -> T) async rethrows -> T {
    try await withThrowingTaskGroup { group in
        group.addTask {
            try await block()
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
