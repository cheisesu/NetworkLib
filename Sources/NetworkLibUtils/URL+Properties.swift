import Foundation

extension URL {
    /// The URL's percent-encoded host component, exposed consistently across supported OS versions.
    ///
    /// Returns `nil` when the URL has no host component.
    public var wrappedHost: String? {
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            return host()
        } else {
            return host
        }
    }

    /// The URL's percent-encoded path component, exposed consistently across supported OS versions.
    ///
    /// An empty path is returned as an empty string.
    public var wrappedPath: String? {
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            return path()
        } else {
            return path
        }
    }

    /// The URL's percent-encoded query component, exposed consistently across supported OS versions.
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
