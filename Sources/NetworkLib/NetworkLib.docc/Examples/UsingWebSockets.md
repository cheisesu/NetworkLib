# Exchanging WebSocket Messages

Send interactive text messages over TLS using Network framework WebSocket framing.

## Overview

The runnable example in `Sources/Examples/WebSocketExample.swift` combines ``RawSocketConfiguration`` with `NWProtocolWebSocket.Options`. Separate types conform to ``RawSocketSendMessage`` and ``RawSocketReceiveMessage`` to attach outgoing metadata and inspect incoming opcodes.

### Run the CLI example

From the repository root in an interactive terminal, run:

```sh
swift run Examples websocket
```

The example connects to `echo.websocket.org` on port `443` with TLS. Internet access is required; no local server or environment variables are needed. See <doc:RunningExamples> for build requirements.

After connecting, the example receives and discards one initial server message before showing the input prompt. At `>`, type text and press Return. Received payloads appear after `<`. Type `exit` to send a normal WebSocket close message; the comparison ignores case and surrounding whitespace. On the normal completion path, the receive loop waits for the peer's close message, the socket is cancelled, and the CLI reports completion.

### Configure the protocol

Inside the example's asynchronous `run()` method:

```swift
let proto = NWProtocolWebSocket.Options()
proto.autoReplyPing = true
let configuration = RawSocketConfiguration(
    "echo.websocket.org",
    443,
    isSecure: true,
    timeout: 0,
    additionalProtocols: [proto]
)
let socket = try RawSocket(configuration)
try await socket.connect()
```

The default transport is TCP. Passing WebSocket options through `additionalProtocols` installs the application protocol that supplies message framing. TLS secures the connection. Setting `autoReplyPing` makes the Network framework reply to incoming Ping messages automatically.

The example uses `timeout: 0` to disable NetworkLib's inactivity timeout while waiting for terminal input. This also means the initial receive and close reply can wait indefinitely. Use Control-C to stop a stalled session. If you adapt the example to another server, revisit its initial-message assumption and choose a timeout appropriate to your application.

### Attach outgoing metadata

The example's `WSSendMessage` stores payload bytes and a content context. Its text initializer uses UTF-8 and a `.text` opcode:

```swift
init(text: String) {
    content = Data(text.utf8)
    let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
    context = NWConnection.ContentContext(
        identifier: "textContext",
        metadata: [metadata]
    )
}
```

Its general initializer accepts an opcode and optional content. For `.close`, it sets `metadata.closeCode = .protocolCode(.normalClosure)`. The static `close` value uses that initializer with no payload. The send loop calls `socket.sendMessage(WSSendMessage(text: input))` for text and `socket.sendMessage(WSSendMessage.close)` for `exit`.

### Inspect incoming metadata

The receive type extracts WebSocket metadata from the supplied content context:

```swift
init?(from context: NWConnection.ContentContext, with content: Data?) {
    let proto = context.protocolMetadata(
        definition: NWProtocolWebSocket.definition
    ) as? NWProtocolWebSocket.Metadata
    guard let proto else { return nil }
    code = proto.opcode
    self.content = content
}
```

The receive loop calls `socket.receiveNextMessage(of: WSReceiveMessage.self)`, checks for `.close`, and otherwise prints the payload as UTF-8. This is a text echo demonstration: its display helper decodes any received payload as text and returns an empty string for absent content. Applications that handle binary messages should branch on the opcode and process the original `Data`.

### Understand the interactive lifetime

A throwing task group runs the terminal send loop and socket receive loop concurrently. The normal path waits for both tasks, then calls `await socket.cancel()`. The deferred `Disconnected.` message is a log statement, not a cleanup operation.

The CLI uses blocking `readLine()` and treats end-of-input as an empty string, so run it interactively and finish with `exit`; redirected input and EOF are not shutdown mechanisms. When adapting it for an app, provide cancellable input handling and explicit cleanup on error as shown in <doc:SendingAndReceiving>.

## See Also

- <doc:ExchangeWebSocketMessages>
- <doc:TypedMessages>
- <doc:RunningExamples>
