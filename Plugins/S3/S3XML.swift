// SPDX-License-Identifier: Apache-2.0
// S3XML.swift — parsers for the S3 responses this plugin reads.
//
// `XMLParser` with explicit state rather than a generic tree: the responses are small and their
// shapes are fixed, and the one thing that actually bites is that the same element name means
// different things in different places. `<Prefix>` is the request's prefix at the top level of a
// ListBucketResult and a *directory* inside `<CommonPrefixes>`; a parser that keys on the element
// name alone reports the folder you are standing in as a folder inside itself.

import Foundation

/// One entry from a listing — a bucket, a common prefix, or an object.
struct S3Entry {
    let name: String          // leaf name, never a path
    let size: Int64           // -1 for directories
    let modified: Int64       // Unix epoch seconds, 0 if unknown
    let isDir: Bool
    let storageClass: String
    let etag: String
}

/// What S3 said when it refused. `code` is the machine-readable half and the only part worth
/// branching on — the message is prose and varies by provider.
struct S3ErrorBody {
    let code: String
    let message: String
    /// Set on a redirect: the region the bucket actually lives in.
    let region: String?
    let endpoint: String?
    let requestID: String?
}

/// Shared date handling for the two timestamp formats S3 uses.
enum S3Time {
    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }
    // Listings use fractional seconds; some S3-compatible servers leave them out, and a parser that
    // only knows one of the two silently reports every object as modified in 1970.
    private static let withMillis = make("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
    private static let withoutMillis = make("yyyy-MM-dd'T'HH:mm:ss'Z'")
    /// HTTP date, as `Last-Modified` on a HEAD response.
    private static let http: DateFormatter = {
        let f = make("EEE, dd MMM yyyy HH:mm:ss zzz")
        f.timeZone = TimeZone(identifier: "GMT")
        return f
    }()

    static func iso(_ s: String) -> Int64 {
        if let d = withMillis.date(from: s) { return Int64(d.timeIntervalSince1970) }
        if let d = withoutMillis.date(from: s) { return Int64(d.timeIntervalSince1970) }
        return 0
    }

    static func httpDate(_ s: String) -> Int64 {
        http.date(from: s).map { Int64($0.timeIntervalSince1970) } ?? 0
    }
}

/// Base delegate that accumulates character data per element. `foundCharacters` can be called more
/// than once for one element — an entity reference or a buffer boundary splits it — so a delegate
/// that reads the value on the *start* of the next element loses half of it.
class S3ParserBase: NSObject, XMLParserDelegate {
    var text = ""
    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
}

// MARK: - ListAllMyBucketsResult

/// The bucket list, which is what the root of the mount shows.
final class S3BucketListParser: S3ParserBase {
    private var buckets: [S3Entry] = []
    private var name: String?
    private var created: Int64 = 0
    private var inBucket = false

    static func parse(_ data: Data) -> [S3Entry] {
        let d = S3BucketListParser()
        let p = XMLParser(data: data)
        p.shouldProcessNamespaces = true
        p.delegate = d
        p.parse()
        return d.buckets
    }

    func parser(_ parser: XMLParser, didStartElement e: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        text = ""
        if e == "Bucket" { inBucket = true; name = nil; created = 0 }
    }

    func parser(_ parser: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch e {
        case "Name" where inBucket: name = v
        case "CreationDate" where inBucket: created = S3Time.iso(v)
        case "Bucket":
            if let name, !name.isEmpty {
                buckets.append(S3Entry(name: name, size: -1, modified: created,
                                       isDir: true, storageClass: "", etag: ""))
            }
            inBucket = false
        default: break
        }
        text = ""
    }
}

// MARK: - ListBucketResult (ListObjectsV2)

/// One page of a ListObjectsV2 response.
struct S3ListPage {
    /// What the panel should show: the self-marker dropped, sub-prefix markers de-duplicated.
    let entries: [S3Entry]
    let isTruncated: Bool
    let nextToken: String?
    /// How many `<Contents>` and `<CommonPrefixes>` elements the server actually sent, before any
    /// filtering.
    ///
    /// The distinction `entries` cannot make. An empty `entries` means either "this directory is
    /// empty" or "there is no such directory", and those are not the same answer — a prefix that
    /// exists only as its own zero-byte marker sends exactly one element and shows zero entries, and
    /// reading that as "no such directory" tells the user a folder they can see in the console is
    /// not there.
    let rawCount: Int
}

