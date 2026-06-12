import Foundation
import Testing
@testable import NetworkLib

extension Tag {
    @Tag static var httpStatusCode: Self
}

struct HTTPStatusCodeTests {
    @Test(.tags(.httpStatusCode), arguments: HTTPStatusCode.knownPairs)
    func initWithKnownCodes_ResultCorrect(_ code: HTTPStatusCode.RawValue, _ expected: HTTPStatusCode) async throws {
        try #require(HTTPStatusCode(rawValue: code) == expected)
    }

    @Test(.tags(.httpStatusCode), arguments: HTTPStatusCode.unknownFromExisted)
    func unknownFromExisted_ResultUnrecognized(_ code: HTTPStatusCode.RawValue) async throws {
        let code = HTTPStatusCode(rawValue: code)
        try #require(code == .unrecognized)
        try #require(code.isInformational == false)
        try #require(code.isSuccessful == false)
        try #require(code.isRedirection == false)
        try #require(code.isClientError == false)
        try #require(code.isServerError == false)
    }

    @Test(.tags(.httpStatusCode), arguments: HTTPStatusCode.informationalCases)
    func isInformation_Correct(_ code: HTTPStatusCode) async throws {
        try #require(code.isInformational == true)
        try #require(code.isSuccessful == false)
        try #require(code.isRedirection == false)
        try #require(code.isClientError == false)
        try #require(code.isServerError == false)
    }

    @Test(.tags(.httpStatusCode), arguments: HTTPStatusCode.successfulCases)
    func isSuccessful_Correct(_ code: HTTPStatusCode) async throws {
        try #require(code.isInformational == false)
        try #require(code.isSuccessful == true)
        try #require(code.isRedirection == false)
        try #require(code.isClientError == false)
        try #require(code.isServerError == false)
    }

    @Test(.tags(.httpStatusCode), arguments: HTTPStatusCode.redirectionCases)
    func isRedirection_Correct(_ code: HTTPStatusCode) async throws {
        try #require(code.isInformational == false)
        try #require(code.isSuccessful == false)
        try #require(code.isRedirection == true)
        try #require(code.isClientError == false)
        try #require(code.isServerError == false)
    }

    @Test(.tags(.httpStatusCode), arguments: HTTPStatusCode.clientErrorCases)
    func isClientError_Correct(_ code: HTTPStatusCode) async throws {
        try #require(code.isInformational == false)
        try #require(code.isSuccessful == false)
        try #require(code.isRedirection == false)
        try #require(code.isClientError == true)
        try #require(code.isServerError == false)
    }

    @Test(.tags(.httpStatusCode), arguments: HTTPStatusCode.serverErrorCases)
    func isServerError_Correct(_ code: HTTPStatusCode) async throws {
        try #require(code.isInformational == false)
        try #require(code.isSuccessful == false)
        try #require(code.isRedirection == false)
        try #require(code.isClientError == false)
        try #require(code.isServerError == true)
    }
}

private extension HTTPStatusCode {
    static let allRawCases: [RawValue] = HTTPStatusCode.allCases.map { $0.rawValue }
    static let unknownFromExisted: Set<RawValue> = Set(1..<600).subtracting(HTTPStatusCode.allCases.map { $0.rawValue })
    static let knownPairs: [(RawValue, HTTPStatusCode)] = HTTPStatusCode.allCases.map { ($0.rawValue, $0) }
    static let informationalCases: [HTTPStatusCode] = Self.cases(from: 100..<200)
    static let successfulCases: [HTTPStatusCode] = Self.cases(from: 200..<300)
    static let redirectionCases: [HTTPStatusCode] = Self.cases(from: 300..<400)
    static let clientErrorCases: [HTTPStatusCode] = Self.cases(from: 400..<500)
    static let serverErrorCases: [HTTPStatusCode] = Self.cases(from: 500..<600)

    private static func cases(from codes: Range<RawValue>) -> [HTTPStatusCode] {
        Set(codes).intersection(HTTPStatusCode.allRawCases).map { HTTPStatusCode(rawValue: $0) }
    }
}
