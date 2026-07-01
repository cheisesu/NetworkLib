import Foundation

// swiftlint:disable identifier_name
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
extension HTTPHeaderKey {
    /// The `Accept` request header.
    public static let accept: Self = "Accept"
    /// The `Accept-Charset` request header.
    public static let acceptCharset: Self = "Accept-Charset"
    /// The `Accept-Encoding` request header.
    public static let acceptEncoding: Self = "Accept-Encoding"
    /// The `Accept-Language` request header.
    public static let acceptLanguage: Self = "Accept-Language"
    /// The `Accept-Ranges` response header.
    public static let acceptRanges: Self = "Accept-Ranges"
    /// The `Access-Control-Allow-Credentials` CORS response header.
    public static let accessControlAllowCredentials: Self = "Access-Control-Allow-Credentials"
    /// The `Access-Control-Allow-Headers` CORS response header.
    public static let accessControlAllowHeaders: Self = "Access-Control-Allow-Headers"
    /// The `Access-Control-Allow-Methods` CORS response header.
    public static let accessControlAllowMethods: Self = "Access-Control-Allow-Methods"
    /// The `Access-Control-Allow-Origin` CORS response header.
    public static let accessControlAllowOrigin: Self = "Access-Control-Allow-Origin"
    /// The `Access-Control-Expose-Headers` CORS response header.
    public static let accessControlExposeHeaders: Self = "Access-Control-Expose-Headers"
    /// The `Access-Control-Max-Age` CORS response header.
    public static let accessControlMaxAge: Self = "Access-Control-Max-Age"
    /// The `Access-Control-Request-Headers` CORS request header.
    public static let accessControlRequestHeaders: Self = "Access-Control-Request-Headers"
    /// The `Access-Control-Request-Method` CORS request header.
    public static let accessControlRequestMethod: Self = "Access-Control-Request-Method"
    /// The `Age` response header.
    public static let age: Self = "Age"
    /// The `Allow` response header.
    public static let allow: Self = "Allow"
    /// The `Authorization` request header.
    public static let authorization: Self = "Authorization"
    /// The `Cache-Control` request or response header.
    public static let cacheControl: Self = "Cache-Control"
    /// The `Connection` request or response header.
    public static let connection: Self = "Connection"
    /// The `Content-Disposition` representation header.
    public static let contentDisposition: Self = "Content-Disposition"
    /// The `Content-Encoding` representation header.
    public static let contentEncoding: Self = "Content-Encoding"
    /// The `Content-Language` representation header.
    public static let contentLanguage: Self = "Content-Language"
    /// The `Content-Length` representation header.
    public static let contentLength: Self = "Content-Length"
    /// The `Content-Location` representation header.
    public static let contentLocation: Self = "Content-Location"
    /// The `Content-Range` representation header.
    public static let contentRange: Self = "Content-Range"
    /// The `Content-Security-Policy` response header.
    public static let contentSecurityPolicy: Self = "Content-Security-Policy"
    /// The `Content-Type` representation header.
    public static let contentType: Self = "Content-Type"
    /// The `Cookie` request header.
    public static let cookie: Self = "Cookie"
    /// The `Date` request or response header.
    public static let date: Self = "Date"
    /// The `ETag` response header.
    public static let eTag: Self = "ETag"
    /// The `Expect` request header.
    public static let expect: Self = "Expect"
    /// The `Expires` response header.
    public static let expires: Self = "Expires"
    /// The `Forwarded` request header.
    public static let forwarded: Self = "Forwarded"
    /// The `From` request header.
    public static let from: Self = "From"
    /// The `Host` request header.
    public static let host: Self = "Host"
    /// The `If-Match` conditional request header.
    public static let ifMatch: Self = "If-Match"
    /// The `If-Modified-Since` conditional request header.
    public static let ifModifiedSince: Self = "If-Modified-Since"
    /// The `If-None-Match` conditional request header.
    public static let ifNoneMatch: Self = "If-None-Match"
    /// The `If-Range` conditional range request header.
    public static let ifRange: Self = "If-Range"
    /// The `If-Unmodified-Since` conditional request header.
    public static let ifUnmodifiedSince: Self = "If-Unmodified-Since"
    /// The `Keep-Alive` connection header.
    public static let keepAlive: Self = "Keep-Alive"
    /// The `Last-Modified` response header.
    public static let lastModified: Self = "Last-Modified"
    /// The `Link` response header.
    public static let link: Self = "Link"
    /// The `Location` response header.
    public static let location: Self = "Location"
    /// The `Origin` request header.
    public static let origin: Self = "Origin"
    /// The `Pragma` request or response header.
    public static let pragma: Self = "Pragma"
    /// The `Proxy-Authenticate` response header.
    public static let proxyAuthenticate: Self = "Proxy-Authenticate"
    /// The `Proxy-Authorization` request header.
    public static let proxyAuthorization: Self = "Proxy-Authorization"
    /// The `Range` request header.
    public static let range: Self = "Range"
    /// The `Referer` request header.
    public static let referer: Self = "Referer"
    /// The `Retry-After` response header.
    public static let retryAfter: Self = "Retry-After"
    /// The `Sec-WebSocket-Accept` WebSocket response header.
    public static let secWebSocketAccept: Self = "Sec-WebSocket-Accept"
    /// The `Sec-WebSocket-Extensions` WebSocket header.
    public static let secWebSocketExtensions: Self = "Sec-WebSocket-Extensions"
    /// The `Sec-WebSocket-Key` WebSocket request header.
    public static let secWebSocketKey: Self = "Sec-WebSocket-Key"
    /// The `Sec-WebSocket-Protocol` WebSocket header.
    public static let secWebSocketProtocol: Self = "Sec-WebSocket-Protocol"
    /// The `Sec-WebSocket-Version` WebSocket request header.
    public static let secWebSocketVersion: Self = "Sec-WebSocket-Version"
    /// The `Server` response header.
    public static let server: Self = "Server"
    /// The `Set-Cookie` response header.
    public static let setCookie: Self = "Set-Cookie"
    /// The `Strict-Transport-Security` response header.
    public static let strictTransportSecurity: Self = "Strict-Transport-Security"
    /// The `TE` request header.
    public static let te: Self = "TE"
    /// The `Trailer` request or response header.
    public static let trailer: Self = "Trailer"
    /// The `Transfer-Encoding` request or response header.
    public static let transferEncoding: Self = "Transfer-Encoding"
    /// The `Upgrade` request or response header.
    public static let upgrade: Self = "Upgrade"
    /// The `User-Agent` request header.
    public static let userAgent: Self = "User-Agent"
    /// The `Vary` response header.
    public static let vary: Self = "Vary"
    /// The `Via` request or response header.
    public static let via: Self = "Via"
    /// The `Warning` request or response header.
    public static let warning: Self = "Warning"
    /// The `WWW-Authenticate` response header.
    public static let wwwAuthenticate: Self = "WWW-Authenticate"
    /// The `X-Content-Type-Options` response header.
    public static let xContentTypeOptions: Self = "X-Content-Type-Options"
    /// The `X-Forwarded-For` de-facto forwarding header.
    public static let xForwardedFor: Self = "X-Forwarded-For"
    /// The `X-Forwarded-Host` de-facto forwarding header.
    public static let xForwardedHost: Self = "X-Forwarded-Host"
    /// The `X-Forwarded-Proto` de-facto forwarding header.
    public static let xForwardedProto: Self = "X-Forwarded-Proto"
    /// The `X-Frame-Options` response header.
    public static let xFrameOptions: Self = "X-Frame-Options"
    /// The `X-Requested-With` de-facto request header.
    public static let xRequestedWith: Self = "X-Requested-With"
}
// swiftlint:enable identifier_name