final class S3ListObjectsParser: S3ParserBase {
    /// The request's own prefix, so the marker object for the directory being listed can be dropped.
    private let selfPrefix: String
    /// Whether values arrive percent-encoded (`encoding-type=url` was asked for).
    private let urlEncoded: Bool

    private var entries: [S3Entry] = []
    private var truncated = false
    private var token: String?
    private var rawCount = 0

    private var inContents = false
    private var inCommonPrefixes = false
    private var key = ""
    private var size: Int64 = 0
    private var modified: Int64 = 0
    private var storageClass = ""
    private var etag = ""

    private init(selfPrefix: String, urlEncoded: Bool) {
        self.selfPrefix = selfPrefix
        self.urlEncoded = urlEncoded
    }

    static func parse(_ data: Data, selfPrefix: String, urlEncoded: Bool) -> S3ListPage {
        let d = S3ListObjectsParser(selfPrefix: selfPrefix, urlEncoded: urlEncoded)
        let p = XMLParser(data: data)
        p.shouldProcessNamespaces = true
        p.delegate = d
        p.parse()
        return S3ListPage(entries: d.entries, isTruncated: d.truncated,
                          nextToken: d.token, rawCount: d.rawCount)
    }

    private func decode(_ s: String) -> String {
        guard urlEncoded else { return s }
        // A key can contain a literal "+" and S3 does not encode it as a space here, so only
        // percent-decoding is right — form-decoding would rename the file.
        return s.removingPercentEncoding ?? s
    }

    func parser(_ parser: XMLParser, didStartElement e: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        text = ""
        switch e {
        case "Contents":
            inContents = true
            key = ""; size = 0; modified = 0; storageClass = ""; etag = ""
        case "CommonPrefixes":
            inCommonPrefixes = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch e {
        case "IsTruncated" where !inContents: truncated = (v == "true")
        case "NextContinuationToken": token = v.isEmpty ? nil : v
        case "Key" where inContents: key = decode(v)
        case "Size" where inContents: size = Int64(v) ?? 0
        case "LastModified" where inContents: modified = S3Time.iso(v)
        case "StorageClass" where inContents: storageClass = v
        case "ETag" where inContents: etag = v.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        case "Contents":
            inContents = false
            rawCount += 1
            addObject()
        // Only inside CommonPrefixes. The top-level <Prefix> echoes the request, and treating it as
        // an entry puts the directory being listed inside itself.
        case "Prefix" where inCommonPrefixes:
            rawCount += 1
            addDirectory(decode(v))
        case "CommonPrefixes":
            inCommonPrefixes = false
        default: break
        }
        text = ""
    }

    private func addObject() {
        guard !key.isEmpty else { return }
        // The zero-byte marker object that stands for the directory itself. S3 has no directories,
        // so "photos/" is how one is made to exist — and listing it as a child of itself is how a
        // panel ends up showing an endless chain of the same folder.
        guard key != selfPrefix else { return }
        // A marker for a *sub*directory ("photos/2006/") also arrives in Contents when it exists as
        // a real object. CommonPrefixes already reported that directory, so taking this one too
        // shows the folder twice — once as a folder and once as an empty file.
        guard !key.hasSuffix("/") else { return }
        let leaf = key.hasPrefix(selfPrefix) ? String(key.dropFirst(selfPrefix.count)) : key
        guard !leaf.isEmpty, !leaf.contains("/") else { return }
        entries.append(S3Entry(name: leaf, size: size, modified: modified,
                               isDir: false, storageClass: storageClass, etag: etag))
    }

    private func addDirectory(_ prefix: String) {
        var p = prefix
        if p.hasSuffix("/") { p.removeLast() }
        let leaf = p.hasPrefix(selfPrefix) ? String(p.dropFirst(selfPrefix.count)) : p
        guard !leaf.isEmpty, !leaf.contains("/") else { return }
        entries.append(S3Entry(name: leaf, size: -1, modified: 0,
                               isDir: true, storageClass: "", etag: ""))
    }
}

// MARK: - Error

final class S3ErrorParser: S3ParserBase {
    private var code = ""
    private var message = ""
    private var region: String?
    private var endpoint: String?
    private var requestID: String?

