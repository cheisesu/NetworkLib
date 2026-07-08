import Foundation
import Network

/// Additional keys used in `URLError` user info dictionaries produced by ``HTTPNetworkTask``.
public enum HTTPTaskErrorInfoKey {
    /// The HTTP task phase where the error occurred.
    public static let phase = "NetworkLib.HTTPTask.phase"

    /// A short string describing the original error.
    public static let error = "NetworkLib.HTTPTask.error"
}

/// A single HTTP request task backed by ``RawSocket``.
///
/// For example, perform a request asynchronously:
///
/// ```swift
/// let request = URLRequest(url: URL(string: "https://example.com")!)
/// let task = HTTPNetworkTask(request)
/// let (response, data) = try await task.perform()
/// print(response.statusCode, data.count)
/// ```
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public final class HTTPNetworkTask: @unchecked Sendable {
    private enum Scheme: String, Sendable {
        case http
        case https

        var isSecure: Bool {
            self == .https
        }

        var defaultNWPort: NWEndpoint.Port {
            switch self {
            case .http: return .http
            case .https: return .https
            }
        }
    }

    /// Callback invoked when an HTTP task finishes with either a response and body data or an error.
    public typealias ResultCallback = @Sendable (_ result: Result<(HTTPURLResponse, Data), Error>) -> Void

    private let proxy: RawSocketConfiguration.Proxy?
    private let originalRequest: URLRequest
    private let sni: String?
    private let callbackLock: NSLock
    private var _callback: ResultCallback?
    private var isFinished: Bool
    private var currentConnection: RawSocket?
    private let accessQueue: DispatchQueue
    private let accessKey: DispatchSpecificKey<ObjectIdentifier>
    private let callbackDelivery: CallbackDelivery

    /// The received HTTP response, if the task has parsed one.
    public private(set) var response: HTTPURLResponse?

    /// The accumulated response body bytes, if any body data has been received.
    public private(set) var data: Data?

    /// The callback invoked when a started task completes.
    public var callback: ResultCallback? {
        get { callbackLock.withLock { _callback } }
        set { callbackLock.withLock { _callback = newValue } }
    }

    /// Creates an HTTP task for a request.
    ///
    /// Callback-based APIs deliver their callbacks on `delegateQueue`, or on the task's default delegate queue when
    /// `delegateQueue` is `nil`.
    ///
    /// - Parameters:
    ///   - urlRequest: The `http` or `https` request to perform.
    ///   - proxy: Optional HTTP CONNECT proxy settings.
    ///   - sni: Optional TLS Server Name Indication value for the remote server.
    ///   - delegateQueue: Optional queue used to deliver ``callback`` and `start(onScheduled:)` callbacks.
    public init(_ urlRequest: URLRequest, through proxy: RawSocketConfiguration.Proxy? = nil,
                sni: String? = nil, delegateQueue: DispatchQueue? = nil) {
        callbackLock = NSLock()
        originalRequest = urlRequest
        self.proxy = proxy
        self.sni = sni
        isFinished = false
        accessQueue = .HTTPTask.access
        accessKey = DispatchSpecificKey()
        accessQueue.setSpecific(key: accessKey, value: ObjectIdentifier(self.accessQueue))
        callbackDelivery = CallbackDelivery(queue: delegateQueue ?? .HTTPTask.delegate)
    }

    /// Starts the task and optionally reports the request scheduled for execution.
    ///
    /// The `onScheduled` callback is not stored. It is invoked once after the original request has been validated, normalized for
    /// execution, and associated with a socket. The request in the success result may differ from the original request, for
    /// example by filling in a default port or normalized host value required by the connection.
    ///
    /// Set ``callback`` separately to receive the final HTTP response or failure. The scheduling callback is delivered on the
    /// task's delegate queue.
    ///
    /// For example, observe the scheduled request and handle the final result:
    ///
    /// ```swift
    /// task.callback = { result in
    ///     if case .success(let (response, data)) = result {
    ///         print(response.statusCode, data.count)
    ///     }
    /// }
    /// task.start { scheduled in
    ///     if case .success(let request) = scheduled {
    ///         print(request.url?.absoluteString ?? "")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter callback: Optional one-shot callback that receives the request actually scheduled for execution
    /// or a scheduling error.
    public func start(onScheduled callback: (@Sendable (_ startResult: Result<URLRequest, Error>) -> Void)? = nil) {
        accessQueue.async { [weak self] in
            printDebug("[http] call start")
            guard let self else { return }
            self.startUnsafe { [weak self] result in
                guard let self, let callback else { return }
                self.deliverStartResult(result, to: callback)
            }
        }
    }

    /// Cancels the current HTTP task if it is running.
    public func cancel() {
        accessQueue.async { [weak self] in
            printDebug("[http] cancel")
            guard let self else { return }
            self.currentConnection?.cancel(nil)
        }
    }

    /// Performs the request asynchronously and returns the complete response and body data.
    ///
    /// Cancelling the surrounding task cancels the underlying socket. The method throws validation, socket, parser, and URL
    /// errors produced while executing the request.
    ///
    /// - Returns: The final HTTP response and accumulated body bytes.
    public func perform() async throws -> (HTTPURLResponse, Data) {
        printDebug("[http] call perform")
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                printDebug("[http] perform continuation enter")
                self.accessQueue.async { [weak self] in
                    guard let self else { return continuation.resume(throwing: URLError(.cancelled)) }
                    self.startUnsafe { startResult in
                        switch startResult {
                        case .success:
                            precondition(self.callback == nil)
                            self.callback = { result in
                                continuation.resume(with: result)
                            }
                        case let .failure(error): continuation.resume(throwing: error)
                        }
                    }
                }
            }
        } onCancel: { [weak self] in
            self?.cancel()
        }
    }
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
private extension HTTPNetworkTask {
    func deliverStartResult(
        _ result: Result<URLRequest, Error>,
        to callback: @escaping @Sendable (_ startResult: Result<URLRequest, Error>) -> Void
    ) {
        callbackDelivery.call {
            callback(result)
        }
    }

