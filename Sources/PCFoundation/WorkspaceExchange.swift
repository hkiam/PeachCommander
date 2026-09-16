// SPDX-License-Identifier: Apache-2.0
// WorkspaceExchange.swift - A workspace as a file you can hand to somebody (F-499).
//
// The storage format *is* the exchange format: `workspaces/<id>.json` and a `.pcworkspace` are the
// same JSON, which is why there is no writer here — only the two adjustments that a file leaving this
// Mac, or arriving on another one, needs.
//
// ## What is deliberately not in an exported file
//
//   * **Anything that could be a credential.** Rather than carrying a site *name* and hoping, tabs
//     that point at a connection or a plugin mount are **removed** on export and counted in the
//     report. Then there is nothing to leak, because nothing about a connection is written — which is
//     stronger than sanitising and can be proved by a test that exports and greps the bytes.
//   * **The journal.** It is a record of what *you* did, naming folders on your machine. Sending it
//     along is an accidental disclosure with no upside; it lives in its own file and simply is not
//     part of this one.
//   * **The live state.** An imported workspace arrives at its baseline — that is what a baseline is
//     for — so cursor positions and whatever the sender happened to be looking at do not travel.
//
// Paths under the sender's home are written tilde-abbreviated, so a workspace handed to a colleague
// lands in *their* home rather than in a folder named after the sender.

import Foundation

public enum WorkspaceExchange {

    public static let fileExtension = "pcworkspace"

    /// What an export left out, so the sheet can say it rather than the user finding out later.
    public struct ExportReport: Sendable, Equatable {
        public var droppedTabs: Int
        public var droppedStashItems: Int
    }

    /// Prepare a workspace for leaving this Mac.
    ///
    /// - Parameter home: the sender's home directory, for the tilde abbreviation. Injected so this is
    ///   testable without depending on whose machine the test runs on.
    public static func forExport(_ workspace: Workspace, home: String) -> (Workspace, ExportReport) {
        var out = workspace
        var report = ExportReport(droppedTabs: 0, droppedStashItems: 0)

        out.baseline.left = clean(out.baseline.left, home: home, dropped: &report.droppedTabs)
        out.baseline.right = clean(out.baseline.right, home: home, dropped: &report.droppedTabs)
        // One state, and it is the baseline: an imported workspace starts where it was set up, so
        // whatever the sender happened to be looking at does not travel. The encoder then omits
        // `live` entirely, because it equals the baseline — see `Workspace.encode`.
        out.live = out.baseline

        // The stash points at this Mac's files. Kept — the names are often the whole point of handing
        // a workspace over — but anything on a connection goes, for the same reason a tab does.
        let keptItems = out.stash.items.filter { !isRemote($0.path) }
        report.droppedStashItems = out.stash.count - keptItems.count
        out.stash = WorkspaceStash(items: keptItems.map {
            StashItem(path: abbreviate($0.path, home: home), addedAt: $0.addedAt, note: $0.note)
        })

        // **The chrome travels, pixel measurements included, and that is deliberate.** A workspace set
        // up with a wide left panel for a comparison job should arrive that way — the arrangement is
        // most of what somebody is handing over. The frame of the window itself is not in this type at
        // all, so "the window size does not travel" holds; what does is three measurements inside it,
        // and each of them lands safely on a smaller screen: `NSSplitView.setPosition` clamps to the
        // pane minimums, and the preview and dock go through `max(minimum, …)`. A fraction would be
        // the better unit, but it is the unit of the *stored* format, shared with every workspace
        // already on disk — not something to change from the export side.
        // `isSet`, deliberately: a root that is not an absolute path is not a scope here and must not
        // become one over there either — it would refuse every operation on the receiver's Mac.
        out.scope.root = out.scope.isSet ? abbreviate(out.scope.root, home: home) : ""
        // Neither means anything on the machine this is going to, and a number that survived the trip
        // would only be wrong there — the same reason an exported macro carries no `order`.
        out.order = 0
        out.lastUsed = nil
        return (out, report)
    }

    /// What an import had to change, so the report can say it.
    public struct ImportReport: Sendable, Equatable {
        public var renamedTo: String?
        public var relocatedTabs: Int
        public var missingStashItems: Int
        public var scopeRelaxed: Bool
    }

