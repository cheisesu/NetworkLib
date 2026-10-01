import Foundation
import Network
@testable import NetworkLib

final class MockProtocolFramer: ProtocolFramer, @unchecked Sendable {
    struct DeliveredInput {
        let data: Data?
        let message: NWProtocolFramer.Message
        let isComplete: Bool
        let noCopy: Bool
    }

    struct ParseInputCall {
        let minimumIncompleteLength: Int
        let maximumLength: Int
    }

    enum Event: Equatable {
        case deliver(HTTPMessageKind)
        case failure(NWError)
    }

    private var inputChunks: [Data]
    var outputs: [Data] = []
    var deliveredInputs: [DeliveredInput] = []
    var failures: [NWError] = []
    var parseInputCalls: [ParseInputCall] = []
    var deliverInputNoCopyResults = [Bool]()
    var events: [Event] = []
    var options: [String: Any] = [:]
    var asyncBlocks: [@Sendable () -> Void] = []
    var prependedProtocols: [NWProtocolOptions] = []
    var prependApplicationProtocolError: Error?
    var passThroughInputCount = 0
    var passThroughOutputCount = 0
    var markReadyCount = 0
    var definition: NWProtocolFramer.Definition?

    init(inputChunks: [Data] = []) {
        self.inputChunks = inputChunks
    }

    func appendInput(_ data: Data) {
        inputChunks.append(data)
    }

    func makeMessage() -> NWProtocolFramer.Message {
        NWProtocolFramer.Message(definition: definition!)
    }

    func parseInput(minimumIncompleteLength: Int, maximumLength: Int,
                    parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool {
        parseInputCalls.append(.init(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength))
        guard !inputChunks.isEmpty else { return false }

        var input = inputChunks.removeFirst()
        guard input.count >= minimumIncompleteLength else {
            inputChunks.insert(input, at: 0)
            return false
        }

        let count = min(input.count, maximumLength)
        var chunk = Data(input.prefix(count))
        let consumed = chunk.withUnsafeMutableBytes { parse($0, false) }

        precondition(consumed >= 0 && consumed <= count)

        if consumed < input.count {
            input.removeFirst(consumed)
            inputChunks.insert(input, at: 0)
        }

        return true
    }

    func writeOutput(data: Data) {
        outputs.append(data)
    }

    func deliverInput(data: Data, message: NWProtocolFramer.Message, isComplete: Bool) {
        deliveredInputs.append(.init(data: data, message: message, isComplete: isComplete, noCopy: false))

        if let kind = message.httpKind {
            events.append(.deliver(kind))
        }
    }

    func deliverInputNoCopy(length: Int, message: NWProtocolFramer.Message, isComplete: Bool) -> Bool {
        deliveredInputs.append(.init(data: nil, message: message, isComplete: isComplete, noCopy: true))

        if let kind = message.httpKind {
            events.append(.deliver(kind))
        }

        return deliverInputNoCopyResults.isEmpty ? true : deliverInputNoCopyResults.removeFirst()
    }

    func markFailed(error: NWError) {
        failures.append(error)
        events.append(.failure(error))
    }

    func async(_ block: @escaping @Sendable () -> Void) {
        asyncBlocks.append(block)
    }

    func runNextAsyncBlock() {
        guard !asyncBlocks.isEmpty else { return }
        asyncBlocks.removeFirst()()
    }

    func prependApplicationProtocol(options: NWProtocolOptions) throws {
        if let prependApplicationProtocolError {
            throw prependApplicationProtocolError
        }
        prependedProtocols.append(options)
    }

    func passThroughInput() {
        passThroughInputCount += 1
    }

    func passThroughOutput() {
        passThroughOutputCount += 1
    }

    func markReady() {
        markReadyCount += 1
    }

    subscript(key: String) -> Any? {
        get { options[key] }
        _modify { yield &options[key] }
    }
}
