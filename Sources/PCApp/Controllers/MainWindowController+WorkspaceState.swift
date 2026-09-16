// SPDX-License-Identifier: Apache-2.0
// MainWindowController+WorkspaceState.swift - Reading the window into a workspace, and back (F-499).
//
// Two functions carry the whole feature: `captureWorkspaceState()` reads the live window into a value,
// and `applyPane(_:to:generation:)` puts one back. Everything else — the chip strip, the menu, the
// manager window — is arrangement around these.
//
// **Capture is synchronous, and that is a requirement rather than a convenience.** Between the click
// on a chip and the outgoing state being safely in memory there must be no suspension point, because
// anything that runs at such a point can still change the panels — and would then be captured into
// the workspace the user has already left, or worse, missed entirely. Everything read below is
// available on the main actor without an `await`; keep it that way. If a future field needs an actor
// hop to read, the answer is to mirror it on the main thread (as `PanelListView` already does for the
// selection), not to make this function `async`.
//
// **Apply is asynchronous and cannot be trusted to finish.** Loading a directory can take as long as
// a network share feels like taking, and the user may switch again while it does. Hence the
// generation counter: an older switch that comes back to find the world has moved on stands down
// rather than finishing and overwriting a newer workspace's panels with its own.
//
// The asymmetry between the two is the source of the one defect class this design is exposed to — a
// field that capture reads and apply forgets. No compiler can see that, which is why
// `verifyNoGhostState` exists below and why it runs against the real window rather than a model.

import AppKit
import PCFoundation

extension MainWindowController {

    // MARK: - Reading the window

    /// The live window as a value. **Synchronous on purpose** — see the note at the top.
    ///
    /// This is the single caller of `WorkspaceState`'s initializer, which is why that initializer has
    /// no default values: adding a field to the state breaks the build *here*, at one line, with the
    /// fix being "read it off the panel". The compile error is the feature.
    func captureWorkspaceState() -> WorkspaceState {
        WorkspaceState(chrome: captureChrome(),
                       left: capturePane(leftPanelController),
                       right: capturePane(rightPanelController),
                       activeSide: activePanel === rightPanelController ? .right : .left)
    }

    /// The window's arrangement, read off the views.
    ///
    /// The divider is the one value that is measured rather than stored: `splitView` is the authority
    /// on where it actually is, and a remembered number goes stale the moment the window is resized.
    private func captureChrome() -> WindowChromeState {
        WindowChromeState(
            horizontalPanels: panelsAreHorizontal,
            splitterLeftWidth: Double(leftPanelController?.view.frame.width ?? 0),
            previewVisible: previewPanelIsVisible,
            previewWidth: Double(preferredPreviewWidth),
            sharedTreeVisible: sharedTreeVisible,
            dockVisible: dockIsVisible,
            dockHeight: Double(preferredDockHeight),
            dockPanel: rememberedDockPanel,
            commandLineVisible: commandLineVisible,
            functionBarVisible: functionBarVisible,
            buttonBarVisible: buttonBarIsVisible,
            buttonBarVertical: buttonBarIsVertical,
            driveBarVisible: driveBarVisible,
            statusBarVisible: statusBarVisible,
            tabBarVisible: tabBarVisible,
            pathBarVisible: pathBarVisible)
    }

