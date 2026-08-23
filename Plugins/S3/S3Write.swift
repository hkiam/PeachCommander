// SPDX-License-Identifier: Apache-2.0
// S3Write.swift — creating, uploading, deleting and moving.
//
// The three things S3 does not have, and what stands in for each:
//
//   * **No directories.** A folder is a common prefix inferred from keys, or a zero-byte object whose
//     key ends in "/". Creating one writes that marker; deleting one has to delete every key beneath
//     it, because there is nothing else to delete.
//   * **No rename.** A move is a server-side copy followed by a delete, and a folder move is that
//     for every key under the prefix. Non-atomic by construction, which is why a failure part-way
//     through is reported rather than retried into a half-moved state.
//   * **No append, and a 5 GiB ceiling on a single PUT or copy.** Above that, multipart — and a
//     multipart upload that is neither completed nor aborted leaves parts in the bucket that the
//     user pays for and cannot see. Every failure path aborts.

import Foundation
import CryptoKit
import UniformTypeIdentifiers

extension S3Connection {

    // MARK: - Sizes

    /// Above this, a single PUT becomes a multipart upload.
    ///
    /// S3's own hard limit is 5 GiB, but multipart is worth taking earlier: a failed 4 GiB PUT starts
    /// again from zero. `PC_S3_MULTIPART_THRESHOLD` overrides it, which is how the tests exercise the
    /// multipart path without producing a multi-gigabyte fixture — the alternative is code that ships
    /// having never run.
    static var multipartThreshold: Int64 {
        if let raw = ProcessInfo.processInfo.environment["PC_S3_MULTIPART_THRESHOLD"],
           let value = Int64(raw), value > 0 { return value }
        return 64 * 1024 * 1024
    }

    /// S3 requires every part except the last to be at least 5 MiB, and allows at most 10 000 parts.
    /// So the part size has to grow with the file: 16 MiB covers 160 GB, and beyond that this scales
    /// rather than failing on the part count.
    ///
    /// `PC_S3_PART_SIZE` overrides it for the tests, and it has to exist separately from the
    /// threshold override: with only the threshold lowered, the 5 MiB floor still puts a small test
    /// file in a single part — so the multipart path ran, produced one part, and proved nothing about
    /// reassembly or about a part failing partway. That test passed for the wrong reason until this
    /// knob existed.
    static func partSize(for total: Int64) -> Int {
        if let raw = ProcessInfo.processInfo.environment["PC_S3_PART_SIZE"],
           let value = Int(raw), value > 0 { return value }
        let floorSize = max(Int64(5 * 1024 * 1024), multipartThreshold / 8)
        let needed = (total + 9_999) / 10_000
        return Int(max(floorSize, needed))
    }

