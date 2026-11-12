import Foundation
import Network

/// A type that can decode a complete Network framework message received by a ``RawSocket``.
///
/// Conforming types inspect both the content context and the optional payload. Use a conformance with
/// ``RawSocket/receiveNextMessage(of:_:)`` or ``RawSocket/receiveNextMessage(of:)``.
public nonisolated protocol RawSocketReceiveMessage: Sendable {
    /// Creates a typed message from received protocol metadata and optional payload bytes.
    ///
    /// Return `nil` when the context or payload doesn't describe a valid message of this type. NetworkLib reports that rejection
    /// to the receive operation as `NWError.posix(.EBADMSG)`.
    ///
    /// - Parameters:
    ///   - context: The received Network framework content context.
    ///   - content: The optional payload bytes delivered with the context.
    init?(from context: NWConnection.ContentContext, with content: Data?)
}