    /// The arrangement as the old `[Layout]` keys describe it.
    ///
    /// The bridge for a configuration that predates workspaces, and the fallback on a first run. Kept
    /// for one release: once every installation has a `workspaces/` directory these keys are read by
    /// nothing, and the block in `applyVisualStateBeforeFirstPaint` that writes them can go.
    static func legacyChrome(from config: ConfigSnapshot, session: ConfigSnapshot) -> WindowChromeState {
        let dockPanel = config.string("Layout", "DockPanel", default: "")
        return WindowChromeState(
            horizontalPanels: config.bool("Layout", "HorizontalPanels", default: false),
            splitterLeftWidth: session.double("Window", "LeftWidth", default: 0),
            previewVisible: config.bool("Layout", "PreviewPanel", default: false),
            previewWidth: Double(config.int("Layout", "PreviewWidth",
                                            default: Int(WindowChromeState.standard.previewWidth))),
            sharedTreeVisible: config.bool("Layout", "SharedTree", default: false),
            dockVisible: config.bool("Layout", "DockVisible", default: false),
            dockHeight: Double(config.int("Layout", "DockHeight",
                                          default: Int(WindowChromeState.standard.dockHeight))),
            dockPanel: dockPanel.isEmpty ? nil : dockPanel,
            commandLineVisible: config.bool("Layout", "CommandLine", default: true),
            functionBarVisible: config.bool("Layout", "FunctionKeys", default: true),
            buttonBarVisible: config.bool("Layout", "ButtonBar", default: true),
            buttonBarVertical: config.bool("Layout", "ButtonBarVertical", default: false),
            driveBarVisible: config.bool("Layout", "DriveBar", default: true),
            statusBarVisible: config.bool("Layout", "StatusBar", default: true),
            tabBarVisible: config.bool("Layout", "TabBar", default: true),
            pathBarVisible: config.bool("Layout", "PathBar", default: true))
    }

    /// The arrangement to paint the first frame with.
    ///
    /// Read synchronously from the workspace the session was left in, because the alternative is
    /// visible: paint the old global layout, then swap to the workspace's a moment later, and every
    /// launch starts with the window rearranging itself. One small JSON file, and the same trade
    /// `ConfigSnapshot` already makes and defends for the config itself.
    func startupChrome() -> WindowChromeState {
        let remembered = startupSession.string("Window", "Workspace", default: "")
        if !remembered.isEmpty,
           let data = try? Data(contentsOf: workspaceStore.url(remembered)),
           let workspace = try? WorkspaceStore.decoder.decode(Workspace.self, from: data),
           workspace.formatVersion <= Workspace.currentFormatVersion {
            return workspace.live.chrome
        }
        return Self.legacyChrome(from: startupConfig, session: startupSession)
    }

    /// Put an arrangement back on the window.
    ///
    /// **Every call here is an absolute setter, and none of them may become a toggle.** Applying a
    /// toggle twice undoes it, which is why the startup path used to carry a note that a second pass
    /// would be safe for everything in it except `togglePreviewPanel`. A workspace switch *is* a
    /// second pass, and a third, and a fortieth.
    ///
    /// Nothing here persists to `peachcmd.ini`: the values belong to the workspace now, and writing
    /// them back would make the last workspace visited the global default.
    func applyChrome(_ chrome: WindowChromeState) {
        setPanelArrangement(horizontal: chrome.horizontalPanels, persist: false)
        setButtonBarVisible(chrome.buttonBarVisible, persist: false)
        setButtonBarVertical(chrome.buttonBarVertical)
        setCommandLineVisible(chrome.commandLineVisible)
        setFunctionBarVisible(chrome.functionBarVisible)
        setDriveBarVisible(chrome.driveBarVisible)
        setStatusBarVisible(chrome.statusBarVisible)
        setTabBarVisible(chrome.tabBarVisible)
        setPathBarVisible(chrome.pathBarVisible)
        setSharedTreeVisible(chrome.sharedTreeVisible, persist: false)

        preferredPreviewWidth = max(PreviewResizeHandle.minWidth, CGFloat(chrome.previewWidth))
        setPreviewPanelVisible(chrome.previewVisible, persist: false)

        preferredDockHeight = max(BottomDockView.minHeight, CGFloat(chrome.dockHeight))
        rememberedDockPanel = chrome.dockPanel
        if let panel = chrome.dockPanel { bottomDock.selectProvider(id: panel) }
        setBottomDockVisible(chrome.dockVisible, persist: false)

        // Last, and after a layout pass: the divider is measured in points against a split view whose
        // width depends on everything set above it. Moving it before the bars have settled puts it
        // where it would have gone in the *previous* arrangement.
        if chrome.splitterLeftWidth > 50 {
            window?.contentView?.layoutSubtreeIfNeeded()
            panelSplitView.setPosition(CGFloat(chrome.splitterLeftWidth), ofDividerAt: 0)
        }
    }

