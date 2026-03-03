import XCTest
import Network
@testable import NetworkLib

class RawSocketTests_TCP_Cancel: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func test_MultipleCancelsWithCallbacks_WillTriggerAllCallbacksInOrder() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let cancel1Expect = expectation(description: "Cancel callback 1 called")
        let cancel2Expect = expectation(description: "Cancel callback 2 called")
        socket.connect { info, error in
            socket.cancel {
                cancel1Expect.fulfill()
            }
            socket.cancel {
                cancel2Expect.fulfill()
            }
        }
        await fulfillment(of: [cancel1Expect, cancel2Expect], timeout: 3, enforceOrder: true)
    }
    
    func test_CancelsWithAndWithoutCallback_WillTriggerCallback() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let cancelsExpect = expectation(description: "Cancel callbacks called")
        socket.connect { info, error in
            socket.cancel()
            socket.cancel {
                cancelsExpect.fulfill()
            }
            socket.cancel()
        }
        await fulfillment(of: [cancelsExpect], timeout: 3, enforceOrder: true)
    }
    
    func test_Cancels_DuringConnect_CallbackReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true, flow: .waitConnect)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let cancelsExpect = expectation(description: "Cancel callbacks called")
        socket.connect { _, error in
            XCTAssertNotNil(error)
            guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
            guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
            XCTAssertEqual(code, .ECANCELED)
            cancelsExpect.fulfill()
        }
        socket.cancel()

        await fulfillment(of: [cancelsExpect], timeout: 3, enforceOrder: true)
    }
    
    func test_Cancels_WhenNotConnected_NextOperationReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let socket = try RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                                   transport: transport, timeout: timeout, sni: "localhost")
        defer { socket.cancel() }

        let cancelsExpect = expectation(description: "Cancel callbacks called")
        socket.cancel {
            socket.connect { _, error in
                XCTAssertNotNil(error)
                guard let error = error as? NWError else { return XCTFail("Error is not NWError") }
                guard case .posix(let code) = error else { return XCTFail("Error is not posix") }
                XCTAssertEqual(code, .ECANCELED)
                cancelsExpect.fulfill()
            }
        }

        await fulfillment(of: [cancelsExpect], timeout: 3, enforceOrder: true)
    }
    
    func test_Cancels_DeinitFromConnectionQueue_NextOperationReturnsError() async throws {
        let transport: NetTransport = .tcp
        let timeout: TimeInterval = 0
        let server = try ServerMock(transport: transport, isSecure: true)
        defer { server.stop() }
        let port = try await server.start()

        let box = _SocketBox()
        try box.set(RawSocket(endpoint: .hostPort(host: "127.0.0.1", port: port), maxDataBlock: 256,
                              transport: transport, timeout: timeout, sni: "localhost"))
        defer { box.get()?.cancel() }

        let cancelsExpect = expectation(description: "Cancel callbacks called")
        box.get()?.connect { _, error in
            XCTAssertNil(error)
            box.get()?.cancel {
                cancelsExpect.fulfill()
            }
            box.set(nil)
        }

        await fulfillment(of: [cancelsExpect], timeout: 3, enforceOrder: true)
    }
}
