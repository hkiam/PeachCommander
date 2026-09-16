// SPDX-License-Identifier: Apache-2.0
// Workspace.swift - A named work context and everything that switches with it (F-499).
//
// A workspace is not a saved layout. The feature that was called "Workspaces" until now stored six
// fields per tab and replaced both panels when you loaded one, which its own help page admitted:
// "anything you had open but did not save is not kept". That is a preset. This is the other thing —
// a context you leave and come back to, where the switch asks nothing and loses nothing.
//
// The rule everything else follows from:
//
//     A workspace is never saved, because it never ends.
//
// So there is no "save changes?" on the way out. Switching writes the outgoing workspace's live state
// down and restores the incoming one exactly as it was left. What the *baseline* is for is the other
// half of the same idea: somewhere to come back to when the live state has wandered off, reached by a
// deliberate "reset", never by a dialog nobody asked for.
//
// **`baseline` and `live` are deliberately the same type.** A separate `WorkspaceBaseline` would
// drift from `WorkspaceState` the first time a field was added to only one of them, and the failure
// would be silent: reset would quietly stop restoring whatever was forgotten.
//
// ## The no-defaults rule
//
// `WorkspaceState`, `PaneState` and every type they contain declare an explicit initializer with **no
// default values**, and that is the single most important line in this file. Swift does not
// synthesise a public memberwise initializer across module boundaries, so the explicit one is the
// only way to build these values — and the only caller is `captureWorkspaceState()` in the app.
//
// Add a field, and the build breaks at exactly one line, whose fix is "read it off the live UI".
// **The compile error is the feature.** Without it, a forgotten field is a value from one workspace
// leaking into another — the marks from "clean up backups" showing up in "sort applicants" — which is
// the one defect this design is most exposed to and the hardest to notice.
//
// That rule governs construction, not decoding: `init(from:)` supplies defaults on purpose, so a file
// written before a field existed still loads. The reverse mistake — a field captured but never
// applied — no compiler can see, which is what `diff` at the bottom of this file is for.
//
// Deliberately NOT here: the stash, the journal and the scope. They arrive as their own optional keys
// when their stage lands. The format tolerates that by construction (see `PanelTabState`'s Codable
// note), and building empty shells for them now would only invite them to be built twice.

import Foundation

/// Which panel is the active one.
public enum PaneSide: String, Codable, Sendable, Equatable {
    case left, right
}

/// One panel's state: its tabs, and the things that belong to the panel rather than to a tab.
///
/// The split between this and `PanelTabState` is not arbitrary. View mode, the tree column and the
/// back/forward stack are properties of the *panel* in this application — switching tabs does not
/// change them — so storing them per tab would promise a fidelity the panel does not have. Marks and
/// the quick filter are the other way round and live on the tab.
public struct PaneState: Codable, Sendable, Equatable {
    public var tabs: [PanelTabState]
    public var activeIndex: Int
    /// `PanelViewMode.rawValue` — "details" | "brief" | "icons" | "gallery" | "tree".
    public var viewMode: String
    public var treeVisible: Bool
    /// The back/forward stack, oldest first, and the position in it.
    public var history: [String]
    public var historyIndex: Int

    /// No defaults. See the note at the top of this file.
    public init(
        tabs: [PanelTabState],
        activeIndex: Int,
        viewMode: String,
        treeVisible: Bool,
        history: [String],
        historyIndex: Int
    ) {
        self.tabs = tabs
        self.activeIndex = activeIndex
        self.viewMode = viewMode
        self.treeVisible = treeVisible
        self.history = history
        self.historyIndex = historyIndex
    }

