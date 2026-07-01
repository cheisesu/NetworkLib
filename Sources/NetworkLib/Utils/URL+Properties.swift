import Foundation

extension URL {
    var wrappedHost: String? {
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            return host()
        } else {
            return host
        }
    }

    var wrappedPath: String? {
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            return path()
        } else {
            return path
        }
    }

    var wrappedQuery: String? {
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            return query()
        } else {
            return query
        }
    }
}
