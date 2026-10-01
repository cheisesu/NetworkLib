import Foundation
import Testing
import Network
@testable import NetworkLib

extension Tag {
    @Tag static var proxy: Tag
}

@Suite(.tags(.core, .proxy), .timeLimit(.minutes(1)))
struct ProtocolProxyFramerTests {
    @Test
    func proxy_ReturnsProtocolProxyFramer() {
        let proxyProto: any ProtocolFramerImplementation = .proxy()

        #expect(type(of: proxyProto) == ProtocolProxyFramer.self)
    }

    @Test
    func withRequiredOptions_WritesConnectRequest() throws {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer()

        framerMock[ProxyOptions.kOptionsEndpointHost] = NWEndpoint.Host("example.com")
        framerMock[ProxyOptions.kOptionsEndpointPort] = NWEndpoint.Port(integerLiteral: 443)
        framerMock[ProxyOptions.kOptionsIsSecure] = false

        let result = proxyProto.start(framer: framerMock)

        #expect(result == .willMarkReady)
        #expect(framerMock.asyncBlocks.count == 1)
        #expect(framerMock.outputs.isEmpty)
        #expect(framerMock.passThroughOutputCount == 0)

        framerMock.runNextAsyncBlock()

        try #require(framerMock.outputs.count == 1)
        let expectedOutput = """
        CONNECT example.com:443 HTTP/1.1\r
        Host: example.com:443\r
        Connection: close\r
        \r

        """
        #expect(String(data: framerMock.outputs[0], encoding: .utf8) == expectedOutput)
        #expect(framerMock.passThroughOutputCount == 1)
        #expect(framerMock.prependedProtocols.isEmpty)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withAuthorization_AddsProxyAuthorizationHeader() throws {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer()

        framerMock[ProxyOptions.kOptionsEndpointHost] = NWEndpoint.Host("example.com")
        framerMock[ProxyOptions.kOptionsEndpointPort] = NWEndpoint.Port(integerLiteral: 443)
        framerMock[ProxyOptions.kOptionsIsSecure] = false
        framerMock[ProxyOptions.kOptionsProxyAuth] = HTTPAuthorization.basic(userName: "user", password: "password")

        let result = proxyProto.start(framer: framerMock)

        #expect(result == .willMarkReady)
        #expect(framerMock.outputs.isEmpty)

        framerMock.runNextAsyncBlock()

        let output = try #require(framerMock.outputs.first)
        let request = try #require(String(data: output, encoding: .utf8))

        let expectedOutput = """
        CONNECT example.com:443 HTTP/1.1\r
        Host: example.com:443\r
        Connection: close\r
        Proxy-Authorization: Basic dXNlcjpwYXNzd29yZA==\r
        \r

        """
        #expect(request == expectedOutput)
        #expect(framerMock.passThroughOutputCount == 1)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withSecureProxy_PrependsTLSProtocol() throws {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer()

        framerMock[ProxyOptions.kOptionsEndpointHost] = NWEndpoint.Host("example.com")
        framerMock[ProxyOptions.kOptionsEndpointPort] = NWEndpoint.Port(integerLiteral: 443)
        framerMock[ProxyOptions.kOptionsIsSecure] = true

        _ = proxyProto.start(framer: framerMock)
        framerMock.runNextAsyncBlock()

        try #require(framerMock.prependedProtocols.count == 1)
        #expect(framerMock.prependedProtocols[0] is NWProtocolTLS.Options)
        #expect(framerMock.outputs.count == 1)
        #expect(framerMock.passThroughOutputCount == 1)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withAdditionalProtocols_PrependsProtocolsBeforeTLS() throws {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer()
        let firstProtocol = NWProtocolFramer.Options(definition: _MockAnyProtocol.definition)
        let secondProtocol = NWProtocolFramer.Options(definition: _MockAnyProtocol.definition)

        framerMock[ProxyOptions.kOptionsEndpointHost] = NWEndpoint.Host("example.com")
        framerMock[ProxyOptions.kOptionsEndpointPort] = NWEndpoint.Port(integerLiteral: 443)
        framerMock[ProxyOptions.kOptionsIsSecure] = true
        framerMock[ProxyOptions.kOptionsProxyTopProtocols] = [firstProtocol, secondProtocol]

        _ = proxyProto.start(framer: framerMock)
        framerMock.runNextAsyncBlock()

        try #require(framerMock.prependedProtocols.count == 3)
        #expect(framerMock.prependedProtocols[0] === firstProtocol)
        #expect(framerMock.prependedProtocols[1] === secondProtocol)
        #expect(framerMock.prependedProtocols[2] is NWProtocolTLS.Options)
        #expect(framerMock.outputs.count == 1)
        #expect(framerMock.passThroughOutputCount == 1)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withMissingHost_FailsWithEDESTADDRREQ() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer()

        framerMock[ProxyOptions.kOptionsEndpointPort] = NWEndpoint.Port(integerLiteral: 443)
        framerMock[ProxyOptions.kOptionsIsSecure] = false

        _ = proxyProto.start(framer: framerMock)
        framerMock.runNextAsyncBlock()

        #expect(framerMock.failures == [.posix(.EDESTADDRREQ)])
        #expect(framerMock.outputs.isEmpty)
        #expect(framerMock.passThroughOutputCount == 0)
    }

