// SPDX-License-Identifier: Apache-2.0
// SidePanelTabs.swift - Which tabs the right-hand side panel offers, and which one survives a change (F-476).
//
// The side panel has three built-in pages — Info, Activities, Log — and one tab per plugin view mounted
// in the "sidebar" container. Two of the three built-ins are transfer lists most people never open, so
// each of them can be switched off; Info alone is what ships. One tab left means no tab strip at all,
// which is the whole point of the exercise.
//
// This type exists because the view it replaces made the *segment index* the mode's identity
// (`enum Mode: Int { case info, activities, log }` read straight out of `selectedSegment`). That is
// correct exactly as long as all three are present: switch Activities off and the Log segment sits at
// index 1, so asking the panel what it is showing answers "activities" and the user gets the wrong page
// under the right label. Nothing about that failure is visible in the code that reads `mode` — which is
// why the mapping is a value with tests rather than arithmetic spread over three methods.
//
// Five rules, each of them here because of what happens when it is missing.
//
// **Built-ins keep their declared order**, whatever the visible subset is. Ordering them by "recently
// switched on" would reshuffle the strip under the hand of someone who just wanted Log back.
//
// **Plugin tabs follow the built-ins and are never hidden by this setting.** A plugin view's visibility
// is the plugin's enablement — Settings ▸ Plugins, `plugins.ini`, a `when` expression. A second,
// invisible off-switch for the same thing is how a view goes missing for a reason its owner cannot find.
//
// **The tab that was showing is kept by identity, not by index.** Keeping the index is the defect
// described above, one step removed: it survives switching a page off and then shows a different tab's
// content without saying so.
//
// **A tab that is gone falls back to the first one**, rather than to nothing. "Nothing selected" is a
// state the panel would have to render, and there is already a better answer for it.
//
// **An empty list is legal.** Every built-in off with no plugin mounted is a reachable configuration —
// somebody keeping the terminal in the side panel and nothing else — and the panel says so plainly
// instead of treating it as an error.

import Foundation

/// A built-in page of the side panel.
///
/// `String`-raw rather than `Int`: these names go into config keys, an automation dump and the startup
/// probe, and a number in any of those would be one renumbering away from meaning something else.
public enum SidePanelPage: String, CaseIterable, Sendable {
    case info
    case activities
    case log
}

/// One tab of the side panel: a built-in page, or a plugin view by its id.
public enum SidePanelTab: Equatable, Sendable {
    case builtin(SidePanelPage)
    case plugin(String)
}

/// The tabs the panel offers right now, in the order they appear.
public struct SidePanelTabList: Equatable, Sendable {

    public let tabs: [SidePanelTab]

    /// - Parameters:
    ///   - visibleBuiltins: the built-in pages that are switched on. Order here is irrelevant; the
    ///     result always follows `SidePanelPage.allCases`.
    ///   - pluginViewIds: the view ids mounted in the "sidebar" container, in the order the registry
    ///     handed them over. Not filtered by `visibleBuiltins` — see the rule at the top of the file.
    public init(visibleBuiltins: Set<SidePanelPage>, pluginViewIds: [String]) {
        tabs = SidePanelPage.allCases.filter(visibleBuiltins.contains).map(SidePanelTab.builtin)
             + pluginViewIds.map(SidePanelTab.plugin)
    }

    public var isEmpty: Bool { tabs.isEmpty }

    public func index(of tab: SidePanelTab) -> Int? {
        tabs.firstIndex(of: tab)
    }

    public func tab(at index: Int) -> SidePanelTab? {
        tabs.indices.contains(index) ? tabs[index] : nil
    }

    /// Which tab to show after the list has changed, given what was showing before it did.
    ///
    /// Returns nil only for an empty list. Everything else keeps `previous` if it is still here, and
    /// otherwise starts over at the first tab.
    public func selection(keeping previous: SidePanelTab?) -> SidePanelTab? {
        if let previous, tabs.contains(previous) { return previous }
        return tabs.first
    }

    /// The visible built-in pages, for the startup probe and the automation dump.
    ///
    /// Reported in list order so a report can be compared literally rather than sorted first.
    public var builtinPages: [SidePanelPage] {
        tabs.compactMap { if case .builtin(let page) = $0 { return page } else { return nil } }
    }
}
