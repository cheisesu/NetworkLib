import Network
import NetworkLib

@available(macOS 12.3, iOS 15.4, tvOS 15.4, *)
func makeProxiedConfiguration(host: String, port: NWEndpoint.Port) -> RawSocketConfiguration {
    let destination = RawSocketConfiguration("example.com", .https, sni: "example.com", timeout: 15)
    let proxy = RawSocketConfiguration.Proxy(
        host: NWEndpoint.Host(host),
        port: port,
        isSecure: true,
        sni: host
    )
    return destination.using(proxy: proxy)
}
