import Foundation
import Network
import NetworkLib

enum CallbackExample {
    static func run() async throws {
        ExampleCLI.log("First run 'nc -l 9000' in another terminal. It will display the payload.")
        let configuration = RawSocketConfiguration("127.0.0.1", 9000, isSecure: false, timeout: 5)
        let socket = try RawSocket(configuration)
        // Keep the CLI alive until the callback chain and socket cleanup have finished.
        let result: Result<Void, NWError> = await withCheckedContinuation { continuation in
            ExampleCLI.log("Connecting to plaintext TCP at 127.0.0.1:9000…")
            socket.connect { result in
                switch result {
                case .success(let info):
                    ExampleCLI.log("Connected to \(info.remoteEndpoint); sending hello.")
                    socket.send(Data("hello from NetworkLib callbacks\n".utf8)) { sendResult in
                        socket.cancel {
                            continuation.resume(returning: sendResult)
                        }
                    }
                case .failure(let error):
                    socket.cancel {
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
        try result.get()
        ExampleCLI.log("Send processed and socket closed. Check the listener terminal for the payload.")
    }
}
