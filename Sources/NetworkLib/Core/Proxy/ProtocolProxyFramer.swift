import Foundation
import Network

@available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
extension ProtocolFramerImplementation where Self == ProtocolProxyFramer {
    static func proxy() -> ProtocolProxyFramer { ProtocolProxyFramer() }
}

@available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
final class ProtocolProxyFramer: ProtocolFramerImplementation, @unchecked Sendable {
    private let parserLock: NSLock
    private var parser: RawHTTPResponseParser
    private var isCompleted: Bool {
        parserLock.withLock { parser.isCompleted }
    }

    init() {
        parserLock = NSLock()
        parser = RawHTTPResponseParser()
    }

    func start(framer: any ProtocolFramer) -> NWProtocolFramer.StartResult {
        framer.async { [weak self, framer] in
            self?.startAsync(with: framer)
        }
        return .willMarkReady
    }

    func handleInput(framer: any ProtocolFramer) -> Int {
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
                        let message = framer.makeMessage()
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

    func handleOutput(framer: any ProtocolFramer, message: NWProtocolFramer.Message,
                      messageLength: Int, isComplete: Bool)
    {
    }
}

@available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
extension ProtocolProxyFramer {
    private func startAsync(with framer: any ProtocolFramer) {
        do {
            if let protocols = framer[ProxyOptions.kOptionsProxyTopProtocols] as? [NWProtocolOptions] {
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

    private func makeConnectRequestData(from framer: any ProtocolFramer) throws(NWError) -> Data {
        let host = framer[ProxyOptions.kOptionsEndpointHost] as? NWEndpoint.Host
        let port = framer[ProxyOptions.kOptionsEndpointPort] as? NWEndpoint.Port
        guard let host, let port else { throw NWError.posix(.EDESTADDRREQ) }
        var headers: [HTTPHeaderKey: String] = [:]
        if let auth = framer[ProxyOptions.kOptionsProxyAuth] as? HTTPAuthorization {
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

    private func createNextTLSIfNeeded(from framer: any ProtocolFramer) -> NWProtocolTLS.Options? {
        guard let isSecure = framer[ProxyOptions.kOptionsIsSecure] as? Bool, isSecure else { return nil }
        let tls = NWProtocolTLS.Options()
        if let sni = framer[ProxyOptions.kOptionsServerName] as? String {
            sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, sni)
        }
        return tls
    }
}
