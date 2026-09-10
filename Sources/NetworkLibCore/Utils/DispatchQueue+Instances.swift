import Foundation

extension DispatchQueue {
    enum RawSocket: Sendable {
        static var access: DispatchQueue { .init(label: .queueId(with: .rawSocket)) }
        static var delegate: DispatchQueue { .init(label: .queueId(with: .rawSocket, .delegate)) }
    }
    enum HTTPTask: Sendable {
        static var access: DispatchQueue { .init(label: .queueId(with: .httpTask)) }
        static var delegate: DispatchQueue { .init(label: .queueId(with: .httpTask, .delegate)) }
    }
}

private extension String {
    static func queueId(with suffixItems: String...) -> String {
        let items = ["com.network_lib"] + suffixItems
        return items.filter { !$0.isEmpty }.joined(separator: ".")
    }

    static let rawSocket = "raw_socket"
    static let httpTask = "http_task"
    static let delegate = "delegate"
}
