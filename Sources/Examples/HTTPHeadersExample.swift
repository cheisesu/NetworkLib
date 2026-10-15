import Foundation
import NetworkLib

enum HTTPHeadersExample {
    static func run() throws {
        ExampleCLI.log("Building a URLRequest locally. No network connection is made.")
        guard let url = URL(string: "https://example.com") else {
            throw ExampleError.message("Could not create the example URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: .accept)
        request.setValue("NetworkLibExample", forHTTPHeaderField: .userAgent)
        let requestIDHeader = HTTPHeaderKey("X-Request-ID")
        request.setValue("example-001", forHTTPHeaderField: requestIDHeader)
        ExampleCLI.log("Request: GET \(url.absoluteString)")
        for (key, value) in (request.allHTTPHeaderFields ?? [:]).sorted(by: { $0.key < $1.key }) {
            print("  \(key): \(value)")
        }
        let headers = request.allHTTPHeaders ?? [:]
        ExampleCLI.log("Request headers converted with rawFields:")
        for (key, value) in headers.rawFields.sorted(by: { $0.key < $1.key }) {
            print("  \(key): \(value)")
        }
    }
}
