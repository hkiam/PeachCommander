// SPDX-License-Identifier: Apache-2.0
// MainWindowController+Workspaces.swift - Living workspaces: switching, creating, migrating (F-499).
//
// The rule this file exists to keep:
//
//     A workspace is never saved, because it never ends.
//
// So there is no "save changes?" anywhere below. Switching writes the outgoing workspace down and
// restores the incoming one exactly as it was left. The only dialogs here are the ones in front of
// something destructive — deleting a workspace — which is a different thing entirely.
//
// ## The session is always in a workspace
//
// `workspaces` is never empty. Even for somebody who has never heard of this feature and never will,
// the session runs through a single workspace whose file *is* what `session.ini`'s panel blocks used
// to be. That is what makes "switched off" a property of the list (exactly one, no surface) rather
// than a second code path writing a different format — and a second format is precisely what produced
// the defect where a tab's cursor survived loading a saved layout but not restarting the app.
//
// ## Three interlocks, and each is there because of a specific way this goes wrong
//
//   1. **`isSwitchingWorkspace`** gates `scheduleSaveState`, so the storm of `onStateChanged` that
//      every `loadPath` fires while the panes are being rebuilt cannot write half-applied state.
//   2. **The workspace id is captured when the save timer is *armed*.** A timer set 0.29 s before a
//      switch fires 0.01 s after it, and without this would write the old workspace's panels into the
//      new one's file.
//   3. **`workspaceSwitchGeneration`** lets a slow switch discover that a newer one has taken over,
//      and stand down rather than finish and overwrite it.

import AppKit
import PCFoundation

extension MainWindowController {

    // MARK: - Startup

    /// Read the workspaces, migrating from `workspaces.ini` on the first run that needs it.
    ///
    /// Called once, after the panels exist and their tabs have been restored — the session as it
    /// stands is the raw material for the workspace the user is about to be standing in.
    func loadWorkspaces() {
        let sessionState = captureWorkspaceState()
        let now = Date()

        if let migrated = workspaceStore.migrateIfNeeded(
            sessionWorkspace: Workspace(id: WorkspaceID.slug(from: defaultWorkspaceName),
                                        name: defaultWorkspaceName,
                                        tint: 0, order: 0, created: now, lastUsed: now,
                                        baseline: sessionState, live: sessionState),
            now: now) {
            PCFoundationLogger.logger.info("workspaces: migrated \(migrated.count) from workspaces.ini")
        }

        let loaded = workspaceStore.load()
        for problem in loaded.problems { PCFoundationLogger.logger.error("workspaces: \(problem)") }
        workspaces = loaded.workspaces

        if workspaces.isEmpty {
            // No directory, no legacy file, nothing to migrate: a fresh installation. The session is
            // still a workspace — it just happens to be the only one, which is the latent state.
            let only = Workspace(id: WorkspaceID.slug(from: defaultWorkspaceName),
                                 name: defaultWorkspaceName, tint: 0, order: 0,
                                 created: now, lastUsed: now,
                                 baseline: sessionState, live: sessionState)
            workspaces = [only]
            workspaceStore.save(only)
        }

        let remembered = startupSession.string("Window", "Workspace", default: "")
        activeWorkspaceID = workspaces.contains { $0.id == remembered } ? remembered : workspaces[0].id

        // The panels were restored from `session.ini` a moment ago and are already showing this
        // workspace's folders, so nothing is applied here — applying would reload both panes for no
        // visible change and cost a second of startup.
        ViewContainerRegistry.shared.setWorkspace(activeWorkspaceID)
        refreshWorkspaceBar()
        // The menu bar was built before this ran, back when the workspace count was still unknown. It
        // only needs rebuilding when there is something to show — which is never for somebody who has
        // not made a second workspace, and that is the whole point of the latent state.
        if workspacesAreVisible { rebuildMainMenu() }
    }

