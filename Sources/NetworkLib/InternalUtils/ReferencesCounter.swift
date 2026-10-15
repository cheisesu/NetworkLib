import Foundation

final class ReferencesCounter: @unchecked Sendable {
    static let shared = ReferencesCounter()

    private let instancesLock: NSLock
    private var instances: [Int: Int]

    private init() {
        instancesLock = .init()
        instances = [:]
    }

    func increment<T: AnyObject>(_ instance: T?) {
        guard let instance else { return }
        let address = address(of: instance)
        instancesLock.withLock {
            instances[address, default: 0] += 1
        }
    }

    func decrement<T: AnyObject>(_ instance: T?) {
        guard let instance else { return }
        let address = address(of: instance)
        instancesLock.withLock {
            instances[address, default: 0] -= 1
        }
    }

    func count(of address: Int) -> Int {
        instancesLock.withLock {
            instances[address, default: 0]
        }
    }

    func address<T: AnyObject>(of instance: T?) -> Int {
        guard let instance else { return 0 }
        let opaque = Unmanaged.passUnretained(instance).toOpaque()
        let address = Int(bitPattern: opaque)
        return address
    }
}
