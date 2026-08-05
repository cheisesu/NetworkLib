import Foundation
import Network

/// A typed inbound message that can be decoded from a Network framework content context and payload.
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public protocol RawSocketReceiveMessage: Sendable {
    /// Creates a typed message from received protocol metadata and optional payload bytes.
    ///
    /// Return `nil` when the context or payload does not describe a valid message of this type.
    ///
    /// - Parameters:
    ///   - context: The received Network framework content context.
    ///   - content: The optional payload bytes delivered with the context.
    init?(from context: NWConnection.ContentContext, with content: Data?)
}
