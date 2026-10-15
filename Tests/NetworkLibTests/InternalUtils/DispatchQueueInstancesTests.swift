import Foundation
import Testing
@testable import NetworkLib

extension Tag.Utils {
    @Tag static var dispatchQueue: Tag
}

@Suite(.tags(.Utils.all, .Utils.dispatchQueue))
struct DispatchQueueInstancesTests {
    @Test
    func queuesHaveExpectedLabelsAndQoS() {
        let cases: [(queue: DispatchQueue, label: String)] = [
            (.RawSocket.access, "com.network_lib.raw_socket"),
            (.RawSocket.delegate, "com.network_lib.raw_socket.delegate"),
            (.HTTPTask.access, "com.network_lib.http_task"),
            (.HTTPTask.delegate, "com.network_lib.http_task.delegate")
        ]

        for item in cases {
            #expect(item.queue.label == item.label)
            #expect(item.queue.qos == .unspecified)
        }
    }

    @Test
    func queuesAreSerial() throws {
        let queues: [DispatchQueue] = [
            .RawSocket.access,
            .RawSocket.delegate,
            .HTTPTask.access,
            .HTTPTask.delegate
        ]

        for queue in queues {
            let state = ExecutionState()
            let group = DispatchGroup()

            for _ in 0 ..< 20 {
                group.enter()
                queue.async {
                    state.beginExecution()
                    Thread.sleep(forTimeInterval: 0.001)
                    state.endExecution()
                    group.leave()
                }
            }

            try #require(group.wait(timeout: .now() + 1) == .success)
            #expect(state.maximumConcurrentExecutions == 1)
        }
    }
}

private final class ExecutionState: @unchecked Sendable {
    private let lock = NSLock()
    private var activeExecutions = 0
    private(set) var maximumConcurrentExecutions = 0

    func beginExecution() {
        lock.withLock {
            activeExecutions += 1
            maximumConcurrentExecutions = max(maximumConcurrentExecutions, activeExecutions)
        }
    }

    func endExecution() {
        lock.withLock {
            activeExecutions -= 1
        }
    }
}
