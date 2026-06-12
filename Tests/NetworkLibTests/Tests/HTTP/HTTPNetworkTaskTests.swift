import Foundation
import Network
import Testing
@testable import NetworkLib

extension Tag {
    @Tag static var httpNetwork: Self
}

struct HTTPNetworkTaskTests {
    @Test(.tags(.httpNetwork),
          arguments: [nil, "localhost"], [Data(), Data("Hello World".utf8), Data(repeating: 0xab, count: 1024 * 1024)])
    func noRedirect_AllValuesCorrect(_ sni: String?, _ body: Data) async throws {
        let lines = [
            "HTTP/1.1 200 OK",
            "Content-Length: \(body.count)",
            "Connection: close",
            "Field: value1",
            "Field: value2",
            "",
            "",
        ]
        let responseData = Data(lines.joined(separator: "\r\n").utf8) + body
        let server = try HTTPServerMock(isSecure: sni != nil, flow: .sendResponse(responseData))
        let port = try await server.start()
        defer { server.stop() }
        let urlString = sni == nil ? "http://localhost:\(port)" : "https://localhost:\(port)"
        let url = try #require(URL(string: urlString))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 2)
        let task = HTTPNetworkTask(request, sni: sni)
        let (response, data) = try await withAsyncTimeout(.seconds(4)) {
            try await task.perform()
        }
        try #require(response.statusCode == 200)
        try #require(response.url == url)
        try #require(response.allHeaderFields["Content-Length"] as? String == "\(body.count)")
        try #require(response.allHeaderFields["Connection"] as? String == "close")
        try #require(response.allHeaderFields["Field"] as? String == "value1, value2")
        try #require(data == body)
    }

    @Test(.tags(.httpNetwork), arguments: [nil, "localhost"])
    func noRedirect_ZeroTimeoutFromRequest_NotFailsWithError(_ sni: String?) async throws {
        let server = try HTTPServerMock(isSecure: sni != nil, flow: .none)
        let port = try await server.start()
        defer { server.stop() }
        let urlString = sni == nil ? "http://localhost:\(port)" : "https://localhost:\(port)"
        let url = try #require(URL(string: urlString))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 0)
        let task = HTTPNetworkTask(request, sni: sni)
        do {
            _ = try await withAsyncTimeout(.seconds(3)) {
                try await task.perform()
            }
            throw TestError.unexpectedEntrance
        } catch is AsyncTimeoutError {
        } catch { throw error }
    }

    @Test(.tags(.httpNetwork), arguments: [nil, "localhost"])
    func noRedirect_NonZeroTimeoutFromRequest_FailsWithError(_ sni: String?) async throws {
        let server = try HTTPServerMock(isSecure: sni != nil, flow: .none)
        let port = try await server.start()
        defer { server.stop() }
        let urlString = sni == nil ? "http://localhost:\(port)" : "https://localhost:\(port)"
        let url = try #require(URL(string: urlString))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 1)
        let task = HTTPNetworkTask(request, sni: sni)
        do {
            _ = try await withAsyncTimeout(.seconds(3)) {
                try await task.perform()
            }
            throw TestError.unexpectedEntrance
        } catch NWError.posix(.ETIMEDOUT) {
        } catch { throw error }
    }

