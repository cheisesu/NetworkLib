import Foundation

public enum HTTPStatusCode: Int, Sendable, CaseIterable {
    /// An unrecognized status code MUST be treated as the x00 status code of its class.
    case unrecognized = 0

    // MARK: INFORMATIONAL

    case `continue` = 100
    case switchingProtocols = 101

    // MARK: SUCCESSFUL

    case ok = 200
    case created = 201
    case accepted = 202
    case nonAuthorizedInformation = 203
    case noContent = 204
    case resetContent = 205
    case partialContent = 206

    // MARK: REDIRECT

    case multipleChoices = 300
    case movedPermanently = 301
    case found = 302
    case seeOther = 303
    case notModified = 304
    case useProxy = 305
    case temporaryRedirect = 307

    // MARK: CLIENT ERROR

    case badRequest = 400
    case unauthorized = 401
    case paymentRequired = 402
    case forbidden = 403
    case notFound = 404
    case methodNotAllowed = 405
    case notAcceptable = 406
    case proxyAuthorizationRequired = 407
    case requestTimeout = 408
    case conflict = 409
    case gone = 410
    case lengthRequired = 411
    case preconditionFailed = 412
    case payloadTooLarge = 413
    case uriTooLong = 414
    case unsupportedMediaType = 415
    case rangeNotSatisfiable = 416
    case expectationFailed = 417
    case upgradeRequired = 426

    // MARK: SERVER ERROR

    case internalServerError = 500
    case notImplemented = 501
    case badGateway = 502
    case serviceUnavailable = 503
    case gatewayTimeout = 504
    case httpVersionNotSupported = 505

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
