import Foundation
import Testing
@testable import NetworkLib

extension Tag.HTTP {
    @Tag static var headerKey: Tag
}

@Suite(.tags(.HTTP.all, .HTTP.headerKey))
struct HTTPHeaderKeyTests {
    private let url = URL(string: "https://example.com")!

    @Test
    func initializers_PreserveRawValue() {
        let rawValueKey = HTTPHeaderKey(rawValue: "X-Raw-Value")
        let literalKey: HTTPHeaderKey = "X-Literal"

        #expect(rawValueKey.rawValue == "X-Raw-Value")
        #expect(literalKey.rawValue == "X-Literal")
    }

    @Test
    func unlabeledInitializer_PreservesRawValue() {
        let initializer: (String) -> HTTPHeaderKey = HTTPHeaderKey.init(_:)
        let rawValue = ["X", "Unlabeled"].joined(separator: "-")

        let key = initializer(rawValue)

        #expect(key.rawValue == rawValue)
    }

    @Test
    func rawFields_ReturnsStringKeyedDictionary() {
        let headers: [HTTPHeaderKey: String] = [
            .accept: "application/json",
            HTTPHeaderKey("X-Request-ID"): "request-id"
        ]

        #expect(headers.rawFields == [
            "Accept": "application/json",
            "X-Request-ID": "request-id"
        ])
    }

    @Test(arguments: [
        (HTTPHeaderKey.accept, "Accept"),
        (.acceptCharset, "Accept-Charset"),
        (.acceptEncoding, "Accept-Encoding"),
        (.acceptLanguage, "Accept-Language"),
        (.acceptRanges, "Accept-Ranges"),
        (.accessControlAllowCredentials, "Access-Control-Allow-Credentials"),
        (.accessControlAllowHeaders, "Access-Control-Allow-Headers"),
        (.accessControlAllowMethods, "Access-Control-Allow-Methods"),
        (.accessControlAllowOrigin, "Access-Control-Allow-Origin"),
        (.accessControlExposeHeaders, "Access-Control-Expose-Headers"),
        (.accessControlMaxAge, "Access-Control-Max-Age"),
        (.accessControlRequestHeaders, "Access-Control-Request-Headers"),
        (.accessControlRequestMethod, "Access-Control-Request-Method"),
        (.age, "Age"),
        (.allow, "Allow"),
        (.authorization, "Authorization"),
        (.cacheControl, "Cache-Control"),
        (.connection, "Connection"),
        (.contentDisposition, "Content-Disposition"),
        (.contentEncoding, "Content-Encoding"),
        (.contentLanguage, "Content-Language"),
        (.contentLength, "Content-Length"),
        (.contentLocation, "Content-Location"),
        (.contentRange, "Content-Range"),
        (.contentSecurityPolicy, "Content-Security-Policy"),
        (.contentType, "Content-Type"),
        (.cookie, "Cookie"),
        (.date, "Date"),
        (.eTag, "ETag"),
        (.expect, "Expect"),
        (.expires, "Expires"),
        (.forwarded, "Forwarded"),
        (.from, "From"),
        (.host, "Host"),
        (.ifMatch, "If-Match"),
        (.ifModifiedSince, "If-Modified-Since"),
        (.ifNoneMatch, "If-None-Match"),
        (.ifRange, "If-Range"),
        (.ifUnmodifiedSince, "If-Unmodified-Since"),
        (.keepAlive, "Keep-Alive"),
        (.lastModified, "Last-Modified"),
        (.link, "Link"),
        (.location, "Location"),
        (.origin, "Origin"),
        (.pragma, "Pragma"),
        (.proxyAuthenticate, "Proxy-Authenticate"),
        (.proxyAuthorization, "Proxy-Authorization"),
        (.range, "Range"),
        (.referer, "Referer"),
        (.retryAfter, "Retry-After"),
        (.secWebSocketAccept, "Sec-WebSocket-Accept"),
        (.secWebSocketExtensions, "Sec-WebSocket-Extensions"),
        (.secWebSocketKey, "Sec-WebSocket-Key"),
        (.secWebSocketProtocol, "Sec-WebSocket-Protocol"),
        (.secWebSocketVersion, "Sec-WebSocket-Version"),
        (.server, "Server"),
        (.setCookie, "Set-Cookie"),
        (.strictTransportSecurity, "Strict-Transport-Security"),
        (.te, "TE"),
        (.trailer, "Trailer"),
        (.transferEncoding, "Transfer-Encoding"),
        (.upgrade, "Upgrade"),
        (.userAgent, "User-Agent"),
        (.vary, "Vary"),
        (.via, "Via"),
        (.warning, "Warning"),
        (.wwwAuthenticate, "WWW-Authenticate"),
        (.xContentTypeOptions, "X-Content-Type-Options"),
        (.xForwardedFor, "X-Forwarded-For"),
        (.xForwardedHost, "X-Forwarded-Host"),
        (.xForwardedProto, "X-Forwarded-Proto"),
        (.xFrameOptions, "X-Frame-Options"),
        (.xRequestedWith, "X-Requested-With")
    ])
    func predefinedHeader_HasExpectedRawValue(_ header: HTTPHeaderKey, _ expected: String) {
        #expect(header.rawValue == expected)
    }

    @Test
    func allHTTPHeadersWithoutHeaders_ReturnsNil() {
        let request = URLRequest(url: url)

        #expect(request.allHTTPHeaders == nil)
    }

    @Test
    func allHTTPHeaders_ReturnsHeadersWithTypedKeys() throws {
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = [
            "Accept": "application/json",
            "X-Request-ID": "request-id"
        ]

        let headers = try #require(request.allHTTPHeaders)
        #expect(headers[.accept] == "application/json")
        #expect(headers[HTTPHeaderKey("X-Request-ID")] == "request-id")
    }

    @Test
    func setAndReadValue_WithTypedKey_UpdatesHeader() {
        var request = URLRequest(url: url)

        request.setValue("application/json", forHTTPHeaderField: .accept)

        #expect(request.value(forHTTPHeaderField: .accept) == "application/json")
        #expect(request.value(forHTTPHeaderField: HTTPHeaderKey("Accept")) == "application/json")
    }

    @Test
    func setNilValue_WithTypedKey_RemovesHeader() {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: .accept)

        request.setValue(nil, forHTTPHeaderField: .accept)

        #expect(request.value(forHTTPHeaderField: .accept) == nil)
    }

    @Test
    func addValue_WithTypedKey_AppendsHeaderValue() {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: .accept)

        request.addValue("text/plain", forHTTPHeaderField: .accept)

        #expect(request.value(forHTTPHeaderField: .accept) == "application/json,text/plain")
    }
}
