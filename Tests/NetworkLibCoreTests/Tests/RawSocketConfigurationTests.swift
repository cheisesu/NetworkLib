import Foundation
import Testing
@preconcurrency import Network
import NetworkLibHttpCore
import NetworkLibUtils
@testable import NetworkLibCore

extension Tag {
    @Tag static var core: Tag
}

extension Tag.RawSocket {
    @Tag static var configuration: Tag
}

@Suite(.tags(.core, .RawSocket.all, .RawSocket.configuration))
struct RawSocketConfigurationTests {
    struct Proxy {
        @Test
        func initDefault_AssignsProperties() throws {
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999)
            try #require(proxy.authorization == nil)
            try #require(proxy.host == "some.host")
            try #require(proxy.port == 9999)
            try #require(proxy.isSecure)
            try #require(proxy.sni == nil)
        }

        @Test
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

        @Test
        func endpointCorrect() throws {
            let expected = NWEndpoint.hostPort(host: "some.host", port: 9999)
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999)
            try #require(proxy.endpoint == expected)
        }
    }

    struct Main {
        @Test
        func maxDataLengthIsDeviceBitWidthKb() throws {
            try #require(RawSocketConfiguration.maxDataLength == Int.bitWidth * 1024)
        }

#if false
        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func init_NoProxy_AssignsProperties(_ transport: RawSocketTransport) throws {
            let config = RawSocketConfiguration("some.host", 9999, ipVersion: .v6, isSecure: true, sni: "sni-value",
                                                transport: transport, maxDataBlock: 256, timeout: 20,
                                                additionalProtocols: [.http()])
            try #require(config.proxy == nil)
            try #require(config.host == "some.host")
            try #require(config.port == 9999)
            try #require(config.overrideIpVersion == .v6)
            try #require(config.isSecure)
            try #require(config.sni == "sni-value")
            try #require(config.transport == transport)
            try #require(config.maxDataBlock == 256)
            try #require(config.timeout == 20)
            try #require(config.additionalProtocols.count == 1)
        }
#endif

        @Test
        func initDefault_NoProxy_AssignsProperties() throws {
            let config = RawSocketConfiguration("some.host", 9999)
            try #require(config.proxy == nil)
            try #require(config.host == "some.host")
            try #require(config.port == 9999)
            try #require(config.overrideIpVersion == .any)
            try #require(config.isSecure)
            try #require(config.sni == nil)
            try #require(config.transport == .tcp)
            try #require(config.maxDataBlock == RawSocketConfiguration.maxDataLength)
            try #require(config.timeout == 30)
            try #require(config.additionalProtocols.isEmpty)
        }

#if false
        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func usingProxy_AssignsProperties(_ transport: RawSocketTransport) throws {
            let auth = RawSocketConfiguration.Proxy.Authorization.basic(userName: "foo", password: "pas)01")
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999, isSecure: true, sni: "sni-value",
                                                     authorization: auth)
            let config = RawSocketConfiguration("some.host", 9999, ipVersion: .v6, isSecure: true, sni: "sni-value",
                                                transport: transport, maxDataBlock: 256, timeout: 20,
                                                additionalProtocols: [.http()])
                .using(proxy: proxy)
            try #require(config.proxy == proxy)
            try #require(config.host == "some.host")
            try #require(config.port == 9999)
            try #require(config.overrideIpVersion == .v6)
            try #require(config.isSecure)
            try #require(config.sni == "sni-value")
            try #require(config.transport == transport)
            try #require(config.maxDataBlock == 256)
            try #require(config.timeout == 20)
            try #require(config.additionalProtocols.count == 1)
        }

        @Test(arguments: [RawSocketTransport.tcp, .udp])
        func init_WithProxy_AssignsProperties(_ transport: RawSocketTransport) throws {
            let auth = RawSocketConfiguration.Proxy.Authorization.basic(userName: "foo", password: "pas)01")
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999, isSecure: true, sni: "sni-value",
                                                     authorization: auth)
            let config = RawSocketConfiguration("some.host", 9999, ipVersion: .v6, isSecure: true, sni: "sni-value", proxy: proxy,
                                                transport: transport, maxDataBlock: 256, timeout: 20,
                                                additionalProtocols: [.http()])
            try #require(config.proxy == proxy)
            try #require(config.host == "some.host")
            try #require(config.port == 9999)
            try #require(config.overrideIpVersion == .v6)
            try #require(config.isSecure)
            try #require(config.sni == "sni-value")
            try #require(config.transport == transport)
            try #require(config.maxDataBlock == 256)
            try #require(config.timeout == 20)
            try #require(config.additionalProtocols.count == 1)
        }