    private enum CodingKeys: String, CodingKey {
        case tabs, active, viewMode, tree, history, historyIndex
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tabs, forKey: .tabs)
        if activeIndex != 0 { try c.encode(activeIndex, forKey: .active) }
        if viewMode != "details" { try c.encode(viewMode, forKey: .viewMode) }
        if treeVisible { try c.encode(true, forKey: .tree) }
        if !history.isEmpty {
            try c.encode(history, forKey: .history)
            try c.encode(historyIndex, forKey: .historyIndex)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let history = try c.decodeIfPresent([String].self, forKey: .history) ?? []
        self.init(
            tabs: try c.decodeIfPresent([PanelTabState].self, forKey: .tabs) ?? [],
            activeIndex: try c.decodeIfPresent(Int.self, forKey: .active) ?? 0,
            viewMode: try c.decodeIfPresent(String.self, forKey: .viewMode) ?? "details",
            treeVisible: try c.decodeIfPresent(Bool.self, forKey: .tree) ?? false,
            history: history,
            historyIndex: try c.decodeIfPresent(Int.self, forKey: .historyIndex) ?? max(0, history.count - 1)
        )
    }
}

/// The window's own arrangement: the bars, the panel layout, the side panel and the dock.
///
/// Everything here used to be a `[Layout]` key in `peachcmd.ini`, i.e. one setting for the whole
/// application. That was right while a window had one arrangement; it is wrong once "clean up
/// backups" wants the dock open with a terminal in it and "sort applicants" wants the side panel
/// showing the file's info. The keys stay readable for one release so an existing configuration still
/// paints correctly on the first frame before any workspace is loaded.
///
/// **Two things are deliberately NOT here**, and both for the same reason — they belong to the screen
/// rather than to the job:
///
///   * **The window frame.** A window that jumps to a different size and position on every chip click
///     is hostile, and the size you want is decided by the display you are on, not by the task.
///   * **Which side-panel pages exist** (Info/Activities/Log). That is a preference about what the
///     panel offers at all, not about what you are doing. Which page is *showing* is closer to
///     context, and arrives with the plugin views in a later stage.
public struct WindowChromeState: Codable, Sendable, Equatable {
    public var horizontalPanels: Bool
    /// Width of the left pane in points; 0 means "centre the divider".
    public var splitterLeftWidth: Double
    public var previewVisible: Bool
    public var previewWidth: Double
    public var sharedTreeVisible: Bool
    public var dockVisible: Bool
    public var dockHeight: Double
    /// Which plugin view the dock is showing, nil when it has never been chosen.
    public var dockPanel: String?
    public var commandLineVisible: Bool
    public var functionBarVisible: Bool
    public var buttonBarVisible: Bool
    public var buttonBarVertical: Bool
    public var driveBarVisible: Bool
    public var statusBarVisible: Bool
    public var tabBarVisible: Bool
    public var pathBarVisible: Bool

    /// No defaults. See the note at the top of this file.
    public init(horizontalPanels: Bool, splitterLeftWidth: Double,
                previewVisible: Bool, previewWidth: Double, sharedTreeVisible: Bool,
                dockVisible: Bool, dockHeight: Double, dockPanel: String?,
                commandLineVisible: Bool, functionBarVisible: Bool,
                buttonBarVisible: Bool, buttonBarVertical: Bool,
                driveBarVisible: Bool, statusBarVisible: Bool,
                tabBarVisible: Bool, pathBarVisible: Bool) {
        self.horizontalPanels = horizontalPanels
        self.splitterLeftWidth = splitterLeftWidth
        self.previewVisible = previewVisible
        self.previewWidth = previewWidth
        self.sharedTreeVisible = sharedTreeVisible
        self.dockVisible = dockVisible
        self.dockHeight = dockHeight
        self.dockPanel = dockPanel
        self.commandLineVisible = commandLineVisible
        self.functionBarVisible = functionBarVisible
        self.buttonBarVisible = buttonBarVisible
        self.buttonBarVertical = buttonBarVertical
        self.driveBarVisible = driveBarVisible
        self.statusBarVisible = statusBarVisible
        self.tabBarVisible = tabBarVisible
        self.pathBarVisible = pathBarVisible
    }

