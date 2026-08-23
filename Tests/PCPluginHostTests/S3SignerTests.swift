// SPDX-License-Identifier: Apache-2.0
// S3SignerTests.swift - The S3 plugin's SigV4 signer against the signatures AWS publishes.
//
// Why this exists separately from S3PluginTests: that file drives the plugin against a fixture, and
// the fixture verifies signatures by recomputing them the same way. Two implementations that agree
// with each other can still both be wrong. The four cases below are the exact inputs and the exact
// signature strings from the "Examples: Signature Calculations" section of the S3 API reference, so
// they are an outside opinion — the only one available without a real AWS account.
//
// The signer is compiled on its own into a small executable rather than being reached through the
// plugin's C ABI. It is deliberately a pure function of its inputs (no clock, no URLSession), and
// that is what makes a published vector usable at all: the same inputs must give the same string.

import XCTest

final class S3SignerTests: XCTestCase {
    private var dir: URL!

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("s3signer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    /// Compile the signer with a driver and return its output, keyed by the driver's labels.
    private func runDriver(_ body: String) throws -> [String: String] {
        let swiftc = "/usr/bin/swiftc"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: swiftc), "swiftc unavailable")
        // Top-level statements are only allowed in a file called main.swift, which is why the driver
        // lives in a directory of its own rather than beside the binary.
        let driverDir = dir.appendingPathComponent("driver", isDirectory: true)
        try FileManager.default.createDirectory(at: driverDir, withIntermediateDirectories: true)
        let main = driverDir.appendingPathComponent("main.swift")
        try Data(body.utf8).write(to: main)

        let binary = dir.appendingPathComponent("signer")
        let build = Process()
        build.executableURL = URL(fileURLWithPath: swiftc)
        build.arguments = ["-O", "-o", binary.path,
                           repoRoot.appendingPathComponent("Plugins/S3/S3Signer.swift").path,
                           main.path]
        let buildErr = Pipe(); build.standardError = buildErr
        try build.run(); build.waitUntilExit()
        guard build.terminationStatus == 0 else {
            let e = String(data: buildErr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            // A compiler that RAN and refused this is a failure, not a skip. The skip belongs to a
            // machine without swiftc; reusing it here means the day S3 signer stops compiling, this
            // file reports success and says nothing.
            XCTFail("S3 signer did not compile:\n\(e)")
            throw NSError(domain: "S3SignerTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "build failed"])
        }

        let run = Process()
        run.executableURL = binary
        let out = Pipe(); run.standardOutput = out
        try run.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        run.waitUntilExit()
        XCTAssertEqual(run.terminationStatus, 0, "the driver did not run to completion")

        var result: [String: String] = [:]
        for line in (String(data: data, encoding: .utf8) ?? "").split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            if parts.count == 2 { result[parts[0]] = parts[1] }
        }
        return result
    }

    // MARK: - The published vectors

    func test_theFourPublishedExamplesProduceThePublishedSignatures() throws {
        let output = try runDriver("""
        import Foundation
        // Every published example is signed at this instant.
        let when = Date(timeIntervalSince1970: 1369353600)   // 2013-05-24T00:00:00Z
        let creds = S3Credentials(accessKeyID: "AKIAIOSFODNN7EXAMPLE",
                                  secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
                                  sessionToken: nil)
        let host = "examplebucket.s3.amazonaws.com"
        let empty = S3Signer.emptyPayload

        func emit(_ label: String, _ s: S3Signer.Signed?) {
            print("\\(label)\\t\\(s?.signature ?? "nil")")
            print("\\(label)-headers\\t\\(s?.signedHeaders ?? "nil")")
        }

        emit("get-object", S3Signer.sign(
            method: "GET", path: "/test.txt", query: [],
            headers: ["host": host, "range": "bytes=0-9",
                      "x-amz-content-sha256": empty, "x-amz-date": "20130524T000000Z"],
            payloadHash: empty, credentials: creds, region: "us-east-1", date: when))

        emit("put-object", S3Signer.sign(
            method: "PUT", path: "/test$file.text", query: [],
            headers: ["host": host, "date": "Fri, 24 May 2013 00:00:00 GMT",
                      "x-amz-date": "20130524T000000Z",
                      "x-amz-storage-class": "REDUCED_REDUNDANCY",
                      "x-amz-content-sha256": "44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072"],
            payloadHash: "44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072",
            credentials: creds, region: "us-east-1", date: when))

        emit("get-lifecycle", S3Signer.sign(
            method: "GET", path: "/", query: [("lifecycle", "")],
            headers: ["host": host, "x-amz-content-sha256": empty, "x-amz-date": "20130524T000000Z"],
            payloadHash: empty, credentials: creds, region: "us-east-1", date: when))

        // Added out of order on purpose: the canonical query is sorted by name, not by the order the
        // caller happened to build it in.
        emit("list-objects", S3Signer.sign(
            method: "GET", path: "/", query: [("prefix", "J"), ("max-keys", "2")],
            headers: ["host": host, "x-amz-content-sha256": empty, "x-amz-date": "20130524T000000Z"],
            payloadHash: empty, credentials: creds, region: "us-east-1", date: when))
        """)

        // GET Object, with a Range header inside the signature.
        XCTAssertEqual(output["get-object"],
                       "f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41")
        XCTAssertEqual(output["get-object-headers"], "host;range;x-amz-content-sha256;x-amz-date")

        // PUT Object. The "$" in the key must be "%24" in the canonical URI; leaving it literal, or
        // double-encoding it, changes the signature and nothing else says so.
        XCTAssertEqual(output["put-object"],
                       "98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd")
        XCTAssertEqual(output["put-object-headers"],
                       "date;host;x-amz-content-sha256;x-amz-date;x-amz-storage-class")

        // A valueless query parameter: "?lifecycle" signs as "lifecycle=", with the "=" present.
        XCTAssertEqual(output["get-lifecycle"],
                       "fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543")

        // Two parameters, sorted by name.
        XCTAssertEqual(output["list-objects"],
                       "34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7")
    }

