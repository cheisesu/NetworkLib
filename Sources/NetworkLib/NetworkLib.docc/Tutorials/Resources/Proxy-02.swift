import Foundation
import Network
import NetworkLib

enum ProxyExample {
    // Pass an interface from NWPath.availableInterfaces to require it; nil uses system selection.
    static func run(interface: NWInterface? = nil) async throws {
        print("Requires an HTTP CONNECT proxy. Set the proxy environment variables described in the proxy guide.")
        guard #available(macOS 12.3, iOS 15.4, tvOS 15.4, *) else {
            throw ProxySetupError.message("Proxy connections require macOS 12.3 or later.")
        }
        let environment = ProcessInfo.processInfo.environment
        guard let host = environment["NL_PROXY_HOST"], !host.isEmpty,
              let portText = environment["NL_PROXY_PORT"],
              let portNumber = UInt16(portText), portNumber > 0,
              let port = NWEndpoint.Port(rawValue: portNumber) else {
            throw ProxySetupError.message("Set NL_PROXY_HOST and NL_PROXY_PORT (1–65535).")
        }
        let tlsText = environment["NL_PROXY_TLS"] ?? "true"
        guard tlsText == "true" || tlsText == "false" else {
            throw ProxySetupError.message("NL_PROXY_TLS must be true or false.")
        }
        let username = environment["NL_PROXY_USERNAME"]
        let password = environment["NL_PROXY_PASSWORD"]
        guard (username == nil) == (password == nil) else {
            throw ProxySetupError.message("Set both NL_PROXY_USERNAME and NL_PROXY_PASSWORD, or neither.")
        }
        var authorization: HTTPAuthorization?
        if let username, let password {
            authorization = .basic(userName: username, password: password)
        }
        let proxy = RawSocketConfiguration.Proxy(
            host: NWEndpoint.Host(host),
            port: port,
            isSecure: tlsText == "true",
            sni: tlsText == "true" ? host : nil,
            authorization: authorization
        )
        print("Proxy configured (TLS: \(tlsText), authentication: \(authorization != nil)).")
        let destination = RawSocketConfiguration("example.com", .https, sni: "example.com", timeout: 15, interface: interface)
        try await SendingAndReceivingExample.exchange(using: destination.using(proxy: proxy))
    }
}

private enum ProxySetupError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let text): return text
        }
    }
}