    /// The name the first workspace gets. Localized, because it is shown on a chip.
    var defaultWorkspaceName: String { String(localized: "Workspace 1") }

    // MARK: - Reading the list

    var activeWorkspace: Workspace? {
        workspaces.first { $0.id == activeWorkspaceID }
    }

    var activeWorkspaceIndex: Int? {
        workspaces.firstIndex { $0.id == activeWorkspaceID }
    }

    /// Is the feature doing anything the user can see? One workspace is the latent state: switched on,
    /// costing nothing, showing nothing.
    var workspacesAreVisible: Bool {
        workspacesEnabled && workspaces.count >= 2
    }

    /// Nine is the limit, and it is about the chip strip rather than about storage: past that the
    /// chips stop being recognisable at a glance, which is the only reason to have them.
    static let maxWorkspaces = 9

    // MARK: - Persisting the active one

    /// Fold the live window into the active workspace and write it out.
    ///
    /// The silent autosave the whole feature rests on. Called on the way out of a workspace, on quit,
    /// and whenever the debounced session save runs.
    func persistActiveWorkspace(flush: Bool = false) {
        guard let index = activeWorkspaceIndex else { return }
        workspaces[index].live = captureWorkspaceState()
        workspaces[index].lastUsed = Date()
        let workspace = workspaces[index]
        let store = workspaceStore
        if flush {
            store.save(workspace)
        } else {
            // Off the main actor: this is a few kilobytes of JSON, but it is on the path of every
            // navigation and there is no reason for the window to wait for the disk.
            Task.detached(priority: .utility) { store.save(workspace) }
        }
    }

    // MARK: - Switching

    /// Switch to another workspace. Asks nothing, loses nothing, kills nothing.
    func switchWorkspace(to id: String) async {
        guard id != activeWorkspaceID,
              workspaces.contains(where: { $0.id == id }),
              !isSwitchingWorkspace else { return }

        // --- synchronous prologue: nothing may suspend before all of this has run ---
        workspaceSwitchGeneration &+= 1
        let generation = workspaceSwitchGeneration
        isSwitchingWorkspace = true

        let outgoingID = activeWorkspaceID
        persistActiveWorkspace()
        parkedUndoStacks[outgoingID] = undoStack
        undoStack = parkedUndoStacks[id] ?? []

        activeWorkspaceID = id
        // The plugins first, and before the panes move: the terminal parks its tabs while its own
        // working directory is still the outgoing workspace's, and the chat rebinds its transcript
        // before the new folder is pushed at it (F-499).
        ViewContainerRegistry.shared.setWorkspace(id)
        refreshWorkspaceBar()
        updateWorkspaceMenuChecks()
        refreshWindowTitle()
        Task { await session.setString(id, "Window", "Workspace") }

        // --- async epilogue ---
        // A restore is not a visit: without this the global history fills up with every folder every
        // switch passes through, which is the same reason session restore turns it off (F-402).
        HistoryService.shared.beginSessionRestore()
        defer {
            HistoryService.shared.endSessionRestore()
            isSwitchingWorkspace = false
        }

        guard let state = workspaces.first(where: { $0.id == id })?.live else { return }
        // The window's arrangement first, and synchronously: the panes are about to be filled, and
        // filling them into the previous workspace's layout means laying them out twice — once
        // visibly wrong.
        applyChrome(state.chrome)
        await applyPane(state.left, to: leftPanelController, generation: generation)
        guard generation == workspaceSwitchGeneration else { return }
        await applyPane(state.right, to: rightPanelController, generation: generation)
        guard generation == workspaceSwitchGeneration else { return }

        if state.activeSide == .right { activateRightPanel() } else { activateLeftPanel() }
        updateCommandLinePrompt()
        #if DEBUG
        verifyNoGhostState(applied: state)
        #endif
    }

    func switchWorkspace(toIndex index: Int) {
        guard workspaces.indices.contains(index) else { return }
        let id = workspaces[index].id
        Task { @MainActor in await switchWorkspace(to: id) }
    }

