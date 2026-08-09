// SPDX-License-Identifier: Apache-2.0
// CrashReportSelectionTests.swift - Which crash reports the app may raise with you (F-313).
//
// ~/Library/Logs/DiagnosticReports holds crash logs for everything on the machine. Two questions
// decide what may be shown, and the failures are the quiet kind: a watermark that does not advance
// asks about the same crash at every launch, and a first-ever launch that reports what it finds
// surfaces months of unrelated crashes as if the app had just produced them.

import XCTest
@testable import PCFoundation

final class CrashReportSelectionTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_000_000)
    private func at(_ offset: TimeInterval) -> Date { epoch.addingTimeInterval(offset) }

    // MARK: - Whose report is it

    func testOurOwnReportsAreRecognised() {
        XCTAssertTrue(CrashReportSelection.isOurReport("PeachCommander-2026-08-09-120000.ips"))
        XCTAssertTrue(CrashReportSelection.isOurReport("peachcommander_2026.crash"))
    }

    func testSomebodyElsesCrashIsNotOurs() {
        XCTAssertFalse(CrashReportSelection.isOurReport("Safari-2026-08-09.ips"),
                       "another application's crash would have been offered for sending")
        XCTAssertFalse(CrashReportSelection.isOurReport("kernel_2026.panic"))
    }

    func testOnlyTheTwoExtensionsMacOSUses() {
        XCTAssertFalse(CrashReportSelection.isOurReport("PeachCommander-notes.txt"))
        XCTAssertFalse(CrashReportSelection.isOurReport("PeachCommander"))
    }

    // MARK: - Is it new

    func testOnlyReportsNewerThanTheWatermark() {
        let files = [(name: "PeachCommander-old.ips", modified: at(-100)),
                     (name: "PeachCommander-new.ips", modified: at(100))]
        let found = CrashReportSelection.newReports(files, since: epoch)
        XCTAssertEqual(found.map(\.name), ["PeachCommander-new.ips"],
                       "a crash already reported would have been raised again")
    }

    func testTheNewestComesFirst() {
        let files = [(name: "PeachCommander-a.ips", modified: at(10)),
                     (name: "PeachCommander-c.ips", modified: at(30)),
                     (name: "PeachCommander-b.ips", modified: at(20))]
        XCTAssertEqual(CrashReportSelection.newReports(files, since: epoch).map(\.name),
                       ["PeachCommander-c.ips", "PeachCommander-b.ips", "PeachCommander-a.ips"])
    }

    func testTheFirstEverLaunchRaisesNothing() {
        // No watermark yet: whatever is lying there predates the app knowing about it, and offering to
        // send a stranger's crash log is not a good introduction.
        let files = [(name: "PeachCommander-ancient.ips", modified: at(-100_000))]
        XCTAssertTrue(CrashReportSelection.newReports(files, since: nil).isEmpty)
    }

    func testAReportExactlyAtTheWatermarkIsNotNew() {
        // Strictly newer, or the last one found is found again at the next launch.
        let files = [(name: "PeachCommander-edge.ips", modified: epoch)]
        XCTAssertTrue(CrashReportSelection.newReports(files, since: epoch).isEmpty)
    }

    func testAFolderFullOfOtherApplicationsIsIgnored() {
        let files = [(name: "Safari-2026.ips", modified: at(100)),
                     (name: "Xcode-2026.ips", modified: at(200)),
                     (name: "PeachCommander-ours.ips", modified: at(50))]
        XCTAssertEqual(CrashReportSelection.newReports(files, since: epoch).map(\.name),
                       ["PeachCommander-ours.ips"])
    }
}
