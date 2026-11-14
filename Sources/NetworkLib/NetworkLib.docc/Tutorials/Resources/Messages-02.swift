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
    // Pass an interface from NWPath.availableInterfaces to require it; nil uses system selection.
    static func run(interface: NWInterface? = nil) async throws {
        print("First start the UDP echo server shown in the typed-message guide in another terminal.")
        print("Using plaintext UDP at 127.0.0.1:9001; waiting up to 5 seconds of inactivity.")
        let configuration = RawSocketConfiguration(
            "127.0.0.1", 9001, isSecure: false, transport: .udp, timeout: 5, interface: interface
        )
        let socket = try RawSocket(configuration)
        do {
            try await socket.connect()
            let message = TextDatagram(text: "hello from NetworkLib UDP")
            print("Sending typed message: \(message.text)")
            try await socket.sendMessage(message)
            let reply = try await socket.receiveNextMessage(of: TextDatagram.self)
            print("Decoded reply: \(reply.text)")
            guard reply.text == message.text else {
                throw DatagramError.message("The server's reply did not match the sent message.")
            }
            await socket.cancel()
            print("Echo matched; socket closed.")
        } catch {
            await socket.cancel()
            throw error
        }
    }
}

private enum DatagramError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let text): return text
        }
    }
}
