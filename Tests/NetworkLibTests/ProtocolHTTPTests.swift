import Foundation
import Network
import Testing
@testable import NetworkLibCore

struct ProtocolHTTPTests {

    // MARK: - TESTS FOR SENDING

    struct Send {
        @Test(.tags(.httpProtocol))
        func messageWithCorrectUrlRequest_CorrectDataSent() async throws {
            let timeout: TimeInterval = 3
            let url = try #require(URL(string: "/some_path?with=query"))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "some data".data(using: .utf8)
            let requestData = HTTPRequestParser(request, version: .v1_1).parsedData
            let server = try HTTPServerMock(isSecure: true, flow: .none)
            let port = try await server.start()
            defer { server.stop() }
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                                maxDataBlock: 256, timeout: timeout, additionalProtocols: [.http()])
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await socket.connect()
            try await socket.sendMessage(HTTPSendMessage(request))
            let receivedData = try await #require(server.manualEcho())
            try #require(receivedData == requestData)
        }

        @Test(.tags(.httpProtocol), arguments: [
            (Data(), NWError.posix(.EBADMSG)),
            (Data("some data".utf8), NWError.posix(.EMSGSIZE)),
        ])
        func rawDataInsteadOfHTTPMessage_ThrowsError(_ data: Data, _ expectedError: NWError) async throws {
            let timeout: TimeInterval = 3
            let server = try HTTPServerMock(isSecure: true, flow: .none)
            let port = try await server.start()
            defer { server.stop() }
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                                maxDataBlock: 256, timeout: timeout, additionalProtocols: [.http()])
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await socket.connect()
            do {
                try await socket.send(data)
                throw TestError.unexpectedEntrance
            } catch let error as NWError {
                guard error == expectedError else { throw error }
            } catch { throw error }
        }

        @Test(.tags(.httpProtocol), arguments: [
            (nil as Data?, NWError.posix(.EBADMSG)),
            (Data(), NWError.posix(.EBADMSG)),
            (Data("some data".utf8), NWError.posix(.EMSGSIZE)),
        ])
        func notHTTPMessage_ThrowsBadMessageError(_ data: Data?, _ expectedError: NWError) async throws {
            struct _SomeSendMessage: RawSocketSendMessage {
                let context: NWConnection.ContentContext = .defaultMessage
                let content: Data?
            }
            let timeout: TimeInterval = 3
            let message = _SomeSendMessage(content: data)
            let server = try HTTPServerMock(isSecure: true, flow: .none)
            let port = try await server.start()
            defer { server.stop() }
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                                maxDataBlock: 256, timeout: timeout, additionalProtocols: [.http()])
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await socket.connect()
            do {
                try await socket.sendMessage(message)
                throw TestError.unexpectedEntrance
            } catch let error as NWError {
                guard error == expectedError else { throw error }
            } catch { throw error }
        }
    }

    // MARK: - TESTS FOR RECEIVEING

    struct Receive {
        @Test(.tags(.httpProtocol))
        func correctResponseData_ReturnsCorrectMessages() async throws {
            let body = Data("Hello World".utf8)
            let expectedResponse = HTTPParserResponseResult(versionRaw: "HTTP/1.1", status: 200, headers: [
                "Content-Length": "\(body.count)",
                "Connection": "close",
            ], rawSize: 58, leftBuffer: Data())
            let expectedMessages = [HTTPReceiveMessage.response(expectedResponse), .data(body), .end]
            let lines = [
                "HTTP/1.1 200 OK",
                "Content-Length: \(body.count)",
                "Connection: close",
                "",
                "",
            ]
            let expectedData = Data(lines.joined(separator: "\r\n").utf8) + body
            let timeout: TimeInterval = 3
            let url = try #require(URL(string: "/some_path?with=query"))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "some data".data(using: .utf8)
            let server = try HTTPServerMock(isSecure: true, flow: .manualEcho(expectedData))
            let port = try await server.start()
            defer { server.stop() }
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                                maxDataBlock: 256, timeout: timeout, additionalProtocols: [.http()])
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await socket.connect()
            try await socket.sendMessage(HTTPSendMessage(request))
            _ = try await server.manualEcho()
            let receivedMessages: [HTTPReceiveMessage] = try [
                await socket.receiveNextMessage(),
                await socket.receiveNextMessage(),
                await socket.receiveNextMessage(),
            ]
            try #require(receivedMessages == expectedMessages)
        }

        @Test(.tags(.httpProtocol))
        func invalidChunkSize_ThrowsIOError() async throws {
            let lines = [
                "HTTP/1.1 200 OK",
                "Transfer-Encoding: chunked",
                "Connection: close",
                "",
                "G",
                "Hello",
                "5",
                "World",
                "0",
                "",
            ]
            let expectedData = Data(lines.joined(separator: "\r\n").utf8)
            let timeout: TimeInterval = 3
            let url = try #require(URL(string: "/some_path?with=query"))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "some data".data(using: .utf8)
            let server = try HTTPServerMock(isSecure: true, flow: .manualEcho(expectedData))
            let port = try await server.start()
            defer { server.stop() }
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                                timeout: timeout, additionalProtocols: [.http()])
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await socket.connect()
            try await socket.sendMessage(HTTPSendMessage(request))
            _ = try await server.manualEcho()
            do {
                _ = try await socket.receiveNextMessage() as HTTPReceiveMessage
                throw TestError.unexpectedEntrance
            } catch NWError.posix(.EIO) {
            } catch { throw error }
        }

        @Test(.tags(.httpProtocol))
        func invalidChunkTerminator_ThrowsProtocolError() async throws {
            let lines = [
                "HTTP/1.1 200 OK",
                "Transfer-Encoding: chunked",
                "Connection: close",
                "",
                "5",
                "Hello",
                "6",
                "World",
                "0",
                "",
            ]
            let expectedData = Data(lines.joined(separator: "\r\n").utf8)
            let timeout: TimeInterval = 3
            let url = try #require(URL(string: "/some_path?with=query"))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "some data".data(using: .utf8)
            let server = try HTTPServerMock(isSecure: true, flow: .manualEcho(expectedData))
            let port = try await server.start()
            defer { server.stop() }
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                                timeout: timeout, additionalProtocols: [.http()])
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await socket.connect()
            try await socket.sendMessage(HTTPSendMessage(request))
            _ = try await server.manualEcho()
            do {
                _ = try await socket.receiveNextMessage() as HTTPReceiveMessage
                throw TestError.unexpectedEntrance
            } catch NWError.posix(.EPROTO) {
            } catch { throw error }
        }

        @Test(.tags(.httpProtocol))
        func moreDataReceived_ThrowsInvalidArgumentError() async throws {
            let lines = [
                "HTTP/1.1 200 OK",
                "Connection: close",
                "",
                "",
            ]
            let expectedData = Data(lines.joined(separator: "\r\n").utf8)
            let timeout: TimeInterval = 3
            let url = try #require(URL(string: "/some_path?with=query"))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "some data".data(using: .utf8)
            let server = try HTTPServerMock(isSecure: true, flow: .manualEcho(expectedData))
            let port = try await server.start()
            defer { server.stop() }
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                                timeout: timeout, additionalProtocols: [.http()])
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await socket.connect()
            try await socket.sendMessage(HTTPSendMessage(request))
            _ = try await server.manualEcho()
            do {
                var msg = try await socket.receiveNextMessage() as HTTPReceiveMessage
                msg = try await socket.receiveNextMessage() as HTTPReceiveMessage
                try #require(msg == .end)
                try await socket.sendMessage(HTTPSendMessage(request))
                _ = try await server.manualEcho()
                _ = try await socket.receiveNextMessage() as HTTPReceiveMessage
                throw TestError.unexpectedEntrance
            } catch NWError.posix(.EINVAL) {
            } catch { throw error }
        }

        @Test(.tags(.httpProtocol))
        func receiveNonHTTPMessage_ThrowsBadMessageError() async throws {
            struct _SomeReceiveMessage: RawSocketReceiveMessage {
                init?(from context: NWConnection.ContentContext, with content: Data?) {
                    return nil
                }
            }
            let lines = [
                "HTTP/1.1 200 OK",
                "Connection: close",
                "",
                "",
            ]
            let expectedData = Data(lines.joined(separator: "\r\n").utf8)
            let timeout: TimeInterval = 3
            let url = try #require(URL(string: "/some_path?with=query"))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "some data".data(using: .utf8)
            let server = try HTTPServerMock(isSecure: true, flow: .manualEcho(expectedData))
            let port = try await server.start()
            defer { server.stop() }
            let config = RawSocketConfiguration("127.0.0.1", port, isSecure: true, sni: "localhost", transport: .tcp,
                                                timeout: timeout, additionalProtocols: [.http()])
            let socket = try RawSocket(config)
            defer { socket.cancel(nil) }
            try await socket.connect()
            try await socket.sendMessage(HTTPSendMessage(request))
            _ = try await server.manualEcho()
            do {
                _ = try await socket.receiveNextMessage() as _SomeReceiveMessage
                throw TestError.unexpectedEntrance
            } catch NWError.posix(.EBADMSG) {
            } catch { throw error }
        }
    }
}