    func nextWorkspace() {
        guard let i = activeWorkspaceIndex, workspaces.count > 1 else { return }
        switchWorkspace(toIndex: (i + 1) % workspaces.count)
    }

    func previousWorkspace() {
        guard let i = activeWorkspaceIndex, workspaces.count > 1 else { return }
        switchWorkspace(toIndex: (i - 1 + workspaces.count) % workspaces.count)
    }

    // MARK: - Creating, renaming, deleting

    /// Make a new workspace from the window as it stands, and switch to it.
    ///
    /// A copy of the current arrangement rather than an empty one, because "new workspace" to somebody
    /// who has just set their panels up means "another one like this, to take somewhere else" — and an
    /// empty workspace would have to invent two folders to point at.
    @discardableResult
    func createWorkspace(named name: String) -> Workspace? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, workspaces.count < Self.maxWorkspaces else { return nil }

        persistActiveWorkspace()
        let state = captureWorkspaceState()
        let id = WorkspaceID.unique(from: trimmed, taken: Set(workspaces.map(\.id)))
        let workspace = Workspace(id: id, name: trimmed,
                                  tint: nextFreeTint(),
                                  order: (workspaces.map(\.order).max() ?? -1) + 1,
                                  created: Date(), lastUsed: Date(),
                                  baseline: state, live: state)
        workspaces.append(workspace)
        workspaceStore.save(workspace)
        activeWorkspaceID = id
        // Creating one is a switch into it, so the plugins have to hear about it here too. Missing
        // this was invisible in the panels — they are a copy of what was on screen anyway — and showed
        // up only as the terminal keeping the previous workspace's tabs (F-499).
        ViewContainerRegistry.shared.setWorkspace(id)
        Task { await session.setString(id, "Window", "Workspace") }
        refreshWorkspaceBar()
        rebuildMainMenu()
        refreshWindowTitle()
        return workspace
    }

    /// The colour least recently used, so a new chip does not arrive wearing its neighbour's.
    func nextFreeTint() -> Int {
        let used = Set(workspaces.map(\.tint))
        for tint in 0..<WorkspaceMigration.tintCount where !used.contains(tint) { return tint }
        return workspaces.count % WorkspaceMigration.tintCount
    }

    func renameWorkspace(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        // The id does not follow the name: it is the file's name, the command's name and what a
        // `.pcworkspace` somebody already has refers to.
        workspaces[index].name = trimmed
        workspaceStore.save(workspaces[index])
        refreshWorkspaceBar()
        rebuildMainMenu()
        refreshWindowTitle()
    }

    func setWorkspaceTint(id: String, tint: Int) {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].tint = ((tint % WorkspaceMigration.tintCount) + WorkspaceMigration.tintCount)
            % WorkspaceMigration.tintCount
        workspaceStore.save(workspaces[index])
        refreshWorkspaceBar()
    }

    /// Delete a workspace. Refuses the last one — there is always somewhere to be.
    func deleteWorkspace(id: String) {
        guard workspaces.count > 1, let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = id == activeWorkspaceID
        workspaces.remove(at: index)
        workspaceStore.delete(id: id)
        parkedUndoStacks[id] = nil

        if wasActive {
            // Move to the neighbour first: leaving the window pointing at a workspace that no longer
            // exists means the next save writes a file that was just deleted.
            let neighbour = workspaces[min(index, workspaces.count - 1)]
            activeWorkspaceID = neighbour.id
            ViewContainerRegistry.shared.setWorkspace(neighbour.id)
            Task { @MainActor in await switchWorkspace(to: neighbour.id) }
        }
        refreshWorkspaceBar()
        rebuildMainMenu()
    }

    func moveWorkspace(from source: Int, to destination: Int) {
        guard workspaces.indices.contains(source), workspaces.indices.contains(destination),
              source != destination else { return }
        let moved = workspaces.remove(at: source)
        workspaces.insert(moved, at: destination)
        for (i, _) in workspaces.enumerated() { workspaces[i].order = i }
        workspaceStore.saveAll(workspaces)
        refreshWorkspaceBar()
        rebuildMainMenu()
    }

    // MARK: - The baseline

    /// Make the window as it stands the state this workspace resets to.
    func updateWorkspaceBaseline() {
        guard let index = activeWorkspaceIndex else { return }
        let state = captureWorkspaceState()
        workspaces[index].baseline = state
        workspaces[index].live = state
        workspaceStore.save(workspaces[index])
    }

    /// Put the workspace back the way it was set up.
    func resetWorkspaceToBaseline() {
        guard let index = activeWorkspaceIndex else { return }
        let baseline = workspaces[index].baseline
        workspaces[index].live = baseline
        workspaceStore.save(workspaces[index])

        workspaceSwitchGeneration &+= 1
        let generation = workspaceSwitchGeneration
        isSwitchingWorkspace = true
        Task { @MainActor in
            HistoryService.shared.beginSessionRestore()
            defer {
                HistoryService.shared.endSessionRestore()
                self.isSwitchingWorkspace = false
            }
            self.applyChrome(baseline.chrome)
            await self.applyPane(baseline.left, to: self.leftPanelController, generation: generation)
            guard generation == self.workspaceSwitchGeneration else { return }
            await self.applyPane(baseline.right, to: self.rightPanelController, generation: generation)
            guard generation == self.workspaceSwitchGeneration else { return }
            if baseline.activeSide == .right { self.activateRightPanel() } else { self.activateLeftPanel() }
            self.updateCommandLinePrompt()
        }
    }
}

