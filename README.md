# NetworkLib

**NetworkLib** is a Swift networking library built on Apple's Network framework. It provides a configurable socket API for exchanging raw bytes and protocol-framed messages, with both Swift concurrency and completion-handler interfaces.

NetworkLib is designed for applications that need direct control over transport, connection security, proxy routing, and application-level protocols. It is a low-level networking library, not a high-level HTTP client.

## Features

- **TCP and UDP** connections through a unified `RawSocket` API.
- **TLS and DTLS** support, including configurable Server Name Indication (SNI).
- **Async/await and callbacks** for connecting, sending, receiving, and cancelling.
- **Raw data and typed messages** using custom message protocols and Network framework content contexts.
- **HTTP CONNECT proxies**, with optional Basic authentication and independent TLS settings for the proxy and destination.
- **Connection configuration** for IP version preferences, inactivity timeouts, receive block sizes, and additional application protocols.
- **HTTP utilities** for header names, status codes, and authorization, plus helpers for addresses, hosts, and URLs.

## Requirements

- Swift 6
- iOS 13.0+, tvOS 13.0+, or macOS 10.15+
- HTTP CONNECT proxy support: iOS/tvOS 15.4+ or macOS 12.3+

NetworkLib uses Apple's Network framework and does not currently target Linux.

## Quick start

This example opens a TLS connection, sends a raw HTTP/1.1 request, and reads the response as bytes:

```swift
import Foundation
import NetworkLib

func fetchExample() async throws {
    let configuration = RawSocketConfiguration(
        "example.com",
        .https,
        isSecure: true,
        sni: "example.com"
    )
    let socket = try RawSocket(configuration)

    do {
        try await socket.connect()

        let request = "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"
        try await socket.send(Data(request.utf8))

        while let data = try await socket.receiveNext() {
            print(String(decoding: data, as: UTF8.self), terminator: "")
        }

        await socket.cancel()
    } catch {
        await socket.cancel()
        throw error
    }
}
```

`receiveNext()` returns the next available block of bytes, not necessarily a complete application-level message. TCP applications should implement their own message framing or configure an appropriate Network framework application protocol.

A socket represents a single connection attempt and cannot be reused after cancellation. Cancelling a task that is awaiting a socket operation also cancels the socket.

## Build and run examples

Clone the repository and switch to the `develop` branch:

```sh
git clone https://github.com/cheisesu/NetworkLib.git
cd NetworkLib
git switch develop
swift build
swift test
```

The package currently uses a build-tool plugin that expects SwiftLint at `/opt/homebrew/bin/swiftlint`. Install SwiftLint at that path before building.

The included `Examples` executable demonstrates the public API:

```sh
swift run Examples           # Show available examples
swift run Examples headers   # Work with HTTP headers
swift run Examples async     # Send and receive raw bytes over TLS
swift run Examples callbacks # Use completion handlers
swift run Examples udp       # Exchange typed UDP datagrams
swift run Examples proxy     # Connect through an HTTP CONNECT proxy
```

Some examples require a local server, Internet access, or proxy credentials. See [Running the Examples](Sources/NetworkLib/NetworkLib.docc/Examples/RunningExamples.md) for setup instructions.

> **Package integration status:** The current `develop` manifest uses an unsafe compiler flag (`-warnings-as-errors`) and a machine-specific SwiftLint plugin path. These need to be addressed before the library can be reliably consumed as a versioned Swift Package Manager dependency. See the [installation guide](Sources/NetworkLib/NetworkLib.docc/Installation.md) for details.

## Documentation

- [Overview and API topics](Sources/NetworkLib/NetworkLib.docc/NetworkLib.md)
- [Installation](Sources/NetworkLib/NetworkLib.docc/Installation.md)
- [Sending and receiving data](Sources/NetworkLib/NetworkLib.docc/Examples/SendingAndReceiving.md)
- [Using completion handlers](Sources/NetworkLib/NetworkLib.docc/Examples/UsingCallbacks.md)
- [Typed messages](Sources/NetworkLib/NetworkLib.docc/Examples/TypedMessages.md)
- [Connecting through a proxy](Sources/NetworkLib/NetworkLib.docc/Examples/UsingProxies.md)

Full API reference and guided tutorials are maintained in the package's [DocC catalog](Sources/NetworkLib/NetworkLib.docc).

## License

NetworkLib is distributed under the [MIT License](LICENSE).
