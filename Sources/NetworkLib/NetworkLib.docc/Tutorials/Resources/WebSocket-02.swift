import Foundation
import Network
import NetworkLib

// swiftlint:disable optional_data_string_conversion
enum WebSocketExample {
    private struct WSReceiveMessage: RawSocketReceiveMessage {
        let code: NWProtocolWebSocket.Opcode
        let content: Data?
        var text: String {
            if let content {
                String(decoding: content, as: UTF8.self)
            } else {
                ""
            }
        }
        init?(from context: NWConnection.ContentContext, with content: Data?) {
            let proto = context.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
            guard let proto else { return nil }
            code = proto.opcode
            self.content = content
        }
    }

    private struct WSSendMessage: RawSocketSendMessage {
        static let close = WSSendMessage(opcode: .close, content: nil)
        let content: Data?
        let context: NWConnection.ContentContext

        init(text: String) {
            content = Data(text.utf8)
            let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
            context = NWConnection.ContentContext(identifier: "textContext", metadata: [metadata])
        }

        init(opcode: NWProtocolWebSocket.Opcode, content: Data?) {
            self.content = content
            let metadata = NWProtocolWebSocket.Metadata(opcode: opcode)
            if opcode == .close {
                metadata.closeCode = .protocolCode(.normalClosure)
            }
            context = NWConnection.ContentContext(identifier: "generalContext", metadata: [metadata])
        }
    }

    static func run() async throws {
        ExampleCLI.log("Example of echo WebSocket.")
        let proto = NWProtocolWebSocket.Options()
        proto.autoReplyPing = true
        let configuration = RawSocketConfiguration("echo.websocket.org", 443, isSecure: true, timeout: 0,
                                                   additionalProtocols: [proto])
        let socket = try RawSocket(configuration)
        ExampleCLI.log("Connecting.")
        try await socket.connect()
        defer { ExampleCLI.log("Disconnected.") }
        ExampleCLI.log("Connected.")
        _ = try await socket.receiveNextMessage(of: WSReceiveMessage.self)
        ExampleCLI.log("Type `exit` to close connection.")

        try await withThrowingTaskGroup { group in
            group.addTask(name: "send_events") {
                repeat {
                    print(">", terminator: "")
                    let input = readLine() ?? ""
                    if input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "exit" {
                        try await socket.sendMessage(WSSendMessage.close)
                        break
                    }
                    let message = WSSendMessage(text: input)
                    try await socket.sendMessage(message)
                } while true
            }

            group.addTask(name: "receive_events") {
                repeat {
                    let message = try await socket.receiveNextMessage(of: WSReceiveMessage.self)
                    if message.code == .close {
                        break
                    }
                    print("<", message.text)
                } while true
            }
            try await group.waitForAll()
            await socket.cancel()
        }
    }
}
// swiftlint:enable optional_data_string_conversion