    // MARK: - Encoding the vectors do not reach

    func test_encodingRulesTheVectorsDoNotCover() throws {
        let output = try runDriver("""
        import Foundation
        func emit(_ label: String, _ value: String) { print("\\(label)\\t\\(value)") }

        emit("dollar", S3Signer.canonicalURI(path: "/test$file.text"))
        emit("space", S3Signer.canonicalURI(path: "/a b/c.txt"))
        emit("plus", S3Signer.canonicalURI(path: "/c+d.txt"))
        emit("double-slash", S3Signer.canonicalURI(path: "/a//b"))
        emit("trailing", S3Signer.canonicalURI(path: "/photos/"))
        emit("root", S3Signer.canonicalURI(path: "/"))
        emit("empty", S3Signer.canonicalURI(path: ""))
        emit("unreserved", S3Signer.canonicalURI(path: "/a-b_c.d~e"))
        emit("unicode", S3Signer.canonicalURI(path: "/Bücher"))
        emit("tilde-not-encoded", S3Signer.encode("~"))
        emit("query", S3Signer.canonicalQuery([("delimiter", "/"), ("prefix", "a b"), ("uploads", "")]))
        emit("query-sorted", S3Signer.canonicalQuery([("b", "2"), ("a", "1"), ("a", "0")]))
        emit("anonymous", S3Signer.sign(method: "GET", path: "/", query: [], headers: [:],
                                        payloadHash: S3Signer.emptyPayload,
                                        credentials: .anonymous, region: "us-east-1",
                                        date: Date(timeIntervalSince1970: 0)) == nil
                                        ? "nil" : "signed")
        emit("amz-date", S3Signer.amzDate(Date(timeIntervalSince1970: 1369353600)))
        emit("date-stamp", S3Signer.dateStamp(Date(timeIntervalSince1970: 1369353600)))
        """)

        XCTAssertEqual(output["dollar"], "/test%24file.text")
        XCTAssertEqual(output["space"], "/a%20b/c.txt")
        // Percent-encoded, not left literal and not turned into a space. A "+" in a key is a "+".
        XCTAssertEqual(output["plus"], "/c%2Bd.txt")
        // S3 is the service that does not normalise the path. "a//b" is a real, addressable key, and
        // collapsing the empty segment signs a request for a different object.
        XCTAssertEqual(output["double-slash"], "/a//b")
        XCTAssertEqual(output["trailing"], "/photos/")
        XCTAssertEqual(output["root"], "/")
        XCTAssertEqual(output["empty"], "/")
        // RFC 3986 unreserved passes through untouched — including "~", which some percent-encoders
        // escape and AWS does not.
        XCTAssertEqual(output["unreserved"], "/a-b_c.d~e")
        XCTAssertEqual(output["tilde-not-encoded"], "~")
        XCTAssertEqual(output["unicode"], "/B%C3%BCcher")
        XCTAssertEqual(output["query"], "delimiter=%2F&prefix=a%20b&uploads=")
        // Sorted by name, then by value.
        XCTAssertEqual(output["query-sorted"], "a=0&a=1&b=2")
        // Nothing to sign with means no Authorization header, not a header signed with an empty key.
        XCTAssertEqual(output["anonymous"], "nil")
        // POSIX locale and UTC. A signer that formats in the user's calendar signs a date the server
        // rejects as skewed, and only for some users.
        XCTAssertEqual(output["amz-date"], "20130524T000000Z")
        XCTAssertEqual(output["date-stamp"], "20130524")
    }
}