    /// What a window looks like out of the box. Used when a stored workspace predates this type, so
    /// that an older file loads as "the usual arrangement" rather than as everything switched off.
    public static let standard = WindowChromeState(
        horizontalPanels: false, splitterLeftWidth: 0,
        previewVisible: false, previewWidth: 300, sharedTreeVisible: false,
        dockVisible: false, dockHeight: 220, dockPanel: nil,
        commandLineVisible: true, functionBarVisible: true,
        buttonBarVisible: true, buttonBarVertical: false,
        driveBarVisible: true, statusBarVisible: true,
        tabBarVisible: true, pathBarVisible: true)

    private enum CodingKeys: String, CodingKey {
        case horizontalPanels, splitterLeftWidth, previewVisible, previewWidth, sharedTreeVisible
        case dockVisible, dockHeight, dockPanel, commandLineVisible, functionBarVisible
        case buttonBarVisible, buttonBarVertical, driveBarVisible, statusBarVisible
        case tabBarVisible, pathBarVisible
    }

    /// Only what differs from `standard` is written, for the same reason a plain tab is one key: these
    /// files are read by people, and sixteen lines of "yes, the usual" is not information.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let d = Self.standard
        if horizontalPanels != d.horizontalPanels { try c.encode(horizontalPanels, forKey: .horizontalPanels) }
        if splitterLeftWidth != d.splitterLeftWidth { try c.encode(splitterLeftWidth, forKey: .splitterLeftWidth) }
        if previewVisible != d.previewVisible { try c.encode(previewVisible, forKey: .previewVisible) }
        if previewWidth != d.previewWidth { try c.encode(previewWidth, forKey: .previewWidth) }
        if sharedTreeVisible != d.sharedTreeVisible { try c.encode(sharedTreeVisible, forKey: .sharedTreeVisible) }
        if dockVisible != d.dockVisible { try c.encode(dockVisible, forKey: .dockVisible) }
        if dockHeight != d.dockHeight { try c.encode(dockHeight, forKey: .dockHeight) }
        try c.encodeIfPresent(dockPanel, forKey: .dockPanel)
        if commandLineVisible != d.commandLineVisible { try c.encode(commandLineVisible, forKey: .commandLineVisible) }
        if functionBarVisible != d.functionBarVisible { try c.encode(functionBarVisible, forKey: .functionBarVisible) }
        if buttonBarVisible != d.buttonBarVisible { try c.encode(buttonBarVisible, forKey: .buttonBarVisible) }
        if buttonBarVertical != d.buttonBarVertical { try c.encode(buttonBarVertical, forKey: .buttonBarVertical) }
        if driveBarVisible != d.driveBarVisible { try c.encode(driveBarVisible, forKey: .driveBarVisible) }
        if statusBarVisible != d.statusBarVisible { try c.encode(statusBarVisible, forKey: .statusBarVisible) }
        if tabBarVisible != d.tabBarVisible { try c.encode(tabBarVisible, forKey: .tabBarVisible) }
        if pathBarVisible != d.pathBarVisible { try c.encode(pathBarVisible, forKey: .pathBarVisible) }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self.standard
        func bool(_ key: CodingKeys, _ fallback: Bool) throws -> Bool {
            try c.decodeIfPresent(Bool.self, forKey: key) ?? fallback
        }
        self.init(
            horizontalPanels: try bool(.horizontalPanels, d.horizontalPanels),
            splitterLeftWidth: try c.decodeIfPresent(Double.self, forKey: .splitterLeftWidth) ?? d.splitterLeftWidth,
            previewVisible: try bool(.previewVisible, d.previewVisible),
            previewWidth: try c.decodeIfPresent(Double.self, forKey: .previewWidth) ?? d.previewWidth,
            sharedTreeVisible: try bool(.sharedTreeVisible, d.sharedTreeVisible),
            dockVisible: try bool(.dockVisible, d.dockVisible),
            dockHeight: try c.decodeIfPresent(Double.self, forKey: .dockHeight) ?? d.dockHeight,
            dockPanel: try c.decodeIfPresent(String.self, forKey: .dockPanel),
            commandLineVisible: try bool(.commandLineVisible, d.commandLineVisible),
            functionBarVisible: try bool(.functionBarVisible, d.functionBarVisible),
            buttonBarVisible: try bool(.buttonBarVisible, d.buttonBarVisible),
            buttonBarVertical: try bool(.buttonBarVertical, d.buttonBarVertical),
            driveBarVisible: try bool(.driveBarVisible, d.driveBarVisible),
            statusBarVisible: try bool(.statusBarVisible, d.statusBarVisible),
            tabBarVisible: try bool(.tabBarVisible, d.tabBarVisible),
            pathBarVisible: try bool(.pathBarVisible, d.pathBarVisible))
    }
}

