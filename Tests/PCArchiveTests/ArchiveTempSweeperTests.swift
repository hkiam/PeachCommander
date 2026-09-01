// SPDX-License-Identifier: Apache-2.0
// ArchiveTempSweeperTests.swift - Clearing away extractions older builds left behind (F-463).

import XCTest
@testable import PCArchive

final class ArchiveTempSweeperTests: XCTestCase {
    private var made: [URL] = []

    override func tearDownWithError() throws {
        for url in made { try? FileManager.default.removeItem(at: url) }
        made = []
    }

    /// A staging directory with a chosen modification date, so age can be tested without
    /// waiting a day for one.
    private func stage(prefix: String, ageInHours: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data("extracted\n".utf8).write(to: url.appendingPathComponent("member.txt"))
        made.append(url)
        let when = Date().addingTimeInterval(-ageInHours * 3600)
        try FileManager.default.setAttributes([.modificationDate: when], ofItemAtPath: url.path)
        return url
    }

    func test_anOldExtractionIsRemoved() throws {
        let old = try stage(prefix: "PCArchive-", ageInHours: 48)
        _ = ArchiveTempSweeper.sweep()
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
    }

    /// A recent one may belong to a mount that is still open — a panel sitting inside an
    /// archive with the viewer showing one of its files.
    func test_aRecentExtractionIsLeftAlone() throws {
        let fresh = try stage(prefix: "PCArchive-", ageInHours: 1)
        _ = ArchiveTempSweeper.sweep()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
    }

    /// Both filesystems stage under their own prefix; the plugin one leaked the same way.
    func test_thePluginFilesystemsStagingIsSweptToo() throws {
        let old = try stage(prefix: "PCX-", ageInHours: 48)
        _ = ArchiveTempSweeper.sweep()
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
    }

    // MARK: - The member stage, which carries its owner's process id (F-479)

    /// A stage root named for a chosen pid.
    private func stageRoot(pid: pid_t, ageInHours: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCStage-\(pid)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data("staged\n".utf8).write(to: url.appendingPathComponent("sheet.xlsx"))
        made.append(url)
        let when = Date().addingTimeInterval(-ageInHours * 3600)
        try FileManager.default.setAttributes([.modificationDate: when], ofItemAtPath: url.path)
        return url
    }

    /// The age rule cannot answer this one: a root belonging to a session that crashed ten minutes
    /// ago is leftover *now*, and waiting a day to say so is what the pid removes.
    func test_aStageRootWhoseProcessIsGoneIsRemovedAtOnce() throws {
        // pid 1 down to a very high number: `pid_t` 999_999 is above the default maximum, so nothing
        // holds it. Checked rather than assumed.
        let dead: pid_t = 999_999
        try XCTSkipIf(ArchiveTempSweeper.processIsAlive(dead), "pid \(dead) is in use on this machine")
        let root = try stageRoot(pid: dead, ageInHours: 0)
        _ = ArchiveTempSweeper.sweep()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    /// A second copy of the app is running and staging into its own root. Age says "old enough",
    /// and it is still in use.
    func test_aStageRootOfALiveProcessIsLeftAloneHoweverOldItLooks() throws {
        let root = try stageRoot(pid: getpid(), ageInHours: 240)
        _ = ArchiveTempSweeper.sweep()
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
    }

    func test_theOwnerIsReadOutOfTheDirectoryName() {
        XCTAssertEqual(ArchiveTempSweeper.ownerPID(of: "PCStage-4242-ABCD"), 4242)
        XCTAssertNil(ArchiveTempSweeper.ownerPID(of: "PCArchive-ABCD"), "the old prefixes carry no pid")
        XCTAssertNil(ArchiveTempSweeper.ownerPID(of: "PCStage-notanumber-ABCD"))
    }

    /// The temp directory belongs to everyone. Nothing outside our own staging names is
    /// ours to delete, however old it is.
    func test_nothingElseInTheTempDirectoryIsTouched() throws {
        let other = try stage(prefix: "SomebodyElse-", ageInHours: 240)
        _ = ArchiveTempSweeper.sweep()
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path),
                      "the sweeper deleted something that was not ours")
    }
}
