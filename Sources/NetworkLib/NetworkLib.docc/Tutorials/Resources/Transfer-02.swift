import Foundation
import Network
import NetworkLib

enum SendingAndReceivingExample {
    // Pass an interface from NWPath.availableInterfaces to require it; nil uses system selection.
    static func run(interface: NWInterface? = nil) async throws {
        print("Requires Internet access. Fetching https://example.com over TLS.")
        let configuration = RawSocketConfiguration("example.com", .https, sni: "example.com", timeout: 15, interface: interface)
        try await exchange(using: configuration)
    }

    static func exchange(using configuration: RawSocketConfiguration) async throws {
        let socket = try RawSocket(configuration)
        do {
            print("Connecting…")
            let info = try await socket.connect()
            print("Connected to \(info.remoteEndpoint)")
            let request = "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"
            print("Sending HTTP/1.1 GET /")
            try await socket.send(Data(request.utf8))
            var response = Data()
            while let block = try await socket.receiveNext() {
                print("Received \(block.count) bytes")
                guard response.count + block.count <= 1_048_576 else {
                    throw TransferError.message("Response exceeded the example's 1 MiB limit.")
                }
                response.append(block)
            }
            // Decode after collecting the bytes so UTF-8 characters may span receive blocks.
            print("--- Raw HTTP response ---")
            print(String(data: response, encoding: .utf8) ?? "<Response contains non-UTF-8 data>")
            await socket.cancel()
            print("Connection closed; received \(response.count) bytes total.")
        } catch {
            await socket.cancel()
            throw error
        }
    }
}

private enum TransferError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let text): return text
        }
    }
}
