import Foundation

/// Common HTTP response status codes grouped by status class.
///
/// For example, classify a status returned by an HTTP response:
///
/// ```swift
/// let status = HTTPStatusCode(rawValue: response.statusCode)
/// if status.isSuccessful {
///     // Handle a 2xx response.
/// }
/// ```
public enum HTTPStatusCode: Int, Sendable, CaseIterable {
    /// An unrecognized status code MUST be treated as the x00 status code of its class.
    case unrecognized = 0

    // MARK: INFORMATIONAL

    /// The server received the request headers and the client may continue sending the request body.
    case `continue` = 100

    /// The server is switching protocols as requested by the client.
    case switchingProtocols = 101

    // MARK: SUCCESSFUL

    /// The request succeeded.
    case ok = 200

    /// The request succeeded and created a new resource.
    case created = 201

    /// The request was accepted for processing but processing has not completed.
    case accepted = 202

    /// The request succeeded but the returned metadata may come from a transformed or non-authoritative source.
    case nonAuthorizedInformation = 203

    /// The request succeeded and there is no response body.
    case noContent = 204

    /// The request succeeded and the client should reset the document view.
    case resetContent = 205

    /// The request succeeded for the requested byte range.
    case partialContent = 206

    // MARK: REDIRECT

    /// Multiple representations are available for the requested resource.
    case multipleChoices = 300

    /// The resource has moved permanently to a new URL.
    case movedPermanently = 301

    /// The resource was found at a different URL for this request.
    case found = 302

    /// The client should retrieve the response from another URL using `GET`.
    case seeOther = 303

    /// The resource has not changed since the client's cached version.
    case notModified = 304

    /// The requested resource must be accessed through a proxy.
    case useProxy = 305

    /// The request should be repeated at another URL using the same method.
    case temporaryRedirect = 307

    // MARK: CLIENT ERROR

    /// The request was malformed or invalid.
    case badRequest = 400

    /// Authentication is required or failed.
    case unauthorized = 401

    /// Payment is required to access the resource.
    case paymentRequired = 402

    /// The server understood the request but refuses to authorize it.
    case forbidden = 403

    /// The requested resource was not found.
    case notFound = 404

    /// The HTTP method is not allowed for the resource.
    case methodNotAllowed = 405

    /// The resource cannot produce a response acceptable to the request headers.
    case notAcceptable = 406

    /// Proxy authentication is required.
    case proxyAuthorizationRequired = 407

    /// The server timed out waiting for the request.
    case requestTimeout = 408

    /// The request conflicts with the current resource state.
    case conflict = 409

    /// The requested resource is no longer available.
    case gone = 410

    /// The request requires a `Content-Length` header.
    case lengthRequired = 411

    /// A request precondition failed.
    case preconditionFailed = 412

    /// The request payload is larger than the server is willing to process.
    case payloadTooLarge = 413

    /// The request URI is longer than the server is willing to interpret.
    case uriTooLong = 414

    /// The request media type is unsupported.
    case unsupportedMediaType = 415

    /// The requested byte range cannot be satisfied.
    case rangeNotSatisfiable = 416

    /// The expectation in the `Expect` header cannot be met.
    case expectationFailed = 417

    /// The client should switch to a different protocol.
    case upgradeRequired = 426

    // MARK: SERVER ERROR

    /// The server encountered an unexpected condition.
    case internalServerError = 500

    /// The server does not support the requested functionality.
    case notImplemented = 501

    /// A gateway or proxy received an invalid response from an upstream server.
    case badGateway = 502

    /// The server is temporarily unable to handle the request.
    case serviceUnavailable = 503

    /// A gateway or proxy timed out waiting for an upstream server.
    case gatewayTimeout = 504

    /// The server does not support the HTTP version used in the request.
    case httpVersionNotSupported = 505

    /// Creates a status code from a raw integer value.
    ///
    /// Unknown integer values map to ``unrecognized``.
    ///
    /// - Parameter rawValue: The numeric HTTP status code.
    public init(rawValue: Int) {
        let existed = Self.allCasesMap[rawValue]
        self = existed ?? .unrecognized
    }
}

extension HTTPStatusCode {
    /// The request was received, continuing process.
    public var isInformational: Bool { Self.informationalCodes.contains(rawValue) }

    /// The request was successfully received, understood, and accepted.
    public var isSuccessful: Bool { Self.successfulCodes.contains(rawValue) }

    /// Further action needs to be taken in order to complete the request.
    public var isRedirection: Bool { Self.redirectionCodes.contains(rawValue) }

    /// The request contains bad syntax or cannot be fulfilled.
    public var isClientError: Bool { Self.clientErrorCodes.contains(rawValue) }

    /// The server failed to fulfill an apparently valid request.
    public var isServerError: Bool { Self.servertErrorCodes.contains(rawValue) }
}

extension HTTPStatusCode {
    private static let informationalCodes: Set<Int> = Set((100..<200).map { $0 })
    private static let successfulCodes: Set<Int> = Set((200..<300).map { $0 })
    private static let redirectionCodes: Set<Int> = Set((300..<400).map { $0 })
    private static let clientErrorCodes: Set<Int> = Set((400..<500).map { $0 })
    private static let servertErrorCodes: Set<Int> = Set((500..<600).map { $0 })

    private static let allCasesMap: [Int: HTTPStatusCode] = {
        HTTPStatusCode.allCases.reduce(into: [:]) { $0[$1.rawValue] = $1 }
    }()
}