// MARK: - The chip strip

extension MainWindowController {

    /// What the menu bar should show. Empty while the feature is latent or off, and an empty list is
    /// what makes `AppMenu` leave the Workspace menu out entirely.
    var workspaceMenuEntries: [AppMenu.WorkspaceMenuEntry] {
        guard workspacesAreVisible else { return [] }
        return workspaces.map {
            AppMenu.WorkspaceMenuEntry(name: $0.name, active: $0.id == activeWorkspaceID)
        }
    }

    /// Tick the right row in the Workspace menu after a switch.
    ///
    /// Cheaper than rebuilding: `rebuildMainMenu()` re-reads the `.mnu`, re-runs the plugin
    /// contribution injector and re-applies the keymap, which is a lot of work to move one checkmark —
    /// and it happens on every switch, which is the one thing that has to stay instant.
    func updateWorkspaceMenuChecks() {
        guard let menu = NSApp.mainMenu?.items.compactMap(\.submenu)
            .first(where: { $0.title == String(localized: "Workspace") }) else { return }
        for (i, _) in workspaces.prefix(9).enumerated() {
            guard menu.items.indices.contains(i) else { break }
            menu.items[i].state = workspaces[i].id == activeWorkspaceID ? .on : .off
        }
    }

    /// Hand the strip what it should draw, and decide whether it is there at all.
    func refreshWorkspaceBar() {
        workspaceBar.setChips(workspaces.map {
            WorkspaceBarView.Chip(id: $0.id, name: $0.name, tint: $0.tint,
                                  current: $0.id == activeWorkspaceID,
                                  stashCount: $0.stash.count)
        })
        applyWorkspaceBarHeight()
    }

    /// **The one place the strip's height is decided**, and it weighs all three conditions together.
    ///
    /// Split across three call sites they would drift, and the drift would be visible: a user who
    /// switched the feature off seeing a strip after deleting their second workspace, or the reverse.
    /// Zero height rather than `isHidden` alone, so the row occupies nothing and the button bar sits
    /// exactly where it did before this feature existed.
    func applyWorkspaceBarHeight() {
        let show = workspacesEnabled && workspaceBarVisible && workspaces.count >= 2
        workspaceBar.isHidden = !show
        workspaceBarHeightConstraint?.constant = show ? WorkspaceBarView.barHeight : 0
    }