    @Test
    func withMissingPort_FailsWithEDESTADDRREQ() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer()

        framerMock[ProxyOptions.kOptionsEndpointHost] = NWEndpoint.Host("example.com")
        framerMock[ProxyOptions.kOptionsIsSecure] = false

        _ = proxyProto.start(framer: framerMock)
        framerMock.runNextAsyncBlock()

        #expect(framerMock.failures == [.posix(.EDESTADDRREQ)])
        #expect(framerMock.outputs.isEmpty)
        #expect(framerMock.passThroughOutputCount == 0)
    }

    @Test
    func withProtocolPrependFailure_FailsWithoutWritingRequest() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer()
        let additionalProtocol = NWProtocolFramer.Options(definition: _MockAnyProtocol.definition)

        framerMock[ProxyOptions.kOptionsEndpointHost] = NWEndpoint.Host("example.com")
        framerMock[ProxyOptions.kOptionsEndpointPort] = NWEndpoint.Port(integerLiteral: 443)
        framerMock[ProxyOptions.kOptionsIsSecure] = false
        framerMock[ProxyOptions.kOptionsProxyTopProtocols] = [additionalProtocol]
        framerMock.prependApplicationProtocolError = NWError.posix(.EINVAL)

        _ = proxyProto.start(framer: framerMock)
        framerMock.runNextAsyncBlock()

        #expect(framerMock.failures == [.posix(.EINVAL)])
        #expect(framerMock.outputs.isEmpty)
        #expect(framerMock.passThroughOutputCount == 0)
    }

    @Test
    func withTLSPrependFailure_FailsWithoutWritingRequest() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer()

        framerMock[ProxyOptions.kOptionsEndpointHost] = NWEndpoint.Host("example.com")
        framerMock[ProxyOptions.kOptionsEndpointPort] = NWEndpoint.Port(integerLiteral: 443)
        framerMock[ProxyOptions.kOptionsIsSecure] = true
        framerMock.prependApplicationProtocolError = NWError.posix(.EINVAL)

        _ = proxyProto.start(framer: framerMock)
        framerMock.runNextAsyncBlock()

        #expect(framerMock.failures == [.posix(.EINVAL)])
        #expect(framerMock.outputs.isEmpty)
        #expect(framerMock.passThroughOutputCount == 0)
    }

    @Test
    func withSuccessfulResponse_MarksReadyAndPassesThroughInput() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer(inputChunks: [
            Data("HTTP/1.1 200 Connection established\r\n\r\n".utf8)
        ])

        let result = proxyProto.handleInput(framer: framerMock)

        #expect(result == 0)
        #expect(framerMock.passThroughInputCount == 1)
        #expect(framerMock.markReadyCount == 1)
        #expect(framerMock.deliveredInputs.isEmpty)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withFragmentedResponse_MarksReadyAfterCompleteResponse() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer(inputChunks: [
            Data("HTTP/1.1 200 Connection ".utf8)
        ])

        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.passThroughInputCount == 0)
        #expect(framerMock.markReadyCount == 0)
        #expect(framerMock.failures.isEmpty)

        framerMock.appendInput(Data("established\r\n\r\n".utf8))
        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.passThroughInputCount == 1)
        #expect(framerMock.markReadyCount == 1)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withSuccessfulResponseAndLeftover_DeliversLeftover() throws {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer(inputChunks: [
            Data("HTTP/1.1 200 Connection established\r\n\r\nhello".utf8)
        ])
        framerMock.definition = .mock

        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.passThroughInputCount == 1)
        #expect(framerMock.markReadyCount == 1)
        try #require(framerMock.deliveredInputs.count == 1)

        let deliveredInput = framerMock.deliveredInputs[0]
        #expect(deliveredInput.data == Data("hello".utf8))
        #expect(deliveredInput.isComplete == false)
        #expect(deliveredInput.noCopy == false)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withCompletedResponse_DoesNotParseFurtherInput() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer(inputChunks: [
            Data("HTTP/1.1 200 Connection established\r\n\r\n".utf8)
        ])

        _ = proxyProto.handleInput(framer: framerMock)
        let parseInputCallCount = framerMock.parseInputCalls.count

        framerMock.appendInput(Data("whatever".utf8))
        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.parseInputCalls.count == parseInputCallCount)
        #expect(framerMock.passThroughInputCount == 1)
        #expect(framerMock.markReadyCount == 1)
    }

    @Test(arguments: [
        (401, POSIXErrorCode.EAUTH),
        (403, POSIXErrorCode.EACCES),
        (404, POSIXErrorCode.ENOENT),
        (407, POSIXErrorCode.EAUTH),
        (502, POSIXErrorCode.ECONNABORTED),
        (503, POSIXErrorCode.EBUSY),
        (504, POSIXErrorCode.ETIMEDOUT),
        (500, POSIXErrorCode.EPROTO)
    ])
    func withErrorStatus_FailsWithExpectedError(status: Int, errorCode: POSIXErrorCode) {
        let proxyProto = ProtocolProxyFramer()
        let response = Data("HTTP/1.1 \(status) Error\r\n\r\n".utf8)
        let framerMock = MockProtocolFramer(inputChunks: [response])

        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.failures == [.posix(errorCode)])
        #expect(framerMock.passThroughInputCount == 0)
        #expect(framerMock.markReadyCount == 0)
        #expect(framerMock.deliveredInputs.isEmpty)
    }

    @Test
    func withNoInput_DoesNothing() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer()

        let result = proxyProto.handleInput(framer: framerMock)

        #expect(result == 0)
        #expect(framerMock.parseInputCalls.count == 1)
        #expect(framerMock.passThroughInputCount == 0)
        #expect(framerMock.markReadyCount == 0)
        #expect(framerMock.deliveredInputs.isEmpty)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withInput_UsesExpectedParseInputLimits() throws {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer(inputChunks: [
            Data("HTTP/1.1 200 Connection established\r\n\r\n".utf8)
        ])

        _ = proxyProto.handleInput(framer: framerMock)

        try #require(framerMock.parseInputCalls.count == 1)
        #expect(framerMock.parseInputCalls[0].minimumIncompleteLength == 1)
        #expect(framerMock.parseInputCalls[0].maximumLength == 100)
    }

    @Test
    func withResponseLargerThanMaximumInputLength_ParsesInMultiplePasses() {
        let proxyProto = ProtocolProxyFramer()
        let header = String(repeating: "a", count: 100)
        let response = """
        HTTP/1.1 200 Connection established\r
        X-Test: \(header)\r
        \r

        """
        let framerMock = MockProtocolFramer(inputChunks: [Data(response.utf8)])

        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.parseInputCalls.count > 1)
        #expect(framerMock.passThroughInputCount == 1)
        #expect(framerMock.markReadyCount == 1)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withMultipleInputChunks_ParsesAllAvailableChunksInSingleCall() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer(inputChunks: [
            Data("HTTP/1.1 200 ".utf8),
            Data("Connection established\r\n".utf8),
            Data("Proxy-Agent: test\r\n".utf8),
            Data("\r\n".utf8)
        ])

        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.parseInputCalls.count == 4)
        #expect(framerMock.passThroughInputCount == 1)
        #expect(framerMock.markReadyCount == 1)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withErrorResponse_DoesNotParseFurtherInput() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer(inputChunks: [
            Data("HTTP/1.1 407 Proxy Authentication Required\r\n\r\n".utf8)
        ])

        _ = proxyProto.handleInput(framer: framerMock)
        let parseInputCallCount = framerMock.parseInputCalls.count

        framerMock.appendInput(Data("whatever".utf8))
        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.parseInputCalls.count == parseInputCallCount)
        #expect(framerMock.failures == [.posix(.EAUTH)])
        #expect(framerMock.passThroughInputCount == 0)
        #expect(framerMock.markReadyCount == 0)
    }

    @Test
    func withResponseSplitAcrossMultipleChunks_ParsesAllChunks() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer(inputChunks: [
            Data("HTTP/1.1 ".utf8),
            Data("200 Connection ".utf8),
            Data("established\r\n".utf8),
            Data("\r\n".utf8)
        ])

        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.parseInputCalls.count == 4)
        #expect(framerMock.passThroughInputCount == 1)
        #expect(framerMock.markReadyCount == 1)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withResponseLargerThanMaximumInputLength_ParsesResponseInMultiplePasses() {
        let proxyProto = ProtocolProxyFramer()
        let value = String(repeating: "a", count: 150)
        let response = "HTTP/1.1 200 Connection established\r\nX-Test: \(value)\r\n\r\n"
        let framerMock = MockProtocolFramer(inputChunks: [Data(response.utf8)])

        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.parseInputCalls.count > 1)
        #expect(framerMock.parseInputCalls.allSatisfy { $0.maximumLength == 100 })
        #expect(framerMock.passThroughInputCount == 1)
        #expect(framerMock.markReadyCount == 1)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withIncompleteResponse_DoesNotCompleteHandshake() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer(inputChunks: [
            Data("HTTP/1.1 200 Connection established\r\n".utf8)
        ])

        _ = proxyProto.handleInput(framer: framerMock)

        #expect(framerMock.passThroughInputCount == 0)
        #expect(framerMock.markReadyCount == 0)
        #expect(framerMock.deliveredInputs.isEmpty)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withBinaryLeftover_DeliversExactData() throws {
        let proxyProto = ProtocolProxyFramer()
        let leftover = Data([0x16, 0x03, 0x01, 0x00, 0x7A])
        var response = Data("HTTP/1.1 200 Connection established\r\n\r\n".utf8)
        response.append(leftover)

        let framerMock = MockProtocolFramer(inputChunks: [response])
        framerMock.definition = .mock

        _ = proxyProto.handleInput(framer: framerMock)

        try #require(framerMock.deliveredInputs.count == 1)
        #expect(framerMock.deliveredInputs[0].data == leftover)
        #expect(framerMock.deliveredInputs[0].isComplete == false)
        #expect(framerMock.passThroughInputCount == 1)
        #expect(framerMock.markReadyCount == 1)
        #expect(framerMock.failures.isEmpty)
    }

    @Test
    func withOutput_DoesNothing() {
        let proxyProto = ProtocolProxyFramer()
        let framerMock = MockProtocolFramer()
        framerMock.definition = _MockAnyProtocol.definition
        let message = framerMock.makeMessage()

        proxyProto.handleOutput(framer: framerMock, message: message, messageLength: 100, isComplete: true)

        #expect(framerMock.outputs.isEmpty)
        #expect(framerMock.deliveredInputs.isEmpty)
        #expect(framerMock.failures.isEmpty)
        #expect(framerMock.passThroughOutputCount == 0)
    }

    struct ProtocolProxyOptionsTests {
        @Test
        func withDefaultParameters_ConfiguresSecureProxy() throws {
            let host = NWEndpoint.Host("example.com")
            let port = NWEndpoint.Port(integerLiteral: 443)

            let options = NWProtocolFramer.Options.proxy(connectingToRemote: host, port)

            #expect(options[ProxyOptions.kOptionsEndpointHost] as? NWEndpoint.Host == host)
            #expect(options[ProxyOptions.kOptionsEndpointPort] as? NWEndpoint.Port == port)
            #expect(options[ProxyOptions.kOptionsIsSecure] as? Bool == true)
            #expect(options[ProxyOptions.kOptionsServerName] as? String == "example.com")
            #expect(options[ProxyOptions.kOptionsProxyAuth] == nil)

            let protocols = try #require(options[ProxyOptions.kOptionsProxyTopProtocols] as? [NWProtocolOptions])
            #expect(protocols.isEmpty)
        }

        @Test
        func withExplicitSNI_UsesExplicitSNI() {
            let options = NWProtocolFramer.Options.proxy(
                connectingToRemote: "example.com",
                443,
                sni: "proxy.example.com"
            )

            #expect(options[ProxyOptions.kOptionsServerName] as? String == "proxy.example.com")
        }

        @Test
        func withIPAddress_DoesNotGenerateSNI() {
            let options = NWProtocolFramer.Options.proxy(connectingToRemote: "127.0.0.1", 443)

            #expect(options[ProxyOptions.kOptionsServerName] == nil)
        }

        @Test
        func withInsecureProxy_DoesNotGenerateSNI() {
            let options = NWProtocolFramer.Options.proxy(connectingToRemote: "example.com", 80, isSecure: false)

            #expect(options[ProxyOptions.kOptionsIsSecure] as? Bool == false)
            #expect(options[ProxyOptions.kOptionsServerName] == nil)
        }

        @Test
        func withAuthorization_StoresAuthorization() {
            let authorization = HTTPAuthorization.basic(userName: "user", password: "password")
            let options = NWProtocolFramer.Options.proxy(
                connectingToRemote: "example.com",
                443,
                authorization: authorization
            )

            let storedAuthorization = options[ProxyOptions.kOptionsProxyAuth] as? HTTPAuthorization
            #expect(storedAuthorization?.httpHeader == authorization.httpHeader)
        }

        @Test
        func withAdditionalProtocols_StoresProtocols() throws {
            let firstProtocol = NWProtocolFramer.Options(definition: _MockAnyProtocol.definition)
            let secondProtocol = NWProtocolFramer.Options(definition: _MockAnyProtocol.definition)
            let options = NWProtocolFramer.Options.proxy(
                connectingToRemote: "example.com",
                443,
                additionalProtocols: [firstProtocol, secondProtocol]
            )

            let protocols = try #require(options[ProxyOptions.kOptionsProxyTopProtocols] as? [NWProtocolOptions])

            try #require(protocols.count == 2)
            #expect(protocols[0] === firstProtocol)
            #expect(protocols[1] === secondProtocol)
        }

        @Test
        func withInsecureProxyAndExplicitSNI_StoresExplicitSNI() {
            let options = NWProtocolFramer.Options.proxy(
                connectingToRemote: "example.com",
                80,
                isSecure: false,
                sni: "proxy.example.com"
            )

            #expect(options[ProxyOptions.kOptionsServerName] as? String == "proxy.example.com")
        }
    }
}
















