import Foundation
import Network

protocol ProtocolFramerImplementation {
    init()

    func start(framer: any ProtocolFramer) -> NWProtocolFramer.StartResult
    func handleInput(framer: any ProtocolFramer) -> Int
    func handleOutput(framer: any ProtocolFramer, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool)
}
