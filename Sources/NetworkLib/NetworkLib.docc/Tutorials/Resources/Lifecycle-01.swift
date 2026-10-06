import Network
import NetworkLib

func runTransfer() async {
    do {
        try await SendingAndReceivingExample.run()
    } catch let error as NWError {
        switch error {
        case .posix(.ETIMEDOUT):
            print("The connection timed out. Check the destination and network.")
        case .posix(.ECANCELED):
            print("The socket was cancelled.")
        default:
            print("Network operation failed:", error)
        }
    } catch {
        print("Transfer failed:", error)
    }
}
