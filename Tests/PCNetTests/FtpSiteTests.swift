// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCNet
import PCFoundation

final class FtpSiteTests: XCTestCase {

    func testDefaultPortsPerProtocol() {
        XCTAssertEqual(FtpProtocol.ftp.defaultPort, 21)
        XCTAssertEqual(FtpProtocol.ftps.defaultPort, 21)
        XCTAssertEqual(FtpProtocol.ftpsImplicit.defaultPort, 990)
        XCTAssertEqual(FtpProtocol.sftp.defaultPort, 22)
        // Port defaults from protocol when not given.
        XCTAssertEqual(FtpSite(name: "s", host: "h", proto: .sftp).port, 22)
    }

    func testSitesRoundTrip() {
        let sites = [
            FtpSite(name: "Prod FTP", host: "ftp.example.com", port: 2121, proto: .ftps,
                    user: "deploy", auth: .password, remoteDir: "/srv/www", localDir: "/Users/me/site",
                    passive: true, encoding: "utf-8", keepAliveSeconds: 30, folder: "Work"),
            FtpSite(name: "box", host: "10.0.0.5", proto: .sftp, user: "root",
                    auth: .keyFile, keyFile: "~/.ssh/id_ed25519", passive: false)
        ]
        let ini = FtpSitesFile.serialize(sites)
        let parsed = FtpSitesFile.parse(ini)
        XCTAssertEqual(parsed, sites)
    }

    func testProxyRoundTripAndConfig() {
        var site = FtpSite(name: "via-proxy", host: "ftp.example.com", proto: .ftp, user: "u")
        site.proxyHost = "10.1.1.9"; site.proxyPort = 1080; site.proxyType = .socks5; site.proxyUser = "px"
        let ini = FtpSitesFile.serialize([site])
        let parsed = FtpSitesFile.parse(ini)
        XCTAssertEqual(parsed.first?.proxyHost, "10.1.1.9")
        XCTAssertEqual(parsed.first?.proxyPort, 1080)
        XCTAssertEqual(parsed.first?.proxyType, .socks5)
        XCTAssertEqual(parsed.first?.proxyUser, "px")
        XCTAssertEqual(parsed.first?.proxyConfig?.host, "10.1.1.9")
        // Password is never persisted; the round-tripped site's config carries none.
        XCTAssertNil(parsed.first?.proxyConfig?.password)
        // A blank proxy host means a direct connection (nil config).
        var direct = site; direct.proxyHost = nil
        XCTAssertNil(direct.proxyConfig)
    }

    func testParseKeepsSiteOrderAndSkipsMeta() {
        let ini = """
        [meta]
        version=1

        [alpha]
        host=a.com

        [beta]
        host=b.com
        """
        let parsed = FtpSitesFile.parse(ini)
        XCTAssertEqual(parsed.map(\.name), ["alpha", "beta"])
        XCTAssertEqual(parsed[0].user, "anonymous")   // default
        XCTAssertTrue(parsed[0].passive)              // default
    }

    func testSectionsWithoutHostAreSkipped() {
        let parsed = FtpSitesFile.parse("[nohost]\nuser=x\n")
        XCTAssertTrue(parsed.isEmpty)
    }

    // MARK: - URL parsing

    func testParseFullURL() {
        let u = FtpURL.parse("ftp://alice:secret@ftp.example.com:2121/pub/files")
        XCTAssertEqual(u?.proto, .ftp)
        XCTAssertEqual(u?.user, "alice")
        XCTAssertEqual(u?.password, "secret")
        XCTAssertEqual(u?.host, "ftp.example.com")
        XCTAssertEqual(u?.port, 2121)
        XCTAssertEqual(u?.path, "/pub/files")
    }

    func testParseAnonymousDefaults() {
        let u = FtpURL.parse("ftp://ftp.gnu.org")
        XCTAssertEqual(u?.user, "anonymous")
        XCTAssertNil(u?.password)
        XCTAssertEqual(u?.port, 21)
        XCTAssertEqual(u?.path, "")
    }

    func testParseSchemesAndPorts() {
        XCTAssertEqual(FtpURL.parse("sftp://u@h")?.proto, .sftp)
        XCTAssertEqual(FtpURL.parse("sftp://u@h")?.port, 22)
        XCTAssertEqual(FtpURL.parse("ftps://h")?.proto, .ftps)
        XCTAssertEqual(FtpURL.parse("ftpes://h")?.proto, .ftps)
        XCTAssertNil(FtpURL.parse("http://h"))   // unsupported scheme
    }

