import Foundation
import Network

/// A typed outbound message sent through a ``RawSocket`` message-send operation.
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public protocol RawSocketSendMessage: Sendable {
    /// The Network framework content context that carries protocol metadata for the message.
    var context: NWConnection.ContentContext { get }

    /// The optional payload bytes to send with the context.
    var content: Data? { get }
}
