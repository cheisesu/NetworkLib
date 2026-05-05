import Foundation
import Testing
@testable import NetworkLib

struct HTTPNetworkTaskTests {
    @Test
    func foo() async throws {
//        let url = try #require(URL(string: "https://api.ipify.org/?format=json"))
        let url = try #require(URL(string: "http://212.183.159.230/5MB.zip"))
        let request = URLRequest(url: url, timeoutInterval: 30)
        let task = HTTPNetworkTask(request)
        let data = try await withCheckedThrowingContinuation { continuation in
            task.callback = { response, result in
                continuation.resume(with: result)
            }
            task.start()
        }
        print("==>>", String(data: data, encoding: .utf8) ?? "??")
    }
}

