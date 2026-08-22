// SPDX-License-Identifier: Apache-2.0
// PathBarHitTests.swift - What a click on the path bar resolves to (F-444).
//
// The regions overlap in the ways that matter: a segment can reach under the reserved trailing inset,
// and the gaps between segments are three pixels wide. Which of them wins is the whole behaviour, and
// getting it wrong is not a crash — it is a click that types a path when it meant to navigate.

import XCTest
@testable import PCFoundation

final class PathBarHitTests: XCTestCase {

    /// Two segments as `draw` lays them out: "/" at x 4…20, "Users" at x 25…70. The gap at 20…25 is
    /// the separator.
    private let segments = [
        PathBarSegmentFrame(rect: CGRect(x: 4, y: 4, width: 16, height: 16), path: "/"),
        PathBarSegmentFrame(rect: CGRect(x: 25, y: 4, width: 45, height: 16), path: "/Users"),
    ]
    private let contentEnd: CGFloat = 70

    func testASegmentNavigates() {
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 10, y: 10), segments: segments,
                                  contentEndX: contentEnd, clickCount: 1), .navigate("/"))
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 40, y: 10), segments: segments,
                                  contentEndX: contentEnd, clickCount: 1), .navigate("/Users"))
    }

    func testTheAreaRightOfThePathEdits() {
        // The point of the change: anywhere from the end of the path to the panel's edge, which is
        // where the pencil sits and where there was nothing to click before.
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 70, y: 10), segments: segments,
                                  contentEndX: contentEnd, clickCount: 1), .edit)
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 400, y: 10), segments: segments,
                                  contentEndX: contentEnd, clickCount: 1), .edit)
    }

    func testTheGapBetweenSegmentsDoesNothing() {
        // A click that just misses a folder name is a miss. Opening the editor there would punish a
        // two-pixel aiming error with a mode change.
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 22, y: 10), segments: segments,
                                  contentEndX: contentEnd, clickCount: 1), .none)
    }

    func testTheAreaLeftOfTheFirstSegmentDoesNothing() {
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 1, y: 10), segments: segments,
                                  contentEndX: contentEnd, clickCount: 1), .none)
    }

    func testADoubleClickAlwaysEdits() {
        // Including on a segment, which is the behaviour that existed before any of this.
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 10, y: 10), segments: segments,
                                  contentEndX: contentEnd, clickCount: 2), .edit)
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 22, y: 10), segments: segments,
                                  contentEndX: nil, clickCount: 2), .edit)
    }

    func testASegmentWinsAgainstTheTrailingArea() {
        // A long path is truncated at the trailing inset, so its last segment ends exactly at
        // `contentEndX` and the two regions touch. The segment has to win, or the deepest folder in a
        // path too long for the bar becomes unclickable.
        let long = [PathBarSegmentFrame(rect: CGRect(x: 4, y: 4, width: 60, height: 16),
                                        path: "/Users/me/some/deep/place")]
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 50, y: 10), segments: long,
                                  contentEndX: 40, clickCount: 1),
                       .navigate("/Users/me/some/deep/place"))
    }

    func testNothingHappensBeforeTheFirstDraw() {
        // `hitFrames` and `contentEndX` are filled in by `draw`. Until then there is nothing on screen
        // to have aimed at, and a click must not open the editor by default.
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 200, y: 10), segments: [],
                                  contentEndX: nil, clickCount: 1), .none)
    }

    func testAnEmptyBarStillEditsToTheRight() {
        // No path yet (a panel still loading): the bar drew nothing but its own background, and
        // `contentEndX` is the left inset — the whole strip opens the editor.
        XCTAssertEqual(pathBarHit(at: CGPoint(x: 200, y: 10), segments: [],
                                  contentEndX: 6, clickCount: 1), .edit)
    }
}
