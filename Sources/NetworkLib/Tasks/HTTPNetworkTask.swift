import Foundation
import Network

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

    public typealias ResultCallback = @Sendable (_ response: HTTPURLResponse?, _ result: Result<Data, Error>) -> Void

    private let proxy: RawSocketConfiguration.Proxy?
    private let originalRequest: URLRequest
    private let sni: String?
    private let callbackLock: NSLock
    private var _callback: ResultCallback?
    private var isFinished: Bool
    private var currentConnection: RawSocket?
    private let accessQueue: DispatchQueue
    private let accessKey: DispatchSpecificKey<ObjectIdentifier>

    public private(set) var response: HTTPURLResponse?
    public private(set) var data: Data?
    public var callback: ResultCallback? {
        get { callbackLock.withLock { _callback } }
        set { callbackLock.withLock { _callback = newValue } }
    }

    public init(_ urlRequest: URLRequest, through proxy: RawSocketConfiguration.Proxy? = nil, sni: String? = nil) {
        callbackLock = NSLock()
        originalRequest = urlRequest
        self.proxy = proxy
        self.sni = sni
        isFinished = false
        accessQueue = DispatchQueue(label: "com.network.lib.http_network_task", target: .global())
        accessKey = DispatchSpecificKey()
        accessQueue.setSpecific(key: accessKey, value: ObjectIdentifier(self.accessQueue))
    }

    public func start() {
        accessQueue.async { [weak self] in
            guard let self else { return }
            self.startUnsafe()
        }
    }

    public func cancel() {
        accessQueue.async { [weak self] in
            guard let self else { return }
            self.currentConnection?.cancel(nil)
        }
    }
}

extension HTTPNetworkTask {
    private func startUnsafe() {
        guard currentConnection == nil else { return }
        do {
            guard !isFinished else { return }
            try startWithRequestUnsafe(originalRequest)
        } catch {
            finishAndNotifyUnsafe(nil, originalRequest, with: error)
        }
    }

    private func startWithRequestUnsafe(_ urlRequest: URLRequest) throws {
        let configuration = try makeConfiguration(from: urlRequest)
        let rawSocket = try RawSocket(configuration, accessQueue: accessQueue)
        currentConnection = rawSocket
        rawSocket.connect { [weak self] result in
            printDebug("[http] connected", result)
            switch result {
            case .success: self?.successConnectUnsafe(rawSocket, urlRequest)
            case let .failure(error): self?.finishAndNotifyUnsafe(rawSocket, urlRequest, with: error)
            }
        }
    }

    private func makeConfiguration(from request: URLRequest) throws(URLError) -> RawSocketConfiguration { // done
        guard let url = request.url else { throw URLError(.badURL) }
        guard let schemeRaw = url.scheme, let scheme = Scheme(rawValue: schemeRaw) else { throw URLError(.unsupportedURL) }
        guard let hostRaw = url.wrappedHost, !hostRaw.isEmpty else { throw URLError(.badURL) }
        let urlPort = if let portInt = url.port {
            NWEndpoint.Port(rawValue: UInt16(truncatingIfNeeded: portInt))
        } else {
            scheme.defaultNWPort
        }
        let port = urlPort ?? scheme.defaultNWPort
        var configuration = RawSocketConfiguration(.init(hostRaw),
                                                   port, isSecure: scheme.isSecure, sni: sni,
                                                   transport: .tcp, maxDataBlock: .max, timeout: request.timeoutInterval,
                                                   additionalProtocols: [.http()])
        if let proxy, #available(macOS 12.3, iOS 15.4, *) {
            configuration = configuration.using(proxy: proxy)
        }
        return configuration
    }

    private func successConnectUnsafe(_ rawSocket: RawSocket, _ urlRequest: URLRequest) {
        var urlRequest = urlRequest
        if urlRequest.value(forHTTPHeaderField: "Host") == nil {
            urlRequest.setValue(urlRequest.url?.wrappedHost, forHTTPHeaderField: "Host")
        }
        rawSocket.sendMessage(HTTPSendMessage(urlRequest)) { [weak self, urlRequest] error in
            printDebug("[http] sent", error, "request", urlRequest)
            if let error {
                self?.finishAndNotifyUnsafe(rawSocket, urlRequest, with: error)
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
            case let .failure(error): self?.finishAndNotifyUnsafe(rawSocket, urlRequest, with: error)
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
            finishAndNotifyUnsafe(rawSocket, urlRequest, with: error)
        }
    }

    private func handleResponseDataUnsafe(_ rawSocket: RawSocket, _ urlRequest: URLRequest, with data: Data) {
        if self.data == nil {
            self.data = Data()
        }
        self.data?.append(contentsOf: data)
    }

    private func finishAndNotifyUnsafe(_ rawSocket: RawSocket?, _ urlRequest: URLRequest, with error: Error?) {
        guard !isFinished else { return }
        isFinished = true
        rawSocket?.cancel(nil)
        let callback = self.callback
        self.callback = nil
        if let error {
            callback?(response, .failure(error))
        } else {
            guard let response else {
                callback?(nil, .failure(URLError(.cannotParseResponse)))
                return
            }
            callback?(response, .success(data ?? Data()))
        }
    }
}
