import Foundation
import Network

@available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
enum ProxyOptions: Sendable {
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
        options[ProxyOptions.kOptionsEndpointHost] = host
        options[ProxyOptions.kOptionsEndpointPort] = port
        options[ProxyOptions.kOptionsIsSecure] = isSecure
        options[ProxyOptions.kOptionsServerName] = if isSecure, sni == nil, !host.isIPAddress {
            host.asString
        } else {
            sni
        }
        options[ProxyOptions.kOptionsProxyAuth] = authorization
        options[ProxyOptions.kOptionsProxyTopProtocols] = additionalProtocols
        return options
    }
}

@available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
private final class ProtocolProxy: NWProtocolFramerImplementation, @unchecked Sendable {
    static let definition = NWProtocolFramer.Definition(implementation: ProtocolProxy.self)
    static let label: String = "ProtocolProxy"

    private let implementation: any ProtocolFramerImplementation

    init(framer: NWProtocolFramer.Instance) {
        implementation = .proxy()
    }

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        return implementation.start(framer: .adapter(for: framer, Self.definition))
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        implementation.handleInput(framer: .adapter(for: framer, Self.definition))
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message,
                      messageLength: Int, isComplete: Bool)
    {
        implementation.handleOutput(framer: .adapter(for: framer, Self.definition),
                                    message: message, messageLength: messageLength, isComplete: isComplete)
    }

    func wakeup(framer: NWProtocolFramer.Instance) {
    }

    func stop(framer: NWProtocolFramer.Instance) -> Bool {
        true
    }

    func cleanup(framer: NWProtocolFramer.Instance) {
    }
}
