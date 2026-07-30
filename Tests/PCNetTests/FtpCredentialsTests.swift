import XCTest
@testable import PCNet
import PCFoundation

final class FtpCredentialsTests: XCTestCase {
    func testAccountKeyIsStableAndSiteSpecific() {
        let a = FtpSite(name: "A", host: "h", port: 21, proto: .ftp, user: "bob")
        XCTAssertEqual(FtpCredentials.account(for: a), "ftp://bob@h:21")
        let b = FtpSite(name: "B", host: "h", port: 2200, proto: .sftp, user: "root")
        XCTAssertEqual(FtpCredentials.account(for: b), "sftp://root@h:2200")
    }

    func testSaveLoadDeleteViaStore() throws {
        let store = InMemorySecretStore()
        let site = FtpSite(name: "S", host: "ftp.example.com", proto: .ftps, user: "deploy")
        try FtpCredentials.savePassword("s3cr3t", for: site, in: store)
        XCTAssertEqual(try FtpCredentials.password(for: site, in: store), "s3cr3t")
        // A different site does not see it.
        let other = FtpSite(name: "S2", host: "other.com", user: "deploy")
        XCTAssertNil(try FtpCredentials.password(for: other, in: store))
        try FtpCredentials.deletePassword(for: site, in: store)
        XCTAssertNil(try FtpCredentials.password(for: site, in: store))
    }

    func testPasswordValueIsNeverInSerializedSites() throws {
        let store = InMemorySecretStore()
        let site = FtpSite(name: "S", host: "h", user: "u")
        try FtpCredentials.savePassword("TOPSECRET-VALUE-123", for: site, in: store)
        let ini = FtpSitesFile.serialize([site])
        XCTAssertFalse(ini.contains("TOPSECRET-VALUE-123"))   // secret stays in the store only
    }
}