    private func capturePane(_ panel: PanelController?) -> PaneState {
        guard let panel else {
            return PaneState(tabs: [], activeIndex: 0, viewMode: PanelViewMode.details.rawValue,
                             treeVisible: false, history: [], historyIndex: 0)
        }
        // `exportTabs` folds the live cursor into the active tab first, so the cursor is part of what
        // is written down without this function having to know about it.
        var (tabs, activeIndex) = panel.exportTabs()
        // Marks and the filter belong to the *active* tab, and only it can have them: loading a
        // directory intersects the marked set with what is in it, so switching tabs already discards
        // the previous tab's marks. Writing them for every tab would promise a fidelity the panel does
        // not have (F-499).
        if tabs.indices.contains(activeIndex) {
            let marked = panel.tableView.markedNames()
            tabs[activeIndex].marked = marked.isEmpty ? nil : marked
            tabs[activeIndex].filterText = panel.tableView.quickFilterText
        }
        let history = panel.navigationHistory
        return PaneState(tabs: tabs,
                         activeIndex: activeIndex,
                         viewMode: panel.viewMode.rawValue,
                         treeVisible: panel.treeVisible,
                         history: history.entries,
                         historyIndex: history.index)
    }

    // MARK: - Putting one back

    /// Restore one pane. Returns false when the switch should be abandoned.
    ///
    /// Order matters twice here and both are easy to get wrong:
    ///
    ///   * The view mode and the tree go on **before** the tabs, so the directory lands in the
    ///     arrangement it is meant to be seen in and the panel is not laid out twice.
    ///   * The history goes on **after** `importTabs`, because loading the tab pushes an entry of its
    ///     own. Restoring first and loading second would leave the panel one step from where the
    ///     workspace was left, with Alt+Left going somewhere it has never been.
    @discardableResult
    func applyPane(_ pane: PaneState, to panel: PanelController?, generation: UInt64) async -> Bool {
        guard let panel, !pane.tabs.isEmpty else { return false }

        if let mode = PanelViewMode(rawValue: pane.viewMode), panel.viewMode != mode {
            panel.setViewMode(mode)
        }
        if panel.treeVisible != pane.treeVisible { panel.setTreeVisible(pane.treeVisible) }

        let index = min(max(pane.activeIndex, 0), pane.tabs.count - 1)
        guard await panel.importTabs(pane.tabs, activeIndex: index) else { return false }
        // A newer switch owns the panels now. Stopping here leaves them showing the newer workspace,
        // which is what the user asked for most recently.
        guard generation == workspaceSwitchGeneration else { return false }

        if !pane.history.isEmpty {
            panel.restoreHistory(entries: pane.history, index: pane.historyIndex)
        }

        // **After the directory is loaded, never before.** `SelectionState.setEntries` intersects the
        // marked set with the new listing, so marks applied first would be wiped by the load that was
        // supposed to bring them back — and the symptom is a workspace that silently forgets the
        // selection, which looks like the marks were never stored at all.
        let tab = pane.tabs[index]
        panel.tableView.setQuickFilter(tab.filterText)
        await panel.tableView.restoreMarks(names: tab.marked ?? [])
        // The filter changes which rows exist, so the cursor goes last of all.
        if let cursor = tab.cursorName { panel.tableView.focusEntry(named: cursor) }
        return true
    }

    // MARK: - Ghost state

    #if DEBUG
    /// Compare what was applied with what is actually there a moment later.
    ///
    /// The net for the mistake the compiler cannot catch. A field that `capture` reads and `apply`
    /// ignores survives a switch with the *outgoing* workspace's value still on screen — the marks
    /// from "clean up backups" showing up in "sort applicants" — and nothing else in the system would
    /// say a word about it.
    ///
    /// DEBUG only, and the count rather than an assertion: a hard stop here would turn a cosmetic
    /// drift into a crash in somebody's debug build, and the number is what the VM scenario asserts on
    /// anyway. `NSLog`, not `logger`, because the harness reads stdout.
    func verifyNoGhostState(applied: WorkspaceState) {
        let drift = WorkspaceState.diff(applied, captureWorkspaceState())
        workspaceGhostFields = drift
        guard !drift.isEmpty else { return }
        NSLog("[workspace] ghost state after switch: \(drift.joined(separator: ", "))")
    }
    #endif
}
