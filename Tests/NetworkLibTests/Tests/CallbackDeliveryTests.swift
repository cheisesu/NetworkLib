import Dispatch
import Testing
@testable import NetworkLib

extension Tag {
    @Tag static var callbackDelivery: Self
}

struct CallbackDeliveryTests {
    @Test(.tags(.callbackDelivery))
    func callWithoutQueueRunsInlineOnCurrentQueue() async {
        let queue = DispatchQueue(label: "callback-delivery.inline")
        let probe = QueueProbe()
        probe.install(on: queue)
        let delivery = CallbackDelivery()

        let isCurrentQueue = await withCheckedContinuation { continuation in
            queue.async {
                delivery.call {
                    continuation.resume(returning: probe.isCurrentQueue)
                }
            }
        }

        #expect(isCurrentQueue)
    }

    @Test(.tags(.callbackDelivery))
    func callWithQueueRunsOnSpecifiedQueue() async {
        let queue = DispatchQueue(label: "callback-delivery.queued")
        let probe = QueueProbe()
        probe.install(on: queue)
        let delivery = CallbackDelivery(queue: queue)

        let isCurrentQueue = await withCheckedContinuation { continuation in
            delivery.call {
                continuation.resume(returning: probe.isCurrentQueue)
            }
        }

        #expect(isCurrentQueue)
    }

    @Test(.tags(.callbackDelivery))
    func callWithValueWithoutQueueRunsInlineOnCurrentQueue() async {
        let queue = DispatchQueue(label: "callback-delivery.inline-value")
        let probe = QueueProbe()
        probe.install(on: queue)
        let delivery = CallbackDelivery()

        let result = await withCheckedContinuation { continuation in
            queue.async {
                delivery.call(42) { value in
                    continuation.resume(returning: (value, probe.isCurrentQueue))
                }
            }
        }

        #expect(result.0 == 42)
        #expect(result.1)
    }

    @Test(.tags(.callbackDelivery))
    func callWithValueForwardsValueOnSpecifiedQueue() async {
        let queue = DispatchQueue(label: "callback-delivery.value")
        let probe = QueueProbe()
        probe.install(on: queue)
        let delivery = CallbackDelivery(queue: queue)

        let result = await withCheckedContinuation { continuation in
            delivery.call(42) { value in
                continuation.resume(returning: (value, probe.isCurrentQueue))
            }
        }

        #expect(result.0 == 42)
        #expect(result.1)
    }
}

private final class QueueProbe: @unchecked Sendable {
    private let key = DispatchSpecificKey<Int>()
    private let value = 1

    var isCurrentQueue: Bool {
        DispatchQueue.getSpecific(key: key) == value
    }

    func install(on queue: DispatchQueue) {
        queue.setSpecific(key: key, value: value)
    }
}
