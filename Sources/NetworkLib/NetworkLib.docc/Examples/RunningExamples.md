# Running the Examples

Run the documented API examples from the terminal using the repository's Examples target.

## Overview

Use a local checkout of NetworkLib on macOS with a Swift 6 toolchain. Run commands from the repository root, alongside `Package.swift`. The package's build plugin currently expects SwiftLint at `/opt/homebrew/bin/swiftlint`.

The existing `Examples` executable target contains all six examples. Adding NetworkLib as a library dependency to another project doesn't copy these example sources into that project.

### List available examples

```sh
swift run Examples
```

With no arguments, the CLI displays the available example types and their setup instructions. Use `swift run Examples --help` or `swift run Examples -h` to display the same help.

### Choose an example

| Command | Guide | Source file under Sources/Examples |
| --- | --- | --- |
| `swift run Examples async` | <doc:SendingAndReceiving> | `SendingAndReceivingExample.swift` |
| `swift run Examples callbacks` | <doc:UsingCallbacks> | `CallbackExample.swift` |
| `swift run Examples proxy` | <doc:UsingProxies> | `ProxyExample.swift` |
| `swift run Examples udp` | <doc:TypedMessages> | `TypedMessagesExample.swift` |
| `swift run Examples websocket` | <doc:UsingWebSockets> | `WebSocketExample.swift` |
| `swift run Examples headers` | <doc:HTTPHeaders> | `HTTPHeadersExample.swift` |

Start with `headers` for an example that needs no network connection. The `async` and `websocket` examples need Internet access. The WebSocket example also needs an interactive terminal; type `exit` to close the connection. The `callbacks` and `udp` examples need local servers, and `proxy` needs an HTTP CONNECT proxy. Each guide includes setup instructions.

### Choose a network interface in code

Each network example exposes `run(interface: NWInterface? = nil)`. Existing CLI commands call `run()` and let the system select the interface. To require a specific interface when adapting an example, pass an `NWInterface` obtained from a path update:

```swift
import Network

func fetchExample(using path: NWPath, interfaceName: String) async throws {
    guard let interface = path.availableInterfaces.first(where: { $0.name == interfaceName }) else {
        throw NWError.posix(.ENODEV)
    }
    try await SendingAndReceivingExample.run(interface: interface)
}
```

Call this helper with a path delivered by your path monitor and an interface name chosen from that path. This helper belongs alongside the example sources; it is not a NetworkLib library API. The requirement does not fall back to another interface. For the localhost callback and UDP examples, leave the argument nil or choose a suitable loopback interface. Proxy examples apply the requirement locally and preserve it through `using(proxy:)`.

See <doc:ConfigureASocket> for configuration snapshots. The CLI does not accept an interface-name argument.

### Read the output

The CLI logs progress with an `[example]` prefix, prints results, and reports successful completion. The WebSocket example sends a normal close message when you type `exit`, waits for the peer's close reply, then cancels its socket. See <doc:UsingWebSockets> for its timeout and interactive-input behavior.

Errors are written to standard error with an `[error]` prefix, and the process exits with status `1`. Successful runs and help exit with status `0`. Unknown example names and extra arguments to an example are rejected.

The dispatcher is in `Sources/Examples/main.swift`; shared help and logging are in `Sources/Examples/ExampleCLI.swift`. The runnable examples include additional logging and result checks beyond the focused snippets in these guides.

## See Also

- <doc:Installation>
