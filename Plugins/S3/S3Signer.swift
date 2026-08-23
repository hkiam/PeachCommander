// SPDX-License-Identifier: Apache-2.0
// S3Signer.swift — AWS Signature Version 4 for S3 requests.
//
// Written here rather than taken from an SDK. A PFX plugin is a bare `swiftc -emit-library` dylib
// outside the Xcode target graph, so it cannot consume a SwiftPM package without new build
// machinery; and SigV4 for S3 is a few hundred lines of string handling over HMAC-SHA256, which
// CryptoKit already provides. See ADR-012.
//
// The whole file is pure: inputs in, signature out, no URLSession and no clock of its own. That is
// deliberate — the published AWS test vectors are the only way to know a signer is right, and they
// are a set of exact inputs with an exact expected signature. A signer that reads `Date()` or builds
// its own request cannot be held against them.

import Foundation
import CryptoKit

/// What identifies the caller. Anonymous is a real case: a public bucket is read without signing.
struct S3Credentials {
    let accessKeyID: String
    let secretAccessKey: String
    /// Temporary credentials carry one; it must be signed, not merely sent.
    let sessionToken: String?

    var isAnonymous: Bool { accessKeyID.isEmpty || secretAccessKey.isEmpty }

    static let anonymous = S3Credentials(accessKeyID: "", secretAccessKey: "", sessionToken: nil)
}

enum S3Signer {
    /// The payload hash for a body the signer is not given. Accepted by S3 over HTTPS only.
    static let unsignedPayload = "UNSIGNED-PAYLOAD"
    /// SHA-256 of nothing — the payload hash of every request without a body.
    static let emptyPayload = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    // MARK: - Encoding

