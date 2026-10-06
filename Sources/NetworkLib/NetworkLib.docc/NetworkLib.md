# ``NetworkLib``

Build socket connections with Swift concurrency and Apple's Network framework.

## Overview

Welcome to NetworkLib, a Swift library for sending and receiving raw bytes and protocol-framed messages on Apple platforms. It wraps Network framework connections in a configurable socket API with both async/await and callback-based operations.

Use NetworkLib when you need control over the transport, connection security, proxy settings, or application protocol framing. The library supports TCP and UDP, with TLS for TCP and DTLS for UDP. It also provides HTTP header, status code, and authorization types, along with utilities for working with network addresses and URLs.

### Features

- **TCP and UDP:** Send and receive raw bytes using either transport.
- **Secure connections:** Use TLS over TCP or DTLS over UDP, with configurable Server Name Indication (SNI).
- **Swift concurrency and callbacks:** Connect, send, receive, and cancel with async/await or completion handlers.
- **Typed messages:** Exchange protocol-framed messages through ``RawSocketSendMessage`` and ``RawSocketReceiveMessage``.
- **HTTP CONNECT proxies:** Configure a proxy with optional Basic authentication and independent security settings for the proxy and destination.
- **Connection configuration:** Choose IPv4 or IPv6 preferences, inactivity timeouts, receive block sizes, and additional application protocols.
- **Connection details:** Inspect the established connection through ``ConnectionInfo``.
- **HTTP and address utilities:** Work with HTTP headers, status codes, authorization, IP addresses, network hosts, and URLs.

### Installation

See <doc:Installation> to add NetworkLib to an Xcode project or Swift package. The first release version is `0.0.1`.

### Configure a connection

Start with ``RawSocketConfiguration`` to choose a destination and transport. You can also configure the IP version, server name, inactivity timeout, receive block size, and additional Network framework application protocols. Secure connections are enabled by default.

Create a ``RawSocket`` from the configuration, then connect asynchronously:

```swift
import NetworkLib

func connectToServer() async throws {
    let configuration = RawSocketConfiguration(
        "example.com",
        .https,
        isSecure: true,
        sni: "example.com"
    )
    let socket = try RawSocket(configuration)
    do {
        let info = try await socket.connect()
        print("Connected to \(info.remoteEndpoint)")
        // Send and receive data here using the server's application protocol.
        await socket.cancel()
    } catch {
        await socket.cancel()
        throw error
    }
}
```

After connecting, use `send(_:)` and `receiveNext()` to exchange bytes. A raw receive returns one available block of data; for TCP, that block isn't necessarily a complete application message. Use ``RawSocketSendMessage`` and ``RawSocketReceiveMessage`` with protocol framing to exchange typed messages.

Each socket represents a single connection attempt. Cancel it when finished, and create a new socket for a new connection. Cancelling a task that is waiting on an asynchronous socket operation permanently cancels that socket; operation failures are reported as `NWError`.

### Connect through a proxy

Configure ``RawSocketConfiguration/Proxy`` to route a connection through an HTTP CONNECT proxy, optionally with ``HTTPAuthorization`` credentials. Security for the connection to the proxy is configured separately from security for the destination connection.

Proxy connections require iOS or tvOS 15.4 or later, or macOS 12.3 or later. NetworkLib uses the system proxy configuration on iOS and tvOS 17 or later and macOS 14 or later, and an HTTP CONNECT protocol framer on earlier supported versions.

### Platform support

The package uses Swift 6 and supports iOS 13 or later, tvOS 13 or later, and macOS 10.15 or later. Individual features may require newer operating system versions, as indicated in their API documentation.

## Topics

### Getting started

- <doc:Installation>

### Socket connections

- ``RawSocket``
- ``RawSocketConfiguration``
- ``RawSocketTransport``
- ``ConnectionInfo``

### Typed messages

- ``RawSocketSendMessage``
- ``RawSocketReceiveMessage``

### Proxy connections

- ``RawSocketConfiguration/Proxy``
- ``HTTPAuthorization``

### HTTP types

- ``HTTPHeaderKey``
- ``HTTPStatusCode``
