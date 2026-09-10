import Foundation
import Network

// swiftlint:disable line_length

protocol UnderlyingConnection: AnyObject {
    var state: NWConnection.State { get }
    var stateUpdateHandler: (@Sendable (_ state: NWConnection.State) -> Void)? { get set }

    func connectionInfo(with transport: RawSocketTransport) -> ConnectionInfo

    func start(queue: DispatchQueue)
    func cancel()
    func forceCancel()

    func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping @Sendable (_ content: Data?, _ contentContext: NWConnection.ContentContext?, _ isComplete: Bool, _ error: NWError?) -> Void)
    func receiveMessage(completion: @escaping @Sendable (_ content: Data?, _ contentContext: NWConnection.ContentContext?, _ isComplete: Bool, _ error: NWError?) -> Void)
    func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
}

extension UnderlyingConnection {
    func send(content: Data?, contentContext: NWConnection.ContentContext = .defaultMessage, isComplete: Bool = true, completion: NWConnection.SendCompletion) {
        send(content: content, contentContext: contentContext, isComplete: isComplete, completion: completion)
    }
}

// swiftlint:enable line_length
