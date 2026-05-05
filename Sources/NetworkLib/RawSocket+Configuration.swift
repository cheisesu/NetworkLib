import Foundation
import Network

extension RawSocketConfiguration {
    public struct Proxy: Sendable, Equatable {
        public let host: NWEndpoint.Host
        public let port: NWEndpoint.Port
        public let isSecure: Bool
        public let sni: String?
        public let authorization: HTTPAuthorization?

        var endpoint: NWEndpoint {
            .hostPort(host: host, port: port)
        }
        
        public init(host: NWEndpoint.Host, port: NWEndpoint.Port, isSecure: Bool = true, sni: String? = nil,
                    authorization: HTTPAuthorization? = nil)
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
    public let additionalProtocols: [NWProtocolOptions]
#if DEBUG
    var disableInBoxProxy: Bool = false
#endif

    var endpoint: NWEndpoint {
        return .hostPort(host: host, port: port)
    }
    
    public init(_ host: NWEndpoint.Host, _ port: NWEndpoint.Port, isSecure: Bool = true, sni: String? = nil,
                transport: RawSocketTransport = .tcp, maxDataBlock: Int = .max, timeout: TimeInterval = 10,
                additionalProtocols: [NWProtocolOptions] = [])
    {
        self.host = host
        self.port = port
        self.isSecure = isSecure
        self.sni = sni
        self.transport = transport
        self.maxDataBlock = maxDataBlock
        self.timeout = timeout
        proxy = nil
        self.additionalProtocols = additionalProtocols
    }
    
    @available(macOS 12.3, iOS 15.4, *)
    public init(_ host: NWEndpoint.Host, _ port: NWEndpoint.Port, isSecure: Bool = true, sni: String? = nil,
                proxy: Proxy, transport: RawSocketTransport = .tcp, maxDataBlock: Int = .max,
                timeout: TimeInterval = 10, additionalProtocols: [NWProtocolOptions] = [])
    {
        self.host = host
        self.port = port
        self.isSecure = isSecure
        self.sni = sni
        self.transport = transport
        self.maxDataBlock = maxDataBlock
        self.timeout = timeout
        self.proxy = proxy
        self.additionalProtocols = additionalProtocols
    }

    @available(macOS 12.3, iOS 15.4, *)
    public func using(proxy: Proxy) -> RawSocketConfiguration {
        RawSocketConfiguration(
            host,
            port,
            isSecure: isSecure,
            sni: sni,
            proxy: proxy,
            transport: transport,
            maxDataBlock: maxDataBlock,
            timeout: timeout,
            additionalProtocols: additionalProtocols
        )
    }

    func makeNWConnection() throws(NWError) -> NWConnection {
        if let proxy {
            return try makeProxyNWConnection(proxy)
        }
        return makeDirectNWConnection()
    }
    
    private func makeProxyNWConnection(_ proxy: Proxy) throws(NWError) -> NWConnection {
        let parameters = try makeProxyParameters(proxy)
        let endpoint = try makeProxyMainEndpoint(proxy)
        return NWConnection(to: endpoint, using: parameters)
    }
    
    private func makeDirectNWConnection() -> NWConnection {
        let parameters = makeDirectNWParameters(transport, isSecure: isSecure, sni: sni)
        parameters.defaultProtocolStack.applicationProtocols.insert(contentsOf: additionalProtocols, at: 0)
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
    
    private func makeProxyParameters(_ proxy: Proxy) throws(NWError) -> NWParameters {
#if !DEBUG
        let disableInBoxProxy = false
#endif
        if #available(macOS 14.0, iOS 17.0, *), !disableInBoxProxy {
            return makeInBoxProxyParameters(proxy)
        }
        if #available(macOS 12.3, iOS 15.4, *) {
            let parameters = makeDirectNWParameters(.tcp, isSecure: proxy.isSecure, sni: proxy.sni)
            let options: NWProtocolFramer.Options = .proxy(
                connectingToRemote: host,
                port,
                isSecure: isSecure,
                sni: sni,
                authorization: proxy.authorization,
                additionalProtocols: additionalProtocols
            )
            parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
            return parameters
        }
        throw NWError.posix(.ENOTSUP)
    }
    
    private func makeProxyMainEndpoint(_ proxy: Proxy) throws(NWError) -> NWEndpoint {
#if !DEBUG
        let disableInBoxProxy = false
#endif
        if #available(macOS 14.0, iOS 17.0, *), !disableInBoxProxy {
            return endpoint
        }
        if #available(macOS 12.3, iOS 15.4, *) {
            return proxy.endpoint
        }
        throw NWError.posix(.ENOTSUP)
    }
    
    @available(macOS 14.0, iOS 17.0, *)
    private func makeInBoxProxyParameters(_ proxy: Proxy) -> NWParameters {
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
        parameters.defaultProtocolStack.applicationProtocols.insert(contentsOf: additionalProtocols, at: 0)
        return parameters
    }
}
