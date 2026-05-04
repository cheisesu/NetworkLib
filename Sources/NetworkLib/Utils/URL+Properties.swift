import Foundation

extension URL {
    var wrappedHost: String? {
        if #available(macOS 13.0, iOS 16.0, *) {
            return host()
        } else {
            return host
        }
    }

    var wrappedPath: String? {
        if #available(macOS 13.0, iOS 16.0, *) {
            return path()
        } else {
            return path
        }
    }

    var wrappedQuery: String? {
        if #available(macOS 13.0, iOS 16.0, *) {
            return query()
        } else {
            return query
        }
    }
}
