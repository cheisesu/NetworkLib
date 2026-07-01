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
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public enum HTTPStatusCode: Int, Sendable, CaseIterable {
    /// An unrecognized status code. Raw value: `0`.
    case unrecognized = 0

    // MARK: INFORMATIONAL

    /// The server received the request headers and the client may continue sending the request body. Raw value: `100`.
    case `continue` = 100

    /// The server is switching protocols as requested by the client. Raw value: `101`.
    case switchingProtocols = 101

    // MARK: SUCCESSFUL

    /// The request succeeded. Raw value: `200`.
    case ok = 200

    /// The request succeeded and created a new resource. Raw value: `201`.
    case created = 201

    /// The request was accepted for processing but processing has not completed. Raw value: `202`.
    case accepted = 202

    /// The request succeeded but the returned metadata may come from a transformed or non-authoritative source. Raw value: `203`.
    case nonAuthorizedInformation = 203

    /// The request succeeded and there is no response body. Raw value: `204`.
    case noContent = 204

    /// The request succeeded and the client should reset the document view. Raw value: `205`.
    case resetContent = 205

    /// The request succeeded for the requested byte range. Raw value: `206`.
    case partialContent = 206

    // MARK: REDIRECT

    /// Multiple representations are available for the requested resource. Raw value: `300`.
    case multipleChoices = 300

    /// The resource has moved permanently to a new URL. Raw value: `301`.
    case movedPermanently = 301

    /// The resource was found at a different URL for this request. Raw value: `302`.
    case found = 302

    /// The client should retrieve the response from another URL using `GET`. Raw value: `303`.
    case seeOther = 303

    /// The resource has not changed since the client's cached version. Raw value: `304`.
    case notModified = 304

    /// The requested resource must be accessed through a proxy. Raw value: `305`.
    case useProxy = 305

    /// The request should be repeated at another URL using the same method. Raw value: `307`.
    case temporaryRedirect = 307

    // MARK: CLIENT ERROR

    /// The request was malformed or invalid. Raw value: `400`.
    case badRequest = 400

    /// Authentication is required or failed. Raw value: `401`.
    case unauthorized = 401

    /// Payment is required to access the resource. Raw value: `402`.
    case paymentRequired = 402

    /// The server understood the request but refuses to authorize it. Raw value: `403`.
    case forbidden = 403

    /// The requested resource was not found. Raw value: `404`.
    case notFound = 404

    /// The HTTP method is not allowed for the resource. Raw value: `405`.
    case methodNotAllowed = 405

    /// The resource cannot produce a response acceptable to the request headers. Raw value: `406`.
    case notAcceptable = 406

    /// Proxy authentication is required. Raw value: `407`.
    case proxyAuthorizationRequired = 407

    /// The server timed out waiting for the request. Raw value: `408`.
    case requestTimeout = 408

    /// The request conflicts with the current resource state. Raw value: `409`.
    case conflict = 409

    /// The requested resource is no longer available. Raw value: `410`.
    case gone = 410

    /// The request requires a `Content-Length` header. Raw value: `411`.
    case lengthRequired = 411

    /// A request precondition failed. Raw value: `412`.
    case preconditionFailed = 412

    /// The request payload is larger than the server is willing to process. Raw value: `413`.
    case payloadTooLarge = 413

    /// The request URI is longer than the server is willing to interpret. Raw value: `414`.
    case uriTooLong = 414

    /// The request media type is unsupported. Raw value: `415`.
    case unsupportedMediaType = 415

    /// The requested byte range cannot be satisfied. Raw value: `416`.
    case rangeNotSatisfiable = 416

    /// The expectation in the `Expect` header cannot be met. Raw value: `417`.
    case expectationFailed = 417

    /// The client should switch to a different protocol. Raw value: `426`.
    case upgradeRequired = 426

    // MARK: SERVER ERROR

    /// The server encountered an unexpected condition. Raw value: `500`.
    case internalServerError = 500

    /// The server does not support the requested functionality. Raw value: `501`.
    case notImplemented = 501

    /// A gateway or proxy received an invalid response from an upstream server. Raw value: `502`.
    case badGateway = 502

    /// The server is temporarily unable to handle the request. Raw value: `503`.
    case serviceUnavailable = 503

    /// A gateway or proxy timed out waiting for an upstream server. Raw value: `504`.
    case gatewayTimeout = 504

    /// The server does not support the HTTP version used in the request. Raw value: `505`.
    case httpVersionNotSupported = 505

    /// Creates a status code from a raw integer value.
    ///
    /// Unknown integer values map to ``unrecognized``.
    ///
    /// For example, known values preserve their raw equivalent, while unknown values become ``unrecognized``:
    ///
    /// ```swift
    /// HTTPStatusCode(rawValue: 200) == .ok
    /// HTTPStatusCode.ok.rawValue == 200
    /// HTTPStatusCode(rawValue: 599) == .unrecognized
    /// ```
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
