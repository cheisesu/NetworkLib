import Foundation
import Network
@testable import NetworkLib

private func loadIdentityFromP12() throws -> SecIdentity {
    guard let url = Bundle.module.url(forResource: "localhost", withExtension: "p12") else {
        throw NSError(domain: "TLS", code: 1, userInfo: [NSLocalizedDescriptionKey: "p12 not found"])
    }
    let data = try Data(contentsOf: url)
    let options = [kSecImportExportPassphrase: "localhost"] as NSDictionary
    var items: CFArray?
    let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
    guard status == errSecSuccess, let array = items as? [[String: Any]], let first = array.first else {
        throw NSError(domain: "TLS", code: 2, userInfo: [NSLocalizedDescriptionKey: "SecPKCS12Import failed: \(status)"])
    }
    let identity = first[kSecImportItemIdentity as String] as CFTypeRef?
    guard let identity, CFGetTypeID(identity) == SecIdentityGetTypeID() else {
        throw NSError(domain: "TLS", code: 3, userInfo: [NSLocalizedDescriptionKey: "SecPKCS12Import failed to get identity"])
    }
    return identity as! SecIdentity
}

final class HTTPServerMock: @unchecked Sendable {
    enum Flow: Sendable {
        case none
        case echo(Data)
    }
    private struct ConnectionInfo: Sendable {
        let connection: NWConnection
        var receivedData: Data
    }
    private let listener: NWListener
    private let queue: DispatchQueue
    private let flow: Flow
    private var connection: NWConnection?

    init(isSecure: Bool, flow: Flow) throws {
        let secIdentity = try loadIdentityFromP12()
        let queue = DispatchQueue(label: "com.network.lib.http-server-mock", target: .global())
        self.queue = queue
        self.flow = flow
        connection = nil
        let tls: NWProtocolTLS.Options? = {
            guard isSecure else { return nil }
            let tls = NWProtocolTLS.Options()
            if let identity = sec_identity_create(secIdentity) {
                sec_protocol_options_set_local_identity(tls.securityProtocolOptions, identity)
            }
            return tls
        }()
        let tcp = NWProtocolTCP.Options()
        let params = NWParameters(tls: tls, tcp: tcp)
        listener = try NWListener(using: params, on: .any)
        listener.newConnectionHandler = { [weak self] newConnection in
            self?.handleNewConnection(newConnection)
        }
    }

    func start() async throws -> NWEndpoint.Port {
        try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { newState in
                printDebug("[server] new state", newState)
                switch newState {
                case let .failed(error), let .waiting(error): continuation.resume(throwing: error)
                case .ready:
                    if let port = self.listener.port {
                        continuation.resume(returning: port)
                    } else {
                        continuation.resume(throwing: NWError.posix(.EINVAL))
                    }
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }

    func stop() {
        listener.cancel()
        queue.async { [weak self] in
            self?.connection?.cancel()
            self?.connection = nil
        }
    }

    func forceStop() {
        listener.cancel()
        queue.async { [weak self] in
            self?.connection?.forceCancel()
            self?.connection = nil
        }
    }

    func receiveNext() async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            let connection = self.connection!
            connection.receive(minimumIncompleteLength: 1, maximumLength: .max) { [weak self, flow] content, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    switch flow {
                    case .none: break
                    case .echo(let data):
                        self?.sendToConnection(data, connection: connection)
                    }
                    continuation.resume(returning: content)
                }
            }
        }
    }

    private func sendToConnection(_ data: Data?, connection: NWConnection) {
        connection.send(content: data, isComplete: true, completion: .contentProcessed({ error in
            printDebug("[server_connection] sent data", data, error)
        }))
    }

    private func handleNewConnection(_ newConnection: NWConnection) {
        printDebug("[server_connection] handle new", newConnection)
        self.connection = newConnection
        newConnection.stateUpdateHandler = { state in
            printDebug("[server_connection] new state", state)
            switch state {
            case .failed, .waiting: newConnection.cancel()
            case .ready: break
            case .cancelled: break
            default: break
            }
        }
        newConnection.start(queue: DispatchQueue(label: "com.network.lib.server-mock.connection", qos: .background, target: .global()))
    }
}
