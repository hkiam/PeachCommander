// SPDX-License-Identifier: Apache-2.0
// MainWindowController+Stash.swift - The collecting basket, and what a drop on a chip does (F-499).
//
// The gesture this exists for: you are deep in the backups, you find something that belongs to an
// entirely different job, and you drag it onto that job's chip. It lands in that workspace's basket
// and you carry on with what you were doing — no switch, no dialog, nothing lost.
//
// Which is also why the plain drop **collects** rather than copying or moving. The strip sits one
// pixel under the top edge of the window, it is on the way to the Finder, and the gesture ends in a
// mouse-up that cannot be taken back. ⌥ copies and ⌘ moves, the same two keys the panel's own drop
// already uses, and both of those go through the ordinary operation machinery — background transfer,
// overwrite resolver, undo entry — rather than around it.

import AppKit
import PCFoundation

extension MainWindowController {

    // MARK: - The basket

    var activeStash: WorkspaceStash {
        activeWorkspace?.stash ?? WorkspaceStash()
    }

    /// Add paths to a workspace's basket and say what happened.
    ///
    /// Reports duplicates separately because "3 added" leaves somebody wondering where the fourth
    /// went; the status line says "3 added to Backups · 1 already there".
    @discardableResult
    func addToStash(_ paths: [String], workspaceID: String? = nil) -> (added: Int, duplicates: Int) {
        let id = workspaceID ?? activeWorkspaceID
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return (0, 0) }
        let result = workspaces[index].stash.add(paths)
        guard result.added > 0 || result.duplicates > 0 else { return result }
        workspaceStore.save(workspaces[index])
        // The chip's counter going up *is* the feedback, and it is feedback in the right place: on the
        // workspace the files went to, which may not be the one on screen. A status line would say it
        // once, somewhere else, and be gone before anybody looked.
        refreshWorkspaceBar()
        // Except when nothing happened — everything was already in the basket, and a counter that does
        // not move looks exactly like a drop that missed.
        if result.added == 0 { NSSound.beep() }
        return result
    }

    func removeFromStash(paths: Set<String>) {
        guard let index = activeWorkspaceIndex, !paths.isEmpty else { return }
        workspaces[index].stash.remove(paths: paths)
        workspaceStore.save(workspaces[index])
        refreshWorkspaceBar()
    }

    func clearStash() {
        guard let index = activeWorkspaceIndex, !workspaces[index].stash.isEmpty else { return }
        workspaces[index].stash.removeAll()
        workspaceStore.save(workspaces[index])
        refreshWorkspaceBar()
    }

    /// Split the basket into what is still on disk and what is not.
    ///
    /// Asked fresh every time rather than cached: a volume mounted a minute ago changes the answer,
    /// and a basket that still calls those files missing is one people stop believing.
    func partitionStash() -> (live: [StashItem], stale: [StashItem]) {
        activeStash.partition { FileManager.default.fileExists(atPath: $0) }
    }

    /// What the side panel's Stash page shows.
    ///
    /// Missing files are listed rather than hidden, with the folder they came from: a file gone
    /// because a volume is not mounted has to come back when it is, and one deleted since is worth
    /// seeing before an operation runs rather than after it.
    func stashPageText() -> String {
        let stash = activeStash
        guard !stash.isEmpty else {
            return String(localized:
                "Nothing collected yet.\n\nDrag files onto a workspace chip, or press Ctrl+Cmd+A to add what is selected.")
        }
        let split = partitionStash()
        var lines: [String] = []
        if split.stale.isEmpty {
            lines.append(String(format: String(localized: "In the stash: %lld"), stash.count))
        } else {
            lines.append(String(format: String(localized: "In the stash: %1$lld · missing: %2$lld"),
                                stash.count, split.stale.count))
        }
        lines.append("")
        for item in stash.items {
            let missing = split.stale.contains { $0.path == item.path }
            let folder = (item.folder as NSString).abbreviatingWithTildeInPath
            lines.append(missing ? "· \(item.name)  —  \(folder)  " + String(localized: "(missing)")
                                 : "· \(item.name)  —  \(folder)")
            if !item.note.isEmpty { lines.append("    \(item.note)") }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Commands

    /// `cm_StashAdd` — put the panel's selection in this workspace's basket.
    func addSelectionToStash() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            let paths = await panel.selectedOrCursorPaths()
            guard !paths.isEmpty else { NSSound.beep(); return }
            addToStash(paths)
        }
    }

    /// `cm_StashClear`.
    func clearStashCommand() {
        guard !activeStash.isEmpty else { NSSound.beep(); return }
        clearStash()
    }

    // MARK: - Doing something with the lot

    /// What to do about entries whose file is not there any more.
    private enum StaleChoice { case skip, remove, cancel }

    /// Ask, but only when there is something to ask about.
    ///
    /// A bulk operation with missing files does not start. The three answers are the three things a
    /// person actually wants — get on with the rest, tidy them away, or stop and look — and "stop and
    /// look" is the default button, because the missing file may be the one that mattered.
    private func askAboutStale(_ stale: [StashItem]) -> StaleChoice {
        guard !stale.isEmpty else { return .skip }
        // A scripted run answers from the environment rather than hanging on a modal nobody is there
        // to click — the same escape hatch the macro manager's dialogs use (F-436).
        if let scripted = AutomationProbe.value("PC_STASH_STALE") {
            return scripted == "remove" ? .remove : (scripted == "cancel" ? .cancel : .skip)
        }
        let alert = NSAlert()
        alert.messageText = String(localized: "Some of these files are not there any more.")
        alert.informativeText = String(format: String(localized: "Missing: %lld"), stale.count)
            + "\n\n" + stale.prefix(5).map(\.name).joined(separator: "\n")
            + (stale.count > 5 ? "\n…" : "")
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.addButton(withTitle: String(localized: "Skip Them"))
        alert.addButton(withTitle: String(localized: "Remove Them from the Stash"))
        alert.alertStyle = .warning
        switch alert.runModal() {
        case .alertSecondButtonReturn: return .skip
        case .alertThirdButtonReturn: return .remove
        default: return .cancel
        }
    }

    /// Copy or move the whole basket into the other panel — `cm_StashCopyTo` / `cm_StashMoveTo`.
    ///
    /// The **other panel** is the destination, which is what F5 and F6 already mean here; a basket
    /// that opened a folder chooser would be the one operation in the app that asks where things go.
    ///
    /// One job, not a loop: it goes through the panel's own drop, so the background transfer, the
    /// overwrite resolver, the privileged-copy fallback, the undo entry and the history record are the
    /// ones every other copy in this application gets.
    func runStashOperation(move: Bool) {
        let split = partitionStash()
        guard !activeStash.isEmpty else { NSSound.beep(); return }

        switch askAboutStale(split.stale) {
        case .cancel: return
        case .remove: removeFromStash(paths: Set(split.stale.map(\.path)))
        case .skip: break
        }
        guard !split.live.isEmpty else { NSSound.beep(); return }

        guard let target = getInactivePanel() else { NSSound.beep(); return }
        let paths = split.live.map(\.path)
        Task { @MainActor in
            let destination = await target.getCurrentPath()
            await target.performDrop(paths: paths, move: move, into: destination)
            // After a move the basket's entries point at where the files *were*, so they leave it. A
            // copy leaves them alone: the originals are still there and may still be wanted.
            if move { removeFromStash(paths: Set(paths)) }
        }
    }

    // MARK: - A drop on a chip

    func handleChipDrop(index: Int, paths: [String], intent: WorkspaceBarView.DropIntent) {
        guard workspaces.indices.contains(index), !paths.isEmpty else { return }
        let target = workspaces[index]

        switch intent {
        case .stash:
            addToStash(paths, workspaceID: target.id)
        case .copyIntoActiveFolder, .moveIntoActiveFolder:
            let move = intent == .moveIntoActiveFolder
            // Where that workspace is looking, read from its stored state rather than from the window
            // — it is not on screen, and this is the whole point of being able to drop onto it.
            let side = target.live.activeSide
            let pane = side == .right ? target.live.right : target.live.left
            guard pane.tabs.indices.contains(pane.activeIndex) else { NSSound.beep(); return }
            let destination = pane.tabs[pane.activeIndex].path
            Task { @MainActor in
                if target.id != activeWorkspaceID { await switchWorkspace(to: target.id) }
                // Through the panel's own drop, so the transfer, the overwrite resolver and the undo
                // entry are the ones every other copy and move in the app gets.
                await activePanel?.performDrop(paths: paths, move: move, into: destination)
            }
        }
    }
}
