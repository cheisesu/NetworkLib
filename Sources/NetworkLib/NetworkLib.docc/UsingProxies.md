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

## See Also

- <doc:SendingAndReceiving>
