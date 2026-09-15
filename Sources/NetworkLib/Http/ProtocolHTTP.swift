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

enum HTTPMessageKind: Sendable, CustomStringConvertible {
    case response
    case body
    case end

    var description: String {
        switch self {
        case .response: return "Response"
        case .body: return "Body"
        case .end: return "End"
        }
    }
}

// MARK: - PRIVATE IMPLEMENTATIONS AND ENTITIES

private final class ProtocolHTTP: NWProtocolFramerImplementation, @unchecked Sendable {
    static let definition = NWProtocolFramer.Definition(implementation: ProtocolHTTP.self)
    static let label: String = "ProtocolHTTP"

    private let parser: HTTPResponseParser
    private var pendingEvents: [HTTPResponseParser.Event]

    init(framer: NWProtocolFramer.Instance) {
        parser = HTTPResponseParser()
        pendingEvents = []
    }

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        return .ready
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        if !deliverPendingEventsUnsafe(with: framer) {
            return 0
        }
        while true {
            var ended = false
            let parsed = framer.parseInput(minimumIncompleteLength: 1, maximumLength: .max) { buffer, _ in
                foo(with: framer, buffer, &ended)
            }
            if !parsed { return 0 }
            if ended { return 0 }
        }
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message,
                      messageLength: Int, isComplete: Bool)
    {
        guard isComplete else {
            framer.markFailed(error: .posix(.EIO))
            return
        }
        guard messageLength == 0 else {
            framer.markFailed(error: .posix(.EMSGSIZE))
            return
        }
        guard let request = message.httpRequest else {
            framer.markFailed(error: .posix(.EBADMSG))
            return
        }
        let requestParser = HTTPRequestParser(request, version: .v1_1)
        framer.writeOutput(data: requestParser.parsedData)
    }

    func wakeup(framer: NWProtocolFramer.Instance) {
    }

    func stop(framer: NWProtocolFramer.Instance) -> Bool {
        true
    }

    func cleanup(framer: NWProtocolFramer.Instance) {
    }
}

extension ProtocolHTTP {
    private func foo(with framer: NWProtocolFramer.Instance, _ buffer: UnsafeMutableRawBufferPointer?,
                     _ ended: inout Bool) -> Int
    {
        guard let buffer, !buffer.isEmpty else { return 0 }
        let assumedBuffer = buffer.assumingMemoryBound(to: UInt8.self)
        let data = Data(bytes: assumedBuffer.baseAddress!, count: buffer.count)
        do throws(HTTPResponseParser.Error) {
            let events = try parser.append(data)
            pendingEvents.append(contentsOf: events)
            if deliverPendingEventsUnsafe(with: framer) {
                ended = events.contains {
                    if case .end = $0 { return true }
                    return false
                }
            }
        } catch {
            switch error {
            case .invalidChunkSize: framer.markFailed(error: .posix(.EIO))
            case .invalidChunkTerminator: framer.markFailed(error: .posix(.EPROTO))
            case .parsingCompleted: framer.markFailed(error: .posix(.EINVAL))
            }
        }
        return buffer.count
    }
    private func deliverPendingEventsUnsafe(with framer: NWProtocolFramer.Instance) -> Bool {
        while !pendingEvents.isEmpty {
            let event = pendingEvents[0]
            guard deliver(event, with: framer) else { return false }
            pendingEvents.removeFirst()
        }
        return true
    }

    private func deliver(_ event: HTTPResponseParser.Event, with framer: NWProtocolFramer.Instance) -> Bool {
        let message = NWProtocolFramer.Message(definition: Self.definition)
        switch event {
        case let .response(response):
            message.httpKind = .response
            message.httpResponse = response
            return framer.deliverInputNoCopy(length: 0, message: message, isComplete: true)
        case let .data(data):
            message.httpKind = .body
            framer.deliverInput(data: data, message: message, isComplete: true)
            return true
        case .end:
            message.httpKind = .end
            return framer.deliverInputNoCopy(length: 0, message: message, isComplete: true)
        }
    }
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
