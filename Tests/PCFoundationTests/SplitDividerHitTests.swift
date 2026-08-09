// SPDX-License-Identifier: Apache-2.0
// SplitDividerHitTests.swift - Double-clicking the divider gives two equal panels (F-001).
//
// The row promised it and nothing did it: the window used an NSSplitView directly, with no subclass
// and no click handling, and the function that centres the divider was reached only when the panel
// arrangement changed or when a launch found no saved width. AppKit has no "is this on the divider"
// question, so the arithmetic is ours — and it is the kind that goes wrong quietly at the edges.

import XCTest
@testable import PCFoundation

final class SplitDividerHitTests: XCTestCase {
    // Two panes side by side in a 1000-point window with a 1-point divider at x = 500.
    private let left = CGRect(x: 0, y: 0, width: 500, height: 600)
    private let right = CGRect(x: 501, y: 0, width: 499, height: 600)

    private func hit(_ x: CGFloat, _ y: CGFloat = 300, vertical: Bool = true) -> Bool {
        SplitDividerHit.isOnDivider(CGPoint(x: x, y: y), first: left, second: right, isVertical: vertical)
    }

    func testAClickOnTheDividerCounts() {
        XCTAssertTrue(hit(500.5))
    }

    func testAClickJustBesideItCountsToo() {
        // A divider is a point or two wide; requiring an exact hit for a double-click asks too much.
        XCTAssertTrue(hit(499))
        XCTAssertTrue(hit(502))
    }

    func testAClickInThePanelDoesNot() {
        XCTAssertFalse(hit(100), "a click in the middle of the left panel would have recentred it")
        XCTAssertFalse(hit(900))
    }

    func testTheOtherAxisIsMeasuredOnTheOtherAxis() {
        // Stacked panels (F-002): the divider is horizontal, so the y coordinate decides.
        let top = CGRect(x: 0, y: 301, width: 1000, height: 299)
        let bottom = CGRect(x: 0, y: 0, width: 1000, height: 300)
        XCTAssertTrue(SplitDividerHit.isOnDivider(CGPoint(x: 500, y: 300.5), first: top, second: bottom,
                                                  isVertical: false))
        XCTAssertFalse(SplitDividerHit.isOnDivider(CGPoint(x: 500, y: 100), first: top, second: bottom,
                                                   isVertical: false))
        // …and the x coordinate does not: a click far to the side but at the divider's height counts.
        XCTAssertTrue(SplitDividerHit.isOnDivider(CGPoint(x: 10, y: 300.5), first: top, second: bottom,
                                                  isVertical: false))
    }

    func testACollapsedPaneDoesNotSwallowTheWholeWindow() {
        // The left pane dragged shut: the gap is at x = 0, and a click in the middle of the remaining
        // panel must still not count as the divider.
        let collapsed = CGRect(x: 0, y: 0, width: 0, height: 600)
        let full = CGRect(x: 1, y: 0, width: 999, height: 600)
        XCTAssertTrue(SplitDividerHit.isOnDivider(CGPoint(x: 0.5, y: 300), first: collapsed,
                                                  second: full, isVertical: true))
        XCTAssertFalse(SplitDividerHit.isOnDivider(CGPoint(x: 500, y: 300), first: collapsed,
                                                   second: full, isVertical: true))
    }

    // MARK: - Where the divider goes

    func testTheTwoPanesComeOutEqual() {
        // The thickness comes off first, or the left pane gets half of everything and the right one
        // what is left after the divider — off by a point, but visibly not "50%".
        let position = SplitDividerHit.centeredPosition(span: 1000, dividerThickness: 10)
        XCTAssertEqual(position, 495)
        XCTAssertEqual(position, 1000 - 10 - position, "the two panes are not the same width")
    }

    func testAWindowTooNarrowForTheDividerDoesNotProduceANegativePosition() {
        XCTAssertEqual(SplitDividerHit.centeredPosition(span: 4, dividerThickness: 10), 0)
    }
}
