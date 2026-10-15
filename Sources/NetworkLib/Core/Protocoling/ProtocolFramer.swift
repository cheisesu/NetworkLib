import Foundation
import Network

protocol ProtocolFramer: Sendable {
    func makeMessage() -> NWProtocolFramer.Message
    func parseInput(minimumIncompleteLength: Int, maximumLength: Int,
                    parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool
    func writeOutput(data: Data)
    func deliverInput(data: Data, message: NWProtocolFramer.Message, isComplete: Bool)
    func deliverInputNoCopy(length: Int, message: NWProtocolFramer.Message, isComplete: Bool) -> Bool
    func markFailed(error: NWError)

    func async(_ block: @escaping @Sendable () -> Void)
    func prependApplicationProtocol(options: NWProtocolOptions) throws
    func passThroughInput()
    func passThroughOutput()
    func markReady()

    @available(macOS 12.3, *)
    subscript(key: String) -> Any? { get set }
}