    func deliverTaskResult(_ result: Result<(HTTPURLResponse, Data), Error>, to callback: @escaping ResultCallback) {
        callbackDelivery.call {
            callback(result)
        }
    }
}

extension HTTPNetworkTask {
    private func startUnsafe(_ onScheduleComplete: @Sendable(_ startResult: Result<URLRequest, Error>) -> Void) {
        guard currentConnection == nil else {
            let error = urlError(from: NWError.posix(.EALREADY), request: originalRequest, phase: .scheduling)
            return onScheduleComplete(.failure(error))
        }
        do {
            guard !isFinished else {
                let error = urlError(from: NWError.posix(.ECANCELED), request: originalRequest, phase: .scheduling)
                return onScheduleComplete(.failure(error))
            }
            let executingRequest = try startWithRequestUnsafe(originalRequest)
            onScheduleComplete(.success(executingRequest))
        } catch {
            let urlError = urlError(from: error, request: originalRequest, phase: .scheduling)
            onScheduleComplete(.failure(urlError))
            finishAndNotifyUnsafe(nil, originalRequest, with: error, phase: .scheduling)
        }
    }

    private func startWithRequestUnsafe(_ urlRequest: URLRequest) throws -> URLRequest {
        let (configuration, executingRequest) = try makeConfiguration(from: urlRequest)
        let rawSocket = try RawSocket(configuration, delegateQueue: accessQueue)
        currentConnection = rawSocket
        rawSocket.connect { [weak self] result in
            printDebug("[http] connected", result)
            switch result {
            case .success: self?.successConnectUnsafe(rawSocket, urlRequest)
            case let .failure(error): self?.finishAndNotifyUnsafe(rawSocket, urlRequest, with: error, phase: .connecting)
            }
        }
        return executingRequest
    }

