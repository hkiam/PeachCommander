// SPDX-License-Identifier: Apache-2.0
// S3XMLTests.swift - The S3 response parsers, on inputs a filesystem cannot hold.
//
// Driver-compiled like S3SignerTests and S3AWSConfigTests, and for the same reason: these are pure
// functions, and the interesting inputs cannot be produced through the fixture. An S3 key is an
// arbitrary byte string — it may not be valid UTF-8, it may contain control characters, and a bucket
// may hold both an object called "docs" and a prefix called "docs/". None of those can exist on APFS,
// so a fixture backed by real files can never present them. Feeding the parser the XML directly can.

import XCTest

final class S3XMLTests: XCTestCase {
    private var dir: URL!

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("s3xml-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    private func runDriver(_ body: String) throws -> [String: String] {
        let swiftc = "/usr/bin/swiftc"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: swiftc), "swiftc unavailable")
        let driverDir = dir.appendingPathComponent("driver", isDirectory: true)
        try FileManager.default.createDirectory(at: driverDir, withIntermediateDirectories: true)
        try Data(body.utf8).write(to: driverDir.appendingPathComponent("main.swift"))

        let binary = dir.appendingPathComponent("xml")
        let build = Process()
        build.executableURL = URL(fileURLWithPath: swiftc)
        build.arguments = ["-O", "-o", binary.path,
                          repoRoot.appendingPathComponent("Plugins/S3/S3XML.swift").path,
                          driverDir.appendingPathComponent("main.swift").path]
        let buildErr = Pipe(); build.standardError = buildErr
        try build.run(); build.waitUntilExit()
        guard build.terminationStatus == 0 else {
            let e = String(data: buildErr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("the S3 parsers did not compile:\n\(e)")
            throw NSError(domain: "S3XMLTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "build failed"])
        }

        let run = Process()
        run.executableURL = binary
        let out = Pipe(); run.standardOutput = out
        try run.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        run.waitUntilExit()
        XCTAssertEqual(run.terminationStatus, 0)

        var result: [String: String] = [:]
        for line in (String(data: data, encoding: .utf8) ?? "").split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            if parts.count == 2 { result[parts[0]] = parts[1] }
        }
        return result
    }

    /// Parse a ListBucketResult and report the entries as `name|d|size` triples.
    private func list(_ xml: String, prefix: String, urlEncoded: Bool = true) throws -> [String: String] {
        try runDriver("""
        import Foundation
        let xml = \"\"\"
        \(xml)
        \"\"\"
        let page = S3ListObjectsParser.parse(Data(xml.utf8), selfPrefix: "\(prefix)",
                                             urlEncoded: \(urlEncoded))
        print("entries\\t" + page.entries.map { "\\($0.name)|\\($0.isDir ? "d" : "f")|\\($0.size)" }
            .joined(separator: " "))
        print("count\\t\\(page.entries.count)")
        print("raw\\t\\(page.rawCount)")
        print("truncated\\t\\(page.isTruncated)")
        print("token\\t\\(page.nextToken ?? "-")")
        """)
    }

    // MARK: - Keys a filesystem cannot hold

    func test_aKeyThatIsNotValidUTF8KeepsItsEncodedForm() throws {
        // An S3 key is an arbitrary byte string. "%C3%28" is not valid UTF-8, so percent-decoding it
        // returns nothing — and returning nothing would drop the object out of the listing entirely,
        // which is the one outcome a file manager must not produce. Showing the encoded form is ugly
        // and honest: the object is there, and it can still be selected and copied.
        let output = try list("""
        <ListBucketResult><Name>b</Name><Prefix></Prefix><IsTruncated>false</IsTruncated>
         <Contents><Key>bad%C3%28name.bin</Key><Size>5</Size></Contents>
         <Contents><Key>good.txt</Key><Size>3</Size></Contents>
        </ListBucketResult>
        """, prefix: "")
        XCTAssertEqual(output["count"], "2", "an undecodable key was dropped from the listing")
        let entries = output["entries"] ?? ""
        XCTAssertTrue(entries.contains("good.txt|f|3"))
        XCTAssertTrue(entries.contains("bad%C3%28name.bin"),
                      "expected the encoded form to survive, got: \(entries)")
    }

    func test_aKeyWithAControlCharacterIsKept() throws {
        // A tab in a key is legal. It must not truncate the name or be mistaken for a separator.
        let output = try list("""
        <ListBucketResult><Name>b</Name><Prefix></Prefix><IsTruncated>false</IsTruncated>
         <Contents><Key>tab%09here.txt</Key><Size>1</Size></Contents>
        </ListBucketResult>
        """, prefix: "")
        XCTAssertEqual(output["count"], "1")
        // Written as an explicit escape. The driver's own output is tab-separated, so a tab inside the
        // value is exactly the case where a lazily-written expectation is wrong about itself — the
        // first version of this line mangled its own expected string and failed against correct code.
        XCTAssertEqual(output["entries"], "tab\u{09}here.txt|f|1")
    }

    func test_anObjectAndAPrefixOfTheSameNameBothAppear() throws {
        // A bucket may hold the object "docs" and the prefix "docs/" at once — impossible on a
        // filesystem, ordinary in S3. Both are real and both must be listed; dropping either loses
        // data, and the panel is what tells them apart by kind.
        let output = try list("""
        <ListBucketResult><Name>b</Name><Prefix></Prefix><IsTruncated>false</IsTruncated>
         <Contents><Key>docs</Key><Size>7</Size></Contents>
         <CommonPrefixes><Prefix>docs/</Prefix></CommonPrefixes>
        </ListBucketResult>
        """, prefix: "")
        XCTAssertEqual(output["count"], "2")
        let entries = output["entries"] ?? ""
        XCTAssertTrue(entries.contains("docs|f|7"), "the object was dropped: \(entries)")
        XCTAssertTrue(entries.contains("docs|d|-1"), "the prefix was dropped: \(entries)")
    }

    func test_theDirectoryOwnMarkerIsNotListedInsideItself() throws {
        // "photos/" as an object, while listing "photos/". Listed, it is a folder inside itself —
        // which in a panel is a chain with no end.
        let output = try list("""
        <ListBucketResult><Name>b</Name><Prefix>photos/</Prefix><IsTruncated>false</IsTruncated>
         <Contents><Key>photos/</Key><Size>0</Size></Contents>
         <Contents><Key>photos/a.jpg</Key><Size>9</Size></Contents>
        </ListBucketResult>
        """, prefix: "photos/")
        XCTAssertEqual(output["entries"], "a.jpg|f|9")
        // But it counted: "the folder exists and is empty" and "there is no such folder" are
        // different answers, and rawCount is the only thing that can tell them apart.
        XCTAssertEqual(output["raw"], "2")
    }

    func test_aSubPrefixMarkerIsNotAlsoListedAsAnEmptyFile() throws {
        // "photos/2006/" arrives in CommonPrefixes AND in Contents when the marker object exists.
        // Taking both shows the folder twice — once as a folder, once as a 0-byte file.
        let output = try list("""
        <ListBucketResult><Name>b</Name><Prefix>photos/</Prefix><IsTruncated>false</IsTruncated>
         <Contents><Key>photos/2006/</Key><Size>0</Size></Contents>
         <CommonPrefixes><Prefix>photos/2006/</Prefix></CommonPrefixes>
        </ListBucketResult>
        """, prefix: "photos/")
        XCTAssertEqual(output["entries"], "2006|d|-1")
    }

    func test_anEmptyPrefixIsDistinguishableFromAMissingOne() throws {
        // Both list zero entries. Only rawCount says which is which, and reading "empty" as "missing"
        // tells the user a folder they can see in the console is not there.
        let empty = try list("""
        <ListBucketResult><Name>b</Name><Prefix>x/</Prefix><IsTruncated>false</IsTruncated>
         <Contents><Key>x/</Key><Size>0</Size></Contents>
        </ListBucketResult>
        """, prefix: "x/")
        XCTAssertEqual(empty["count"], "0")
        XCTAssertEqual(empty["raw"], "1")

        let missing = try list("""
        <ListBucketResult><Name>b</Name><Prefix>y/</Prefix><IsTruncated>false</IsTruncated>
        </ListBucketResult>
        """, prefix: "y/")
        XCTAssertEqual(missing["count"], "0")
        XCTAssertEqual(missing["raw"], "0")
    }

    func test_aPlusInAKeyStaysAPlus() throws {
        // A literal "+" arrives as "%2B" — it is not RFC 3986 unreserved, so every encoding scheme
        // escapes it. This is what makes form-decoding safe: a bare "+" can then only ever have
        // meant a space.
        let output = try list("""
        <ListBucketResult><Name>b</Name><Prefix></Prefix><IsTruncated>false</IsTruncated>
         <Contents><Key>c%2Bd%20e.txt</Key><Size>4</Size></Contents>
        </ListBucketResult>
        """, prefix: "")
        XCTAssertEqual(output["entries"], "c+d e.txt|f|4")
    }

    func test_aSpaceSentAsAPlusIsASpace() throws {
        // What a real server actually sends. MinIO returns the key `odd +name=v~1.txt` as
        // `odd+%2Bname%3Dv%7E1.txt`: space as "+", literal plus as "%2B". Decoding percent-escapes
        // only produced `odd++name`, and the object then appeared under a name that could not be
        // opened. Found by the Docker conformance suite, because the Python fixture had been encoding
        // the same way this decoded — two halves wrong together see nothing.
        let output = try list("""
        <ListBucketResult><Name>b</Name><Prefix></Prefix><IsTruncated>false</IsTruncated>
         <Contents><Key>odd+%2Bname%3Dv%7E1.txt</Key><Size>7</Size></Contents>
        </ListBucketResult>
        """, prefix: "")
        XCTAssertEqual(output["entries"], "odd +name=v~1.txt|f|7")
    }

    func test_anUndecodableKeyIsNotRenamedByTheFallback() throws {
        // The fallback returns the value UNCHANGED, not the half-decoded one: a key that fails to
        // decode must not come back with its "+" already turned into a space, because that name
        // matches nothing on either side.
        let output = try list("""
        <ListBucketResult><Name>b</Name><Prefix></Prefix><IsTruncated>false</IsTruncated>
         <Contents><Key>a+b%C3%28c.bin</Key><Size>2</Size></Contents>
        </ListBucketResult>
        """, prefix: "")
        XCTAssertEqual(output["entries"], "a+b%C3%28c.bin|f|2")
    }

    func test_aTopLevelPrefixEchoIsNotAnEntry() throws {
        // <Prefix> appears twice in the schema with two meanings: the request's prefix at the top
        // level, and a directory inside <CommonPrefixes>. Keying on the element name alone puts the
        // directory being listed inside itself.
        let output = try list("""
        <ListBucketResult><Name>b</Name><Prefix>photos/</Prefix><Delimiter>/</Delimiter>
         <IsTruncated>false</IsTruncated>
         <Contents><Key>photos/a.jpg</Key><Size>1</Size></Contents>
        </ListBucketResult>
        """, prefix: "photos/")
        XCTAssertEqual(output["entries"], "a.jpg|f|1")
    }

    // MARK: - Timestamps and pagination

    func test_bothTimestampFormatsAreUnderstood() throws {
        // The real service sends milliseconds; some S3-compatible servers do not. A parser that knows
        // only one reports every object as modified in 1970, which sorts and displays wrongly with no
        // hint that anything failed.
        let output = try runDriver("""
        import Foundation
        print("millis\\t\\(S3Time.iso("2009-10-12T17:50:30.000Z"))")
        print("plain\\t\\(S3Time.iso("2009-10-12T17:50:30Z"))")
        print("rubbish\\t\\(S3Time.iso("not a date"))")
        print("http\\t\\(S3Time.httpDate("Mon, 12 Oct 2009 17:50:30 GMT"))")
        """)
        XCTAssertEqual(output["millis"], "1255369830")
        XCTAssertEqual(output["plain"], "1255369830")
        XCTAssertEqual(output["rubbish"], "0")
        XCTAssertEqual(output["http"], "1255369830")
    }

    func test_aTruncatedPageCarriesItsToken() throws {
        let output = try list("""
        <ListBucketResult><Name>b</Name><Prefix></Prefix>
         <IsTruncated>true</IsTruncated>
         <NextContinuationToken>1ueGcxLPRx1Tr</NextContinuationToken>
         <Contents><Key>a.txt</Key><Size>1</Size></Contents>
        </ListBucketResult>
        """, prefix: "")
        XCTAssertEqual(output["truncated"], "true")
        XCTAssertEqual(output["token"], "1ueGcxLPRx1Tr")
    }

    // MARK: - Buckets and errors

    func test_theAccountOwnerIsNotABucket() throws {
        // <Owner><DisplayName> sits beside <Buckets> in the same document. A parser keyed on element
        // names alone lists the account as a bucket, and clicking it goes nowhere.
        let output = try runDriver("""
        import Foundation
        let xml = \"\"\"
        <ListAllMyBucketsResult>
         <Owner><ID>abc</ID><DisplayName>owner-name</DisplayName></Owner>
         <Buckets>
          <Bucket><Name>photos</Name><CreationDate>2009-10-12T17:50:30.000Z</CreationDate></Bucket>
         </Buckets>
        </ListAllMyBucketsResult>
        \"\"\"
        let buckets = S3BucketListParser.parse(Data(xml.utf8))
        print("names\\t" + buckets.map(\\.name).joined(separator: ","))
        print("kinds\\t" + buckets.map { $0.isDir ? "d" : "f" }.joined(separator: ","))
        print("sizes\\t" + buckets.map { String($0.size) }.joined(separator: ","))
        """)
        XCTAssertEqual(output["names"], "photos")
        XCTAssertEqual(output["kinds"], "d")
        // A directory has no meaningful size, and -1 is the ABI's word for that.
        XCTAssertEqual(output["sizes"], "-1")
    }

    func test_aRedirectErrorCarriesTheRegionAndEndpoint() throws {
        let output = try runDriver("""
        import Foundation
        let xml = \"\"\"
        <Error><Code>PermanentRedirect</Code><Message>use the specified endpoint</Message>
        <Region>eu-central-1</Region><Endpoint>b.s3.eu-central-1.amazonaws.com</Endpoint>
        <RequestId>REQ1</RequestId></Error>
        \"\"\"
        let e = S3ErrorParser.parse(Data(xml.utf8))
        print("code\\t\\(e?.code ?? "-")")
        print("region\\t\\(e?.region ?? "-")")
        print("endpoint\\t\\(e?.endpoint ?? "-")")
        print("request\\t\\(e?.requestID ?? "-")")
        print("html\\t\\(S3ErrorParser.parse(Data("<html>403</html>".utf8)) == nil ? "nil" : "parsed")")
        print("empty\\t\\(S3ErrorParser.parse(Data()) == nil ? "nil" : "parsed")")
        print("none\\t\\(S3ErrorParser.parse(nil) == nil ? "nil" : "parsed")")
        """)
        XCTAssertEqual(output["code"], "PermanentRedirect")
        XCTAssertEqual(output["region"], "eu-central-1")
        XCTAssertEqual(output["endpoint"], "b.s3.eu-central-1.amazonaws.com")
        XCTAssertEqual(output["request"], "REQ1")
        // A proxy's HTML page, an empty 403, a provider that answers a bare status: none of those is
        // an <Error> document, and pretending otherwise invents a code the caller then branches on.
        XCTAssertEqual(output["html"], "nil")
        XCTAssertEqual(output["empty"], "nil")
        XCTAssertEqual(output["none"], "nil")
    }

    func test_aBatchDeleteReportsTheKeysItDidNotDelete() throws {
        // The call answers 200 even when it deleted nothing; the outcomes are in the body.
        let output = try runDriver("""
        import Foundation
        let xml = \"\"\"
        <DeleteResult>
         <Deleted><Key>gone.txt</Key></Deleted>
         <Error><Key>locked.txt</Key><Code>AccessDenied</Code></Error>
         <Error><Key>other.txt</Key><Code>InternalError</Code></Error>
        </DeleteResult>
        \"\"\"
        print("failed\\t" + S3DeleteResultParser.parse(Data(xml.utf8)).joined(separator: ","))
        print("clean\\t" + S3DeleteResultParser.parse(
            Data("<DeleteResult><Deleted><Key>a</Key></Deleted></DeleteResult>".utf8))
            .joined(separator: ","))
        """)
        XCTAssertEqual(output["failed"], "locked.txt,other.txt")
        XCTAssertEqual(output["clean"] ?? "", "")
    }

    func test_rawKeysKeepTheMarkersARecursiveDeleteNeeds() throws {
        // The opposite shape from a listing: no delimiter, no folding, and the marker objects very
        // much included — they are keys, and a recursive delete that skips them leaves the folder.
        let output = try runDriver("""
        import Foundation
        let xml = \"\"\"
        <ListBucketResult><IsTruncated>false</IsTruncated>
         <Contents><Key>photos/</Key><Size>0</Size></Contents>
         <Contents><Key>photos/2006/</Key><Size>0</Size></Contents>
         <Contents><Key>photos/2006/a.jpg</Key><Size>9</Size></Contents>
        </ListBucketResult>
        \"\"\"
        let page = S3RawKeyParser.parse(Data(xml.utf8), urlEncoded: false)
        print("keys\\t" + page.keys.joined(separator: ","))
        """)
        XCTAssertEqual(output["keys"], "photos/,photos/2006/,photos/2006/a.jpg")
    }
}
