# Exchanging Typed UDP Messages

Represent a UTF-8 datagram with the socket's message protocols.

## Overview

Conform a value type to ``RawSocketSendMessage`` and ``RawSocketReceiveMessage`` to encode and decode messages. UDP preserves datagram boundaries, making it suitable for this small example without a custom application framer.

### Define the message

```swift
import Foundation
import Network
import NetworkLib

struct TextDatagram: RawSocketSendMessage, RawSocketReceiveMessage {
    let text: String

    var context: NWConnection.ContentContext {
        .defaultMessage
    }

    var content: Data? {
        Data(text.utf8)
    }

    init(text: String) {
        self.text = text
    }

    init?(from context: NWConnection.ContentContext, with content: Data?) {
        guard let content, let text = String(data: content, encoding: .utf8) else {
            return nil
        }
        self.text = text
    }
}
```

The computed content context avoids storing framework metadata in the value. Returning `nil` from the decoding initializer rejects a message; the receive operation then reports `NWError.posix(.EBADMSG)`.

### Send and receive a datagram

Place this function alongside `TextDatagram`. Run a local UDP echo service on port 9001 that returns each received datagram unchanged.

```swift
func exchangeDatagram() async throws -> String {
    let configuration = RawSocketConfiguration(
        "127.0.0.1",
        9001,
        isSecure: false,
        transport: .udp,
        timeout: 5
    )
    let socket = try RawSocket(configuration)

    do {
        try await socket.connect()
        try await socket.sendMessage(TextDatagram(text: "hello"))
        let reply = try await socket.receiveNextMessage(of: TextDatagram.self)
        await socket.cancel()
        return reply.text
    } catch {
        await socket.cancel()
        throw error
    }
}
```

UDP doesn't guarantee delivery or ordering. A successful connect doesn't establish that an echo service is listening; a missing reply can result in an error or timeout. This local example uses plaintext UDP. A DTLS-enabled service requires `isSecure: true`.

These protocols don't add framing to a TCP byte stream. For typed messages over TCP, install a suitable Network framework application protocol through the configuration's `additionalProtocols` and supply the metadata that protocol expects.

## See Also

- <doc:SendingAndReceiving>
