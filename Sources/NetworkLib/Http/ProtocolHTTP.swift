import Foundation
import Network

extension NWProtocolDefinition {
    static var http: NWProtocolFramer.Definition { return ProtocolHTTP.definition }
}

extension NWProtocolOptions {
    static func http() -> NWProtocolFramer.Options {
        return NWProtocolFramer.Options(definition: .http)
    }
}

struct HTTPSendMessage: Sendable, RawSocketSendMessage {
    let context: NWConnection.ContentContext
    let content: Data?

    init(_ urlRequest: URLRequest) {
        content = nil
        let meta = NWProtocolFramer.Message(definition: .http)
        meta.httpRequest = urlRequest
        context = .init(identifier: "ProtocolHTTP.Message.Request", isFinal: false, metadata: [meta])
    }
}

enum HTTPReceiveMessage: Sendable, RawSocketReceiveMessage, Equatable {
    case response(HTTPParserResponseResult)
    case data(Data)
    case end

    init?(from context: NWConnection.ContentContext, with content: Data?) {
        guard let meta = context.protocolMetadata(definition: .http) as? NWProtocolFramer.Message else { return nil }
        guard let kind = meta.httpKind else { return nil }
        switch kind {
        case .response:
            guard let response = meta.httpResponse else { return nil }
            self = .response(response)
        case .body:
            guard let content else { return nil }
            self = .data(content)
        case .end: self = .end
        }
    }
}

enum HTTPMessageKind: Sendable {
    case response
    case body
    case end
}

extension NWProtocolFramer.Message {
    private enum _Key: Sendable {
        static let response = "kHTTPMessageResponse"
        static let request = "kHTTPMessageRequest"
        static let kind = "kHTTPMessageKind"
    }

    var httpResponse: HTTPParserResponseResult? {
        get { self[_Key.response] as? HTTPParserResponseResult }
        set { self[_Key.response] = newValue }
    }

    var httpRequest: URLRequest? {
        get { self[_Key.request] as? URLRequest }
        set { self[_Key.request] = newValue }
    }

    var httpKind: HTTPMessageKind? {
        get { self[_Key.kind] as? HTTPMessageKind }
        set { self[_Key.kind] = newValue }
    }
}

// MARK: - PRIVATE IMPLEMENTATIONS AND ENTITIES

private final class ProtocolHTTP: NWProtocolFramerImplementation, @unchecked Sendable {
    static let definition = NWProtocolFramer.Definition(implementation: ProtocolHTTP.self)
    static let label: String = "ProtocolHTTP"

    private let implementation: any ProtocolFramerImplementation

    init(framer: NWProtocolFramer.Instance) {
        implementation = ProtocolHTTPFramer()
    }

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        return implementation.start(framer: .adapter(for: framer, Self.definition))
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        return implementation.handleInput(framer: .adapter(for: framer, Self.definition))
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message,
                      messageLength: Int, isComplete: Bool)
    {
        implementation.handleOutput(framer: .adapter(for: framer, Self.definition),
                                    message: message, messageLength: messageLength, isComplete: isComplete)
    }

    func wakeup(framer: NWProtocolFramer.Instance) {
    }

    func stop(framer: NWProtocolFramer.Instance) -> Bool {
        true
    }

    func cleanup(framer: NWProtocolFramer.Instance) {
    }
}
