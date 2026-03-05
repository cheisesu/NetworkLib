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

final class ServerMock: @unchecked Sendable {
    enum Flow: Sendable {
        case none
        case echo
        case cancel
        case acceptAndCancel
        case waitConnect
    }
    private let listener: NWListener
    private let queue: DispatchQueue
    private let flow: Flow
    private var connections: [UUID: NWConnection]

    init(transport: NetTransport, isSecure: Bool, flow: Flow = .none) throws {
        let secIdentity = try loadIdentityFromP12()
        let queue = DispatchQueue(label: "com.network.lib.server-mock", target: .global())
        self.queue = queue
        self.flow = flow
        connections = [:]
        let tls: NWProtocolTLS.Options? = {
            guard isSecure else { return nil }
            let tls = NWProtocolTLS.Options()
            if let identity = sec_identity_create(secIdentity) {
                sec_protocol_options_set_local_identity(tls.securityProtocolOptions, identity)
            }
//            let secIdentity = sec_identity_create(secIdentity)
//            sec_protocol_options_set_challenge_block(tls.securityProtocolOptions, { meta, completion in
//                let sni = sec_protocol_metadata_copy_server_name(meta).map { String(cString: $0) }
//                if sni == "localhost" {
//                    completion(secIdentity)
//                } else {
//                    completion(nil)
//                }
//            }, queue)
            return tls
        }()
        let params = {
            switch transport {
            case .tcp:
                let tcp = NWProtocolTCP.Options()
                return NWParameters(tls: tls, tcp: tcp)
            case .udp:
                let udp = NWProtocolUDP.Options()
                return NWParameters(dtls: tls, udp: udp)
            }
        }()
        listener = try NWListener(using: params, on: .any)
        listener.newConnectionHandler = { [weak self] newConnection in
            self?.handleNewConnection(newConnection)
        }
    }

    func start() async throws -> NWEndpoint.Port {
        try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { newState in
                print("[server] new state", newState)
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
            let connections = self?.connections ?? [:]
            for (_, conn) in connections {
                conn.cancel()
            }
        }
    }

    func forceStop() {
        listener.cancel()
        queue.async { [weak self] in
            let connections = self?.connections ?? [:]
            for (_, conn) in connections {
                conn.forceCancel()
            }
        }
    }

    private func handleNewConnection(_ newConnection: NWConnection) {
        if flow == .cancel {
            newConnection.cancel()
            return
        }
        let id = UUID()
        connections[id] = newConnection
        newConnection.stateUpdateHandler = { [flow, weak self] state in
            print("[server_connection] new state", state)
            switch state {
            case .failed, .waiting: newConnection.cancel()
            case .ready:
                switch flow {
                case .none: break
                case .echo: self?.echoReceiveCycle(for: newConnection)
                case .cancel: break
                case .acceptAndCancel: break
                case .waitConnect: break
                }
            case .cancelled:
                self?.queue.async { [weak self] in
                    self?.connections[id] = nil
                }
            default: break
            }
        }
        if flow == .waitConnect {
            Thread.sleep(forTimeInterval: 0.5)
        }
        newConnection.start(queue: DispatchQueue(label: "com.network.lib.server-mock.connection", qos: .background, target: .global()))
        if flow == .acceptAndCancel {
            newConnection.cancel()
        }
    }

    private func echoReceiveCycle(for connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: .max) { [weak self] content, contentContext, isComplete, error in
            if let content {
                print("[server_connection] received content", content)
                connection.send(content: content, completion: .contentProcessed({
                    print("[server_connection] sent echo", content, $0)
                }))
                self?.echoReceiveCycle(for: connection)
            } else if let error {
                print("[server_connection] received error", error)
                connection.cancel()
            } else if isComplete {
                print("[server_connection] completed")
            } else {
                assertionFailure("Undefined behaviour")
            }
        }
    }
}
