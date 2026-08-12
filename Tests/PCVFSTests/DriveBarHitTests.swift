// SPDX-License-Identifier: Apache-2.0
// DriveBarHitTests.swift - The eject glyph must win over the chip it sits inside (F-385).
//
// The drive bar draws a volume's eject glyph *inside* that volume's chip, so the glyph's rectangle
// lies entirely within the chip's. Hit-testing takes the first region that contains the point, which
// makes the order the list is built in the whole of the correctness: append the chip first and the
// glyph is drawn, looks clickable, and only ever navigates. Nothing about that is visible in a
// screenshot or catchable by the compiler, so it is pinned here.

import XCTest
@testable import PCVFS

final class DriveBarHitTests: XCTestCase {

    private enum Target: Equatable, Sendable { case chip, eject }

    /// A chip with the glyph at its trailing edge, in the order the view appends them.
    private var regions: [DriveBarHit.Region<Target>] {
        [DriveBarHit.Region(rect: CGRect(x: 100, y: 0, width: 20, height: 18), payload: .eject),
         DriveBarHit.Region(rect: CGRect(x: 40, y: 0, width: 80, height: 18), payload: .chip)]
    }

    func testAClickOnTheGlyphEjectsRatherThanNavigates() {
        let hit = DriveBarHit.region(at: CGPoint(x: 110, y: 9), in: regions)
        XCTAssertEqual(hit?.payload, .eject)
    }

    func testAClickOnTheRestOfTheChipStillNavigates() {
        let hit = DriveBarHit.region(at: CGPoint(x: 50, y: 9), in: regions)
        XCTAssertEqual(hit?.payload, .chip)
    }

    /// The failure this file exists for: build the list the other way round and the glyph is dead.
    func testTheChipWouldSwallowTheGlyphIfAppendedFirst() {
        let wrongOrder = Array(regions.reversed())
        XCTAssertEqual(DriveBarHit.region(at: CGPoint(x: 110, y: 9), in: wrongOrder)?.payload, .chip,
                       "if this ever says .eject the ordering no longer matters and this test is moot")
    }

    func testAPointOutsideEveryRegionHitsNothing() {
        XCTAssertNil(DriveBarHit.region(at: CGPoint(x: 5, y: 9), in: regions))
    }
}
