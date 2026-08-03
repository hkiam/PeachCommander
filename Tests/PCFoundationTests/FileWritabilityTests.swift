// SPDX-License-Identifier: Apache-2.0
// FileWritabilityTests.swift - Why a file cannot be written (F-357).
//
// Real files and real flags. The whole value of this check is that it agrees with what the kernel will
// do at save time, so a mock would test the wrong thing.

import XCTest
@testable import PCFoundation

final class FileWritabilityTests: XCTestCase {
    private var directory = ""

    override func setUpWithError() throws {
        directory = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("pc-writability-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Clear any immutable flag first, or the directory cannot be removed either.
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/chflags"),
                             arguments: ["-R", "nouchg", directory]).waitUntilExit()
        try? FileManager.default.removeItem(atPath: directory)
    }

    private func file(_ name: String, mode: Int? = nil) throws -> String {
        let path = (directory as NSString).appendingPathComponent(name)
        try "x\n".write(toFile: path, atomically: true, encoding: .utf8)
        if let mode {
            try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: path)
        }
        return path
    }

    func testAnOrdinaryFileIsWritable() throws {
        XCTAssertEqual(FileWritabilityCheck.check(path: try file("plain.txt")), .writable)
    }

    func testYourOwnFileWithoutWritePermissionSaysSo() throws {
        // The distinction that matters: this one the user can fix themselves, and offering them an
        // authorization prompt for it would be wrong.
        let result = FileWritabilityCheck.check(path: try file("locked.txt", mode: 0o444))
        XCTAssertEqual(result, .permissionsDeny)
        XCTAssertFalse(result.administratorMayHelp)
    }

    func testAnImmutableFileIsReportedAsImmutable() throws {
        let path = try file("flagged.txt")
        let chflags = try Process.run(URL(fileURLWithPath: "/usr/bin/chflags"),
                                      arguments: ["uchg", path])
        chflags.waitUntilExit()
        try XCTSkipUnless(chflags.terminationStatus == 0, "chflags unavailable")
        XCTAssertEqual(FileWritabilityCheck.check(path: path), .immutable)
    }

    func testARootOwnedFileWouldNeedAuthorization() {
        // /etc/hosts is root-owned and mode 644 on every macOS: not writable by us, and exactly the
        // case the editor's administrator save exists for.
        let result = FileWritabilityCheck.check(path: "/etc/hosts")
        XCTAssertEqual(result, .ownedByAnotherUser(owner: "root"))
        XCTAssertTrue(result.administratorMayHelp)
    }

    func testASystemProtectedFileIsNotOfferedToAdministrators() throws {
        // SIP-restricted on a *writable* volume — authorization does not help, and offering it would
        // fail after the prompt. Measured rather than assumed: this is where such files actually are,
        // because everything under /System is answered by the read-only-volume case below.
        let path = "/private/var/db/SystemPolicyConfiguration"
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path), "no SIP-flagged path here")
        let result = FileWritabilityCheck.check(path: path)
        XCTAssertEqual(result, .systemProtected)
        XCTAssertFalse(result.administratorMayHelp)
    }

    func testTheSealedSystemVolumeIsReportedAsAReadOnlyVolume() {
        // macOS mounts / read-only, so this — not the SIP flag those files also carry — is what the
        // user needs to hear: nothing they can authorize will make the save work.
        let result = FileWritabilityCheck.check(path: "/System/Library/CoreServices/SystemVersion.plist")
        XCTAssertEqual(result, .readOnlyVolume)
        XCTAssertFalse(result.administratorMayHelp)
    }

    func testAMissingFileIsNotReportedAsAnObstacle() {
        // Reading it is about to fail with a better message than anything guessed here.
        XCTAssertEqual(FileWritabilityCheck.check(
            path: (directory as NSString).appendingPathComponent("nope.txt")), .writable)
    }
}
