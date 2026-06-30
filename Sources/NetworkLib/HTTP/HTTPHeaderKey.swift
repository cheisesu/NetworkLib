import Foundation

/// A typed wrapper around an HTTP header field name.
///
/// Use `HTTPHeaderKey` instead of raw `String` values when reading, writing, or storing
/// HTTP header fields. The wrapper preserves the exact wire name in ``rawValue`` while
/// making header dictionaries and `URLRequest` helpers harder to mix up with unrelated strings.
public struct HTTPHeaderKey: RawRepresentable {
    /// The header field name as it appears on the HTTP wire, such as `"Content-Length"`.
    public let rawValue: String

    /// Creates a header key from a raw header field name.
    ///
    /// - Parameter rawValue: The exact header field name to use.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a header key from a raw header field name.
    ///
    /// - Parameter rawValue: The exact header field name to use.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - CONFORMANCES

extension HTTPHeaderKey: Sendable {}

extension HTTPHeaderKey: Hashable {}

extension HTTPHeaderKey: ExpressibleByStringLiteral {
    /// Creates a header key from a string literal.
    ///
    /// This allows custom headers to be written inline, for example:
    ///
    /// ```swift
    /// let key: HTTPHeaderKey = "X-Request-ID"
    /// ```
    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }
}

// MARK: - CONVERSIONS

extension Dictionary where Key == HTTPHeaderKey, Value == String {
    /// Returns this dictionary using raw string header names as keys.
    ///
    /// Use this when passing typed header dictionaries to Foundation APIs that still require
    /// `[String: String]`, such as `HTTPURLResponse` initializers.
    public var rawFields: [String: String] {
        reduce(into: [:]) { partialResult, keyValue in
            partialResult[keyValue.key.rawValue] = keyValue.value
        }
    }
}

// MARK: - EXTENDING URLREQUEST

extension URLRequest {
    /// The request's HTTP headers keyed by ``HTTPHeaderKey``.
    ///
    /// This mirrors `allHTTPHeaderFields` while preserving this library's typed header key API.
    public var allHTTPHeaders: [HTTPHeaderKey: String]? {
        allHTTPHeaderFields?.reduce(into: [:]) { partialResult, keyValue in
            partialResult[.init(rawValue: keyValue.key)] = keyValue.value
        }
    }

    /// Sets the value for a typed HTTP header field.
    ///
    /// - Parameters:
    ///   - value: The value to set, or `nil` to remove the header.
    ///   - field: The typed header key to update.
    public mutating func setValue(_ value: String?, forHTTPHeaderField field: HTTPHeaderKey) {
        setValue(value, forHTTPHeaderField: field.rawValue)
    }

    /// Adds a value to a typed HTTP header field.
    ///
    /// - Parameters:
    ///   - value: The value to append.
    ///   - field: The typed header key to update.
    public mutating func addValue(_ value: String, forHTTPHeaderField field: HTTPHeaderKey) {
        addValue(value, forHTTPHeaderField: field.rawValue)
    }

    /// Returns the value for a typed HTTP header field.
    ///
    /// - Parameter field: The typed header key to read.
    /// - Returns: The header value, if present.
    public func value(forHTTPHeaderField field: HTTPHeaderKey) -> String? {
        value(forHTTPHeaderField: field.rawValue)
    }
}
