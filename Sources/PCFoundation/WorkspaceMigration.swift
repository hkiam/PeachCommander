// SPDX-License-Identifier: Apache-2.0
// WorkspaceMigration.swift - Turning the old `workspaces.ini` into real workspaces, once (F-499).
//
// Pure and IO-free on purpose: the whole of this runs from strings in a unit test, which is the only
// way to be confident about a one-way migration of somebody else's data. `WorkspaceStore` owns the
// files and the "only when there is no directory yet" rule; this owns the shape change.
//
// Two things it must get right, and only the second is obvious.
//
// **Nothing saved is lost.** Every entry in `[Workspaces]` becomes a workspace whose baseline *and*
// live state are the layout that was saved, because a preset that was loaded is exactly a workspace
// sitting at its starting point.
//
// **Nothing *unsaved* is lost either**, and that is the one that would have been missed. The old
// feature was opt-in: almost nobody ever pressed Save Workspace, so migrating only `workspaces.ini`
// would hand the overwhelming majority an empty list and two panels pointing at home — a regression
// dressed as a feature. So the caller's *current session* comes across as the first workspace, and it
// is listed first. Somebody who never used the old feature opens the new build, sees no chip strip at
// all (one workspace is the latent state) and notices nothing. Somebody who saved four layouts opens
// it and finds four chips, which is the best first impression this feature can make.

import Foundation

public enum WorkspaceMigration {

    static let section = "Workspaces"

    /// How many colours the chip palette has. Migrated workspaces are dealt them round-robin so a
    /// list arrives looking deliberate rather than uniformly grey.
    public static let tintCount = 9

    /// Build the workspace list from a legacy `workspaces.ini` plus the session as it stands.
    ///
    /// - Parameters:
    ///   - legacyINI: the contents of `workspaces.ini`, or "" when there is none.
    ///   - session: the current session as a workspace. Its name and state come from the caller
    ///     (which is the only thing that can read a live window); its `order` and `tint` are set here.
    ///   - now: injected so the test does not depend on the clock.
    /// - Returns: the session workspace first, then the saved layouts in their stored order.
    public static func workspaces(legacyINI: String, session: Workspace, now: Date = Date()) -> [Workspace] {
        var out: [Workspace] = []
        var first = session
        first.order = 0
        first.tint = session.tint % tintCount
        first.created = session.created
        first.lastUsed = now
        out.append(first)

        var taken: Set<String> = [first.id]
        for (i, saved) in savedLayouts(in: legacyINI).enumerated() {
            let id = WorkspaceID.unique(from: saved.name, taken: taken)
            taken.insert(id)
            // A saved layout has no history of its own — the old format never stored one — so the
            // panes start with an empty back/forward stack rather than inheriting the session's,
            // which would send Alt+Left somewhere this workspace has never been.
            let state = WorkspaceState(
                // The user's *current* arrangement rather than the factory one. A saved layout from
                // the old feature carried no window chrome at all, and inheriting the defaults would
                // open it without the bars they have had switched on for years — which reads as the
                // migration having broken something.
                chrome: session.live.chrome,
                left: PaneState(tabs: saved.left, activeIndex: saved.leftActive,
                                viewMode: "details", treeVisible: false,
                                history: [], historyIndex: 0),
                right: PaneState(tabs: saved.right, activeIndex: saved.rightActive,
                                 viewMode: "details", treeVisible: false,
                                 history: [], historyIndex: 0),
                activeSide: saved.activeSide == "right" ? .right : .left)
            out.append(Workspace(
                id: id,
                name: saved.name,
                tint: (i + 1) % tintCount,
                order: i + 1,
                created: now,
                lastUsed: nil,
                // Baseline and live are the same thing here, and that is not a shortcut: a saved
                // layout *is* a starting point, so "reset to baseline" on a freshly migrated
                // workspace does exactly what loading it used to do.
                baseline: state,
                live: state))
        }

        // Deliberately NOT capped at nine. The limit exists to keep the chip strip readable and is
        // enforced when somebody creates one; applying it here would silently delete saved layouts
        // during an upgrade, which is the one thing a migration may never do.
        return out
    }

    /// One entry of the old `[Workspaces]` section.
    struct SavedLayout: Equatable {
        var name: String
        var left: [PanelTabState]
        var leftActive: Int
        var right: [PanelTabState]
        var rightActive: Int
        var activeSide: String
    }

    /// Read the old section. Entries with an empty name, or with no tabs on either side, are skipped:
    /// they cannot be switched to and would show as a chip that does nothing.
    static func savedLayouts(in text: String) -> [SavedLayout] {
        guard !text.isEmpty else { return [] }
        let ini = INIDocument(parsing: text)
        func str(_ key: String) -> String { ini.value(section: section, key: key) ?? "" }
        func int(_ key: String) -> Int { Int(str(key)) ?? 0 }

        let count = int("Count")
        guard count > 0 else { return [] }

        var out: [SavedLayout] = []
        for i in 0..<count {
            let name = str("Name\(i)").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let left = WorkspaceCodec.decode(str("Left\(i)"))
            let right = WorkspaceCodec.decode(str("Right\(i)"))
            guard !left.isEmpty || !right.isEmpty else { continue }
            out.append(SavedLayout(
                name: name,
                left: left, leftActive: int("LeftActive\(i)"),
                right: right, rightActive: int("RightActive\(i)"),
                activeSide: str("Active\(i)").isEmpty ? "left" : str("Active\(i)")))
        }
        return out
    }
}
