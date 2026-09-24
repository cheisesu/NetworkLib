import Foundation
import Network
@testable import NetworkLib

final class MockProtocolFramer: ProtocolFramer {
    struct DeliveredInput {
        let data: Data?
        let message: NWProtocolFramer.Message
        let isComplete: Bool
        let noCopy: Bool
    }

    private var inputChunks: [Data]
    var outputs: [Data] = []
    var deliveredInputs: [DeliveredInput] = []
    var failures: [NWError] = []

    var deliverInputNoCopyResult = true

    init(inputChunks: [Data] = []) {
        self.inputChunks = inputChunks
    }

    func appendInput(_ data: Data) {
        inputChunks.append(data)
    }

    func makeMessage() -> NWProtocolFramer.Message {
        NWProtocolFramer.Message(definition: .http)
    }

    func parseInput(minimumIncompleteLength: Int, maximumLength: Int,
                    parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool {
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
    }

    func deliverInputNoCopy(length: Int, message: NWProtocolFramer.Message, isComplete: Bool) -> Bool {
        deliveredInputs.append(.init(data: nil, message: message, isComplete: isComplete, noCopy: true))
        return deliverInputNoCopyResult
    }

    func markFailed(error: NWError) {
        failures.append(error)
    }
}
