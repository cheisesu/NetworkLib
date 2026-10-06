import Foundation
@preconcurrency import Network

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
extension RawSocketConfiguration {
    /// The default upper bound for a data block returned by a single raw receive operation.
    ///
    /// The value is `Int.bitWidth * 1024` bytes.
    public static let maxDataLength: Int = Int.bitWidth * 1024
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
extension RawSocketConfiguration {
    /// HTTP CONNECT proxy settings used when creating a proxied socket connection.
    ///
    /// On iOS and tvOS 17 or later and macOS 14 or later, NetworkLib applies these settings using
    /// `ProxyConfiguration`. On iOS and tvOS 15.4 through 16 and macOS 12.3 through 13, it uses an HTTP CONNECT
    /// protocol framer. Proxy connections aren't supported on earlier deployment targets.
    /// The proxy connection always uses TCP; ``isSecure`` controls TLS to the proxy, independently of the destination's transport
    /// and security settings.
    ///
    /// For example, attach a proxy to an existing socket configuration:
    ///
    /// ```swift
    /// let proxy = RawSocketConfiguration.Proxy(host: "proxy.example.com", port: 8080)
    /// let proxied = configuration.using(proxy: proxy)
    /// ```
    public struct Proxy: Sendable, Equatable {
        /// The proxy server host name or IP address.
        public let host: NWEndpoint.Host

        /// The proxy server port.
        public let port: NWEndpoint.Port

        /// A Boolean value indicating whether the TCP connection to the proxy itself uses TLS.
        public let isSecure: Bool

        /// The Server Name Indication value used for TLS when connecting to the proxy.
        ///
        /// A `nil` value leaves server-name selection to the Network framework.
        public let sni: String?

        /// Credentials sent to the proxy in the `Proxy-Authorization` header, or `nil` when the proxy requires no authentication.
        public let authorization: HTTPAuthorization?

        var endpoint: NWEndpoint {
            .hostPort(host: host, port: port)
        }