#endif

        @Test
        func initDefault_WithProxy_AssignsProperties() throws {
            let auth = HTTPAuthorization.basic(userName: "foo", password: "pas)01")
            let proxy = RawSocketConfiguration.Proxy(host: "some.host", port: 9999, isSecure: true, sni: "sni-value",
                                                     authorization: auth)
            let config = RawSocketConfiguration("some.host", 9999, proxy: proxy)
            try #require(config.proxy == proxy)
            try #require(config.host == "some.host")
            try #require(config.port == 9999)
            try #require(config.overrideIpVersion == .any)
            try #require(config.isSecure)
            try #require(config.sni == nil)
            try #require(config.transport == .tcp)
            try #require(config.maxDataBlock == RawSocketConfiguration.maxDataLength)
            try #require(config.timeout == 30)
            try #require(config.additionalProtocols.isEmpty)
        }

        @Test
        func endpointCorrect() throws {
            let expected = NWEndpoint.hostPort(host: "some.host", port: 9999)
            let config = RawSocketConfiguration("some.host", 9999)
            try #require(config.endpoint == expected)
        }
    }

    struct CreateNWConnection {
        // MARK: NO PROXY

        @Test(arguments: [RawSocketTransport.tcp, .udp], [NWProtocolIP.Options.Version.any, .v4, .v6])
        func noProxy_Insecure_NoAdditionalProtocols_ReturnsCorrect(_ transport: RawSocketTransport,
                                                                   _ ipVersion: NWProtocolIP.Options.Version) throws
        {
            let config = RawSocketConfiguration("some.host", 9999, ipVersion: ipVersion, isSecure: false, transport: transport)
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
            let ip = try #require(parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options)
            try #require(ip.version == ipVersion)
            try #require(parameters.defaultProtocolStack.applicationProtocols.isEmpty)
        }

#if false
        @Test(arguments: [RawSocketTransport.tcp, .udp])
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
#endif

        @Test(arguments: [RawSocketTransport.tcp, .udp])
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

#if false
        @Test(arguments: [RawSocketTransport.tcp, .udp])
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
#endif

        // MARK: WITH PROXY INBOX

        @Test(.disabled("Not possible to get privacyContext"), arguments: [RawSocketTransport.tcp, .udp])
        func withInsecureProxy_Insecure_InBox_NoAdditionalProtocols_ReturnsCorrect(_ transport: RawSocketTransport) throws {
        }

        // MARK: WITH PROXY CUSTOM

        static let customProxyAuthBasic: HTTPAuthorization? = .basic(userName: "foo", password: "pas)01")
        static let customProxyAuthNone: HTTPAuthorization? = nil
        static let customProxySniSet: String? = "some-sni"
        static let customProxySniNone: String? = nil
        static let customProxyProtocolsEmpty: [NWProtocolOptions] = []
#if false
        static let customProxyProtocolsHttp: [NWProtocolOptions] = [.http()]
#else
        static let customProxyProtocolsHttp: [NWProtocolOptions] = []
#endif

#if false
        @Test(arguments: [
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, NWProtocolIP.Options.Version.any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (false, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (false, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.tcp, Self.customProxyAuthNone, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, Self.customProxyAuthBasic, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (true, "some.host", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, false, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniNone, Self.customProxyProtocolsHttp, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsEmpty, .v6),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .any),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v4),
                (true, "2001:db8::1", RawSocketTransport.udp, nil, true, Self.customProxySniSet, Self.customProxyProtocolsHttp, .v6),
              ])
        func withCustomProxy_ReturnsCorrect(_ isProxySecure: Bool, _ host: String, _ transport: RawSocketTransport,
                                            _ auth: RawSocketConfiguration.Proxy.Authorization?, _ isSecure: Bool, _ sni: String?,
                                            _ additionalProtocols: [NWProtocolOptions], _ ipVersion: NWProtocolIP.Options.Version) throws
        {
            let host = NWEndpoint.Host(host)
            let proxy = RawSocketConfiguration.Proxy(host: "some.proxy", port: 8888, isSecure: isProxySecure, authorization: auth)
            var config = RawSocketConfiguration(host, 9999, ipVersion: ipVersion, isSecure: isSecure, sni: sni, proxy: proxy,
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
            let optAuth = options["kOptionsProxyAuth"] as? RawSocketConfiguration.Proxy.Authorization
            let optTopProtocols = try #require(options["kOptionsProxyTopProtocols"] as? [NWProtocolOptions])
            let ip = try #require(parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options)

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
            try #require(ip.version == ipVersion)
        }
#endif
    }
}
