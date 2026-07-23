import Foundation

func printDebug(_ items: Any?..., separator: String = " ", terminator: String = "\n", defaultNil: String = "<??>") {
#if DEBUG
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
