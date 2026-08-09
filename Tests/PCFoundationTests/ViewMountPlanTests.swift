// SPDX-License-Identifier: Apache-2.0
// ViewMountPlanTests.swift - What a refresh is allowed to destroy (F-381).
//
// `ViewContainerRegistry.refresh` began with `live.forEach { $0.close() }`. That is a correct rebuild
// and a ruinous one, because a refresh fires for reasons unrelated to the view being rebuilt —
// enabling any plugin, disabling another, a `when` expression flipping elsewhere. `PcCloseView` is how
// a plugin destroys what is behind a view, so under the old code toggling an unrelated plugin would
// have restarted a terminal's shell, and moving a view between containers (which routes through the
// same function) would have restarted it on arrival.
//
// The registry itself cannot be driven from a test process: `ContribPlugin` wraps a real dlopen'ed
// library. So the decision — what is new, what is kept, what merely moved, what is genuinely gone —
// lives in a pure type, and this is where it is held to account.
//
// The cases below are the ones that were wrong or would have been: an unrelated change must move
// nothing, a container change must be a move rather than a close-and-create, and two plugins sharing
// a view id must stay two mounts.

import XCTest
@testable import PCFoundation

final class ViewMountPlanTests: XCTestCase {

    private func key(_ plugin: String, _ view: String) -> ViewMountKey {
        ViewMountKey(pluginId: plugin, viewId: view)
    }

    // MARK: - The defect this exists to prevent

    func testAnUnchangedSetChangesNothing() {
        // The whole point. Enabling some other plugin re-resolves every container, and the mounts that
        // did not change must not be touched — no close, no create, no move.
        let terminal = key("Terminal", "term.main")
        let notes = key("Notes", "notes.sidebar")
        let plan = ViewMountPlan.plan(
            live: [terminal: "bottom", notes: "sidebar"],
            wanted: [(terminal, "bottom"), (notes, "sidebar")])

        XCTAssertEqual(plan.close, [])
        XCTAssertEqual(plan.create, [])
        XCTAssertTrue(plan.moved.isEmpty)
        XCTAssertEqual(Set(plan.keep), [terminal, notes])
        XCTAssertTrue(plan.isEmpty, "a refresh that changes nothing must be a no-op")
    }

    func testAContainerChangeIsAMoveNotACloseAndCreate() {
        // A view dragged from the sidebar to the dock is the same view in a different place. Reported
        // as close+create it would be destroyed and rebuilt, which for a terminal means a new shell.
        let terminal = key("Terminal", "term.main")
        let plan = ViewMountPlan.plan(live: [terminal: "sidebar"],
                                      wanted: [(terminal, "bottom")])

        XCTAssertEqual(plan.close, [], "a moved view must never be closed")
        XCTAssertEqual(plan.create, [], "…nor built a second time")
        XCTAssertEqual(plan.moved.count, 1)
        XCTAssertEqual(plan.moved.first?.key, terminal)
        XCTAssertEqual(plan.moved.first?.from, "sidebar")
        XCTAssertEqual(plan.moved.first?.to, "bottom")
    }

    // MARK: - The ordinary arithmetic

    func testAContributionThatWentAwayIsClosed() {
        // The one case where closing is right: the plugin was disabled, or its `when` turned false.
        // Nothing else may produce a close, or the feature is back to where it started.
        let gone = key("Notes", "notes.sidebar")
        let stays = key("Terminal", "term.main")
        let plan = ViewMountPlan.plan(live: [gone: "sidebar", stays: "bottom"],
                                      wanted: [(stays, "bottom")])

        XCTAssertEqual(plan.close, [gone])
        XCTAssertEqual(plan.keep, [stays])
    }

    func testSomethingNewIsCreated() {
        let fresh = key("Git", "git.sidebar")
        let plan = ViewMountPlan.plan(live: [:], wanted: [(fresh, "sidebar")])
        XCTAssertEqual(plan.create, [fresh])
        XCTAssertEqual(plan.close, [])
    }

    // MARK: - Identity

    func testTwoPluginsMayShareAViewId() {
        // Keyed by view id alone these would be one mount, and the second plugin would be handed the
        // first one's view — or close it. Nothing stops two manifests choosing the same id.
        let a = key("PluginA", "panel")
        let b = key("PluginB", "panel")
        let plan = ViewMountPlan.plan(live: [a: "sidebar"], wanted: [(a, "sidebar"), (b, "sidebar")])

        XCTAssertEqual(plan.keep, [a])
        XCTAssertEqual(plan.create, [b])
        XCTAssertEqual(plan.close, [])
    }

    func testOneManifestDeclaringAViewTwiceGivesOneMount() {
        // Otherwise two mounts share an identity and the second silently takes the first's place on
        // the next refresh — a bug that would only show up as a view that stops updating.
        let dup = key("Terminal", "term.main")
        let plan = ViewMountPlan.plan(live: [:], wanted: [(dup, "sidebar"), (dup, "bottom")])

        XCTAssertEqual(plan.create, [dup])
        XCTAssertTrue(plan.moved.isEmpty, "the second declaration must not read as a move")
    }

    // MARK: - Determinism

    func testTheCloseListIsOrderedTheSameWayTwice() {
        // It is derived from a dictionary's keys, whose iteration order is not stable across runs.
        // A plan that differs from itself is untestable and, worse, makes teardown order arbitrary.
        let live = [key("C", "v"): "sidebar", key("A", "v"): "sidebar", key("B", "v"): "sidebar"]
        let first = ViewMountPlan.plan(live: live, wanted: [])
        let second = ViewMountPlan.plan(live: live, wanted: [])
        XCTAssertEqual(first.close, second.close)
        XCTAssertEqual(first.close.map(\.pluginId), ["A", "B", "C"])
    }

    func testContainerOrderIsPreserved() {
        // The order views appear in a container is the order the manifest asked for; a plan that
        // reshuffles them would reorder the sidebar's segments on every unrelated refresh.
        let one = key("P", "one"), two = key("P", "two"), three = key("P", "three")
        let plan = ViewMountPlan.plan(live: [:],
                                      wanted: [(one, "sidebar"), (two, "sidebar"), (three, "sidebar")])
        XCTAssertEqual(plan.create, [one, two, three])
    }
}
