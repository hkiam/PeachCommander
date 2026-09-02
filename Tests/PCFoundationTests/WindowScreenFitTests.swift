// SPDX-License-Identifier: Apache-2.0
// WindowScreenFitTests.swift - What happens to a window when the screens change.
//
// The reason this is a pure function and not only a method on the window controller: the half that
// matters most — "the monitor is plugged back in, give me my layout" — needs a second screen
// configuration, and a test machine has one screen. Driving it through the running app can only
// exercise the shrinking half.

import XCTest
@testable import PCFoundation

final class WindowScreenFitTests: XCTestCase {

    /// The machine this was found on: one external display, menu bar and Dock taken off.
    private let small = CGRect(x: 0, y: 90, width: 2560, height: 960)
    /// What it was before the mode change.
    private let large = CGRect(x: 0, y: 60, width: 2560, height: 1320)

    func testAWindowThatFitsIsLeftAlone() {
        // The notification also fires for a Dock resize and a menu-bar change. A window that is
        // fine must not be nudged on either.
        let frame = CGRect(x: 100, y: 200, width: 1280, height: 800)
        XCTAssertEqual(WindowScreenFit.decide(frame: frame, remembered: nil, visible: small),
                       .leaveAlone)
    }

    func testAWindowTallerThanTheScreenIsShrunkToFit() {
        // The measured case: 1320 points tall on a screen with 960 of usable height, so the status
        // bar, the function keys and the command line were below the edge.
        let frame = CGRect(x: 0, y: 60, width: 2560, height: 1320)
        guard case .clamp(let target) = WindowScreenFit.decide(frame: frame, remembered: nil,
                                                               visible: small)
        else { return XCTFail("a window taller than the screen has to be clamped") }
        XCTAssertEqual(target.height, 960)
        XCTAssertEqual(target.width, 2560)
        XCTAssertTrue(small.contains(target))
    }

    func testAWindowPushedOffTheEdgeIsMovedBackIn() {
        let frame = CGRect(x: 2400, y: 900, width: 800, height: 400)
        guard case .clamp(let target) = WindowScreenFit.decide(frame: frame, remembered: nil,
                                                               visible: small)
        else { return XCTFail("a window off the edge has to be moved back") }
        XCTAssertTrue(small.contains(target))
        XCTAssertEqual(target.size, frame.size, "moving is enough; it already fits by size")
    }

    // MARK: - The half a single-screen machine cannot show

    func testTheRememberedFrameComesBackWhenThereIsRoomAgain() {
        // Monitor reattached. This is the whole reason the pre-clamp frame is remembered: without
        // it, unplugging a display for a minute would cost the layout permanently.
        let clamped = CGRect(x: 0, y: 90, width: 2560, height: 960)
        let chosen = CGRect(x: 0, y: 60, width: 2560, height: 1320)
        XCTAssertEqual(WindowScreenFit.decide(frame: clamped, remembered: chosen, visible: large),
                       .restore(chosen))
    }

    func testTheRememberedFrameIsNotRestoredWhileItStillWouldNotFit() {
        // A third screen size, between the two: still too small, so the window stays clamped and
        // the memory is kept for later.
        let middle = CGRect(x: 0, y: 90, width: 2560, height: 1100)
        let clamped = CGRect(x: 0, y: 90, width: 2560, height: 960)
        let chosen = CGRect(x: 0, y: 60, width: 2560, height: 1320)
        XCTAssertEqual(WindowScreenFit.decide(frame: clamped, remembered: chosen, visible: middle),
                       .leaveAlone)
    }

    func testRestoreWinsOverLeavingAFittingWindowAlone() {
        // Both are true at that moment — the clamped window fits *and* the remembered one now fits.
        // Restoring has to win, or the layout is never given back.
        let clamped = CGRect(x: 0, y: 90, width: 1000, height: 700)
        let chosen = CGRect(x: 0, y: 60, width: 2560, height: 1320)
        guard case .restore = WindowScreenFit.decide(frame: clamped, remembered: chosen,
                                                     visible: large)
        else { return XCTFail("the remembered frame must win once there is room") }
    }

    // MARK: - Shapes that must not do anything silly

    func testNoScreenMeansNoDecision() {
        // The notification fires while a display is being torn down, when the visible frame can be
        // empty. Clamping a window to nothing would be worse than waiting for the next one.
        XCTAssertEqual(WindowScreenFit.decide(frame: CGRect(x: 0, y: 0, width: 800, height: 600),
                                              remembered: nil, visible: .zero), .leaveAlone)
    }

    func testAWindowExactlyTheSizeOfTheScreenFits() {
        XCTAssertEqual(WindowScreenFit.decide(frame: small, remembered: nil, visible: small),
                       .leaveAlone)
    }
}