    /// Parse an `<Error>` body. Returns nil when the body is not one — a proxy's HTML error page, an
    /// empty 403, or a provider that answers a bare status. The caller then falls back to the HTTP
    /// status, which is the only thing it can trust.
    static func parse(_ data: Data?) -> S3ErrorBody? {
        guard let data, !data.isEmpty else { return nil }
        let d = S3ErrorParser()
        let p = XMLParser(data: data)
        p.shouldProcessNamespaces = true
        p.delegate = d
        p.parse()
        guard !d.code.isEmpty else { return nil }
        return S3ErrorBody(code: d.code, message: d.message,
                           region: d.region, endpoint: d.endpoint, requestID: d.requestID)
    }

    func parser(_ parser: XMLParser, didStartElement e: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        text = ""
    }

    func parser(_ parser: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch e {
        case "Code": code = v
        case "Message": message = v
        case "Region": region = v.isEmpty ? nil : v
        case "Endpoint": endpoint = v.isEmpty ? nil : v
        case "RequestId": requestID = v.isEmpty ? nil : v
        default: break
        }
        text = ""
    }
}

// MARK: - Multipart

/// `<InitiateMultipartUploadResult>` — the one field that matters is the upload id.
final class S3MultipartStartParser: S3ParserBase {
    private var uploadID = ""

    static func parse(_ data: Data?) -> String? {
        guard let data else { return nil }
        let d = S3MultipartStartParser()
        let p = XMLParser(data: data)
        p.shouldProcessNamespaces = true
        p.delegate = d
        p.parse()
        return d.uploadID.isEmpty ? nil : d.uploadID
    }

    func parser(_ parser: XMLParser, didStartElement e: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        text = ""
    }

    func parser(_ parser: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
        if e == "UploadId" { uploadID = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        text = ""
    }
}

/// `<DeleteResult>` — specifically the `<Error>` entries in it.
///
/// A batch delete answers 200 even when it deleted nothing: the per-key outcomes are in the body.
/// Reading only the status is how "deleted" gets reported for keys that are still there.
final class S3DeleteResultParser: S3ParserBase {
    private var failedKeys: [String] = []
    private var inError = false
    private var key = ""

    static func parse(_ data: Data?) -> [String] {
        guard let data else { return [] }
        let d = S3DeleteResultParser()
        let p = XMLParser(data: data)
        p.shouldProcessNamespaces = true
        p.delegate = d
        p.parse()
        return d.failedKeys
    }

    func parser(_ parser: XMLParser, didStartElement e: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        text = ""
        if e == "Error" { inError = true; key = "" }
    }

    func parser(_ parser: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch e {
        case "Key" where inError: key = v
        case "Error":
            inError = false
            if !key.isEmpty { failedKeys.append(key) }
        default: break
        }
        text = ""
    }
}

/// Every key under a prefix, for a recursive delete or a prefix rename.
///
/// Distinct from `S3ListObjectsParser` because the shape wanted is the opposite one: no delimiter, no
/// folding into directories, and the marker objects very much included — they are keys, and a
/// recursive delete that skips them leaves the folder behind.
final class S3RawKeyParser: S3ParserBase {
    private var keys: [String] = []
    private var truncated = false
    private var token: String?
    private var inContents = false
    private let urlEncoded: Bool

    private init(urlEncoded: Bool) { self.urlEncoded = urlEncoded }

    struct Page {
        let keys: [String]
        let isTruncated: Bool
        let nextToken: String?
    }

    static func parse(_ data: Data, urlEncoded: Bool) -> Page {
        let d = S3RawKeyParser(urlEncoded: urlEncoded)
        let p = XMLParser(data: data)
        p.shouldProcessNamespaces = true
        p.delegate = d
        p.parse()
        return Page(keys: d.keys, isTruncated: d.truncated, nextToken: d.token)
    }

    func parser(_ parser: XMLParser, didStartElement e: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        text = ""
        if e == "Contents" { inContents = true }
    }

    func parser(_ parser: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch e {
        case "IsTruncated" where !inContents: truncated = (v == "true")
        case "NextContinuationToken": token = v.isEmpty ? nil : v
        case "Key" where inContents:
            let decoded = urlEncoded ? (v.removingPercentEncoding ?? v) : v
            if !decoded.isEmpty { keys.append(decoded) }
        case "Contents": inContents = false
        default: break
        }
        text = ""
    }
}
