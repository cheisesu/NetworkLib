import Network
import NetworkLib

enum CallbackExample {
    static func run() async throws {
        let configuration = RawSocketConfiguration("127.0.0.1", 9000, isSecure: false, timeout: 5)
        let socket = try RawSocket(configuration)
        let result: Result<ConnectionInfo, NWError> = await withCheckedContinuation { continuation in
            socket.connect { result in
                socket.cancel {
                    continuation.resume(returning: result)
                }
            }
        }
        let info = try result.get()
        print("Connected and closed:", info.remoteEndpoint)
    }
}