    /// Ansicht ▸ Show Workspace Bar — hides the *display* for somebody who switches with ⌃1…⌃9. A
    /// different thing from the feature switch in Settings, which takes the whole feature away.
    func toggleWorkspaceBar() {
        workspaceBarVisible.toggle()
        applyWorkspaceBarHeight()
        let value = workspaceBarVisible
        Task { await mainConfig.setBool(value, "Layout", "WorkspaceBar"); await mainConfig.flush() }
    }

    /// Wire the strip's callbacks. Called once, from `start()`.
    func connectWorkspaceBar() {
        workspaceBar.onSelect = { [weak self] index in
            guard let self, self.workspaces.indices.contains(index) else { return }
            let id = self.workspaces[index].id
            Task { @MainActor in await self.switchWorkspace(to: id) }
        }
        workspaceBar.onNewWorkspace = { [weak self] in self?.runCommandNamed("cm_NewWorkspace") }
        workspaceBar.onReorder = { [weak self] from, to in self?.moveWorkspace(from: from, to: to) }
        workspaceBar.onContextMenu = { [weak self] index, event in
            self?.showWorkspaceChipMenu(index: index, event: event)
        }
        workspaceBar.onDropFiles = { [weak self] index, paths, intent in
            self?.handleChipDrop(index: index, paths: paths, intent: intent)
        }
        // Straight into the same confirmation the context menu and the Workspace menu use. Deleting
        // is destructive and takes the stash and the journal with it, so the ✕ saves the trip through
        // the context menu and nothing else — one dialog, written in one place, or the copies drift
        // and it is always the copy that stopped asking that nobody notices.
        workspaceBar.onCloseWorkspace = { [weak self] id in
            self?.confirmDeleteWorkspace(id: id)
        }
    }

