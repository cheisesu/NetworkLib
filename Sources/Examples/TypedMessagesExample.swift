import Foundation
import Network
import NetworkLib

struct TextDatagram: RawSocketSendMessage, RawSocketReceiveMessage {
    let text: String

    var context: NWConnection.ContentContext { .defaultMessage }
    var content: Data? { Data(text.utf8) }

    init(text: String) {
        self.text = text
    }

    init?(from context: NWConnection.ContentContext, with content: Data?) {
        guard let content, let text = String(data: content, encoding: .utf8) else { return nil }
        self.text = text
    }
}

enum TypedMessagesExample {
    static func run() async throws {
        ExampleCLI.log("First start the UDP echo server from --help in another terminal.")
        ExampleCLI.log("Using plaintext UDP at 127.0.0.1:9001; waiting up to 5 seconds of inactivity.")
        let configuration = RawSocketConfiguration(
            "127.0.0.1", 9001, isSecure: false, transport: .udp, timeout: 5
        )
        let socket = try RawSocket(configuration)
        do {
            try await socket.connect()
            let message = TextDatagram(text: "hello from NetworkLib UDP")
            ExampleCLI.log("Sending typed message: \(message.text)")
            try await socket.sendMessage(message)
            let reply = try await socket.receiveNextMessage(of: TextDatagram.self)
            ExampleCLI.log("Decoded reply: \(reply.text)")
            guard reply.text == message.text else {
                throw ExampleError.message("The server's reply did not match the sent message.")
            }
            await socket.cancel()
            ExampleCLI.log("Echo matched; socket closed.")
        } catch {
            await socket.cancel()
            throw error
        }
    }
}