    @Test(.tags(.httpNetwork), arguments: [nil, "localhost"])
    func cancelAfterStart_Callback_FailsWithError(_ sni: String?) async throws {
        let server = try HTTPServerMock(isSecure: sni != nil, flow: .sendResponse(Data(repeating: 0xae, count: 1024 * 1024)))
        let port = try await server.start()
        defer { server.stop() }
        let urlString = sni == nil ? "http://localhost:\(port)" : "https://localhost:\(port)"
        let url = try #require(URL(string: urlString))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 2)
        let task = HTTPNetworkTask(request, sni: sni)
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                task.callback = { result in
                    continuation.resume(with: result)
                }
                task.start()
                task.cancel()
            }
            throw TestError.unexpectedEntrance
        } catch NWError.posix(.ECANCELED) {
        } catch { throw error }
    }

    @Test(.tags(.httpNetwork), arguments: [nil, "localhost"])
    func cancelAfterStart_Async_FailsWithError(_ sni: String?) async throws {
        let server = try HTTPServerMock(isSecure: sni != nil, flow: .sendResponse(Data(repeating: 0xae, count: 1024 * 1024)))
        let port = try await server.start()
        defer { server.stop() }
        let urlString = sni == nil ? "http://localhost:\(port)" : "https://localhost:\(port)"
        let url = try #require(URL(string: urlString))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 2)
        let task = HTTPNetworkTask(request, sni: sni)
        do {
            let request = Task.detached {
                try await withAsyncTimeout(.seconds(3)) {
                    try await task.perform()
                }
            }
            let cancelTask = Task.detached {
                try? await Task.sleep(for: .milliseconds(100))
                task.cancel()
            }
            _ = try await request.value
            _ = await cancelTask.value
            throw TestError.unexpectedEntrance
        } catch NWError.posix(.ECANCELED) {
        } catch { throw error }
    }

    @Test(.tags(.httpNetwork), arguments: [nil, "localhost"])
    func multipleStart_Async_FailsWithError(_ sni: String?) async throws {
        let server = try HTTPServerMock(isSecure: sni != nil, flow: .none)
        let port = try await server.start()
        defer { server.stop() }
        let urlString = sni == nil ? "http://localhost:\(port)" : "https://localhost:\(port)"
        let url = try #require(URL(string: urlString))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 2)
        let task = HTTPNetworkTask(request, sni: sni)
        do {
            try await withThrowingTaskGroup { group in
                group.addTask {
                    _ = try await task.perform()
                }
                group.addTask {
                    _ = try await task.perform()
                }
                defer { group.cancelAll() }
                try await group.next()
            }
            throw TestError.unexpectedEntrance
        } catch NWError.posix(.EALREADY) {
        }
    }

    @Test(.tags(.httpNetwork), arguments: [nil, "localhost"])
    func startAfterTaskFinished_Callback_FailsWithError(_ sni: String?) async throws {
        let body = Data("Hello World".utf8)
        let lines = [
            "HTTP/1.1 200 OK",
            "Content-Length: \(body.count)",
            "Connection: close",
            "Field: value1",
            "Field: value2",
            "",
            "",
        ]
        let responseData = Data(lines.joined(separator: "\r\n").utf8) + body
        let server = try HTTPServerMock(isSecure: sni != nil, flow: .sendResponse(responseData))
        let port = try await server.start()
        defer { server.stop() }
        let urlString = sni == nil ? "http://localhost:\(port)" : "https://localhost:\(port)"
        let url = try #require(URL(string: urlString))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 2)
        let task = HTTPNetworkTask(request, sni: sni)
        do {
           let _: Void = try await withAsyncTimeout(.seconds(4)) {
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        task.start { startResult1 in
                            switch startResult1 {
                            case .success:
                                task.start { startResult2 in
                                    switch startResult2 {
                                    case .success: continuation.resume(returning: ())
                                    case let .failure(error2): continuation.resume(throwing: error2)
                                    }
                                }
                            case let .failure(error1): continuation.resume(throwing: error1)
                            }
                        }
                    }
                } onCancel: {
                    task.cancel()
                }
            }
            throw TestError.unexpectedEntrance
        } catch NWError.posix(.EALREADY) {
        } catch { throw error }
    }

    @Test(.tags(.httpNetwork), arguments: [nil, "localhost"])
    func startAfterTaskFinished_Async_FailsWithError(_ sni: String?) async throws {
        let body = Data("Hello World".utf8)
        let lines = [
            "HTTP/1.1 200 OK",
            "Content-Length: \(body.count)",
            "Connection: close",
            "Field: value1",
            "Field: value2",
            "",
            "",
        ]
        let responseData = Data(lines.joined(separator: "\r\n").utf8) + body
        let server = try HTTPServerMock(isSecure: sni != nil, flow: .sendResponse(responseData))
        let port = try await server.start()
        defer { server.stop() }
        let urlString = sni == nil ? "http://localhost:\(port)" : "https://localhost:\(port)"
        let url = try #require(URL(string: urlString))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 2)
        let task = HTTPNetworkTask(request, sni: sni)
        _ = try await withAsyncTimeout(.seconds(4)) {
            try await task.perform()
        }
        do {
            _ = try await task.perform()
            throw TestError.unexpectedEntrance
        } catch NWError.posix(.ECANCELED) {
        }
    }

    @Test(.tags(.httpNetwork), arguments: [nil, "localhost"])
    func multipleStart_Concurrent_SuccessResponse(_ sni: String?) async throws {
        let body = Data("Hello, world".utf8)
        let lines = [
            "HTTP/1.1 200 OK",
            "Content-Length: \(body.count)",
            "Connection: close",
            "",
            "",
        ]
        let responseData = Data(lines.joined(separator: "\r\n").utf8) + body
        let server = try HTTPServerMock(isSecure: sni != nil, flow: .sendResponse(responseData))
        let port = try await server.start()
        defer { server.stop() }
        let urlString = sni == nil ? "http://localhost:\(port)" : "https://localhost:\(port)"
        let url = try #require(URL(string: urlString))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 1)
        let task = HTTPNetworkTask(request, sni: sni)
        let (_, data) = try await withAsyncTimeout(.seconds(3)) {
            try await withCheckedThrowingContinuation { continuation in
                task.callback = { result in
                    continuation.resume(with: result)
                }
                task.start()
                task.start()
            }
        }
        try #require(data == body)
    }

    @Test(.tags(.httpNetwork))
    func noRequestUrl_ThrowsBadUrlError() async throws {
        let url = try #require(URL(string: "http://example.com"))
        var request = URLRequest(url: url)
        request.url = nil
        do {
            _ = try await HTTPNetworkTask(request).perform()
            throw TestError.unexpectedEntrance
        } catch let error as URLError where error.code == .badURL {
        }
    }

    @Test(.tags(.httpNetwork))
    func unsupportedScheme_ThrowsUnsupportedUrlError() async throws {
        let url = try #require(URL(string: "scheme://example.com"))
        let request = URLRequest(url: url)
        do {
            _ = try await HTTPNetworkTask(request).perform()
            throw TestError.unexpectedEntrance
        } catch let error as URLError where error.code == .unsupportedURL {
        }
    }

    @Test(.tags(.httpNetwork))
    func urlHostIsEmpty_ThrowsBadUrlError() async throws {
        let url = try #require(URL(string: "http://"))
        let request = URLRequest(url: url)
        do {
            _ = try await HTTPNetworkTask(request).perform()
            throw TestError.unexpectedEntrance
        } catch let error as URLError where error.code == .badURL {
        }
    }

    @Test(.tags(.httpNetwork), arguments: [
        ("http", NWEndpoint.Port.http),
        ("https", NWEndpoint.Port.https),
    ])
    func portNotSet_UsesDefaultSchemePort(_ scheme: String, _ expectedPort: NWEndpoint.Port) async throws {
        let url = try #require(URL(string: "\(scheme)://example.com"))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 1)
        let task = HTTPNetworkTask(request)
        defer { task.cancel() }
        let executingRequest = try await withAsyncTimeout(.seconds(3)) {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    task.start { startResult in
                        continuation.resume(with: startResult)
                    }
                }
            } onCancel: {
                task.cancel()
            }
        }
        try #require(executingRequest.url?.port == Int(expectedPort.rawValue))
    }

    @Test(.tags(.httpNetwork), arguments: [
        (8976, 8976),
        (1234567, UInt16(truncatingIfNeeded: 1234567)),
    ])
    func portSet_MakesCorrectPort(_ passedPort: Int, _ expectedPort: UInt16) async throws {
        let url = try #require(URL(string: "https://example.com:\(passedPort)"))
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 1)
        let task = HTTPNetworkTask(request)
        defer { task.cancel() }
        let executingRequest = try await withAsyncTimeout(.seconds(3)) {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    task.start { startResult in
                        continuation.resume(with: startResult)
                    }
                }
            } onCancel: {
                task.cancel()
            }
        }
        try #require(executingRequest.url?.port == Int(expectedPort))
    }

    @Test(.disabled("Not implemented"), .tags(.httpNetwork))
    func noRedirect_SendRequestFailed_Callback_ReturnsError() async throws {
        
    }

    @Test(.disabled("Not implemented"), .tags(.httpNetwork))
    func noRedirect_SendRequestFailed_Async_ReturnsError() async throws {

    }
}
