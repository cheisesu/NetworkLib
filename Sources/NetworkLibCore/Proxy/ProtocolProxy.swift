import Foundation
import Network
import NetworkLibHttpCore

@available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
extension ProtocolProxy {
    static let kOptionsEndpointHost = "kOptionsEndpointHost"
    static let kOptionsEndpointPort = "kOptionsEndpointPort"
    static let kOptionsIsSecure = "kOptionsIsSecure"
    static let kOptionsServerName = "kOptionsServerName"
    static let kOptionsProxyAuth = "kOptionsProxyAuth"
    static let kOptionsProxyTopProtocols = "kOptionsProxyTopProtocols"
}

extension NWProtocolFramer.Options {
    @available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
    static func proxy(
        connectingToRemote host: NWEndpoint.Host,
        _ port: NWEndpoint.Port,
        isSecure: Bool = true,
        sni: String? = nil,
        authorization: HTTPAuthorization? = nil,
        additionalProtocols: [NWProtocolOptions] = []
    ) -> NWProtocolFramer.Options
    {
        let options = NWProtocolFramer.Options(definition: ProtocolProxy.definition)
        options[ProtocolProxy.kOptionsEndpointHost] = host
        options[ProtocolProxy.kOptionsEndpointPort] = port
        options[ProtocolProxy.kOptionsIsSecure] = isSecure
        options[ProtocolProxy.kOptionsServerName] = if isSecure, sni == nil, !host.isIPAddress {
            host.asString
        } else {
            sni
        }
        options[ProtocolProxy.kOptionsProxyAuth] = authorization
        options[ProtocolProxy.kOptionsProxyTopProtocols] = additionalProtocols
        return options
    }
}

@available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
private final class ProtocolProxy: NWProtocolFramerImplementation, @unchecked Sendable {
    static let definition = NWProtocolFramer.Definition(implementation: ProtocolProxy.self)
    static let label: String = "ProtocolProxy"

    private let parserLock: NSLock
    private var parser: RawHTTPResponseParser
    private var isCompleted: Bool {
        parserLock.withLock { parser.isCompleted }
    }

    init(framer: NWProtocolFramer.Instance) {
        parserLock = NSLock()
        parser = RawHTTPResponseParser()
    }

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        framer.async { [weak self] in
            self?.startAsync(with: framer)
        }
        return .willMarkReady
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        if isCompleted {
            return 0
        }
        while true {
            let hasMoreToParse = framer.parseInput(minimumIncompleteLength: 1, maximumLength: 100) { buffer, _ in
                guard let buffer, !buffer.isEmpty else {
                    framer.markFailed(error: .posix(.ENODATA))
                    return 0
                }
                let assumedBuffer = buffer.assumingMemoryBound(to: UInt8.self)
                let data = Data(bytes: assumedBuffer.baseAddress!, count: buffer.count)
                let response = parserLock.withLock {
                    parser.append(data)
                    return parser.tryParse()
                }
                guard let response else { return buffer.count }
                do {
                    try validateResponseStatus(response.status)
                    framer.passThroughInput()
                    framer.markReady()

                    if !response.leftBuffer.isEmpty {
                        let message = NWProtocolFramer.Message(definition: Self.definition)
                        framer.deliverInput(data: response.leftBuffer, message: message, isComplete: false)
                    }
                } catch let error as NWError {
                    framer.markFailed(error: error)
                } catch {
                    framer.markFailed(error: .posix(.EPROTO))
                }

                return buffer.count
            }
            if !hasMoreToParse || isCompleted {
                break
            }
        }
        return 0
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message,
                      messageLength: Int, isComplete: Bool)
    {
    }

    func wakeup(framer: NWProtocolFramer.Instance) {
    }

    func stop(framer: NWProtocolFramer.Instance) -> Bool {
        true
    }

    func cleanup(framer: NWProtocolFramer.Instance) {
    }
}

@available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
extension ProtocolProxy {
    private func startAsync(with framer: NWProtocolFramer.Instance) {
        do {
            if let protocols = framer.options[Self.kOptionsProxyTopProtocols] as? [NWProtocolFramer.Options] {
                for proto in protocols {
                    try framer.prependApplicationProtocol(options: proto)
                }
            }
            if let tls = createNextTLSIfNeeded(from: framer) {
                try framer.prependApplicationProtocol(options: tls)
            }
            let data = try makeConnectRequestData(from: framer)
            framer.writeOutput(data: data)
            framer.passThroughOutput()
        } catch let error as NWError {
            framer.markFailed(error: error)
        } catch {
            preconditionFailure("Cannot prepend protocol - Already marked ready.")
        }
    }

    private func makeConnectRequestData(from framer: NWProtocolFramer.Instance) throws(NWError) -> Data {
        let host = framer.options[Self.kOptionsEndpointHost] as? NWEndpoint.Host
        let port = framer.options[Self.kOptionsEndpointPort] as? NWEndpoint.Port
        guard let host, let port else { throw NWError.posix(.EDESTADDRREQ) }
        var headers: [HTTPHeaderKey: String] = [:]
        if let auth = framer.options[Self.kOptionsProxyAuth] as? HTTPAuthorization {
            headers[.proxyAuthorization] = auth.httpHeader
        }
        let parser = HTTPRequestParser(connectTo: host, port, headerKeys: headers)
        return parser.parsedData
    }

    private func validateResponseStatus(_ status: Int) throws(NWError) {
        switch status {
        case 200: break
        case 401: throw .posix(.EAUTH)
        case 403: throw .posix(.EACCES)
        case 404: throw .posix(.ENOENT)
        case 407: throw .posix(.EAUTH)
        case 502: throw .posix(.ECONNABORTED)
        case 503: throw .posix(.EBUSY)
        case 504: throw .posix(.ETIMEDOUT)
        default: throw .posix(.EPROTO)
        }
    }

    private func createNextTLSIfNeeded(from framer: NWProtocolFramer.Instance) -> NWProtocolTLS.Options? {
        guard let isSecure = framer.options[Self.kOptionsIsSecure] as? Bool, isSecure else { return nil }
        let tls = NWProtocolTLS.Options()
        if let sni = framer.options[Self.kOptionsServerName] as? String {
            sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, sni)
        }
        return tls
    }
}