    /// The `Content-Type` for a key, from its extension. Nothing else knows: S3 stores what it is
    /// told, and an object uploaded without one is served back as `application/octet-stream` — which
    /// turns a web-hosted image into a download.
    static func contentType(forKey key: String) -> String {
        let ext = (key as NSString).pathExtension
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext),
              let mime = type.preferredMIMEType else { return "application/octet-stream" }
        return mime
    }

    // MARK: - Upload

    /// Upload `source` to `key`, choosing a single PUT or a multipart upload by size.
    func putObject(bucket: String, key: String, from source: URL, name: String) -> S3Response {
        let size = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size])
            .flatMap { $0 as? NSNumber }?.int64Value ?? 0
        let headers = ["content-type": Self.contentType(forKey: key)]
        if size > Self.multipartThreshold {
            return putObjectMultipart(bucket: bucket, key: key, from: source,
                                      name: name, size: size, extraHeaders: headers)
        }
        return putFile(bucket: bucket, key: key, from: source, name: name, extraHeaders: headers)
    }

    private func putObjectMultipart(bucket: String, key: String, from source: URL, name: String,
                                    size: Int64, extraHeaders: [String: String]) -> S3Response {
        let start = send("POST", bucket: bucket, key: key, query: [("uploads", "")],
                         headers: extraHeaders)
        guard start.ok, let uploadID = S3MultipartStartParser.parse(start.data) else {
            return start.ok
                ? S3Response(status: 0, data: nil, headers: [:], error: nil)   // no upload id
                : start
        }

        func abort() {
            // Deliberately ignoring the result: this runs on a path that has already failed, and the
            // failure the caller needs to hear about is the original one. What must not happen is
            // returning without trying — orphaned parts are billed and invisible.
            _ = send("DELETE", bucket: bucket, key: key, query: [("uploadId", uploadID)])
        }

        let chunk = Self.partSize(for: size)
        var etags: [(Int, String)] = []
        var sent: Int64 = 0
        do {
            let handle = try FileHandle(forReadingFrom: source)
            defer { try? handle.close() }
            var number = 1
            while true {
                guard let data = try handle.read(upToCount: chunk), !data.isEmpty else { break }
                let part = send("PUT", bucket: bucket, key: key,
                                query: [("partNumber", String(number)), ("uploadId", uploadID)],
                                body: data)
                guard part.ok, let etag = part.header("ETag") else {
                    abort()
                    return part
                }
                etags.append((number, etag))
                sent += Int64(data.count)
                if let report = progress, size > 0 {
                    // Per part rather than per byte: the parts go up through `send`, which has no
                    // byte-level callback. It is also the only place an abort can be answered.
                    if !report(name, min(100, Int(sent * 100 / size))) {
                        abort()
                        lastError = Int32(PC_E_EABORTED)
                        return S3Response(status: 0, data: nil, headers: [:], error: nil)
                    }
                }
                number += 1
            }
        } catch {
            abort()
            lastError = Int32(PC_E_EOPEN)
            lastMessage = L("The file could not be read.")
            return S3Response(status: 0, data: nil, headers: [:], error: nil)
        }

        guard !etags.isEmpty else {
            abort()
            lastError = Int32(PC_E_EWRITE)
            return S3Response(status: 0, data: nil, headers: [:], error: nil)
        }

        var xml = "<CompleteMultipartUpload>"
        for (number, etag) in etags {
            xml += "<Part><PartNumber>\(number)</PartNumber><ETag>\(etag)</ETag></Part>"
        }
        xml += "</CompleteMultipartUpload>"
        let complete = send("POST", bucket: bucket, key: key, query: [("uploadId", uploadID)],
                            body: Data(xml.utf8))
        // CompleteMultipartUpload can answer 200 and still have failed: S3 keeps the connection open
        // while it assembles the object and writes an <Error> document into a successful response.
        // Reading only the status reports a corrupt or absent object as uploaded.
        if complete.ok, let body = complete.data, let failure = S3ErrorParser.parse(body) {
            abort()
            lastError = Int32(PC_E_EWRITE)
            lastMessage = failure.message
            return S3Response(status: 500, data: body, headers: complete.headers, error: failure)
        }
        if !complete.ok { abort() }
        return complete
    }

    // MARK: - Directories

    /// Create a bucket. Only meaningful at the root of the mount.
    func createBucket(_ bucket: String) -> S3Response {
        // us-east-1 must NOT carry a LocationConstraint, and every other region must. Sending the
        // wrong one of those two is `InvalidLocationConstraint`, and it is the single most common way
        // a first CreateBucket fails.
        var body: Data?
        if endpoint.region != "us-east-1", !endpoint.region.isEmpty {
            body = Data(("<CreateBucketConfiguration>"
                + "<LocationConstraint>\(endpoint.region)</LocationConstraint>"
                + "</CreateBucketConfiguration>").utf8)
        }
        return send("PUT", bucket: bucket, body: body)
    }

    /// Create a folder: a zero-byte object whose key ends in "/".
    func createPrefix(bucket: String, prefix: String) -> S3Response {
        let key = prefix.hasSuffix("/") ? prefix : prefix + "/"
        return send("PUT", bucket: bucket, key: key, body: Data())
    }

    // MARK: - Delete

    func deleteObject(bucket: String, key: String) -> S3Response {
        send("DELETE", bucket: bucket, key: key)
    }

    func deleteBucket(_ bucket: String) -> S3Response {
        send("DELETE", bucket: bucket)
    }

    /// Every key under `prefix`, paged. Includes marker objects, which are keys like any other.
    func allKeys(bucket: String, prefix: String) -> [String]? {
        var out: [String] = []
        var token: String?
        repeat {
            var query: [(String, String)] = [("list-type", "2"), ("max-keys", "1000"),
                                             ("encoding-type", "url")]
            if !prefix.isEmpty { query.append(("prefix", prefix)) }
            if let token, !token.isEmpty { query.append(("continuation-token", token)) }
            let response = send("GET", bucket: bucket, query: query)
            guard response.ok, let data = response.data else { return nil }
            let page = S3RawKeyParser.parse(data, urlEncoded: true)
            out += page.keys
            token = page.isTruncated ? page.nextToken : nil
            // A truncated page that carries no token would loop for ever. The server is wrong, but
            // spinning is not a better answer than stopping.
            if page.isTruncated, page.nextToken == nil { return nil }
        } while token != nil
        return out
    }

    /// Delete a folder: every key under it, in batches.
    ///
    /// Returns the keys that were not deleted. A batch delete answers 200 even when it deleted
    /// nothing — the per-key outcomes are in the body — so the result is read rather than the status.
    func deletePrefix(bucket: String, prefix: String) -> [String]? {
        guard let keys = allKeys(bucket: bucket, prefix: prefix) else { return nil }
        guard !keys.isEmpty else { return [] }
        var failed: [String] = []
        // 1000 per request is the protocol's limit, not a tuning choice.
        for batch in stride(from: 0, to: keys.count, by: 1000).map({ start in
            Array(keys[start..<min(start + 1000, keys.count)])
        }) {
            var xml = "<Delete><Quiet>false</Quiet>"
            for key in batch {
                xml += "<Object><Key>\(Self.xmlEscape(key))</Key></Object>"
            }
            xml += "</Delete>"
            let body = Data(xml.utf8)
            // Content-MD5 is REQUIRED on this call — S3 rejects it outright without one. It is the
            // only request in this plugin that needs MD5, which is why it is computed inline.
            let md5 = Data(Insecure.MD5.hash(data: body)).base64EncodedString()
            let response = send("POST", bucket: bucket, query: [("delete", "")],
                                headers: ["content-md5": md5,
                                          "content-type": "application/xml"],
                                body: body)
            guard response.ok else { return nil }
            failed += S3DeleteResultParser.parse(response.data)
        }
        return failed
    }

    static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - Copy and move

    /// Server-side copy of one object. The bytes never come back to this Mac.
    ///
    /// `sourceBucket` is separate because a move can cross buckets — dragging a folder from one
    /// bucket chip to another is an ordinary thing to do, and assuming one bucket would copy the
    /// wrong object (or, worse, an object of the same name that happens to exist in the target).
    func copyObject(bucket: String, to: String, sourceBucket: String, from: String) -> S3Response {
        // The copy source is a header, and it must be encoded the same way a path is — a key with a
        // space or a "+" in an unencoded x-amz-copy-source is a copy of a different object, or a
        // malformed request. It is NOT part of the canonical URI, so it is encoded by hand here.
        let source = "/" + sourceBucket + S3Signer.canonicalURI(path: "/" + from)
        var headers = ["x-amz-copy-source": source]
        headers["content-type"] = Self.contentType(forKey: to)
        // Copying metadata rather than replacing it: a move should not silently change an object's
        // content type or drop its user metadata.
        headers["x-amz-metadata-directive"] = "COPY"
        let response = send("PUT", bucket: bucket, key: to, headers: headers)
        // CopyObject has the same late-failure shape as CompleteMultipartUpload: 200 with an <Error>
        // body. Believing the status here reports a move that did not happen, and the delete that
        // follows would then lose the object.
        if response.ok, let body = response.data, let failure = S3ErrorParser.parse(body) {
            lastError = Int32(PC_E_EWRITE)
            lastMessage = failure.message
            return S3Response(status: 500, data: body, headers: response.headers, error: failure)
        }
        return response
    }

    /// Move one object: copy, then delete the source. Only if the copy really succeeded.
    func moveObject(bucket: String, to: String, sourceBucket: String, from: String) -> Int32 {
        let copied = copyObject(bucket: bucket, to: to, sourceBucket: sourceBucket, from: from)
        guard copied.ok else {
            var message = ""
            return S3Connection.pcError(copied, message: &message)
        }
        let removed = deleteObject(bucket: sourceBucket, key: from)
        guard removed.ok else {
            // The copy is there and the source is not gone. Reported, and deliberately not rolled
            // back: deleting the copy to "undo" risks losing the only good object if the source
            // delete failed because the source is already gone.
            var message = ""
            lastMessage = L("The object was copied but the original could not be removed.")
            return S3Connection.pcError(removed, message: &message)
        }
        return Int32(PC_OK)
    }

    /// Move a folder: every key under `fromPrefix`, one at a time.
    ///
    /// One at a time and not in parallel, because the host serialises calls on this connection
    /// anyway; and reported at the first failure rather than continuing, because a half-moved folder
    /// with no record of which half is worse than a folder that did not move.
    func movePrefix(bucket: String, to toPrefix: String,
                    sourceBucket: String, from fromPrefix: String) -> Int32 {
        let source = fromPrefix.hasSuffix("/") ? fromPrefix : fromPrefix + "/"
        let target = toPrefix.hasSuffix("/") ? toPrefix : toPrefix + "/"
        guard let keys = allKeys(bucket: sourceBucket, prefix: source) else {
            return lastError == Int32(PC_OK) ? Int32(PC_E_EOPEN) : lastError
        }
        guard !keys.isEmpty else { return Int32(PC_E_EOPEN) }
        for key in keys {
            let suffix = String(key.dropFirst(source.count))
            let rc = moveObject(bucket: bucket, to: target + suffix,
                                sourceBucket: sourceBucket, from: key)
            guard rc == PC_OK else { return rc }
        }
        return Int32(PC_OK)
    }
}
