// SPDX-License-Identifier: Apache-2.0
// MainWindowController+WorkspaceFile.swift - A workspace as a file you can hand over (F-499).
//
// The storage format *is* the exchange format, so there is no writer here and no second schema to keep
// in step — `WorkspaceExchange` makes the two adjustments a file needs to leave this Mac or arrive on
// another one, and everything below is the dialogs around it.
//
// Three things this deliberately does not do:
//
//   * **It does not switch.** Double-clicking a `.pcworkspace` in the Finder adds a workspace and says
//     so; it does not throw away what you were looking at. A file somebody mailed you is not a command.
//     The report offers the switch as a button, one click away.
//   * **It does not merge into an existing workspace.** An import is always a new one, with a fresh
//     id — so a file can never overwrite the workspace you are standing in, which is the failure mode
//     that would make people afraid to open these.
//   * **It does not ask what to leave out.** What a `.pcworkspace` excludes is fixed and stated, not a
//     row of checkboxes: an export dialog with "include connections" on it is one wrong click away
//     from being the disclosure it exists to prevent.

import AppKit
import PCFoundation
import UniformTypeIdentifiers

extension MainWindowController {

    // MARK: - Export

    /// `cm_ExportWorkspace` — write the current workspace to a file.
    func exportWorkspaceCommand() {
        guard workspacesEnabled, let workspace = activeWorkspace else { return }
        // **The saved starting point travels, not wherever you are standing right now.** That is what
        // a baseline is for, and it has the property that makes these files worth keeping: exporting
        // the same workspace twice a week apart produces the same bytes, because it does not pick up
        // the temp folder somebody wandered into. ⌘⌃S is how you change what gets sent, and the report
        // below says so, because otherwise the difference is only discovered at the other end.
        let suggested = "\(workspace.id).\(WorkspaceExchange.fileExtension)"
        guard let url = WorkspaceFilePrompt.chooseExportFile(named: suggested, in: window) else { return }
        do {
            let (data, report) = try WorkspaceExchange.encode(workspace, home: NSHomeDirectory())
            try data.write(to: url, options: .atomic)
            reportExport(report, name: workspace.name, url: url)
        } catch {
            WorkspaceFilePrompt.note(String(localized: "The workspace could not be exported."),
                                     detail: String(describing: error), in: window)
        }
    }

    /// What the file does *not* contain, said at the moment it is written rather than in a help page
    /// somebody reads afterwards.
    private func reportExport(_ report: WorkspaceExchange.ExportReport, name: String, url: URL) {
        var lines: [String] = []
        if report.droppedTabs > 0 {
            lines.append(String(format: String(localized:
                "%d tabs pointed at a connection or a mounted plugin drive. They are not in the file."),
                report.droppedTabs))
        }
        if report.droppedStashItems > 0 {
            lines.append(String(format: String(localized:
                "%d stash entries were on a connection and are not in the file."),
                report.droppedStashItems))
        }
        // Said every time, not only when something was dropped: it is the sentence that lets somebody
        // send one of these without first having to work out what is in it.
        lines.append(String(localized:
            "The file holds this workspace's saved starting point, not the folders you happen to be in."))
        lines.append(String(localized:
            "The journal stays on this Mac. Cursor positions, the undo history and the window frame are not included."))
        WorkspaceFilePrompt.note(String(format: String(localized: "“%@” was written to %@."),
                                        name, url.lastPathComponent),
                                 detail: lines.joined(separator: "\n\n"), in: window)
    }

    // MARK: - Import

    /// `cm_ImportWorkspace`.
    func importWorkspaceCommand() {
        guard workspacesEnabled else { return }
        let urls = WorkspaceFilePrompt.chooseImportFiles(in: window)
        guard !urls.isEmpty else { return }
        Task { @MainActor in await importWorkspaceFiles(urls) }
    }

