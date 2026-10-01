import Foundation
import Network

extension NWProtocolDefinition {
    static var mock: NWProtocolFramer.Definition { _MockAnyProtocol.definition }
}

extension NWProtocolOptions {
    static func mock() -> NWProtocolFramer.Options {
        return NWProtocolFramer.Options(definition: .mock)
    }
}

final class _MockAnyProtocol: NWProtocolFramerImplementation, @unchecked Sendable {
    static let definition = NWProtocolFramer.Definition(implementation: _MockAnyProtocol.self)
    static let label: String = "_MockAnyProtocol"

    init(framer: NWProtocolFramer.Instance) {
    }

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        .ready
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        0
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message,
                      messageLength: Int, isComplete: Bool)
    {
    }

    func wakeup(framer: NWProtocolFramer.Instance) {
    }

    func stop(framer: NWProtocolFramer.Instance) -> Bool {
        true
    }

    func cleanup(framer: NWProtocolFramer.Instance) {
    }
}
