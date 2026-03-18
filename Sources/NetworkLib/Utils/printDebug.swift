import Foundation

func printDebug(_ items: Any?..., separator: String = " ", terminator: String = "\n", defaultNil: String = "<??>") {
#if DEBUG
    let items = items.map {
        if let item = $0 {
            String(describing: item)
        } else {
            defaultNil
        }
    }.joined(separator: separator)
    print(items, terminator: terminator)
#endif
}