    private func makeConfiguration(from request: URLRequest) throws(URLError) -> (RawSocketConfiguration, URLRequest) { // done
        guard let url = request.url else { throw URLError(.badURL) }
        guard let schemeRaw = url.scheme, let scheme = Scheme(rawValue: schemeRaw) else { throw URLError(.unsupportedURL) }
        guard let hostRaw = url.wrappedHost, !hostRaw.isEmpty else { throw URLError(.badURL) }
        let urlPort: NWEndpoint.Port? = if let portInt = url.port {
            .init(rawValue: UInt16(truncatingIfNeeded: portInt))
        } else {
            nil
        }
        let port = urlPort ?? scheme.defaultNWPort
        var configuration = RawSocketConfiguration(.init(hostRaw),
                                                   port, isSecure: scheme.isSecure, sni: sni,
                                                   transport: .tcp, maxDataBlock: .max, timeout: request.timeoutInterval,
                                                   additionalProtocols: [.http()])
        if let proxy, #available(iOS 15.4, tvOS 15.4, macOS 12.3, *) {
            configuration = configuration.using(proxy: proxy)
        }
        var executingRequest = request
        var executingComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        executingComponents?.scheme = schemeRaw
        executingComponents?.host = hostRaw
        executingComponents?.port = Int(port.rawValue)
        guard let executingUrl = executingComponents?.url else { throw URLError(.badURL) }
        executingRequest.url = executingUrl
        return (configuration, executingRequest)
    }

    private func successConnectUnsafe(_ rawSocket: RawSocket, _ urlRequest: URLRequest) {
        var urlRequest = urlRequest
        if urlRequest.value(forHTTPHeaderField: .host) == nil {
            urlRequest.setValue(urlRequest.url?.wrappedHost, forHTTPHeaderField: .host)
        }
        rawSocket.sendMessage(HTTPSendMessage(urlRequest)) { [weak self, urlRequest] error in
            printDebug("[http] sent", error, "request", urlRequest)
            if let error {
                self?.finishAndNotifyUnsafe(rawSocket, urlRequest, with: error, phase: .sending)
            } else {
                self?.successSendHTTPUnsafe(rawSocket, urlRequest)
            }
        }
    }

    private func successSendHTTPUnsafe(_ rawSocket: RawSocket, _ urlRequest: URLRequest) {
        receiveNextDataUnsafe(rawSocket, urlRequest)
    }

    private func receiveNextDataUnsafe(_ rawSocket: RawSocket, _ urlRequest: URLRequest) {
        printDebug("[http] call receive next")
        rawSocket.receiveNextMessage(of: HTTPReceiveMessage.self) { [weak self] result in
            printDebug("[http] receive message", result)
            switch result {
            case let .success(message): self?.successReceiveNextUnsafe(rawSocket, urlRequest, with: message)
            case let .failure(error): self?.finishAndNotifyUnsafe(rawSocket, urlRequest, with: error, phase: .receiving)
            }
        }
    }

    private func successReceiveNextUnsafe(_ rawSocket: RawSocket, _ urlRequest: URLRequest, with message: HTTPReceiveMessage) {
        do throws(URLError) {
            switch message {
            case let .response(response):
                guard let url = urlRequest.url else { throw URLError(.badURL) }
                self.response = response.urlResponse(with: url)
                receiveNextDataUnsafe(rawSocket, urlRequest)
            case let .data(data):
                guard response != nil else { throw URLError(.badServerResponse) }
                handleResponseDataUnsafe(rawSocket, urlRequest, with: data)
                receiveNextDataUnsafe(rawSocket, urlRequest)
            case .end: finishAndNotifyUnsafe(rawSocket, urlRequest, with: nil)
            }
        } catch {
            finishAndNotifyUnsafe(rawSocket, urlRequest, with: error, phase: .parsing)
        }
    }

    private func handleResponseDataUnsafe(_ rawSocket: RawSocket, _ urlRequest: URLRequest, with data: Data) {
        if self.data == nil {
            self.data = Data()
        }
        self.data?.append(contentsOf: data)
    }

    private func finishAndNotifyUnsafe(
        _ rawSocket: RawSocket?,
        _ urlRequest: URLRequest,
        with error: Error?,
        phase: FailurePhase? = nil
    ) {
        guard !isFinished else { return }
        isFinished = true
        rawSocket?.cancel(nil)
        currentConnection = nil
        let callback = self.callback
        self.callback = nil
        guard let callback else { return }
        if let error {
            deliverTaskResult(.failure(urlError(from: error, request: urlRequest, phase: phase)), to: callback)
        } else {
            guard let response else {
                let error = urlError(from: URLError(.cannotParseResponse), request: urlRequest, phase: .parsing)
                deliverTaskResult(.failure(error), to: callback)
                return
            }
            let result = (response, data ?? Data())
            deliverTaskResult(.success(result), to: callback)
        }
    }

    private func urlError(from error: Error, request: URLRequest, phase: FailurePhase?) -> URLError {
        var userInfo = (error as? URLError)?.errorUserInfo ?? [:]
        if !(error is URLError) {
            userInfo[NSUnderlyingErrorKey] = error
        }
        if let url = request.url {
            userInfo[NSURLErrorFailingURLErrorKey] = url as NSURL
            userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString
            userInfo[NSURLErrorKey] = url as NSURL
        }
        if let phase {
            userInfo[HTTPTaskErrorInfoKey.phase] = phase.rawValue
        }
        userInfo[HTTPTaskErrorInfoKey.error] = String(describing: error)
        return URLError(urlErrorCode(from: error), userInfo: userInfo)
    }

    private func urlErrorCode(from error: Error) -> URLError.Code {
        if let error = error as? URLError {
            return error.code
        }
        guard let error = error as? NWError else {
            return .unknown
        }
        switch error {
        case let .posix(code):
            return urlErrorCode(from: code)
        case .dns:
            return .cannotFindHost
        case .tls:
            return .secureConnectionFailed
        default:
            return .unknown
        }
    }

    private func urlErrorCode(from code: POSIXErrorCode) -> URLError.Code {
        switch code {
        case .ECANCELED:
            return .cancelled
        case .ETIMEDOUT:
            return .timedOut
        case .ECONNREFUSED, .EHOSTUNREACH, .ENETUNREACH:
            return .cannotConnectToHost
        case .ECONNRESET, .ECONNABORTED, .EPIPE:
            return .networkConnectionLost
        case .ENOTCONN:
            return .notConnectedToInternet
        case .EAUTH, .EACCES:
            return .userAuthenticationRequired
        case .EBADMSG, .EPROTO, .EIO, .EINVAL:
            return .cannotParseResponse
        case .ENOTSUP:
            return .unsupportedURL
        default:
            return .unknown
        }
    }
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
private extension HTTPNetworkTask {
    enum FailurePhase: String, Sendable {
        case scheduling
        case connecting
        case sending
        case receiving
        case parsing
    }
}
