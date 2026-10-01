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

    @Test
    func updatingURLError_PreservesCodeAndUserInfo() throws {
        let url = try #require(URL(string: "https://example.com/path"))
        let request = URLRequest(url: url)
        let original = URLError(.cancelled, userInfo: ["Existing": "value"])

        let error = URLError(orUpdate: original, for: request, phase: .receiving)

        #expect(error.code == .cancelled)
        #expect(error.userInfo["Existing"] as? String == "value")
        #expect(error.userInfo[NSURLErrorFailingURLErrorKey] as? URL == url)
        #expect(error.userInfo[NSURLErrorFailingURLStringErrorKey] as? String == url.absoluteString)
        #expect(error.userInfo[NSURLErrorKey] as? URL == url)
        #expect(error.userInfo[HTTPTaskErrorInfoKey.phase] as? String == "receiving")
        #expect(error.userInfo[NSUnderlyingErrorKey] == nil)
    }

    @Test
    func updatingNWError_MapsCodeAndStoresUnderlyingError() throws {
        let url = try #require(URL(string: "https://example.com"))
        let request = URLRequest(url: url)
        let underlyingError = NWError.posix(.ETIMEDOUT)

        let error = URLError(orUpdate: underlyingError, for: request, phase: .connecting)

        #expect(error.code == .timedOut)
        #expect(error.userInfo[HTTPTaskErrorInfoKey.phase] as? String == "connecting")
        #expect(error.userInfo[NSUnderlyingErrorKey] as? NWError == underlyingError)
    }

    @Test(arguments: [POSIXErrorCode.EBADMSG, .EMSGSIZE, .EPROTO])
    func sendingProtocolError_UsesUnknownCode(_ posixCode: POSIXErrorCode) throws {
        let url = try #require(URL(string: "https://example.com"))
        let underlyingError = NWError.posix(posixCode)

        let error = URLError(orUpdate: underlyingError, for: URLRequest(url: url), phase: .sending)

        #expect(error.code == .unknown)
        #expect(error.userInfo[NSUnderlyingErrorKey] as? NWError == underlyingError)
    }

    @Test
    func arbitraryErrorWithoutURL_UsesUnknownCodeAndDefaultPhase() throws {
        let initialURL = try #require(URL(string: "https://example.com"))
        var request = URLRequest(url: initialURL)
        request.url = nil
        let underlyingError = _MockError.justMock

        let error = URLError(orUpdate: underlyingError, for: request)

        #expect(error.code == .unknown)
        #expect(error.userInfo[HTTPTaskErrorInfoKey.phase] as? String == "common")
        #expect(error.userInfo[NSUnderlyingErrorKey] as? _MockError == underlyingError)
        #expect(error.userInfo[NSURLErrorFailingURLErrorKey] == nil)
        #expect(error.userInfo[NSURLErrorFailingURLStringErrorKey] == nil)
        #expect(error.userInfo[NSURLErrorKey] == nil)
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
