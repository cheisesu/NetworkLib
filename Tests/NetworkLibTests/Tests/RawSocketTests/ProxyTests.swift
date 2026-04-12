import Foundation
import Testing
import Network
@testable import NetworkLib

struct ProxyTests {
    @Test
    func continuationCalledOnlyOnce() async throws {
        let timeout: TimeInterval = 0
        let lines = [
            "GET /v2/ip.json HTTP/1.1",
            "Host: api.my-ip.io",
            "Connection: close",
            "",
            "",
        ]
        let dataToSend = Data(lines.joined(separator: "\r\n").utf8)
        let proxy = RawSocketConfiguration.Proxy(host: "<#server#>", port: 0,
                                                 authorization: .basic(userName: "<#username#>", password: "<#userpassword#>"))
        let config = try RawSocketConfiguration("api.my-ip.io", 443, isSecure: true, proxy: proxy, transport: .tcp,
                                                 maxDataBlock: .max, timeout: timeout)
        let socket = try RawSocket(config)
        defer { socket.cancel(nil) }
        try await socket.connect()
        try await socket.send(dataToSend)
        let received = try #require(await socket.receiveNext())
        let str = String(data: received, encoding: .utf8) ?? "--"
        print("==>>", str)
        
        await socket.cancel()
    }
}
