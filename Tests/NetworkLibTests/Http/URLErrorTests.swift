import Foundation
import Testing
import Network
@testable import NetworkLib

extension Tag.HTTP {
    @Tag static var urlError: Tag
}

private enum _MockError: Error {
    case justMock
}

@Suite(.tags(.HTTP.all, .HTTP.urlError))
struct URLErrorTests {
    @Test(arguments: [
        (URLError(.cancelled), URLError.cancelled),
    ])
    func urlErrorCodeReturnsItsCode(_ urlError: URLError, _ expectedCode: URLError.Code) throws {
        try #require(urlError.urlErrorCode == expectedCode)
    }

    @available(macOS 26.0, *)
    @Test(arguments: [
        (NWError.posix(.ENOTCONN), URLError.Code.notConnectedToInternet),
        (NWError.dns(999), URLError.Code.cannotFindHost),
        (NWError.tls(999), URLError.Code.secureConnectionFailed),
        (NWError.wifiAware(999), URLError.Code.unknown),
    ])
    func nwErrorReturnsCodeCovertedValue(_ error: NWError, _ expectedCode: URLError.Code) throws {
        try #require(error.urlErrorCode == expectedCode)
    }

    @available(macOS 26.0, *)
    @Test(arguments: [
        (NWError.posix(.ENOTCONN), URLError.Code.notConnectedToInternet),
        (NWError.dns(999), URLError.Code.cannotFindHost),
        (NWError.tls(999), URLError.Code.secureConnectionFailed),
        (NWError.wifiAware(999), URLError.Code.unknown),
    ])
    func anyErrorButNWErrorReturnsCodeCovertedValue(_ error: Error, _ expectedCode: URLError.Code) throws {
        try #require(error.urlErrorCode == expectedCode)
    }

    @Test
    func anyErrorCodeReturnsItsCode() throws {
        try #require(_MockError.justMock.urlErrorCode == .unknown)
    }

    @Test(arguments: [
        (POSIXErrorCode.ECANCELED, URLError.Code.cancelled),
        (POSIXErrorCode.ETIMEDOUT, URLError.Code.timedOut),
        (POSIXErrorCode.ECONNREFUSED, URLError.Code.cannotConnectToHost),
        (POSIXErrorCode.EHOSTUNREACH, URLError.Code.cannotConnectToHost),
        (POSIXErrorCode.ENETUNREACH, URLError.Code.cannotConnectToHost),
        (POSIXErrorCode.ECONNRESET, URLError.Code.networkConnectionLost),
        (POSIXErrorCode.ECONNABORTED, URLError.Code.networkConnectionLost),
        (POSIXErrorCode.EPIPE, URLError.Code.networkConnectionLost),
        (POSIXErrorCode.ENOTCONN, URLError.Code.notConnectedToInternet),
        (POSIXErrorCode.EAUTH, URLError.Code.userAuthenticationRequired),
        (POSIXErrorCode.EACCES, URLError.Code.userAuthenticationRequired),
        (POSIXErrorCode.EBADMSG, URLError.Code.cannotParseResponse),
        (POSIXErrorCode.EPROTO, URLError.Code.cannotParseResponse),
        (POSIXErrorCode.EIO, URLError.Code.cannotParseResponse),
        (POSIXErrorCode.EINVAL, URLError.Code.cannotParseResponse),
        (POSIXErrorCode.ENOTSUP, URLError.Code.unsupportedURL),
        (POSIXErrorCode.EFBIG, URLError.Code.unknown),
    ])
    func posixCodeToUrlErrorCode(_ code: POSIXErrorCode, _ expectedCode: URLError.Code) throws {
        try #require(code.urlErrorCode == expectedCode)
    }
}