    func testBareHostAssumesFTP() {
        let u = FtpURL.parse("files.example.com/dir")
        XCTAssertEqual(u?.proto, .ftp)
        XCTAssertEqual(u?.host, "files.example.com")
        XCTAssertEqual(u?.path, "/dir")
    }

    func testURLToSite() {
        let site = FtpURL.parse("sftp://root@box:2200/var")!.toSite(name: "My Box")
        XCTAssertEqual(site.name, "My Box")
        XCTAssertEqual(site.host, "box")
        XCTAssertEqual(site.port, 2200)
        XCTAssertEqual(site.proto, .sftp)
        XCTAssertEqual(site.auth, .password)
        XCTAssertEqual(site.remoteDir, "/var")
    }

    func test_effectiveKeepAlive_siteOverridesGlobal_elseFallsBack() {
        var s = FtpSite(name: "s", host: "h")
        s.keepAliveSeconds = 0
        XCTAssertEqual(s.effectiveKeepAlive(globalDefault: 30), 30)  // unset → global default
        s.keepAliveSeconds = 45
        XCTAssertEqual(s.effectiveKeepAlive(globalDefault: 30), 45)  // site value wins
        s.keepAliveSeconds = 0
        XCTAssertEqual(s.effectiveKeepAlive(globalDefault: 0), 0)    // both off → disabled
        XCTAssertEqual(s.effectiveKeepAlive(globalDefault: -5), 0)   // negative global clamped
    }

    // MARK: - Nothing secret may reach ftp-sites.ini (F-210)
    //
    // The rule is stated in three places in comments and was checked nowhere. It is the kind of rule
    // that is broken by adding one convenient line, and the file is plain text in the user's config
    // folder — backed up, synced, and readable by anything.

    func testSerializingASiteNeverWritesAPassword() {
        var site = FtpSite(name: "prod", host: "files.example.com", port: 21, proto: .ftp,
                           user: "alice", auth: .password)
        site.proxyHost = "proxy.example.com"
        site.proxyPort = 1080
        site.proxyUser = "bob"
        site.proxyPassword = "PROXY-SECRET"
        let text = FtpSitesFile.serialize([site])

        XCTAssertFalse(text.contains("PROXY-SECRET"), "the proxy password reached the ini:\n\(text)")
        // Key names, not the word anywhere: `auth=password` names the *method* and is not a secret. My
        // first version banned the substring outright and failed on that line — the test was wrong.
        let keys = text.split(whereSeparator: \.isNewline)
            .compactMap { $0.split(separator: "=", maxSplits: 1).first.map { String($0).lowercased() } }
        for forbidden in ["password", "proxypassword", "passphrase", "secret"] {
            XCTAssertFalse(keys.contains(forbidden), "the ini has a \(forbidden) key:\n\(text)")
        }
        // …and the things that *are* meant to be there still are, so this cannot pass by writing nothing.
        XCTAssertTrue(text.contains("files.example.com"))
        XCTAssertTrue(text.contains("alice"))
        XCTAssertTrue(text.contains("proxy.example.com"))
        XCTAssertTrue(text.contains("bob"))
    }

    func testAProxyLoginRoundTripsThroughTheSecretStoreAndNotTheFile() throws {
        var site = FtpSite(name: "prod", host: "files.example.com", port: 21, proto: .ftp,
                           user: "alice", auth: .password)
        site.proxyHost = "proxy.example.com"
        site.proxyPort = 1080
        site.proxyUser = "bob"

        let store = InMemorySecretStore()
        try FtpCredentials.saveProxyPassword("PROXY-SECRET", for: site, in: store)
        XCTAssertEqual(try FtpCredentials.proxyPassword(for: site, in: store), "PROXY-SECRET")

        // A different proxy user is a different secret; one login must not answer for another.
        var other = site
        other.proxyUser = "carol"
        XCTAssertNil(try FtpCredentials.proxyPassword(for: other, in: store))
    }

    func testAProxyWithoutALoginHasNoSecretToStore() throws {
        var site = FtpSite(name: "prod", host: "h", port: 21, proto: .ftp, user: "u", auth: .password)
        site.proxyHost = "proxy.example.com"
        XCTAssertNil(FtpCredentials.proxyAccount(for: site), "no user means no account key to key it by")
        let store = InMemorySecretStore()
        try FtpCredentials.saveProxyPassword("ignored", for: site, in: store)
        XCTAssertNil(try FtpCredentials.proxyPassword(for: site, in: store))
    }
}