    /// Add the workspaces in these files. Also the entry point for a double-click in the Finder.
    func importWorkspaceFiles(_ urls: [URL]) async {
        // **Cold start.** Double-clicking a `.pcworkspace` while the app is not running delivers the
        // file from `applicationDidFinishLaunching`, and `loadWorkspaces()` runs later, inside the
        // asynchronous session restore. Importing before it would be lost twice over: the list this
        // appends to is about to be replaced by what is on disk, and writing a workspace file would
        // create the directory whose absence is what triggers the one-time migration — so somebody
        // upgrading would silently lose their saved layouts to a file a colleague sent them.
        //
        // `workspaces` is never empty once the load has run, which makes it the readiness signal.
        // Bounded, because a wait that can hang forever in a launch path is worse than an import that
        // gives up: ten seconds is far past any restore, and in-app imports never wait at all.
        var waited = 0
        while workspaces.isEmpty && waited < 200 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            waited += 1
        }
        guard !workspaces.isEmpty else { return }

        guard workspacesEnabled else {
            WorkspaceFilePrompt.note(String(localized: "Workspaces are switched off."),
                                     detail: String(localized:
                "Switch them on under Settings ▸ Tabs to open this file."), in: window)
            return
        }
        var added: [Workspace] = []
        var reports: [WorkspaceExchange.ImportReport] = []
        var unreadable: [String] = []

        for url in urls {
            guard workspaces.count + added.count < Self.maxWorkspaces else { break }
            guard let data = try? Data(contentsOf: url), let incoming = WorkspaceExchange.decode(data) else {
                unreadable.append(url.lastPathComponent)
                continue
            }
            // `taken` counts the ones added in this same pass, or importing a file twice in one go
            // would produce two workspaces claiming one filename and the second would win.
            let taken = Set(workspaces.map(\.id)).union(added.map(\.id))
            let (prepared, report) = WorkspaceExchange.forImport(
                incoming, taken: taken, home: NSHomeDirectory(),
                directoryExists: { Self.directoryExists($0) },
                itemExists: { FileManager.default.fileExists(atPath: $0) },
                nearestExisting: { Self.nearestExistingDirectory($0) })
            var landed = prepared
            landed.order = (workspaces.map(\.order).max() ?? -1) + added.count + 1
            // Against what is already added too, or two arriving workspaces that both collide would
            // both be handed the same "next free" colour and arrive as twins.
            let usedTints = Set(workspaces.map(\.tint)).union(added.map(\.tint))
            if usedTints.contains(landed.tint) {
                landed.tint = (0..<WorkspaceMigration.tintCount).first { !usedTints.contains($0) }
                    ?? nextFreeTint()
            }
            added.append(landed)
            reports.append(report)
        }

        for workspace in added {
            workspaces.append(workspace)
            workspaceStore.save(workspace)
        }
        if !added.isEmpty {
            refreshWorkspaceBar()
            rebuildMainMenu()
        }
        reportImport(added, reports: reports, unreadable: unreadable, offered: urls.count)
    }

    private func reportImport(_ added: [Workspace], reports: [WorkspaceExchange.ImportReport],
                              unreadable: [String], offered: Int) {
        var lines: [String] = []
        for (workspace, report) in zip(added, reports) {
            var notes: [String] = []
            if let renamed = report.renamedTo {
                notes.append(String(format: String(localized: "stored as “%@”"), renamed))
            }
            if report.relocatedTabs > 0 {
                notes.append(String(format: String(localized:
                    "%d tabs pointed at folders that are not on this Mac and moved up to the nearest one that is"),
                    report.relocatedTabs))
            }
            if report.missingStashItems > 0 {
                notes.append(String(format: String(localized:
                    "%d stash entries are not on this Mac and are shown greyed out"),
                    report.missingStashItems))
            }
            if report.scopeRelaxed {
                // Worth its own sentence: the sender set this workspace to refuse work outside a
                // folder, that folder is not here, and a refusal the user cannot act on would make
                // every operation in the workspace fail with a reason about somebody else's Mac.
                notes.append(String(localized:
                    "its folder limit points somewhere that is not on this Mac, so it asks instead of refusing"))
            }
            lines.append(notes.isEmpty ? workspace.name
                                       : "\(workspace.name) — " + notes.joined(separator: ", "))
        }
        if !unreadable.isEmpty {
            lines.append(String(format: String(localized: "Not a workspace file: %@"),
                                unreadable.joined(separator: ", ")))
        }
        if added.isEmpty && unreadable.isEmpty && offered > 0 {
            lines.append(String(format: String(localized: "There is no room for more than %d workspaces."),
                                Self.maxWorkspaces))
        }

        let title = added.isEmpty
            ? String(localized: "Nothing was imported.")
            : String(format: String(localized: "%d workspaces added."), added.count)
        // The switch is offered, never taken: a file somebody sent should not be able to move the
        // window you are working in.
        guard let first = added.first else {
            WorkspaceFilePrompt.note(title, detail: lines.joined(separator: "\n"), in: window)
            return
        }
        let switchNow = WorkspaceFilePrompt.confirm(
            title, detail: lines.joined(separator: "\n"),
            accept: String(format: String(localized: "Switch to “%@”"), first.name),
            in: window)
        if switchNow { Task { @MainActor in await switchWorkspace(to: first.id) } }
    }

    // MARK: - Paths

    static func directoryExists(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    /// Walk up to a folder that is actually there.
    ///
    /// Not `settleTabOnNearestReachableAncestor`: that one navigates a *live* panel and reports what
    /// the panel did, and at import time the workspace has no panel — it is not even the active one.
    /// Bounded for the same reason that one is: a hand-written file is free to contain a path that
    /// `deletingLastPathComponent` never shortens to "/".
    static func nearestExistingDirectory(_ path: String) -> String {
        var candidate = path
        for _ in 0..<64 {
            let parent = (candidate as NSString).deletingLastPathComponent
            if parent.isEmpty || parent == candidate { break }
            candidate = parent
            if directoryExists(candidate) { return candidate }
        }
        return NSHomeDirectory()
    }
}

