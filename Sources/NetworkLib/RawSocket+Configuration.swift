import Foundation
import Network

extension RawSocketConfiguration.Proxy {
    public enum Authorization: Sendable {
        case basic(userName: String, password: String)

        var httpHeader: String {
            switch self {
            case let .basic(username, password):
                let encoded = Data("\(username):\(password)".utf8).base64EncodedString()
                return ["Basic", encoded].joined(separator: " ")
            }
        }
    }
}

extension RawSocketConfiguration {
    public struct Proxy: Sendable {
        public let host: NWEndpoint.Host
        public let port: NWEndpoint.Port
        public let isSecure: Bool
        public let sni: String?
        public let authorization: Authorization?
        
        var endpoint: NWEndpoint {
            .hostPort(host: host, port: port)
        }
        
        public init(host: NWEndpoint.Host, port: NWEndpoint.Port, isSecure: Bool = true, sni: String? = nil,
                    authorization: Authorization? = nil)
        {
            self.host = host
            self.port = port
            self.isSecure = isSecure
            self.sni = sni
            self.authorization = authorization
        }
    }
}

public struct RawSocketConfiguration: Sendable {
    public let host: NWEndpoint.Host
    public let port: NWEndpoint.Port
    public let isSecure: Bool
    public let sni: String?
    public let transport: RawSocketTransport
    public let maxDataBlock: Int
    public let timeout: TimeInterval
    public let proxy: Proxy?
    
    var endpoint: NWEndpoint {
        return .hostPort(host: host, port: port)
    }
    
    public init(_ host: NWEndpoint.Host, _ port: NWEndpoint.Port, isSecure: Bool = true, sni: String? = nil,
                transport: RawSocketTransport = .tcp, maxDataBlock: Int = .max, timeout: TimeInterval = 10) throws
    {
        self.host = host
        self.port = port
        self.isSecure = isSecure
        self.sni = sni
        self.transport = transport
        self.maxDataBlock = maxDataBlock
        self.timeout = timeout
        proxy = nil
    }
    
    @available(macOS 12.3, iOS 15.4, *)
    public init(_ host: NWEndpoint.Host, _ port: NWEndpoint.Port, isSecure: Bool = true, sni: String? = nil,
                proxy: Proxy, transport: RawSocketTransport = .tcp, maxDataBlock: Int = .max,
                timeout: TimeInterval = 10) throws
    {
        self.host = host
        self.port = port
        self.isSecure = isSecure
        self.sni = sni
        self.transport = transport
        self.maxDataBlock = maxDataBlock
        self.timeout = timeout
        self.proxy = proxy
    }
    
    // TODO: move to a separate entity
    func makeNWConnection() throws -> NWConnection {
        if let proxy {
            return try makeProxyNWConnection(proxy)
        }
        return makeDirectNWConnection()
    }
    
    private func makeProxyNWConnection(_ proxy: Proxy) throws -> NWConnection {
        let parameters = try makeProxyParameters(proxy)
        let endpoint = makeProxyMainEndpoint(proxy)
        return NWConnection(to: endpoint, using: parameters)
    }
    
    private func makeDirectNWConnection() -> NWConnection {
        let parameters = makeDirectNWParameters(transport, isSecure: isSecure, sni: sni)
        return NWConnection(to: endpoint, using: parameters)
    }
    
    private func makeDirectNWParameters(_ transport: RawSocketTransport, isSecure: Bool, sni: String?) -> NWParameters {
        let tls: NWProtocolTLS.Options? = {
            guard isSecure else { return nil }
            let tls = NWProtocolTLS.Options()
            if let sni = sni {
                sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, sni)
            }
            return tls
        }()
        let parameters = {
            switch transport {
            case .tcp:
                let tcp = NWProtocolTCP.Options()
                return NWParameters(tls: tls, tcp: tcp)
            case .udp:
                let udp = NWProtocolUDP.Options()
                return NWParameters(dtls: tls, udp: udp)
            }
        }()
        return parameters
    }
    
    private func makeProxyParameters(_ proxy: Proxy) throws -> NWParameters {
        if #available(macOS 12.3, iOS 15.4, *) {
            let options = NWProtocolFramer.Options(definition: ProxyProtocol.definition)
            options[ProxyProtocol.kOptionsEndpointHost] = host
            options[ProxyProtocol.kOptionsEndpointPort] = port
            options[ProxyProtocol.kOptionsIsSecure] = isSecure
            options[ProxyProtocol.kOptionsServerName] = sni
            options[ProxyProtocol.kOptionsProxyAuth] = proxy.authorization
            let parameters = makeDirectNWParameters(transport, isSecure: proxy.isSecure, sni: proxy.sni)
            parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
            return parameters
        }
        if #available(macOS 14.0, iOS 17.0, *) {
            return makeInBoxSocketParameters(proxy)
        }
        throw NWError.posix(.ENOTSUP)
    }
    
    private func makeProxyMainEndpoint(_ proxy: Proxy) -> NWEndpoint {
        if #available(macOS 12.3, iOS 15.4, *) {
            return proxy.endpoint
        }
        if #available(macOS 14.0, iOS 17.0, *) {
            return endpoint
        }
        return proxy.endpoint
    }
    
    @available(macOS 14.0, iOS 17.0, *)
    private func makeInBoxSocketParameters(_ proxy: Proxy) -> NWParameters {
        let parameters = makeDirectNWParameters(transport, isSecure: isSecure, sni: sni)
        let tls: NWProtocolTLS.Options? = {
            guard proxy.isSecure else { return nil }
            let tls = NWProtocolTLS.Options()
            if let sni = proxy.sni {
                sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, sni)
            }
            return tls
        }()
        let _proxy = ProxyConfiguration(httpCONNECTProxy: proxy.endpoint, tlsOptions: tls)
        if let auth = proxy.authorization {
            switch auth {
            case let .basic(username, password): _proxy.applyCredential(username: username, password: password)
            }
        }
        let context = NWParameters.PrivacyContext(description: "Proxy")
        context.proxyConfigurations = [_proxy]
        parameters.setPrivacyContext(context)
        return parameters
    }
}
