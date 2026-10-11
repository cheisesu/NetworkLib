import Foundation

enum ExampleError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let text): return text
        }
    }
}

enum ExampleCLI {
    static func log(_ message: String) {
        print("[example] \(message)")
    }

    static func printHelp() {
        print("""
        NetworkLib API examples
        Run from the package directory: swift run Examples <example>

          async       Fetch https://example.com using TLS and async/await.
          callbacks   Send UTF-8 bytes to a local TCP listener on port 9000.
          proxy       Fetch https://example.com through your HTTP CONNECT proxy.
          udp         Exchange a typed message with a local UDP echo server on port 9001.
          headers     Build and inspect HTTP headers locally; no server needed.

        Setup:
          async: Internet access is required.
          callbacks: In another terminal, run: nc -l 9000
          udp: In another terminal, run:
        python3 -u - <<'PYTHON'
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.bind(("127.0.0.1", 9001))
        print("UDP echo ready")
        while True:
            data, addr = s.recvfrom(65535)
            s.sendto(data, addr)
        PYTHON
          proxy: Set NL_PROXY_HOST and NL_PROXY_PORT.
            NL_PROXY_HOST=localhost NL_PROXY_PORT=8080 NL_PROXY_TLS=false swift run Examples proxy
            NL_PROXY_TLS defaults to true; set false for a plaintext proxy.
            Optional: NL_PROXY_USERNAME and NL_PROXY_PASSWORD (set both).
            TLS proxy certificates must be trusted by the system.
            Requires macOS 12.3 or later.

        Each network example prints progress and closes its socket.
        Errors exit with status 1. Use --help or -h to show this screen.
        """)
    }
}
