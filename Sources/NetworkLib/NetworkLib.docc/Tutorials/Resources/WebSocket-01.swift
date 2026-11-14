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

}
// swiftlint:enable optional_data_string_conversion
