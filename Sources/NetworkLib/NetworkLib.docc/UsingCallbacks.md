# Using Completion Handlers

Connect and send data using the callback-based socket API.

## Overview

``RawSocket`` provides completion handlers alongside its asynchronous methods. This example sends a payload to a local TCP service and closes the connection once the send completes.

### Send to a local service

Run a TCP service listening on port 9000 before calling this function. The service must accept the example's UTF-8 payload.

```swift
import Foundation
import Network
import NetworkLib

func sendWithCallbacks(
    completion: @escaping @Sendable (Result<Void, NWError>) -> Void
) throws -> RawSocket {
    let configuration = RawSocketConfiguration(
        "127.0.0.1",
        9000,
        isSecure: false,
        timeout: 10
    )
    let socket = try RawSocket(configuration)

    socket.connect { result in
        switch result {
        case .success:
            socket.send(Data("hello\n".utf8)) { sendResult in
                socket.cancel {
                    completion(sendResult)
                }
            }
        case .failure(let error):
            socket.cancel {
                completion(.failure(error))
            }
        }
    }
    return socket
}
```

Retain the returned socket while the operation is in progress. You can call `socket.cancel(nil)` to stop it early. A successful send means that the connection processed the bytes; it doesn't confirm that the server processed the application message.

### Choose a callback queue

The initializer accepts a `delegateQueue` argument. Without it, callbacks run on NetworkLib's shared socket delegate queue. Completion handlers are `@Sendable`; synchronize any shared mutable state and use an explicit actor hop before updating actor-isolated UI state.

The example disables TLS for its local plaintext service. Use `isSecure: true` when connecting to a TLS-enabled server.

## See Also

- <doc:SendingAndReceiving>
