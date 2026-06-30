import Foundation

public struct HTTPHeaderKey: RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - CONFORMANCES

extension HTTPHeaderKey: Sendable {}

extension HTTPHeaderKey: Hashable {}

extension HTTPHeaderKey: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }
}

// MARK: - EXTENDING URLREQUEST

extension URLRequest {
    public var allHTTPHeaders: [HTTPHeaderKey: String]? {
        allHTTPHeaderFields?.reduce(into: [:]) { partialResult, keyValue in
            partialResult[.init(rawValue: keyValue.key)] = keyValue.value
        }
    }

    public mutating func setValue(_ value: String?, forHTTPHeaderField field: HTTPHeaderKey) {
        setValue(value, forHTTPHeaderField: field.rawValue)
    }

    public mutating func addValue(_ value: String, forHTTPHeaderField field: HTTPHeaderKey) {
        addValue(value, forHTTPHeaderField: field.rawValue)
    }

    public func value(forHTTPHeaderField field: HTTPHeaderKey) -> String? {
        value(forHTTPHeaderField: field.rawValue)
    }
}
