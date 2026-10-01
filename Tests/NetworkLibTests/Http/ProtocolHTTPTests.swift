import Foundation
import Network
import Testing
@testable import NetworkLib

@Suite(.tags(.HTTP.all, .HTTP.protocol))
struct ProtocolHTTPTests {
    @Test
    func protocolOptions_CreatesHTTPFramerOptions() {
        let _: NWProtocolFramer.Options = .http()
    }
}
