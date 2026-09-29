import Foundation
import Network

extension ProtocolFramer where Self == NWProtocolFramerAdapter {
    static func adapter(for framer: NWProtocolFramer.Instance, _ definition: NWProtocolFramer.Definition) -> Self {
        NWProtocolFramerAdapter(framer: framer, definition: definition)
    }
}

struct NWProtocolFramerAdapter: ProtocolFramer {
    private let framer: NWProtocolFramer.Instance
    private let definition: NWProtocolFramer.Definition

    init(framer: NWProtocolFramer.Instance, definition: NWProtocolFramer.Definition) {
        self.framer = framer
        self.definition = definition
    }

    func makeMessage() -> NWProtocolFramer.Message {
        NWProtocolFramer.Message(definition: definition)
    }

    func parseInput(minimumIncompleteLength: Int, maximumLength: Int,
                    parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool {
        framer.parseInput(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, parse: parse)
    }

    func writeOutput(data: Data) {
        framer.writeOutput(data: data)
    }

    func deliverInput(data: Data, message: NWProtocolFramer.Message, isComplete: Bool) {
        framer.deliverInput(data: data, message: message, isComplete: isComplete)
    }

    func deliverInputNoCopy(length: Int, message: NWProtocolFramer.Message, isComplete: Bool) -> Bool {
        framer.deliverInputNoCopy(length: length, message: message, isComplete: isComplete)
    }

    func markFailed(error: NWError) {
        framer.markFailed(error: error)
    }

    func async(_ block: @escaping @Sendable () -> Void) {
        framer.async(execute: block)
    }

    func prependApplicationProtocol(options: NWProtocolOptions) throws {
        try framer.prependApplicationProtocol(options: options)
    }

    func passThroughInput() {
        framer.passThroughInput()
    }

    func passThroughOutput() {
        framer.passThroughOutput()
    }

    func markReady() {
        framer.markReady()
    }

    @available(macOS 12.3, *)
    subscript(key: String) -> Any? {
        get { framer.options[key] }
        _modify { yield &framer.options[key] }
    }
}