        /// Creates HTTP CONNECT proxy settings.
        ///
        /// - Parameters:
        ///   - host: The proxy server host name or IP address.
        ///   - port: The proxy server port.
        ///   - isSecure: Whether to use TLS for the connection to the proxy server.
        ///   - sni: The TLS server name to send when connecting to the proxy, or `nil` to use the system default behavior.
        ///   - authorization: Optional proxy authentication credentials.
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

/// Configuration used to create a ``RawSocket``.
///
/// For example, configure a TLS TCP connection to a web server:
///
/// ```swift
/// let configuration = RawSocketConfiguration(
///     "example.com",
///     .https,
///     isSecure: true,
///     sni: "example.com"
/// )
/// let socket = try RawSocket(configuration)
/// ```
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public struct RawSocketConfiguration: Sendable {
    /// The remote host name or IP address to connect to.
    public let host: NWEndpoint.Host

    /// The remote port to connect to.
    public let port: NWEndpoint.Port

    /// A Boolean value indicating whether the destination connection uses TLS for TCP or DTLS for UDP.
    public let isSecure: Bool

    /// The Server Name Indication value used for destination TLS or DTLS, or `nil` to leave server-name selection to the Network
    /// framework.
    public let sni: String?

    /// The transport protocol used by the socket.
    public let transport: RawSocketTransport

    /// The IP protocol version preference applied to the connection parameters.
    ///
    /// The default `.any` permits the Network framework to select IPv4 or IPv6.
    public let overrideIpVersion: NWProtocolIP.Options.Version

    /// The upper bound for a data block returned by each raw receive operation.
    ///
    /// This value applies to ``RawSocket/receiveNext(_:)`` and ``RawSocket/receiveNext()``.
    public let maxDataBlock: Int

    /// The inactivity timeout, in seconds, for connection, send, and receive operations.
    ///
    /// Network activity refreshes the timeout. When it expires, the socket fails pending work with `NWError.posix(.ETIMEDOUT)`.
    public let timeout: TimeInterval

    /// The HTTP CONNECT proxy settings, or `nil` for a direct connection.
    public let proxy: Proxy?

    /// Additional Network framework application protocols inserted at the front of the application protocol stack.
    ///
    /// For a proxied connection, these protocols apply to the connection inside the established HTTP CONNECT tunnel.
    public let additionalProtocols: [NWProtocolOptions]
#if DEBUG
    var disableInBoxProxy: Bool = false
#endif

    var endpoint: NWEndpoint {
        return .hostPort(host: host, port: port)
    }

    /// Creates a configuration for a direct socket connection.
    ///
    /// - Parameters:
    ///   - host: The remote host name or IP address.
    ///   - port: The remote port.
    ///   - ipVersion: The IP version preference for the underlying connection.
    ///   - isSecure: Whether to enable TLS for TCP or DTLS for UDP.
    ///   - sni: The TLS or DTLS server name, or `nil` for the system default behavior.
    ///   - transport: The transport protocol to use.
    ///   - maxDataBlock: The maximum byte count requested by each raw receive operation.
    ///   - timeout: The socket operation timeout in seconds.
    ///   - additionalProtocols: Application protocols to insert above the transport protocol stack.
    public init(_ host: NWEndpoint.Host, _ port: NWEndpoint.Port, ipVersion: NWProtocolIP.Options.Version = .any,
                isSecure: Bool = true, sni: String? = nil,
                transport: RawSocketTransport = .tcp, maxDataBlock: Int = Self.maxDataLength,
                timeout: TimeInterval = 30, additionalProtocols: [NWProtocolOptions] = [])
    {
        self.host = host
        self.port = port
        overrideIpVersion = ipVersion
        self.isSecure = isSecure
        self.sni = sni
        self.transport = transport
        self.maxDataBlock = maxDataBlock
        self.timeout = timeout
        proxy = nil
        self.additionalProtocols = additionalProtocols
    }

    /// Creates a configuration for a socket connection through an HTTP CONNECT proxy.
    ///
    /// - Parameters:
    ///   - host: The final remote host name or IP address.
    ///   - port: The final remote port.
    ///   - ipVersion: The IP version preference for the underlying connection.
    ///   - isSecure: Whether to enable TLS for TCP or DTLS for UDP after the proxy tunnel is established.
    ///   - sni: The TLS or DTLS server name for the final remote connection.
    ///   - proxy: The proxy server configuration.
    ///   - transport: The transport protocol to use for the final connection.
    ///   - maxDataBlock: The maximum byte count requested by each raw receive operation.
    ///   - timeout: The socket operation timeout in seconds.
    ///   - additionalProtocols: Application protocols to insert above the final remote connection.
    @available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
    public init(_ host: NWEndpoint.Host, _ port: NWEndpoint.Port, ipVersion: NWProtocolIP.Options.Version = .any,
                isSecure: Bool = true, sni: String? = nil,
                proxy: Proxy, transport: RawSocketTransport = .tcp, maxDataBlock: Int = Self.maxDataLength,
                timeout: TimeInterval = 30, additionalProtocols: [NWProtocolOptions] = [])
    {
        self.host = host
        self.port = port
        overrideIpVersion = ipVersion
        self.isSecure = isSecure
        self.sni = sni
        self.transport = transport
        self.maxDataBlock = maxDataBlock
        self.timeout = timeout
        self.proxy = proxy
        self.additionalProtocols = additionalProtocols
    }

    /// Returns a copy of this configuration that connects through the specified HTTP CONNECT proxy.
    ///
    /// All destination, transport, security, receive-size, timeout, and application-protocol settings remain unchanged.
    ///
    /// - Parameter proxy: The proxy server configuration to use.
    /// - Returns: A new configuration with the same destination and socket settings, plus the supplied proxy.
    @available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
    public func using(proxy: Proxy) -> RawSocketConfiguration {
        RawSocketConfiguration(
            host,
            port,
            ipVersion: overrideIpVersion,
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
        let parameters = makeDirectNWParameters(transport, ipVersion: overrideIpVersion, isSecure: isSecure, sni: sni)
        parameters.defaultProtocolStack.applicationProtocols.insert(contentsOf: additionalProtocols, at: 0)
        return NWConnection(to: endpoint, using: parameters)
    }

    private func makeDirectNWParameters(_ transport: RawSocketTransport, ipVersion: NWProtocolIP.Options.Version,
                                        isSecure: Bool, sni: String?) -> NWParameters
    {
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
        let ipProtocol = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options
        ipProtocol?.version = ipVersion
        return parameters
    }

    private func makeProxyParameters(_ proxy: Proxy) throws(NWError) -> NWParameters {
        if #available(iOS 17.0, tvOS 17.0, macOS 14.0, *), !disableInBoxProxy {
            return makeInBoxProxyParameters(proxy)
        }
        if #available(iOS 15.4, tvOS 15.4, macOS 12.3, *) {
            let parameters = makeDirectNWParameters(.tcp, ipVersion: overrideIpVersion, isSecure: proxy.isSecure, sni: proxy.sni)
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
        if #available(iOS 17.0, tvOS 17.0, macOS 14.0, *), !disableInBoxProxy {
            return endpoint
        }
        if #available(iOS 15.4, tvOS 15.4, macOS 12.3, *) {
            return proxy.endpoint
        }
        throw NWError.posix(.ENOTSUP)
    }

    @available(iOS 17.0, tvOS 17.0, macOS 14.0, *)
    private func makeInBoxProxyParameters(_ proxy: Proxy) -> NWParameters {
        let parameters = makeDirectNWParameters(transport, ipVersion: overrideIpVersion, isSecure: isSecure, sni: sni)
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
