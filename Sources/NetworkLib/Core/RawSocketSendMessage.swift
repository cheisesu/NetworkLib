import Foundation
import Network

/// A type that supplies the metadata and optional payload for a ``RawSocket`` message-send operation.
///
/// Use a conforming value with ``RawSocket/sendMessage(_:_:)`` or ``RawSocket/sendMessage(_:)`` when the connection's
/// application protocol needs an `NWConnection.ContentContext`.
public nonisolated protocol RawSocketSendMessage: Sendable {
    /// The Network framework content context that carries protocol metadata and message-completion information.
    var context: NWConnection.ContentContext { get }

    /// The payload bytes to send with ``context``, or `nil` for a context-only message.
    var content: Data? { get }
}
