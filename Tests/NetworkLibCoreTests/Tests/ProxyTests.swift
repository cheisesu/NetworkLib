import Foundation
import Testing
import Network
@testable import NetworkLibCore

struct ProxyTests {
    @Test(.disabled())
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
        let config = RawSocketConfiguration("api.my-ip.io", 443, isSecure: true, proxy: proxy, transport: .tcp,
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

final class Logger: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: Logger.self)
    static let label: String = "Logger"

    public init(framer: NWProtocolFramer.Instance) {
    }

    public func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        return .ready
    }

    public func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            let parsed = framer.parseInput(minimumIncompleteLength: 1, maximumLength: .max) {buffer, isComplete in
                guard let buffer, !buffer.isEmpty else { return 0 }
                let assumedBuffer = buffer.assumingMemoryBound(to: UInt8.self)
                let data = Data(bytes: assumedBuffer.baseAddress!, count: buffer.count)
                let string = String(data: data, encoding: .ascii) ?? ""
                print("==>> received", data, string)
                framer.deliverInput(data: data, message: .init(definition: Logger.definition), isComplete: isComplete)

                return buffer.count
            }
            if !parsed  {
                return 0
            }
        }
    }

    public func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        var fullData = Data()
        _ = framer.parseOutput(minimumIncompleteLength: 1, maximumLength: .max) { buffer, isComplete in
            guard let buffer, !buffer.isEmpty else {
                return 0
            }
            let assumedBuffer = buffer.assumingMemoryBound(to: UInt8.self)
            let data = Data(bytes: assumedBuffer.baseAddress!, count: buffer.count)
            let string = String(data: data, encoding: .ascii) ?? ""
            print("==>> send", data, string)
            fullData.append(data)
            return buffer.count
        }
        framer.writeOutput(data: fullData)
//        try! framer.writeOutputNoCopy(length: messageLength)
    }

    public func wakeup(framer: NWProtocolFramer.Instance) {
    }

    public func stop(framer: NWProtocolFramer.Instance) -> Bool {
        true
    }

    public func cleanup(framer: NWProtocolFramer.Instance) {
    }
}
