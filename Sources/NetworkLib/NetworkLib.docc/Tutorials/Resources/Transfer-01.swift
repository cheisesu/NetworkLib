import NetworkLib

enum SendingAndReceivingExample {
    static func run() async throws {
        let configuration = RawSocketConfiguration("example.com", .https, sni: "example.com", timeout: 15)
        let socket = try RawSocket(configuration)
        do {
            let info = try await socket.connect()
            print("Connected to", info.remoteEndpoint)
            await socket.cancel()
        } catch {
            await socket.cancel()
            throw error
        }
    }
}
