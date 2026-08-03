// SPDX-License-Identifier: Apache-2.0
// AccessibilityHotspotTests.swift - The stand-in element for a hand-drawn control (I19 T06).
//
// These views draw their controls and hit-test clicks themselves, which means an unlabelled button is
// not the failure mode — *nothing at all* is. A test is the only cheap way to notice if that comes
// back: the check is not "does it look right" but "does the view answer when asked what it contains".

import XCTest
import AppKit
@testable import PCFoundation

final class AccessibilityHotspotTests: XCTestCase {

    func testAHotspotAnswersWithItsRoleLabelAndPress() {
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        var pressed = false
        let spot = AccessibleHotspot(label: "Macintosh HD, 40 GB free", role: .button,
                                    frameInView: NSRect(x: 4, y: 2, width: 60, height: 20),
                                    parent: parent) { pressed = true }
        XCTAssertEqual(spot.accessibilityRole(), .button)
        XCTAssertEqual(spot.accessibilityLabel(), "Macintosh HD, 40 GB free")
        XCTAssertTrue(spot.accessibilityPerformPress())
        XCTAssertTrue(pressed, "the press action must run the same closure a click would")
    }

    func testARadioHotspotReportsWhetherItIsTheCurrentOne() {
        let parent = NSView()
        let on = AccessibleHotspot(label: "Downloads", role: .radioButton, selected: true,
                                  frameInView: .zero, parent: parent) {}
        let off = AccessibleHotspot(label: "Documents", role: .radioButton, selected: false,
                                   frameInView: .zero, parent: parent) {}
        // Without a value every tab announces identically and "which one am I on" is unanswerable.
        XCTAssertEqual(on.accessibilityValue() as? Int, 1)
        XCTAssertEqual(off.accessibilityValue() as? Int, 0)
    }
}
