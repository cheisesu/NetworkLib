# Working with HTTP Headers

Use typed header keys with Foundation requests.

## Overview

``HTTPHeaderKey`` provides standard header names and supports custom keys. NetworkLib extends `URLRequest` with methods that accept these keys.

### Create a request

```swift
import Foundation
import NetworkLib

func makeRequest(url: URL, requestID: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: .accept)
    request.setValue("NetworkLibExample", forHTTPHeaderField: .userAgent)

    let requestIDHeader = HTTPHeaderKey("X-Request-ID")
    request.setValue(requestID, forHTTPHeaderField: requestIDHeader)
    return request
}
```

Pass the resulting request to your Foundation networking code. These helpers configure headers; they don't send the request or serialize it for ``RawSocket``.

### Convert a typed header dictionary

Read the same request through `allHTTPHeaders`, then convert its typed keys back to strings. This preserves all headers, including `X-Request-ID`.

```swift
import Foundation
import NetworkLib

func rawHeaders(for request: URLRequest) -> [String: String] {
    let headers = request.allHTTPHeaders ?? [:]
    return headers.rawFields
}
```

Use `rawFields` with APIs that expect string keys. Direct `HTTPHeaderKey` equality and dictionary hashing preserve exact spelling, so differently capitalized keys remain distinct in a Swift dictionary even though HTTP field names are case-insensitive on the wire.

### Run the CLI example

From a local checkout of NetworkLib, run this command in the directory containing `Package.swift`:

```sh
swift run Examples headers
```

No server or network connection is needed. The CLI prints the request's headers before and after conversion through `allHTTPHeaders` and `rawFields`. Both outputs include the same three headers.

The runnable implementation is in `Sources/Examples/HTTPHeadersExample.swift`. See <doc:RunningExamples> for tool requirements, the complete command list, and shared CLI behavior.

## See Also

- <doc:SendingAndReceiving>