    /// Right-click on a chip, or on the strip's free space.
    private func showWorkspaceChipMenu(index: Int?, event: NSEvent) {
        let menu = NSMenu()
        if let index, workspaces.indices.contains(index) {
            let workspace = workspaces[index]
            let switchItem = NSMenuItem(title: String(localized: "Switch to This Workspace"),
                                        action: #selector(chipSwitch(_:)), keyEquivalent: "")
            switchItem.representedObject = workspace.id
            switchItem.target = self
            switchItem.isEnabled = workspace.id != activeWorkspaceID
            menu.addItem(switchItem)

            let rename = NSMenuItem(title: String(localized: "Rename…"),
                                    action: #selector(chipRename(_:)), keyEquivalent: "")
            rename.representedObject = workspace.id
            rename.target = self
            menu.addItem(rename)

            let colour = NSMenuItem(title: String(localized: "Color"), action: nil, keyEquivalent: "")
            let colourMenu = NSMenu()
            for tint in 0..<WorkspaceTint.count {
                let item = NSMenuItem(title: WorkspaceTint.name(tint),
                                      action: #selector(chipTint(_:)), keyEquivalent: "")
                item.representedObject = ["id": workspace.id, "tint": tint] as [String: Any]
                item.target = self
                item.state = workspace.tint == tint ? .on : .off
                colourMenu.addItem(item)
            }
            colour.submenu = colourMenu
            menu.addItem(colour)

            let scope = NSMenuItem(title: String(localized: "Limit to Folder"), action: nil, keyEquivalent: "")
            let scopeMenu = NSMenu()
            let setHere = NSMenuItem(title: String(localized: "Set to the Active Folder"),
                                     action: #selector(chipScopeHere(_:)), keyEquivalent: "")
            setHere.representedObject = workspace.id
            setHere.target = self
            scopeMenu.addItem(setHere)
            if workspace.scope.isSet {
                for enforcement in ScopeEnforcement.allCases {
                    let item = NSMenuItem(title: Self.scopeTitle(enforcement),
                                          action: #selector(chipScopeMode(_:)), keyEquivalent: "")
                    item.representedObject = ["id": workspace.id, "mode": enforcement.rawValue]
                    item.target = self
                    item.state = workspace.scope.enforcement == enforcement ? .on : .off
                    scopeMenu.addItem(item)
                }
                scopeMenu.addItem(.separator())
                let clear = NSMenuItem(title: String(localized: "No Limit"),
                                       action: #selector(chipScopeClear(_:)), keyEquivalent: "")
                clear.representedObject = workspace.id
                clear.target = self
                scopeMenu.addItem(clear)
            }
            scope.submenu = scopeMenu
            menu.addItem(scope)

            menu.addItem(.separator())
            if workspaces.count > 1 {
                let delete = NSMenuItem(title: String(localized: "Delete…"),
                                        action: #selector(chipDelete(_:)), keyEquivalent: "")
                delete.representedObject = workspace.id
                delete.target = self
                menu.addItem(delete)
            }
        } else {
            let new = NSMenuItem(title: String(localized: "New Workspace…"),
                                 action: #selector(chipNew), keyEquivalent: "")
            new.target = self
            new.isEnabled = workspaces.count < Self.maxWorkspaces
            menu.addItem(new)
            menu.addItem(.separator())
            let hide = NSMenuItem(title: String(localized: "Hide Workspace Bar"),
                                  action: #selector(chipHideBar), keyEquivalent: "")
            hide.target = self
            menu.addItem(hide)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: workspaceBar)
    }

    @objc private func chipSwitch(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Task { @MainActor in await switchWorkspace(to: id) }
    }

    @objc private func chipRename(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let workspace = workspaces.first(where: { $0.id == id }) else { return }
        let dialog = InputDialog(title: String(localized: "Rename Workspace"),
                                 prompt: String(localized: "Workspace name:"),
                                 initialValue: workspace.name)
        dialog.onConfirm = { [weak self] name in
            Task { @MainActor in self?.renameWorkspace(id: id, to: name) }
        }
        pathDialog = dialog
        dialog.runModalDialog()
    }

    @objc private func chipTint(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let id = info["id"] as? String, let tint = info["tint"] as? Int else { return }
        setWorkspaceTint(id: id, tint: tint)
    }

    @objc private func chipDelete(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        confirmDeleteWorkspace(id: id)
    }

    /// What each enforcement level is called where somebody chooses it.
    static func scopeTitle(_ enforcement: ScopeEnforcement) -> String {
        switch enforcement {
        case .allow: return String(localized: "Allow Operations Outside")
        case .ask: return String(localized: "Ask About Operations Outside")
        case .refuse: return String(localized: "Refuse Operations Outside")
        }
    }

    @objc private func chipScopeHere(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        Task { @MainActor in
            guard let folder = await activePanel?.getCurrentPath(), !folder.isEmpty else { return }
            // The default for a scope somebody has just set is to *ask*, not to refuse: the first
            // thing they do afterwards is almost always something they meant to do.
            let previous = workspaces[index].scope.enforcement
            workspaces[index].scope = WorkspaceScope(
                root: folder,
                enforcement: workspaces[index].scope.isSet ? previous : .ask)
            workspaceStore.save(workspaces[index])
            refreshWorkspaceBar()
        }
    }

    @objc private func chipScopeMode(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let id = info["id"], let raw = info["mode"],
              let mode = ScopeEnforcement(rawValue: raw),
              let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].scope.enforcement = mode
        workspaceStore.save(workspaces[index])
    }

    @objc private func chipScopeClear(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].scope = WorkspaceScope()
        workspaceStore.save(workspaces[index])
        refreshWorkspaceBar()
    }

    @objc private func chipNew() { runCommandNamed("cm_NewWorkspace") }
    @objc private func chipHideBar() { toggleWorkspaceBar() }
}
