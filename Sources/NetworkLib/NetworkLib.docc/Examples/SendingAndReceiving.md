# Sending and Receiving Data

Connect securely, send bytes, and read a response with async/await.

## Overview

This example uses ``RawSocket`` to send an HTTP/1.1 request over TLS. It prints the raw response, including HTTP headers, rather than decoding an HTTP response object.

### Exchange bytes over TLS

```swift
import Foundation
import NetworkLib

func fetchExample() async throws {
    let configuration = RawSocketConfiguration(
        "example.com",
        .https,
        isSecure: true,
        sni: "example.com",
        timeout: 15
    )
    let socket = try RawSocket(configuration)

    do {
        let info = try await socket.connect()
        print("Connected to", info.remoteEndpoint)

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

Call `try await fetchExample()` from an asynchronous context. The request asks the server to close the connection after the response, so the loop ends when `receiveNext()` returns `nil`.

TCP is a byte stream. A receive block can contain part of a message or several messages, and even a UTF-8 character can span blocks. The printing above is intended for inspecting this example's response; a real protocol implementation should buffer and decode according to its framing rules.

### Handle timeouts and cancellation

The configuration's `timeout` is an inactivity timeout in seconds, not a total request deadline. Socket failures are reported as `NWError`, including `NWError.posix(.ETIMEDOUT)` when the timeout expires.

Cancelling a task waiting on a socket's asynchronous connect, send, or receive operation permanently cancels the socket. Cancellation is reported through `NWError`, rather than necessarily as `CancellationError`. Both success and failure paths above await cleanup. Create a new socket for another connection.

### Run the CLI example

From a local checkout of NetworkLib, run this command in the directory containing `Package.swift`:

```sh
swift run Examples async
```

Requires Internet access. The CLI logs each receive block, then prints the collected raw HTTP response and closes the socket.

The runnable implementation is in `Sources/Examples/SendingAndReceivingExample.swift`. See <doc:RunningExamples> for tool requirements, the complete command list, and shared CLI behavior.

## See Also

- <doc:UsingCallbacks>
- <doc:UsingProxies>
