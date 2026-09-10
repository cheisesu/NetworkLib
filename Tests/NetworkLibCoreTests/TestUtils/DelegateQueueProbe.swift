import Foundation

final class DelegateQueueProbe: @unchecked Sendable {
    private let key = DispatchSpecificKey<Int>()
    private let value = 1

    var isCurrentQueue: Bool {
        DispatchQueue.getSpecific(key: key) == value
    }

    func install(on queue: DispatchQueue) {
        queue.setSpecific(key: key, value: value)
    }
}
