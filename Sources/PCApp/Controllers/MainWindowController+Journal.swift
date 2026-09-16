// SPDX-License-Identifier: Apache-2.0
// MainWindowController+Journal.swift - Writing down what happened in a workspace (F-499).
//
// One entry point, `journal(_:label:directory:payload:outcome:)`, called from four places:
//
//   * `recordInHistory` — every completed file operation, with the repeat payload already assembled.
//   * `loadPath` — navigation, beside the global history's own note.
//   * the command line — shell lines, with the folder they ran in.
//   * the scope gate — the refusals, which have no counterpart in the global history at all and are
//     the reason somebody opens this window.
//
// The journal is loaded lazily and written debounced: it is appended to on every navigation, and a
// synchronous write there would put the disk on the path of pressing Return on a folder.

import AppKit
import PCFoundation

extension MainWindowController {

    /// The active workspace's journal, read from disk the first time it is wanted.
    var activeJournal: WorkspaceJournal {
        if let cached = journalCache[activeWorkspaceID] { return cached }
        let loaded = workspaceStore.loadJournal(id: activeWorkspaceID)
        journalCache[activeWorkspaceID] = loaded
        return loaded
    }

    /// Write one thing down.
    ///
    /// Silent when the feature or the journal is switched off, and silent while a workspace switch is
    /// rebuilding the panes — the folders a switch passes through are not places the user went, the
    /// same reason `HistoryService.beginSessionRestore` exists (F-402).
    func journal(_ kind: JournalEntry.Kind, label: String, directory: String,
                 payload: String = "", outcome: JournalEntry.Outcome = .done) {
        guard workspacesEnabled, journalEnabled, !isSwitchingWorkspace,
              !activeWorkspaceID.isEmpty else { return }
        var journal = activeJournal
        journal.append(JournalEntry(kind: kind, label: label, directory: directory,
                                    payload: payload, outcome: outcome))
        journalCache[activeWorkspaceID] = journal
        scheduleJournalSave()
    }

    /// Debounced, for the same reason the session save is: navigation appends, and navigation is the
    /// thing that has to stay instant.
    private func scheduleJournalSave() {
        guard !journalSaveScheduled else { return }
        journalSaveScheduled = true
        let id = activeWorkspaceID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.journalSaveScheduled = false
            self.flushJournal(id: id)
        }
    }

    /// Write one workspace's journal out. Called on the debounce, on a switch and on quit.
    func flushJournal(id: String) {
        guard let journal = journalCache[id] else { return }
        let store = workspaceStore
        Task.detached(priority: .utility) { store.saveJournal(journal, for: id) }
    }

    func flushAllJournals() {
        let store = workspaceStore
        for (id, journal) in journalCache { store.saveJournal(journal, for: id) }
    }

    func clearActiveJournal() {
        journalCache[activeWorkspaceID] = WorkspaceJournal()
        flushJournal(id: activeWorkspaceID)
    }

    // MARK: - The window

    /// `cm_WorkspaceJournal` — show what was done in this workspace.
    func showWorkspaceJournal() {
        guard workspacesEnabled else { NSSound.beep(); return }
        let controller = WorkspaceJournalWindowController(
            journal: activeJournal,
            workspaceName: activeWorkspace?.name ?? "")
        controller.onRepeat = { [weak self] entry in self?.repeatJournalEntry(entry) }
        controller.onClear = { [weak self] in self?.clearActiveJournal() }
        journalWindow = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    /// Do one of them again.
    ///
    /// Through `repeatRecordedOperation`, the same method the history palette drives — and therefore
    /// under the same rule: `HistoryOperation.decode` answers only for copy and move, so a delete
    /// stays out of reach of one keystroke on a row somebody is only reading. A shell line fills the
    /// command line rather than running, for the reason the palette's own header gives.
    private func repeatJournalEntry(_ entry: JournalEntry) {
        if entry.kind == .command {
            // Filled in, not run — the same rule the history palette states: a shell line from three
            // days ago, picked off a list somebody is skimming, is one keystroke away from something
            // they did not read. It arrives ready to run.
            commandLine.prefill(entry.label, in: window)
            return
        }
        guard let decoded = HistoryOperation.decode(entry.payload),
              let panel = activePanel else { NSSound.beep(); return }
        Task { @MainActor in
            await panel.repeatRecordedOperation(kind: decoded.kind, items: decoded.items,
                                                mask: decoded.mask, to: entry.directory)
        }
    }
}
