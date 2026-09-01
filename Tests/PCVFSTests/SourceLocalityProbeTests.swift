// SPDX-License-Identifier: Apache-2.0
// SourceLocalityProbeTests.swift - Telling a share and an evicted cloud file from a local disk (F-479).
//
// The dataless case cannot be created in a test — only a File Provider sets `SF_DATALESS`, and asking
// one to evict a file is not something a unit test can do. So the flag arithmetic is tested against a
// real `lstat` of a real file (which must come back materialised), and the classification itself is
// tested as the pure function it is.

import XCTest
@testable import PCFoundation
@testable import PCVFS

final class SourceLocalityProbeTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-locality-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - The classification

    func testAFileOnALocalVolumeIsFast() {
        XCTAssertEqual(SourceLocalityProbe.of(localPath: "/Users/x/a.txt", volumeIsLocal: true), .fast)
    }

    func testAFileOnAMountedShareIsRemote() {
        // The case the report is about: an ordinary-looking path whose bytes are on another machine.
        XCTAssertEqual(SourceLocalityProbe.of(localPath: "/Volumes/team/film.mov", volumeIsLocal: false),
                       .remote)
    }

    // MARK: - The dataless flag

    func testAnOrdinaryFileIsNotDataless() throws {
        let file = dir.appendingPathComponent("plain.txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertFalse(SourceLocalityProbe.isDataless(file.path))
    }

    func testAMissingFileIsNotDataless() {
        // `lstat` fails; the answer must be "no" rather than a crash or a refusal.
        XCTAssertFalse(SourceLocalityProbe.isDataless(dir.appendingPathComponent("nope").path))
    }

    func testTheFlagIsTheOneTheKernelUses() {
        // Spelled out in the probe rather than imported, so it is worth asserting the value: getting
        // it wrong classifies every evicted file as materialised and the guard silently does nothing.
        XCTAssertEqual(SourceLocalityProbe.datalessFlag, 0x4000_0000)
    }

    // MARK: - Where the question is even asked

    func testOnlyProviderDirectoriesAreStattedPerFile() {
        // An `lstat` per row is cheap but not free, and on a share it is a round trip. Outside a
        // provider's own directory the question is not asked at all.
        XCTAssertFalse(SourceLocalityProbe.mayBeDormant("/Users/x/Documents/a.txt"))
        XCTAssertTrue(SourceLocalityProbe.mayBeDormant(
            SourceLocalityProbe.fileProviderRoot + "/Dropbox/a.txt"))
    }

    func testTheFileProviderRootIsWhereMacOSMountsThem() {
        // Dropbox, OneDrive and Google Drive all land under this one directory on a current macOS.
        XCTAssertTrue(SourceLocalityProbe.fileProviderRoot.hasSuffix("Library/CloudStorage"))
    }

    // MARK: - The volume question

    func testTheStartupDiskAnswersLocal() {
        XCTAssertTrue(SourceLocalityProbe.volumeIsLocal(NSHomeDirectory()))
        XCTAssertEqual(SourceLocalityProbe.ofDirectory(NSHomeDirectory()), .fast)
    }

    func testAPathNobodyCanAnswerForCountsAsLocal() {
        // Refusing a preview because a resource key was unavailable would be the worse failure.
        XCTAssertTrue(SourceLocalityProbe.volumeIsLocal("/no/such/place/at/all"))
    }
}