/// The dialogs, with the escape hatch every modal in this app needs.
///
/// An `NSSavePanel` in a headless automation run is a nested run loop the script never gets out of, so
/// the environment answers for it (F-436) — the same arrangement `MacroManagerPrompt` uses, and for
/// the same reason.
enum WorkspaceFilePrompt {

    /// True in an automation run, where a file panel would be a nested run loop nothing gets out of.
    /// The probes count as well, so a scenario that answers one of them never reaches a panel either.
    private static var isScripted: Bool {
        AutomationProbe.value("PC_WORKSPACE_EXPORT") != nil
            || AutomationProbe.value("PC_WORKSPACE_IMPORT") != nil
            || AutomationProbe.isScriptedRun
    }

    @MainActor
    static func chooseExportFile(named name: String, in window: NSWindow?) -> URL? {
        if let scripted = AutomationProbe.value("PC_WORKSPACE_EXPORT") {
            return URL(fileURLWithPath: scripted)
        }
        guard !isScripted else { return nil }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [WorkspaceFilePrompt.type]
        panel.canCreateDirectories = true
        panel.message = String(localized: "Where should this workspace be written?")
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// `PC_WORKSPACE_IMPORT` may name several files, separated by `|`.
    @MainActor
    static func chooseImportFiles(in window: NSWindow?) -> [URL] {
        if let scripted = AutomationProbe.value("PC_WORKSPACE_IMPORT") {
            return scripted.split(separator: "|").map { URL(fileURLWithPath: String($0)) }
        }
        guard !isScripted else { return [] }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [WorkspaceFilePrompt.type]
        panel.message = String(localized: "Which workspace files should be added?")
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    /// The declared type, falling back to plain JSON on a build whose `Info.plist` has not been
    /// re-generated — a file picker that shows nothing selectable is a worse failure than one that is
    /// a little too permissive.
    static var type: UTType {
        UTType("com.peachcommander.workspace") ?? .json
    }

    @MainActor
    static func note(_ message: String, detail: String, in window: NSWindow?) {
        guard !isScripted else {
            NSLog("[workspace] %@ %@", message, detail.replacingOccurrences(of: "\n", with: " "))
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    @MainActor
    static func confirm(_ message: String, detail: String, accept: String, in window: NSWindow?) -> Bool {
        guard !isScripted else {
            NSLog("[workspace] %@ %@", message, detail.replacingOccurrences(of: "\n", with: " "))
            return false
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: accept)
        alert.addButton(withTitle: String(localized: "Stay Here"))
        return alert.runModal() == .alertFirstButtonReturn
    }
}
