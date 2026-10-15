import Foundation

extension AsyncThrowingStream {
    var values: [Element] {
        get async throws {
            try await reduce(into: [], { $0.append($1) })
        }
    }
}

extension AsyncStream {
    var values: [Element] {
        get async {
            await reduce(into: [], { $0.append($1) })
        }
    }
}
