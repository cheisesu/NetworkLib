# Connecting Through an HTTP Proxy

Configure an HTTP CONNECT tunnel with optional authentication.

## Overview

Use ``RawSocketConfiguration/Proxy`` and ``RawSocketConfiguration/using(proxy:)`` to add a proxy to a destination configuration. Proxy connections require iOS or tvOS 15.4 or later, or macOS 12.3 or later.

### Configure a secure proxy connection

Replace the example proxy hostname and port with those of your proxy. Supply credentials from your application's credential storage.

```swift
import NetworkLib

@available(iOS 15.4, tvOS 15.4, macOS 12.3, *)
func connectThroughProxy(username: String, password: String) async throws {
    let destination = RawSocketConfiguration(
        "example.com",
        .https,
        isSecure: true,
        sni: "example.com"
    )
    let proxy = RawSocketConfiguration.Proxy(
        host: "proxy.example.com",
        port: 8443,
        isSecure: true,
        sni: "proxy.example.com",
        authorization: .basic(userName: username, password: password)
    )
    let socket = try RawSocket(destination.using(proxy: proxy))

    do {
        let info = try await socket.connect()
        print("Connected through proxy:", info.remoteEndpoint)
        // Exchange destination protocol data here.
        await socket.cancel()
    } catch {
        await socket.cancel()
        throw error
    }
}
```

The proxy in this example must support TLS and HTTP CONNECT. Its `isSecure` setting controls TLS to the proxy; the destination configuration controls TLS inside the tunnel. For a plaintext HTTP CONNECT proxy, set the proxy's `isSecure` to `false` and use its appropriate port. Omit `authorization` when authentication isn't required.

After connecting, send and receive data using the same socket methods as for a direct connection. The library establishes the CONNECT tunnel for you.

### Run the CLI example

From a local checkout of NetworkLib, run this command in the directory containing `Package.swift`:

```sh
swift run Examples proxy
```

Set `NL_PROXY_HOST` and `NL_PROXY_PORT` for your HTTP CONNECT proxy. For example, with a plaintext proxy listening locally:

```sh
NL_PROXY_HOST=localhost NL_PROXY_PORT=8080 NL_PROXY_TLS=false swift run Examples proxy
```

`NL_PROXY_TLS` defaults to `true`. For TLS proxies, the certificate must be trusted by the system. If authentication is required, set both `NL_PROXY_USERNAME` and `NL_PROXY_PASSWORD` in the environment. The CLI fetches `https://example.com` through the proxy and prints the raw response. This command requires macOS 12.3 or later.

The runnable implementation is in `Sources/Examples/ProxyExample.swift`. See <doc:RunningExamples> for tool requirements, the complete command list, and shared CLI behavior.

## See Also

- <doc:SendingAndReceiving>
