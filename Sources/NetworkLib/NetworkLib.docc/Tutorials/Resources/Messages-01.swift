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
