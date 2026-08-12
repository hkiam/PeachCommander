// SPDX-License-Identifier: Apache-2.0
// PathSegmentsTests.swift - Where a breadcrumb click navigates (F-007).
//
// The path bar had no test at all, and it decides *where a click goes* — a segment whose cumulative path
// is wrong takes the panel somewhere the user did not point at, which looks like the app losing its
// place rather than like a parsing bug.

import XCTest
@testable import PCFoundation

final class PathSegmentsTests: XCTestCase {

    private func names(_ path: String) -> [String] { PathSegments.make(path).map(\.name) }
    private func paths(_ path: String) -> [String] { PathSegments.make(path).map(\.path) }

    func testAnOrdinaryPath() {
        XCTAssertEqual(names("/Users/me"), ["/", "Users", "me"])
        XCTAssertEqual(paths("/Users/me"), ["/", "/Users", "/Users/me"])
    }

    func testTheRootIsOneSegment() {
        XCTAssertEqual(PathSegments.make("/").map(\.path), ["/"])
    }

    func testEmptyGivesNothingRatherThanAStraySlash() {
        XCTAssertTrue(PathSegments.make("").isEmpty)
    }

    func testATrailingSeparatorDoesNotAddAnEmptySegment() {
        XCTAssertEqual(names("/Users/me/"), ["/", "Users", "me"])
        XCTAssertEqual(paths("/Users/me/"), paths("/Users/me"))
    }

    func testDoubledSeparatorsCollapse() {
        // These arise from joining paths, and a breadcrumb built from them must navigate to the same
        // place as the plain form — not to "/Users//me", which some servers treat differently.
        XCTAssertEqual(paths("//Users//me"), ["/", "/Users", "/Users/me"])
    }

    func testANameWithSpacesStaysOneSegment() {
        XCTAssertEqual(names("/Users/me/Ordner mit Leerzeichen"),
                       ["/", "Users", "me", "Ordner mit Leerzeichen"])
    }

    func testAPathInsideAnArchiveIsJustAPath() {
        // The panel shows the archive as a folder, so its breadcrumb is built exactly like any other.
        XCTAssertEqual(paths("/tmp/archiv.zip/innen"),
                       ["/", "/tmp", "/tmp/archiv.zip", "/tmp/archiv.zip/innen"])
    }

    func testAMountedDriveNamesItsOwnRoot() {
        // Inside a plugin drive the path is that mount's own "/", and a breadcrumb reading "/" claims
        // the panel is at the startup disk's root. Only the label changes: the segment still goes to
        // "/", which inside the mount is the drive's root and nowhere near the local one.
        let segs = PathSegments.make("/", rootLabel: "TaskManager")
        XCTAssertEqual(segs.map(\.name), ["TaskManager"])
        XCTAssertEqual(segs.map(\.path), ["/"])
        let deeper = PathSegments.make("/1234", rootLabel: "TaskManager")
        XCTAssertEqual(deeper.map(\.name), ["TaskManager", "1234"])
        XCTAssertEqual(deeper.map(\.path), ["/", "/1234"])
    }

    func testNoLabelLeavesTheBreadcrumbAsItWas() {
        // The label is absent for every ordinary listing, which is nearly all of them.
        XCTAssertEqual(names("/Users/me"), PathSegments.make("/Users/me", rootLabel: nil).map(\.name))
        // An empty name is no name — a volume without one must not blank out the root segment.
        XCTAssertEqual(PathSegments.make("/", rootLabel: "").map(\.name), ["/"])
    }

    func testEverySegmentPathIsAPrefixOfTheOneAfterIt() {
        // The property that makes a breadcrumb a breadcrumb: clicking the nth segment must land inside
        // the path the (n+1)th describes, never beside it.
        for path in ["/Users/me/Documents/2026", "/Volumes/Backup/x", "/tmp/a.zip/b/c"] {
            let segs = PathSegments.make(path)
            for (earlier, later) in zip(segs, segs.dropFirst()) {
                XCTAssertTrue(later.path.hasPrefix(earlier.path),
                              "\(later.path) does not continue \(earlier.path)")
            }
            XCTAssertEqual(segs.last?.path, path, "the last segment is the path itself")
        }
    }
}
