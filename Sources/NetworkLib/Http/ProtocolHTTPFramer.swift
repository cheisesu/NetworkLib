import Foundation
import Network

final class ProtocolHTTPFramer: ProtocolFramerImplementation, @unchecked Sendable {
    private static let maximumInputLength = 64 * 1024

    private let parser: HTTPResponseParser
    private var pendingEvents: ArraySlice<HTTPResponseParser.Event>
    private var pendingParserError: HTTPResponseParser.Error?

    init() {
        parser = HTTPResponseParser()
        pendingEvents = []
        pendingParserError = nil
    }

    func start(framer: any ProtocolFramer) -> NWProtocolFramer.StartResult {
        return .ready
    }

    func handleInput(framer: any ProtocolFramer) -> Int {
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

    func handleOutput(framer: any ProtocolFramer, message: NWProtocolFramer.Message,
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

    func wakeup(framer: any ProtocolFramer) {
    }

    func stop(framer: any ProtocolFramer) -> Bool {
        true
    }

    func cleanup(framer: any ProtocolFramer) {
    }
}

extension ProtocolHTTPFramer {
    private func parseInputBuffer(with framer: any ProtocolFramer, _ buffer: UnsafeMutableRawBufferPointer?,
                                  _ shouldStop: inout Bool) -> Int
    {
        guard let buffer, !buffer.isEmpty else { return 0 }
        let data = Data(buffer)
        do throws(HTTPResponseParser.Error) {
            var reachedEnd = false

            try parser.append(data) { event in
                assert(!reachedEnd, "Parser emitted an event after .end")
                pendingEvents.append(event)
                reachedEnd = event.isEnd
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
    private func deliverPendingEvents(with framer: any ProtocolFramer) -> Bool {
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

    private func deliver(_ event: HTTPResponseParser.Event, with framer: any ProtocolFramer) -> Bool {
        let message = framer.makeMessage()
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