    /// Prepare an arriving workspace for this Mac.
    ///
    /// - Parameters:
    ///   - taken: ids already in use, so an arriving workspace never replaces one.
    ///   - home: this Mac's home, for expanding the tildes.
    ///   - directoryExists: whether a *folder* is there — a tab and a scope root are both folders.
    ///   - itemExists: whether *anything* is there. Separate from the one above rather than sharing
    ///     it, because the stash holds files: asking "is this a directory?" about `~/report.pdf`
    ///     answers no, and every stash entry would be reported as missing.
    ///   - nearestExisting: how to walk up to a folder that does exist.
    public static func forImport(_ workspace: Workspace,
                                 taken: Set<String>,
                                 home: String,
                                 directoryExists: (String) -> Bool,
                                 itemExists: (String) -> Bool,
                                 nearestExisting: (String) -> String) -> (Workspace, ImportReport) {
        var out = workspace
        var report = ImportReport(renamedTo: nil, relocatedTabs: 0,
                                  missingStashItems: 0, scopeRelaxed: false)

        let id = WorkspaceID.unique(from: workspace.name, taken: taken)
        if id != workspace.id { report.renamedTo = id }
        out.id = id
        out.created = Date()
        out.lastUsed = nil

        out.baseline.left = land(out.baseline.left, home: home, exists: directoryExists,
                                 nearestExisting: nearestExisting, relocated: &report.relocatedTabs)
        out.baseline.right = land(out.baseline.right, home: home, exists: directoryExists,
                                  nearestExisting: nearestExisting, relocated: &report.relocatedTabs)
        out.live = out.baseline

        // Stash items keep their paths and are simply reported: an import that silently pruned twelve
        // of them would have thrown away the point of the file, and a volume mounted tomorrow brings
        // them back.
        out.stash = WorkspaceStash(items: out.stash.items.map {
            StashItem(path: expand($0.path, home: home), addedAt: $0.addedAt, note: $0.note)
        })
        report.missingStashItems = out.stash.items.filter { !itemExists($0.path) }.count

        // `hasRoot`, because the root arrives tilde-abbreviated and is not enforceable *until* the
        // line below expands it. Asking `isSet` here would skip the expansion and silently drop the
        // folder limit the sender set.
        if out.scope.hasRoot {
            out.scope.root = expand(out.scope.root, home: home)
            // **A missing root is kept, but the enforcement is relaxed to `ask`.** A `refuse` scope
            // rooted at a folder that does not exist here refuses every operation in the workspace,
            // with a reason the user cannot act on — the file would arrive broken and look like the
            // import's fault.
            if !directoryExists(out.scope.root), out.scope.enforcement == .refuse {
                out.scope.enforcement = .ask
                report.scopeRelaxed = true
            }
        }
        return (out, report)
    }

    // MARK: - Bytes

    /// The bytes of a `.pcworkspace`, prepared for leaving this Mac.
    public static func encode(_ workspace: Workspace, home: String) throws -> (Data, ExportReport) {
        let (prepared, report) = forExport(workspace, home: home)
        var data = try WorkspaceStore.encoder.encode(prepared)
        if data.last != 0x0A { data.append(0x0A) }
        return (data, report)
    }

    /// The most a `.pcworkspace` may be before it is refused unread.
    ///
    /// A real one is a couple of kilobytes; nine workspaces with full stashes do not approach this.
    /// It exists because these arrive from other people — a double-click on a mail attachment — and
    /// `Data(contentsOf:)` is happy to pull a gigabyte of anything into memory before the first
    /// question about it is asked.
    public static let maximumFileSize = 8 * 1024 * 1024

    /// Read a `.pcworkspace` somebody sent. Nil when it is not one, never a throw: this is a file a
    /// person picked in an open panel, and half of what lands there will be the wrong file.
    public static func decode(_ data: Data) -> Workspace? {
        guard !data.isEmpty, data.count <= maximumFileSize,
              let workspace = try? WorkspaceStore.decoder.decode(Workspace.self, from: data),
              workspace.formatVersion <= Workspace.currentFormatVersion
        else { return nil }
        return workspace
    }

    // MARK: - Pieces

    /// A tab that points at a connection or a plugin mount, which never travels.
    static func isRemote(_ path: String) -> Bool {
        path.hasPrefix("netmount:") || path.hasPrefix("pfxmount:")
            || path.contains("://")
    }

    private static func clean(_ pane: PaneState, home: String, dropped: inout Int) -> PaneState {
        var out = pane
        let kept = pane.tabs.filter { $0.driveVolume == nil && !isRemote($0.path) }
        dropped += pane.tabs.count - kept.count
        out.tabs = kept.map {
            var tab = $0
            tab.path = abbreviate(tab.path, home: home)
            // The cursor and the marks are this Mac's files; a folder list is what travels.
            tab.cursorName = nil
            tab.marked = nil
            return tab
        }
        // A pane emptied by the cleaning still needs somewhere to be, and the receiver's home is the
        // only folder both machines are certain to have.
        if out.tabs.isEmpty { out.tabs = [PanelTabState(path: "~")] }
        out.activeIndex = min(max(0, out.activeIndex), max(0, out.tabs.count - 1))
        out.history = []
        out.historyIndex = 0
        return out
    }

    private static func land(_ pane: PaneState, home: String, exists: (String) -> Bool,
                             nearestExisting: (String) -> String, relocated: inout Int) -> PaneState {
        var out = pane
        out.tabs = pane.tabs.map { tab in
            var moved = tab
            moved.path = expand(tab.path, home: home)
            guard !exists(moved.path) else { return moved }
            // A workspace that opens onto four error panels is a workspace nobody keeps.
            moved.path = nearestExisting(moved.path)
            relocated += 1
            return moved
        }
        return out
    }

    static func abbreviate(_ path: String, home: String) -> String {
        guard !home.isEmpty else { return path }
        if path == home { return "~" }
        guard path.hasPrefix(home + "/") else { return path }
        return "~" + path.dropFirst(home.count)
    }

    static func expand(_ path: String, home: String) -> String {
        guard !home.isEmpty, path.hasPrefix("~") else { return path }
        if path == "~" { return home }
        guard path.hasPrefix("~/") else { return path }
        return home + path.dropFirst(1)
    }
}
