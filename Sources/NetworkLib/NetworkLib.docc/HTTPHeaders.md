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

```swift
import Foundation
import NetworkLib

let headers: [HTTPHeaderKey: String] = [
    .accept: "application/json",
    .userAgent: "NetworkLibExample"
]
let rawHeaders: [String: String] = headers.rawFields
```

Use `rawFields` with APIs that expect string keys. Direct `HTTPHeaderKey` equality and dictionary hashing preserve exact spelling, so differently capitalized keys remain distinct in a Swift dictionary even though HTTP field names are case-insensitive on the wire.

## See Also

- <doc:SendingAndReceiving>
