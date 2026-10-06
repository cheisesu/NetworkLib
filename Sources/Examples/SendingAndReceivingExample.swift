import Foundation
import NetworkLib

enum SendingAndReceivingExample {
    static func run() async throws {
        ExampleCLI.log("Requires Internet access. Fetching https://example.com over TLS.")
        let configuration = RawSocketConfiguration("example.com", .https, sni: "example.com", timeout: 15)
        try await exchange(using: configuration)
    }

    static func exchange(using configuration: RawSocketConfiguration) async throws {
        let socket = try RawSocket(configuration)
        do {
            ExampleCLI.log("Connecting…")
            let info = try await socket.connect()
            ExampleCLI.log("Connected to \(info.remoteEndpoint)")
            let request = "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"
            ExampleCLI.log("Sending HTTP/1.1 GET /")
            try await socket.send(Data(request.utf8))
            var response = Data()
            while let block = try await socket.receiveNext() {
                ExampleCLI.log("Received \(block.count) bytes")
                guard response.count + block.count <= 1_048_576 else {
                    throw ExampleError.message("Response exceeded the example's 1 MiB limit.")
                }
                response.append(block)
            }
            // Decode after collecting the bytes so UTF-8 characters may span receive blocks.
            print("--- Raw HTTP response ---")
            print(String(data: response, encoding: .utf8) ?? "<Response contains non-UTF-8 data>")
            await socket.cancel()
            ExampleCLI.log("Connection closed; received \(response.count) bytes total.")
        } catch {
            await socket.cancel()
            throw error
        }
    }
}
