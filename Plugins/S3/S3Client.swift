// SPDX-License-Identifier: Apache-2.0
// S3Client.swift — the HTTP half: addressing, signing, sending, and what an error means.
//
// Every call is synchronous, because the PFX ABI is: `PfxFindFirst` returns a handle or NULL, and
// there is nowhere to put a continuation. Blocking is safe here for the reason `pfx.h` states — the
// host calls one connection from one dedicated serial queue and never from two threads at once — and
// it is the same bargain `Plugins/WebDAV/webdav.swift` makes.
//
// Object transfers do NOT go through `Data`. An S3 object is routinely larger than memory, and the
// host hands us a destination path precisely so that the bytes never have to be held. Metadata
// requests (listings, HEAD, small XML) do use `Data`: they are bounded by the protocol.

import Foundation
import CryptoKit

// MARK: - Where we are talking to

/// The endpoint and how it addresses buckets.
///
/// `pathStyle` is not a preference. AWS wants `bucket.s3.region.amazonaws.com`; MinIO, Ceph and
/// anything reached by IP or by a name without a wildcard certificate can only do
/// `host/bucket/key`. Guessing wrong produces a DNS failure or a 404 that looks like a missing
/// bucket, so it is a field the user can see and set.
struct S3Endpoint {
    var host: String            // may include a port, e.g. "127.0.0.1:9000"
    var useTLS: Bool
    var region: String
    var pathStyle: Bool

    var scheme: String { useTLS ? "https" : "http" }

    /// The Host header (and URL authority) for a request against `bucket`.
    func authority(bucket: String?) -> String {
        guard let bucket, !bucket.isEmpty, !pathStyle else { return host }
        return "\(bucket).\(host)"
    }

    /// The request path — which is also what gets signed, so the two cannot be derived separately.
    func path(bucket: String?, key: String) -> String {
        let leadingKey = key.hasPrefix("/") ? String(key.dropFirst()) : key
        guard let bucket, !bucket.isEmpty else { return "/" }
        if pathStyle {
            return leadingKey.isEmpty ? "/\(bucket)" : "/\(bucket)/\(leadingKey)"
        }
        return leadingKey.isEmpty ? "/" : "/\(leadingKey)"
    }
}

// MARK: - One response

struct S3Response {
    let status: Int
    let data: Data?
    let headers: [String: String]
    /// The parsed `<Error>` body, when there was one.
    let error: S3ErrorBody?

    var ok: Bool { (200...299).contains(status) }

    func header(_ name: String) -> String? {
        let wanted = name.lowercased()
        for (k, v) in headers where k.lowercased() == wanted { return v }
        return nil
    }
}

// MARK: - The connection

final class S3Connection {
    var endpoint: S3Endpoint
    let credentials: S3Credentials
    /// The label the drive chip is built from, e.g. "s3:127.0.0.1:9000".
    let displayHost: String

    /// The last PC_E_* worth reporting, for `PfxLastError`.
    ///
    /// Set in one place — `send` — for the reason the WebDAV plugin learned: a reason that has to be
    /// remembered at each call site is a reason that will be forgotten at one of them, and the
    /// symptom is a dead connection reported as a missing directory.
    var lastError: Int32 = Int32(PC_OK)

    /// The reason the *user* should be told, when a status code alone would mislead. A
    /// `SignatureDoesNotMatch` is a configuration mistake, not "permission denied", and the
    /// difference is the difference between fixing it and asking an administrator for access.
    var lastMessage: String = ""

    private let session: URLSession
    private let transfers: S3TransferDelegate
    private let transferSession: URLSession

    /// Progress for the transfer currently running, if the host asked for it. One slot, because the
    /// host serialises calls on a connection — the same reason `PFXProgressSink` has one.
    var progress: ((String, Int) -> Bool)?

