import Foundation

/// Opt-in lifecycle tracing. Records contain identifiers and events, never network payloads.
enum SocketDiagnostics {
    static func record(_ socketID: String, _ event: String) {
#if DEBUG
        guard let writer else { return }
        writer.record(socketID, event)
#endif
    }

#if DEBUG
    private static let writer: Writer? = {
        guard ProcessInfo.processInfo.environment["NETWORKLIB_DIAGNOSTICS"] == "1" else { return nil }
        return Writer()
    }()

    private final class Writer: @unchecked Sendable {
        private let lock = NSLock()
        private let file: FileHandle
        private var sequence = 0

        init?() {
            let configuredDirectory = ProcessInfo.processInfo.environment["NETWORKLIB_DIAGNOSTICS_DIRECTORY"]
            let directory = configuredDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("NetworkLibDiagnostics", isDirectory: true)
            let url = directory.appendingPathComponent("\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString).jsonl")
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard FileManager.default.createFile(atPath: url.path, contents: nil) else { return nil }
                file = try FileHandle(forWritingTo: url)
                // Also announce the location in captured runner stderr.
                FileHandle.standardError.write(Data("NetworkLib diagnostics: \(url.path)\n".utf8))
            } catch {
                FileHandle.standardError.write(Data("NetworkLib diagnostics failed: \(error)\n".utf8))
                return nil
            }
            record("process", "started os=\(ProcessInfo.processInfo.operatingSystemVersionString)")
        }

        func record(_ socketID: String, _ event: String) {
            lock.withLock {
                sequence += 1
                let entry: [String: Any] = [
                    "sequence": sequence,
                    "uptime": ProcessInfo.processInfo.systemUptime,
                    "pid": ProcessInfo.processInfo.processIdentifier,
                    "socket": socketID,
                    "event": event
                ]
                do {
                    var data = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
                    data.append(0x0A)
                    // Write directly: no logging queue or buffered print that could lose the final events on timeout.
                    if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *) {
                        try file.write(contentsOf: data)
                    } else {
                        file.write(data)
                    }
                } catch {
                    FileHandle.standardError.write(Data("NetworkLib diagnostics write failed: \(error)\n".utf8))
                }
            }
        }
    }
#endif
}