    /// RFC 3986 unreserved. Everything else is percent-encoded, which is what `UriEncode` means in
    /// the AWS spec — notably including `+`, `=`, `:` and `@`, which `URLComponents` would leave
    /// alone and a signature would then disagree about.
    private static let unreserved = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// Percent-encode one component (a path segment, or a query key or value).
    static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s
    }

    /// The canonical URI for an object key: every segment encoded, the separators left alone.
    ///
    /// S3 is the service that does NOT double-encode the path and does NOT normalise it, so a key
    /// containing "a//b" or "./c" is signed exactly as it is addressed. Getting that wrong produces
    /// `SignatureDoesNotMatch` for precisely the keys a user is least likely to be able to rename.
    static func canonicalURI(path: String) -> String {
        guard !path.isEmpty else { return "/" }
        // Empty segments are kept, which is the whole point: a key really can be "a//b", and the
        // first version of this dropped the empty segment while the comment above claimed it did
        // not. Signing "/a/b" for a request addressed to "/a//b" is `SignatureDoesNotMatch` on
        // exactly the keys a user cannot easily rename.
        var out = ""
        var first = true
        for segment in path.split(separator: "/", omittingEmptySubsequences: false) {
            if !first { out += "/" }
            out += encode(String(segment))
            first = false
        }
        return out
    }

    /// The canonical query string: pairs sorted by encoded name, then by encoded value.
    ///
    /// A parameter with no value still carries its `=` ("?uploads" signs as "uploads="). Sorting is
    /// on the *encoded* forms, not the raw ones, because that is the order AWS re-derives.
    static func canonicalQuery(_ items: [(String, String)]) -> String {
        // Spelled out rather than chained: the chained form type-checks so slowly that the compiler
        // gives up on it, which is a strange thing to leave for the next person to rediscover.
        var encoded: [(String, String)] = []
        encoded.reserveCapacity(items.count)
        for item in items { encoded.append((encode(item.0), encode(item.1))) }
        encoded.sort { left, right in
            left.0 == right.0 ? left.1 < right.1 : left.0 < right.0
        }
        var parts: [String] = []
        parts.reserveCapacity(encoded.count)
        for pair in encoded { parts.append(pair.0 + "=" + pair.1) }
        return parts.joined(separator: "&")
    }

    // MARK: - Hashing

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func hmac(_ key: SymmetricKey, _ message: String) -> SymmetricKey {
        SymmetricKey(data: HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key))
    }

    private static func hmacHex(_ key: SymmetricKey, _ message: String) -> String {
        HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
            .map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Dates

    /// `20130524T000000Z` — the value of `x-amz-date`, and half of the credential scope.
    static func amzDate(_ date: Date) -> String {
        Self.formatter(("yyyyMMdd'T'HHmmss'Z'")).string(from: date)
    }

    /// `20130524` — the scope's date.
    static func dateStamp(_ date: Date) -> String {
        Self.formatter("yyyyMMdd").string(from: date)
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        // POSIX and UTC, not the user's locale: a signer that formats "20130524" in a calendar that
        // is not Gregorian, or an hour that is not UTC, signs a request the server dates elsewhere
        // and rejects as skewed — and it would only fail for some users.
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }

    // MARK: - Signing

    struct Signed {
        /// The `Authorization` header value.
        let authorization: String
        /// The signature on its own — the one thing an AWS test vector states.
        let signature: String
        /// The header list that was signed, in canonical order.
        let signedHeaders: String
    }

    /// Sign one request.
    ///
    /// `headers` must already contain everything that will be sent and is to be signed, including
    /// `host` and `x-amz-date`. Names are matched case-insensitively and canonicalised to lower case.
    ///
    /// Returns nil for anonymous credentials: there is nothing to sign with, and a request to a
    /// public bucket is sent unsigned rather than sent wrong.
    static func sign(method: String,
                     path: String,
                     query: [(String, String)],
                     headers: [String: String],
                     payloadHash: String,
                     credentials: S3Credentials,
                     region: String,
                     service: String = "s3",
                     date: Date) -> Signed? {
        guard !credentials.isAnonymous else { return nil }

        let canonicalHeaderPairs = headers
            .map { (($0.key as String).lowercased(),
                    $0.value.trimmingCharacters(in: .whitespaces)) }
            .sorted { $0.0 < $1.0 }
        let canonicalHeaders = canonicalHeaderPairs.map { "\($0.0):\($0.1)\n" }.joined()
        let signedHeaders = canonicalHeaderPairs.map(\.0).joined(separator: ";")

        let canonicalRequest = [
            method,
            canonicalURI(path: path),
            canonicalQuery(query),
            canonicalHeaders,          // already ends in \n; the blank line after it is the join
            signedHeaders,
            payloadHash,
        ].joined(separator: "\n")

        let stamp = dateStamp(date)
        let scope = "\(stamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate(date),
            scope,
            sha256Hex(Data(canonicalRequest.utf8)),
        ].joined(separator: "\n")

        var key = SymmetricKey(data: Data("AWS4\(credentials.secretAccessKey)".utf8))
        key = hmac(key, stamp)
        key = hmac(key, region)
        key = hmac(key, service)
        key = hmac(key, "aws4_request")
        let signature = hmacHex(key, stringToSign)

        let authorization = "AWS4-HMAC-SHA256 "
            + "Credential=\(credentials.accessKeyID)/\(scope), "
            + "SignedHeaders=\(signedHeaders), "
            + "Signature=\(signature)"
        return Signed(authorization: authorization, signature: signature, signedHeaders: signedHeaders)
    }

    /// Query-signing for a presigned URL: the signature travels in the query, not a header.
    ///
    /// Not used by the browsing path — it is what "copy a shareable link" needs, and it is here
    /// rather than beside that feature because it is the same canonical request with the credential
    /// moved. Keeping the two derivations apart is how they drift.
    static func presignQuery(method: String,
                             path: String,
                             query: [(String, String)],
                             host: String,
                             expiresIn seconds: Int,
                             credentials: S3Credentials,
                             region: String,
                             date: Date) -> [(String, String)]? {
        guard !credentials.isAnonymous else { return nil }
        let scope = "\(dateStamp(date))/\(region)/s3/aws4_request"
        var signedQuery = query
        signedQuery.append(("X-Amz-Algorithm", "AWS4-HMAC-SHA256"))
        signedQuery.append(("X-Amz-Credential", "\(credentials.accessKeyID)/\(scope)"))
        signedQuery.append(("X-Amz-Date", amzDate(date)))
        signedQuery.append(("X-Amz-Expires", String(seconds)))
        signedQuery.append(("X-Amz-SignedHeaders", "host"))
        if let token = credentials.sessionToken, !token.isEmpty {
            signedQuery.append(("X-Amz-Security-Token", token))
        }
        guard let signed = sign(method: method, path: path, query: signedQuery,
                                headers: ["host": host], payloadHash: unsignedPayload,
                                credentials: credentials, region: region, date: date) else { return nil }
        signedQuery.append(("X-Amz-Signature", signed.signature))
        return signedQuery
    }
}
