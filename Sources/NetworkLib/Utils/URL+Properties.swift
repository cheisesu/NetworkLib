import Foundation

extension URL {
    /// The URL's host component, using the host accessor available on the current OS version.
    ///
    /// Returns `nil` when the URL has no host component.
    public var wrappedHost: String? {
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            return host()
        } else {
            return host
        }
    }

    /// The URL's path component, using the path accessor available on the current OS version.
    ///
    /// An empty path is returned as an empty string.
    public var wrappedPath: String? {
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            return path()
        } else {
            return path
        }
    }

    /// The URL's query component, using the query accessor available on the current OS version.
    ///
    /// Returns `nil` when the URL has no query component.
    public var wrappedQuery: String? {
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            return query()
        } else {
            return query
        }
    }
}
