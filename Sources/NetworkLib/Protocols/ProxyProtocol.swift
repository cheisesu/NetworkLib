import Foundation
import Network

@available(macOS 12.3, iOS 15.4, *)
extension ProxyProtocol {
    /// ``NWEndpoint.Host``
    static let kOptionsEndpointHost = "kOptionsEndpointHost"
    /// ``NWEndpoint.Port``
    static let kOptionsEndpointPort = "kOptionsEndpointPort"
    /// ``Bool``
    static let kOptionsIsSecure = "kOptionsIsSecure"
    /// ``String``
    static let kOptionsServerName = "kOptionsServerName"
    /// ``RawSocketConfiguration.Proxy.Authorization``
    static let kOptionsProxyAuth = "kOptionsProxyAuth"
}

@available(macOS 12.3, iOS 15.4, *)
final class ProxyProtocol: NWProtocolFramerImplementation, @unchecked Sendable {
    static let definition = NWProtocolFramer.Definition(implementation: ProxyProtocol.self)
    static let label: String = "ProxyProtocol"

    private let parserLock: NSLock
    private var parser: RawHTTPResponseParser
    private var isCompleted: Bool {
        parserLock.withLock { parser.isCompleted }
    }

    public init(framer: NWProtocolFramer.Instance) {
        parserLock = NSLock()
        parser = RawHTTPResponseParser()
    }

    public func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        framer.async { [weak self] in
            self?.startAsync(with: framer)
        }
        return .willMarkReady
    }

    public func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        if isCompleted {
            return 0
        }
        while true {
            let hasMoreToParse = framer.parseInput(minimumIncompleteLength: 1, maximumLength: 100) { buffer, isComplete in
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
            if !hasMoreToParse || isCompleted  {
                break
            }
        }
        return 0
    }

    public func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
    }

    public func wakeup(framer: NWProtocolFramer.Instance) {
    }

    public func stop(framer: NWProtocolFramer.Instance) -> Bool {
        true
    }

    public func cleanup(framer: NWProtocolFramer.Instance) {
    }
}

@available(macOS 12.3, iOS 15.4, *)
extension ProxyProtocol {
    private func startAsync(with framer: NWProtocolFramer.Instance) {
        do {
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
        var headers: [String: String] = [:]
        if let auth = framer.options[Self.kOptionsProxyAuth] as? RawSocketConfiguration.Proxy.Authorization {
            headers["Proxy-Authorization"] = auth.httpHeader
        }
        let parser = HTTPRequestParser(connectTo: host, port, headers: headers)
        return parser.parsedData
    }

    private func validateResponseStatus(_ status: Int) throws(NWError) {
        switch status {
        case 200: break
        case 401: throw .posix(.EAUTH)
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
