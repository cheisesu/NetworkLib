import Foundation
import Network

protocol ProtocolFramer {
    func makeMessage() -> NWProtocolFramer.Message
    func parseInput(minimumIncompleteLength: Int, maximumLength: Int,
                    parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool
    func writeOutput(data: Data)
    func deliverInput(data: Data, message: NWProtocolFramer.Message, isComplete: Bool)
    func deliverInputNoCopy(length: Int, message: NWProtocolFramer.Message, isComplete: Bool) -> Bool
    func markFailed(error: NWError)
}
