// SPDX-License-Identifier: Apache-2.0
// SidePanelTabsTests.swift - Which side-panel tabs are offered, and which one survives a change (F-476).
//
// The rules are small and each exists because of what goes wrong without it. Built-ins ordered by
// anything other than their declaration would reshuffle the strip while somebody is using it. A plugin
// tab filtered out by this setting would be a second, invisible off-switch for something the Plugins
// page already governs. And a selection kept by *index* rather than by identity is the defect this
// whole type was written to remove: switch Info off and the panel would show the Log page's content
// under the Activities label.

import XCTest
@testable import PCFoundation

final class SidePanelTabsTests: XCTestCase {

    // MARK: - What the list contains

    func testTheDefaultIsInfoAloneAndNeedsNoTabStrip() {
        // What ships: one tab, which is why the switcher can be left out entirely.
        let list = SidePanelTabList(visibleBuiltins: [.info], pluginViewIds: [])
        XCTAssertEqual(list.tabs, [.builtin(.info)])
    }

    func testBuiltinsKeepTheirDeclaredOrderWhicheverAreOn() {
        // Passed in back to front, and as a Set, so nothing about the caller's order can leak through.
        let list = SidePanelTabList(visibleBuiltins: [.log, .activities, .info], pluginViewIds: [])
        XCTAssertEqual(list.tabs, [.builtin(.info), .builtin(.activities), .builtin(.log)])
    }

    func testSwitchingAPageBackOnDoesNotReshuffleTheStrip() {
        // Log alone, then Info added: Info must land in front of Log, not after it. Ordering by
        // "recently switched on" would move Log under the pointer of the person who just clicked it.
        let before = SidePanelTabList(visibleBuiltins: [.log], pluginViewIds: [])
        let after = SidePanelTabList(visibleBuiltins: [.log, .info], pluginViewIds: [])
        XCTAssertEqual(before.tabs, [.builtin(.log)])
        XCTAssertEqual(after.tabs, [.builtin(.info), .builtin(.log)])
    }

    func testPluginTabsFollowTheBuiltins() {
        let list = SidePanelTabList(visibleBuiltins: [.info], pluginViewIds: ["plugin.notes.sidebar"])
        XCTAssertEqual(list.tabs, [.builtin(.info), .plugin("plugin.notes.sidebar")])
    }

    func testPluginTabsKeepTheOrderTheRegistryGaveThem() {
        // Not sorted: the registry's order comes from the contributions' `order` field, and re-sorting
        // here would quietly overrule what a plugin asked for.
        let list = SidePanelTabList(visibleBuiltins: [], pluginViewIds: ["b", "a"])
        XCTAssertEqual(list.tabs, [.plugin("b"), .plugin("a")])
    }

    func testAPluginTabIsNotHiddenByThisSetting() {
        // Every built-in off and the plugin tab is still there. Its visibility is the plugin's
        // enablement; hiding it here would be a second off-switch nobody can see.
        let list = SidePanelTabList(visibleBuiltins: [], pluginViewIds: ["plugin.terminal.sidebar"])
        XCTAssertEqual(list.tabs, [.plugin("plugin.terminal.sidebar")])
    }

    func testEveryPageOffWithNoPluginIsAnEmptyListRatherThanAnError() {
        // A reachable configuration — somebody who keeps only the terminal in the side panel — and the
        // panel has a sentence for it.
        let list = SidePanelTabList(visibleBuiltins: [], pluginViewIds: [])
        XCTAssertTrue(list.isEmpty)
        XCTAssertNil(list.selection(keeping: nil))
    }

    // MARK: - Index ↔ identity

    func testIndexAndTabAgreeWithAPageMissingInTheMiddle() {
        // The case the old segment-index-as-raw-value mapping got wrong: with Activities off, index 1
        // is Log, and asking either way round has to say so.
        let list = SidePanelTabList(visibleBuiltins: [.info, .log], pluginViewIds: ["x"])
        XCTAssertEqual(list.tab(at: 0), .builtin(.info))
        XCTAssertEqual(list.tab(at: 1), .builtin(.log))
        XCTAssertEqual(list.tab(at: 2), .plugin("x"))
        XCTAssertEqual(list.index(of: .builtin(.log)), 1)
        XCTAssertNil(list.index(of: .builtin(.activities)))
    }

    func testAnIndexOutsideTheListIsNilRatherThanAFallback() {
        // A stale `selectedSegment` must read as "no tab", not as the first one: a caller that gets
        // Info back for a segment that does not exist would render the wrong page and never find out.
        let list = SidePanelTabList(visibleBuiltins: [.info], pluginViewIds: [])
        XCTAssertNil(list.tab(at: 1))
        XCTAssertNil(list.tab(at: -1))
    }

    // MARK: - What stays selected

    func testTheShowingTabIsKeptByIdentityWhenAPageInFrontOfItGoesAway() {
        // Log is showing; Info is switched off. Log moves from index 2 to index 1, and Log is what must
        // still be showing. Keeping the index here is exactly how the panel came to show one page's
        // content under another page's label.
        let list = SidePanelTabList(visibleBuiltins: [.activities, .log], pluginViewIds: [])
        XCTAssertEqual(list.selection(keeping: .builtin(.log)), .builtin(.log))
        XCTAssertEqual(list.index(of: .builtin(.log)), 1)
    }

    func testAPluginTabStaysSelectedWhenABuiltinIsSwitchedOff() {
        let list = SidePanelTabList(visibleBuiltins: [], pluginViewIds: ["plugin.notes.sidebar"])
        XCTAssertEqual(list.selection(keeping: .plugin("plugin.notes.sidebar")),
                       .plugin("plugin.notes.sidebar"))
    }

    func testTheTabThatWasShowingAndIsNowGoneFallsBackToTheFirst() {
        let list = SidePanelTabList(visibleBuiltins: [.info, .log], pluginViewIds: [])
        XCTAssertEqual(list.selection(keeping: .builtin(.activities)), .builtin(.info))
    }

    func testNothingWasShowingSelectsTheFirstTab() {
        let list = SidePanelTabList(visibleBuiltins: [.activities], pluginViewIds: ["x"])
        XCTAssertEqual(list.selection(keeping: nil), .builtin(.activities))
    }

    // MARK: - What a report says

    func testBuiltinPagesAreReportedInListOrder() {
        // For the startup probe and the automation dump, which compare the string literally rather than
        // sorting it first.
        let list = SidePanelTabList(visibleBuiltins: [.log, .info], pluginViewIds: ["x"])
        XCTAssertEqual(list.builtinPages.map(\.rawValue), ["info", "log"])
    }
}