/// Everything that switches when you switch workspaces.
///
/// Built only by the app's `captureWorkspaceState()`. No defaults — see the note at the top.
public struct WorkspaceState: Codable, Sendable, Equatable {
    public var chrome: WindowChromeState
    public var left: PaneState
    public var right: PaneState
    public var activeSide: PaneSide

    public init(chrome: WindowChromeState, left: PaneState, right: PaneState, activeSide: PaneSide) {
        self.chrome = chrome
        self.left = left
        self.right = right
        self.activeSide = activeSide
    }

    private enum CodingKeys: String, CodingKey {
        case chrome, left, right, activeSide
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // Written even when it matches the standard arrangement, because its own encoder drops the
        // parts that do: an empty object here says "the usual", which is worth one line.
        try c.encode(chrome, forKey: .chrome)
        try c.encode(left, forKey: .left)
        try c.encode(right, forKey: .right)
        try c.encode(activeSide, forKey: .activeSide)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let empty = PaneState(tabs: [], activeIndex: 0, viewMode: "details",
                              treeVisible: false, history: [], historyIndex: 0)
        self.init(
            // A workspace stored before the chrome was part of one loads as the usual arrangement
            // rather than as everything switched off.
            chrome: try c.decodeIfPresent(WindowChromeState.self, forKey: .chrome) ?? .standard,
            left: try c.decodeIfPresent(PaneState.self, forKey: .left) ?? empty,
            right: try c.decodeIfPresent(PaneState.self, forKey: .right) ?? empty,
            activeSide: try c.decodeIfPresent(PaneSide.self, forKey: .activeSide) ?? .left
        )
    }
}

/// A named work context: "clean up backups", "sort applicant documents".
public struct Workspace: Codable, Sendable, Equatable {
    /// Written always, read to refuse a file from a future version rather than silently losing the
    /// half of it this build does not understand.
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    /// Stable, and the file's name. Never the display name: renaming a workspace must not move its
    /// file, orphan its stash or invalidate a `.pcworkspace` somebody already has.
    public var id: String
    public var name: String
    /// An INDEX into a fixed nine-colour palette, never a stored hex value.
    ///
    /// The concrete colour is resolved at draw time from the current theme, which is what lets a chip
    /// stay readable in the Norton Commander palette, satisfy the contrast audit by construction
    /// rather than by luck, and look right on the machine of whoever a `.pcworkspace` is sent to.
    public var tint: Int
    public var order: Int
    public var created: Date
    public var lastUsed: Date?
    /// The arrangement this workspace was set up as; where "reset" goes back to.
    public var baseline: WorkspaceState
    /// Where the user actually left it. Written on every switch, silently.
    public var live: WorkspaceState
    /// The folder this workspace is limited to, if any (F-499).
    ///
    /// Outside `live` and `baseline` for the same reason the stash is: resetting the panels must not
    /// quietly take the safety net off.
    public var scope: WorkspaceScope
    /// Files collected for this job (F-499).
    ///
    /// Deliberately *outside* `live` and `baseline`: the basket is not part of the arrangement, and
    /// "reset to the saved state" must put the panels back without throwing away the eleven files
    /// somebody spent the afternoon finding.
    public var stash: WorkspaceStash

