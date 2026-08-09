// SPDX-License-Identifier: Apache-2.0
// ViewPlacementTests.swift - Where a plugin view sits when the user disagrees with its manifest (F-381).
//
// The rules are small and each of them exists because of what goes wrong without it. An override
// naming a container that is no longer registered would mount the view nowhere, so it would vanish for
// a reason the user cannot see. An override equal to the declared container would make "reset to
// default" stop meaning what it says the moment a plugin update changes its own default. And pruning
// has to leave alone the views whose plugin is merely switched off, or switching a plugin off would
// forget where its view was.

import XCTest
@testable import PCFoundation

final class ViewPlacementTests: XCTestCase {

    private let containers: Set<String> = ["sidebar", "bottom", "titlebar", "settings"]

    func testWithoutAnOverrideTheManifestDecides() {
        XCTAssertEqual(ViewPlacement.container(declared: "sidebar", override: nil,
                                               registered: containers), "sidebar")
    }

    func testAnOverrideWins() {
        XCTAssertEqual(ViewPlacement.container(declared: "sidebar", override: "bottom",
                                               registered: containers), "bottom")
    }

    func testAnOverrideNamingAContainerThatIsNotThereIsIgnored() {
        // Containers come and go with the window's furniture; an override outlives the thing it names.
        // Honouring this one would mount the view nowhere and it would silently disappear.
        XCTAssertEqual(ViewPlacement.container(declared: "sidebar", override: "inspector",
                                               registered: containers), "sidebar")
    }

    func testAnOverrideEqualToTheDefaultIsNotAnOverride() {
        // Dragging a view out and back must leave nothing behind. Otherwise a plugin update that moves
        // its own view is overruled by a preference the user thought they had undone.
        XCTAssertEqual(ViewPlacement.container(declared: "bottom", override: "bottom",
                                               registered: containers), "bottom")
    }

    // MARK: - Pruning what is written back

    func testAnOverrideThatMatchesTheDefaultIsNotWrittenOut() {
        let pruned = ViewPlacement.pruned(["a": "sidebar", "b": "bottom"],
                                          declared: ["a": "sidebar", "b": "sidebar"],
                                          registered: containers)
        XCTAssertEqual(pruned, ["b": "bottom"])
    }

    func testAnOverrideForAContainerThatIsGoneIsDropped() {
        let pruned = ViewPlacement.pruned(["a": "inspector"], declared: ["a": "sidebar"],
                                          registered: containers)
        XCTAssertTrue(pruned.isEmpty)
    }

    func testAViewWhosePluginIsSwitchedOffKeepsItsPlacement() {
        // Nothing declares "ghost" right now — its plugin is disabled, not gone. Forgetting where the
        // user put it because they switched the plugin off for an afternoon is not a tidy-up.
        let pruned = ViewPlacement.pruned(["ghost": "bottom"], declared: [:], registered: containers)
        XCTAssertEqual(pruned, ["ghost": "bottom"])
    }
}
