import Foundation
import Network
import Testing
@testable import NetworkLib

@Suite(.tags(.HTTP.all, .HTTP.protocol), .timeLimit(.minutes(1)))
struct ProtocolHTTPFramerTests {
    @Test
    func proxy_ReturnsProtocolProxyFramer() {
        let proxyProto: any ProtocolFramerImplementation = .http()

        #expect(type(of: proxyProto) == ProtocolHTTPFramer.self)
    }

    @Test
    func startReturnsReady() throws {
        let httpProto = ProtocolHTTPFramer()
        let framerMock = MockProtocolFramer()
        let result = httpProto.start(framer: framerMock)
        #expect(result == .ready)
    }

    // MARK: - OUTPUT

    struct Output {
        @Test
        func incompleteOutput_ReturnsProtoError() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer()
            httpProto.handleOutput(framer: framerMock, message: NWProtocolFramer.Message(definition: .http),
                                   messageLength: 0, isComplete: false)
            try #require(framerMock.failures.count == 1)
            #expect(framerMock.failures[0] == .posix(.EPROTO))
            #expect(framerMock.outputs.isEmpty)
        }

        @Test
        func outputMessageSizeNonZero_ReturnsMessageSizeError() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer()
            httpProto.handleOutput(framer: framerMock, message: NWProtocolFramer.Message(definition: .http),
                                   messageLength: 10, isComplete: true)
            try #require(framerMock.failures.count == 1)
            #expect(framerMock.failures[0] == .posix(.EMSGSIZE))
            #expect(framerMock.outputs.isEmpty)
        }

        @Test
        func outputMessageWithoutRequest_ReturnsBadMessageError() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer()
            httpProto.handleOutput(framer: framerMock, message: NWProtocolFramer.Message(definition: .http),
                                   messageLength: 0, isComplete: true)
            try #require(framerMock.failures.count == 1)
            #expect(framerMock.failures[0] == .posix(.EBADMSG))
            #expect(framerMock.outputs.isEmpty)
        }

        @Test
        func correctMessageWithRequest_ReturnsParsedData() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer()
            let url = try #require(URL(string: "https://example.com/somepath?query=1"))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Some-value", forHTTPHeaderField: .allow)
            request.httpBody = Data("Hello".utf8)
            let requestData = HTTPRequestParser(request, version: .v1_1).parsedData
            let message = NWProtocolFramer.Message(definition: .http)
            message.httpRequest = request
            httpProto.handleOutput(framer: framerMock, message: message,
                                   messageLength: 0, isComplete: true)
            try #require(framerMock.outputs.count == 1)
            #expect(framerMock.outputs[0] == requestData)
            #expect(framerMock.failures.isEmpty)
        }
    }

    // MARK: - INPUT

    struct Input {
        // MARK: FULL INPUT AT ONCE

        @Test
        func emptyBody_DeliversResponseAndEnd() throws {
            let input = Data("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n".utf8)
            let framerMock = MockProtocolFramer(inputChunks: [input])
            framerMock.definition = .http
            let httpProto = ProtocolHTTPFramer()
            let result = httpProto.handleInput(framer: framerMock)

            #expect(result == 0)
            #expect(framerMock.outputs.isEmpty)
            #expect(framerMock.failures.isEmpty)

            try #require(framerMock.deliveredInputs.count == 2)
            let response = try #require(framerMock.deliveredInputs.first)
            #expect(response.data == nil)
            #expect(response.isComplete)
            #expect(response.noCopy)
            #expect(response.message.httpKind == .response)
            #expect(response.message.httpResponse?.status == 200)

            let end = try #require(framerMock.deliveredInputs.last)
            #expect(end.data == nil)
            #expect(end.isComplete)
            #expect(end.noCopy)
            #expect(end.message.httpKind == .end)
        }

        @Test
        func withContentLength_DeliversResponseAndDataAndEnd() throws {
            let input = Data("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello".utf8)
            let framerMock = MockProtocolFramer(inputChunks: [input])
            framerMock.definition = .http
            let httpProto = ProtocolHTTPFramer()

            let result = httpProto.handleInput(framer: framerMock)

            #expect(result == 0)
            #expect(framerMock.failures.isEmpty)
            try #require(framerMock.deliveredInputs.count == 3)

            let response = framerMock.deliveredInputs[0]
            #expect(response.data == nil)
            #expect(response.isComplete)
            #expect(response.noCopy)
            #expect(response.message.httpKind == .response)
            #expect(response.message.httpResponse?.status == 200)

            let body = framerMock.deliveredInputs[1]
            #expect(body.data == Data("Hello".utf8))
            #expect(body.isComplete)
            #expect(!body.noCopy)
            #expect(body.message.httpKind == .body)

            let end = framerMock.deliveredInputs[2]
            #expect(end.data == nil)
            #expect(end.isComplete)
            #expect(end.noCopy)
            #expect(end.message.httpKind == .end)
        }

        @Test
        func chunkedBody_DeliversResponseBodyAndEnd() throws {
            let input = Data("""
            HTTP/1.1 200 OK\r
            Transfer-Encoding: chunked\r
            \r
            5\r
            Hello\r
            0\r
            \r

            """.utf8)
            let framerMock = MockProtocolFramer(inputChunks: [input])
            framerMock.definition = .http
            let httpProto = ProtocolHTTPFramer()

            let result = httpProto.handleInput(framer: framerMock)

            #expect(result == 0)
            #expect(framerMock.failures.isEmpty)
            try #require(framerMock.deliveredInputs.count == 3)

            let response = framerMock.deliveredInputs[0]
            #expect(response.data == nil)
            #expect(response.isComplete)
            #expect(response.noCopy)
            #expect(response.message.httpKind == .response)
            #expect(response.message.httpResponse?.status == 200)

            let body = framerMock.deliveredInputs[1]
            #expect(body.data == Data("Hello".utf8))
            #expect(body.isComplete)
            #expect(!body.noCopy)
            #expect(body.message.httpKind == .body)

            let end = framerMock.deliveredInputs[2]
            #expect(end.data == nil)
            #expect(end.isComplete)
            #expect(end.noCopy)
            #expect(end.message.httpKind == .end)
        }

        // MARK: FRAGMENTED INPUT

        @Test
        func withFragmented_HeadersDeliversResponseBodyAndEnd() throws {
            let framerMock = MockProtocolFramer()
            framerMock.definition = .http
            let httpProto = ProtocolHTTPFramer()

            framerMock.appendInput(Data("HTTP/1.1 200 OK\r\nContent-Len".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            #expect(framerMock.deliveredInputs.isEmpty)
            #expect(framerMock.failures.isEmpty)

            framerMock.appendInput(Data("gth: 5\r\n\r\nHello".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            #expect(framerMock.failures.isEmpty)
            try #require(framerMock.deliveredInputs.count == 3)

            #expect(framerMock.deliveredInputs[0].message.httpKind == .response)
            #expect(framerMock.deliveredInputs[1].message.httpKind == .body)
            #expect(framerMock.deliveredInputs[1].data == Data("Hello".utf8))
            #expect(framerMock.deliveredInputs[2].message.httpKind == .end)
        }

        @Test
        func withFragmentedBody_DeliversResponseBodyAndEnd() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer()
            framerMock.definition = .http

            framerMock.appendInput(Data("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHel".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 2)

            let response = framerMock.deliveredInputs[0]
            #expect(response.message.httpKind == .response)
            #expect(response.message.httpResponse?.status == 200)

            let firstBody = framerMock.deliveredInputs[1]
            #expect(firstBody.message.httpKind == .body)
            #expect(firstBody.data == Data("Hel".utf8))

            framerMock.appendInput(Data("lo".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 4)

            let secondBody = framerMock.deliveredInputs[2]
            #expect(secondBody.message.httpKind == .body)
            #expect(secondBody.data == Data("lo".utf8))

            let end = framerMock.deliveredInputs[3]
            #expect(end.message.httpKind == .end)

            #expect(framerMock.failures.isEmpty)
        }

        @Test
        func withFragmentedChunkedBody_DeliversResponseBodyAndEnd() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer()
            framerMock.definition = .http

            framerMock.appendInput(Data("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 1)
            #expect(framerMock.deliveredInputs[0].message.httpKind == .response)

            framerMock.appendInput(Data("\nHel".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            framerMock.appendInput(Data("lo\r".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            framerMock.appendInput(Data("\n0\r".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            framerMock.appendInput(Data("\n\r\n".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 3)

            let body = framerMock.deliveredInputs[1]
            #expect(body.message.httpKind == .body)
            #expect(body.data == Data("Hello".utf8))
            #expect(body.isComplete)
            #expect(!body.noCopy)

            let end = framerMock.deliveredInputs[2]
            #expect(end.message.httpKind == .end)
            #expect(end.isComplete)
            #expect(end.noCopy)

            #expect(framerMock.failures.isEmpty)
        }

        @Test
        func withFragmentedStatusLineAndHeadersTerminator_DeliversResponseBodyAndEnd() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer()
            framerMock.definition = .http

            framerMock.appendInput(Data("HTTP/1.1 20".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            #expect(framerMock.deliveredInputs.isEmpty)

            framerMock.appendInput(Data("0 OK\r\nContent-Length: 5\r\n\r".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            #expect(framerMock.deliveredInputs.isEmpty)

            framerMock.appendInput(Data("\nHello".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 3)

            let response = framerMock.deliveredInputs[0]
            #expect(response.message.httpKind == .response)
            #expect(response.message.httpResponse?.status == 200)

            let body = framerMock.deliveredInputs[1]
            #expect(body.message.httpKind == .body)
            #expect(body.data == Data("Hello".utf8))

            let end = framerMock.deliveredInputs[2]
            #expect(end.message.httpKind == .end)

            #expect(framerMock.failures.isEmpty)
        }

        @Test
        func withMultipleAvailableFragments_DeliversResponseBodyAndEndInSingleHandleInput() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n".utf8),
                Data("Hel".utf8),
                Data("lo".utf8)
            ])
            framerMock.definition = .http

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 4)

            let response = framerMock.deliveredInputs[0]
            #expect(response.message.httpKind == .response)
            #expect(response.message.httpResponse?.status == 200)

            let firstBody = framerMock.deliveredInputs[1]
            #expect(firstBody.message.httpKind == .body)
            #expect(firstBody.data == Data("Hel".utf8))

            let secondBody = framerMock.deliveredInputs[2]
            #expect(secondBody.message.httpKind == .body)
            #expect(secondBody.data == Data("lo".utf8))

            let end = framerMock.deliveredInputs[3]
            #expect(end.message.httpKind == .end)

            #expect(framerMock.failures.isEmpty)
        }

        // MARK: BACKPRESSURE

        @Test
        func whenResponseDeliveryIsRejected_RetriesPendingResponse() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello".utf8)
            ])
            framerMock.definition = .http
            framerMock.deliverInputNoCopyResults = [false, true]

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 1)

            let rejectedResponse = framerMock.deliveredInputs[0]
            #expect(rejectedResponse.message.httpKind == .response)
            #expect(rejectedResponse.message.httpResponse?.status == 200)

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 4)

            let retriedResponse = framerMock.deliveredInputs[1]
            #expect(retriedResponse.message.httpKind == .response)
            #expect(retriedResponse.message.httpResponse?.status == 200)

            let body = framerMock.deliveredInputs[2]
            #expect(body.message.httpKind == .body)
            #expect(body.data == Data("Hello".utf8))

            let end = framerMock.deliveredInputs[3]
            #expect(end.message.httpKind == .end)

            #expect(framerMock.failures.isEmpty)
        }

        @Test
        func whenEndDeliveryIsRejected_RetriesOnlyPendingEnd() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n".utf8)
            ])
            framerMock.definition = .http
            framerMock.deliverInputNoCopyResults = [true, false, true]

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 2)

            let response = framerMock.deliveredInputs[0]
            #expect(response.message.httpKind == .response)

            let rejectedEnd = framerMock.deliveredInputs[1]
            #expect(rejectedEnd.message.httpKind == .end)

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 3)

            let retriedEnd = framerMock.deliveredInputs[2]
            #expect(retriedEnd.message.httpKind == .end)

            #expect(framerMock.failures.isEmpty)
        }

        @Test
        func whenPendingResponseIsRejected_DoesNotProcessNewInput() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello".utf8)
            ])
            framerMock.definition = .http
            framerMock.deliverInputNoCopyResults = [false, false, true]

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 1)
            #expect(framerMock.deliveredInputs[0].message.httpKind == .response)

            framerMock.appendInput(Data("garbage".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 2)
            #expect(framerMock.deliveredInputs[1].message.httpKind == .response)
            #expect(framerMock.failures.isEmpty)

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 5)

            #expect(framerMock.deliveredInputs[2].message.httpKind == .response)
            #expect(framerMock.deliveredInputs[3].message.httpKind == .body)
            #expect(framerMock.deliveredInputs[3].data == Data("Hello".utf8))
            #expect(framerMock.deliveredInputs[4].message.httpKind == .end)
        }

        // MARK: ERRORS MAPPING

        @Test(arguments: [
            ("ZZZ\r\n", POSIXErrorCode.EBADMSG),
            ("5\r\nHelloXX", POSIXErrorCode.EPROTO)
        ])
        func withParserError_FailsWithExpectedPOSIXError(input: String, expectedError: POSIXErrorCode) throws {
            let httpProto = ProtocolHTTPFramer()
            let response = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
            let framerMock = MockProtocolFramer(inputChunks: [Data((response + input).utf8)])
            framerMock.definition = .http

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 1)
            #expect(framerMock.deliveredInputs[0].message.httpKind == .response)
            #expect(framerMock.deliveredInputs[0].message.httpResponse?.status == 200)

            try #require(framerMock.failures.count == 1)
            #expect(framerMock.failures[0] == .posix(expectedError))
        }

        @Test
        func afterParsingCompletedWithAdditionalInput_FailsWithEPROTO() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n".utf8)
            ])
            framerMock.definition = .http

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.deliveredInputs.count == 2)
            #expect(framerMock.deliveredInputs[0].message.httpKind == .response)
            #expect(framerMock.deliveredInputs[1].message.httpKind == .end)
            #expect(framerMock.failures.isEmpty)

            framerMock.appendInput(Data("unexpected".utf8))
            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.failures.count == 1)
            #expect(framerMock.failures[0] == .posix(.EPROTO))
        }

        // MARK: OTHERS

        @Test
        func withInput_UsesExpectedParseInputBoundaries() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n".utf8)
            ])
            framerMock.definition = .http

            _ = httpProto.handleInput(framer: framerMock)

            try #require(!framerMock.parseInputCalls.isEmpty)

            for call in framerMock.parseInputCalls {
                #expect(call.minimumIncompleteLength == 1)
                #expect(call.maximumLength == 64 * 1024)
            }
        }

        @Test
        func withParserError_DoesNotProcessFurtherInput() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nZZZ\r\n".utf8),
                Data("unexpected".utf8)
            ])
            framerMock.definition = .http

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.failures.count == 1)
            #expect(framerMock.failures[0] == .posix(.EBADMSG))
            #expect(framerMock.parseInputCalls.count == 1)
        }

        @Test
        func withEmptyInput_DoesNothing() {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer()
            framerMock.definition = .http

            let result = httpProto.handleInput(framer: framerMock)

            #expect(result == 0)
            #expect(framerMock.parseInputCalls.count == 1)
            #expect(framerMock.deliveredInputs.isEmpty)
            #expect(framerMock.outputs.isEmpty)
            #expect(framerMock.failures.isEmpty)
        }

        @Test
        func withInputLargerThanMaximumLength_ProcessesInputInMultiplePasses() throws {
            let httpProto = ProtocolHTTPFramer()

            let body = Data(repeating: 0x41, count: 70 * 1024)
            let headers = Data("HTTP/1.1 200 OK\r\nContent-Length: \(body.count)\r\n\r\n".utf8)

            var input = headers
            input.append(body)

            let framerMock = MockProtocolFramer(inputChunks: [input])
            framerMock.definition = .http

            _ = httpProto.handleInput(framer: framerMock)

            #expect(framerMock.parseInputCalls.count == 2)

            try #require(framerMock.deliveredInputs.count == 4)

            let response = framerMock.deliveredInputs[0]
            #expect(response.message.httpKind == .response)
            #expect(response.message.httpResponse?.status == 200)

            let firstBody = framerMock.deliveredInputs[1]
            #expect(firstBody.message.httpKind == .body)

            let secondBody = framerMock.deliveredInputs[2]
            #expect(secondBody.message.httpKind == .body)

            var deliveredBody = try #require(firstBody.data)
            deliveredBody.append(try #require(secondBody.data))

            #expect(deliveredBody == body)

            let end = framerMock.deliveredInputs[3]
            #expect(end.message.httpKind == .end)

            #expect(framerMock.failures.isEmpty)
        }

        @Test
        func whenInputPartiallyConsumed_PreservesRemainingBytes() {
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("Hello".utf8)
            ])

            var firstInput: Data?
            var secondInput: Data?

            let firstResult = framerMock.parseInput(minimumIncompleteLength: 1, maximumLength: 64) { buffer, _ in
                guard let buffer else { return 0 }
                firstInput = Data(buffer)
                return 2
            }

            let secondResult = framerMock.parseInput(minimumIncompleteLength: 1, maximumLength: 64) { buffer, _ in
                guard let buffer else { return 0 }
                secondInput = Data(buffer)
                return buffer.count
            }

            #expect(firstResult)
            #expect(firstInput == Data("Hello".utf8))

            #expect(secondResult)
            #expect(secondInput == Data("llo".utf8))
        }

        @Test
        func whenInputExceedsMaximumLength_PreservesRemainingBytes() {
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("Hello".utf8)
            ])

            var firstInput: Data?
            var secondInput: Data?

            _ = framerMock.parseInput(minimumIncompleteLength: 1, maximumLength: 3) { buffer, _ in
                guard let buffer else { return 0 }
                firstInput = Data(buffer)
                return buffer.count
            }

            _ = framerMock.parseInput(minimumIncompleteLength: 1, maximumLength: 3) { buffer, _ in
                guard let buffer else { return 0 }
                secondInput = Data(buffer)
                return buffer.count
            }

            #expect(firstInput == Data("Hel".utf8))
            #expect(secondInput == Data("lo".utf8))
        }

        @Test
        func afterEnd_DoesNotProcessFurtherInput() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n".utf8),
                Data("unexpected".utf8)
            ])
            framerMock.definition = .http

            _ = httpProto.handleInput(framer: framerMock)

            #expect(framerMock.parseInputCalls.count == 1)

            try #require(framerMock.deliveredInputs.count == 2)
            #expect(framerMock.deliveredInputs[0].message.httpKind == .response)
            #expect(framerMock.deliveredInputs[1].message.httpKind == .end)

            #expect(framerMock.failures.isEmpty)
        }

        @Test
        func withEventsBeforeParserError_DeliversEventsBeforeFailure() {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nZZZ\r\n".utf8)
            ])
            framerMock.definition = .http

            _ = httpProto.handleInput(framer: framerMock)

            #expect(framerMock.events == [
                .deliver(.response),
                .failure(.posix(.EBADMSG))
            ])
        }

        @Test
        func withParserErrorAndRejectedPendingEvent_DeliversEventBeforeFailure() throws {
            let httpProto = ProtocolHTTPFramer()
            let framerMock = MockProtocolFramer(inputChunks: [
                Data("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nZZZ\r\n".utf8)
            ])
            framerMock.definition = .http
            framerMock.deliverInputNoCopyResults = [false, true]

            _ = httpProto.handleInput(framer: framerMock)

            try #require(framerMock.events.count == 1)
            #expect(framerMock.events[0] == .deliver(.response))
            #expect(framerMock.failures.isEmpty)

            _ = httpProto.handleInput(framer: framerMock)

            #expect(framerMock.events == [
                .deliver(.response),
                .deliver(.response),
                .failure(.posix(.EBADMSG))
            ])

            try #require(framerMock.failures.count == 1)
            #expect(framerMock.failures[0] == .posix(.EBADMSG))
        }
    }
}