    public init(
        formatVersion: Int = Workspace.currentFormatVersion,
        id: String,
        name: String,
        tint: Int,
        order: Int,
        created: Date,
        lastUsed: Date?,
        baseline: WorkspaceState,
        live: WorkspaceState,
        stash: WorkspaceStash = WorkspaceStash(),
        scope: WorkspaceScope = WorkspaceScope()
    ) {
        self.formatVersion = formatVersion
        self.id = id
        self.name = name
        self.tint = tint
        self.order = order
        self.created = created
        self.lastUsed = lastUsed
        self.baseline = baseline
        self.live = live
        self.stash = stash
        self.scope = scope
    }

    /// The command name this workspace answers to wherever a `cm_*` name is accepted.
    ///
    /// The macro precedent (`mc_<id>`): a workspace is addressed by name everywhere the user can see
    /// it — the keymap, `.bar` files, `.mnu` files — because its name is what they chose and its
    /// number is not.
    public var commandName: String { "ws_" + id }

    private enum CodingKeys: String, CodingKey {
        case formatVersion = "format", id, name, tint, order, created, lastUsed, baseline, live
        case stash, scope
    }

    /// Written only when there is something in it, and absent means an empty basket — which is what a
    /// workspace stored before stashes existed also decodes as.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(formatVersion, forKey: .formatVersion)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(tint, forKey: .tint)
        try c.encode(order, forKey: .order)
        try c.encode(created, forKey: .created)
        try c.encodeIfPresent(lastUsed, forKey: .lastUsed)
        try c.encode(baseline, forKey: .baseline)
        // Omitted when it is the same as the baseline, which is the rule every other field in this
        // format follows: a default is not written. It matters most in an exported `.pcworkspace`,
        // where the two are equal by construction — with no `live` key there is structurally no
        // divergence to leak, rather than two identical blocks and a promise that they match.
        if live != baseline { try c.encode(live, forKey: .live) }
        if !stash.isEmpty { try c.encode(stash, forKey: .stash) }
        // `hasRoot`, not `isSet` — the same distinction the scope's own encoder makes, and the same
        // trap: an exported root is tilde-abbreviated, so `isSet` is false and this outer gate would
        // drop the whole key. Two gates, one rule; fixing only the inner one fixes nothing.
        if scope.hasRoot { try c.encode(scope, forKey: .scope) }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Read once and used twice: an absent `live` means "the same as the baseline", so a file that
        // has never been navigated away from — and every exported one — is half the size and says the
        // arrangement once.
        let baseline = try c.decode(WorkspaceState.self, forKey: .baseline)
        self.init(
            formatVersion: try c.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1,
            id: try c.decode(String.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            tint: try c.decodeIfPresent(Int.self, forKey: .tint) ?? 0,
            order: try c.decodeIfPresent(Int.self, forKey: .order) ?? 0,
            created: try c.decodeIfPresent(Date.self, forKey: .created) ?? Date(),
            lastUsed: try c.decodeIfPresent(Date.self, forKey: .lastUsed),
            baseline: baseline,
            live: try c.decodeIfPresent(WorkspaceState.self, forKey: .live) ?? baseline,
            stash: try c.decodeIfPresent(WorkspaceStash.self, forKey: .stash) ?? WorkspaceStash(),
            scope: try c.decodeIfPresent(WorkspaceScope.self, forKey: .scope) ?? WorkspaceScope())
    }
}

// MARK: - Identifiers

