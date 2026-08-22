import Foundation

func printDebug(_ items: Any?..., separator: String = " ", terminator: String = "\n", defaultNil: String = "<??>") {
#if DEBUG
    guard #available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    let date = Date().formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))
    let items = [date] + items.map {
        if let item = $0 {
            String(describing: item)
        } else {
            defaultNil
        }
    }
    print(items.joined(separator: separator), terminator: terminator)
#endif
}