    /// Where each bucket actually lives, learned from a redirect or a HEAD.
    ///
    /// A connection has one configured region, and buckets do not have to be in it. AWS answers a
    /// request signed for the wrong region with a 301, or with a 400 whose code says the signature
    /// was built for the wrong one — and it names the right region in the body or in
    /// `x-amz-bucket-region`. Learned once per bucket rather than per request, because the answer
    /// does not change and paying a redirect on every listing is a doubled request count on a
    /// service that charges per request.
    ///
    /// Not locked: `pfx.h` guarantees the host calls one connection from one thread at a time, and
    /// nothing on a URLSession callback thread touches this.
    private var bucketRegions: [String: String] = [:]
    private var bucketHosts: [String: String] = [:]

    init(endpoint: S3Endpoint, credentials: S3Credentials, displayHost: String) {
        self.endpoint = endpoint
        self.credentials = credentials
        self.displayHost = displayHost
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = ["User-Agent": "PeachCommander-S3/1"]
        config.timeoutIntervalForRequest = 60
        // A transfer of a large object legitimately takes longer than a listing, and a resource
        // timeout that applies to both either cuts off uploads or lets a dead listing hang.
        config.timeoutIntervalForResource = 3600
        self.session = URLSession(configuration: config)
        self.transfers = S3TransferDelegate()
        self.transferSession = URLSession(configuration: config, delegate: transfers,
                                          delegateQueue: nil)
    }

    func invalidate() {
        session.invalidateAndCancel()
        transferSession.invalidateAndCancel()
    }

    // MARK: Request building

    /// The endpoint to use for `bucket`, with whatever has been learned about where it lives.
    ///
    /// Both halves matter and they are learned together: a bucket in another region needs the other
    /// region in the signature *and*, for virtual-hosted addressing, the other host in the URL.
    /// Fixing only the region produces a signature the right region rejects because the host is
    /// still wrong.
    func resolvedEndpoint(for bucket: String?) -> S3Endpoint {
        guard let bucket, !bucket.isEmpty else { return endpoint }
        var resolved = endpoint
        if let region = bucketRegions[bucket] { resolved.region = region }
        if let host = bucketHosts[bucket] { resolved.host = host }
        return resolved
    }

    /// Remember where `bucket` lives. `host` may be nil when only the region was reported.
    private func learn(bucket: String, region: String?, host: String?) {
        if let region, !region.isEmpty { bucketRegions[bucket] = region }
        if let host, !host.isEmpty {
            // The <Endpoint> a redirect names is the *bucket's* virtual-hosted address, so the
            // leading "<bucket>." has to come off before it can be used as an endpoint host —
            // otherwise the next request asks for "bucket.bucket.s3...".
            var trimmed = host
            let prefix = bucket + "."
            if trimmed.hasPrefix(prefix) { trimmed = String(trimmed.dropFirst(prefix.count)) }
            bucketHosts[bucket] = trimmed
        } else if let region, !region.isEmpty, endpoint.host.hasSuffix(".amazonaws.com") {
            // AWS without an explicit endpoint: the regional host is derivable, and deriving it is
            // what makes a redirect on a HEAD (which has no body to carry <Endpoint>) usable.
            bucketHosts[bucket] = "s3.\(region).amazonaws.com"
        }
    }

    /// Learn from a region redirect and say whether retrying is worth it.
    ///
    /// Used by the transfer paths, which build their own requests and so cannot go through `send`'s
    /// retry. Without this, an object in a bucket outside the connection's region could be listed —
    /// the listing goes through `send` — and then not downloaded, which is a confusing place to fail.
    func followRegionRedirect(bucket: String, response: S3Response) -> Bool {
        guard Self.isRegionRedirect(response) else { return false }
        let region = response.error?.region ?? response.header("x-amz-bucket-region")
        guard let region, !region.isEmpty, region != resolvedEndpoint(for: bucket).region else {
            return false
        }
        learn(bucket: bucket, region: region, host: response.error?.endpoint)
        return true
    }

    /// True when this response is AWS saying "that bucket is somewhere else".
    static func isRegionRedirect(_ response: S3Response) -> Bool {
        let code = response.error?.code ?? ""
        return response.status == 301 || response.status == 307
            || (response.status == 400 && code == "AuthorizationHeaderMalformed")
    }

