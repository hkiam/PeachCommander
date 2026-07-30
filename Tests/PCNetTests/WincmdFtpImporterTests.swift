// WincmdFtpImporterTests.swift - TC wcx_ftp.ini site import (F-276).

import XCTest
@testable import PCNet

final class WincmdFtpImporterTests: XCTestCase {

    func testParsesConnectionsInIndexOrderWithoutPasswords() {
        let text = """
        [connections]
        1=Site B
        2=Site A

        [Site A]
        host=ftp.a.example.com
        username=alice
        directory=/pub
        pasvmode=1
        password=OBFUSCATED

        [Site B]
        host=ftp.b.example.com:2121
        username=bob
        defremdir=/home/bob
        pasvmode=0
        """
        let sites = WincmdFtpImporter.parse(text)
        XCTAssertEqual(sites.map(\.name), ["Site B", "Site A"])   // index order, not section order

        let b = sites[0]
        XCTAssertEqual(b.host, "ftp.b.example.com")
        XCTAssertEqual(b.port, 2121)                              // port split out of host
        XCTAssertEqual(b.user, "bob")
        XCTAssertEqual(b.remoteDir, "/home/bob")                  // defremdir fallback
        XCTAssertFalse(b.passive)

        let a = sites[1]
        XCTAssertEqual(a.host, "ftp.a.example.com")
        XCTAssertEqual(a.port, 21)                                // default
        XCTAssertEqual(a.remoteDir, "/pub")
        XCTAssertTrue(a.passive)
        XCTAssertEqual(a.auth, .password)
    }

    func testTlsSiteBecomesFtps() {
        let text = """
        [connections]
        1=Secure

        [Secure]
        host=secure.example.com
        username=user
        usetls=1
        """
        let sites = WincmdFtpImporter.parse(text)
        XCTAssertEqual(sites.count, 1)
        XCTAssertEqual(sites[0].proto, .ftps)
    }

    func testAnonymousSiteWithoutUsername() {
        let text = """
        [connections]
        1=Pub

        [Pub]
        host=mirror.example.com
        """
        let sites = WincmdFtpImporter.parse(text)
        XCTAssertEqual(sites.count, 1)
        XCTAssertEqual(sites[0].user, "anonymous")
        XCTAssertEqual(sites[0].auth, .anonymous)
    }

    func testFallsBackToSectionsWhenNoIndex() {
        let text = """
        [MySite]
        host=h.example.com
        username=u
        """
        let sites = WincmdFtpImporter.parse(text)
        XCTAssertEqual(sites.map(\.name), ["MySite"])
    }

    func testSectionWithoutHostIsSkipped() {
        let text = """
        [connections]
        1=Bad

        [Bad]
        username=nohost
        """
        XCTAssertTrue(WincmdFtpImporter.parse(text).isEmpty)
    }
}
