// SPDX-License-Identifier: Apache-2.0
// S3AWSConfigTests.swift - Reading the credentials the AWS CLI already has.
//
// Compiled on its own into a driver, like S3SignerTests, because the parser is a pure function and a
// driver holds it to exact strings. Driving it through the plugin's C ABI instead would mean writing
// files into a fake home directory and inferring the parse from which connection succeeded — a much
// weaker statement about a format whose failures are all quiet: a profile named "profile foo", a
// secret truncated at a '#', a region silently missing.

import XCTest

final class S3AWSConfigTests: XCTestCase {
    private var dir: URL!

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("s3aws-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    /// Compile the config reader (and what it needs) with a driver, and return its tab-separated output.
    ///
    /// The driver takes the fake home through argv rather than through interpolated source, so all
    /// ten tests share one compiled binary instead of compiling eight files each. See SwiftDriver.
    private func runDriver(_ body: String, home: URL) throws -> [String: String] {
        // S3Profiles and S3Client come along because S3AWSConfig builds an `S3Profile` and reads
        // `S3Environment.looksLikeALocalEndpoint`; a stub would be a second implementation to keep in
        // step with the first.
        try SwiftDriver.run(
            label: "s3awsconfig",
            sources: ["S3AWSConfig", "S3Profiles", "S3Client", "S3Signer", "S3XML", "S3Transfer", "S3Write"]
                .map { "Plugins/S3/\($0).swift" } + ["Plugins/SDK/PluginLoc.swift"],
            extraFlags: ["-import-objc-header",
                         repoRoot.appendingPathComponent("Plugins/S3/S3Bridging.h").path,
                         "-Xcc", "-I\(repoRoot.appendingPathComponent("Plugins/SDK").path)",
                         "-framework", "AppKit"],
            body: body,
            arguments: [home.path],
            repoRoot: repoRoot)
    }

    /// Write a fake ~/.aws and report what the reader made of it.
    private func read(credentials: String, config: String) throws -> [String: String] {
        let home = dir.appendingPathComponent("home", isDirectory: true)
        let aws = home.appendingPathComponent(".aws", isDirectory: true)
        try FileManager.default.createDirectory(at: aws, withIntermediateDirectories: true)
        try Data(credentials.utf8).write(to: aws.appendingPathComponent("credentials"))
        try Data(config.utf8).write(to: aws.appendingPathComponent("config"))

        return try runDriver("""
        import Foundation
        S3AWSConfig.homeOverride = CommandLine.arguments[1]
        let profiles = S3AWSConfig.profiles()
        print("names\\t" + profiles.map(\\.name).joined(separator: ","))
        for p in profiles {
            let (converted, secret) = S3AWSConfig.connection(for: p)
            print("\\(p.name).key\\t\\(p.accessKeyID)")
            print("\\(p.name).secret\\t\\(secret)")
            print("\\(p.name).token\\t\\(p.sessionToken ?? "-")")
            print("\\(p.name).region\\t\\(p.region ?? "-")")
            print("\\(p.name).host\\t\\(converted.host)")
            print("\\(p.name).tls\\t\\(converted.useTLS)")
            print("\\(p.name).pathStyle\\t\\(converted.pathStyle)")
            print("\\(p.name).anonymous\\t\\(converted.anonymous)")
        }
        """, home: home)
    }

    // MARK: - The format's quiet failures

    func test_theProfilePrefixInConfigIsNotPartOfTheName() throws {
        // `[profile work]` in config, `[work]` in credentials, `[default]` in both. Treating them
        // alike produces a profile literally called "profile work", which then never matches the
        // credentials section and so has no key.
        let output = try read(credentials: """
        [default]
        aws_access_key_id = AKIADEFAULT
        aws_secret_access_key = defaultsecret

        [work]
        aws_access_key_id = AKIAWORK
        aws_secret_access_key = worksecret
        """, config: """
        [default]
        region = us-east-1

        [profile work]
        region = eu-central-1
        """)
        XCTAssertEqual(output["names"], "default,work")
        XCTAssertEqual(output["work.key"], "AKIAWORK")
        XCTAssertEqual(output["work.region"], "eu-central-1")
        // default sorts first whatever the file order, because that is what the CLI implies.
        XCTAssertEqual(output["default.region"], "us-east-1")
    }

    func test_aRegionBecomesTheRegionalHost() throws {
        let output = try read(credentials: """
        [eu]
        aws_access_key_id = AKIAEU
        aws_secret_access_key = eusecret
        """, config: """
        [profile eu]
        region = eu-central-1
        """)
        XCTAssertEqual(output["eu.host"], "s3.eu-central-1.amazonaws.com")
        XCTAssertTrue(output["eu.tls"] == "true")
        XCTAssertEqual(output["eu.pathStyle"], "false")
        // us-east-1 is the one region whose host has no region in it.
        let plain = try read(credentials: """
        [us]
        aws_access_key_id = AKIAUS
        aws_secret_access_key = ussecret
        """, config: """
        [profile us]
        region = us-east-1
        """)
        XCTAssertEqual(plain["us.host"], "s3.amazonaws.com")
    }

    func test_aNestedAddressingStyleIsFound() throws {
        // The only place the CLI keeps this, and the setting that decides whether a MinIO or Ceph
        // endpoint works at all. A parser that ignores indentation never sees it.
        let output = try read(credentials: """
        [minio]
        aws_access_key_id = minioadmin
        aws_secret_access_key = minioadmin
        """, config: """
        [profile minio]
        region = us-east-1
        s3 =
          addressing_style = path
          endpoint_url = http://127.0.0.1:9000
        """)
        XCTAssertEqual(output["minio.pathStyle"], "true")
        XCTAssertEqual(output["minio.host"], "127.0.0.1:9000")
        // The scheme in the endpoint decides TLS; assuming HTTPS for a local MinIO fails to connect.
        XCTAssertEqual(output["minio.tls"], "false")
    }

    func test_anEndpointWithAPortImpliesPathStyleEvenWhenUnstated() throws {
        // There is no wildcard name to put a bucket in front of, so virtual-hosted addressing cannot
        // work — and the failure is a DNS error, which reads as the endpoint being wrong.
        let output = try read(credentials: """
        [local]
        aws_access_key_id = k
        aws_secret_access_key = s
        """, config: """
        [profile local]
        endpoint_url = http://localhost:9000
        """)
        XCTAssertEqual(output["local.pathStyle"], "true")
    }

    func test_aTrailingCommentDoesNotTruncateASecret() throws {
        // '#' is a legal character in a secret access key. Stripping it unconditionally produces a
        // secret that is almost right, and the failure looks like a wrong password rather than a
        // parser bug.
        let output = try read(credentials: """
        [hashy]
        aws_access_key_id = AKIAHASH   # the key for staging
        aws_secret_access_key = abc#def
        """, config: "")
        XCTAssertEqual(output["hashy.key"], "AKIAHASH")
        XCTAssertEqual(output["hashy.secret"], "abc#def")
    }

    func test_credentialsWinOverConfig() throws {
        // Both files may carry a key. The credentials file is the one that exists to hold it, and a
        // stale copy in config must not shadow it.
        let output = try read(credentials: """
        [both]
        aws_access_key_id = FRESH
        aws_secret_access_key = freshsecret
        """, config: """
        [profile both]
        aws_access_key_id = STALE
        aws_secret_access_key = stalesecret
        region = us-east-1
        """)
        XCTAssertEqual(output["both.key"], "FRESH")
        XCTAssertEqual(output["both.secret"], "freshsecret")
    }

    func test_aSessionTokenIsCarried() throws {
        let output = try read(credentials: """
        [temp]
        aws_access_key_id = ASIATEMP
        aws_secret_access_key = tempsecret
        aws_session_token = FQoGZXIvYXdzEBYaD
        """, config: "")
        XCTAssertEqual(output["temp.token"], "FQoGZXIvYXdzEBYaD")
    }

    func test_sectionsThatCannotConnectAreNotOffered() throws {
        // An `[sso-session]` block, or a profile that only sets `output = json`, would put a name in
        // the dialog that cannot connect to anything.
        let output = try read(credentials: "", config: """
        [profile useful]
        region = us-east-1

        [sso-session my-sso]
        sso_start_url = https://example.awsapps.com/start

        [profile decorative]
        output = json
        cli_pager =
        """)
        XCTAssertEqual(output["names"], "useful")
    }

    func test_aProfileWithNoCredentialsIsOfferedAsAnonymous() throws {
        // A region-only profile is a real thing — someone who authenticates another way, or a public
        // bucket. It is offered, and honestly marked as having nothing to sign with.
        let output = try read(credentials: "", config: """
        [profile regiononly]
        region = eu-west-1
        """)
        XCTAssertEqual(output["regiononly.anonymous"], "true")
        XCTAssertEqual(output["regiononly.host"], "s3.eu-west-1.amazonaws.com")
    }

    func test_missingFilesAreNotAnError() throws {
        // Most Macs have no ~/.aws at all, and the dialog still has to open.
        let home = dir.appendingPathComponent("empty-home", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let output = try runDriver("""
        import Foundation
        S3AWSConfig.homeOverride = CommandLine.arguments[1]
        print("count\\t\\(S3AWSConfig.profiles().count)")
        """, home: home)
        XCTAssertEqual(output["count"], "0")
    }
}
