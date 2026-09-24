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

    private static let maximumInputLength = 64 * 1024

    private let parser: HTTPResponseParser
    private var pendingEvents: ArraySlice<HTTPResponseParser.Event>
    private var pendingParserError: HTTPResponseParser.Error?

    init(framer: NWProtocolFramer.Instance) {
        parser = HTTPResponseParser()
        pendingEvents = []
        pendingParserError = nil
    }

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        return .ready
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        if !deliverPendingEvents(with: framer) {
            return 0
        }
        while true {
            var shouldStop = false
            let parsed = framer.parseInput(minimumIncompleteLength: 1, maximumLength: Self.maximumInputLength) { buffer, _ in
                parseInputBuffer(with: framer, buffer, &shouldStop)
            }
            if !parsed { return 0 }
            if shouldStop { return 0 }
        }
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message,
                      messageLength: Int, isComplete: Bool)
    {
        guard isComplete else {
            framer.markFailed(error: .posix(.EPROTO))
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
    private func parseInputBuffer(with framer: NWProtocolFramer.Instance, _ buffer: UnsafeMutableRawBufferPointer?,
                                  _ shouldStop: inout Bool) -> Int
    {
        guard let buffer, !buffer.isEmpty else { return 0 }
        let data = Data(buffer)
        do throws(HTTPResponseParser.Error) {
            var reachedEnd = false

            try parser.append(data) { event in
                assert(!reachedEnd, "Parser emitted an event after .end")
                if !reachedEnd {
                    pendingEvents.append(event)
                }
                reachedEnd = reachedEnd || event.isEnd
            }

            let deliveryCompleted = deliverPendingEvents(with: framer)
            shouldStop = reachedEnd || !deliveryCompleted
        } catch {
            pendingParserError = error
            _ = deliverPendingEvents(with: framer)
            shouldStop = true
        }
        return buffer.count
    }
    private func deliverPendingEvents(with framer: NWProtocolFramer.Instance) -> Bool {
        while !pendingEvents.isEmpty {
            guard let event = pendingEvents.first else { break }
            guard deliver(event, with: framer) else { return false }
            pendingEvents.removeFirst()
        }
        pendingEvents = []
        guard let error = pendingParserError else { return true }
        pendingParserError = nil

        switch error {
        case .invalidChunkSize:
            framer.markFailed(error: .posix(.EBADMSG))
        case .invalidChunkTerminator, .parsingCompleted:
            framer.markFailed(error: .posix(.EPROTO))
        }

        return false
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