extension ProtocolProxyFramerTests {
//    @Test(.disabled())
//    func continuationCalledOnlyOnce() async throws {
//        let timeout: TimeInterval = 0
//        let lines = [
//            "GET /v2/ip.json HTTP/1.1",
//            "Host: api.my-ip.io",
//            "Connection: close",
//            "",
//            "",
//        ]
//        let dataToSend = Data(lines.joined(separator: "\r\n").utf8)
//        let proxy = RawSocketConfiguration.Proxy(host: "<#server#>", port: 0,
//                                                 authorization: .basic(userName: "<#username#>", password: "<#userpassword#>"))
//        let config = RawSocketConfiguration("api.my-ip.io", 443, isSecure: true, proxy: proxy, transport: .tcp,
//                                            maxDataBlock: .max, timeout: timeout)
//        let socket = try RawSocket(config)
//        defer { socket.cancel(nil) }
//        try await socket.connect()
//        try await socket.send(dataToSend)
//        let received = try #require(await socket.receiveNext())
//        let str = String(data: received, encoding: .utf8) ?? "--"
//        print("==>>", str)
//
//        await socket.cancel()
//    }
}

//final class Logger: NWProtocolFramerImplementation {
//    static let definition = NWProtocolFramer.Definition(implementation: Logger.self)
//    static let label: String = "Logger"
//
//    public init(framer: NWProtocolFramer.Instance) {
//    }
//
//    public func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
//        return .ready
//    }
//
//    public func handleInput(framer: NWProtocolFramer.Instance) -> Int {
//        while true {
//            let parsed = framer.parseInput(minimumIncompleteLength: 1, maximumLength: .max) {buffer, isComplete in
//                guard let buffer, !buffer.isEmpty else { return 0 }
//                let assumedBuffer = buffer.assumingMemoryBound(to: UInt8.self)
//                let data = Data(bytes: assumedBuffer.baseAddress!, count: buffer.count)
//                let string = String(data: data, encoding: .ascii) ?? ""
//                print("==>> received", data, string)
//                framer.deliverInput(data: data, message: .init(definition: Logger.definition), isComplete: isComplete)
//
//                return buffer.count
//            }
//            if !parsed  {
//                return 0
//            }
//        }
//    }
//
//    public func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
//        var fullData = Data()
//        _ = framer.parseOutput(minimumIncompleteLength: 1, maximumLength: .max) { buffer, isComplete in
//            guard let buffer, !buffer.isEmpty else {
//                return 0
//            }
//            let assumedBuffer = buffer.assumingMemoryBound(to: UInt8.self)
//            let data = Data(bytes: assumedBuffer.baseAddress!, count: buffer.count)
//            let string = String(data: data, encoding: .ascii) ?? ""
//            print("==>> send", data, string)
//            fullData.append(data)
//            return buffer.count
//        }
//        framer.writeOutput(data: fullData)
////        try! framer.writeOutputNoCopy(length: messageLength)
//    }
//
//    public func wakeup(framer: NWProtocolFramer.Instance) {
//    }
//
//    public func stop(framer: NWProtocolFramer.Instance) -> Bool {
//        true
//    }
//
//    public func cleanup(framer: NWProtocolFramer.Instance) {
//    }
//}