public enum WorkspaceID {
    /// Turn a display name into something usable as a file name and as part of a command name.
    ///
    /// Restricted to what a command id may hold, for the same reason `MacroStore` sanitises: the id
    /// becomes `ws_<id>` in the command table, and a name with a slash in it would otherwise become a
    /// path. An empty or entirely unusable name falls back to "workspace" rather than to "", because
    /// a file called ".json" is not a file anybody can find again.
    public static func slug(from name: String) -> String {
        let lowered = name.lowercased()
        var out = ""
        var lastWasDash = false
        for ch in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(ch), ch.isASCII {
                out.unicodeScalars.append(ch)
                lastWasDash = false
            } else if !lastWasDash, !out.isEmpty {
                out.append("-")
                lastWasDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        if out.count > 48 { out = String(out.prefix(48)) }
        while out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "workspace" : out
    }

    /// `slug(from:)`, made unique against ids already in use by appending -2, -3, …
    public static func unique(from name: String, taken: Set<String>) -> String {
        let base = slug(from: name)
        guard taken.contains(base) else { return base }
        var n = 2
        while taken.contains("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }
}

// MARK: - Ghost-state detection

extension WorkspaceState {
    /// Field paths that legitimately differ between "what was applied" and "what is there a moment
    /// later", and so must not be reported as drift.
    ///
    /// Deliberately a short, explicit list rather than a clever rule: every entry here is a hole in
    /// the check, so each one should have to be argued for. A cursor is the honest case — the file it
    /// named may have been deleted while the workspace was away, and the panel is right to land
    /// somewhere else.
    public static let volatileFieldSuffixes: [String] = ["cursor", "cursorName"]

    /// Which fields differ between two states, as dotted paths ("left.viewMode", "right.tabs.0.path").
    ///
    /// Written over `Mirror` rather than as a hand-maintained comparison, so adding a field to any of
    /// these types needs no edit here — which matters, because this is the net that catches the
    /// mistake the compiler cannot see: a field that `capture` reads and `apply` ignores. Such a
    /// field survives a switch with the *outgoing* workspace's value still on screen, and nothing
    /// else in the system would say so.
    public static func diff(_ a: WorkspaceState, _ b: WorkspaceState) -> [String] {
        var out: [String] = []
        compare(a, b, path: "", into: &out)
        return out.filter { field in
            !volatileFieldSuffixes.contains { field == $0 || field.hasSuffix("." + $0) }
        }
    }

    private static func compare(_ a: Any, _ b: Any, path: String, into out: inout [String]) {
        let ma = Mirror(reflecting: a), mb = Mirror(reflecting: b)

        // Optionals: Mirror reports `.optional` with zero or one child.
        if ma.displayStyle == .optional || mb.displayStyle == .optional {
            let ca = ma.children.first?.value, cb = mb.children.first?.value
            switch (ca, cb) {
            case (nil, nil): return
            case (nil, _), (_, nil): out.append(path); return
            default: compare(ca!, cb!, path: path, into: &out); return
            }
        }

        if ma.displayStyle == .collection {
            let va = Array(ma.children), vb = Array(mb.children)
            guard va.count == vb.count else { out.append(path); return }
            for (i, pair) in zip(va, vb).enumerated() {
                compare(pair.0.value, pair.1.value, path: "\(path).\(i)", into: &out)
            }
            return
        }

        // A struct with named children: recurse. Anything else is a leaf.
        if ma.displayStyle == .struct, !ma.children.isEmpty {
            let ca = Array(ma.children), cb = Array(mb.children)
            guard ca.count == cb.count else { out.append(path); return }
            for (x, y) in zip(ca, cb) {
                let name = x.label ?? "?"
                compare(x.value, y.value, path: path.isEmpty ? name : "\(path).\(name)", into: &out)
            }
            return
        }

        if String(describing: a) != String(describing: b) { out.append(path) }
    }

    /// Every stored field path of a `WorkspaceState`, for the test that asserts capture covers them.
    ///
    /// Walks the *types* through one sample value, so it needs no maintenance either. Collections are
    /// reported once by name rather than per element — "left.tabs", not "left.tabs.0.path" — since
    /// the question it answers is "is this field carried at all".
    public static func fieldKeys(of sample: WorkspaceState) -> [String] {
        var out: [String] = []
        keys(sample, path: "", into: &out)
        return out.sorted()
    }

    private static func keys(_ value: Any, path: String, into out: inout [String]) {
        let m = Mirror(reflecting: value)
        if m.displayStyle == .struct, !m.children.isEmpty {
            for child in m.children {
                let name = child.label ?? "?"
                keys(child.value, path: path.isEmpty ? name : "\(path).\(name)", into: &out)
            }
            return
        }
        out.append(path)
    }
}
