// SPDX-License-Identifier: Apache-2.0
// MainWindowController+WorkspaceMenu.swift - The two commands that survived, and what they mean now.
//
// `cm_Workspaces` and `cm_SaveWorkspace` are kept — id, name and ⌘⌃S — rather than replaced. People
// have that shortcut in `keymap-user.ini`, on `.bar` buttons, in `.mnu` files and in their fingers,
// and the help page documents it. What changed is what they do.
//
// They are also the whole of the feature's surface in the **latent** state: one workspace, no chip
// strip, no menu of its own. Both already sit in the Go menu today, so somebody who never makes a
// second workspace sees exactly what they saw before this feature was rebuilt — which is the point.
//
// **`cm_SaveWorkspace` is the interesting one.** In a living model there is no "save the layout",
// because the workspace saves itself continuously. The honest successor is one keystroke away: make
// *now* the state this workspace goes back to. For somebody still in the unnamed default workspace it
// first asks for a name, which is byte-for-byte what the old command did.

import AppKit
import PCFoundation

extension MainWindowController {

    /// Hub: switch, create, rename, delete — `cm_Workspaces`.
    func showWorkspaces() {
        guard let panel = activePanel else { return }
        let menu = NSMenu(title: String(localized: "Workspaces"))
        // Off, or AppKit recomputes every item's enabled state from the responder chain and the
        // `isEnabled = false` set below is overwritten before the menu is drawn — nothing here
        // validates, so everything would come back enabled (the F-385 lesson). It was already wrong
        // for "New Workspace…" at nine workspaces: the item read as available and did nothing.
        menu.autoenablesItems = false

        for (i, workspace) in workspaces.enumerated() {
            let item = NSMenuItem(title: workspace.name,
                                  action: #selector(switchWorkspaceMenu(_:)),
                                  keyEquivalent: i < 9 ? "\(i + 1)" : "")
            item.keyEquivalentModifierMask = []
            item.representedObject = workspace.id
            item.target = self
            item.state = workspace.id == activeWorkspaceID ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let new = NSMenuItem(title: String(localized: "New Workspace…"),
                             action: #selector(newWorkspacePrompt), keyEquivalent: "")
        new.target = self
        // Nine is the limit, and a greyed item with a reason beats one that silently does nothing.
        new.isEnabled = workspaces.count < Self.maxWorkspaces
        menu.addItem(new)

        if let active = activeWorkspace {
            let rename = NSMenuItem(title: String(localized: "Rename Workspace…"),
                                    action: #selector(renameWorkspacePrompt), keyEquivalent: "")
            rename.target = self
            menu.addItem(rename)

            let reset = NSMenuItem(title: String(localized: "Reset to Saved State"),
                                   action: #selector(resetWorkspaceMenu), keyEquivalent: "")
            reset.target = self
            menu.addItem(reset)

            if workspaces.count > 1 {
                let delete = NSMenuItem(title: String(format: String(localized: "Delete “%@”…"), active.name),
                                        action: #selector(deleteWorkspacePrompt), keyEquivalent: "")
                delete.target = self
                menu.addItem(delete)
            }

            // Export and import live here as well as in the Workspace menu, because in the **latent**
            // state this popup is the only surface the feature has — and a workspace somebody mailed
            // you would otherwise be reachable only by finding the file in the Finder. Importing one
            // is also the second way out of latency, alongside "New Workspace…".
            menu.addItem(.separator())
            let export = NSMenuItem(title: String(localized: "Export Workspace…"),
                                    action: #selector(exportWorkspaceMenu), keyEquivalent: "")
            export.target = self
            menu.addItem(export)
            let importItem = NSMenuItem(title: String(localized: "Import Workspace…"),
                                        action: #selector(importWorkspaceMenu), keyEquivalent: "")
            importItem.target = self
            // Nine is the limit here too, and a greyed item with a reason beats one that reads the
            // file and then silently drops it.
            importItem.isEnabled = workspaces.count < Self.maxWorkspaces
            menu.addItem(importItem)
        }

        let point = NSPoint(x: 12, y: panel.view.bounds.height - 36)
        menu.popUp(positioning: nil, at: point, in: panel.view)
    }

    /// Make the current arrangement the one this workspace resets to — `cm_SaveWorkspace`, ⌘⌃S.
    func showSaveWorkspace() {
        // Still in the unnamed default and never having made a second one? Then this keystroke means
        // what it always meant: name this arrangement.
        if workspaces.count == 1, activeWorkspace?.name == defaultWorkspaceName {
            promptForName(title: String(localized: "New Workspace"),
                          prompt: String(localized: "Workspace name:"),
                          initial: "") { [weak self] name in
                guard let self, let index = self.activeWorkspaceIndex else { return }
                self.renameWorkspace(id: self.workspaces[index].id, to: name)
                self.updateWorkspaceBaseline()
            }
            return
        }
        updateWorkspaceBaseline()
    }

    /// `cm_NewWorkspace`.
    func showNewWorkspace() { newWorkspacePrompt() }

    /// `cm_RenameWorkspace`.
    func showRenameWorkspace() { renameWorkspacePrompt() }

    /// `cm_DeleteWorkspace`.
    func showDeleteWorkspace() { deleteWorkspacePrompt() }

    // MARK: - Menu actions

    @objc private func switchWorkspaceMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Task { @MainActor in await switchWorkspace(to: id) }
    }

    @objc func newWorkspacePrompt() {
        promptForName(title: String(localized: "New Workspace"),
                      prompt: String(localized: "Workspace name:"),
                      initial: "") { [weak self] name in
            self?.createWorkspace(named: name)
        }
    }

    @objc func renameWorkspacePrompt() {
        guard let active = activeWorkspace else { return }
        promptForName(title: String(localized: "Rename Workspace"),
                      prompt: String(localized: "Workspace name:"),
                      initial: active.name) { [weak self] name in
            self?.renameWorkspace(id: active.id, to: name)
        }
    }

    @objc private func resetWorkspaceMenu() { resetWorkspaceToBaseline() }

    @objc private func exportWorkspaceMenu() { exportWorkspaceCommand() }
    @objc private func importWorkspaceMenu() { importWorkspaceCommand() }

    @objc func deleteWorkspacePrompt() {
        guard let active = activeWorkspace else { return }
        confirmDeleteWorkspace(id: active.id)
    }

    /// The one dialog this feature is allowed, and the only place it is written.
    ///
    /// Deleting is destructive and cannot be undone, which is a different thing from the "save
    /// changes?" a switch must never ask — those are what the whole design exists to avoid. Both the
    /// chip's context menu and the Workspace menu come through here, because two copies of a
    /// confirmation drift and the drift is only ever noticed in the copy that stopped confirming.
    func confirmDeleteWorkspace(id: String) {
        guard workspaces.count > 1,
              let workspace = workspaces.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = String(format: String(localized: "Delete the workspace “%@”?"), workspace.name)
        alert.informativeText = String(localized:
            "Its tabs and its saved starting point are deleted. The folders and files it pointed at are not touched.")
        alert.addButton(withTitle: String(localized: "Delete"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.alertStyle = .warning

        // A scripted run answers from the environment (F-436), and with nothing configured it
        // **cancels**: a modal would hang the run, and the safe reading of an unanswered question
        // about deleting somebody's workspace is no. That is also what makes the ✕ testable — a
        // scenario can assert that clicking it asks, by finding the workspace still there.
        if AutomationProbe.isScriptedRun {
            guard AutomationProbe.value("PC_WORKSPACE_DELETE") == "yes" else {
                NSLog("[workspace] delete of %@ cancelled: scripted run without PC_WORKSPACE_DELETE", id)
                return
            }
        } else {
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        deleteWorkspace(id: id)
    }

    /// The name prompt, shared by the three places that need one.
    private func promptForName(title: String, prompt: String, initial: String,
                               onConfirm: @escaping (String) -> Void) {
        let dialog = InputDialog(title: title, prompt: prompt, initialValue: initial)
        dialog.onConfirm = { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            Task { @MainActor in onConfirm(trimmed) }
        }
        self.pathDialog = dialog
        dialog.runModalDialog()
    }
}
