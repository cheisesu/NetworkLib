import Foundation
import Testing
import Network
@testable import NetworkLib

@Suite(.tags(.core, .RawSocket.all, .RawSocket.connect), .timeLimit(.minutes(2)))
struct RawSocketAsyncConnectTests {
    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func onSuccess(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock()
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        // Opt in explicitly so comparison runs perform no trace recording or snapshot scheduling.
        let trace: ConnectTimingTrace?
        let snapshot: DispatchWorkItem?
        if ProcessInfo.processInfo.environment["NETWORKLIB_CONNECT_TRACE"] == "1" {
            let recorder = ConnectTimingTrace(test: "onSuccess", transport: transport)
            trace = recorder
            socket.connectionTrace = { recorder.record($0) }
            underlyingConnection.connectionTrace = { recorder.record($0) }
            recorder.record("test.beforeConnect")
            let work = DispatchWorkItem { recorder.export(phase: "pending-90s") }
            snapshot = work
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 90, execute: work)
        } else {
            trace = nil
            snapshot = nil
        }
        defer {
            snapshot?.cancel()
            trace?.record("test.finished")
            trace?.export(phase: "finished")
        }
        let info = try await socket.connect()
        trace?.record("test.afterConnect")
        try #require(info == underlyingConnection.connectionInfo(with: transport))
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func onError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let expectedError = NWError.posix(.EINVAL)
        let underlyingConnection = NWConnectionMock(overridedStates: [.preparing, .failed(expectedError)])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        do {
            try await socket.connect()
            Issue.record("Unexpected entrance")
        } catch where (error as any Error) as? NWError == expectedError {
        }
    }

    @Test(arguments: [RawSocketTransport.tcp, .udp])
    func whenTaskCancelled_ThrowsCancelledError(_ transport: RawSocketTransport) async throws {
        let timeout: TimeInterval = 0
        let underlyingConnection = NWConnectionMock(overridedStates: [.preparing])
        let socket = try RawSocket(underlyingConnection, accessQueue: nil, delegateQueue: nil, timeout: timeout,
                                   maxDataBlock: 256, transport: transport)
        defer { socket.cancel(nil) }
        // Subscribe before starting connect; the stream buffers an early transition.
        let (connecting, continuation) = AsyncStream.makeStream(of: Void.self)
        socket.onInternalStateChange = { _, newState in
            guard newState == .connecting else { return }
            continuation.yield(())
            continuation.finish()
        }
        defer { continuation.finish() }
        do {
            let task = Task {
                try await socket.connect()
            }
            defer { task.cancel() }
            for await _ in connecting {
                break
            }
            task.cancel()
            _ = try await task.value
        } catch NWError.posix(.ECANCELED) {
        }
    }
}

// One buffer and lock per connection; disk I/O happens only when exporting a snapshot.
private final class ConnectTimingTrace: @unchecked Sendable {
    private struct Entry: Codable {
        let event: String
        let elapsedMilliseconds: Double
    }

    private struct Report: Codable {
        let id: String
        let pid: Int32
        let test: String
        let transport: String
        let phase: String
        let startedAt: Date
        let events: [Entry]
    }

    private let lock = NSLock()
    private var entries: [Entry] = []
    private let start = DispatchTime.now().uptimeNanoseconds
    private let startedAt = Date()
    private let id = UUID().uuidString
    private let test: String
    private let transport: String

    init(test: String, transport: RawSocketTransport) {
        self.test = test
        self.transport = String(describing: transport)
    }

    func record(_ event: String) {
        lock.withLock {
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            entries.append(Entry(event: event, elapsedMilliseconds: elapsed))
        }
    }

    func export(phase: String) {
        let events = lock.withLock { entries }
        let report = Report(id: id, pid: ProcessInfo.processInfo.processIdentifier,
                            test: test, transport: transport, phase: phase,
                            startedAt: startedAt, events: events)
        let directory = ProcessInfo.processInfo.environment["NETWORKLIB_CONNECT_TRACE_DIRECTORY"]
            ?? NSTemporaryDirectory() + "NetworkLibConnectTraces"
        let root = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            try data.write(to: root.appendingPathComponent("\(id)-\(phase).json"), options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("Connect trace export failed: \(error)\n".utf8))
        }
    }
}