    private func url(bucket: String?, key: String, query: [(String, String)]) -> URL? {
        let endpoint = resolvedEndpoint(for: bucket)
        let path = endpoint.path(bucket: bucket, key: key)
        // Built from the *canonical* forms so that what is signed is byte-for-byte what is sent.
        // Handing the raw path to URLComponents and the encoded one to the signer is how a key with
        // a space or a "+" starts answering SignatureDoesNotMatch.
        var s = "\(endpoint.scheme)://\(endpoint.authority(bucket: bucket))"
            + S3Signer.canonicalURI(path: path)
        if !query.isEmpty { s += "?" + S3Signer.canonicalQuery(query) }
        return URL(string: s)
    }

    /// Build a signed request. `payloadHash` must be the hex SHA-256 of the body that will be sent.
    ///
    /// Internal rather than private so that the write operations in `S3Write.swift` can build their
    /// own requests. They need to, because a multipart part carries a body this class never sees as a
    /// whole and a copy carries no body at all.
    func request(_ method: String, bucket: String?, key: String,
                         query: [(String, String)], extraHeaders: [String: String],
                         payloadHash: String) -> URLRequest? {
        guard let url = url(bucket: bucket, key: key, query: query) else { return nil }
        let endpoint = resolvedEndpoint(for: bucket)
        let now = Date()
        var headers = extraHeaders
        headers["host"] = endpoint.authority(bucket: bucket)
        headers["x-amz-date"] = S3Signer.amzDate(now)
        headers["x-amz-content-sha256"] = payloadHash
        if let token = credentials.sessionToken, !token.isEmpty {
            // In the signed set, not merely sent: an unsigned security token is rejected.
            headers["x-amz-security-token"] = token
        }

        var r = URLRequest(url: url)
        r.httpMethod = method
        if let signed = S3Signer.sign(method: method,
                                      path: endpoint.path(bucket: bucket, key: key),
                                      query: query, headers: headers, payloadHash: payloadHash,
                                      credentials: credentials, region: endpoint.region, date: now) {
            headers["Authorization"] = signed.authorization
        }
        // `host` is set by URLSession itself, and setting it by hand makes it appear twice on some
        // paths. It still had to be in the signed set above, which is the asymmetry to remember.
        headers.removeValue(forKey: "host")
        for (k, v) in headers { r.setValue(v, forHTTPHeaderField: k) }
        return r
    }

    // MARK: Sending

    /// Send a metadata request and read the whole (bounded) body.
    ///
    /// `redirectsLeft` is how a bucket in another region is followed. Not a general redirect follower:
    /// exactly one retry, and only after learning the region from the answer, because the *only*
    /// thing that changes is the signature and the host. Retrying without learning would send the
    /// same wrong request again.
    func send(_ method: String, bucket: String? = nil, key: String = "",
              query: [(String, String)] = [], headers: [String: String] = [:],
              body: Data? = nil, redirectsLeft: Int = 1) -> S3Response {
        let payload = body.map { S3Signer.sha256Hex($0) } ?? S3Signer.emptyPayload
        var extra = headers
        if let body { extra["content-length"] = String(body.count) }
        guard var r = request(method, bucket: bucket, key: key, query: query,
                              extraHeaders: extra, payloadHash: payload) else {
            lastError = Int32(PC_E_BAD_DATA)
            return S3Response(status: 0, data: nil, headers: [:], error: nil)
        }
        r.httpBody = body

        let sem = DispatchSemaphore(value: 0)
        var data: Data?
        var status = 0
        var responseHeaders: [String: String] = [:]
        session.dataTask(with: r) { d, resp, _ in
            data = d
            if let http = resp as? HTTPURLResponse {
                status = http.statusCode
                for (k, v) in http.allHeaderFields {
                    if let key = k as? String, let value = v as? String { responseHeaders[key] = value }
                }
            }
            sem.signal()
        }.resume()
        sem.wait()

        // A body is only an error document when the status says so. A 200 listing also parses as
        // "no <Code> element", but asking is wasted work and, worse, a bucket that legitimately
        // contains a key called "Code" is not an error.
        let parsed = (200...299).contains(status) ? nil : S3ErrorParser.parse(data)
        let response = S3Response(status: status, data: data, headers: responseHeaders, error: parsed)

        if let bucket, redirectsLeft > 0, Self.isRegionRedirect(response) {
            // The region arrives two ways and both have to be read: in the <Error> body, and in
            // `x-amz-bucket-region` — which is the only one a HEAD can carry, since a HEAD has no
            // body at all.
            let region = response.error?.region ?? response.header("x-amz-bucket-region")
            if let region, !region.isEmpty, region != resolvedEndpoint(for: bucket).region {
                learn(bucket: bucket, region: region, host: response.error?.endpoint)
                return send(method, bucket: bucket, key: key, query: query, headers: headers,
                            body: body, redirectsLeft: redirectsLeft - 1)
            }
        }

        record(response)
        return response
    }

