import Foundation
import Testing
import Network
@testable import NetworkLib

extension Tag.RawSocketConnect {
    @Tag static var configuration: Tag
}

struct RawSocketConfigurationTests {
    struct Proxy {
        @Test(.tags(.RawSocketConnect.configuration))
        func authorizationHeader() throws {
            let expected = "Basic Zm9vOnBhcykwMQ=="
            let auth = HTTPAuthorization.basic(userName: "foo", password: "pas)01")
            let header = auth.httpHeader
            try #require(header == expected)
        }

        @Test(.tags(.RawSocketConnect.configuration))
        func initDefault_AssignsProperties() throws {
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999)
            try #require(proxy.authorization == nil)
            try #require(proxy.host == "some.host")
            try #require(proxy.port == 9999)
            try #require(proxy.isSecure)
            try #require(proxy.sni == nil)
        }

        @Test(.tags(.RawSocketConnect.configuration))
        func initAssignsProperties() throws {
            let auth = HTTPAuthorization.basic(userName: "foo", password: "pas)01")
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999, isSecure: true, sni: "sni-value",
                                                     authorization: auth)
            try #require(proxy.authorization == auth)
            try #require(proxy.host == "some.host")
            try #require(proxy.port == 9999)
            try #require(proxy.isSecure)
            try #require(proxy.sni == "sni-value")
        }

        @Test(.tags(.RawSocketConnect.configuration))
        func endpointCorrect() throws {
            let expected = NWEndpoint.hostPort(host: "some.host", port: 9999)
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999)
            try #require(proxy.endpoint == expected)
        }
    }

    struct Main {
        @Test(.tags(.RawSocketConnect.configuration), arguments: [RawSocketTransport.tcp, .udp])
        func init_NoProxy_AssignsProperties(_ transport: RawSocketTransport) throws {
            let config = RawSocketConfiguration("some.host", 9999, isSecure: true, sni: "sni-value", transport: transport,
                                                maxDataBlock: 256, timeout: 20, additionalProtocols: [.http()])
            try #require(config.proxy == nil)
            try #require(config.host == "some.host")
            try #require(config.port == 9999)
            try #require(config.isSecure)
            try #require(config.sni == "sni-value")
            try #require(config.transport == transport)
            try #require(config.maxDataBlock == 256)
            try #require(config.timeout == 20)
            try #require(config.additionalProtocols.count == 1)
        }

        @Test(.tags(.RawSocketConnect.configuration))
        func initDefault_NoProxy_AssignsProperties() throws {
            let config = RawSocketConfiguration("some.host", 9999)
            try #require(config.proxy == nil)
            try #require(config.host == "some.host")
            try #require(config.port == 9999)
            try #require(config.isSecure)
            try #require(config.sni == nil)
            try #require(config.transport == .tcp)
            try #require(config.maxDataBlock == .max)
            try #require(config.timeout == 10)
            try #require(config.additionalProtocols.isEmpty)
        }

        @Test(.tags(.RawSocketConnect.configuration), arguments: [RawSocketTransport.tcp, .udp])
        func usingProxy_AssignsProperties(_ transport: RawSocketTransport) throws {
            let auth = HTTPAuthorization.basic(userName: "foo", password: "pas)01")
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999, isSecure: true, sni: "sni-value",
                                                     authorization: auth)
            let config = RawSocketConfiguration("some.host", 9999, isSecure: true, sni: "sni-value", transport: transport,
                                                maxDataBlock: 256, timeout: 20, additionalProtocols: [.http()])
                .using(proxy: proxy)
            try #require(config.proxy == proxy)
            try #require(config.host == "some.host")
            try #require(config.port == 9999)
            try #require(config.isSecure)
            try #require(config.sni == "sni-value")
            try #require(config.transport == transport)
            try #require(config.maxDataBlock == 256)
            try #require(config.timeout == 20)
            try #require(config.additionalProtocols.count == 1)
        }

        @Test(.tags(.RawSocketConnect.configuration), arguments: [RawSocketTransport.tcp, .udp])
        func init_WithProxy_AssignsProperties(_ transport: RawSocketTransport) throws {
            let auth = HTTPAuthorization.basic(userName: "foo", password: "pas)01")
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999, isSecure: true, sni: "sni-value",
                                                     authorization: auth)
            let config = RawSocketConfiguration("some.host", 9999, isSecure: true, sni: "sni-value", proxy: proxy,
                                                transport: transport, maxDataBlock: 256, timeout: 20,
                                                additionalProtocols: [.http()])
            try #require(config.proxy == proxy)
            try #require(config.host == "some.host")
            try #require(config.port == 9999)
            try #require(config.isSecure)
            try #require(config.sni == "sni-value")
            try #require(config.transport == transport)
            try #require(config.maxDataBlock == 256)
            try #require(config.timeout == 20)
            try #require(config.additionalProtocols.count == 1)
        }

        @Test(.tags(.RawSocketConnect.configuration))
        func initDefault_WithProxy_AssignsProperties() throws {
            let auth = HTTPAuthorization.basic(userName: "foo", password: "pas)01")
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999, isSecure: true, sni: "sni-value",
                                                     authorization: auth)
            let config = RawSocketConfiguration("some.host", 9999, proxy: proxy)
            try #require(config.proxy == proxy)
            try #require(config.host == "some.host")
            try #require(config.port == 9999)
            try #require(config.isSecure)
            try #require(config.sni == nil)
            try #require(config.transport == .tcp)
            try #require(config.maxDataBlock == .max)
            try #require(config.timeout == 10)
            try #require(config.additionalProtocols.isEmpty)
        }

        @Test(.tags(.RawSocketConnect.configuration))
        func endpointCorrect() throws {
            let expected = NWEndpoint.hostPort(host: "some.host", port: 9999)
            let config = RawSocketConfiguration("some.host", 9999)
            try #require(config.endpoint == expected)
        }
    }

    struct CreateNWConnection {
        // MARK: NO PROXY

        @Test(.tags(.RawSocketConnect.configuration), arguments: [RawSocketTransport.tcp, .udp])
        func noProxy_Insecure_NoAdditionalProtocols_ReturnsCorrect(_ transport: RawSocketTransport) throws {
            let config = RawSocketConfiguration("some.host", 9999, isSecure: false, transport: transport)
            let connection = try config.makeNWConnection()
            try #require(connection.endpoint == config.endpoint)
            let parameters = connection.parameters
            switch transport {
            case .tcp:
                let proto = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options
                try #require(proto != nil)
            case .udp:
                let proto = parameters.defaultProtocolStack.transportProtocol as? NWProtocolUDP.Options
                try #require(proto != nil)
            }
            try #require(parameters.defaultProtocolStack.applicationProtocols.isEmpty)
        }

        @Test(.tags(.RawSocketConnect.configuration), arguments: [RawSocketTransport.tcp, .udp])
        func noProxy_Insecure_WithAdditionalProtocols_ReturnsCorrect(_ transport: RawSocketTransport) throws {
            let http = NWProtocolFramer.Options.http()
            let config = RawSocketConfiguration("some.host", 9999, isSecure: false, transport: transport,
                                                additionalProtocols: [http])
            let connection = try config.makeNWConnection()
            try #require(connection.endpoint == config.endpoint)
            let parameters = connection.parameters
            switch transport {
            case .tcp:
                let proto = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options
                try #require(proto != nil)
            case .udp:
                let proto = parameters.defaultProtocolStack.transportProtocol as? NWProtocolUDP.Options
                try #require(proto != nil)
            }
            try #require(parameters.defaultProtocolStack.applicationProtocols.count == 1)
        }

        @Test(.tags(.RawSocketConnect.configuration), arguments: [RawSocketTransport.tcp, .udp])
        func noProxy_Secure_NoAdditionalProtocols_ReturnsCorrect(_ transport: RawSocketTransport) throws {
            let config = RawSocketConfiguration("some.host", 9999, isSecure: true, transport: transport,
                                                additionalProtocols: [])
            let connection = try config.makeNWConnection()
            try #require(connection.endpoint == config.endpoint)
            let parameters = connection.parameters
            switch transport {
            case .tcp:
                let proto = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options
                try #require(proto != nil)
            case .udp:
                let proto = parameters.defaultProtocolStack.transportProtocol as? NWProtocolUDP.Options
                try #require(proto != nil)
            }
            try #require(parameters.defaultProtocolStack.applicationProtocols.count == 1)
            let tls = parameters.defaultProtocolStack.applicationProtocols.first as? NWProtocolTLS.Options
            try #require(tls != nil)
        }

        @Test(.tags(.RawSocketConnect.configuration), arguments: [RawSocketTransport.tcp, .udp])
        func noProxy_Secure_WithAdditionalProtocols_ReturnsCorrect(_ transport: RawSocketTransport) throws {
            let http = NWProtocolFramer.Options.http()
            let config = RawSocketConfiguration("some.host", 9999, isSecure: true, transport: transport,
                                                additionalProtocols: [http])
            let connection = try config.makeNWConnection()
            try #require(connection.endpoint == config.endpoint)
            let parameters = connection.parameters
            switch transport {
            case .tcp:
                let proto = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options
                try #require(proto != nil)
            case .udp:
                let proto = parameters.defaultProtocolStack.transportProtocol as? NWProtocolUDP.Options
                try #require(proto != nil)
            }
            try #require(parameters.defaultProtocolStack.applicationProtocols.count == 2)
            let httpAdded = parameters.defaultProtocolStack.applicationProtocols[0] as? NWProtocolTLS.Options
            let tls = parameters.defaultProtocolStack.applicationProtocols[1] as? NWProtocolTLS.Options
            try #require(tls != nil)
            try #require(httpAdded == nil)
        }

        // MARK: WITH PROXY INBOX

        @Test(.disabled("Not possible to get privacyContext"), .tags(.RawSocketConnect.configuration),
              arguments: [RawSocketTransport.tcp, .udp])
        func withInsecureProxy_Insecure_InBox_NoAdditionalProtocols_ReturnsCorrect(_ transport: RawSocketTransport) throws {
        }

        // MARK: WITH PROXY CUSTOM

        @Test(.tags(.RawSocketConnect.configuration),
              arguments: [
                (false, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.tcp, nil, false, nil as String?, [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.tcp, nil, false, nil as String?, [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.tcp, nil, true, nil as String?, [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.tcp, nil, true, nil as String?, [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.tcp, nil, true, "some-sni", [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.tcp, nil, true, "some-sni", [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.tcp, nil, false, nil as String?, [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.tcp, nil, false, nil as String?, [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.tcp, nil, true, nil as String?, [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.tcp, nil, true, nil as String?, [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.tcp, nil, true, "some-sni", [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.tcp, nil, true, "some-sni", [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.udp, nil, false, nil as String?, [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.udp, nil, false, nil as String?, [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.udp, nil, true, nil as String?, [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.udp, nil, true, nil as String?, [NWProtocolOptions.http()]),
                (false, "some.host", RawSocketTransport.udp, nil, true, "some-sni", [NWProtocolOptions]()),
                (false, "some.host", RawSocketTransport.udp, nil, true, "some-sni", [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, false, nil as String?, [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, false, nil as String?, [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, nil as String?, [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, nil as String?, [NWProtocolOptions.http()]),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, "some-sni", [NWProtocolOptions]()),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, "some-sni", [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.tcp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.tcp, nil, false, nil as String?, [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.tcp, nil, false, nil as String?, [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.tcp, nil, true, nil as String?, [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.tcp, nil, true, nil as String?, [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.tcp, nil, true, "some-sni", [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.tcp, nil, true, "some-sni", [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.tcp, nil, false, nil as String?, [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.tcp, nil, false, nil as String?, [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.tcp, nil, true, nil as String?, [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.tcp, nil, true, nil as String?, [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.tcp, nil, true, "some-sni", [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.tcp, nil, true, "some-sni", [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), false, nil as String?, [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, nil as String?, [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.udp, HTTPAuthorization.basic(userName: "foo", password: "pas)01"), true, "some-sni", [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.udp, nil, false, nil as String?, [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.udp, nil, false, nil as String?, [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.udp, nil, true, nil as String?, [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.udp, nil, true, nil as String?, [NWProtocolOptions.http()]),
                (true, "some.host", RawSocketTransport.udp, nil, true, "some-sni", [NWProtocolOptions]()),
                (true, "some.host", RawSocketTransport.udp, nil, true, "some-sni", [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, false, nil as String?, [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, false, nil as String?, [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, nil as String?, [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, nil as String?, [NWProtocolOptions.http()]),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, "some-sni", [NWProtocolOptions]()),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, "some-sni", [NWProtocolOptions.http()]),
              ])
        func withCustomProxy_ReturnsCorrect(_ isProxySecure: Bool, _ host: String, _ transport: RawSocketTransport,
                                            _ auth: HTTPAuthorization?, _ isSecure: Bool, _ sni: String?,
                                            _ additionalProtocols: [NWProtocolOptions]) throws
        {
            let host = NWEndpoint.Host(host)
            let proxy = RawSocketConfiguration.Proxy(host: "some.proxy", port: 8888, isSecure: isProxySecure, authorization: auth)
            var config = RawSocketConfiguration(host, 9999, isSecure: isSecure, sni: sni, proxy: proxy,
                                                transport: transport, additionalProtocols: additionalProtocols)
            config.disableInBoxProxy = true
            let connection = try config.makeNWConnection()
            try #require(connection.endpoint == proxy.endpoint)
            let parameters = connection.parameters
            let proto = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options
            try #require(proto != nil)
            let appProtosCount = isProxySecure ? 2 : 1
            try #require(parameters.defaultProtocolStack.applicationProtocols.count == appProtosCount)
            if isProxySecure {
                let tls = parameters.defaultProtocolStack.applicationProtocols[1] as? NWProtocolTLS.Options
                try #require(tls != nil)
            }
            let options = try #require(parameters.defaultProtocolStack.applicationProtocols[0] as? NWProtocolFramer.Options)
            let optHost = try #require(options["kOptionsEndpointHost"] as? NWEndpoint.Host)
            let optPort = try #require(options["kOptionsEndpointPort"] as? NWEndpoint.Port)
            let optIsSecure = try #require(options["kOptionsIsSecure"] as? Bool)
            let optSni = options["kOptionsServerName"] as? String
            let optAuth = options["kOptionsProxyAuth"] as? HTTPAuthorization
            let optTopProtocols = try #require(options["kOptionsProxyTopProtocols"] as? [NWProtocolOptions])

            try #require(optHost == host)
            try #require(optPort == 9999)
            try #require(optIsSecure == isSecure)
            let sni = if isSecure, sni == nil, !host.isIPAddress {
                host.asString
            } else {
                sni
            }
            try #require(optSni == sni)
            try #require(optAuth == auth)
            try #require(optTopProtocols.count == additionalProtocols.count)
        }
    }
}
