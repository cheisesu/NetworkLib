import Foundation

struct CallbackDelivery: Sendable {
    private let queue: DispatchQueue?

    init(queue: DispatchQueue? = nil) {
        self.queue = queue
    }

    func call(_ callback: @Sendable @escaping () -> Void) {
        if let queue {
            queue.async {
                callback()
            }
        } else {
            callback()
        }
    }

    func call<Value: Sendable>(_ value: Value, _ callback: @Sendable @escaping (Value) -> Void) {
        if let queue {
            queue.async {
                callback(value)
            }
        } else {
            callback(value)
        }
    }
}