    /// Download an object straight to `destination`, reporting progress and honouring an abort.
    func download(bucket: String, key: String, to destination: URL, name: String,
                  redirectsLeft: Int = 1) -> S3Response {
        guard let r = request("GET", bucket: bucket, key: key, query: [],
                              extraHeaders: [:], payloadHash: S3Signer.emptyPayload) else {
            lastError = Int32(PC_E_BAD_DATA)
            return S3Response(status: 0, data: nil, headers: [:], error: nil)
        }
        let outcome = transfers.run(session: transferSession, request: r, name: name,
                                    progress: progress) { temp in
            // Moved rather than copied, and the stale target removed first: the host may hand us a
            // path a previous attempt already half-wrote.
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: temp, to: destination)
        }
        // A failed GET writes an <Error> body, and the delegate kept it precisely so this can say
        // which failure it was rather than "the download did not work".
        let response = S3Response(status: outcome.status, data: outcome.errorBody,
                                  headers: outcome.headers,
                                  error: (200...299).contains(outcome.status)
                                      ? nil : S3ErrorParser.parse(outcome.errorBody))
        if redirectsLeft > 0, !outcome.aborted,
           followRegionRedirect(bucket: bucket, response: response) {
            return download(bucket: bucket, key: key, to: destination, name: name,
                            redirectsLeft: redirectsLeft - 1)
        }
        record(response, aborted: outcome.aborted)
        return response
    }

    /// Upload a local file to `key` in one PUT, reporting progress and honouring an abort.
    func putFile(bucket: String, key: String, from source: URL, name: String,
                 extraHeaders: [String: String], redirectsLeft: Int = 1) -> S3Response {
        let hash: String
        do { hash = try Self.sha256HexOfFile(source) }
        catch {
            lastError = Int32(PC_E_EOPEN)
            lastMessage = L("The file could not be read.")
            return S3Response(status: 0, data: nil, headers: [:], error: nil)
        }
        var headers = extraHeaders
        let size = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size])
            .flatMap { $0 as? NSNumber }?.int64Value ?? 0
        headers["content-length"] = String(size)
        guard let r = request("PUT", bucket: bucket, key: key, query: [],
                              extraHeaders: headers, payloadHash: hash) else {
            lastError = Int32(PC_E_BAD_DATA)
            return S3Response(status: 0, data: nil, headers: [:], error: nil)
        }
        let outcome = transfers.upload(session: transferSession, request: r,
                                       file: source, name: name, progress: progress)
        let response = S3Response(status: outcome.status, data: outcome.errorBody,
                                  headers: outcome.headers,
                                  error: (200...299).contains(outcome.status)
                                      ? nil : S3ErrorParser.parse(outcome.errorBody))
        if redirectsLeft > 0, !outcome.aborted,
           followRegionRedirect(bucket: bucket, response: response) {
            return putFile(bucket: bucket, key: key, from: source, name: name,
                           extraHeaders: extraHeaders, redirectsLeft: redirectsLeft - 1)
        }
        record(response, aborted: outcome.aborted)
        return response
    }

    /// The hex SHA-256 of a file, read in chunks.
    ///
    /// SigV4 needs the payload hash before the first byte is sent, so the file is read twice — once
    /// to hash, once to send. That is the price of a signed payload; the alternative,
    /// `UNSIGNED-PAYLOAD`, is accepted only over HTTPS and gives up the integrity check that catches
    /// a file changing under us mid-upload.
    static func sha256HexOfFile(_ url: URL) throws -> String {
        var hasher = SHA256()
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Error interpretation

    private func record(_ response: S3Response, aborted: Bool = false) {
        lastMessage = ""
        if aborted { lastError = Int32(PC_E_EABORTED); return }
        lastError = Self.pcError(response, message: &lastMessage,
                                 anonymous: credentials.isAnonymous)
        if lastError == Int32(PC_OK), !response.ok {
            lastError = Int32(PC_E_BAD_DATA)
        }
    }

    /// Map a response onto a PC_E_* code, and say something true about it when the code cannot.
    static func pcError(_ response: S3Response, message: inout String,
                        anonymous: Bool = false) -> Int32 {
        if response.ok { return Int32(PC_OK) }
        let code = response.error?.code ?? ""

        // A bucket in another region, which arrives two different ways: a 301/307 redirect, or a 400
        // whose code says the signature was built for the wrong region. Taken out of the switch below
        // because a `where` on the last of three comma-separated patterns applies only to that one —
        // true here, and unreadable enough that the compiler warns about it.
        let isRegionRedirect = response.status == 301 || response.status == 307
            || (response.status == 400 && code == "AuthorizationHeaderMalformed")
        if isRegionRedirect {
            // The body carries the right region; whether the caller retries there is its decision.
            // What matters here is that this must not read as "no such bucket".
            message = L("This bucket is in a different region.")
            return Int32(PC_E_EOPEN)
        }

        switch response.status {
        // No HTTP response at all: refused, DNS failed, or the socket died. That is the end of the
        // mount rather than a fact about a file, and saying so lets the host leave the drive and
        // name the server instead of reporting the object as damaged.
        case 0:
            message = L("The server did not answer.")
            return Int32(PC_E_CONNECTION_LOST)
        case 403:
            // Without credentials there is no signature to be wrong about, and "the secret key was
            // not accepted" would send the user looking for a key they deliberately did not give.
            // What a 403 means here is that the bucket is not public.
            if anonymous {
                message = L("This bucket is not publicly readable. Connect with an access key.")
                return Int32(PC_E_ECREATE)
            }
            switch code {
            case "SignatureDoesNotMatch":
                // A configuration mistake, not a permission. Reported as "access denied" it sends
                // the user to an administrator for a key they already have and mistyped.
                message = L("The secret key was not accepted. Check the key and the region.")
            case "InvalidAccessKeyId":
                message = L("This access key ID does not exist on the server.")
            case "RequestTimeTooSkewed":
                message = L("This Mac's clock is too far from the server's.")
            default:
                message = L("Access denied.")
            }
            return Int32(PC_E_ECREATE)
        case 404:
            message = code == "NoSuchBucket" ? L("There is no such bucket.") : L("There is no such object.")
            return Int32(PC_E_EOPEN)
        case 409:
            message = code == "BucketNotEmpty"
                ? L("The bucket still contains objects.") : L("The server reported a conflict.")
            return Int32(PC_E_EWRITE)
        case 429, 500, 503:
            message = L("The server is busy or unavailable.")
            return Int32(PC_E_CONNECTION_LOST)
        case 502, 504:
            message = L("The server did not answer.")
            return Int32(PC_E_CONNECTION_LOST)
        default:
            if code == "InvalidObjectState" {
                // Glacier and Deep Archive. The object exists and cannot be read until it has been
                // restored, which is neither "missing" nor "denied".
                message = L("This object is archived and must be restored before it can be read.")
                return Int32(PC_E_NOT_SUPPORTED)
            }
            message = response.error?.message ?? ""
            return Int32(PC_E_BAD_DATA)
        }
    }
}
