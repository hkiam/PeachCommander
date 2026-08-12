// SPDX-License-Identifier: Apache-2.0
// MainWindowController.swift - Main window controller for Peach Commander
//
// Dual-pane layout (NSSplitView), path bars, per-panel status bars, and the
// main menu wired through the command registry.

import AppKit
import UniformTypeIdentifiers
import QuickLookThumbnailing
import Quartz
import PCFoundation
import PCVFS
import PCCommands
import PCArchive
import PCPluginHost
import PCNet
import PCAutomation
import PCOperations

/// Main window controller for Peach Commander
final class MainWindowController: NSWindowController, WindowControllerProtocol, NSWindowDelegate, NSSplitViewDelegate {
    private let logger = PCFoundationLogger.logger

    private let splitView = PanelSplitView()
    /// One tree for both panels, to the left of them (F-015). Separate from the per-panel tree column:
    /// Total Commander offers either, and they answer different questions — "where am I in this panel"
    /// versus "one place to steer both panels from".
    private let sharedTree = PanelTreeView()
    private var sharedTreeWidthConstraint: NSLayoutConstraint?
    #if DEBUG
    /// Diagnostic: push the divider right so a wide column fits in a screenshot (F-372).
    func automationWidenLeftPanel() {
        splitView.setPosition(splitView.bounds.width - 40, ofDividerAt: 0)
    }
    #endif
    private let previewPanel = PreviewPanelView()
    #if DEBUG
    /// Diagnostic: the preview panel, i.e. the host's "sidebar" plugin view container (F-372).
    func previewPanelForAutomation() -> PreviewPanelView? { previewPanel }
    /// The embedded Quick View's preview area, when it is up (F-118/F-389).
    func quickViewForAutomation() -> FilePreviewView? { quickViewPreview }
    #endif
    private let previewHandle = PreviewToggleHandle()
    private let previewResizer = PreviewResizeHandle()
    private var previewWidthConstraint: NSLayoutConstraint?
    private var previewResizerWidthConstraint: NSLayoutConstraint?
    private var previewTimer: Timer?
    private static let previewWidth: CGFloat = 300
    /// Plugin views docked across the bottom of the window (F-381), between the panels and the
    /// command line. Width is what a terminal or a build log needs, and the window is widest here.
    private let bottomDock = BottomDockView()
    private let dockResizer = DockResizeHandle()
    private var dockHeightConstraint: NSLayoutConstraint?
    private var dockResizerHeightConstraint: NSLayoutConstraint?
    /// The height to restore when the dock is opened again, kept across a close.
    private var preferredDockHeight: CGFloat = BottomDockView.defaultHeight
    #if DEBUG
    /// Diagnostic: the bottom dock, i.e. the host's "bottom" plugin view container (F-381).
    func bottomDockForAutomation() -> BottomDockView? { bottomDock }
    /// Diagnostic: the two frames the dock was inserted between, so a scenario can check the stack
    /// rather than a visibility flag. Both are private and live in another file from the automation
    /// extension, which is the only reason these exist.
    func splitViewFrameForAutomation() -> NSRect { splitView.frame }
    func commandLineFrameForAutomation() -> NSRect { commandLine.frame }
    #endif
    /// Docked AI assistant panel (right column, left of the preview panel).
    /// Minimum width, in points, that each panel may be shrunk to by dragging.
    private let minPaneWidth: CGFloat = 200
    /// Panels stacked above/below (horizontal arrangement) instead of side by side (F-002).
    private var horizontalPanels = false
    private let rootContentVC = ContentViewController()
    /// The live controller, for the AppleScript layer (F-296). Single-window app.
    static weak var shared: MainWindowController?

    private(set) var leftPanelController: PanelController?
    private(set) var rightPanelController: PanelController?

    private let commandRegistry = CommandRegistry()

    private(set) var activePanel: PanelController? {
        didSet { updateActivePanelAppearance() }
    }

    private let volumeManager = VolumeManager()

    /// The drive-bar volume whose click is currently being carried out, set only for the duration
    /// of a plugin's `connect`. It exists because the mount arrives through `fsMount`, which the
    /// plugin calls and which is told nothing about the volume the user picked — while the panel
    /// needs exactly that to keep the chip selected and to name the drive it is showing.
    private var pendingDriveVolume: Volume?

    /// The panel that mount is going into, when it is not simply the active one — a tab being
    /// restored belongs to its own panel, and at startup both panels restore, so mounting into
    /// whichever is active at the time would put one panel's drive into the other.
    private weak var pendingMountPanel: PanelController?

    /// Configuration + session persistence (I05).
    let mainConfig: ConfigStore

    /// The unified host event bus (panel/selection/cursor/config events). The
    /// Automation Core exposes it to the AI agent, MCP server and Python plugin.
    let hostEventBus = HostEventBus()
    /// The Automation Core wired to this window (built lazily on first use, e.g. by
    /// the AI agent plugin or the MCP server). Reads/navigation/commands run under a
    /// PermissionPolicy; writes/deletes/config are gated (plan-then-confirm).
    lazy var automationCore: DefaultAutomationCore = makeAutomationCore()

    /// Build the core, merging automation tools contributed by loaded plugins (KI-06).
    private func makeAutomationCore() -> DefaultAutomationCore {
        let externalTools = ContributionRegistry.shared.toolDefinitions()
        let router: DefaultAutomationCore.ExternalToolRouter = { [weak self] name, args in
            guard let self else { return nil }
            let json = args.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            guard let text = await ContributionRegistry.shared.invokeTool(name, argumentsJson: json, host: self) else {
                return .failed(error: "Plugin tool '\(name)' returned nothing.")
            }
            return .ok(payload: try? JSONSerialization.data(withJSONObject: ["result": text]))
        }
        return DefaultAutomationCore(bridge: HostAutomationBridge(host: self), bus: hostEventBus,
                                     externalTools: externalTools, externalRouter: router)
    }
    /// The optional MCP server exposing the Automation Core to external agents
    /// (off by default; enabled via the Automation.MCPServerEnabled config key).
    private var mcpServer: MCPSocketServer?
    // AI cloud endpoint, cached from config so the AI plugin can read it synchronously
    // via getContext (keys never carry the API key — that stays in the environment).
    private var cachedCloudBase = ""
    private var cachedCloudModel = "local"
    let session: ConfigStore
    private let hotlistStore: ConfigStore
    private var hotlist = Hotlist()
    private let configPaths: ConfigPaths
    /// Selected colour theme id ("system" = follow the appearance, the default and the
    /// behaviour that predates themes). Persisted as [Colors] Theme.
    private var themeId: String = "system"
    private var hiddenFilesShown = false
    private var saveScheduled = false
    private var didRestore = false
    var settingsWindow: SettingsWindowController?
    /// Current plugin-contributed settings panes (container "settings"), kept fresh
    /// by ViewContainerRegistry.refresh so `showSettings()` can hand them over.
    private var settingsPaneProviders: [PreviewViewProvider] = []
    private var displaySizeStyle = "kb"
    private var displayTypeColors = ""
    private var displayBrackets = false
    private var displayNaturalSort = true   // F-026
    private var displayAlternatingRows = false   // F-032
    private var displayFontSize = 13   // F-272
    private var displayDateFormat = PanelDateFormatter.defaultPattern
    // Copy/Delete defaults (Options page F-271), mirrored to both panels.
    private var copySpeedLimitKBps = 0
    private var copyPreserveMetadata = true
    private var copyUseClone = true
    private var copyOnlyNewer = false
    // Zip/Packer defaults (Options page F-274), mirrored to both panels.
    private var packDefaultFormat = "zip"
    private var packLevel = 5
    // Tabs behavior (Options page), mirrored to both panels.
    private var tabOpenInForeground = true
    private var tabLockedOpensNewTab = true
    // FTP default keep-alive interval in seconds (Options page; 0 = off). Read by
    // connectToSite; per-site keepalive overrides it.
    private var ftpKeepAliveSeconds = 0
    private let commandLine = CommandLineView()
    private let buttonBarView = ButtonBarView()
    private var buttonBarHeightConstraint: NSLayoutConstraint?   // active when horizontal
    private var buttonBarWidthConstraint: NSLayoutConstraint?    // active when vertical (F-011)
    private var buttonBarGroupH: [NSLayoutConstraint] = []       // top-strip layout
    private var buttonBarGroupV: [NSLayoutConstraint] = []       // left-column layout
    private var buttonBarVertical = false
    private var buttonBarVisible = true
    private var commandLineHeightConstraint: NSLayoutConstraint?
    private var functionBarHeightConstraint: NSLayoutConstraint?
    private var buttonBar = ButtonBar()
    private let functionKeyBar = FunctionKeyBar()
    private var cachedActiveCwd = NSHomeDirectory()
    /// Trailing titlebar accessory hosting the "titlebar" view container (system
    /// monitor plugin, etc.). Empty until a plugin contributes a titlebar view.
    private let titlebarAccessoryContainer = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 28))
    private lazy var titlebarAccessory: NSTitlebarAccessoryViewController = {
        let vc = NSTitlebarAccessoryViewController()
        vc.layoutAttribute = .trailing
        vc.view = titlebarAccessoryContainer
        return vc
    }()
    /// Root of the on-demand Disk Map sidebar view (nil = not shown). Gates the
    /// view's `when: diskMapActive` and answers getContext("sidebarViewRoot").
    private var diskMapRoot: String?
    /// "light" | "dark" | "system" — drives Theme + NSApp appearance (Dark Mode).
    private var appearanceSetting = "system"
    private var shellOutputWindow: ShellOutputWindow?
    private var listerWindows: [ListerWindowController] = []
    private var quickViewLister: ListerWindowController?
    private var quickViewScheduled = false
    // Quick View embedded in the inactive panel (F-118).
    /// The embedded Quick View's preview area (F-118). A `FilePreviewView` rather than a bare
    /// `QLPreviewView`, so a picture in it can be zoomed exactly as in the side panel (F-389) — it is the
    /// same "quick preview" to the user, and it lands in the *left* panel whenever the right one is
    /// active, which is where this was reported from.
    private var quickViewPreview: FilePreviewView?
    private weak var quickViewHostPanel: PanelController?
    /// Background transfer manager window (created on first use, TODOS #135).
    private var transferManagerWC: TransferManagerWindowController?
    private var openSourceWC: OpenSourceWindowController?
    /// Toolbar (.bar) editor window (retained while open).
    private var buttonBarEditor: ButtonBarEditorWindowController?
    /// FTP connection manager window (retained while open).
    private var ftpConnectWC: FtpConnectionManagerWindowController?
    /// Native Quick Look preview controller (retained; owns the shared panel data).
    private let quickLook = QuickLookController()
    var findWindow: FindFilesWindowController?
    private var searchTask: Task<Void, Never>?
    private let spotlightSearch = SpotlightSearch()
    /// The filesystem the last search ran over, so "View" can extract a hit that
    /// lives inside an archive/network mount (F-153).
    private var lastSearchFS: VirtualFileSystem?
    private var renameWindow: MultiRenameWindowController?
    private var renameUndoLog: [(from: String, to: String)] = []
    private var diffWindows: [DiffWindowController] = []
    private var binaryCompareWindows: [BinaryCompareWindowController] = []
    private var editorWindows: [EditorWindowController] = []
    private var hexEditorWindows: [HexEditorWindowController] = []
    private var pathDialog: InputDialog?
    private var attributesDialog: AttributesDialog?
    private var hotlistManager: HotlistManagerWindowController?
    private var typeColorsEditor: TypeColorsWindowController?
    private var syncWindow: SyncWindowController?
    private var userCommands = UserCommands()
    private var startMenuObserver: NSObjectProtocol?
    private var keymap = Keymap(builtin: KeymapScheme())
    private var currentKeyScheme = "tc-classic"
    private var commandBrowser: CommandBrowserWindowController?
    private var keysWindow: KeysWindowController?
    private var implementedCommands: Set<String> = []
    private lazy var pluginManager = PluginManager(pluginsDir: configPaths.pluginsDirectory,
                                                   configURL: configPaths.pluginsConfig,
                                                   bundledPluginsDir: Bundle.main.builtInPlugInsURL)
    private var pluginsWindow: PluginsWindowController?
    private lazy var workspaceStore = WorkspaceStore(url: configPaths.workspaces)
    /// Content-field registry (rebuilt when enabled PDX plugins change) + the
    /// plugin fields available as columns.
    private var contentFieldRegistry = ContentFieldRegistry()
    /// The "<path>#L<line>" the viewer last asked for a note about, published through the plugin
    /// context for the length of one command dispatch (F-379).
    fileprivate var pendingNoteTarget: String?
    private var availablePluginFields: [ColumnSpec] = []
    private var columnsWindow: ColumnsConfigWindowController?
    private var processTreeWindow: ProcessTreeWindowController?
    private var duplicateWindow: DuplicateFinderWindowController?

    // Undo stack for the last file operations (F-101). Each op carries a label +
    // an inverse action; removals on undo go to the Trash (never a hard delete).
    private struct UndoableOp { let label: String; let run: () async -> Void }
    private var undoStack: [UndoableOp] = []

    /// The config as it was at launch, read synchronously so the first frame is already correct (F-360).
    /// Read-only and never written: `mainConfig`/`session` stay the owners of the files.
    private let startupConfig: ConfigSnapshot
    private let startupSession: ConfigSnapshot

    init() {
        configPaths = ConfigPaths.resolve()
        mainConfig = ConfigStore(url: configPaths.mainConfig)
        session = ConfigStore(url: configPaths.session)
        hotlistStore = ConfigStore(url: configPaths.hotlist)
        // The same two files, read synchronously, for everything that must be right in the first frame
        // (F-360). See `applyVisualStateBeforeFirstPaint`.
        startupConfig = ConfigSnapshot(url: configPaths.mainConfig)
        startupSession = ConfigSnapshot(url: configPaths.session)
        let window = MainWindow(
            contentRect: NSMakeRect(0, 0, 1280, 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Peach Commander"
        window.backgroundColor = Theme.current.windowBackground
        super.init(window: window)
        logger.info("MainWindowController initialized (config: \(self.configPaths.root.path))")
    }

    required init?(coder: NSCoder) {
        configPaths = ConfigPaths.resolve()
        mainConfig = ConfigStore(url: configPaths.mainConfig)
        session = ConfigStore(url: configPaths.session)
        hotlistStore = ConfigStore(url: configPaths.hotlist)
        startupConfig = ConfigSnapshot(url: configPaths.mainConfig)
        startupSession = ConfigSnapshot(url: configPaths.session)
        super.init(coder: coder)
    }

    /// Deterministic setup entry point (called by the app delegate after the
    /// window is shown; `windowDidLoad` is unreliable for programmatic windows).
    func start() {
        Self.shared = self
        leftPanelController = PanelController(position: .left, config: mainConfig)
        rightPanelController = PanelController(position: .right, config: mainConfig)
        setupSplitView()

        // Use the container as the window's contentView (NOT contentViewController):
        // an NSViewController-based content view forces the window to the content's
        // fitting width, which pins the window to 2×minimumThickness and freezes the
        // divider in the middle. With a plain contentView the window drives the
        // content, so it stays freely resizable (down to minSize) and the divider is
        // draggable. The NSSplitViewController is still retained to manage the panes.
        let container = rootContentVC.view
        window?.contentView = container
        buttonBarView.translatesAutoresizingMaskIntoConstraints = false
        commandLine.translatesAutoresizingMaskIntoConstraints = false
        splitView.translatesAutoresizingMaskIntoConstraints = false
        functionKeyBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(buttonBarView)
        container.addSubview(sharedTree)
        sharedTree.translatesAutoresizingMaskIntoConstraints = false
        sharedTreeWidthConstraint = sharedTree.widthAnchor.constraint(equalToConstant: 0)
        container.addSubview(splitView)
        container.addSubview(previewPanel)
        container.addSubview(previewHandle)
        container.addSubview(previewResizer)
        container.addSubview(dockResizer)
        container.addSubview(bottomDock)
        container.addSubview(commandLine)
        container.addSubview(functionKeyBar)
        bottomDock.translatesAutoresizingMaskIntoConstraints = false
        dockResizer.translatesAutoresizingMaskIntoConstraints = false
        dockHeightConstraint = bottomDock.heightAnchor.constraint(equalToConstant: 0)  // shut by default
        // The divider collapses with the dock: a drag handle for something that is not there would be
        // a dead strip across the window, exactly as it would beside a closed preview panel.
        dockResizerHeightConstraint = dockResizer.heightAnchor.constraint(equalToConstant: 0)
        dockResizer.onResize = { [weak self] height in self?.setDockHeight(height) }
        dockResizer.onResizeFinished = { [weak self] height in
            Task { await self?.mainConfig.setInt(Int(height), "Layout", "DockHeight")
                   await self?.mainConfig.flush() }
        }
        bottomDock.onClose = { [weak self] in self?.setBottomDockVisible(false) }
        bottomDock.onSelectionChange = { [weak self] id in
            Task { await self?.mainConfig.setString(id, "Layout", "DockPanel") }
            self?.updateTerminalMenuState()   // switching panels can hide the terminal (F-388)
        }
        previewPanel.translatesAutoresizingMaskIntoConstraints = false
        previewWidthConstraint = previewPanel.widthAnchor.constraint(equalToConstant: 0)  // hidden by default
        // The resizer collapses with the panel: a drag handle for something that is not there
        // would be a dead strip down the middle of the window.
        previewResizerWidthConstraint = previewResizer.widthAnchor.constraint(equalToConstant: 0)
        previewPanel.onModeChange = { [weak self] _ in
            self?.refreshPreview()
            self?.updateTerminalMenuState()   // the terminal may be one of the sidebar's tabs (F-388)
        }
        previewHandle.translatesAutoresizingMaskIntoConstraints = false
        previewHandle.onClick = { [weak self] in self?.togglePreviewPanel() }
        previewResizer.translatesAutoresizingMaskIntoConstraints = false
        previewResizer.onResize = { [weak self] width in self?.setPreviewWidth(width) }
        previewResizer.onResizeFinished = { [weak self] width in
            Task { await self?.mainConfig.setInt(Int(width), "Layout", "PreviewWidth")
                   await self?.mainConfig.flush() }
        }
        buttonBarHeightConstraint = buttonBarView.heightAnchor.constraint(equalToConstant: 0)
        buttonBarWidthConstraint = buttonBarView.widthAnchor.constraint(equalToConstant: 0)
        commandLineHeightConstraint = commandLine.heightAnchor.constraint(equalToConstant: Metrics.commandLineHeight)
        functionBarHeightConstraint = functionKeyBar.heightAnchor.constraint(equalToConstant: FunctionKeyBar.barHeight)
        // Constraints that never change (button-bar top-left anchor, the preview
        // column on the right, the command line + function bar across the bottom).
        NSLayoutConstraint.activate([
            buttonBarView.topAnchor.constraint(equalTo: container.topAnchor),
            buttonBarView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            // The resizer sits between the file panels and the preview column, which is where a
            // divider belongs — the toggle chevron stays out at the window edge.
            sharedTreeWidthConstraint!,
            sharedTree.topAnchor.constraint(equalTo: splitView.topAnchor),
            sharedTree.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
            splitView.trailingAnchor.constraint(equalTo: previewResizer.leadingAnchor),
            previewResizer.trailingAnchor.constraint(equalTo: previewPanel.leadingAnchor),
            previewResizer.topAnchor.constraint(equalTo: splitView.topAnchor),
            previewResizer.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
            previewResizerWidthConstraint!,
            previewPanel.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
            previewPanel.trailingAnchor.constraint(equalTo: previewHandle.leadingAnchor),
            previewWidthConstraint!,
            previewHandle.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
            previewHandle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            previewHandle.widthAnchor.constraint(equalToConstant: PreviewToggleHandle.width),
            // The dock spans the whole window between the panels and the command line, so the command
            // line and the function-key bar stay exactly where the muscle memory expects them.
            dockResizer.topAnchor.constraint(equalTo: splitView.bottomAnchor),
            dockResizer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dockResizer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dockResizerHeightConstraint!,
            bottomDock.topAnchor.constraint(equalTo: dockResizer.bottomAnchor),
            bottomDock.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomDock.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dockHeightConstraint!,
            commandLine.topAnchor.constraint(equalTo: bottomDock.bottomAnchor),
            commandLine.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            commandLine.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            commandLineHeightConstraint!,
            functionKeyBar.topAnchor.constraint(equalTo: commandLine.bottomAnchor),
            functionKeyBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            functionKeyBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            functionKeyBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            functionBarHeightConstraint!,
        ])
        // Horizontal (top-strip): bar spans the top, content sits below it.
        buttonBarGroupH = [
            buttonBarView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonBarHeightConstraint!,
            splitView.topAnchor.constraint(equalTo: buttonBarView.bottomAnchor),
            sharedTree.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            splitView.leadingAnchor.constraint(equalTo: sharedTree.trailingAnchor),
            previewPanel.topAnchor.constraint(equalTo: buttonBarView.bottomAnchor),
            previewHandle.topAnchor.constraint(equalTo: buttonBarView.bottomAnchor),
        ]
        // Vertical (left-column): bar spans top→command-line on the left, content
        // sits to its right.
        buttonBarGroupV = [
            buttonBarView.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
            buttonBarWidthConstraint!,
            splitView.topAnchor.constraint(equalTo: container.topAnchor),
            sharedTree.leadingAnchor.constraint(equalTo: buttonBarView.trailingAnchor),
            splitView.leadingAnchor.constraint(equalTo: sharedTree.trailingAnchor),
            previewPanel.topAnchor.constraint(equalTo: container.topAnchor),
            previewHandle.topAnchor.constraint(equalTo: container.topAnchor),
        ]
        NSLayoutConstraint.activate(buttonBarGroupH)
        functionKeyBar.onRun = { [weak self] cmd in self?.runCommandNamed(cmd) }
        loadExternalPlugins()
        window?.minSize = NSSize(width: 640, height: 400)
        splitView.setPosition(512.0, ofDividerAt: 0)
        window?.delegate = self
        installTitlebarAccessory()
        (window as? MainWindow)?.onTabSwitch = { [weak self] in self?.toggleActivePanel() }
        activePanel = leftPanelController

        commandLine.cwdProvider = { [weak self] in self?.cachedActiveCwd ?? NSHomeDirectory() }
        commandLine.onExecute = { [weak self] line in self?.runCommandLine(line) }


        // Persist session state when a panel's path/sort changes.
        leftPanelController?.onStateChanged = { [weak self] in self?.scheduleSaveState(); self?.updateCommandLinePrompt(); self?.emitPanelEvent(.left) }
        rightPanelController?.onStateChanged = { [weak self] in self?.scheduleSaveState(); self?.updateCommandLinePrompt(); self?.emitPanelEvent(.right) }
        leftPanelController?.onCursorChanged = { [weak self] in self?.updateQuickView(); self?.notifyPluginViews(); self?.emitCursorEvent(.left) }
        rightPanelController?.onCursorChanged = { [weak self] in self?.updateQuickView(); self?.notifyPluginViews(); self?.emitCursorEvent(.right) }
        leftPanelController?.tableView.keymapRouter = { [weak self] in self?.routeKeymap($0) ?? false }
        rightPanelController?.tableView.keymapRouter = { [weak self] in self?.routeKeymap($0) ?? false }
        (window as? MainWindow)?.onFirstResponderChange = { [weak self] in
            self?.refreshFunctionKeyOwnership()
        }
        leftPanelController?.tableView.wantsRawKeyboard = { [weak self] in self?.focusedViewWantsRawKeyboard($0) ?? false }
        rightPanelController?.tableView.wantsRawKeyboard = { [weak self] in self?.focusedViewWantsRawKeyboard($0) ?? false }

        installMainMenu()
        loadUserCommands()
        loadButtonBar()
        loadPlugins()
        Task { @MainActor in
            await self.commandRegistry.registerDefaultCommands()
            // Cache the numeric-id → cm_ name map so a .mnu can reference TC ids (F-257),
            // then rebuild in case a user .mnu is present and needed id resolution.
            let all = await self.commandRegistry.getAllCommands()
            self.commandIdToName = Dictionary(all.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            if self.hasUserMenuFile { self.rebuildMainMenu() }
            await self.restoreStateAndLoad()   // loads the keymap
            await self.applyKeymapToMenu()
        }

        // Last, and before the window is shown: the appearance the user configured, not the default
        // one (F-360). Everything above built the views; this decides what they look like.
        applyVisualStateBeforeFirstPaint()
        logger.info("MainWindowController window loaded")
    }

    private func setupSplitView() {
        guard let left = leftPanelController, let right = rightPanelController else { return }
        // A plain NSSplitView (not NSSplitViewController): the controller couples the
        // window/content width to the panes' fitting width, which pins the window and
        // freezes the divider. A plain split view resizes with the window and, with the
        // min-coordinate delegate below, keeps a freely draggable divider.
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        // The shared tree steers the *active* panel (F-015).
        sharedTree.onSelect = { [weak self] path in
            guard let self, let panel = self.activePanel else { return }
            Task { @MainActor in await panel.loadDirectory(path) }
        }
        // Double-clicking the divider gives two equal panels back (F-001).
        splitView.onDividerDoubleClick = { [weak self] in self?.centerDivider() }
        splitView.translatesAutoresizingMaskIntoConstraints = false
        left.view.translatesAutoresizingMaskIntoConstraints = true
        right.view.translatesAutoresizingMaskIntoConstraints = true
        splitView.addSubview(left.view)
        splitView.addSubview(right.view)
        // Save state when the user drags the divider.
        NotificationCenter.default.addObserver(self, selector: #selector(splitViewResized),
                                               name: NSSplitView.didResizeSubviewsNotification,
                                               object: splitView)
    }

    @objc private func splitViewResized() { scheduleSaveState() }

    // MARK: - NSSplitViewDelegate (keep each pane at least `minPaneWidth` wide)

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMin: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        max(proposedMin, minPaneWidth)
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMax: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        // The divider slides along width when vertical, height when horizontal.
        let span = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        return min(proposedMax, span - splitView.dividerThickness - minPaneWidth)
    }

    private var isMaximized = false

    /// Put the divider in the middle of the split view along its current axis.
    ///
    /// Reached from the panel arrangement, from a launch with no saved width, and — since F-001 said so
    /// and nothing did it — from a double-click on the divider itself, which is how Total Commander
    /// gives you two equal panels back.
    func centerDivider() {
        window?.contentView?.layoutSubtreeIfNeeded()
        let span = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard span > 0 else { return }
        splitView.setPosition(SplitDividerHit.centeredPosition(span: span,
                                                               dividerThickness: splitView.dividerThickness),
                              ofDividerAt: 0)
    }

    /// Apply the current panel arrangement (side-by-side vs stacked) to the split
    /// view and recenter the divider along the new axis (F-002).
    private func applyPanelArrangement() {
        splitView.isVertical = !horizontalPanels
        splitView.adjustSubviews()
        centerDivider()
        setMenuCheck(cmd: "cm_HorizontalPanels", on: horizontalPanels)
    }

    /// Toggle horizontal panel arrangement, persist it, and re-lay-out.
    func toggleHorizontalPanels() {
        horizontalPanels.toggle()
        let value = horizontalPanels
        Task { await mainConfig.setBool(value, "Layout", "HorizontalPanels") }
        applyPanelArrangement()
    }

    /// Set the checkmark on the menu item whose represented command is `cmd`.
    private func setMenuCheck(cmd: String, on: Bool) {
        guard let menu = NSApp.mainMenu else { return }
        func walk(_ m: NSMenu) {
            for item in m.items {
                if (item.representedObject as? String) == cmd { item.state = on ? .on : .off }
                if let sub = item.submenu { walk(sub) }
            }
        }
        walk(menu)
    }

    /// Clamp the window's size + position into the current screen's visible frame so
    /// the title bar and edges stay reachable (e.g. after moving to a smaller monitor
    /// or restoring a frame saved on a larger one).
    private func ensureWindowOnScreen() {
        guard let window, let vf = (window.screen ?? NSScreen.main)?.visibleFrame else { return }
        var f = window.frame
        f.size.width = min(f.width, vf.width)
        f.size.height = min(f.height, vf.height)
        f.origin.x = min(max(f.minX, vf.minX), vf.maxX - f.width)
        f.origin.y = min(max(f.minY, vf.minY), vf.maxY - f.height)
        if f != window.frame { window.setFrame(f, display: true) }
    }

    // Green "zoom"/maximize button: fill the screen's visible frame when maximizing,
    // otherwise return to a comfortable default size. The split view resizes
    // proportionally with the window, so the divider ratio is preserved.
    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        isMaximized.toggle()
        let vf = (window.screen ?? NSScreen.main)?.visibleFrame ?? newFrame
        if isMaximized {
            window.setFrame(vf, display: true)
        } else {
            var f = window.frame
            f.size.width = min(1280, vf.width)
            f.size.height = min(820, vf.height)
            window.setFrame(f, display: true)
            window.center()
        }
        return false
    }

    // MARK: - Session restore / save (I05-T02)

    /// Apply everything the user can see, before the window is shown (F-360).
    ///
    /// All of this used to run in the async restore, i.e. after the window was already on screen, so
    /// the first frame showed the built-in defaults and corrected itself a moment later: a light window
    /// that turned dark, bars that appeared and disappeared, side-by-side panels that became stacked,
    /// a window that jumped to its saved size. Read from a synchronous snapshot of the same files
    /// (`ConfigSnapshot`) there is nothing to wait for, and the first paint is the right one.
    ///
    /// The order is the one the async version had, because some of it matters: user palettes before the
    /// theme id that may name one of them, the appearance after the theme it derives from, and the
    /// window frame before the divider position that is measured against it.
    ///
    /// Nothing here is repeated by `restoreStateAndLoad` — a second pass would be harmless for the
    /// setters but not for `togglePreviewPanel`, which toggles, so applying it twice would close the
    /// panel it just opened.
    private func applyVisualStateBeforeFirstPaint() {
        let config = startupConfig

        hiddenFilesShown = config.bool("Configuration", "ShowHiddenSystem", default: false)
        leftPanelController?.setHiddenFiles(hiddenFilesShown)
        rightPanelController?.setHiddenFiles(hiddenFilesShown)
        IconLoader.shared.mode = Self.iconMode(from: config.string("Configuration", "IconMode",
                                                                  default: "all"))
        let watchDirectories = config.bool("Configuration", "WatchDirectories", default: true)
        leftPanelController?.watchDirectories = watchDirectories
        rightPanelController?.watchDirectories = watchDirectories
        displaySizeStyle = config.string("Display", "SizeStyle", default: "kb")
        displayTypeColors = config.string("Display", "TypeColors", default: "")
        displayBrackets = config.bool("Display", "BracketDirs", default: false)
        displayNaturalSort = config.bool("Display", "NaturalSort", default: true)
        displayAlternatingRows = config.bool("Display", "AlternatingRows", default: false)
        displayFontSize = config.int("Display", "FontSize", default: 13)
        displayDateFormat = config.string("Display", "DateFormat",
                                         default: PanelDateFormatter.defaultPattern)
        applyDisplayOptionsToPanels()
        Theme.customColors = Theme.ColorOverride(                              // F-272
            listText: NSColor(hexString: config.string("Colors", "Foreground", default: "")),
            listBackground: NSColor(hexString: config.string("Colors", "Background", default: "")),
            selectedText: NSColor(hexString: config.string("Colors", "Selection", default: "")),
            cursorFrame: NSColor(hexString: config.string("Colors", "Cursor", default: "")))
        // User themes first: the id read below may name one of them, and resolution falls back
        // to "system" for anything unknown, so loading after this would render a user theme as
        // the default on every launch.
        ThemeFile.loadUserPalettes(from: configPaths.themesDirectory)
        // Selected colour theme. "system" is the default and means: no named palette, follow
        // the appearance exactly as before — so an existing configuration renders unchanged.
        themeId = config.string("Colors", "Theme", default: "system")
        applyAppearance(config.string("Colors", "Appearance", default: "system"))
        let savedWidth = config.int("Layout", "PreviewWidth", default: Int(Self.previewWidth))
        preferredPreviewWidth = max(PreviewResizeHandle.minWidth, CGFloat(savedWidth))
        if config.bool("Layout", "PreviewPanel", default: false) { togglePreviewPanel() }
        horizontalPanels = config.bool("Layout", "HorizontalPanels", default: false)
        if horizontalPanels { applyPanelArrangement() }
        setCommandLineVisible(config.bool("Layout", "CommandLine", default: true))
        setFunctionBarVisible(config.bool("Layout", "FunctionKeys", default: true))
        setButtonBarVisible(config.bool("Layout", "ButtonBar", default: true))
        setDriveBarVisible(config.bool("Layout", "DriveBar", default: true))
        setStatusBarVisible(config.bool("Layout", "StatusBar", default: true))
        setTabBarVisible(config.bool("Layout", "TabBar", default: true))
        setPathBarVisible(config.bool("Layout", "PathBar", default: true))
        if let mode = PanelViewMode(rawValue: config.string("Layout", "LeftViewMode",
                                                           default: "details")) {
            leftPanelController?.setViewMode(mode)
        }
        if let mode = PanelViewMode(rawValue: config.string("Layout", "RightViewMode",
                                                           default: "details")) {
            rightPanelController?.setViewMode(mode)
        }
        if config.bool("Layout", "LeftTree", default: false) { leftPanelController?.setTreeVisible(true) }
        if config.bool("Layout", "RightTree", default: false) { rightPanelController?.setTreeVisible(true) }
        if config.bool("Layout", "SharedTree", default: false) { setSharedTreeVisible(true, persist: false) }
        // The dock (F-381). Its height is restored whether or not it is open, so reopening it later
        // gives back the size it had rather than the factory one.
        loadViewPlacements(config)
        preferredDockHeight = max(BottomDockView.minHeight,
                                  CGFloat(config.int("Layout", "DockHeight",
                                                     default: Int(BottomDockView.defaultHeight))))
        let panel = config.string("Layout", "DockPanel", default: "")
        rememberedDockPanel = panel.isEmpty ? nil : panel
        if let rememberedDockPanel { bottomDock.selectProvider(id: rememberedDockPanel) }
        // Shut by default: opening it needs a plugin to have something to show, and closing it again
        // when nothing does is handled where the providers arrive — which is also where it is opened
        // *back* up once one does, since the plugins are still loading at this point. The wish is set
        // here without persisting it: this is the config being read, not the user choosing again.
        dockWantedVisible = config.bool("Layout", "DockVisible", default: false)
        if dockWantedVisible { setBottomDockVisible(true, persist: false) }
        runCommandLineInTerminal = config.bool("Terminal", "RunCommandLine", default: false)
        setMenuCheck(cmd: "cm_TerminalRunCommandLine", on: runCommandLineInTerminal)
        if config.bool("Layout", "ButtonBarVertical", default: false) { setButtonBarVertical(true) }
        // The keymap names the function-key bar's labels, so a late load relabels the bar in place.
        loadKeymap(scheme: config.string("Configuration", "KeyScheme", default: "tc-classic"))

        // Window frame + splitter (session). Restore a saved frame if present, then
        // size the panes for the CURRENT screen and make sure the whole window
        // (title bar included) is on-screen — a frame saved on a bigger monitor must
        // not leave the header above a smaller screen.
        if let savedFrame = Self.parseFrame(startupSession.string("Window", "Frame", default: "")) {
            window?.setFrame(savedFrame, display: true)
        } else {
            window?.center()
        }
        ensureWindowOnScreen()
        // Restore the saved divider position, otherwise center it.
        let leftWidth = startupSession.double("Window", "LeftWidth", default: 0)
        if leftWidth > 50 {
            window?.contentView?.layoutSubtreeIfNeeded()
            splitView.setPosition(leftWidth, ofDividerAt: 0)
        } else {
            centerDivider()
        }
    }


    #if DEBUG
    /// What the window looks like at the moment it is shown (`-StartupProbe <file>`, F-360).
    ///
    /// Read off the *views*, not off the flags that were set: a flag says what the code intended, and
    /// the complaint here was about what was on screen. If any of these still held its built-in default
    /// while the configuration said otherwise, the first frame was wrong — which is precisely what this
    /// makes checkable instead of a matter of feel.
    func startupProbeReport() -> String {
        let appearance = window?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])?.rawValue ?? "-"
        let frame = window?.frame ?? .zero
        func hex(_ color: NSColor) -> String {
            let rgb = color.usingColorSpace(.sRGB) ?? .black
            return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255),
                          Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
        }
        return """
        theme=\(themeId)
        appearance=\(appearance)
        listBackground=\(hex(Theme.current.listBackground))
        commandLine=\(!commandLine.isHidden)
        functionBar=\(!functionKeyBar.isHidden)
        buttonBar=\(!buttonBarView.isHidden && (buttonBarHeightConstraint?.constant ?? 0) > 0)
        buttonBarVertical=\(buttonBarVertical)
        previewPanel=\(previewIsVisible)
        panelsVertical=\(splitView.isVertical)
        leftViewMode=\(leftPanelController?.viewMode.rawValue ?? "-")
        rightViewMode=\(rightPanelController?.viewMode.rawValue ?? "-")
        hiddenFiles=\(hiddenFilesShown)
        fontSize=\(displayFontSize)
        frame=\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height))
        dividerAt=\(Int(leftPanelController?.view.frame.width ?? 0))

        """
    }

    /// Write the probe if `-StartupProbe <file>` was given. Called right after the window is shown.
    func writeStartupProbeIfRequested() {
        guard let path = LaunchOptions.parse(CommandLine.arguments).startupProbe else { return }
        try? startupProbeReport().write(toFile: path, atomically: true, encoding: .utf8)
        logger.info("startup probe written to \(path, privacy: .public)")
    }
    #endif

    private func restoreStateAndLoad() async {
        // Everything visible — palette, appearance, which bars are shown, panel arrangement, view
        // modes, the window frame — was applied synchronously before the first paint; see
        // `applyVisualStateBeforeFirstPaint` (F-360). What is left here is the state nobody can see
        // until they use it, which is exactly what may arrive a moment late.
        await startMCPServerIfEnabled()
        // Cache the AI cloud endpoint so the AI plugin can read it via getContext
        // (the config store is async; contribAugmentContext is sync).
        cachedCloudBase = await mainConfig.string("AI", "CloudBaseURL", default: "")
        cachedCloudModel = await mainConfig.string("AI", "CloudModel", default: "local")
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(systemAppearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
        // Most dialogs are created long after the theme was applied, so painting only the windows
        // that exist now would miss nearly all of them (F-339).
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowBecameKey(_:)),
            name: NSWindow.didBecomeKeyNotification, object: nil)
        let mouseMode = await mainConfig.string("Operation", "MouseMode", default: "left")
        leftPanelController?.setMouseMode(mouseMode)
        rightPanelController?.setMouseMode(mouseMode)
        let quickSearch = await mainConfig.string("Operation", "QuickSearchMode", default: "direct")
        leftPanelController?.setQuickSearchMode(quickSearch)
        rightPanelController?.setQuickSearchMode(quickSearch)
        copyPreserveMetadata = await mainConfig.bool("Copy", "PreserveMetadata", default: true)
        copyUseClone = await mainConfig.bool("Copy", "CloneCopy", default: true)
        copyOnlyNewer = await mainConfig.bool("Copy", "OnlyNewer", default: false)
        copySpeedLimitKBps = await mainConfig.int("Copy", "SpeedLimitKBps", default: 0)
        applyCopyDefaultsToPanels()
        packDefaultFormat = await mainConfig.string("Pack", "DefaultFormat", default: "zip")
        packLevel = Int(await mainConfig.string("Pack", "Level", default: "5")) ?? 5
        applyPackDefaultsToPanels()
        tabOpenInForeground = await mainConfig.bool("Tabs", "OpenInForeground", default: true)
        tabLockedOpensNewTab = await mainConfig.bool("Tabs", "LockedOpensNewTab", default: true)
        applyTabDefaultsToPanels()
        ftpKeepAliveSeconds = Int(await mainConfig.string("FTP", "KeepAliveSeconds", default: "0")) ?? 0
        // The editors save on the main actor and cannot await the config store there, so the answer is
        // read once here and kept where all three save paths can see it (F-387).
        DocumentFile.keepBackups = await mainConfig.bool("Editor", "CreateBackups", default: false)
        // Panel tabs (session).
        didRestore = true
        await restoreTabs(into: leftPanelController, prefix: "LeftPanel")
        await restoreTabs(into: rightPanelController, prefix: "RightPanel")

        let active = await session.string("Window", "Active", default: "left")
        if active == "right" { activateRightPanel() } else { activateLeftPanel() }
        await loadHotlist()
        let launchOpts = LaunchOptions.parse(CommandLine.arguments)
        await applyLaunchOptions(launchOpts)
        logger.info("Session restored")
        #if DEBUG
        if let script = launchOpts.automationScript { await runAutomationScript(script) }
        #endif
    }

    /// Apply command-line launch parameters over the restored session: point the
    /// panels at the requested directories (in a new tab with -Tab) and set the
    /// active panel. Only existing directories are honored.
    private func applyLaunchOptions(_ opts: LaunchOptions) async {
        func isDir(_ p: String) -> Bool {
            var d: ObjCBool = false
            return FileManager.default.fileExists(atPath: p, isDirectory: &d) && d.boolValue
        }
        if let left = opts.effectiveLeft, isDir(left) {
            await leftPanelController?.openFromLaunch(path: left, inNewTab: opts.openInNewTab)
        }
        if let right = opts.effectiveRight, isDir(right) {
            await rightPanelController?.openFromLaunch(path: right, inNewTab: opts.openInNewTab)
        }
        switch opts.activePanel {
        case .left: activateLeftPanel()
        case .right: activateRightPanel()
        case nil: break
        }
        // -View <file> [-ViewSearch <term>]: open the file straight in the viewer,
        // optionally pre-applying a search (F-113).
        if let file = opts.viewFile, FileManager.default.fileExists(atPath: file) {
            openLister(files: [file], index: 0)
            if let term = opts.viewSearch, !term.isEmpty {
                listerWindows.last?.applyInitialSearch(term)
            }
        }
    }

    // MARK: - Hotlist (I06-T03)

    private func loadHotlist() async {
        let count = await hotlistStore.int("Hotlist", "Count", default: 0)
        var entries: [HotlistEntry] = []
        for i in 0..<max(0, count) {
            let path = await hotlistStore.string("Hotlist", "Entry\(i)Path", default: "")
            let title = await hotlistStore.string("Hotlist", "Entry\(i)Title",
                                                  default: (path as NSString).lastPathComponent)
            // Keep separators (title "-", no path); skip only truly empty rows.
            guard !path.isEmpty || title == "-" else { continue }
            entries.append(HotlistEntry(title: title, path: path))
        }
        hotlist = Hotlist(entries: entries)
    }

    private func persistHotlist() async {
        await hotlistStore.setInt(hotlist.entries.count, "Hotlist", "Count")
        for (i, entry) in hotlist.entries.enumerated() {
            await hotlistStore.setString(entry.title, "Hotlist", "Entry\(i)Title")
            await hotlistStore.setString(entry.path, "Hotlist", "Entry\(i)Path")
        }
        await hotlistStore.flush()
    }

    /// The current hotlist favorites (for the per-panel Go dropdown).
    func favoriteEntries() -> [(title: String, path: String)] {
        hotlist.entries.map { ($0.title, $0.path) }
    }

    func showHotlist() {
        guard let panel = activePanel else { return }
        let menu = buildHotlistMenu()
        if !hotlist.entries.isEmpty { menu.addItem(.separator()) }
        let add = NSMenuItem(title: String(localized: "Add Current Directory"),
                             action: #selector(hotlistAddCurrent), keyEquivalent: "d")
        add.target = self
        menu.addItem(add)
        let organize = NSMenuItem(title: String(localized: "Organize Hotlist…"),
                                  action: #selector(showHotlistManager), keyEquivalent: "")
        organize.target = self
        menu.addItem(organize)
        let point = NSPoint(x: 12, y: panel.view.bounds.height - 36)
        menu.popUp(positioning: nil, at: point, in: panel.view)
    }

    /// Build the hotlist as a nested menu (F-061): a "Folder\Item" title places the
    /// item under a "Folder" submenu (any depth); a title of "-" is a separator.
    private func buildHotlistMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Hotlist"))
        var submenus: [String: NSMenu] = [:]   // backslash-prefix → its submenu
        var accel = 0
        for entry in hotlist.entries {
            let parts = entry.title.components(separatedBy: "\\")
            // Resolve (creating as needed) the parent submenu for this entry.
            var parent = menu
            var prefix = ""
            for comp in parts.dropLast() where !comp.isEmpty {
                prefix = prefix.isEmpty ? comp : prefix + "\\" + comp
                if let existing = submenus[prefix] {
                    parent = existing
                } else {
                    let sub = NSMenu(title: comp)
                    let subItem = NSMenuItem(title: comp, action: nil, keyEquivalent: "")
                    subItem.submenu = sub
                    parent.addItem(subItem)
                    submenus[prefix] = sub
                    parent = sub
                }
            }
            let leaf = parts.last ?? entry.title
            if leaf == "-" { parent.addItem(.separator()); continue }
            let item = NSMenuItem(title: leaf, action: #selector(hotlistNavigate(_:)),
                                  keyEquivalent: accel < 9 ? "\(accel + 1)" : "")
            item.representedObject = entry.path
            item.target = self
            parent.addItem(item)
            accel += 1
        }
        return menu
    }

    @objc func showHotlistManager() {
        let manager = HotlistManagerWindowController(entries: hotlist.entries)
        manager.onSave = { [weak self] newEntries in
            guard let self else { return }
            self.hotlist.setEntries(newEntries)
            Task { @MainActor in await self.persistHotlist() }
        }
        hotlistManager = manager
        manager.showWindow(nil)
        manager.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func hotlistNavigate(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        Task { @MainActor in await activePanel?.loadDirectory(path) }
    }


    // MARK: - Workspaces (named layouts)

    /// Popup hub: load a saved workspace, delete one, or save the current layout.
    func showWorkspaces() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            let names = await workspaceStore.names()
            let menu = NSMenu(title: String(localized: "Workspaces"))
            if names.isEmpty {
                let empty = NSMenuItem(title: String(localized: "(no saved workspaces)"), action: nil, keyEquivalent: "")
                empty.isEnabled = false
                menu.addItem(empty)
            } else {
                for (i, name) in names.enumerated() {
                    let item = NSMenuItem(title: name, action: #selector(self.loadWorkspaceMenu(_:)),
                                          keyEquivalent: i < 9 ? "\(i + 1)" : "")
                    item.representedObject = name
                    item.target = self
                    menu.addItem(item)
                }
                menu.addItem(.separator())
                let delete = NSMenuItem(title: String(localized: "Delete"), action: nil, keyEquivalent: "")
                let deleteMenu = NSMenu()
                for name in names {
                    let d = NSMenuItem(title: name, action: #selector(self.deleteWorkspaceMenu(_:)), keyEquivalent: "")
                    d.representedObject = name
                    d.target = self
                    deleteMenu.addItem(d)
                }
                delete.submenu = deleteMenu
                menu.addItem(delete)
            }
            menu.addItem(.separator())
            let save = NSMenuItem(title: String(localized: "Save Current as Workspace…"),
                                  action: #selector(self.saveWorkspacePrompt), keyEquivalent: "")
            save.target = self
            menu.addItem(save)
            let point = NSPoint(x: 12, y: panel.view.bounds.height - 36)
            menu.popUp(positioning: nil, at: point, in: panel.view)
        }
    }

    /// Prompt for a name and save the current two-panel layout.
    func showSaveWorkspace() {
        let dialog = InputDialog(title: String(localized: "Save Workspace"),
                                 prompt: String(localized: "Workspace name:"), initialValue: "")
        dialog.onConfirm = { [weak self] name in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            Task { @MainActor in await self?.saveCurrentWorkspace(named: trimmed) }
        }
        self.pathDialog = dialog
        dialog.runModalDialog()
    }

    @objc private func saveWorkspacePrompt() { showSaveWorkspace() }

    @objc private func loadWorkspaceMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        Task { @MainActor in await self.loadWorkspace(name) }
    }

    @objc private func deleteWorkspaceMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        Task { await self.workspaceStore.delete(name) }
    }

    private func saveCurrentWorkspace(named name: String) async {
        guard let left = leftPanelController, let right = rightPanelController else { return }
        let (l, la) = left.exportTabs()
        let (r, ra) = right.exportTabs()
        let layout = WorkspaceLayout(left: l, leftActive: la, right: r, rightActive: ra,
                                     activeSide: activePanel === right ? "right" : "left")
        await workspaceStore.save(name, layout: layout)
    }

    private func loadWorkspace(_ name: String) async {
        guard let layout = await workspaceStore.load(name) else { return }
        await leftPanelController?.importTabs(layout.left, activeIndex: layout.leftActive)
        await rightPanelController?.importTabs(layout.right, activeIndex: layout.rightActive)
        if layout.activeSide == "right" { activateRightPanel() } else { activateLeftPanel() }
        updateCommandLinePrompt()
    }

    // MARK: - Lister (I07)

    func showLister() {
        guard let panel = activePanel else { return }
        // F3 on a directory shows a recursive folder summary, not file content.
        if !panel.isInArchive, let dir = panel.tableView.cursorDirectoryPath() {
            openDirectoryLister(dir)
            return
        }
        Task { @MainActor in
            let plugins = await self.makeListerPlugins()
            if panel.isInArchive {
                if let local = await panel.localPathForCursor() {
                    self.openLister(files: [local], index: 0, plugins: plugins)
                }
            } else {
                let ctx = panel.listerContext()
                guard !ctx.paths.isEmpty else { return }
                // Per-extension viewer association (F-273): open the cursor file in
                // its configured external app instead of the built-in Lister.
                let cursor = ctx.paths[ctx.index]
                if let app = self.fileAssociations().viewerApp(forExtension: (cursor as NSString).pathExtension),
                   self.openWithExternalApp(cursor, app: app) {
                    return
                }
                self.openLister(files: ctx.paths, index: ctx.index, plugins: plugins)
            }
        }
    }

    /// Freshly-parsed per-extension viewer/editor associations (F-273). Parsed on
    /// each use so hand-edits to associations.ini take effect without a restart.
    private func fileAssociations() -> FileAssociations {
        let text = (try? String(contentsOf: configPaths.associations, encoding: .utf8)) ?? ""
        return FileAssociations.parse(text)
    }

    /// Persist edited associations to associations.ini (F-273 Options editor).
    /// fileAssociations() re-parses on each use, so changes take effect at once.
    private func saveFileAssociations(_ assoc: FileAssociations) {
        do {
            try FileManager.default.createDirectory(at: configPaths.associations.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try assoc.serialized().write(to: configPaths.associations, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed to save associations: \(error)")
        }
    }

    /// Open `path` in the external application named by `app` (an `.app` path or a
    /// bundle id). Returns false if the app can't be resolved, so the caller can
    /// fall back to the built-in view/edit.
    @discardableResult
    private func openWithExternalApp(_ path: String, app: String) -> Bool {
        let appURL: URL?
        if app.hasPrefix("/") {
            appURL = FileManager.default.fileExists(atPath: app) ? URL(fileURLWithPath: app) : nil
        } else {
            appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app)
        }
        guard let appURL else { return false }
        NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: appURL,
                                configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        return true
    }

    /// Build a `PLXLister` for each enabled lister (PLX) plugin, opening its dylib
    /// on demand. Rebuilt per viewer open so it reflects the current enabled set.
    func makeListerPlugins() async -> [PLXLister] {
        let plx = await pluginManager.enabledPlugins().filter { $0.manifest.type == .plx }
        var listers: [PLXLister] = []
        for plugin in plx {
            if case .success(let lib) = PluginHost.openLibrary(plugin) {
                listers.append(PLXLister(library: lib, name: plugin.manifest.name))
            }
        }
        return listers
    }

    /// Does a rename spec actually use a `[=provider.field]` placeholder?
    ///
    /// Resolving those means one plugin call per file per field, so it is skipped when the masks do not
    /// ask for them. Which mask is in force is only known once the dialog is open, hence this test.
    private static func usesContentFields(_ values: MultiRenameWindowController.SpecValues) -> Bool {
        // Only the two masks can carry a placeholder; search/replace operate on the expanded name.
        values.nameMask.contains("[=") || values.extMask.contains("[=")
    }

    /// Populate each rename input's content-field values (built-in `fileinfo.*`
    /// plus enabled PDX plugin fields) for `[=provider.field]` masks (F-172).
    ///
    /// `limit` guards against spending a plugin call per file when nothing needs the values. It used to
    /// be a flat 500 applied *before* the dialog opened, so a selection of 600 files silently resolved
    /// every `[=…]` to an empty string — and renaming 600 photos by their EXIF date is the case this
    /// feature exists for. The cap now only applies when the masks do not ask for these fields; when
    /// they do, the values are fetched however many files there are, because a wrong name is worse than
    /// a slow dialog.
    private func enrichRenameInputs(_ inputs: [RenameInput], dir: String,
                                    limit: Int = 500) async -> [RenameInput] {
        let fields = contentFieldRegistry.allQualifiedFields()
        guard !fields.isEmpty, inputs.count <= limit else { return inputs }
        var out: [RenameInput] = []
        out.reserveCapacity(inputs.count)
        for input in inputs {
            let url = URL(fileURLWithPath: (dir as NSString).appendingPathComponent(input.name))
            var values: [String: String] = [:]
            for (qid, _) in fields {
                let display = await contentFieldRegistry.value(qualifiedID: qid, forFileAt: url).display
                if !display.isEmpty { values[qid] = display }
            }
            out.append(RenameInput(name: input.name, modified: input.modified,
                                   parentName: input.parentName, grandparentName: input.grandparentName,
                                   fields: values))
        }
        return out
    }

    // MARK: - Multi-rename (I11)

    func showMultiRename() {
        guard let panel = activePanel, !panel.isInArchive else { return }
        Task { @MainActor in
            let (dir, baseInputs) = await panel.renameInputs()
            guard !baseInputs.isEmpty else { return }
            // Populate content-plugin field values so [=provider.field] masks work (F-172).
            var inputs = await self.enrichRenameInputs(baseInputs, dir: dir)
            let win = MultiRenameWindowController(oldNames: inputs.map { $0.name },
                                                 presetsURL: self.configPaths.renamePresets)
            self.renameWindow = win
            var lastResults: [RenameResult] = []
            var enrichedOnDemand = false
            win.onSpecChanged = { values in
                // A large selection skipped the field lookup above; if the mask turns out to need it,
                // fetch it now rather than quietly renaming everything with an empty value in place of
                // the field. Once per dialog, not per keystroke.
                if !enrichedOnDemand, Self.usesContentFields(values), inputs.first?.fields.isEmpty != false {
                    enrichedOnDemand = true
                    Task { @MainActor in
                        inputs = await self.enrichRenameInputs(baseInputs, dir: dir, limit: .max)
                        let refreshed = MultiRenameEngine.compute(inputs, spec: Self.renameSpec(from: values))
                        lastResults = refreshed
                        win.setPreview(refreshed.map { ($0.oldName, $0.newName, $0.isValid && !$0.collides) })
                    }
                }
                let results = MultiRenameEngine.compute(inputs, spec: Self.renameSpec(from: values))
                lastResults = results
                win.setPreview(results.map { ($0.oldName, $0.newName, $0.isValid && !$0.collides) })
            }
            win.onStart = { [weak self, weak win] _ in
                let pairs = lastResults
                    .filter { $0.isValid && !$0.collides && $0.oldName != $0.newName }
                    .map { (old: $0.oldName, new: $0.newName) }
                guard !pairs.isEmpty else { return }
                self?.renameUndoLog = panel.performRenames(dir: dir, pairs: pairs)
                win?.enableUndo(true)
                Task { @MainActor in await panel.reload() }
            }
            win.onUndo = { [weak self, weak win] in
                guard let self else { return }
                panel.performUndo(self.renameUndoLog)
                self.renameUndoLog = []
                win?.enableUndo(false)
                Task { @MainActor in await panel.reload() }
            }
            win.onClose = { [weak win] in win?.close() }
            win.showWindow()
        }
    }

    private static func renameSpec(from v: MultiRenameWindowController.SpecValues) -> RenameSpec {
        let mode: RenameCase = [.unchanged, .lower, .upper, .firstUpper, .everyWord][max(0, min(4, v.caseModeIndex))]
        return RenameSpec(nameMask: v.nameMask, extMask: v.extMask, search: v.search, replace: v.replace,
                          useRegex: v.useRegex, caseSensitive: v.caseSensitive, repeatReplace: v.repeatReplace,
                          caseMode: mode, counterStart: v.counterStart, counterStep: v.counterStep,
                          counterDigits: v.counterDigits)
    }

    // MARK: - Network / FTP quick connect (I15, F-211)

    /// Ctrl+N / Net menu: prompt for an FTP URL, connect, and mount it in the
    /// active panel. Password (for non-anonymous logins) is prompted separately
    /// and never persisted here. SFTP/FTPS are handled once their transports land.
    func showQuickConnect() {
        let urlDialog = InputDialog(title: String(localized: "Connect to FTP Server"),
                                    prompt: String(localized: "URL (e.g. ftp://user@host/path):"),
                                    initialValue: "ftp://", okTitle: String(localized: "Connect"))
        var entered: String?
        urlDialog.onConfirm = { entered = $0 }
        urlDialog.runModalDialog()
        guard let urlString = entered?.trimmingCharacters(in: .whitespaces), !urlString.isEmpty else { return }

        guard let url = FtpURL.parse(urlString) else {
            presentInfo(String(localized: "Connect"), String(localized: "Could not parse that URL."))
            return
        }
        var password = url.password ?? ""
        let anonymous = url.user.isEmpty || url.user == "anonymous"
        if !anonymous && password.isEmpty {
            let pwDialog = InputDialog(title: String(localized: "Password"),
                                       prompt: String(localized: "Password for \(url.user)@\(url.host):"),
                                       initialValue: "", okTitle: "OK", secure: true)
            var pw: String?
            pwDialog.onConfirm = { pw = $0 }
            pwDialog.runModalDialog()
            guard let pw else { return }   // cancelled
            password = pw
        }
        // Proto handling (plain/implicit-FTPS vs. not-yet-supported explicit-FTPS/SFTP)
        // lives in connectToSite.
        connectToSite(url.toSite(), password: password)
    }

    /// Connect the active panel to a WebDAV server, mounted as a drive (Option 2

    /// Re-aggregate every enabled external plugin's contributions (menus, context,
    /// views — declared in its Info.plist, no plugin code run to decide presence)
    /// and its file-system adapters. Called at startup and whenever a plugin is
    /// enabled/disabled/removed, so the UI reflects exactly the active plugins.
    func loadExternalPlugins() {
        Task { @MainActor in
            await pluginManager.reload()   // scan the plugins dir (discovered is empty until this runs)
            let enabled = await pluginManager.enabledPlugins()
            ContributionRegistry.shared.removeAll()
            FileSystemPluginRegistry.shared.removeAll()
            for plugin in enabled {
                // Contribution behavior (any type) if the manifest declares any.
                if let dict = Self.infoPlist(atBundle: plugin.bundlePath) {
                    let parsed = ContributionParser.parse(infoPlist: dict).contributions
                    if !parsed.isEmpty, case .success(let lib) = PluginHost.openContribLibrary(plugin) {
                        ContributionRegistry.shared.register(pluginId: plugin.bundlePath,
                                                             contributions: parsed,
                                                             plugin: ContribPlugin(library: lib))
                    }
                }
                // File-system adapters (PFX). Keyed by bundlePath so a contributed
                // "connect" command can correlate to this plugin's connect facet.
                if plugin.manifest.type == .pfx, case .success(let lib) = PluginHost.openLibrary(plugin) {
                    FileSystemPluginRegistry.shared.register(
                        LoadedPFXPlugin(id: plugin.bundlePath, plugin: PFXPlugin(library: lib)))
                }
            }
            // PDX content-field plugins → extra panel columns (lazy per-file values).
            loadContentFieldPlugins(enabled)
            // PFX plugins may contribute drives — rebuild both bars now they exist.
            leftPanelController?.reloadDriveBar()
            rightPanelController?.reloadDriveBar()
        }
    }

    /// Build a fresh content-field registry from the enabled PDX plugins and push
    /// their fields to both panels as extra (lazy) columns. A new registry per call
    /// means disabling a plugin drops its columns.
    private func loadContentFieldPlugins(_ enabled: [DiscoveredPlugin]) {
        let registry = ContentFieldRegistry()
        registry.register(BuiltinContentProvider())   // builtin.name/size/extension/modified (F-157)
        var pluginFields: [ColumnSpec] = []
        var badgeField: String?
        // Content fields from any plugin that exports them, not only declared `pdx` bundles — the
        // same rule contributions have always followed. A lister that turns a .class into text can
        // also answer "what is this file's text", and the type gate was all that stopped the
        // decompiler taking part in the host's search (F-351). Plugins exporting nothing are skipped.
        for plugin in enabled {
            let opened = plugin.manifest.type == .pdx
                ? PluginHost.openLibrary(plugin)
                : PluginHost.openContentLibrary(plugin)
            guard case .success(let lib) = opened, lib.symbol("ContentGetSupportedField") != nil else { continue }
            guard let provider = try? PDXContentProvider(
                providerName: Self.pluginSlug(plugin.manifest.name), plugin: PDXPlugin(library: lib)) else { continue }
            registry.register(provider)
            // Full-text fields are for searching, never for a column: the value is a whole document,
            // and a table cell holding a decompiled class would be neither readable nor cheap.
            for f in provider.fields where !f.isFullText {
                let qid = "\(provider.providerName).\(f.id)"
                // Localize the column HEADER through the plugin bundle; the field
                // id (qid) stays English so saved column sets keep matching.
                let title = PluginTitleLocalizer.localize(f.title, bundlePath: plugin.bundlePath)
                pluginFields.append(ColumnSpec(fieldID: qid, title: title, width: 120))
                // A field can opt into a name-cell badge via unit "badge".
                if f.unit == "badge", badgeField == nil { badgeField = qid }
            }
        }
        contentFieldRegistry = registry
        availablePluginFields = pluginFields
        installNoteBridge(registry: registry)
        let resolve: (String, String) async -> String? = { fieldID, path in
            await registry.value(qualifiedID: fieldID, forFileAt: URL(fileURLWithPath: path)).display
        }
        for panel in [leftPanelController, rightPanelController].compactMap({ $0 }) {
            // A content-providing PFX mount (e.g. TaskManager) resolves its own
            // columns per virtual entry by path; fall back to the on-disk PDX
            // registry for local files.
            panel.tableView.contentValueProvider = { [weak panel] fieldID, path in
                if let pfx = await panel?.currentFileSystem as? PFXFileSystem,
                   let value = pfx.contentDisplay(fieldID: fieldID, path: path) {
                    return value
                }
                return await resolve(fieldID, path)
            }
            panel.tableView.badgeFieldID = badgeField
        }
        applyColumns()
    }

    /// Push the active panel's cursor path + directory to embedded plugin views
    /// (e.g. the Notes sidebar) so they follow the selection.
    func notifyPluginViews() {
        ViewContainerRegistry.shared.notifyViews(key: "cursorPath",
                                                 value: activePanel?.tableView.cursorItemFullPath() ?? "")
        ViewContainerRegistry.shared.notifyViews(key: "dir", value: cachedActiveCwd ?? "")
    }

    /// Every field the user may show as a column: built-ins + enabled plugin fields.
    func availableColumnFields() -> [ColumnSpec] { PanelColumn.allSpecs + availablePluginFields }

    /// Apply each panel's persisted column set (per side; falling back to the old
    /// global "default", then built-ins + plugin fields).
    private func applyColumns() {
        leftPanelController?.tableView.setColumns(columnSpecs(forSide: "left"))
        rightPanelController?.tableView.setColumns(columnSpecs(forSide: "right"))
    }

    private func columnSpecs(forSide side: String) -> [ColumnSpec] {
        let specs = loadColumnSet(name: side) ?? loadColumnSet(name: "default") ?? availableColumnFields()
        // Drop qualified columns that aren't available in the file-system context
        // (e.g. a mount's fields left in a saved set from before per-context
        // columns) so they don't render as blank. Built-ins (unqualified) pass.
        let known = Set(availableColumnFields().map(\.fieldID))
        return specs.filter { !$0.fieldID.contains(".") || known.contains($0.fieldID) }
    }

    // MARK: - Content mounts (PFX volumes that publish their own columns, e.g. TaskManager)

    /// The Name/Size/Date built-ins a content mount reuses (Size→a primary metric
    /// like MEM, Date→e.g. start time) plus the mount's own published fields — the
    /// column choices that belong to THIS mount's context (not the FS context).
    private func contentMountColumns(_ fs: PFXFileSystem) -> [ColumnSpec] {
        let builtins = PanelColumn.defaultSpecs.filter { ["name", "size", "date"].contains($0.fieldID) }
        let fields = fs.qualifiedContentFields.map { qf in
            ColumnSpec(fieldID: qf.qualifiedID, title: qf.field.title,
                       width: qf.field.defaultWidth > 0 ? qf.field.defaultWidth : 100,
                       alignment: qf.field.isRightAligned ? .right : .left)
        }
        return builtins + fields
    }

    /// A panel entered a content-providing PFX mount: apply the mount's OWN column
    /// context (a saved "mount:<qualifier>" set, else Name/Size/Date + its fields)
    /// — kept entirely separate from the file-system columns — and start the
    /// volatile auto-refresh. The mount's fields are NOT mixed into the FS picker.
    func panelDidEnterContentMount(_ fs: PFXFileSystem, panel: PanelController) {
        // Numeric fields (CPU/PID/threads/…) must sort by value, not lexically.
        panel.tableView.numericContentFields = Set(
            fs.qualifiedContentFields.filter { $0.field.isNumericSort }.map(\.qualifiedID))
        // A synchronous resolver so a content-column sort survives auto-refresh.
        panel.tableView.syncContentValue = { [weak panel] fieldID, path in
            (panel?.currentFileSystem as? PFXFileSystem)?.contentDisplay(fieldID: fieldID, path: path)
        }
        let specs = loadColumnSet(name: "mount:\(fs.contentQualifier)") ?? contentMountColumns(fs)
        panel.tableView.setColumns(specs)
        panel.startVolatileAutoRefresh()
    }

    /// A panel left a content mount: stop auto-refresh, drop the mount's sort/value
    /// wiring, and restore the panel's file-system columns.
    func panelDidLeaveContentMount(panel: PanelController) {
        panel.stopVolatileAutoRefresh()
        panel.tableView.numericContentFields = []
        panel.tableView.syncContentValue = nil
        let side = (panel === rightPanelController) ? "right" : "left"
        panel.tableView.setColumns(columnSpecs(forSide: side))
    }

    // MARK: - Per-context columns (header menu; F-024)

    /// The column context for `panel`: a content mount uses its own
    /// "mount:<qualifier>" set + fields; a local/other view uses the per-side set +
    /// the file-system fields. Keeps plugin and FS columns from mixing.
    func columnContext(for panel: PanelController) -> (id: String, available: [ColumnSpec]) {
        if let fs = panel.currentFileSystem as? PFXFileSystem, !fs.contentFields.isEmpty {
            return ("mount:\(fs.contentQualifier)", contentMountColumns(fs))
        }
        let side = (panel === rightPanelController) ? "right" : "left"
        return (side, availableColumnFields())
    }

    /// (available fields, currently shown) for `panel`'s header column menu.
    func columnsMenu(for panel: PanelController) -> (available: [ColumnSpec], current: [ColumnSpec]) {
        (columnContext(for: panel).available, panel.tableView.currentColumns())
    }

    /// Toggle a column on/off in `panel`'s current context (from the header menu),
    /// persisting the change to that context only.
    func toggleColumn(_ fieldID: String, panel: PanelController) {
        let ctx = columnContext(for: panel)
        var current = panel.tableView.currentColumns()
        if let idx = current.firstIndex(where: { $0.fieldID == fieldID }) {
            guard current.count > 1 else { return }   // never hide the last column
            current.remove(at: idx)
        } else if let spec = ctx.available.first(where: { $0.fieldID == fieldID }) {
            current.append(spec)
        }
        saveColumnSet(current, forContext: ctx.id, panel: panel)
    }

    /// Open the column configuration dialog for `panel`'s current context.
    func configureColumns(panel: PanelController) {
        let ctx = columnContext(for: panel)
        let current = panel.tableView.currentColumns()
        let label = ctx.id.hasPrefix("mount:") ? String(ctx.id.dropFirst("mount:".count))
                    : (ctx.id == "right" ? "Right" : "Left")
        let win = ColumnsConfigWindowController(available: ctx.available, current: current, sideLabel: label)
        columnsWindow = win
        win.onApply = { [weak self] specs in self?.saveColumnSet(specs, forContext: ctx.id, panel: panel) }
        win.onClose = { [weak self] in self?.columnsWindow = nil }
        win.showWindow()
    }

    /// Persist `specs` under column context `id` and apply them to `panel`.
    func saveColumnSet(_ specs: [ColumnSpec], forContext id: String, panel: PanelController) {
        let text = (try? String(contentsOf: configPaths.columns, encoding: .utf8)) ?? ""
        var doc = INIDocument(parsing: text)
        ColumnSetStore.save([ColumnSet(name: id, columns: specs)], into: &doc)
        try? doc.serialized().write(to: configPaths.columns, atomically: true, encoding: .utf8)
        panel.tableView.setColumns(specs)
        panel.refreshComments()   // fill a freshly-added Comment column
    }

    // MARK: - Process tree (content mounts exposing pid + ppid, e.g. TaskManager)

    /// The active panel's filesystem when it's a content mount that models a
    /// process hierarchy (publishes both "pid" and "ppid" fields), else nil —
    /// the gate for the "Show Process Tree" context-menu item.
    var activePanelProcessMount: PFXFileSystem? {
        guard let fs = activePanel?.currentFileSystem as? PFXFileSystem else { return nil }
        let ids = Set(fs.contentFields.map(\.name))
        return (ids.contains("pid") && ids.contains("ppid")) ? fs : nil
    }

    /// The PID encoded in a TaskManager entry name "<name> (<pid>)".
    private static func pid(fromEntryName name: String?) -> Int? {
        guard let name, let open = name.lastIndex(of: "(") else { return nil }
        let inner = name[name.index(after: open)...].prefix { $0.isNumber }
        return Int(inner)
    }

    /// Build the process forest from the active mount and show the tree window,
    /// expanded to the process named by `cursorEntryName`.
    func showProcessTree(cursorEntryName: String?) {
        guard let fs = activePanelProcessMount else { NSSound.beep(); return }
        let qualifier = fs.contentQualifier
        let focus = Self.pid(fromEntryName: cursorEntryName)
        Task { @MainActor in
            var procs: [ProcessTreeWindowController.ProcInfo] = []
            do {
                for try await batch in fs.list(VFSPath(filesystemId: fs.scheme, path: "/")) {
                    for e in batch.entries {
                        guard let pid = Self.pid(fromEntryName: e.name) else { continue }
                        let path = "/" + e.name
                        let ppid = Int(fs.contentDisplay(fieldID: "\(qualifier).ppid", path: path) ?? "") ?? 0
                        let cpu = fs.contentDisplay(fieldID: "\(qualifier).cpu", path: path) ?? ""
                        procs.append(.init(pid: pid, ppid: ppid, name: e.name, cpu: cpu, rss: e.size))
                    }
                }
            } catch {
                logger.error("process tree: listing failed: \(error)")
                return
            }
            guard !procs.isEmpty else { NSSound.beep(); return }
            let win = ProcessTreeWindowController(processes: procs, focusPid: focus)
            win.onReveal = { [weak self] name in
                guard let self else { return }
                self.window?.makeKeyAndOrderFront(nil)
                self.activePanel?.tableView.focusEntry(named: name)
            }
            processTreeWindow = win
            win.present()
        }
    }

    /// Prompt for a port number, ask the mount which process owns it, and jump the
    /// panel cursor there. Auto-refresh is paused around the lookup so it can't
    /// rebuild the snapshot mid-scan.
    func findProcessByPort() {
        guard let fs = activePanelProcessMount, let panel = activePanel else { NSSound.beep(); return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Find Process by Port")
        alert.informativeText = String(localized: "Enter a TCP/UDP port number to locate the process using it.")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = "8080"
        alert.accessoryView = field
        alert.addButton(withTitle: String(localized: "Search"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.window.initialFirstResponder = field

        panel.stopVolatileAutoRefresh()
        defer { panel.startVolatileAutoRefresh() }
        guard alert.runModal() == .alertFirstButtonReturn,
              let port = Int(field.stringValue.trimmingCharacters(in: .whitespaces)),
              port > 0, port <= 65535 else { return }
        guard let hit = fs.lookup(query: "port:\(port)") else {
            presentInfo(String(localized: "No Process Found"),
                        String(format: String(localized: "No accessible process is using port %d. System ports may need elevated privileges."), port))
            return
        }
        let name = hit.hasPrefix("/") ? String(hit.dropFirst()) : hit
        panel.tableView.focusEntry(named: name)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Persisted column set named `name`, or nil if none saved.
    private func loadColumnSet(name: String) -> [ColumnSpec]? {
        let text = (try? String(contentsOf: configPaths.columns, encoding: .utf8)) ?? ""
        guard !text.isEmpty else { return nil }
        let set = ColumnSetStore.load(from: INIDocument(parsing: text)).first { $0.name == name }
        return set.flatMap { $0.columns.isEmpty ? nil : $0.columns }
    }

    /// Open the column-configuration dialog for the active panel (Configuration ▸
    /// Columns…). Context-aware: on a content mount it edits that mount's columns,
    /// otherwise the panel's file-system columns.
    func showColumnsConfig() {
        guard let panel = activePanel ?? leftPanelController else { return }
        configureColumns(panel: panel)
    }

    /// Slug a plugin name into a content-field provider namespace ("Git" → "git").
    static func pluginSlug(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    /// Read a plugin bundle's Info.plist as a dictionary.
    static func infoPlist(atBundle bundlePath: String) -> [String: Any]? {
        let url = URL(fileURLWithPath: bundlePath).appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return dict
    }

    /// Connect the active panel to an FTP site (shared by quick-connect and the
    /// connection manager). Explicit FTPS and SFTP are not live yet.
    func connectToSite(_ site: FtpSite, password: String) {
        switch site.proto {
        case .ftp, .ftpsImplicit:
            break
        case .ftps:
            presentInfo(String(localized: "Connect"),
                        String(localized: "Explicit FTPS (AUTH TLS) is not supported yet. Use implicit FTPS or plain ftp://."))
            return
        case .sftp:
            let sftpUser = site.user.isEmpty ? NSUserName() : site.user
            let keyFile = site.auth == .keyFile ? site.keyFile : nil
            Task { @MainActor in
                do {
                    let sftp = SFTPSession()
                    try await sftp.connect(host: site.host, port: UInt16(site.port), user: sftpUser,
                                           password: password.isEmpty ? nil : password,
                                           keyFile: keyFile, keyPassphrase: nil)
                    let fs = SFTPFileSystem(session: sftp, fsID: "sftp:\(site.host)",
                                            transferViaSCP: site.useSCP)
                    await self.activePanel?.enterNetwork(fs, startPath: site.remoteDir)
                } catch {
                    self.presentInfo(String(localized: "Connection failed"),
                                     String(localized: "Could not connect to \(site.host): \(String(describing: error))"))
                }
            }
            return
        }
        let useTLS = site.proto == .ftpsImplicit
        let anonymous = site.auth == .anonymous || site.user.isEmpty || site.user == "anonymous"
        let user = anonymous ? "anonymous" : site.user
        let pass = anonymous && password.isEmpty ? "anonymous@" : password
        Task { @MainActor in
            do {
                let nwTransport = NWFTPControlTransport(host: site.host, port: site.port, useTLS: useTLS,
                                                      allowInsecureTLS: site.allowInsecureTLS,
                                                      proxy: site.proxyConfig)   // F-212 SOCKS5 proxy
                // Wrap the transport so all control traffic is captured for the
                // FTP console / protocol log (F-217).
                let protocolLog = FTPProtocolLog()
                let transport = LoggingFTPControlTransport(nwTransport, log: protocolLog)
                let connection = FTPControlConnection(transport: transport, controlHost: site.host)
                if !site.passive { await connection.setActiveMode(true) }   // F-212 (site's passive/active toggle)
                try await connection.connectAndLogin(user: user, password: pass, protectData: useTLS)
                // Keep an idle control connection alive (Options → FTP default,
                // overridden per-site). Enforces the previously-inert keepalive config.
                let interval = site.effectiveKeepAlive(globalDefault: self.ftpKeepAliveSeconds)
                if interval > 0 {
                    await connection.startKeepAlive(intervalSeconds: interval,
                                                    command: site.keepAliveCommand ?? "NOOP")
                }
                let ftpFS = FTPFileSystem(connection: connection, fsID: "ftp:\(site.host)", protocolLog: protocolLog)
                await self.activePanel?.enterNetwork(ftpFS, startPath: site.remoteDir)
            } catch {
                self.presentInfo(String(localized: "Connection failed"),
                                 String(localized: "Could not connect to \(site.host): \(String(describing: error))"))
            }
        }
    }

    /// Native Quick Look (Cmd+Y) for the selected/cursor local files. cm_QuickLook.
    func showQuickLook() {
        guard let panel = activePanel, !panel.isInArchive else { NSSound.beep(); return }
        var paths = panel.tableView.selectedFilePaths()
        if paths.isEmpty, let cursor = panel.tableView.cursorItemFullPath() { paths = [cursor] }
        guard !paths.isEmpty else { return }
        quickLook.show(paths)
    }

    /// Open the FTP console for the active panel's FTP session: a live raw-protocol
    /// log plus a field to send custom commands (F-217). cm_FtpRawCommand.
    func showFtpConsole() {
        guard let ftp = activePanel?.currentFileSystem as? FTPFileSystem, let log = ftp.protocolLog else {
            presentInfo(String(localized: "FTP Console"),
                        String(localized: "Open an FTP connection first (the active panel must be browsing an FTP site)."))
            return
        }
        let console = FTPConsoleWindowController(fs: ftp, log: log)
        ftpConsole = console
        console.present()
    }
    private var ftpConsole: FTPConsoleWindowController?

    private var downloadDialog: DownloadURLWindowController?

    /// wget-style download of an HTTP/HTTPS URL into the active panel's folder
    /// (F-330). Runs as a background transfer with resume via a ".part" file.
    func showDownloadFromURL() {
        guard let panel = activePanel, panel.currentFileSystem is LocalFS, !panel.isInArchive else {
            presentInfo(String(localized: "Download from URL"),
                        String(localized: "Switch the active panel to a local folder first."))
            return
        }
        // Pre-fill from the clipboard when it holds an http(s) link.
        let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let prefill = (clip.hasPrefix("http://") || clip.hasPrefix("https://")) ? clip : ""
        let dialog = DownloadURLWindowController(prefillURL: prefill)
        downloadDialog = dialog
        dialog.onStart = { [weak self] batch in
            Task { @MainActor in
                guard let self else { return }
                let dir = await panel.getCurrentPath()
                let opts = HTTPDownloadOptions(
                    username: batch.username.isEmpty ? nil : batch.username,
                    password: batch.password.isEmpty ? nil : batch.password,
                    extraHeaders: batch.headers,
                    allowInsecureTLS: batch.allowInsecureTLS,
                    proxy: batch.proxy)
                for url in batch.urls {
                    let name = (batch.urls.count == 1 ? batch.singleFileName : nil) ?? DownloadName.suggested(fromURL: url)
                    self.enqueueURLDownload(url: url, name: DownloadName.sanitize(name), into: dir,
                                            options: opts,
                                            expectedSHA256: batch.urls.count == 1 ? batch.expectedSHA256 : nil,
                                            held: batch.queueForLater)
                }
            }
        }
        dialog.runModalDialog()
    }

    /// Resolve a collision-safe destination and enqueue an HTTP download as a
    /// (optionally held) background transfer-manager job — progress + cancel, a
    /// ".part" enables resume, and an optional SHA-256 is verified on completion (F-330).
    func enqueueURLDownload(url: String, name rawName: String, into dir: String,
                            options: HTTPDownloadOptions, expectedSHA256: String?, held: Bool) {
        let fm = FileManager.default
        // Keep the chosen name when a ".part" is present (resume); otherwise avoid
        // clobbering an already-complete file by finding a free "name (n)".
        var name = rawName
        let base = (dir as NSString).appendingPathComponent(name)
        if !fm.fileExists(atPath: base + ".part"), fm.fileExists(atPath: base) {
            let ext = (name as NSString).pathExtension
            let stem = (name as NSString).deletingPathExtension
            var n = 2
            while fm.fileExists(atPath: (dir as NSString).appendingPathComponent(
                    ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)")) { n += 1 }
            name = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
        }
        let destPath = (dir as NSString).appendingPathComponent(name)
        let speed = DownloadSpeedMeter()
        let expected = expectedSHA256?.lowercased()

        TransferManager.shared.enqueue(.custom(run: { control, progress in
            let result = try await HTTPDownloader().download(
                urlString: url, to: destPath, options: options,
                progress: { done, total in
                    progress(OpProgress(filesTotal: 1, filesDone: 0,
                                        bytesTotal: max(0, total), bytesDone: done,
                                        currentItem: name, bytesPerSecond: speed.rate(bytes: done)))
                },
                checkpoint: { try await control.checkpoint() })
            // Optional integrity check (F-330): mismatched files are removed + reported.
            if let expected {
                let actual = Self.sha256OfFile(result.path)
                if actual != expected {
                    try? FileManager.default.removeItem(atPath: result.path)
                    throw NSError(domain: "PeachCommander.Download", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: String(localized: "SHA-256 mismatch for \(name): expected \(expected), got \(actual)")])
                }
            }
            return []
        }), title: String(localized: "Download \(name)"), startHeld: held,
            onComplete: { [weak self] _ in Task { @MainActor in await self?.activePanel?.reload() } })
        showTransferManager()
    }

    /// Stream a local file through the SHA-256 hasher (lowercase hex).
    private static func sha256OfFile(_ path: String) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else { return "" }
        defer { try? handle.close() }
        let hasher = ChecksumHasher(.sha256)
        while case let chunk = handle.readData(ofLength: 1 << 20), !chunk.isEmpty {
            hasher.update(chunk)
        }
        return hasher.finalizeHex()
    }

    /// Open the FTP connection manager (saved sites). cm_FtpConnect.
    func showFtpConnect() {
        let store = KeychainSecretStore()
        let sitesURL = configPaths.ftpSites
        let editor = FtpConnectionManagerWindowController(sitesURL: sitesURL, store: store)
        editor.onConnect = { [weak self] site, password in self?.connectToSite(site, password: password) }
        ftpConnectWC = editor
        editor.present()
    }

    /// cm_FtpDisconnect: leave the active panel's FTP/SFTP mount and tear the
    /// connection down.
    func disconnectActivePanelNetwork() {
        Task { @MainActor in await activePanel?.leaveNetworkMount() }
    }

    // MARK: - Import wincmd.ini (F-276)

    func showImportWincmd() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Import wincmd.ini")
        panel.message = String(localized: "Choose a Total Commander wincmd.ini to import (hotlist, button bar, FTP sites).")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let iniType = UTType(filenameExtension: "ini") { panel.allowedContentTypes = [iniType] }
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            presentInfo(String(localized: "Import wincmd.ini"),
                        String(localized: "The file could not be read."))
            return
        }
        let result = WincmdImporter.importAll(iniText: text, sourceURL: url)
        // TC keeps FTP sites in wcx_ftp.ini beside wincmd.ini, not in wincmd.ini itself.
        var ftpSites: [FtpSite] = []
        let ftpURL = url.deletingLastPathComponent().appendingPathComponent("wcx_ftp.ini")
        if let ftpText = try? String(contentsOf: ftpURL, encoding: .utf8) {
            ftpSites = WincmdFtpImporter.parse(ftpText)
        }
        Task { @MainActor in
            let message = await self.applyWincmdImport(result, ftpSites: ftpSites)
            self.presentInfo(String(localized: "Import wincmd.ini"), message)
        }
    }

    /// Apply an import to the (isolated) config, returning a human summary. Hotlist
    /// and FTP sites are merged (existing entries kept); the button bar is replaced
    /// after backing up the current one to `.bak`. Colors are not imported.
    private func applyWincmdImport(_ result: WincmdImportResult, ftpSites: [FtpSite]) async -> String {
        var lines: [String] = []

        // Hotlist — merge, skipping paths already bookmarked.
        var addedHot = 0
        for entry in result.hotlistEntries where !hotlist.contains(path: entry.path) {
            hotlist.add(title: entry.title, path: entry.path)
            addedHot += 1
        }
        if addedHot > 0 { await persistHotlist() }
        lines.append(String(localized: "Hotlist: \(addedHot) bookmark(s) added."))

        // Button bar — replace, backing up the current bar first.
        if let bar = result.buttonBar {
            let barURL = configPaths.buttonBar
            if FileManager.default.fileExists(atPath: barURL.path) {
                let backup = barURL.appendingPathExtension("bak")
                try? FileManager.default.removeItem(at: backup)
                try? FileManager.default.copyItem(at: barURL, to: backup)
            }
            try? bar.serialize().write(to: barURL, atomically: true, encoding: .utf8)
            loadButtonBar()
            lines.append(String(localized: "Button bar: \(bar.buttons.count) button(s) imported (previous saved as .bak)."))
        } else if result.buttonBarReference != nil {
            lines.append(String(localized: "Button bar: referenced .bar file not found next to wincmd.ini — skipped."))
        } else {
            lines.append(String(localized: "Button bar: none found."))
        }

        // FTP sites — merge into ftp-sites.ini, skipping existing names. No passwords.
        if !ftpSites.isEmpty {
            let sitesURL = configPaths.ftpSites
            let existingText = (try? String(contentsOf: sitesURL, encoding: .utf8)) ?? ""
            var sites = FtpSitesFile.parse(existingText)
            let existingNames = Set(sites.map { $0.name.lowercased() })
            var addedFtp = 0
            for site in ftpSites where !existingNames.contains(site.name.lowercased()) {
                sites.append(site)
                addedFtp += 1
            }
            if addedFtp > 0 {
                try? FtpSitesFile.serialize(sites).write(to: sitesURL, atomically: true, encoding: .utf8)
            }
            lines.append(String(localized: "FTP: \(addedFtp) site(s) added (re-enter passwords on connect)."))
        }

        if result.colorsPresent {
            lines.append(String(localized: "Colors were not imported (no configurable palette yet)."))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Checksums (I17-T04)

    func showCreateChecksums() {
        guard let panel = activePanel else { return }
        let algos: [ChecksumAlgorithm] = [.crc32, .md5, .sha1, .sha256, .sha512]
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 26))
        popup.addItems(withTitles: [
            String(localized: "CRC32 (.sfv)"), "MD5", "SHA-1", "SHA-256", "SHA-512"])
        popup.selectItem(at: algos.firstIndex(of: .sha256) ?? 0)
        let alert = NSAlert()
        alert.messageText = String(localized: "Create Checksum(s)")
        alert.informativeText = String(localized: "Choose an algorithm, then where to put the result.")
        alert.accessoryView = popup
        alert.addButton(withTitle: String(localized: "Save…"))
        alert.addButton(withTitle: String(localized: "Copy to Clipboard"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        let resp = alert.runModal()
        guard resp == .alertFirstButtonReturn || resp == .alertSecondButtonReturn else { return }
        let algo = algos[max(0, popup.indexOfSelectedItem)]
        let toClipboard = (resp == .alertSecondButtonReturn)
        Task { @MainActor in
            guard let r = await panel.checksumText(algorithm: algo) else {
                self.presentInfo(String(localized: "Create Checksum(s)"),
                                 String(localized: "Select one or more files first."))
                return
            }
            if toClipboard { self.copyStringToClipboard(r.text) }
            else { self.saveText(r.text, suggestedName: r.suggestedName, directory: r.directory) }
        }
    }

    // MARK: - Output-target helpers (save / clipboard / print), shared by the
    // checksum, encode and file-list commands.

    /// Encoded/exported text larger than this is impractical on the pasteboard;
    /// steer the user to "Save…" instead.
    private static let clipboardTextLimit = 20 * 1024 * 1024

    /// Present a save panel pre-filled with `suggestedName` (defaulting into
    /// `directory` when it is a real local folder) and write `text` there.
    private func saveText(_ text: String, suggestedName: String, directory: String?) {
        let sp = NSSavePanel()
        sp.nameFieldStringValue = suggestedName
        sp.canCreateDirectories = true
        if let directory, FileManager.default.fileExists(atPath: directory) {
            sp.directoryURL = URL(fileURLWithPath: directory)
        }
        sp.begin { [weak self] resp in
            guard resp == .OK, let url = sp.url else { return }
            do { try Data(text.utf8).write(to: url) }
            catch { self?.presentInfo(String(localized: "Save Failed"), error.localizedDescription) }
        }
    }

    private func copyStringToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// True if `text` was copied; false (and an alert shown) if it exceeds the limit.
    @discardableResult
    private func copyStringToClipboardGuarded(_ text: String, context: String) -> Bool {
        guard text.utf8.count <= Self.clipboardTextLimit else {
            presentInfo(context, String(localized: "The result is too large for the clipboard — use Save instead."))
            return false
        }
        copyStringToClipboard(text)
        return true
    }

    private func printPlainText(_ text: String) {
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
        tv.string = text
        tv.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        tv.isEditable = false
        let op = NSPrintOperation(view: tv)
        op.printInfo.orientation = .landscape
        op.run()
    }

    func showVerifyChecksums() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            guard let out = await panel.verifyChecksumsUnderCursor() else {
                self.presentInfo(String(localized: "Verify Checksums"),
                                 String(localized: "Put the cursor on a checksum file (.sfv/.md5/.sha256…)."))
                return
            }
            var ok = 0, failed = 0, missing = 0
            for r in out.results {
                switch r.status {
                case .ok: ok += 1
                case .mismatch: failed += 1
                case .unreadable: missing += 1
                }
            }
            self.presentInfo(String(localized: "Verify Checksums"),
                             String(localized: "\(out.fileName): \(ok) OK, \(failed) failed, \(missing) missing."))
        }
    }

    // MARK: - Image info (I16-T04)

    func showImageInfo() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            guard let r = await panel.cursorImageInfo() else {
                self.presentInfo(String(localized: "Image Info"), String(localized: "Put the cursor on an image file."))
                return
            }
            var detail = "\(r.info.dimensionsText) px"
            if let cm = r.info.colorModel { detail += ", \(cm)" }
            if let dpi = r.info.dpi { detail += ", \(dpi) dpi" }
            self.presentInfo(String(localized: "Image Info — \(r.name)"), detail)
        }
    }

    // MARK: - Create link (I17-T12)

    func showCreateSymlink() { createLink(kind: .symbolic, title: String(localized: "Create Symbolic Link"), suffix: " link") }
    func showCreateHardlink() { createLink(kind: .hard, title: String(localized: "Create Hard Link"), suffix: " link") }
    func showCreateAlias() { createLink(kind: .alias, title: String(localized: "Create Alias"), suffix: " alias") }

    private func createLink(kind: LinkKind, title: String, suffix: String) {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            guard let targetName = await panel.cursorItemName() else {
                self.presentInfo(title, String(localized: "Put the cursor on a local file or folder."))
                return
            }
            let dialog = InputDialog(title: title, prompt: String(localized: "Link name:"),
                                     initialValue: targetName + suffix, okTitle: String(localized: "Create"))
            var entered: String?
            dialog.onConfirm = { entered = $0 }
            dialog.runModalDialog()
            guard let name = entered?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }
            let ok = await panel.createLink(kind: kind, name: name)
            if !ok {
                self.presentInfo(title, String(localized: "Could not create the link (does it already exist?)."))
            }
        }
    }

    // MARK: - Branch view (I17-T06)

    func showBranchView() { runBranchView(selectedOnly: false) }
    func showBranchViewSelected() { runBranchView(selectedOnly: true) }

    private func runBranchView(selectedOnly: Bool) {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            if await panel.enterBranchView(selectedOnly: selectedOnly) == nil {
                self.presentInfo(String(localized: "Branch View"),
                                 selectedOnly ? String(localized: "Select folders or files first.")
                                              : String(localized: "This folder has no files."))
            }
        }
    }

    // MARK: - Print / export file list (I17-T10)

    // Both cm_ExportFileList and cm_PrintFileList now open one unified dialog that
    // lets the user save, copy to the clipboard, or print the listing.
    func showExportFileList() { showFileListDialog() }
    func showPrintFileList() { showFileListDialog() }

    func showFileListDialog() {
        guard let panel = activePanel else { return }
        let rows = panel.fileListRows(namesFilter: nil)
        guard !rows.isEmpty else {
            presentInfo(String(localized: "File List"), String(localized: "The folder has no entries."))
            return
        }
        let formats: [FileListFormat] = [.tsv, .csv, .plain]
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 26))
        popup.addItems(withTitles: [
            String(localized: "Tab-separated (.txt)"),
            String(localized: "CSV (.csv)"),
            String(localized: "Names only (.txt)")])
        let alert = NSAlert()
        alert.messageText = String(localized: "File List")
        alert.informativeText = String(localized: "Choose a format and destination.")
        alert.accessoryView = popup
        alert.addButton(withTitle: String(localized: "Save…"))
        alert.addButton(withTitle: String(localized: "Copy to Clipboard"))
        alert.addButton(withTitle: String(localized: "Print"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        let resp = alert.runModal()
        let fmt = formats[max(0, min(popup.indexOfSelectedItem, formats.count - 1))]
        let text = panel.fileListText(format: fmt)
        let ext = (fmt == .csv) ? "csv" : "txt"
        switch resp {
        case .alertFirstButtonReturn:
            Task { @MainActor in
                let dir = await panel.currentDirectoryIfLocal()
                self.saveText(text, suggestedName: "filelist.\(ext)", directory: dir)
            }
        case .alertSecondButtonReturn:
            copyStringToClipboardGuarded(text, context: String(localized: "File List"))
        case .alertThirdButtonReturn:
            printPlainText(text)
        default:
            break   // Cancel (fourth button)
        }
    }


    // MARK: - Comments (I17-T09)

    func showEditComment() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            guard let ctx = await panel.cursorCommentContext() else {
                self.presentInfo(String(localized: "Edit Comment"), String(localized: "Put the cursor on a file."))
                return
            }
            let dialog = InputDialog(title: String(localized: "Edit Comment"),
                                     prompt: String(localized: "Comment for \(ctx.name):"),
                                     initialValue: ctx.current, okTitle: String(localized: "Save"))
            var entered: String?
            dialog.onConfirm = { entered = $0 }
            dialog.runModalDialog()
            guard let text = entered else { return }   // cancelled
            _ = await panel.setCursorComment(text)
        }
    }

    // MARK: - Change attributes (I17-T01)

    func showChangeAttributes() {
        guard let panel = activePanel else { return }
        // Seed the checkboxes from the cursor item's current permissions (else 644).
        var startMode: UInt16 = 0o644
        let cursorPath = panel.tableView.cursorItemFullPath()
        if let path = cursorPath,
           let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let n = attrs[.posixPermissions] as? NSNumber {
            startMode = UInt16(truncating: n) & 0o7777
        }
        let dialog = AttributesDialog(permissions: PosixPermissions(mode: startMode), path: cursorPath)
        dialog.onApply = { [weak self] change in
            Task { @MainActor in
                let perms = PosixPermissions(mode: change.mode)
                if let r = await panel.changeAttributes(mode: change.mode, recursive: change.recursive,
                                                         bsdFlags: change.bsdFlags, modified: change.modified,
                                                         ownerName: change.ownerName, groupName: change.groupName) {
                    let failedNote = r.failed > 0 ? String(localized: ", \(r.failed) failed") : ""
                    self?.presentInfo(String(localized: "Change Attributes"),
                                      String(localized: "Set \(perms.symbolic) on \(r.changed) item(s)\(failedNote)."))
                    // Only for local files: the privileged retry runs /bin/chmod on the *host*, so on
                    // an SFTP or FTP mount it would either fail or, worse, hit a same-named local path.
                    // Unreachable until now only because those filesystems silently reported success
                    // (F-364), which is exactly the kind of bug a silent success hides.
                    if r.failed > 0, panel.currentFileSystem is LocalFS {
                        await self?.offerPrivilegedChmod(mode: change.mode, recursive: change.recursive, panel: panel)
                    }
                } else {
                    self?.presentInfo(String(localized: "Change Attributes"), String(localized: "Select files or folders first."))
                }
            }
        }
        attributesDialog = dialog
        dialog.runModalDialog()
    }

    /// After a chmod partially failed (permission denied), offer to retry the
    /// change with administrator privileges (F-099).
    private func offerPrivilegedChmod(mode: UInt16, recursive: Bool, panel: PanelController) async {
        let targets = await panel.selectedOrCursorPaths()
        guard !targets.isEmpty else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Retry as administrator?")
        alert.informativeText = String(localized: "Some items could not be changed (permission denied). Retry setting the permissions with administrator privileges?")
        alert.addButton(withTitle: String(localized: "Retry as Administrator"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let flag = recursive ? "-R " : ""
        let octal = String(mode, radix: 8)
        let quoted = targets.map { PrivilegedRunner.shellQuote($0) }.joined(separator: " ")
        let command = "/bin/chmod \(flag)\(octal) \(quoted)"
        if let error = PrivilegedRunner.runShell(command) {
            presentInfo(String(localized: "Administrator Operation Failed"), error)
        } else {
            presentInfo(String(localized: "Change Attributes"),
                        String(localized: "Permissions applied with administrator privileges."))
        }
        await panel.reload()
    }

    // MARK: - Occupied space (I17-T11)

    func showOccupiedSpace() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            guard let s = await panel.occupiedSpace() else {
                self.presentInfo(String(localized: "Occupied Space"),
                                 String(localized: "Available for local files and folders only."))
                return
            }
            let size = ByteSize(s.bytes)
            let detail = String(localized: "\(size.formatted(style: .bytesWithSep)) — \(size.formatted(style: .mb))\nin \(s.files) file(s) and \(s.folders) folder(s).")
            self.presentInfo(String(localized: "Occupied Space"), detail)
        }
    }

    // MARK: - Split / Combine (I17-T02)

    func showSplitFile() {
        guard let panel = activePanel else { return }
        let dialog = InputDialog(title: String(localized: "Split File"),
                                 prompt: String(localized: "Part size (e.g. 10M, 700M, 1G):"),
                                 initialValue: "10M", okTitle: String(localized: "Split"))
        var entered: String?
        dialog.onConfirm = { entered = $0 }
        dialog.runModalDialog()
        guard let text = entered else { return }
        guard let size = ByteSize.parse(text), size > 0 else {
            presentInfo(String(localized: "Split File"), String(localized: "Invalid part size."))
            return
        }
        Task { @MainActor in
            if let r = await panel.splitCursorFile(partSize: size) {
                self.presentInfo(String(localized: "Split File"), String(localized: "Split \(r.name) into \(r.parts) part(s)."))
            } else {
                self.presentInfo(String(localized: "Split File"), String(localized: "Put the cursor on a file to split."))
            }
        }
    }

    func showCombineFiles() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            guard let r = await panel.combineFromCursor() else {
                self.presentInfo(String(localized: "Combine Files"), String(localized: "Put the cursor on a .crc or .001 part file."))
                return
            }
            let status = r.crcOK ? String(localized: "CRC OK") : String(localized: "CRC MISMATCH")
            self.presentInfo(String(localized: "Combine Files"), String(localized: "Rebuilt \(r.name) — \(status)."))
        }
    }

    // MARK: - Encode / Decode (I17-T03)

    /// Text encodings offered by the Encode File command.
    enum FileEncodingScheme: CaseIterable {
        case base64, hex, uuencode, xxencode
        var title: String {
            switch self {
            case .base64: return "Base64"
            case .hex: return String(localized: "Hex")
            case .uuencode: return "uuencode"
            case .xxencode: return "xxencode"
            }
        }
        var ext: String {
            switch self { case .base64: return "b64"; case .hex: return "hex"
                          case .uuencode: return "uue"; case .xxencode: return "xxe" }
        }
        func encode(_ data: Data, filename: String) -> String {
            switch self {
            case .base64: return Base64Codec.encode(data, wrap: true)
            case .hex: return data.map { String(format: "%02x", $0) }.joined()
            case .uuencode: return UUCodec.encode(data, variant: .uu, filename: filename)
            case .xxencode: return UUCodec.encode(data, variant: .xx, filename: filename)
            }
        }
    }

    func showEncodeFile() {
        guard let panel = activePanel else { return }
        let schemes = FileEncodingScheme.allCases
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 26))
        popup.addItems(withTitles: schemes.map(\.title))
        let alert = NSAlert()
        alert.messageText = String(localized: "Encode File")
        alert.informativeText = String(localized: "Choose an encoding, then where to put the result.")
        alert.accessoryView = popup
        alert.addButton(withTitle: String(localized: "Save…"))
        alert.addButton(withTitle: String(localized: "Copy to Clipboard"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        let resp = alert.runModal()
        guard resp == .alertFirstButtonReturn || resp == .alertSecondButtonReturn else { return }
        let scheme = schemes[max(0, popup.indexOfSelectedItem)]
        let toClipboard = (resp == .alertSecondButtonReturn)
        Task { @MainActor in
            guard let file = await panel.cursorFileData() else {
                self.presentInfo(String(localized: "Encode File"), String(localized: "Put the cursor on a file to encode."))
                return
            }
            let text = scheme.encode(file.data, filename: file.name)
            if toClipboard {
                self.copyStringToClipboardGuarded(text, context: String(localized: "Encode File"))
            } else {
                self.saveText(text, suggestedName: "\(file.name).\(scheme.ext)", directory: file.directory)
            }
        }
    }

    func showDecodeFile() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            if let name = await panel.decodeCursorBase64() {
                self.presentInfo(String(localized: "Decode (Base64)"), String(localized: "Wrote \(name)."))
            } else {
                self.presentInfo(String(localized: "Decode (Base64)"), String(localized: "Put the cursor on a valid Base64 file."))
            }
        }
    }

    // MARK: - Duplicate finder (I17-T05)

    func showFindDuplicates() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            guard let r = await panel.findDuplicateGroups() else {
                self.presentInfo(String(localized: "Find Duplicates"), String(localized: "No files to scan here."))
                return
            }
            guard !r.groups.isEmpty else {
                self.presentInfo(String(localized: "Find Duplicates"), String(localized: "No duplicate files found."))
                return
            }
            let win = DuplicateFinderWindowController(groups: r.groups, canDelete: r.isLocal)
            win.onReveal = { [weak self] path in
                self?.window?.makeKeyAndOrderFront(nil)
                self?.contribOpenPath(path)
            }
            win.onDelete = { [weak self] paths in
                await self?.deleteDuplicatePaths(paths)
            }
            self.duplicateWindow = win
            win.present()
        }
    }

    /// Move duplicate files to the Trash and refresh the panels (used by the
    /// Duplicate Files window). Local files only.
    private func deleteDuplicatePaths(_ paths: [String]) async {
        let urls = paths.map { URL(fileURLWithPath: $0) }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            NSWorkspace.shared.recycle(urls) { _, _ in cont.resume() }
        }
        await leftPanelController?.reload()
        await rightPanelController?.reload()
    }

    // MARK: - Undo last operation (F-101)

    /// Record an inverse for the last file operation. `run` should restore the
    /// prior state (move back / rename back / trash the just-created items).
    func pushUndo(_ label: String, _ run: @escaping () async -> Void) {
        undoStack.append(UndoableOp(label: label, run: run))
        if undoStack.count > 30 { undoStack.removeFirst(undoStack.count - 30) }
    }

    /// Undo the most recent recorded operation, then refresh both panels (Cmd+Z
    /// via the Edit menu when a panel — not a text field — is first responder).
    func undoLastOperation() {
        guard let op = undoStack.popLast() else { NSSound.beep(); return }
        Task { @MainActor in
            await op.run()
            await leftPanelController?.reload()
            await rightPanelController?.reload()
        }
    }

    // MARK: - Compare by content (I12 T02)

    func showCompareByContent() {
        guard let (leftPath, rightPath) = compareByContentSelection() else {
            presentInfo(String(localized: "Compare by Content"),
                        String(localized: "Select two files (or one file in each panel) to compare."))
            return
        }
        // Auto-detect: if either file looks binary, use the hex comparer.
        if Self.anyFileLooksBinary([leftPath, rightPath]) {
            openBinaryCompare(leftPath, rightPath)
        } else {
            openTextCompare(leftPath, rightPath)
        }
    }

    func showCompareBinary() {
        guard let (leftPath, rightPath) = compareByContentSelection() else {
            presentInfo(String(localized: "Compare by Content (Hex)"),
                        String(localized: "Select two files (or one file in each panel) to compare."))
            return
        }
        openBinaryCompare(leftPath, rightPath)
    }

    private func openTextCompare(_ leftPath: String, _ rightPath: String) {
        let win = DiffWindowController(leftPath: leftPath, rightPath: rightPath)
        diffWindows.append(win)
        win.onClose = { [weak self, weak win] in
            self?.diffWindows.removeAll { $0 === win }
        }
        win.showWindow()
    }

    private func openBinaryCompare(_ leftPath: String, _ rightPath: String) {
        let win = BinaryCompareWindowController(leftPath: leftPath, rightPath: rightPath)
        binaryCompareWindows.append(win)
        win.onClose = { [weak self, weak win] in
            self?.binaryCompareWindows.removeAll { $0 === win }
        }
        win.showWindow()
    }

    /// Whether any of `paths` sniffs as binary (first 4 KB) — picks text vs hex compare.
    private static func anyFileLooksBinary(_ paths: [String]) -> Bool {
        for path in paths {
            guard let slice = FileSlice(path: path) else { continue }
            if BinaryHeuristic.isProbablyBinary(slice.bytes(at: 0, length: 4096)) { return true }
        }
        return false
    }

    func showGotoPath() {
        guard let panel = activePanel, !panel.isInArchive else { return }
        Task { @MainActor in
            let current = await panel.getCurrentPath()
            let dialog = InputDialog(title: String(localized: "Go to Folder"),
                                     prompt: String(localized: "Path:"), initialValue: current)
            dialog.onConfirm = { [weak self] text in
                guard let self, let resolved = PathResolver.resolve(text, base: current) else { return }
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue {
                    Task { @MainActor in await self.activePanel?.loadDirectory(resolved) }
                } else {
                    self.presentInfo(String(localized: "Go to Folder"),
                                     String(format: NSLocalizedString("Not a folder: %@", comment: ""), resolved))
                }
            }
            self.pathDialog = dialog
            dialog.runModalDialog()
        }
    }

    func showEditorForCursor() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            let path: String?
            var onSaved: (() -> Void)? = nil
            if panel.isInArchive {
                // Non-local filesystem: edit a downloaded temp copy. For writable
                // network filesystems (SFTP/FTP/WebDAV) upload the edited copy back
                // to the origin on each save (F-214); archives are read-only here.
                let local = await panel.localPathForCursor()
                path = local
                let fs = panel.currentFileSystem
                if let local, let remote = panel.tableView.cursorItemFullPath(),
                   fs.capabilities.contains(.write) {
                    onSaved = { [weak self, weak panel] in
                        self?.writeBackEditedFile(localPath: local, to: remote, on: fs, panel: panel)
                    }
                }
            } else {
                path = panel.tableView.cursorDirectoryPath() == nil
                    ? panel.tableView.cursorItemFullPath() : nil
            }
            guard let path, !path.isEmpty else { return }
            self.openEditor(path: path, onSaved: onSaved)
        }
    }

    /// Upload an edited local temp copy back to its origin on a writable network
    /// filesystem, then refresh the panel (F-214 edit write-back).
    private func writeBackEditedFile(localPath: String, to remote: String,
                                     on fs: VirtualFileSystem, panel: PanelController?) {
        Task { @MainActor in
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: localPath)) else { return }
            let vpath = VFSPath(filesystemId: fs.scheme, path: remote)
            do {
                let writer = try await fs.openWrite(vpath, options: WriteOptions())
                try await writer.write(data)
                try await writer.close()
            } catch {
                self.presentInfo(String(localized: "Save"),
                                 String(format: String(localized: "Could not write back “%@”: %@"),
                                        (remote as NSString).lastPathComponent, "\(error)"))
                return
            }
            await panel?.reload()
        }
    }

    func showEditorForNewFile() {
        guard let panel = activePanel, !panel.isInArchive else { return }
        Task { @MainActor in
            let dir = await panel.getCurrentPath()
            let dialog = InputDialog(title: String(localized: "New Text File"),
                                     prompt: String(localized: "File name:"), initialValue: "new.txt")
            dialog.onConfirm = { [weak self] name in
                let leaf = name.trimmingCharacters(in: .whitespaces)
                guard !leaf.isEmpty else { return }
                let full = (dir as NSString).appendingPathComponent(leaf)
                if !FileManager.default.fileExists(atPath: full) {
                    FileManager.default.createFile(atPath: full, contents: Data())
                }
                Task { @MainActor in
                    await self?.activePanel?.reload()
                    self?.openEditor(path: full)
                }
            }
            self.pathDialog = dialog
            dialog.runModalDialog()
        }
    }

    func showMountShare() {
        let dialog = InputDialog(title: String(localized: "Connect to Server"),
                                 prompt: String(localized: "Address (smb://… or \\\\server\\share):"),
                                 initialValue: "smb://")
        dialog.onConfirm = { [weak self] input in
            guard let url = NetworkShare.url(from: input) else {
                self?.presentInfo(String(localized: "Connect to Server"),
                                  String(localized: "Enter an SMB/AFP address, a UNC path or server/share."))
                return
            }
            self?.mountAndOpen(url)
        }
        pathDialog = dialog
        dialog.runModalDialog()
    }

    /// Mount `url` via the system (which handles authentication UI), then navigate the
    /// active panel to the mount point once it appears under /Volumes (best-effort poll).
    private func mountAndOpen(_ url: URL) {
        guard NSWorkspace.shared.open(url) else {
            presentInfo(String(localized: "Connect to Server"),
                        String(format: NSLocalizedString("Could not start mounting %@.", comment: ""), url.absoluteString))
            return
        }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard let share = parts.first else { return }
        let mountBase = "/Volumes/" + share
        let sub = parts.dropFirst().joined(separator: "/")
        let target = sub.isEmpty ? mountBase : mountBase + "/" + sub
        pollForMount(target: target, fallback: mountBase, attempts: 24)
    }

    private func pollForMount(target: String, fallback: String, attempts: Int) {
        guard attempts > 0 else { return }
        let fm = FileManager.default
        if fm.fileExists(atPath: target) {
            Task { @MainActor in await self.activePanel?.loadDirectory(target) }
        } else if fm.fileExists(atPath: fallback) {
            Task { @MainActor in await self.activePanel?.loadDirectory(fallback) }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.pollForMount(target: target, fallback: fallback, attempts: attempts - 1)
            }
        }
    }

    /// F-174: export the selected names to a temp text file, open it in the
    /// built-in editor, and rename on save (positional `old<TAB>new` round-trip).
    func showRenameByEditor() {
        guard let panel = activePanel, !panel.isInArchive else { return }
        Task { @MainActor in
            let (dir, inputs) = await panel.renameInputs()
            let names = inputs.map { $0.name }
            guard !names.isEmpty else { return }
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("pc-rename-\(UUID().uuidString)", isDirectory: true)
                .appendingPathComponent("rename-names.txt")
            do {
                try FileManager.default.createDirectory(at: tmp.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try RenameByEditor.exportText(names).write(to: tmp, atomically: true, encoding: .utf8)
            } catch {
                self.presentInfo(String(localized: "Rename"), "\(error)")
                return
            }
            self.openEditor(path: tmp.path, onSaved: { [weak self, weak panel] in
                self?.applyRenameByEditor(tempPath: tmp.path, originals: names, dir: dir, panel: panel)
            })
        }
    }

    private func applyRenameByEditor(tempPath: String, originals: [String], dir: String, panel: PanelController?) {
        let text = (try? String(contentsOfFile: tempPath, encoding: .utf8)) ?? ""
        switch RenameByEditor.plan(originals: originals, editedText: text) {
        case .success(let pairs):
            guard !pairs.isEmpty else { return }
            renameUndoLog = panel?.performRenames(dir: dir, pairs: pairs.map { (old: $0.old, new: $0.new) }) ?? []
            Task { @MainActor in await panel?.reload() }
        case .failure(let err):
            presentInfo(String(localized: "Rename"), Self.renameByEditorError(err))
        }
    }

    private static func renameByEditorError(_ e: RenameByEditor.PlanError) -> String {
        switch e {
        case .countMismatch(let expected, let got):
            return String(format: String(localized: "Expected %lld line(s) but found %lld — the line count must match the number of files."), expected, got)
        case .emptyName(let line):
            return String(format: String(localized: "Line %lld has an empty name."), line)
        case .duplicate(let name):
            return String(format: String(localized: "The name “%@” is used more than once."), name)
        }
    }

    func showRenameFile() {
        guard let panel = activePanel else { return }
        // Prefer in-cell editing (F-081); falls back to the dialog for archives,
        // remote mounts, and the grid view modes.
        if panel.beginInlineRename() { return }
        // Inside a non-rewritable mount (plugin/network) renaming is unsupported.
        let inArchive = panel.isInArchive
        if inArchive, panel.currentArchiveZipPath == nil { return }
        Task { @MainActor in
            guard let name = await panel.cursorItemName() else { return }
            let dir = await panel.getCurrentPath()
            let dialog = InputDialog(title: String(localized: "Rename"),
                                     prompt: String(localized: "New name:"), initialValue: name)
            dialog.onConfirm = { [weak self] newName in
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                guard RenameValidator.isValid(trimmed), trimmed != name else { return }
                if inArchive {
                    // Rename inside the zip by rewriting it (F-133).
                    guard let zip = panel.currentArchiveZipPath else { return }
                    // Renaming inside an archive rewrites it, and only zip is rewritten here — the
                    // others used to reach the zip rewriter and report "unreadableArchive".
                    guard case .rewrite = ArchiveWriteSupport.capability(forArchiveAt: zip) else {
                        self?.presentInfo(String(localized: "Rename"),
                                          String(localized: "Files can only be renamed inside .zip archives."))
                        return
                    }
                    let oldPath = (dir as NSString).appendingPathComponent(name)
                    let newPath = (dir as NSString).appendingPathComponent(trimmed)
                    Task { @MainActor in
                        do {
                            try ArchiveEditor.rename(in: URL(fileURLWithPath: zip), from: oldPath, to: newPath)
                        } catch {
                            self?.presentInfo(String(localized: "Rename"), "\(error)")
                            return
                        }
                        await panel.reloadCurrentArchive()
                    }
                    return
                }
                let target = (dir as NSString).appendingPathComponent(trimmed)
                if FileManager.default.fileExists(atPath: target) {
                    self?.presentInfo(String(localized: "Rename"),
                                      String(format: NSLocalizedString("An item named “%@” already exists.", comment: ""), trimmed))
                    return
                }
                Task { @MainActor in
                    _ = self?.activePanel?.performRenames(dir: dir, pairs: [(old: name, new: trimmed)])
                    await self?.activePanel?.reload()
                }
            }
            self.pathDialog = dialog
            dialog.runModalDialog()
        }
    }

    private func openEditor(path: String, onSaved: (() -> Void)? = nil) {
        // Per-extension editor association (F-273): hand off to the configured
        // external editor instead of the built-in one. (Only for local files —
        // a remote temp copy has no meaningful write-back to an external app.)
        if onSaved == nil,
           let app = fileAssociations().editorApp(forExtension: (path as NSString).pathExtension),
           openWithExternalApp(path, app: app) {
            return
        }
        editorWindows.removeAll { $0.window == nil || !($0.window?.isVisible ?? false) }
        let win = EditorWindowController(path: path)
        win.onSaved = onSaved
        editorWindows.append(win)
        win.onClose = { [weak self, weak win] in
            self?.editorWindows.removeAll { $0 === win }
        }
        win.showWindow()
    }

    func showHexEditor() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            let path: String?
            if panel.isInArchive {
                path = await panel.localPathForCursor()
            } else {
                path = panel.tableView.cursorDirectoryPath() == nil
                    ? panel.tableView.cursorItemFullPath() : nil
            }
            guard let path, !path.isEmpty else { return }
            self.hexEditorWindows.removeAll { $0.window == nil || !($0.window?.isVisible ?? false) }
            let win = HexEditorWindowController(path: path)
            self.hexEditorWindows.append(win)
            win.onClose = { [weak self, weak win] in
                self?.hexEditorWindows.removeAll { $0 === win }
            }
            win.showWindow()
        }
    }


    func openTerminalHere() {
        guard let panel = activePanel, !panel.isInArchive else { return }
        Task { @MainActor in
            let dir = await panel.getCurrentPath()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", dir]
            do { try process.run() } catch {
                self.presentInfo(String(localized: "Open Terminal"),
                                 String(localized: "Could not launch Terminal."))
            }
        }
    }

    /// Explain Full Disk Access and offer to open System Settings (F-299).
    /// Eject the removable volume the cursor — or, failing that, the current folder — is on (F-006).
    ///
    /// Which volume that is lives in `VolumeEjection` and is tested there, because the ways it goes
    /// wrong are silent: the startup disk contains every path, and one stick's name can be a prefix
    /// of another's.
    func ejectVolumeUnderCursor() {
        let panel = activePanel
        let cursor = panel?.tableView.cursorItemFullPath()
        let here = panel?.view.currentPathValue ?? ""
        switch VolumeEjection.target(focusedPath: cursor, currentDirectory: here,
                                     volumes: panel?.driveVolumes ?? []) {
        case .success(let volume):
            eject(volume)
        case .failure(.bootVolume):
            reportEjectProblem(String(localized: "The startup disk cannot be ejected."), detail: nil)
        case .failure(.notEjectable(let name)):
            reportEjectProblem(String(localized: "“\(name)” cannot be ejected."),
                               detail: String(localized: "Network shares and internal disks stay mounted."))
        case .failure(.noVolume):
            reportEjectProblem(String(localized: "Nothing here is on a removable volume."), detail: nil)
        }
    }

    /// The volume an eject would act on, or nil. Used to decide whether the entry is worth showing:
    /// an "Eject" on every file's context menu is noise, and one that is always there and usually
    /// complains teaches people to stop reading it.
    func ejectableVolumeUnderCursor() -> Volume? {
        let panel = activePanel
        return try? VolumeEjection.target(focusedPath: panel?.tableView.cursorItemFullPath(),
                                          currentDirectory: panel?.view.currentPathValue ?? "",
                                          volumes: panel?.driveVolumes ?? []).get()
    }

    /// Eject a volume named directly — the drive bar's context menu (F-385), as opposed to
    /// `ejectVolumeUnderCursor`, which has to work out which volume is meant first.
    func ejectVolume(_ volume: Volume) {
        eject(volume)
    }

    private func eject(_ volume: Volume) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: URL(fileURLWithPath: volume.path))
            // Leave before the panel is standing on a folder that no longer exists, which reads as
            // the eject having failed. Both panels, because either may be inside it.
            for panel in [leftPanelController, rightPanelController].compactMap({ $0 }) {
                if VolumeEjection.contains(volume: volume.path, path: panel.view.currentPathValue) {
                    Task { await panel.loadDirectory("/Volumes") }
                }
            }
        } catch {
            // The system's own words. It knows which application is holding the volume open and this
            // is the only place that information exists — replacing it with "could not eject" would
            // throw away the one thing that tells the user what to close.
            let ns = error as NSError
            reportEjectProblem(String(localized: "“\(volume.name)” could not be ejected."),
                               detail: ns.localizedRecoverySuggestion ?? ns.localizedDescription)
        }
    }

    private func reportEjectProblem(_ message: String, detail: String?) {
        let alert = NSAlert()
        alert.messageText = message
        if let detail { alert.informativeText = detail }
        alert.alertStyle = .warning
        alert.beginSheetModal(for: window ?? NSApp.mainWindow ?? NSWindow()) { _ in }
    }

    func showFullDiskAccessInfo() {
        FullDiskAccessGuide.presentPrompt()
    }

    /// Verify a zip's integrity: the cursor .zip on a local panel, or the archive
    /// we're currently inside (F-135). Decompresses every entry and checks CRCs.
    func showTestArchive() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            let zipPath: String?
            if !panel.isInArchive, let cursor = panel.tableView.cursorItemFullPath(),
               cursor.lowercased().hasSuffix(".zip") {
                zipPath = cursor
            } else {
                zipPath = panel.currentArchiveZipPath
            }
            guard let zip = zipPath else {
                self.presentInfo(String(localized: "Test Archive"),
                                 String(localized: "Select a .zip archive (or open one) first."))
                return
            }
            let name = (zip as NSString).lastPathComponent
            let problems: [ZipReader.IntegrityProblem]? = await Task.detached {
                guard let reader = ZipReader(fileURL: URL(fileURLWithPath: zip)) else { return nil }
                return reader.verify()
            }.value
            guard let problems else {
                self.presentInfo(String(localized: "Test Archive"),
                                 String(localized: "“\(name)” is not a readable zip archive."))
                return
            }
            if problems.isEmpty {
                self.presentInfo(String(localized: "Test Archive"),
                                 String(localized: "“\(name)”: OK — all entries verified."))
            } else {
                let list = problems.prefix(20).map { "• \($0.path): \($0.reason)" }.joined(separator: "\n")
                let more = problems.count > 20 ? String(localized: "\n… and \(problems.count - 20) more.") : ""
                self.presentInfo(String(localized: "Test Archive"),
                                 String(localized: "“\(name)”: \(problems.count) problem(s):\n\(list)\(more)"))
            }
        }
    }

    /// Unpack the cursor archive (or the archive we're currently inside) into a
    /// destination directory, preserving structure (F-132 / cm_UnpackFiles). The
    /// default destination is a folder named after the archive in the other panel.
    func showUnpackFiles() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            // Resolve the source filesystem + a name for the default destination.
            let sourceFS: VirtualFileSystem
            let archiveName: String
            if panel.isInArchive {
                sourceFS = panel.currentFileSystem
                archiveName = ((panel.currentArchiveZipPath ?? "archive") as NSString).lastPathComponent
            } else if let cursor = panel.tableView.cursorItemFullPath(),
                      let archive = ArchiveFS(archiveFileURL: URL(fileURLWithPath: cursor), fsID: "zip:\(cursor)") {
                if archive.hasEncryptedEntries {
                    _ = resolveArchivePassword(for: archive, localPath: cursor)
                }
                sourceFS = archive
                archiveName = (cursor as NSString).lastPathComponent
            } else {
                self.presentInfo(String(localized: "Unpack"),
                                 String(localized: "Select an archive (or open one) first."))
                return
            }
            let baseName = (archiveName as NSString).deletingPathExtension
            let destBase: String
            if let inactive = self.getInactivePanel() {
                destBase = await inactive.getCurrentPath()
            } else {
                destBase = await panel.getCurrentPath()
            }
            let defaultDest = (destBase as NSString).appendingPathComponent(baseName)

            let dialog = InputDialog(title: String(localized: "Unpack Archive"),
                                     prompt: String(localized: "Extract to:"), initialValue: defaultDest)
            dialog.onConfirm = { [weak self] text in
                guard let self else { return }
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let dest = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true)
                // Run through the background transfer queue (F-138): backgroundable,
                // cancellable, and shown in the transfer manager.
                TransferManager.shared.enqueue(.custom(run: { _, progress in
                    do {
                        let result = try await ArchiveExtractor.extractAll(from: sourceFS, to: dest)
                        progress(OpProgress(filesTotal: result.files, filesDone: result.files,
                                            bytesTotal: result.bytes, bytesDone: result.bytes,
                                            currentItem: dest.lastPathComponent, bytesPerSecond: 0))
                        return []
                    } catch is CancellationError { throw OperationError.cancelled }
                }), title: String(localized: "Unpack \(archiveName)"),
                    onComplete: { [weak self] _ in
                        Task { @MainActor in await self?.getInactivePanel()?.loadDirectory(dest.path) }
                    })
            }
            self.pathDialog = dialog
            dialog.runModalDialog()
        }
    }

    // MARK: - Cross-panel transfer (F-063)

    func transferToLeftPanel() async { await transferCursorItem(toRight: false) }
    func transferToRightPanel() async { await transferCursorItem(toRight: true) }

    /// Target = source (F-064): show the active panel's current directory in the
    /// other panel.
    func targetEqualsSource() async {
        guard let active = activePanel, let target = getInactivePanel() else { return }
        await target.loadDirectory(await active.getCurrentPath())
    }

    /// Ctrl+Left/Right: point the target panel at the folder under the active
    /// panel's cursor, or — when the cursor is on a file or ".." — at the active
    /// panel's current folder.
    private func transferCursorItem(toRight: Bool) async {
        guard let active = activePanel,
              let target = toRight ? rightPanelController : leftPanelController else { return }
        let path: String
        if let dir = active.tableView.cursorDirectoryPath() {
            path = dir
        } else {
            path = await active.getCurrentPath()
        }
        await target.loadDirectory(path)
    }

    /// Resolve the two files to compare per SPEC-010 §1 selection rules.
    private func compareByContentSelection() -> (String, String)? {
        guard let active = activePanel, let other = getInactivePanel() else { return nil }
        let activeSel = activePanelSelectionPaths()
        if activeSel.count == 2 { return (activeSel[0], activeSel[1]) }
        let otherSel = panelSelectionPaths(other)
        if activeSel.count == 1, otherSel.count == 1 { return (activeSel[0], otherSel[0]) }
        if activeSel.isEmpty, otherSel.isEmpty,
           let a = active.tableView.cursorItemFullPath(), let b = other.tableView.cursorItemFullPath() {
            return (a, b)
        }
        return nil
    }

    private func activePanelSelectionPaths() -> [String] {
        guard let active = activePanel else { return [] }
        return panelSelectionPaths(active)
    }

    private func panelSelectionPaths(_ panel: PanelController) -> [String] {
        panel.tableView.selectedFilePaths()
    }

    // MARK: - Synchronize directories (I12 T05/T06)

    func showSynchronizeDirs() {
        guard let left = leftPanelController, let right = rightPanelController else { return }
        Task { @MainActor in
            // A panel browsing a rewritable .zip becomes a zip side (from its root);
            // anything else must be a local folder (F-193). Reject unsupported combos.
            let leftPath = await left.getCurrentPath()
            let rightPath = await right.getCurrentPath()
            // A panel on a live connection — FTP, SFTP, a filesystem plugin — is a remote side
            // (F-193). `DisconnectableFileSystem` is the protocol's own word for "backed by a
            // connection", which is exactly the distinction wanted here: a tar or rar mount is also
            // "not local", and syncing one of those is a different thing that this does not do.
            @MainActor func side(_ panel: PanelController, _ path: String) -> SyncSide {
                if let zip = panel.currentArchiveZipPath { return .zip(zip) }
                if panel.isInArchive, panel.currentFileSystem is DisconnectableFileSystem {
                    return .remote(RemoteSyncSource(fs: panel.currentFileSystem, path: path))
                }
                return .localDir(path)
            }
            let leftSide = side(left, leftPath)
            let rightSide = side(right, rightPath)
            if leftSide.isZip && rightSide.isZip {
                self.presentInfo(String(localized: "Synchronize Directories"),
                                 String(localized: "Synchronizing two archives is not supported."))
                return
            }
            if leftSide.isRemote && rightSide.isRemote {
                self.presentInfo(String(localized: "Synchronize Directories"),
                                 String(localized: "Synchronizing two servers with each other is not supported."))
                return
            }
            if (leftSide.isZip && rightSide.isRemote) || (leftSide.isRemote && rightSide.isZip) {
                self.presentInfo(String(localized: "Synchronize Directories"),
                                 String(localized: "Synchronizing an archive with a server is not supported."))
                return
            }
            // What is left over: a mount that is neither local, nor a rewritable zip, nor a connection
            // — a tar or rar archive, which cannot be written to.
            if (left.isInArchive && !leftSide.isZip && !leftSide.isRemote) ||
               (right.isInArchive && !rightSide.isZip && !rightSide.isRemote) {
                self.presentInfo(String(localized: "Synchronize Directories"),
                                 String(localized: "Only local folders, .zip archives and server connections can be synchronized."))
                return
            }
            let win = SyncWindowController(left: leftSide, right: rightSide,
                                           presetsURL: self.configPaths.syncPresets)
            self.syncWindow = win
            win.onClose = { [weak self] in self?.syncWindow = nil }
            win.reload = { [weak self] in
                // Re-parse a zip side from disk (its bytes changed); reload listings.
                if leftSide.isZip { await self?.leftPanelController?.reloadCurrentArchive() }
                else { await self?.leftPanelController?.reload() }
                if rightSide.isZip { await self?.rightPanelController?.reloadCurrentArchive() }
                else { await self?.rightPanelController?.reload() }
            }
            win.showWindow()
        }
    }

    // MARK: - Compare directories (I12 T04)

    func compareDirectories(withSubdirs: Bool) {
        guard let left = leftPanelController, let right = rightPanelController else { return }
        guard !left.isInArchive, !right.isInArchive else {
            presentInfo(String(localized: "Compare Directories"),
                        String(localized: "Compare Directories works on local folders only."))
            return
        }
        Task { @MainActor in
            let leftDir = await left.getCurrentPath()
            let rightDir = await right.getCurrentPath()
            let result: DirCompareResult
            if withSubdirs {
                // Off the main thread. Walking a tree costs a `stat` per file and this walks *two* of
                // them: measured at ~800 ms for a 40,000-file source tree, so 1.6 s of frozen window
                // for a moderate project and considerably worse for a home folder. Nothing here needs
                // the main actor — `gatherRecursive` and `compare` are pure functions over paths — and
                // the marking below hops back to it.
                result = await Task.detached(priority: .userInitiated) {
                    DirCompareMarker.compare(left: Self.gatherRecursive(leftDir),
                                             right: Self.gatherRecursive(rightDir),
                                             caseSensitive: false)
                }.value
            } else {
                // The top-level case reads the panels' own listings, which belong to the main actor —
                // and is bounded by what is on screen anyway.
                result = DirCompareMarker.compare(left: Self.topLevelFileEntries(left),
                                                  right: Self.topLevelFileEntries(right),
                                                  caseSensitive: false)
            }
            let leftNames = Set(result.leftMarks.map(Self.firstPathComponent))
            let rightNames = Set(result.rightMarks.map(Self.firstPathComponent))
            left.tableView.markNames(leftNames)
            right.tableView.markNames(rightNames)
        }
    }

    private static func topLevelFileEntries(_ panel: PanelController) -> [DirCompareEntry] {
        panel.tableView.currentEntries()
            .filter { !PanelEntryHelpers.isDirectoryLike($0.kind) }
            .map { DirCompareEntry(name: $0.name, isDirectory: false, size: $0.size, modified: $0.modified) }
    }

    /// Recursively gather local files under `dir`, keyed by POSIX-relative path.
    private static func gatherRecursive(_ dir: String) -> [DirCompareEntry] {
        let fm = FileManager.default
        var out: [DirCompareEntry] = []
        let base = (dir as NSString).standardizingPath
        guard let en = fm.enumerator(at: URL(fileURLWithPath: base),
                                     includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                                     options: [.skipsHiddenFiles]) else { return out }
        for case let url as URL in en {
            let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
            guard vals?.isRegularFile == true else { continue }
            var rel = url.path
            if rel.hasPrefix(base + "/") { rel.removeFirst(base.count + 1) }
            out.append(DirCompareEntry(name: rel, isDirectory: false,
                                       size: Int64(vals?.fileSize ?? 0),
                                       modified: vals?.contentModificationDate ?? Date(timeIntervalSince1970: 0)))
        }
        return out
    }

    private static func firstPathComponent(_ p: String) -> String {
        if let slash = p.firstIndex(of: "/") { return String(p[..<slash]) }
        return p
    }

    private func presentInfo(_ message: String, _ detail: String) {
        // Defensive: NSAlert must be created and run on the main thread. Command
        // handlers are @MainActor, but this keeps any other caller safe too.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.presentInfo(message, detail) }
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    // MARK: - Find Files (I10)

    func showFindFiles() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            let startDir = await panel.getCurrentPath()
            let win = FindFilesWindowController(startDirectory: startDir,
                                                templatesURL: self.configPaths.searchTemplates)
            win.setContentFields(self.contentFieldRegistry.allQualifiedFields()
                .filter { !$0.field.isFullText }
                .map { ($0.qualifiedID, $0.field.title) })   // F-157
            // The plugin-text option only appears if some loaded plugin can produce text (F-351).
            win.setHasPluginText(self.contentFieldRegistry.hasFullTextProvider)
            self.findWindow = win
            win.onStart = { [weak self, weak win] template, dir, inSelectionOnly, useSpotlight, searchArchives, notContaining, contentPredicate, searchPluginText, searchComments in
                guard let self, let win else { return }
                self.searchTask?.cancel()
                win.clearResults()
                self.searchTask = Task { @MainActor in
                    guard let panel = self.activePanel else { return }
                    // Search over the panel's current filesystem, so a panel inside
                    // an archive searches the archive (F-153).
                    let fs = panel.currentFileSystem
                    self.lastSearchFS = fs

                    // Spotlight mode: only for indexed local folders (ignores regex,
                    // depth and selection scope). Falls back if we're not on LocalFS.
                    if useSpotlight, fs is LocalFS {
                        let paths = await self.spotlightSearch.search(nameMask: template.nameMask, contentText: template.contentText, in: dir)
                        guard !Task.isCancelled else { win.searchFinished(); return }
                        for path in paths { win.addResult(path) }
                        // Spotlight answers a different question from the walker: it has no notion of a
                        // regular expression, a depth limit or a selection scope. The tooltip on the
                        // checkbox says so, which is no help at the moment it matters — so when one of
                        // those is actually set, the result says which of them did not apply (F-159).
                        var ignored: [String] = []
                        if template.useRegex { ignored.append(String(localized: "regular expressions")) }
                        if template.maxDepth > 0 { ignored.append(String(localized: "the depth limit")) }
                        if inSelectionOnly { ignored.append(String(localized: "the selection scope")) }
                        win.setStatus(ignored.isEmpty
                            ? String(localized: "Done: \(paths.count) found (Spotlight)")
                            : String(localized: "Done: \(paths.count) found (Spotlight — \(ignored.joined(separator: ", ")) did not apply)"))
                        win.searchFinished()
                        return
                    }

                    let scope: [String]? = inSelectionOnly ? await panel.selectedOrCursorPaths() : nil
                    // Multiple start directories (F-150): ";"-separated in the field.
                    let roots = dir.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    var query = template.makeQuery(startDirectory: roots.first ?? dir, scopePaths: scope)
                    query.extraStartDirectories = scope == nil ? Array(roots.dropFirst()) : []
                    query.searchArchives = searchArchives
                    query.contentNotContaining = notContaining
                    query.searchPluginText = searchPluginText
                    query.searchComments = searchComments
                    // A pattern that will not compile ends the search with no results and no message,
                    // which reads exactly like "the term is not in these files" (F-154). Say so instead.
                    if let bad = query.firstInvalidPattern() {
                        win.setStatus(String(localized: "Invalid regular expression in the \(bad.field) field: \(bad.reason)"))
                        win.searchFinished()
                        return
                    }
                    var count = 0
                    let engine = FileSearchEngine()
                    // Open a zip-family archive found during the walk as an ArchiveFS.
                    // On disk it's opened directly; inside another archive it's
                    // extracted to a temp file first (enabling nested archive search).
                    let opener: FileSearchEngine.ArchiveOpener = { fs, path in
                        let localURL: URL
                        if fs is LocalFS {
                            localURL = URL(fileURLWithPath: path)
                        } else if let url = (try? await fs.localFileIfAvailable(
                            VFSPath(filesystemId: fs.scheme, path: path))) ?? nil {
                            localURL = url
                        } else { return nil }
                        return ArchiveFS(archiveFileURL: localURL, fsID: "zip:\(localURL.path)")
                    }
                    let registry = self.contentFieldRegistry
                    // Text from the loaded content plugins, for files whose own bytes are not text
                    // (F-351). Passed only when asked for: producing it can run a decompiler, and the
                    // engine must not pay that on an ordinary search.
                    var textProvider: FileSearchEngine.TextProvider?
                    var textSearcher: FileSearchEngine.TextSearcher?
                    if searchPluginText {
                        textProvider = { path in
                            await registry.fullText(forFileAt: URL(fileURLWithPath: path))
                        }
                        // Preferred when a plugin can search its own result (F-354): nothing is copied,
                        // so the whole document is reachable rather than as much as a buffer holds.
                        textSearcher = { path, needle, matchCase in
                            await registry.searchFullText(forFileAt: URL(fileURLWithPath: path),
                                                          needle: needle, matchCase: matchCase)
                        }
                    }
                    // A file's comment, from all three places one can live (F-373): the directory's
                    // descript.ion, the macOS Finder comment, and whatever a plugin contributes as its
                    // note field. Joined, because the user asked "is this text written about the file"
                    // and does not care which of the three answered.
                    var commentProvider: FileSearchEngine.CommentProvider?
                    if searchComments {
                        commentProvider = { [weak self] path in
                            await MainActor.run { self?.searchableComment(forPath: path) }
                        }
                    }
                    for await hit in await engine.search(query, fs: fs,
                                                         archiveOpener: searchArchives ? opener : nil,
                                                         textProvider: textProvider,
                                                         textSearcher: textSearcher,
                                                         commentProvider: commentProvider) {
                        // Content-field predicate (F-157): resolve the field on the
                        // (local) hit and skip files that don't satisfy the condition.
                        if let pred = contentPredicate, fs is LocalFS {
                            let v = await registry.value(qualifiedID: pred.qualifiedID,
                                                         forFileAt: URL(fileURLWithPath: hit.path))
                            if !pred.evaluate(v) { continue }
                        }
                        win.addResult(hit.path, matchLine: hit.matchLine, matchPreview: hit.matchPreview)
                        count += 1
                        if count % 25 == 0 { win.setStatus(String(localized: "\(count) found — searching…")) }
                    }
                    win.setStatus(String(localized: "Done: \(count) found"))
                    win.searchFinished()
                }
            }
            win.onCancel = { [weak self, weak win] in
                self?.searchTask?.cancel(); self?.spotlightSearch.cancel(); win?.searchFinished()
            }
            win.onFeedToListbox = { [weak self, weak win] paths in
                win?.close()
                Task { @MainActor in await self?.activePanel?.enterResults(paths) }
            }
            win.onView = { [weak self] path in
                guard let self else { return }
                if FileManager.default.fileExists(atPath: path) {
                    self.openLister(files: [path], index: 0)
                } else if let fs = self.lastSearchFS {
                    // Archive/network hit: extract to a temp file, then view it.
                    Task { @MainActor in
                        if let url = (try? await fs.localFileIfAvailable(VFSPath(filesystemId: fs.scheme, path: path))) ?? nil {
                            self.openLister(files: [url.path], index: 0)
                        } else { NSSound.beep() }
                    }
                } else { NSSound.beep() }
            }
            win.showWindow()
        }
    }

    private func openLister(files: [String], index: Int, plugins: [PLXLister] = []) {
        listerWindows.removeAll { $0.window == nil || !($0.window?.isVisible ?? false) }
        let lister = ListerWindowController(files: files, startIndex: index, plugins: plugins)
        listerWindows.append(lister)
        lister.showWindow(nil)
        lister.window?.makeKeyAndOrderFront(nil)
    }

    private func openDirectoryLister(_ dir: String) {
        listerWindows.removeAll { $0.window == nil || !($0.window?.isVisible ?? false) }
        let lister = ListerWindowController(directoryPath: dir)
        listerWindows.append(lister)
        lister.showWindow(nil)
        lister.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Quick View (SPEC-005 §6)

    /// Quick View (Ctrl+Q, F-118): embed a live file preview into the *inactive*
    /// panel that follows the active panel's cursor. Toggling again restores it.
    func toggleQuickView() {
        if quickViewPreview != nil {
            quickViewHostPanel?.view.setQuickViewOverlay(nil)
            quickViewPreview = nil
            quickViewHostPanel = nil
            return
        }
        guard let host = getInactivePanel() else { return }
        let preview = FilePreviewView()
        // Media starts by itself here and not in the side panel: Quick View is the gesture for "show me
        // this", and the panel's info page merely follows the cursor.
        preview.autostartsMedia = true
        quickViewPreview = preview
        quickViewHostPanel = host
        host.view.setQuickViewOverlay(preview)
        setQuickViewItem(activePanel?.tableView.cursorItemFullPath())
    }

    private func setQuickViewItem(_ path: String?) {
        guard let preview = quickViewPreview else { return }
        let exists = path.map { FileManager.default.fileExists(atPath: $0) } ?? false
        preview.show(path: exists ? path : nil, fallbackIcon: nil)
    }

    private func updateQuickView() {
        if previewIsVisible, previewPanel.mode == .info { refreshPreviewInfo() }
        // Embedded Quick View follows the active panel's cursor (F-118). Ignore
        // cursor moves inside the host (inactive) panel itself.
        if quickViewPreview != nil, activePanel !== quickViewHostPanel {
            setQuickViewItem(activePanel?.tableView.cursorItemFullPath())
        }
        guard quickViewLister != nil, !quickViewScheduled else { return }
        quickViewScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            self.quickViewScheduled = false
            if let qv = self.quickViewLister, let path = self.activePanel?.tableView.cursorItemFullPath() {
                qv.setFile(path)
            }
        }
    }

    // MARK: - Preview panel (Info / Activities / Log sidebar)

    private var previewIsVisible: Bool { (previewWidthConstraint?.constant ?? 0) > 0 }

    private static let previewDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    /// Apply a panel width while dragging (F-344). The resizer owns the clamping.
    private func setPreviewWidth(_ width: CGFloat) {
        guard let c = previewWidthConstraint, c.constant > 0 else { return }
        c.constant = width
        previewResizer.panelWidth = width
        preferredPreviewWidth = width
    }

    /// The width to restore the panel to. Starts at the built-in default and follows the user's
    /// last drag, so re-opening the panel does not undo the resize.
    private var preferredPreviewWidth: CGFloat = MainWindowController.previewWidth

    func togglePreviewPanel() {
        guard let c = previewWidthConstraint else { return }
        let show = c.constant == 0
        c.constant = show ? preferredPreviewWidth : 0
        previewResizerWidthConstraint?.constant = show ? PreviewResizeHandle.width : 0
        previewResizer.panelWidth = preferredPreviewWidth
        previewPanel.isHidden = !show   // fully hide when collapsed (no leftover sliver)
        previewResizer.isHidden = !show
        previewHandle.isPanelOpen = show
        previewPanel.applyTheme()
        Task { await mainConfig.setBool(show, "Layout", "PreviewPanel") }
        updateTerminalMenuState()   // the sidebar may be where the terminal lives (F-388)
        previewTimer?.invalidate(); previewTimer = nil
        if show {
            refreshPreview()
            // Live-update Activities/Log while visible (transfers change over time).
            previewTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self, self.previewPanel.mode != .info else { return }
                self.refreshPreview()
            }
        }
    }

    func refreshPreview() {
        guard previewIsVisible else { return }
        switch previewPanel.mode {
        case .info:
            refreshPreviewInfo()
        case .activities:
            let running = TransferManager.shared.jobs.filter { !$0.status.isFinished }
            previewPanel.setActivities(running.isEmpty
                ? String(localized: "No active transfers.")
                : running.map { "\($0.title)\n  \($0.status.rawValue) — \(Self.percent($0.progress))" }.joined(separator: "\n\n"))
        case .log:
            let done = TransferManager.shared.jobs.filter { $0.status.isFinished }
            previewPanel.setLog(done.isEmpty
                ? String(localized: "No completed transfers yet.")
                : done.map { "\($0.title): \($0.status.rawValue)\($0.errorText.map { " — \($0)" } ?? "")" }.joined(separator: "\n"))
        }
    }

    private static func percent(_ p: OpProgress) -> String {
        let f: Double = p.bytesTotal > 0 ? Double(p.bytesDone) / Double(p.bytesTotal)
                       : (p.filesTotal > 0 ? Double(p.filesDone) / Double(p.filesTotal) : 0)
        return "\(Int(f * 100))%"
    }

    private func refreshPreviewInfo() {
        guard let path = activePanel?.tableView.cursorItemFullPath() else {
            previewPanel.setInfo(path: nil, title: String(localized: "No selection."),
                                 subtitle: "", details: [], fallbackIcon: nil)
            return
        }
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        let vals = try? url.resourceValues(forKeys: [
            .fileSizeKey, .contentModificationDateKey, .creationDateKey,
            .localizedTypeDescriptionKey, .totalFileSizeKey,
        ])

        // Finder's arrangement: kind and size on one dimmed line under the name, then the dates
        // as a key/value block. Path last, because it is the least interesting and the longest.
        var subtitleParts: [String] = []
        if let kind = vals?.localizedTypeDescription { subtitleParts.append(kind) }
        if !isDir.boolValue, let size = vals?.fileSize {
            subtitleParts.append(ByteSize(Int64(size)).formatted(style: .bytesWithSep))
        }

        var details: [(String, String)] = []
        if let created = vals?.creationDate {
            details.append((String(localized: "Created"), Self.previewDateFormatter.string(from: created)))
        }
        if let modified = vals?.contentModificationDate {
            details.append((String(localized: "Modified"), Self.previewDateFormatter.string(from: modified)))
        }
        details.append((String(localized: "Where"), (path as NSString).deletingLastPathComponent))

        previewPanel.setInfo(path: path,
                             title: url.lastPathComponent,
                             subtitle: subtitleParts.joined(separator: " — "),
                             details: details,
                             fallbackIcon: NSWorkspace.shared.icon(forFile: path))
    }

    @objc private func hotlistAddCurrent() {
        Task { @MainActor in
            guard let cwd = await activePanel?.getCurrentPath(), !cwd.isEmpty, !hotlist.contains(path: cwd) else { return }
            hotlist.add(title: (cwd as NSString).lastPathComponent, path: cwd)
            await persistHotlist()
        }
    }

    private func restoreTabs(into panel: PanelController?, prefix: String) async {
        guard let panel else { return }
        let home = NSHomeDirectory()
        let count = await session.int(prefix, "TabCount", default: 0)
        if count <= 0 {
            // Back-compat / first run: single tab from legacy Path/Sort keys.
            let path = validDirectory(await session.string(prefix, "Path", default: home), fallback: home)
            let sort = await session.string(prefix, "Sort", default: "name")
            let asc = await session.bool(prefix, "SortAsc", default: true)
            await panel.importTabs([PanelTabState(path: path, sortColumn: sort, sortAscending: asc)], activeIndex: 0)
            return
        }
        var states: [PanelTabState] = []
        for i in 0..<count {
            let path = validDirectory(await session.string(prefix, "Tab\(i)Path", default: home), fallback: home)
            let sort = await session.string(prefix, "Tab\(i)Sort", default: "name")
            let asc = await session.bool(prefix, "Tab\(i)Asc", default: true)
            let locked = await session.bool(prefix, "Tab\(i)Locked", default: false)
            // A tab that was on a plugin drive comes back as that drive, not as the local "/" its
            // path happens to be. Empty for every ordinary tab, which is nearly all of them.
            let drive = await session.string(prefix, "Tab\(i)Drive", default: "")
            states.append(PanelTabState(path: path, sortColumn: sort, sortAscending: asc, locked: locked,
                                        driveVolume: drive.isEmpty ? nil : drive))
        }
        let activeIndex = await session.int(prefix, "ActiveTab", default: 0)
        await panel.importTabs(states, activeIndex: activeIndex)
        await restoreHistory(into: panel, prefix: prefix)
    }

    /// Restore a panel's persisted back/forward stack (F-062), overwriting the
    /// single entry that importTabs' load just pushed.
    private func restoreHistory(into panel: PanelController, prefix: String) async {
        let hc = await session.int(prefix, "HistCount", default: 0)
        guard hc > 0 else { return }
        var entries: [String] = []
        for i in 0..<hc {
            let p = await session.string(prefix, "Hist\(i)", default: "")
            if !p.isEmpty { entries.append(p) }
        }
        guard !entries.isEmpty else { return }
        let idx = await session.int(prefix, "HistIndex", default: entries.count - 1)
        panel.restoreHistory(entries: entries, index: idx)
    }

    private func validDirectory(_ path: String, fallback: String) -> String {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue { return path }
        return fallback
    }

    func scheduleSaveState() {
        refreshWindowTitle()   // navigation and tab changes come through here too (F-012)
        guard didRestore, !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.saveScheduled = false
            Task { await self.saveState() }
        }
    }

    private func saveState() async {
        guard let left = leftPanelController, let right = rightPanelController else { return }
        await saveTabs(left, prefix: "LeftPanel")
        await saveTabs(right, prefix: "RightPanel")
        await session.setString(activePanel === right ? "right" : "left", "Window", "Active")
        if let window, window.frame.width > 200, window.frame.height > 200 {
            await session.setString(Self.frameString(window.frame), "Window", "Frame")
        }
        let leftWidth = leftPanelController?.view.frame.width ?? 0
        if leftWidth > 50 { await session.setDouble(Double(leftWidth), "Window", "LeftWidth") }
    }

    private func saveTabs(_ panel: PanelController, prefix: String) async {
        let (states, activeIndex) = panel.exportTabs()
        await session.setInt(states.count, prefix, "TabCount")
        await session.setInt(activeIndex, prefix, "ActiveTab")
        for (i, tab) in states.enumerated() {
            await session.setString(tab.path, prefix, "Tab\(i)Path")
            await session.setString(tab.sortColumn, prefix, "Tab\(i)Sort")
            await session.setBool(tab.sortAscending, prefix, "Tab\(i)Asc")
            await session.setBool(tab.locked, prefix, "Tab\(i)Locked")
            await session.setString(tab.driveVolume ?? "", prefix, "Tab\(i)Drive")
        }
        // Persist the back/forward stack (F-062).
        let h = panel.navigationHistory
        await session.setInt(h.entries.count, prefix, "HistCount")
        await session.setInt(h.index, prefix, "HistIndex")
        for (i, p) in h.entries.enumerated() { await session.setString(p, prefix, "Hist\(i)") }
    }

    /// Persist and flush synchronously-awaitable (called from applicationShouldTerminate).
    func persistNow() async {
        await saveState()
        await session.flush()
        await mainConfig.flush()
    }

    // MARK: - Global hidden-files toggle (WindowControllerProtocol)

    func toggleHiddenFiles() {
        hiddenFilesShown.toggle()
        leftPanelController?.setHiddenFiles(hiddenFilesShown)
        rightPanelController?.setHiddenFiles(hiddenFilesShown)
        let value = hiddenFilesShown
        Task { await mainConfig.setBool(value, "Configuration", "ShowHiddenSystem") }
    }

    // MARK: - Settings (I05-T03/T04)

    func showSettings() {
        Task { @MainActor in
            let snapshot = await buildSettingsSnapshot()
            let win = SettingsWindowController(
                snapshot: snapshot,
                associations: self.fileAssociations(),
                configRootPath: self.configPaths.root.path,
                currentLanguage: Self.currentUILanguage(),
                currentKeyScheme: self.currentKeyScheme,
                onSetBool: { [weak self] keyPath, value in self?.applyBoolOption(keyPath, value) },
                onSetString: { [weak self] keyPath, value in self?.applyStringOption(keyPath, value) },
                onSaveAssociations: { [weak self] assoc in self?.saveFileAssociations(assoc) },
                onOpenConfigFolder: { [weak self] in
                    guard let self else { return }
                    NSWorkspace.shared.activateFileViewerSelecting([self.configPaths.root])
                },
                onOpenThemesFolder: { [weak self] in
                    guard let self else { return }
                    // Created on demand, with a commented example inside when it is empty —
                    // there is no guessing the format from an empty folder.
                    let dir = self.configPaths.themesDirectory
                    do {
                        _ = try ThemeFile.prepareDirectory(dir)
                    } catch {
                        self.logger.error("could not prepare themes folder \(dir.path, privacy: .public): \(String(describing: error), privacy: .public)")
                    }
                    NSWorkspace.shared.activateFileViewerSelecting([dir])
                },
                themesDirectory: self.configPaths.themesDirectory,
                onSetLanguage: { [weak self] lang in self?.setUILanguage(lang) },
                onSetKeyScheme: { [weak self] scheme in self?.setKeyScheme(scheme) },
                onEditShortcuts: { [weak self] in self?.showKeysEditor() }
            )
            win.setPluginPanes(self.settingsPaneProviders)
            // Plugins page (F-274): installed plugins + enable checkboxes.
            var pluginRows: [PluginRow] = []
            for p in await self.pluginManager.discovered {
                pluginRows.append(PluginRow(name: p.manifest.name, type: p.manifest.type.rawValue,
                                            apiVersion: p.manifest.apiVersion,
                                            enabled: await self.pluginManager.isEnabled(p.manifest.name),
                                            path: p.bundlePath))
            }
            win.setPluginRows(pluginRows)
            win.onTogglePlugin = { [weak self] name, enabled in
                Task { @MainActor in await self?.pluginManager.setEnabled(name, enabled); self?.loadExternalPlugins() }
            }
            win.onOpenPluginsManager = { [weak self] in self?.showPluginsManager() }
            // File-type colour editor (F-032).
            win.onEditTypeColors = { [weak self] in
                guard let self else { return }
                let editor = TypeColorsWindowController(config: self.displayTypeColors)
                editor.onSave = { [weak self] config in self?.applyStringOption("Display.TypeColors", config) }
                self.typeColorsEditor = editor
                editor.showWindow(nil)
                editor.window?.makeKeyAndOrderFront(nil)
            }
            self.settingsWindow = win
            win.showModalless()
        }
    }

    private func buildSettingsSnapshot() async -> SettingsSnapshot {
        let aiPluginCfg = Self.readAIPluginConfig(root: configPaths.root)
        return SettingsSnapshot(
            showHidden: await mainConfig.bool("Configuration", "ShowHiddenSystem", default: false),
            iconMode: await mainConfig.string("Configuration", "IconMode", default: "all"),
            appearance: await mainConfig.string("Colors", "Appearance", default: "system"),
            theme: await mainConfig.string("Colors", "Theme", default: "system"),
            confirmDelete: await mainConfig.bool("Operation", "ConfirmDelete", default: true),
            deleteToTrash: await mainConfig.bool("Operation", "DeleteToTrash", default: true),
            selectDirsWithMask: await mainConfig.bool("Operation", "SelectDirs", default: false),
            bracketsAroundDirs: await mainConfig.bool("Display", "BracketDirs", default: false),
            naturalSort: await mainConfig.bool("Display", "NaturalSort", default: true),
            watchDirectories: await mainConfig.bool("Configuration", "WatchDirectories", default: true),
            alternatingRows: await mainConfig.bool("Display", "AlternatingRows", default: false),
            fontSize: await mainConfig.int("Display", "FontSize", default: 13),
            sizeStyle: await mainConfig.string("Display", "SizeStyle", default: "kb"),
            dateFormat: await mainConfig.string("Display", "DateFormat", default: PanelDateFormatter.defaultPattern),
            showCommandLine: await mainConfig.bool("Layout", "CommandLine", default: true),
            showFunctionKeys: await mainConfig.bool("Layout", "FunctionKeys", default: true),
            showButtonBar: await mainConfig.bool("Layout", "ButtonBar", default: true),
            showDriveBar: await mainConfig.bool("Layout", "DriveBar", default: true),
            showStatusBar: await mainConfig.bool("Layout", "StatusBar", default: true),
            showTabBar: await mainConfig.bool("Layout", "TabBar", default: true),
            showPathBar: await mainConfig.bool("Layout", "PathBar", default: true),
            verifyAfterCopy: await mainConfig.bool("Operation", "VerifyAfterCopy", default: false),
            quickSearchMode: await mainConfig.string("Operation", "QuickSearchMode", default: "direct"),
            mouseMode: await mainConfig.string("Operation", "MouseMode", default: "left"),
            copyPreserveMetadata: await mainConfig.bool("Copy", "PreserveMetadata", default: true),
            copyCloneCopy: await mainConfig.bool("Copy", "CloneCopy", default: true),
            copyOnlyNewer: await mainConfig.bool("Copy", "OnlyNewer", default: false),
            copySpeedLimitKBps: await mainConfig.int("Copy", "SpeedLimitKBps", default: 0),
            packDefaultFormat: await mainConfig.string("Pack", "DefaultFormat", default: "zip"),
            packLevel: Int(await mainConfig.string("Pack", "Level", default: "5")) ?? 5,
            packArchiveExtensions: await mainConfig.string("Pack", "ArchiveExtensions", default: ""),
            editorCreateBackups: await mainConfig.bool("Editor", "CreateBackups", default: false),
            tabOpenInForeground: await mainConfig.bool("Tabs", "OpenInForeground", default: true),
            tabLockedOpensNewTab: await mainConfig.bool("Tabs", "LockedOpensNewTab", default: true),
            ftpKeepAliveSeconds: Int(await mainConfig.string("FTP", "KeepAliveSeconds", default: "0")) ?? 0,
            aiMCPEnabled: await mainConfig.bool("Automation", "MCPServerEnabled", default: false),
            aiMCPPort: await mainConfig.int("Automation", "MCPPort", default: 8790),
            aiMCPToken: await mainConfig.string("Automation", "MCPAuthToken", default: ""),
            aiAutonomy: await mainConfig.string("AI", "Autonomy", default: "confirm"),
            aiAllowShell: await mainConfig.bool("AI", "AllowShell", default: false),
            aiCloudBase: await mainConfig.string("AI", "CloudBaseURL", default: ""),
            aiCloudModel: await mainConfig.string("AI", "CloudModel", default: "local"),
            aiHasCloudKey: Self.cloudKeyExists(),
            aiModelPreference: aiPluginCfg["modelPreference"] as? String ?? "auto",
            aiSystemPrompt: aiPluginCfg["systemPrompt"] as? String ?? "",
            customForeground: await mainConfig.string("Colors", "Foreground", default: ""),
            customBackground: await mainConfig.string("Colors", "Background", default: ""),
            customSelection: await mainConfig.string("Colors", "Selection", default: ""),
            customCursor: await mainConfig.string("Colors", "Cursor", default: "")
        )
    }

    /// The user's chosen UI language ("system" | "en" | "de"), tracked in
    /// UserDefaults alongside the AppleLanguages override so the popup can show
    /// "System default" distinctly from an explicit match of the OS language.
    static func currentUILanguage() -> String {
        UserDefaults.standard.string(forKey: "PCUILanguage") ?? "system"
    }

    /// Apply a UI language choice (F-272): "system" clears the override so the app
    /// follows the OS; "en"/"de" pin AppleLanguages. Takes effect on next launch.
    private func setUILanguage(_ lang: String) {
        let defaults = UserDefaults.standard
        defaults.set(lang, forKey: "PCUILanguage")
        if lang == "system" {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([lang], forKey: "AppleLanguages")
        }
        let alert = NSAlert()
        alert.messageText = String(localized: "Language changed")
        alert.informativeText = String(localized: "The new language takes effect after you restart PeachCommander.")
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    /// Not private, for the same reason as `applyStringOption`: the DEBUG automation runner changes a
    /// setting through exactly the path the Settings dialog uses rather than a second one of its own.
    func applyBoolOption(_ keyPath: String, _ value: Bool) {
        let (section, key) = Self.splitKeyPath(keyPath)
        Task { await mainConfig.setBool(value, section, key) }
        switch keyPath {
        case "Configuration.ShowHiddenSystem":
            hiddenFilesShown = value
            leftPanelController?.setHiddenFiles(value)
            rightPanelController?.setHiddenFiles(value)
        case "Configuration.WatchDirectories":
            // Takes effect at once, in both directions: switching it on starts watching what is already
            // open rather than waiting for the next navigation (F-361).
            for panel in [leftPanelController, rightPanelController] {
                panel?.watchDirectories = value
                if value {
                    Task { @MainActor in await panel?.startWatching(panel?.getCurrentPath() ?? "") }
                } else {
                    panel?.stopWatching()
                }
            }
        case "Display.BracketDirs":
            displayBrackets = value
            applyDisplayOptionsToPanels()
        case "Display.NaturalSort":
            displayNaturalSort = value
            applyDisplayOptionsToPanels()
        case "Display.AlternatingRows":
            displayAlternatingRows = value
            applyDisplayOptionsToPanels()
        case "Layout.CommandLine":
            setCommandLineVisible(value)
        case "Layout.FunctionKeys":
            setFunctionBarVisible(value)
        case "Layout.ButtonBar":
            setButtonBarVisible(value)
        case "Layout.DriveBar":
            setDriveBarVisible(value)
        case "Layout.StatusBar":
            setStatusBarVisible(value)
        case "Layout.TabBar":
            setTabBarVisible(value)
        case "Layout.PathBar":
            setPathBarVisible(value)
        case "Copy.PreserveMetadata":
            copyPreserveMetadata = value; applyCopyDefaultsToPanels()
        case "Copy.CloneCopy":
            copyUseClone = value; applyCopyDefaultsToPanels()
        case "Copy.OnlyNewer":
            copyOnlyNewer = value; applyCopyDefaultsToPanels()
        case "Editor.CreateBackups":
            // Editors that are already open pick this up too: the flag is consulted at save time, and a
            // setting the user just changed applying only to the next window would read as ignored.
            DocumentFile.keepBackups = value
        case "Tabs.OpenInForeground":
            tabOpenInForeground = value; applyTabDefaultsToPanels()
        case "Tabs.LockedOpensNewTab":
            tabLockedOpensNewTab = value; applyTabDefaultsToPanels()
        case "Automation.MCPServerEnabled":
            if value {
                Task { let p = await mainConfig.int("Automation", "MCPPort", default: 8790)
                       let t = await mainConfig.string("Automation", "MCPAuthToken", default: "")
                       startMCPServer(port: UInt16(clamping: p), authToken: t) }
            } else {
                stopMCPServer()
            }
        default:
            break // Operation.* read at action time
        }
    }

    /// Not private: the DEBUG automation runner uses it so a scripted run changes a setting
    /// through exactly the same path the Settings dialog does.
    func applyStringOption(_ keyPath: String, _ value: String) {
        // The Cloud API key goes to the Keychain, never to the config store.
        if keyPath == "AI.CloudKey" { Self.saveCloudKeyToKeychain(value); return }
        // AI-plugin-owned prefs persist to the plugin's JSON (aichat/config.json), which
        // the plugin reads when building a chat. Surfaced on the host AI page for one
        // unified settings location; harmless if the plugin is removed.
        if keyPath == "AIPlugin.ModelPreference" {
            Self.writeAIPluginConfig(root: configPaths.root, field: "modelPreference", value: value); return
        }
        if keyPath == "AIPlugin.SystemPrompt" {
            Self.writeAIPluginConfig(root: configPaths.root, field: "systemPrompt", value: value); return
        }
        let (section, key) = Self.splitKeyPath(keyPath)
        Task { await mainConfig.setString(value, section, key) }
        switch keyPath {
        case "Configuration.IconMode":
            IconLoader.shared.mode = Self.iconMode(from: value)
            leftPanelController?.applyAppearance()
            rightPanelController?.applyAppearance()
        case "Display.SizeStyle":
            displaySizeStyle = value
            applyDisplayOptionsToPanels()
        case "Display.DateFormat":
            displayDateFormat = value
            applyDisplayOptionsToPanels()
        case "Display.FontSize":
            displayFontSize = Int(value) ?? 13
            applyDisplayOptionsToPanels()
        case "Display.TypeColors":
            displayTypeColors = value
            applyDisplayOptionsToPanels()
        case "Colors.Theme":
            themeId = value
            applyAppearance(appearanceSetting)
        case "Colors.Appearance":
            applyAppearance(value)
        case "Colors.Foreground", "Colors.Background", "Colors.Selection", "Colors.Cursor":
            let c = NSColor(hexString: value)                       // F-272; empty/invalid = theme default
            switch key {
            case "Foreground": Theme.customColors.listText = c
            case "Background": Theme.customColors.listBackground = c
            case "Selection":  Theme.customColors.selectedText = c
            default:           Theme.customColors.cursorFrame = c
            }
            applyAppearance(appearanceSetting)                     // re-derive palette + refresh all views (panels included)
        case "Operation.QuickSearchMode":
            leftPanelController?.setQuickSearchMode(value)
            rightPanelController?.setQuickSearchMode(value)
        case "Operation.MouseMode":
            leftPanelController?.setMouseMode(value)
            rightPanelController?.setMouseMode(value)
        case "Pack.DefaultFormat":
            packDefaultFormat = value; applyPackDefaultsToPanels()
        case "Pack.Level":
            packLevel = Int(value) ?? 5; applyPackDefaultsToPanels()
        case "Pack.ArchiveExtensions":
            applyExtraArchiveExtensions(value)   // additive; removal needs a restart
        case "FTP.KeepAliveSeconds":
            ftpKeepAliveSeconds = max(0, Int(value) ?? 0)   // applies to new connections
        case "Copy.SpeedLimitKBps":
            copySpeedLimitKBps = max(0, Int(value) ?? 0); applyCopyDefaultsToPanels()
        default:
            break
        }
    }

    private func applyDisplayOptionsToPanels() {
        leftPanelController?.setDisplayOptions(sizeStyle: displaySizeStyle, bracketDirs: displayBrackets,
                                               dateFormat: displayDateFormat)
        rightPanelController?.setDisplayOptions(sizeStyle: displaySizeStyle, bracketDirs: displayBrackets,
                                                dateFormat: displayDateFormat)
        leftPanelController?.setTypeColors(displayTypeColors)
        rightPanelController?.setTypeColors(displayTypeColors)
        leftPanelController?.setNaturalSort(displayNaturalSort)
        rightPanelController?.setNaturalSort(displayNaturalSort)
        leftPanelController?.setZebraStripes(displayAlternatingRows)
        rightPanelController?.setZebraStripes(displayAlternatingRows)
        leftPanelController?.setPanelFontSize(displayFontSize)
        rightPanelController?.setPanelFontSize(displayFontSize)
    }

    private func applyCopyDefaultsToPanels() {
        for p in [leftPanelController, rightPanelController] {
            p?.setCopyDefaults(preserveMetadata: copyPreserveMetadata, useClone: copyUseClone,
                               onlyNewer: copyOnlyNewer, speedLimitKBps: copySpeedLimitKBps)
        }
    }

    private func applyPackDefaultsToPanels() {
        for p in [leftPanelController, rightPanelController] {
            p?.setPackDefaults(format: packDefaultFormat, level: packLevel)
        }
    }

    private func applyTabDefaultsToPanels() {
        for p in [leftPanelController, rightPanelController] {
            p?.setTabDefaults(openInForeground: tabOpenInForeground, lockedOpensNewTab: tabLockedOpensNewTab)
        }
    }

    /// Layout (TC "Layout"): collapse the command line / function-key bar to zero height.
    private func setCommandLineVisible(_ visible: Bool) {
        commandLine.isHidden = !visible
        commandLineHeightConstraint?.constant = visible ? Metrics.commandLineHeight : 0
    }
    private func setFunctionBarVisible(_ visible: Bool) {
        functionKeyBar.isHidden = !visible
        functionBarHeightConstraint?.constant = visible ? FunctionKeyBar.barHeight : 0
    }

    /// Show/hide the per-panel drive bar / status bar in both panels (F-270).
    private func setDriveBarVisible(_ visible: Bool) {
        leftPanelController?.setDriveBarVisible(visible)
        rightPanelController?.setDriveBarVisible(visible)
    }
    private func setStatusBarVisible(_ visible: Bool) {
        leftPanelController?.setStatusBarVisible(visible)
        rightPanelController?.setStatusBarVisible(visible)
    }
    private func setTabBarVisible(_ visible: Bool) {
        leftPanelController?.setTabBarVisible(visible)
        rightPanelController?.setTabBarVisible(visible)
    }
    private func setPathBarVisible(_ visible: Bool) {
        leftPanelController?.setPathBarVisible(visible)
        rightPanelController?.setPathBarVisible(visible)
    }

    /// Apply an appearance setting: "light", "dark", or "system" (follow macOS).
    /// For "system" the app appearance is left to follow the OS and our custom
    /// Theme palette is derived from the current effective appearance; a system
    /// dark-mode toggle is observed and re-applied (see systemAppearanceChanged).
    @objc private func windowBecameKey(_ note: Notification) {
        guard let opened = note.object as? NSWindow else { return }
        ThemedWindows.applyOnOpen(opened, themeId: themeId, mainWindow: window)
    }

    /// Whether the UI is dark right now: the palette's own base if a theme is selected, otherwise
    /// the Appearance setting, otherwise the OS. Shared so the plugin context and the panels can
    /// never disagree about it.
    static func appearanceIsDark(themeId: String, setting: String) -> Bool {
        if let palette = Theme.palette(id: themeId) { return palette.isDark }
        return setting == "dark" || (setting != "light" && systemIsDark())
    }

    private func applyAppearance(_ value: String) {
        appearanceSetting = value
        let isDark = Self.appearanceIsDark(themeId: themeId, setting: value)
        let named: NSAppearance.Name?
        if Theme.palette(id: themeId) != nil {
            // A named palette decides the base appearance, not just the panel colours. Without
            // this a dark-based palette like Norton left every dialog, sheet and scroller in light
            // aqua — a white Settings window against CGA-blue panels. Deriving it from the palette
            // is what the comment here always claimed and the code never did.
            named = isDark ? .darkAqua : .aqua
        } else {
            // No palette: exactly the pre-theme behaviour, including nil = follow the OS.
            switch value {
            case "dark": named = .darkAqua
            case "light": named = .aqua
            default: named = nil   // system
            }
        }
        let appAppearance = named.map { NSAppearance(named: $0) } ?? nil
        NSApp.appearance = appAppearance     // nil = follow the OS
        window?.appearance = appAppearance
        let resolved = Theme.resolve(themeId: themeId, isDark: isDark)
        Theme.current = resolved.colors.applying(Theme.customColors)   // F-272
        Theme.currentSyntax = resolved.syntax
        Theme.activePaletteId = themeId
        // Rebuilt here, and only here: the one place the theme can change (F-338).
        Theme.pluginContext = Theme.pluginContextValues(colors: Theme.current, isDark: isDark,
                                                       themeId: themeId)
        // A named palette carries its own syntax colours, so take them from what was resolved
        // rather than re-deriving them from isDark — otherwise a palette could show panels in its
        // own colours while plugins highlighted code in the generic dark set.
        Theme.pluginContext.merge(Theme.pluginSyntaxValues(Theme.currentSyntax)) { _, new in new }
        window?.backgroundColor = Theme.current.windowBackground
        leftPanelController?.applyAppearance()
        rightPanelController?.applyAppearance()
        buttonBarView.applyTheme()
        functionKeyBar.applyTheme()
        commandLine.applyTheme()
        bottomDock.applyTheme()
        dockResizer.applyTheme()
        previewPanel.applyTheme()
        previewHandle.applyTheme()
        previewResizer.applyTheme()
        // Both folder trees: the shared column and the one inside each panel (F-015). Neither was
        // repainted on a theme change, and neither was painted at launch either — the theme is read
        // from the configuration after the window is built.
        sharedTree.applyTheme()
        leftPanelController?.view.applyTreeTheme()
        rightPanelController?.view.applyTreeTheme()
        // Plugin-drawn UI (F-338): mounted views get the context key, plugin-owned windows get
        // the broadcast. Both are no-ops for plugins that do not implement them.
        ViewContainerRegistry.shared.notifyViews(key: "theme", value: themeId)
        ContributionRegistry.shared.notifyThemeChanged()
        // The app's own dialogs (F-339). No-op unless a named palette is selected.
        ThemedWindows.apply(themeId: themeId, mainWindow: window)
        // Windows that colour surfaces of their own re-derive them; ThemedWindows only owns the
        // window background, because restoring an inner surface from a remembered value is unsound.
        settingsWindow?.applyTheme()
        // One line per theme change. Cheap, and it answers "which theme is this user actually on,
        // and did it resolve?" — which is otherwise invisible, since a bad id falls back silently.
        logger.info("Theme applied: id=\(self.themeId, privacy: .public), appearance=\(value, privacy: .public), dark=\(isDark), background=\(Theme.pluginHex(Theme.current.listBackground), privacy: .public)")
    }

    /// True when the OS is currently in Dark Mode.
    static func systemIsDark() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    /// macOS toggled light/dark — re-derive our palette when following the system.
    @objc private func systemAppearanceChanged() {
        guard appearanceSetting != "light", appearanceSetting != "dark" else { return }
        // effectiveAppearance updates slightly after the notification.
        DispatchQueue.main.async { [weak self] in self?.applyAppearance("system") }
    }

    private static func splitKeyPath(_ keyPath: String) -> (String, String) {
        let parts = keyPath.split(separator: ".", maxSplits: 1).map(String.init)
        return parts.count == 2 ? (parts[0], parts[1]) : ("General", keyPath)
    }

    static func iconMode(from string: String) -> IconMode {
        switch string.lowercased() {
        case "none": return .none
        case "standard": return .standard
        default: return .all
        }
    }

    private static func frameString(_ f: NSRect) -> String {
        "\(Int(f.origin.x)),\(Int(f.origin.y)),\(Int(f.size.width)),\(Int(f.size.height))"
    }

    private static func parseFrame(_ s: String) -> NSRect? {
        let parts = s.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4, parts[2] > 100, parts[3] > 100 else { return nil }
        return NSRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    private func updateActivePanelAppearance() {
        leftPanelController?.view.isHighlighted = (activePanel === leftPanelController)
        rightPanelController?.view.isHighlighted = (activePanel === rightPanelController)
        refreshWindowTitle()
        revealActivePathInSharedTree()
    }

    /// Put the active panel's path in the window title (F-012).
    ///
    /// The title used to be assigned once at startup and never touched, so it said "Peach Commander"
    /// whatever you were looking at — and that is the text Mission Control, the Window menu and Cmd-Tab
    /// show, which made two windows on two folders indistinguishable. The free-space part is optional,
    /// as the row says; the wording and the abbreviation live in PCFoundation.WindowTitle.
    func refreshWindowTitle() {
        guard let window else { return }
        Task { @MainActor in
            guard let panel = self.activePanel else { return }
            let path = await panel.getCurrentPath()
            let showFree = await self.mainConfig.bool("Display", "TitleShowFreeSpace", default: false)
            var free: Int64?
            var capacity: Int64?
            if showFree, let volume = await self.volumeManager.getVolume(for: path) {
                free = volume.freeSpace
                capacity = volume.capacity
            }
            window.title = WindowTitle.text(path: path, freeSpace: free, capacity: capacity,
                                            showFreeSpace: showFree)
        }
    }

    @objc func activateLeftPanel() {
        activePanel = leftPanelController
        if let v = leftPanelController?.contentResponder { window?.makeFirstResponder(v) }
        scheduleSaveState()
        updateCommandLinePrompt()
        markActiveViewMode()
        notifyPluginViews()
    }

    @objc func activateRightPanel() {
        activePanel = rightPanelController
        if let v = rightPanelController?.contentResponder { window?.makeFirstResponder(v) }
        scheduleSaveState()
        updateCommandLinePrompt()
        markActiveViewMode()
        notifyPluginViews()
    }

    /// WindowControllerProtocol: toggle between panels (Tab key / cm_SwitchPanel).
    func toggleActivePanel() {
        if activePanel === leftPanelController { activateRightPanel() } else { activateLeftPanel() }
    }

    func getActivePanel() -> PanelController? { activePanel }

    func getInactivePanel() -> PanelController? {
        activePanel === leftPanelController ? rightPanelController : leftPanelController
    }

    func getVolumeManager() -> VolumeManager { volumeManager }

    // MARK: - Command line (I06-T05)

    /// Command-line aliases, re-read each run so hand-edits to aliases.ini apply.
    private func aliasStore() -> AliasStore {
        AliasStore(parsing: (try? String(contentsOf: configPaths.aliases, encoding: .utf8)) ?? "")
    }

    private func runCommandLine(_ rawLine: String) {
        guard let panel = activePanel else { return }
        // Expand a leading command-line alias (F-256) before anything else.
        let line = aliasStore().expand(rawLine)
        // A bare cm_/em_ command name executes that command (TC behaviour).
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.range(of: "^(cm_|em_)[A-Za-z0-9]+$", options: .regularExpression) != nil {
            if trimmed.hasPrefix("em_") { runUserCommand(trimmed) } else { runCommandNamed(trimmed) }
            return
        }
        // Run it in the embedded terminal instead, when the user has asked for that (F-381, plan §7).
        //
        // Worth having as more than a preference: a detached command has no terminal, so anything that
        // asks a question gets no answer. `sudo` is the case everyone hits — it prompts for a password
        // into a pipe nobody is reading and fails. In the terminal the prompt is on screen, the output
        // arrives as it happens, and a long command can be interrupted.
        if runCommandLineInTerminal {
            Task { @MainActor in
                let cwd = await panel.getCurrentPath()
                // `cd` first, so the command runs where the panel is looking rather than wherever the
                // shell was left. Both lines go together, so nothing can be typed in between.
                if sendToTerminal("cd \(ShellQuoting.quote(cwd))\n\(line)\n") { return }
                // No terminal to run it in: fall back rather than swallow the command.
                await self.runCommandLineDetached(line, in: cwd, panel: panel)
            }
            return
        }
        Task { @MainActor in
            let cwd = await panel.getCurrentPath()
            let result = await ShellExecutor.run(line, workingDirectory: cwd)
            if let dir = result.changedDirectory {
                await panel.loadDirectory(dir)
            } else {
                await panel.reload()
                if !result.output.isEmpty { self.showShellOutput(command: line, output: result.output) }
            }
            self.updateCommandLinePrompt()
        }
    }

    private func showShellOutput(command: String, output: String) {
        let win = ShellOutputWindow(command: command, output: output)
        shellOutputWindow = win
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
    }

    func updateCommandLinePrompt() {
        guard let panel = activePanel else { return }
        Task { @MainActor in
            let cwd = await panel.getCurrentPath()
            self.cachedActiveCwd = cwd
            self.commandLine.setPrompt(cwd)
            // The window title stays the static app name — the current path already
            // shows in the command-line prompt and the path bar, so mirroring it in
            // the title bar was redundant.
        }
    }

    /// Route a printable keystroke from a panel into the command line (TC default).
    func routeTypingToCommandLine(_ text: String) { commandLine.insertText(text) }

    /// Append the cursor name/path to the command line (Ctrl+Enter / Ctrl+Shift+Enter).
    func appendToCommandLine(_ text: String) {
        commandLine.insertText(commandLine.frame.width > 0 ? " \(text)" : text)
    }

    /// WindowControllerProtocol: swap the two panels' directories (Ctrl+U).
    func swapPanels() {
        Task { @MainActor in
            guard let left = leftPanelController, let right = rightPanelController else { return }
            let l = await left.getCurrentPath()
            let r = await right.getCurrentPath()
            await left.loadDirectory(r)
            await right.loadDirectory(l)
        }
    }

    /// Ctrl+Shift+U: swap the two panels including all their tabs (F-064).
    func swapPanelsIncludingTabs() {
        Task { @MainActor in
            guard let left = leftPanelController, let right = rightPanelController else { return }
            let l = left.exportTabs()
            let r = right.exportTabs()
            await left.importTabs(r.states, activeIndex: r.activeIndex)
            await right.importTabs(l.states, activeIndex: l.activeIndex)
        }
    }

    /// Show (or focus) the background transfer manager window (TODOS #135).
    func showTransferManager() {
        if transferManagerWC == nil { transferManagerWC = TransferManagerWindowController() }
        transferManagerWC?.present()
    }

    /// cm_QuickFilter: toggle the active panel's quick-filter (same as Ctrl+S).
    func toggleQuickFilter() { activePanel?.tableView.toggleQuickFilter() }

    /// cm_HistoryList (Alt+Down): dropdown of the active panel's visited paths;
    /// the current one is checked; picking one navigates there.
    func showHistoryMenu() {
        guard let panel = activePanel else { return }
        let h = panel.navigationHistory
        guard !h.entries.isEmpty else { return }
        let menu = NSMenu()
        for i in stride(from: h.entries.count - 1, through: 0, by: -1) {
            let item = NSMenuItem(title: (h.entries[i] as NSString).abbreviatingWithTildeInPath,
                                  action: #selector(historyMenuPick(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            item.state = (i == h.index) ? .on : .off
            menu.addItem(item)
        }
        let view = panel.tableView
        menu.popUp(positioning: nil, at: NSPoint(x: 4, y: 4), in: view)
    }

    @objc private func historyMenuPick(_ sender: NSMenuItem) {
        let i = sender.tag
        Task { @MainActor in await activePanel?.goToHistoryIndex(i) }
    }

    /// cm_OpenSourceNotices: the Open Source & Third-Party Software window (built
    /// entirely from the bundled ThirdPartyNotices.json).
    func showOpenSourceNotices() {
        if openSourceWC == nil { openSourceWC = OpenSourceWindowController.make() }
        if openSourceWC == nil {
            presentInfo(String(localized: "Open Source & Third-Party Software"),
                        String(localized: "The third-party notices are unavailable in this build."))
            return
        }
        openSourceWC?.present()
    }

    /// Cycle the active panel's view mode and persist it (TODOS #58).
    func cycleActivePanelViewMode() {
        guard let panel = activePanel else { return }
        panel.cycleViewMode()
        persistViewMode(of: panel)
    }

    /// Set the active panel's view mode directly (View-menu items) and persist it.
    func setActivePanelViewMode(_ mode: PanelViewMode) {
        guard let panel = activePanel else { return }
        panel.setViewMode(mode)
        persistViewMode(of: panel)
    }

    private func persistViewMode(of panel: PanelController) {
        let key = (panel === leftPanelController) ? "LeftViewMode" : "RightViewMode"
        let mode = panel.viewMode.rawValue
        markActiveViewMode()
        Task { await mainConfig.setString(mode, "Layout", key); await mainConfig.flush() }
    }

    /// Width of the shared tree column when it is open.
    private static let sharedTreeWidth: CGFloat = 220

    /// Is the one-tree-for-both-panels column open (F-015)?
    var sharedTreeVisible: Bool { (sharedTreeWidthConstraint?.constant ?? 0) > 0 }

    /// Show or hide the shared tree (cm_TreeShared, F-015).
    ///
    /// One tree for both panels, as Total Commander offers alongside the per-panel column: clicking a
    /// folder in it navigates whichever panel is *active*, so it reads as a place to steer from rather
    /// than as part of either panel. The per-panel trees are untouched — the two answer different
    /// questions and TC lets you have either.
    func setSharedTreeVisible(_ visible: Bool, persist: Bool = true) {
        sharedTreeWidthConstraint?.constant = visible ? Self.sharedTreeWidth : 0
        sharedTree.isHidden = !visible          // no leftover sliver when collapsed
        setMenuCheck(cmd: "cm_TreeShared", on: visible)
        if visible { revealActivePathInSharedTree() }
        if persist { Task { await mainConfig.setBool(visible, "Layout", "SharedTree") } }
    }

    @objc func toggleSharedTree() { setSharedTreeVisible(!sharedTreeVisible) }

    // MARK: - The bottom dock (F-381)

    /// Which docked panel was on screen last time, restored once the plugin providing it turns up.
    private var rememberedDockPanel: String?

    /// Is the plugin dock across the bottom of the window open?
    var bottomDockVisible: Bool { (dockHeightConstraint?.constant ?? 0) > 0 }

    /// Whether the dock is *meant* to be open — the user's answer, as opposed to whether it can be.
    ///
    /// The two are not the same at startup, and that was the whole of the "it never comes back" bug
    /// (F-388): the configuration is applied before any plugin is loaded, so the dock opens, gets its
    /// first — empty — provider list, and is closed again as an empty frame. Keeping the wish separately
    /// lets that housekeeping undo itself when the plugin arrives, without ever overriding a user who
    /// closed the dock on purpose.
    private var dockWantedVisible = false

    /// Open or close the dock (cm_BottomArea, F-381).
    ///
    /// It starts shut. "Installed and active" is about the plugin, not about the furniture: taking a
    /// quarter of the window from someone who has never asked for a terminal is not a default anyone
    /// would choose, and one keystroke is a cheap way to ask. Once opened, the state is remembered.
    /// `wanted` is false for the housekeeping changes — closing an empty dock, reopening it once its
    /// plugin turns up — which must not rewrite what the user asked for. It follows `persist`, since
    /// "worth remembering" and "the user meant it" are the same set of calls.
    func setBottomDockVisible(_ visible: Bool, persist: Bool = true) {
        // Reopening restores the height it had, not the factory one — a dock the user shrank to a
        // four-line strip should come back as a four-line strip.
        dockHeightConstraint?.constant = visible ? preferredDockHeight : 0
        dockResizerHeightConstraint?.constant = visible ? DockResizeHandle.height : 0
        dockResizer.dockHeight = visible ? preferredDockHeight : 0
        bottomDock.isHidden = !visible          // no leftover sliver when collapsed
        dockResizer.isHidden = !visible
        setMenuCheck(cmd: "cm_BottomArea", on: visible)
        if visible { focusBottomDock() }
        if persist {
            dockWantedVisible = visible
            Task { await mainConfig.setBool(visible, "Layout", "DockVisible") }
        }
        updateTerminalMenuState()
    }

    /// Show or hide the bottom area (cm_BottomArea, F-381).
    ///
    /// Plain visibility, and generic: the area is a mount point any plugin view can be moved into, so
    /// this command is about the furniture rather than about the terminal. Moving the keyboard is
    /// `cm_TerminalFocus`, which is what the shortcut is bound to and what people actually reach for
    /// — those were briefly the same command and the name fitted neither half.
    @objc func toggleBottomDock() { setBottomDockVisible(!bottomDockVisible) }

    /// Move the keyboard between the file panel and the terminal (cm_TerminalFocus, F-381).
    ///
    /// The most-used integration there is, so it must do the obvious thing from every state: closed →
    /// open it and go there; open with the cursor elsewhere → go there; already there → back to the
    /// panel. Coming back leaves the terminal on screen, because dismissing it mid-command is not what
    /// "let me look at the file list for a second" means.
    @objc func focusTerminal() {
        guard revealTerminal() != nil else {
            presentInfo(String(localized: "Terminal"), String(localized: "No terminal is open."))
            return
        }
        guard let window,
              let view = ViewContainerRegistry.shared.existingView(ofViewId: Self.terminalViewId) else { return }
        // Already inside the terminal? Then this is the way back to the file list.
        if let first = window.firstResponder as? NSView, first === view || first.isDescendant(of: view) {
            if let back = activePanel?.contentResponder { window.makeFirstResponder(back) }
            return
        }
        window.makeFirstResponder(view)
    }

    /// The terminal plugin's view id. The host has commands of its own for this one view, so the id it
    /// asks the registry about is named once rather than spelled out at each call — and matching on
    /// "contains terminal" is gone with it: that also matched a plugin called *TerminalColours*.
    static let terminalViewId = "plugin.terminal.view"

    /// Is the terminal on screen right now — in whichever container it lives?
    var terminalIsShowing: Bool {
        switch ViewContainerRegistry.shared.container(ofViewId: Self.terminalViewId) {
        case "bottom":  return bottomDockVisible && bottomDock.selectedProviderId == Self.terminalViewId
        case "sidebar": return previewIsVisible && previewPanel.selectedPluginViewId == Self.terminalViewId
        default:        return false
        }
    }

    /// Bring the terminal on screen wherever it lives, and answer which container that was.
    ///
    /// Every terminal command used to open the *bottom dock* and select the terminal there, because that
    /// is where a terminal starts. Move it to the sidebar — which the placement menu invites — and each
    /// of them opened the empty dock instead and left the terminal where it was: the command appeared to
    /// do nothing while a blank strip took up the window (F-388). The container is a question with an
    /// answer, so it is asked.
    @discardableResult
    private func revealTerminal() -> String? { revealPluginView(id: Self.terminalViewId) }

    /// Open the container `viewId` is mounted in and select it there. Nil when it is not mounted.
    @discardableResult
    func revealPluginView(id viewId: String) -> String? {
        guard let container = ViewContainerRegistry.shared.container(ofViewId: viewId) else { return nil }
        switch container {
        case "bottom":
            if !bottomDockVisible { setBottomDockVisible(true) }
            bottomDock.selectProvider(id: viewId)
        case "sidebar":
            if !previewIsVisible { togglePreviewPanel() }
            previewPanel.selectPluginView(id: viewId)
        default:
            break   // "titlebar" and "settings" are always where they are; there is nothing to open
        }
        updateTerminalMenuState()
        return container
    }

    /// Show or hide the terminal (cm_TerminalToggle, F-388).
    ///
    /// The one thing the Terminal menu did not offer. Collapsing and expanding it was `View ▸ Bottom
    /// Area` — furniture named after the room, not after the terminal, in a different menu from
    /// everything else the terminal can do; reported as "I cannot find a way to fold the terminals in
    /// and out". Hiding it is *not* closing it: the shells keep running and the tabs come back as they
    /// were, which is the difference between a collapse and the close button on the dock.
    ///
    /// Showing also moves the keyboard there, since that is what asking for a terminal means. Hiding
    /// closes the container it lives in — the same gesture the user would make on the dock itself, and
    /// for the sidebar that is the panel: a terminal is what they put in it.
    @objc func toggleTerminal() {
        guard let container = ViewContainerRegistry.shared.container(ofViewId: Self.terminalViewId) else {
            presentInfo(String(localized: "Terminal"), String(localized: "No terminal is open."))
            return
        }
        guard terminalIsShowing else { focusTerminal(); return }
        switch container {
        case "bottom":  setBottomDockVisible(false)
        case "sidebar": if previewIsVisible { togglePreviewPanel() }
        default:        break
        }
        // The keyboard cannot stay in a view that is no longer on screen.
        if let back = activePanel?.contentResponder { window?.makeFirstResponder(back) }
        updateTerminalMenuState()
    }

    /// Keep the Terminal menu's checkmark telling the truth about what is on screen (F-388).
    func updateTerminalMenuState() { setMenuCheck(cmd: "cm_TerminalToggle", on: terminalIsShowing) }

    /// Open another terminal tab (cm_TerminalNewTab, F-381).
    @objc func terminalNewTab() { notifyTerminal(key: "newTab", value: "") }

    /// Split the terminal, or put it back together (cm_TerminalSplit, F-381).
    @objc func terminalSplit() { notifyTerminal(key: "toggleSplit", value: "") }

    // MARK: - The assistant's shell (F-381, plan §7)

    /// Marker the wrapper prints when the command is done, with its exit status after it.
    private static let shellDoneMarker = "__PC_RUN_SHELL_DONE__"

    /// Run `command` in a terminal tab the user can watch, and return what it printed.
    ///
    /// Visible on purpose. A hidden shell would be the same capability with the evidence removed; run
    /// in a tab, what the assistant did is on screen afterwards, in the user's own scrollback, beside
    /// everything else they ran that day. It is also a real terminal, so a command that asks a
    /// question — `sudo` wanting a password — can be answered instead of failing into a pipe.
    ///
    /// The tab runs a **non-interactive** shell. A login shell reads the user's dotfiles, and an alias
    /// or function there can make an approved command line mean something else entirely; the point of
    /// showing the command is that the text on screen is the text that ran.
    ///
    /// Output is teed to a file because a terminal's buffer is the plugin's and there is no way to
    /// read it back across the ABI. The approval dialog says so rather than leaving the user to
    /// discover that the line they approved had two more clauses on it.
    func runShellVisibly(_ command: String) async throws -> String {
        guard ViewContainerRegistry.shared.container(ofViewId: "plugin.terminal.view") != nil else {
            throw AutomationError.notImplemented("no terminal plugin is loaded")
        }
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-run-shell-\(UUID().uuidString).log")
        let quoted = ShellQuoting.quote(file.path)
        // `pipestatus[1]` and not `$?`: with `tee` on the end, `$?` is tee's status and would report
        // success for a command that failed.
        let wrapped = "\(command) 2>&1 | tee \(quoted); "
            + "printf '\\n\(Self.shellDoneMarker)%s\\n' \"${pipestatus[1]}\" >> \(quoted)"

        revealTerminal()
        guard ViewContainerRegistry.shared.notifyView(viewId: Self.terminalViewId,
                                                      key: "runInNewTab", value: wrapped) else {
            throw AutomationError.notImplemented("the terminal view is not open")
        }

        // Poll for the marker. A command that never finishes is a real possibility — the assistant
        // may have started a server — so this gives up after a while and says what it saw rather than
        // hanging the conversation.
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            guard let range = text.range(of: Self.shellDoneMarker) else { continue }
            let output = String(text[text.startIndex..<range.lowerBound])
            let status = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            try? FileManager.default.removeItem(at: file)
            return output + "\n[exit status \(status)]"
        }
        let sofar = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        return sofar + "\n[still running after 60 s — the terminal tab is open]"
    }

    /// Close the terminal tab that is showing (cm_TerminalCloseTab, F-381).
    ///
    /// The plugin asks first when something is running in it; the host does not second-guess that.
    @objc func terminalCloseTab() { notifyTerminal(key: "closeCurrentTab", value: "") }

    /// Ask the terminal to do something, opening and focusing it first.
    ///
    /// The host does not know what a tab is — that is the plugin's word — so these commands are a
    /// message rather than a call. The same channel carries "cd here" and the dropped file names.
    private func notifyTerminal(key: String, value: String) {
        guard revealTerminal() != nil else {
            presentInfo(String(localized: "Terminal"), String(localized: "No terminal is open."))
            return
        }
        _ = ViewContainerRegistry.shared.notifyView(viewId: Self.terminalViewId, key: key, value: value)
    }

    /// Put the keyboard into the docked view, or back into the panel if it is already there.
    ///
    /// This is the gesture the whole dock is for: one key between navigating files and typing at a
    /// prompt, landing back where the cursor was. Toggling rather than always-focusing means the same
    /// key gets you out again, which is what makes it usable without thinking.
    func focusBottomDock() {
        guard bottomDockVisible, let content = bottomDock.visibleContentView else { return }
        guard let window else { return }
        // Already inside the dock? Then this is the way back to the file list.
        if let first = window.firstResponder as? NSView,
           first === content || first.isDescendant(of: content) {
            if let back = activePanel?.contentResponder { window.makeFirstResponder(back) }
            return
        }
        window.makeFirstResponder(content)
    }

    // MARK: - Where the user put things (F-381)

    /// Read the placement overrides out of preferences and hand them to the registry.
    ///
    /// Called before the first refresh, so a view the user moved is mounted where they left it rather
    /// than appearing in its manifest's container and jumping.
    private func loadViewPlacements(_ config: ConfigSnapshot) {
        var placements: [String: String] = [:]
        for viewId in config.keys(inSection: ViewPlacement.section) {
            let container = config.string(ViewPlacement.section, viewId, default: "")
            if !container.isEmpty { placements[viewId] = container }
        }
        ViewContainerRegistry.shared.setPlacements(placements)
    }

    /// Write the placement overrides back, key by key.
    ///
    /// Removing what is gone matters as much as writing what is there: an override is *absent* when
    /// the view is in its default place, and a leftover key would mean the manifest could never take
    /// its default back — a plugin update that moved its own view would be silently overruled.
    private func persistViewPlacements(_ placements: [String: String]) {
        Task {
            let existing = await mainConfig.keys(inSection: ViewPlacement.section)
            for viewId in existing where placements[viewId] == nil {
                await mainConfig.remove(ViewPlacement.section, viewId)
            }
            for (viewId, container) in placements {
                await mainConfig.setString(container, ViewPlacement.section, viewId)
            }
            await mainConfig.flush()
        }
    }

    /// Put the window's furniture back the way it ships (cm_ResetLayout, F-381).
    ///
    /// In the menu rather than only in Settings, because the layout you cannot see is exactly the one
    /// you cannot repair from a dialog you also cannot see — a panel dragged somewhere useless, a dock
    /// pulled over the whole window.
    @objc func resetLayout() {
        ViewContainerRegistry.shared.resetPlacements(host: self)
        preferredDockHeight = BottomDockView.defaultHeight
        if bottomDockVisible { setBottomDockVisible(true) }   // re-apply the restored height
        setPreviewWidth(Self.previewWidth)
        Task {
            await mainConfig.setInt(Int(BottomDockView.defaultHeight), "Layout", "DockHeight")
            await mainConfig.setInt(Int(Self.previewWidth), "Layout", "PreviewWidth")
            await mainConfig.flush()
        }
    }

    /// Carry out a placement menu item (F-381).
    @objc func movePluginViewFromMenu(_ sender: NSMenuItem) {
        guard let request = sender.representedObject as? ViewPlacementRequest else { return }
        ViewContainerRegistry.shared.place(viewId: request.viewId, in: request.container, host: self)
        // Wherever it went, show it there. This used to name the dock and only the dock, so a view sent
        // to the sidebar arrived behind whichever tab was already showing — the move looked like it had
        // been ignored, or worse, like the view had been lost (F-388). `revealPluginView` is the same
        // call the drop path makes, so dragging a view somewhere and asking the menu to move it there
        // cannot mean two different things.
        revealPluginView(id: request.viewId)
    }

    // MARK: - Panel ↔ terminal (F-381, plan §7)

    /// Send a line to the docked terminal, opening and focusing the dock if it is not there yet.
    ///
    /// Returns false when nothing is listening — no terminal mounted, or its view never built — so a
    /// command can say so instead of appearing to work.
    @discardableResult
    private func sendToTerminal(_ text: String) -> Bool {
        guard revealTerminal() != nil else { return false }
        return ViewContainerRegistry.shared.notifyView(viewId: Self.terminalViewId,
                                                       key: "sendText", value: text)
    }

    /// Should the command line run in the embedded terminal? Persisted; off by default, because it
    /// changes where output appears and that should be the user's choice rather than a surprise.
    private(set) var runCommandLineInTerminal = false

    /// Flip it (cm_TerminalRunCommandLine, F-381).
    @objc func toggleRunCommandLineInTerminal() {
        runCommandLineInTerminal.toggle()
        setMenuCheck(cmd: "cm_TerminalRunCommandLine", on: runCommandLineInTerminal)
        Task { await mainConfig.setBool(runCommandLineInTerminal, "Terminal", "RunCommandLine") }
    }

    /// The original behaviour: run it detached and show whatever it printed.
    private func runCommandLineDetached(_ line: String, in cwd: String, panel: PanelController) async {
        let result = await ShellExecutor.run(line, workingDirectory: cwd)
        if let dir = result.changedDirectory {
            await panel.loadDirectory(dir)
        } else {
            await panel.reload()
            if !result.output.isEmpty { showShellOutput(command: line, output: result.output) }
        }
    }

    /// Take the terminal to the active panel's folder (cm_TerminalCdHere, F-381).
    ///
    /// A `cd` typed into the shell rather than anything clever, because the shell is the thing that
    /// knows what a directory means to it — and because a user watching the prompt change understands
    /// what happened. Quoted through ShellQuoting, which is measured against a real shell.
    @objc func terminalCdHere() {
        Task { @MainActor in
            guard let path = await activePanel?.getCurrentPath(), !path.isEmpty else { return }
            if !sendToTerminal("cd \(ShellQuoting.quote(path))\n") {
                presentInfo(String(localized: "Terminal"),
                            String(localized: "No terminal is open."))
            }
        }
    }

    /// Put the selected file names at the terminal's prompt (cm_TerminalSendNames, F-381).
    ///
    /// Inserted, not executed: the user is composing a command and the names are its arguments. This
    /// is the panel's "copy names to the command line" gesture pointed at the terminal instead, and it
    /// goes through the same quoting, so a file called `two words.txt` or `it's here` arrives as one
    /// argument rather than as several.
    @objc func terminalSendNames() {
        guard let panel = activePanel else { return }
        var paths = panel.tableView.selectedFilePaths()
        // Nothing marked means the file under the cursor, which is what every other command here does
        // and what anyone coming from Total Commander expects.
        if paths.isEmpty, let cursor = panel.tableView.cursorItemFullPath() { paths = [cursor] }
        guard !paths.isEmpty else { return }
        let line = paths.map { ShellQuoting.quote($0) }.joined(separator: " ")
        if !sendToTerminal(line + " ") {
            presentInfo(String(localized: "Terminal"), String(localized: "No terminal is open."))
        }
    }

    /// Set the dock's height while dragging; the divider reports values already clamped.
    private func setDockHeight(_ height: CGFloat) {
        guard let constraint = dockHeightConstraint else { return }
        constraint.constant = height
        preferredDockHeight = height
        dockResizer.dockHeight = height
    }

    /// Choose a folder in the shared tree, as clicking one does — the same callback, so a scenario
    /// exercises the real path rather than a shortcut around it.
    func sharedTreeAutomationSelect(_ path: String) { sharedTree.onSelect?(path) }

    /// Point the shared tree at the active panel's folder, without it navigating anything back.
    func revealActivePathInSharedTree() {
        guard sharedTreeVisible, let panel = activePanel else { return }
        Task { @MainActor in
            let path = await panel.getCurrentPath()
            // Only a local path is a folder in this tree; inside an archive or on a server there is
            // nothing here to point at, and pretending otherwise would jump the tree somewhere random.
            guard !panel.isInArchive, !path.isEmpty else { return }
            sharedTree.reveal(path: path)
        }
    }

    /// Toggle the active panel's folder-tree column (cm_SrcTree / Ctrl+F8, F-015).
    func toggleActivePanelTree() {
        guard let panel = activePanel else { return }
        panel.setTreeVisible(!panel.treeVisible)
        let key = (panel === leftPanelController) ? "LeftTree" : "RightTree"
        let visible = panel.treeVisible
        setMenuCheck(cmd: "cm_SrcTree", on: visible)
        Task { await mainConfig.setBool(visible, "Layout", key); await mainConfig.flush() }
    }

    /// Put a checkmark on the View-menu item matching the active panel's mode.
    private func markActiveViewMode() {
        guard let menu = NSApp.mainMenu, let mode = activePanel?.viewMode else { return }
        let map: [String: PanelViewMode] = ["cm_SrcLong": .details, "cm_SrcShort": .brief,
                                            "cm_SrcIcons": .icons, "cm_SrcThumbs": .gallery]
        let treeOn = activePanel?.treeVisible ?? false
        for top in menu.items {
            for item in top.submenu?.items ?? [] {
                if let cmd = item.representedObject as? String, let m = map[cmd] {
                    item.state = (m == mode) ? .on : .off
                }
                if (item.representedObject as? String) == "cm_SrcTree" {
                    item.state = treeOn ? .on : .off
                }
            }
        }
    }

    // MARK: - Window / split-view delegates (persist geometry)

    func windowDidResize(_ notification: Notification) { scheduleSaveState() }
    func windowDidMove(_ notification: Notification) { scheduleSaveState() }

    // MARK: - Menu / command dispatch

    /// The full main-window menu bar (cached so we can restore it when the main
    /// window regains focus after a tool window swapped in a minimal bar).
    private var fullMainMenu: NSMenu?
    /// Numeric TC command id → cm_ name, for resolving `.mnu` items (F-257).
    private var commandIdToName: [Int: String] = [:]
    /// The raw text of the user `.mnu` menu(s) last applied, to detect on-disk edits.
    private var lastMenuFileText: String?
    /// Retains the delegate that validates injected plugin menu items' `when`.
    private var contribMenuValidator: ContributionMenuValidator?
    /// Menu-bar menus contributed by external plugin windows (keyed by NSWindow),
    /// installed while that window is key. Auto-removed on window close.
    private var toolWindowMenus: [ObjectIdentifier: (edit: NSMenu?, content: NSMenu?, title: String)] = [:]

    /// Add the trailing titlebar accessory (once) that hosts the "titlebar"
    /// view container.
    private func installTitlebarAccessory() {
        window?.addTitlebarAccessoryViewController(titlebarAccessory)
    }

    /// Mount (or clear) the single titlebar view provider as the accessory's view.
    /// The accessory tracks the view's frame (autoresizing, not Auto Layout): the
    /// plugin seeds an initial size from `intrinsicContentSize` and resizes its own
    /// frame as content changes, since the accessory only measures fittingSize once.
    private func mountTitlebar(_ providers: [PreviewViewProvider]) {
        if let provider = providers.first, let view = provider.makeView() {
            view.translatesAutoresizingMaskIntoConstraints = true
            view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
            titlebarAccessory.view = view
        } else {
            titlebarAccessory.view = NSView(frame: .zero)   // empty → no width
        }
    }

    private func installMainMenu() {
        // The preview panel is the first named view container ("sidebar").
        ViewContainerRegistry.shared.register(container: "sidebar", acceptsMoves: true) { [weak self] providers in
            self?.previewPanel.setViewProviders(providers)
        }
        ViewContainerRegistry.shared.onPlacementsChanged = { [weak self] placements in
            self?.persistViewPlacements(placements)
        }
        let placementMenu: (String, String) -> NSMenu? = { [weak self] viewId, title in
            guard let self else { return nil }
            return ViewPlacementMenu.menu(forViewId: viewId, title: title, host: self, controller: self)
        }
        previewPanel.placementMenuProvider = placementMenu
        bottomDock.placementMenuProvider = placementMenu
        // Dropping a view onto a container moves it there — the same call the menu item makes, so the
        // two gestures cannot mean different things.
        previewPanel.onViewDropped = { [weak self] viewId in
            guard let self else { return }
            ViewContainerRegistry.shared.place(viewId: viewId, in: "sidebar", host: self)
            revealPluginView(id: viewId)
        }
        bottomDock.onViewDropped = { [weak self] viewId in
            guard let self else { return }
            ViewContainerRegistry.shared.place(viewId: viewId, in: "bottom", host: self)
            revealPluginView(id: viewId)
        }
        // The dock across the bottom of the window is the "bottom" view container (F-381), for the
        // plugins that need width rather than height — a terminal, a build log, a REPL.
        ViewContainerRegistry.shared.register(container: "bottom", acceptsMoves: true) { [weak self] providers in
            guard let self else { return }
            self.bottomDock.setViewProviders(providers)
            if let remembered = self.rememberedDockPanel { self.bottomDock.selectProvider(id: remembered) }
            // A dock left open by a plugin that has since been removed would be an empty frame with
            // an explanation nobody asked for; close it instead. And the other way round: the plugins
            // load *after* the configuration is applied, so on every launch this ran once with nothing
            // in it and shut a dock the user had left open — which is why "the terminal was open when I
            // quit" never survived a restart (F-388). `dockWantedVisible` remembers what was asked for,
            // as opposed to what is possible at this instant, so the dock comes back when its plugin
            // finally arrives and stays shut if the user shut it.
            if providers.isEmpty {
                if self.bottomDockVisible { self.setBottomDockVisible(false, persist: false) }
            } else if self.dockWantedVisible, !self.bottomDockVisible {
                self.setBottomDockVisible(true, persist: false)
            }
            self.updateTerminalMenuState()
        }
        // The trailing titlebar accessory is the "titlebar" view container.
        ViewContainerRegistry.shared.register(container: "titlebar") { [weak self] providers in
            self?.mountTitlebar(providers)
        }
        // Plugin settings panes are collected under "settings" and surfaced as extra
        // source-list pages in the Settings dialog (see showSettings()).
        ViewContainerRegistry.shared.register(container: "settings") { [weak self] providers in
            self?.settingsPaneProviders = providers
        }
        // Rebuild the menu bar AND refresh view containers whenever the set of
        // enabled plugin contributions changes.
        ContributionRegistry.shared.onChange = { [weak self] in
            guard let self else { return }
            self.rebuildMainMenu()
            ViewContainerRegistry.shared.refresh(host: self)
            // Plugins can be enabled/disabled at runtime, so the formatters they
            // contribute are rebuilt with the rest of their contributions.
            FormatterSetup.refreshPluginFormatters(host: self)
        }
        rebuildMainMenu()
        ViewContainerRegistry.shared.refresh(host: self)
        FormatterSetup.refreshUserFormatters(configRoot: configPaths.root)
        FormatterSetup.ensureTemplate(at: configPaths.formatters)
        FormatterSetup.refreshPluginFormatters(host: self)
        // Swap the whole bar when a tool window / the main window becomes key so tool
        // windows get a minimal, content-specific menu (TODOS: minimal tool menus).
        NotificationCenter.default.addObserver(self, selector: #selector(keyWindowChangedForMenu(_:)),
                                               name: NSWindow.didBecomeKeyNotification, object: nil)
        // Drop a plugin window's registered menus when it closes.
        NotificationCenter.default.addObserver(self, selector: #selector(toolWindowWillClose(_:)),
                                               name: NSWindow.willCloseNotification, object: nil)
    }

    @objc private func toolWindowWillClose(_ note: Notification) {
        guard let w = note.object as? NSWindow else { return }
        toolWindowMenus.removeValue(forKey: ObjectIdentifier(w))
    }

    /// Build the menu bar from AppMenu and inject the active plugins' menu
    /// contributions. Swaps the live bar only if the main bar is currently active
    /// (so a tool window's transient bar isn't clobbered).
    private func rebuildMainMenu() {
        let wasActive = fullMainMenu == nil || NSApp.mainMenu === fullMainMenu
        let menu: NSMenu
        if let menuFile = loadUserMenuFile() {
            // A user .mnu drives the command menus; App/Edit/Window/Help stay standard.
            let commandMenus = MnuMenuBuilder.build(
                roots: menuFile.roots, target: self, action: #selector(runMenuCommand(_:)),
                resolve: { [weak self] in self?.resolveMenuCommand($0) ?? $0 })
            menu = AppMenu.build(target: self, commandAction: #selector(runMenuCommand(_:)),
                                 commandMenus: commandMenus)
        } else {
            menu = AppMenu.build(target: self, commandAction: #selector(runMenuCommand(_:)))
        }
        contribMenuValidator = ContributionMenuInjector.inject(
            into: menu, registry: .shared, target: self, action: #selector(runMenuCommand(_:)),
            contextProvider: { [weak self] in self?.contributionContext() ?? ContributionContext() })
        fullMainMenu = menu
        if wasActive {
            AppMenu.dropDuplicateItems(in: menu)
            NSApp.mainMenu = menu
            bindStandardMenus(menu)
            Task { await applyKeymapToMenu() }
        }
    }

    /// Point NSApp.windowsMenu / helpMenu at the given bar's Window/Help submenus so
    /// AppKit fills in the window list and Help search for whichever bar is active.
    private func bindStandardMenus(_ menu: NSMenu) {
        NSApp.windowsMenu = menu.items.first { $0.submenu?.title == String(localized: "Window") }?.submenu
        NSApp.helpMenu = menu.items.first { $0.submenu?.title == String(localized: "Help") }?.submenu
    }

    @objc private func keyWindowChangedForMenu(_ note: Notification) {
        guard let window = note.object as? NSWindow else { return }
        if window !== self.window,
           let provider = window.windowController as? WindowContextMenuProviding {
            let tool = AppMenu.buildTool(menus: provider.toolMenus(),
                                         target: self, commandAction: #selector(runMenuCommand(_:)))
            AppMenu.dropDuplicateItems(in: tool)
            NSApp.mainMenu = tool
            bindStandardMenus(tool)
        } else if window !== self.window, let menus = toolWindowMenus[ObjectIdentifier(window)] {
            // External plugin window: install the menus it registered.
            let content = menus.content ?? NSMenu(title: menus.title)
            if !menus.title.isEmpty { content.title = menus.title }
            let tool = AppMenu.buildTool(editMenu: menus.edit ?? AppMenu.standardEditMenu(),
                                         contentMenu: content,
                                         target: self, commandAction: #selector(runMenuCommand(_:)))
            AppMenu.dropDuplicateItems(in: tool)
            NSApp.mainMenu = tool
            bindStandardMenus(tool)
        } else if window === self.window, let full = fullMainMenu {
            // Only the main window restores the full bar. Transient windows (a tool's
            // find dialog, alerts, sheets) leave the current bar in place so the menu
            // doesn't flip to the panel menu while a tool is still the user's context.
            AppMenu.dropDuplicateItems(in: full)
            NSApp.mainMenu = full
            bindStandardMenus(full)
        }
    }

    @objc private func runMenuCommand(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        runCommandNamed(name)
    }

    // MARK: - User main-menu file (.mnu, F-257)

    /// Whether the user has a `.mnu` override on disk (main file or menus/*.mnu).
    private var hasUserMenuFile: Bool { loadUserMenuFile() != nil }

    /// Concatenate the user's `default.mnu` (if any) with every `menus/*.mnu`
    /// (sorted), returning nil when the user has provided no menu file at all.
    private func loadUserMenuFile() -> MenuFile? {
        var text = ""
        if let main = try? String(contentsOf: configPaths.mainMenu, encoding: .utf8) { text += main + "\n" }
        if let extra = try? FileManager.default.contentsOfDirectory(
            at: configPaths.menusDirectory, includingPropertiesForKeys: nil) {
            for url in extra.filter({ $0.pathExtension.lowercased() == "mnu" })
                            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if let t = try? String(contentsOf: url, encoding: .utf8) { text += t + "\n" }
            }
        }
        lastMenuFileText = text.isEmpty ? nil : text
        guard !text.isEmpty else { return nil }
        let menu = MenuFile(parsing: text)
        return menu.roots.isEmpty ? nil : menu
    }

    /// Resolve a `.mnu` command token (numeric TC id or cm_/em_ name) to a cm_/em_
    /// name; unknown tokens pass through so KeymapMenu disables them.
    private func resolveMenuCommand(_ token: String) -> String {
        if token.hasPrefix("cm_") || token.hasPrefix("em_") { return token }
        if let id = Int(token), let name = commandIdToName[id] { return name }
        return token
    }

    /// Re-read the `.mnu` on app activation; rebuild the bar only if it changed.
    private func reloadMenuFileFromDisk() {
        let previous = lastMenuFileText
        _ = loadUserMenuFile()   // refreshes lastMenuFileText
        if lastMenuFileText != previous { rebuildMainMenu(); Task { await applyKeymapToMenu() } }
    }

    /// cm_ConfigMainMenu: seed a starter `default.mnu` if none exists, then open it in
    /// the app's built-in editor. Saving reloads the menu from disk immediately
    /// (passing a non-nil onSaved also forces the built-in editor rather than any
    /// per-extension external association).
    ///
    /// The starter is generated from the *live built-in menu*, so it is complete and
    /// already localized — opening the editor never silently drops menus or reverts
    /// captions to English. The user then edits a faithful copy. (Removing the file
    /// restores the built-in menu.)
    func showEditMainMenu() {
        let url = configPaths.mainMenu
        if !FileManager.default.fileExists(atPath: url.path) {
            try? generatedMenuFileText().write(to: url, atomically: true, encoding: .utf8)
        }
        openEditor(path: url.path, onSaved: { [weak self] in self?.reloadMenuFileFromDisk() })
    }

    /// Serialize the built-in command menus (everything except the standard App/Edit/
    /// Window/Help menus, which stay standard) into `.mnu` text with the current
    /// localized captions and cm_ names. Shortcuts stay keymap-driven, so no
    /// accelerators are written.
    private func generatedMenuFileText() -> String {
        let builtIn = AppMenu.build(target: self, commandAction: #selector(runMenuCommand(_:)))
        let skip: Set<String> = [String(localized: "Edit"), String(localized: "Window"), String(localized: "Help")]
        var roots: [MenuNode] = []
        for (index, item) in builtIn.items.enumerated() {
            if index == 0 { continue }                      // application menu
            guard let submenu = item.submenu, !skip.contains(submenu.title) else { continue }
            roots.append(.popup(caption: submenu.title, children: Self.menuNodes(from: submenu)))
        }
        let header = """
        ; Peach Commander menu file (Total Commander .mnu format).
        ; Generated from the built-in menu — edit freely; changes apply when the app
        ; is next activated. Reference commands by cm_ name or numeric id. Delete this
        ; file to restore the built-in menu. Extra menus/*.mnu files are appended.


        """
        return header + MenuFile(roots: roots).serialize()
    }

    /// Convert an NSMenu's items into `.mnu` nodes (separators, commands via their
    /// represented cm_ name, and nested submenus). Structural items with no command
    /// are skipped.
    private static func menuNodes(from menu: NSMenu) -> [MenuNode] {
        var nodes: [MenuNode] = []
        for item in menu.items {
            if item.isSeparatorItem { nodes.append(.separator); continue }
            if let submenu = item.submenu {
                nodes.append(.popup(caption: item.title, children: menuNodes(from: submenu)))
            } else if let cmd = item.representedObject as? String, !cmd.isEmpty {
                nodes.append(.command(caption: item.title, command: cmd))
            }
        }
        return nodes
    }

    /// Execute a command by name against the current active/inactive panels.
    /// Plugin-contributed commands are dispatched to their plugin first; built-in
    /// `cm_*` commands fall through to the CommandRegistry.
    func runCommandNamed(_ name: String) {
        Task { @MainActor in
            if ContributionRegistry.shared.canHandle(name) {
                _ = await ContributionRegistry.shared.dispatch(name, host: self)
                return
            }
            let context = CommandContext(
                activePanel: activePanel,
                inactivePanel: getInactivePanel(),
                windowController: self,
                selection: activePanel?.getSelectionState()
            )
            do { try await commandRegistry.execute(name, context: context) }
            catch { logger.error("Command \(name) failed: \(error)") }
        }
    }

    // MARK: - Start menu / user commands (I13 §4)

    private func loadUserCommands() {
        let text = (try? String(contentsOf: configPaths.userCommands, encoding: .utf8)) ?? ""
        userCommands = UserCommands(parsing: text)
        refreshStartMenu()
        if startMenuObserver == nil {
            startMenuObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.reloadUserCommandsFromDisk()
                self?.reloadMenuFileFromDisk()
            }
        }
    }

    private func reloadUserCommandsFromDisk() {
        let text = (try? String(contentsOf: configPaths.userCommands, encoding: .utf8)) ?? ""
        let parsed = UserCommands(parsing: text)
        guard parsed != userCommands else { return }
        userCommands = parsed
        refreshStartMenu()
    }

    /// Rebuild the Start menu's user-command items (kept above "Change Start Menu…").
    private func refreshStartMenu() {
        guard let startMenu = NSApp.mainMenu?.items.first(where: { $0.submenu?.title == "Start" })?.submenu
            ?? NSApp.mainMenu?.item(withTitle: "Start")?.submenu else { return }
        // Remove everything except the trailing "Change Start Menu…" command.
        let changeItem = startMenu.items.first { ($0.representedObject as? String) == "cm_ChangeStartMenu" }
        startMenu.removeAllItems()
        for cmd in userCommands.commands {
            let item = NSMenuItem(title: cmd.displayTitle, action: #selector(runUserCommandMenu(_:)), keyEquivalent: "")
            item.representedObject = cmd.name
            item.target = self
            startMenu.addItem(item)
        }
        if !userCommands.commands.isEmpty { startMenu.addItem(.separator()) }
        if let changeItem { startMenu.addItem(changeItem) }
    }

    @objc private func runUserCommandMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        runUserCommand(name)
    }

    func runUserCommand(_ name: String) {
        guard let cmd = userCommands.command(named: name) else {
            logger.error("Unknown user command: \(name)")
            return
        }
        if cmd.cmd.hasPrefix("cm_") { runCommandNamed(cmd.cmd); return }
        if cmd.cmd.hasPrefix("em_") { runUserCommand(cmd.cmd); return }
        Task { @MainActor in
            let ctx = await buildParamContext()
            let program = ParamExpander.expand(cmd.cmd, context: ctx, quoting: false)
            let params = ParamExpander.expand(cmd.param, context: ctx, listFile: { Self.makeListFile($0, ctx: ctx) })
            let workdir = cmd.path.isEmpty ? ctx.sourceDir : ParamExpander.expand(cmd.path, context: ctx, quoting: false)
            guard !program.isEmpty else { return }
            // Expanded unquoted so the `.app` test sees a real path. Quoted on the way into the line
            // only when the template actually substituted something: a literal template is the user's
            // own text and may legitimately be `ls -la`, but a program name that came out of `%N` is a
            // file name and must not be able to carry a command with it.
            let line = Self.commandLine(program: program, template: cmd.cmd, params: params)
            let result = await ShellExecutor.run(line, workingDirectory: workdir)
            if result.exitCode != 0 {
                self.logger.error("User command \(name) exited \(result.exitCode): \(result.output)")
            }
        }
    }

    /// Build the %-parameter context from the current panel state.
    private func buildParamContext() async -> ParamContext {
        let source = activePanel
        let target = getInactivePanel()
        let sourceDir = await source?.getCurrentPath() ?? ""
        let targetDir = await target?.getCurrentPath() ?? ""
        let cursorName = source?.tableView.cursorItemFullPath().map { ($0 as NSString).lastPathComponent } ?? ""
        let targetName = target?.tableView.cursorItemFullPath().map { ($0 as NSString).lastPathComponent } ?? ""
        let selected = await source?.getSelectionState().getSelectedPathList() ?? []
        let names = selected.map { ($0 as NSString).lastPathComponent }
        return ParamContext(sourceDir: sourceDir, cursorName: cursorName, targetDir: targetDir,
                            targetName: targetName, selectedNames: names)
    }

    /// Generate a temp list-file for %L/%F/%D/%W and return its path.
    private static func makeListFile(_ kind: ListFileKind, ctx: ParamContext) -> String {
        let names = ctx.selectedNames.isEmpty && !ctx.cursorName.isEmpty ? [ctx.cursorName] : ctx.selectedNames
        let lines: [String]
        switch kind {
        case .fullPaths:
            lines = names.map { (ctx.sourceDir as NSString).appendingPathComponent($0) }
        case .names, .dosNames, .withoutPath:
            lines = names
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-list-\(UUID().uuidString).txt")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    /// Assemble the shell line for a user command or toolbar button.
    ///
    /// `program` is the expanded (unquoted) command. It is quoted only when the expansion changed the
    /// template — i.e. a `%`-token was substituted, so the value is a file name rather than something
    /// the user typed. Quoting unconditionally would break the long-standing habit of putting a whole
    /// command such as `ls -la` in that field; not quoting at all would put a file name into a shell
    /// line raw, which is the defect this pair of rules exists to close (F-252).
    private static func commandLine(program: String, template: String, params: String) -> String {
        let isApp = program.hasSuffix(".app") || program.hasSuffix(".app/")
        if isApp { return "open -a \(shellQuote(program)) \(params)" }
        let head = program == template ? program : shellQuote(program)
        return "\(head) \(params)"
    }

    /// Double quotes were not enough here either: a shell substitutes `$(…)` and backticks *inside*
    /// them, so an app path containing either would have run. One implementation now (F-252).
    private static func shellQuote(_ s: String) -> String { ShellQuoting.quote(s) }

    // MARK: - Plugins (I14)

    private func loadPlugins() {
        // Wire each panel to resolve a plugin-backed VFS for an associated archive.
        let opener: (String) async -> VirtualFileSystem? = { [weak self] path in
            guard let self else { return nil }
            let ext = (path as NSString).pathExtension.lowercased()
            guard let plugin = await self.pluginManager.packerPlugin(forExtension: ext),
                  case .success(let lib) = PluginHost.openLibrary(plugin) else { return nil }
            return PCXArchiveFS(archivePath: path, library: lib, fsID: "pcx:\(path)")
        }
        leftPanelController?.resolvePluginArchive = opener
        rightPanelController?.resolvePluginArchive = opener

        // Pack dialog: offer enabled PCX packer plugins' formats (F-137).
        let formats: () async -> [(ext: String, label: String)] = { [weak self] in
            guard let self else { return [] }
            var out: [(ext: String, label: String)] = []
            for p in await self.pluginManager.enabledPlugins() where p.manifest.type == .pcx {
                // Only offer plugins that can actually pack.
                guard case .success(let lib) = PluginHost.openLibrary(p), PCXArchive(library: lib).canPack else { continue }
                for ext in p.manifest.extensions {
                    out.append((ext: ext, label: "\(p.manifest.name) (.\(ext))"))
                }
            }
            return out
        }
        // Perform a plugin pack: open the packer for the output extension and call PackFiles.
        let packer: (String, String, [String]) async -> Bool = { archivePath, sourceDir, files in
            let ext = (archivePath as NSString).pathExtension.lowercased()
            guard let plugin = await self.pluginManager.packerPlugin(forExtension: ext),
                  case .success(let lib) = PluginHost.openLibrary(plugin) else { return false }
            // pluginID scopes the crash guard's quarantine to this specific plugin (F-230).
            do { try PCXArchive(library: lib, pluginID: plugin.manifest.name)
                    .pack(archivePath: archivePath, sourceDir: sourceDir, files: files); return true }
            catch { self.logger.error("Plugin pack failed: \(error)"); return false }
        }
        for pc in [leftPanelController, rightPanelController] {
            pc?.packerPluginFormats = formats
            pc?.resolvePackerPack = packer
        }

        Task { @MainActor in
            await self.pluginManager.reload()
            // Teach the panels which extensions enabled packer plugins can browse.
            let exts = await self.pluginManager.enabledPlugins()
                .filter { $0.manifest.type == .pcx }
                .flatMap { $0.manifest.extensions }
            let set = Set(exts)
            if !set.isEmpty {
                self.leftPanelController?.tableView.addArchiveExtensions(set)
                self.rightPanelController?.tableView.addArchiveExtensions(set)
            }
            // User-configured extra archive extensions (F-274).
            self.applyExtraArchiveExtensions(await self.mainConfig.string("Pack", "ArchiveExtensions", default: ""))
        }
    }

    /// Register user-configured extra archive extensions on both panels (F-274).
    /// Space/comma-separated, dots stripped; additive (removals need a restart).
    func applyExtraArchiveExtensions(_ raw: String) {
        let set = Set(raw.split(whereSeparator: { $0 == " " || $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". \t")).lowercased() }
            .filter { !$0.isEmpty })
        guard !set.isEmpty else { return }
        leftPanelController?.tableView.addArchiveExtensions(set)
        rightPanelController?.tableView.addArchiveExtensions(set)
    }

    func showPluginsManager() {
        let win = PluginsWindowController()
        self.pluginsWindow = win
        win.onToggle = { [weak self] name, enabled in
            Task { @MainActor in
                await self?.pluginManager.setEnabled(name, enabled)
                self?.loadExternalPlugins()   // re-aggregate contributions → menus rebuild
                await self?.refreshPluginsWindow()
            }
        }
        win.onRemove = { [weak self] name in
            Task { @MainActor in
                await self?.pluginManager.remove(name: name)
                self?.loadExternalPlugins()
                await self?.refreshPluginsWindow()
            }
        }
        win.onInstallFolder = { [weak self] in
            guard let self, let window = win.window else { return }
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.zip]
            panel.message = String(localized: "Choose a plugin bundle or a .zip to install")
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                Task { @MainActor in
                    do {
                        if url.pathExtension.lowercased() == "zip" {
                            _ = try await self.pluginManager.installFromZip(zipURL: url)
                        } else {
                            _ = try await self.pluginManager.install(bundleURL: url)
                        }
                    } catch { self.presentInfo(String(localized: "Install failed"), "\(error)") }
                    self.loadExternalPlugins()
                    await self.refreshPluginsWindow()
                }
            }
        }
        win.onClose = { [weak self] in self?.pluginsWindow = nil }
        win.showWindow()
        Task { @MainActor in await refreshPluginsWindow() }
    }

    private func refreshPluginsWindow() async {
        let discovered = await pluginManager.discovered
        var rows: [PluginRow] = []
        for p in discovered {
            let enabled = await pluginManager.isEnabled(p.manifest.name)
            rows.append(PluginRow(name: p.manifest.name, type: p.manifest.type.rawValue,
                                  apiVersion: p.manifest.apiVersion, enabled: enabled, path: p.bundlePath))
        }
        pluginsWindow?.setRows(rows)
    }

    // MARK: - Keymap (I13 §5)

    /// Load the active key scheme from the app bundle plus the user's overrides.
    /// The resulting keymap is the single source for shortcut lookup / display;
    /// runtime routing and the Keys editor page are wired in a later step.
    func loadKeymap(scheme name: String) {
        let resource = name == "macos" ? "keymap-macos" : "keymap-tc-classic"
        currentKeyScheme = name == "macos" ? "macos" : "tc-classic"
        let schemeText = Bundle.main.url(forResource: resource, withExtension: "ini")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let userText = (try? String(contentsOf: configPaths.userKeymap, encoding: .utf8)) ?? ""
        keymap = Keymap(builtin: KeymapScheme(parsing: schemeText),
                        user: KeymapScheme(parsing: userText))
        logger.info("Keymap loaded: scheme=\(self.currentKeyScheme), \(self.keymap.effective.count) effective bindings")
    }

    #if DEBUG
    /// Diagnostic: put the keyboard in the command line, as clicking it does (F-381).
    /// - Parameter container: focus the command line *view* rather than its field editor. Reachable
    ///   in the real app, and the case that showed the `is NSText` rule was not enough on its own.
    func focusCommandLineForAutomation(container: Bool = false) {
        if container { window?.makeFirstResponder(commandLine) }
        else { commandLine.focusFieldForAutomation(in: window) }
    }

    /// Diagnostic: are the folder trees painted in the theme, in every palette (F-015)?
    ///
    /// Every combination rather than the one that was reported: the bug was a repaint nobody called,
    /// so any palette applied after the view was built looked wrong, and "it is fine in Dark" would
    /// have been an accident of which colours happen to be close. Both trees, because they are two
    /// instances of the same class reached by different routes, and only one of them was noticed.
    func dumpTreeColours(_ file: String) {
        func hex(_ c: NSColor) -> String {
            guard let rgb = c.usingColorSpace(.sRGB) else { return "?" }
            return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255),
                          Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
        }
        let original = themeId
        var lines: [String] = []
        for palette in Theme.palettes {
            themeId = palette.id
            applyAppearance(appearanceSetting)
            let expectedBackground = hex(Theme.current.listBackground)
            let expectedText = hex(Theme.current.listText)
            for (name, tree) in [("shared", sharedTree),
                                 ("panel", leftPanelController?.view.treeForAutomation)] {
                guard let tree else { continue }
                let actual = tree.automationColours
                let ok = hex(actual.background) == expectedBackground && hex(actual.text) == expectedText
                lines.append("\(palette.id)/\(name) want=\(expectedBackground)/\(expectedText) "
                             + "got=\(hex(actual.background))/\(hex(actual.text)) \(ok ? "ok" : "WRONG")")
                // And a row opened after the switch, which is vended from the reuse pool rather than
                // rebuilt by the reload — the half of the fix the visible rows do not exercise.
                let opened = hex(tree.automationColourOfRowOpenedLater)
                lines.append("\(palette.id)/\(name)/opened want=\(expectedText) got=\(opened) "
                             + "\(opened == expectedText ? "ok" : "WRONG")")
            }
        }
        themeId = original
        applyAppearance(appearanceSetting)
        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
    }

    /// Diagnostic: every visible window's surfaces, in every palette (F-015).
    ///
    /// Broader than `dumpTreeColours` on purpose. That one knows what the tree should be and checks
    /// it; this one knows nothing about any particular widget and instead reports surfaces that
    /// violate the two properties the tree defect violated — a bright box in a dark window, and text
    /// too close in colour to what is behind it. Whatever it lists is then judged one at a time; a
    /// bright surface is not automatically a defect.
    ///
    /// All windows rather than this one, so a scenario can open the viewer, the editor or a dialog
    /// first and have it audited without this knowing such things exist.
    func dumpSurfaceColours(_ file: String) {
        let original = themeId
        var lines: [String] = []
        var audited = 0
        for palette in Theme.palettes {
            themeId = palette.id
            applyAppearance(appearanceSetting)
            for window in NSApp.windows where window.isVisible {
                // Lay out before reading, for the same reason the tree probe does: a repaint that
                // has only been *requested* has not happened yet, and reading early reports the
                // colour from before the switch as though the switch had failed.
                window.contentView?.layoutSubtreeIfNeeded()
                let name = window.title.isEmpty ? String(describing: type(of: window)) : window.title
                audited += 1
                lines += SurfaceColourAudit.audit(window: window,
                                                  label: "\(palette.id)/\(name)").map(\.line)
            }
            // Both container tab strips show one view at a time, so a single pass sees one plugin
            // view and misses every other installed one. Visiting each in turn is the difference
            // between "the terminal is fine" and "the plugin views are fine".
            lines += auditHiddenTabs(palette: palette.id, audited: &audited)
        }
        themeId = original
        applyAppearance(appearanceSetting)
        // Last line, and it carries the window count: an empty findings list means "nothing found"
        // only if something was actually looked at, and a scenario that opened no window would
        // otherwise produce a clean report by doing nothing.
        lines.append("windows=\(audited) findings=\(lines.count)")
        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
    }

    /// Every plugin view that is mounted but currently behind another tab, brought to the front one
    /// at a time and audited (F-015).
    ///
    /// The selection is put back afterwards, so the scenario's screenshot shows what it would have
    /// shown anyway and a later step is not surprised by a tab it did not choose.
    private func auditHiddenTabs(palette: String, audited: inout Int) -> [String] {
        guard let window else { return [] }
        var lines: [String] = []

        func sweep(_ names: [String], label: String, select: (String) -> Void) {
            for name in names {
                select(name)
                window.contentView?.layoutSubtreeIfNeeded()
                audited += 1
                lines += SurfaceColourAudit.audit(window: window,
                                                  label: "\(palette)/\(label):\(name)").map(\.line)
            }
        }

        if let panel = previewPanelForAutomation() {
            let restore = panel.automationSelectedTab
            sweep(panel.automationTabTitles, label: "side") { panel.automationSelectTab(titled: $0) }
            panel.automationSelectTab(titled: restore)
        }
        if let dock = bottomDockForAutomation() {
            let ids = dock.providerIds
            let restore = ids.first
            sweep(ids, label: "dock") { _ = dock.selectProvider(id: $0) }
            if let restore { _ = dock.selectProvider(id: restore) }
        }
        window.contentView?.layoutSubtreeIfNeeded()
        return lines
    }

    /// Diagnostic: the function-key bar, to ask whether it is claiming keys it does not have (F-381).
    func functionKeyBarForAutomation() -> FunctionKeyBar? { functionKeyBar }

    /// Diagnostic: run a command line, as pressing Return in it does (F-381).
    func runCommandLineForAutomation(_ line: String) { runCommandLine(line) }

    /// Diagnostic: send a key equivalent the way AppKit does — into the window's view hierarchy,
    /// which is where `performKeyEquivalent` is broadcast from (F-381).
    ///
    /// Calling the panel's method directly would prove nothing: the defect being guarded against is
    /// precisely that the *broadcast* reaches a view that should not act on it, and a direct call
    /// skips the broadcast.
    /// - Parameter viaMenu: consult the main menu first, as AppKit does. Off by default, and the
    ///   default is the interesting one: the raw-keyboard rule governs the *broadcast* to the view
    ///   hierarchy, and a chord that is also a menu shortcut — Ctrl+B is `cm_DirBranch` — is claimed
    ///   by the menu wherever the cursor is, which would drown the very distinction being measured.
    ///   Turn it on for a shortcut that only exists in the menu, such as Edit ▸ Find.
    @discardableResult
    func sendKeyEquivalentForAutomation(_ characters: String, flags: NSEvent.ModifierFlags,
                                        keyCode: UInt16 = 0, viaMenu: Bool = false) -> Bool {
        guard let window,
              let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                           timestamp: ProcessInfo.processInfo.systemUptime,
                                           windowNumber: window.windowNumber, context: nil,
                                           characters: characters,
                                           charactersIgnoringModifiers: characters,
                                           isARepeat: false, keyCode: keyCode) else { return false }
        if viaMenu, NSApp.mainMenu?.performKeyEquivalent(with: event) == true { return true }
        return window.contentView?.performKeyEquivalent(with: event) ?? false
    }
    #endif

    /// Keep the function-key bar honest about whose keys these are (F-381).
    ///
    /// Asked with a plain F5, because that is the key the question is about: whatever is focused
    /// either takes the function keys or it does not.
    func refreshFunctionKeyOwnership() {
        guard let window else { return }
        let probe = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                     timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                     characters: "\u{F708}", charactersIgnoringModifiers: "\u{F708}",
                                     isARepeat: false, keyCode: 0)
        functionKeyBar.keysAreOurs = !(probe.map { focusedViewWantsRawKeyboard($0) } ?? false)
    }

    /// Does the focused view consume this key itself, rather than the app turning it into a command?
    ///
    /// One question, asked at two depths. `PanelListView.performKeyEquivalent` is the broadcast
    /// boundary and has to refuse before `super` as well as before the keymap; `routeKeymap` is the
    /// function that turns a key into a command and refuses on its own account. Today the panel is
    /// the only caller of `routeKeymap`, so the second check never fires — it is there so that a
    /// future caller cannot route a key that the focused view had already claimed. Said plainly
    /// because a duplicated guard that is silently unreachable is worth knowing about.
    func focusedViewWantsRawKeyboard(_ event: NSEvent) -> Bool {
        // The way out is never the view's to keep. See RawKeyboard.reservedCommands.
        if let chord = KeymapMenu.chord(from: event), let cmd = keymap.command(for: chord),
           RawKeyboard.reservedCommands.contains(cmd) {
            return false
        }
        return RawKeyboard.wantsRaw(event, firstResponder: window?.firstResponder,
                                    rawViews: ViewContainerRegistry.shared.rawKeyboardViews())
    }

    /// Sync menu accelerators + enablement from the active keymap and registry.
    /// Only commands that are registered AND implemented enable their menu items.
    func applyKeymapToMenu() async {
        let enabled = Set(await commandRegistry.getAllCommands().filter { $0.implemented }.map { $0.name })
        implementedCommands = enabled
        guard let menu = NSApp.mainMenu else { return }
        KeymapMenu.apply(keymap, to: menu, registered: enabled)
        markActiveScheme()
    }

    /// Route a key event through the keymap. Conservative: only modified chords
    /// (Ctrl/Alt/Cmd) that map to an implemented command, and never while a text
    /// field is focused — bare keys/F-keys stay with the menu + panel keyDown.
    private func routeKeymap(_ event: NSEvent) -> Bool {
        // Whatever is focused gets first refusal (F-381). This asked `firstResponder is NSText`, which
        // covered the command line and nothing else — a plugin view holding a terminal is not an
        // NSText and would have had Ctrl+B taken by the directory branch.
        if focusedViewWantsRawKeyboard(event) { return false }
        let f = event.modifierFlags
        guard f.contains(.control) || f.contains(.option) || f.contains(.command) else { return false }
        guard let chord = KeymapMenu.chord(from: event) else { return false }
        // Plugin-contributed keybindings win over the built-in keymap.
        if let pluginCmd = ContributionRegistry.shared.keybindingCommand(for: chord, context: contributionContext()) {
            runCommandNamed(pluginCmd)
            return true
        }
        guard let cmd = keymap.command(for: chord) else { return false }
        if cmd.hasPrefix("em_") { runUserCommand(cmd); return true }
        guard implementedCommands.contains(cmd) else { return false }
        runCommandNamed(cmd)
        return true
    }

    /// Put a checkmark on the active keyboard-scheme menu item.
    private func markActiveScheme() {
        guard let menu = NSApp.mainMenu else { return }
        for top in menu.items {
            guard let sub = top.submenu else { continue }
            for item in sub.items {
                guard let schemeSub = item.submenu else { continue }
                for s in schemeSub.items {
                    if let cmd = s.representedObject as? String {
                        s.state = (cmd == "cm_ConfigKeyClassic" && currentKeyScheme == "tc-classic")
                               || (cmd == "cm_ConfigKeyMacOS" && currentKeyScheme == "macos") ? .on : .off
                    }
                }
            }
        }
    }

    func setKeyScheme(_ name: String) {
        Task { @MainActor in
            await mainConfig.setString(name, "Configuration", "KeyScheme")
            loadKeymap(scheme: name)
            await applyKeymapToMenu()
        }
    }

    func showCustomizeToolbar() {
        Task { @MainActor in
            // Load the full command catalog (name + help) so the editor's Command
            // dropdown lists every command with a description — previously it used
            // an empty cache unless the Keys editor had been opened first.
            let commands = await commandRegistry.getAllCommands().map { (name: $0.name, help: $0.help) }
            let editor = ButtonBarEditorWindowController(bar: self.buttonBar, commands: commands)
            editor.onSave = { [weak self] bar in
                guard let self else { return }
                self.buttonBar = bar
                self.saveButtonBar()
            }
            editor.onPickCommand = { [weak self] complete in self?.presentCommandPicker(onPick: complete) }   // F-255
            self.buttonBarEditor = editor
            editor.present()
        }
    }

    func showNotImplemented(_ name: String) {
        presentInfo(String(localized: "Not yet implemented"),
                    String(localized: "The command \(name) is planned but not available yet."))
    }

    // MARK: - Keys editor (I13 T06, F-254)

    private var commandCatalog: [(name: String, category: String, implemented: Bool)] = []

    func showKeysEditor() {
        Task { @MainActor in
            self.commandCatalog = await commandRegistry.getAllCommands()
                .map { ($0.name, $0.category, $0.implemented) }
            let win = KeysWindowController()
            self.keysWindow = win
            win.rowsProvider = { [weak self] in
                guard let self else { return [] }
                return self.commandCatalog
                    .map { KeyBindingRow(command: $0.name, category: $0.category,
                                         spec: self.keymap.chord(for: $0.name)?.spec ?? "",
                                         implemented: $0.implemented) }
            }
            win.onAssign = { [weak self] command, chord in
                guard let self else { return nil }
                let displaced = self.keymap.command(for: chord)
                self.keymap.setUserBinding(chord, to: command)
                self.persistUserKeymap()
                Task { @MainActor in await self.applyKeymapToMenu() }
                return displaced
            }
            win.onClear = { [weak self] command in
                guard let self, let chord = self.keymap.chord(for: command) else { return }
                self.keymap.setUserBinding(chord, to: "")   // suppress
                self.persistUserKeymap()
                Task { @MainActor in await self.applyKeymapToMenu() }
            }
            win.onRestoreDefaults = { [weak self] in
                guard let self else { return }
                try? FileManager.default.removeItem(at: self.configPaths.userKeymap)
                self.loadKeymap(scheme: self.currentKeyScheme)
                Task { @MainActor in await self.applyKeymapToMenu() }
            }
            win.onClose = { [weak self] in self?.keysWindow = nil }
            win.showWindow()
        }
    }

    private func persistUserKeymap() {
        try? keymap.userScheme.serialized().write(to: configPaths.userKeymap, atomically: true, encoding: .utf8)
    }

    func showCommandBrowser() {
        Task { @MainActor in
            let rows = await commandRegistry.getAllCommands()
                .map { CommandRow(name: $0.name, category: $0.category, help: $0.help, implemented: $0.implemented) }
            let win = CommandBrowserWindowController(commands: rows)
            self.commandBrowser = win
            win.onRun = { [weak self, weak win] name in
                win?.close()
                if name.hasPrefix("em_") { self?.runUserCommand(name) } else { self?.runCommandNamed(name) }
            }
            win.onClose = { [weak self] in self?.commandBrowser = nil }
            win.showWindow()
        }
    }

    /// Present the command browser as a modal "Choose command" picker (F-255):
    /// calls `onPick` with the chosen command name, used by the button-bar / keymap
    /// editors to fill a command field instead of running the command.
    func presentCommandPicker(onPick: @escaping (String) -> Void) {
        Task { @MainActor in
            let rows = await commandRegistry.getAllCommands()
                .map { CommandRow(name: $0.name, category: $0.category, help: $0.help, implemented: $0.implemented) }
            let win = CommandBrowserWindowController(commands: rows, runButtonTitle: String(localized: "Choose"))
            self.commandBrowser = win
            win.onRun = { [weak self, weak win] name in win?.close(); self?.commandBrowser = nil; onPick(name) }
            win.onClose = { [weak self] in self?.commandBrowser = nil }
            win.showWindow()
        }
    }

    // MARK: - Button bar (I13 §2)

    private func loadButtonBar() {
        let url = configPaths.buttonBar
        if !FileManager.default.fileExists(atPath: url.path) {
            try? Self.defaultButtonBar().serialize().write(to: url, atomically: true, encoding: .utf8)
        }
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        buttonBar = ButtonBar(parsing: text)
        buttonBarView.setBar(buttonBar)
        applyButtonBarThickness()
        buttonBarView.onRunButton = { [weak self] in self?.runBarButton($0) }
        buttonBarView.onEditBar = { [weak self] in self?.showCustomizeToolbar() }
        buttonBarView.onDropOnButton = { [weak self] button, files in self?.handleButtonDrop(button, files: files) }
        buttonBarView.onAddPrograms = { [weak self] files, index in self?.addBarButtons(for: files, at: index) }
    }

    // MARK: - Vertical button bar (F-011)

    /// Drive the active size constraint from the bar's preferred thickness (height
    /// when horizontal, width when vertical); the inactive one stays at 0.
    private func applyButtonBarThickness() {
        // Hidden collapses both constraints, so visibility flows through the one place that owns
        // the bar's size — a separate isHidden toggle would fight this on every relayout (F-342).
        let t = buttonBarVisible ? buttonBarView.preferredThickness : 0
        buttonBarView.isHidden = !buttonBarVisible
        buttonBarHeightConstraint?.constant = buttonBarVertical ? 0 : t
        buttonBarWidthConstraint?.constant = buttonBarVertical ? t : 0
    }

    /// Whether the button bar is shown (F-342). Persisted as [Layout] ButtonBar; default true, so
    /// an existing configuration is unchanged.
    var isButtonBarVisible: Bool { buttonBarVisible }

    func setButtonBarVisible(_ visible: Bool, persist: Bool = false) {
        buttonBarVisible = visible
        applyButtonBarThickness()
        setMenuCheck(cmd: "cm_ButtonBar", on: visible)
        guard persist else { return }
        Task { await mainConfig.setBool(visible, "Layout", "ButtonBar"); await mainConfig.flush() }
    }

    func toggleButtonBar() { setButtonBarVisible(!buttonBarVisible, persist: true) }

    var isButtonBarVertical: Bool { buttonBarVertical }

    /// Switch the button bar between the top strip and a left column (layout only;
    /// persistence lives in `toggleVerticalButtonBar` / the startup restore).
    func setButtonBarVertical(_ vertical: Bool) {
        guard vertical != buttonBarVertical else { return }
        buttonBarVertical = vertical
        NSLayoutConstraint.deactivate(vertical ? buttonBarGroupH : buttonBarGroupV)
        NSLayoutConstraint.activate(vertical ? buttonBarGroupV : buttonBarGroupH)
        buttonBarView.setVertical(vertical)
        applyButtonBarThickness()
        setMenuCheck(cmd: "cm_VerticalButtonBar", on: vertical)
    }

    func toggleVerticalButtonBar() {
        setButtonBarVertical(!buttonBarVertical)
        let value = buttonBarVertical
        Task { await mainConfig.setBool(value, "Layout", "ButtonBarVertical"); await mainConfig.flush() }
    }

    /// A small starter bar so the strip is useful out of the box.
    private static func defaultButtonBar() -> ButtonBar {
        func b(_ cmd: String, _ menu: String, _ sf: String) -> BarButton {
            BarButton(icon: "sf:\(sf)", cmd: cmd, menu: menu, iconic: true)
        }
        return ButtonBar(buttons: [
            b("cm_Copy", "Copy (F5)", "doc.on.doc"),
            b("cm_RenMov", "Move (F6)", "arrow.right.doc.on.clipboard"),
            b("cm_MkDir", "New Folder (F7)", "folder.badge.plus"),
            b("cm_PackFiles", "Pack", "archivebox"),
            BarButton(),
            b("cm_SearchFor", "Find Files", "magnifyingglass"),
            b("cm_MultiRenameFiles", "Multi-Rename", "character.cursor.ibeam"),
            b("cm_SyncDirs", "Synchronize", "arrow.triangle.2.circlepath"),
        ])
    }

    func runBarButton(_ button: BarButton) {
        let cmd = button.cmd
        if cmd.hasPrefix("cm_") { runCommandNamed(cmd); return }
        if cmd.hasPrefix("em_") { runUserCommand(cmd); return }
        if cmd.hasSuffix(".bar") {
            // Descend into the subbar (F-253). Resolve relative to the bar directory.
            let path = (cmd as NSString).isAbsolutePath
                ? cmd : configPaths.root.appendingPathComponent(cmd).path
            if let text = try? String(contentsOfFile: path, encoding: .utf8) {
                buttonBarView.enterSubbar(ButtonBar(parsing: text))
            } else {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))   // missing file → open for editing
            }
            return
        }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: cmd, isDirectory: &isDir), isDir.boolValue {
            Task { @MainActor in await activePanel?.loadDirectory(cmd) }
            return
        }
        // Treat as an external program with %-parameter expansion.
        Task { @MainActor in
            let ctx = await buildParamContext()
            self.runProgramButton(button, context: ctx)
        }
    }

    /// Run a bar button's external program against a specific parameter context
    /// (shared by click and drop-onto-button, F-067).
    private func runProgramButton(_ button: BarButton, context ctx: ParamContext) {
        let program = ParamExpander.expand(button.cmd, context: ctx, quoting: false)
        let params = ParamExpander.expand(button.param, context: ctx, listFile: { Self.makeListFile($0, ctx: ctx) })
        let workdir = button.path.isEmpty ? ctx.sourceDir : ParamExpander.expand(button.path, context: ctx, quoting: false)
        guard !program.isEmpty else { return }
        let line = Self.commandLine(program: program, template: button.cmd, params: params)
        Task { @MainActor in
            let result = await ShellExecutor.run(line, workingDirectory: workdir)
            if result.exitCode != 0 { self.logger.error("Button command exited \(result.exitCode): \(result.output)") }
        }
    }

    /// Handle files dropped onto a button-bar button (F-067). A directory button
    /// receives the files as a background copy into that folder; a program button
    /// runs with the dropped files as its %-parameter selection; other command
    /// kinds (cm_/em_/.bar) just run normally.
    /// Add buttons for programs, scripts or folders dropped on free bar space (F-342).
    ///
    /// The counterpart to dropping *onto* a button, which runs it with those files. Here the drop
    /// creates the button, which is how Total Commander has always let you put a tool on the bar
    /// without opening an editor first.
    func addBarButtons(for paths: [String], at index: Int) {
        var inserted = 0
        for path in paths {
            guard let button = Self.barButton(forDropped: path) else { continue }
            buttonBar.buttons.insert(button, at: min(index + inserted, buttonBar.buttons.count))
            inserted += 1
        }
        guard inserted > 0 else { return }
        saveButtonBar()
        logger.info("Button bar: added \(inserted) button(s) from a drop")
    }

    /// Turn a dropped path into a button, or nil if it is nothing we can run.
    ///
    /// A folder becomes a *navigation* button, matching what `runBarButton` already does with a
    /// directory command — and dropping files on it later copies them there, which is the
    /// behaviour that was already implemented for folder buttons.
    ///
    /// Everything else becomes a program button whose parameter defaults to `%S`, the selected
    /// names. That is the point of putting a tool on the bar: click it and it runs on what you
    /// have selected. The editor can clear it for a tool that should take no arguments.
    static func barButton(forDropped path: String) -> BarButton? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return nil }
        let ns = path as NSString
        let isApp = ns.pathExtension.lowercased() == "app"
        let name = FileManager.default.displayName(atPath: path)
        if isDir.boolValue && !isApp {
            return BarButton(icon: path, cmd: path, param: "", path: "", menu: name, iconic: true)
        }
        // A plain file has to be launchable: an app bundle, or something with an execute bit.
        guard isApp || fm.isExecutableFile(atPath: path) else { return nil }
        return BarButton(icon: path, cmd: path, param: "%S", path: "", menu: name, iconic: true)
    }

    /// Persist the bar and re-render the live strip. One place, so a drop and the editor cannot
    /// diverge — the editor used to write the file and then re-read it from disk, which meant two
    /// code paths for the same operation.
    func saveButtonBar() {
        try? buttonBar.serialize().write(to: configPaths.buttonBar, atomically: true, encoding: .utf8)
        buttonBarView.setBar(buttonBar)
        applyButtonBarThickness()
    }

    func handleButtonDrop(_ button: BarButton, files: [String]) {
        let cmd = button.cmd
        guard !files.isEmpty else { runBarButton(button); return }
        var isDir: ObjCBool = false
        if !cmd.hasPrefix("cm_"), !cmd.hasPrefix("em_"), !cmd.hasSuffix(".bar"),
           FileManager.default.fileExists(atPath: cmd, isDirectory: &isDir), isDir.boolValue {
            TransferManager.shared.enqueue(.copy(items: files, toDirectory: cmd, options: CopyOptions()),
                                           title: String(localized: "Copy \(files.count) → \((cmd as NSString).lastPathComponent)"))
            showTransferManager()
            return
        }
        if cmd.hasPrefix("cm_") || cmd.hasPrefix("em_") || cmd.hasSuffix(".bar") {
            runBarButton(button)
            return
        }
        // Program button: expand %-params against the dropped files as the selection.
        let dir = (files[0] as NSString).deletingLastPathComponent
        let ctx = ParamContext(sourceDir: dir,
                               cursorName: (files[0] as NSString).lastPathComponent,
                               selectedNames: files.map { ($0 as NSString).lastPathComponent })
        runProgramButton(button, context: ctx)
    }

    func showChangeStartMenu() {
        let url = configPaths.userCommands
        if !FileManager.default.fileExists(atPath: url.path) {
            let template = """
            ; Peach Commander user commands (Start menu). One [em_Name] section per command.
            ; Keys: cmd (program path, cm_ command, or em_ command), param (%P %N %T %M %S …),
            ;       path (start dir), menu (title shown in the Start menu), key (e.g. C+S+B).
            ;
            ; [em_OpenTerminalHere]
            ; cmd=open
            ; param=-a Terminal %P
            ; menu=Open Terminal Here

            """
            try? template.write(to: url, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(url)
    }
}

/// PanelColumn to PanelSortColumn conversion
extension PanelColumn {
    func toPanelSortColumn() -> PanelSortColumn {
        switch self {
        case .name: return .name
        case .ext: return .ext
        case .size: return .size
        case .date: return .date
        case .attr: return .name
        case .tag: return .name
        case .comment: return .name
        }
    }
}

/// Panel position enum
enum PanelPosition: String, CustomStringConvertible {
    case left
    case right
    var isLeft: Bool { self == .left }
    var description: String { rawValue }
}

/// Panel controller - manages a panel view with table view, model and selection.
@MainActor
final class PanelController: NSObject, PanelControllerProtocol {
    let logger = PCFoundationLogger.logger

    let position: PanelPosition
    private(set) lazy var view: PanelView = { PanelView(position: position, controller: self) }()
    private var fs: VirtualFileSystem = LocalFS()
    /// Mounted archive stack: each frame remembers the host fs + local return path — and the drive
    /// chip that was lit before this mount, so popping restores the same three things it saved.
    private var mountStack: [(fs: VirtualFileSystem, returnPath: String, archivePath: String,
                              driveVolume: Volume?)] = []
    /// The drive this panel is currently on when it is a mounted plugin volume, else nil. A plugin
    /// drive like TaskManager lists at its own "/", which no real volume owns and which names no
    /// disk the user could point at — so the bar, the tab and the path bar all take the drive from
    /// the mount rather than from the path. Restored to the enclosing mount's value on the way out.
    private var mountedDriveVolume: Volume?

    /// Record the drive this panel is now on, in the panel and in the tab showing it.
    ///
    /// Always both: the panel's copy is what the drive bar, the breadcrumb and the columns read
    /// right now, the tab's is what brings the drive back after a tab switch or a restart. A place
    /// that sets one without the other is a tab that outlives its drive, or a drive no tab returns
    /// to. The exception is `resetToLocalFS`, which unwinds *because* another tab is coming up and
    /// must not write its answer into that tab.
    private func setMountedDrive(_ volume: Volume?) {
        mountedDriveVolume = volume
        tabs.updateActive { $0.driveVolume = volume?.path }
    }
    /// Backing zip paths that are temp extractions of a nested archive (F-134);
    /// these are browse-only — edits would be lost, so they are not rewritten.
    private var tempExtractedArchives: Set<String> = []
    /// Repeating reload for a volatile mount (e.g. TaskManager); cancelled on
    /// leaving the mount or switching tabs. See `startVolatileAutoRefresh`.
    private var volatileRefreshTask: Task<Void, Never>?
    /// Consumes the current directory's change stream (F-361).
    private var watchTask: Task<Void, Never>?
    /// The archive file's identity when it was last parsed, while the panel is inside it (F-384).
    private var watchedArchiveStamp: FileStamp?
    private let model: DirectoryModel
    private let volumeManager: VolumeManager
    private let selectionState = SelectionState()
    /// App configuration (for operation options like confirm/trash).
    let config: ConfigStore
    /// Back/forward navigation history for this panel.
    private var history = NavigationHistory()
    /// Open tabs for this panel (at least one).
    private var tabs = PanelTabs(initial: PanelTabState(path: NSHomeDirectory()))

    /// A dialog currently being presented (retained while visible).
    private var activeDialog: NSWindowController?
    private var statusRefreshScheduled = false
    private var volumeLastPath: [String: String] = [:]
    private var driveBarPopulated = false
    private var cachedDriveVolumes: [Volume] = []
    /// What this panel's drive bar is showing. The eject command needs it and the panel is the only
    /// thing that has already asked the system.
    var driveVolumes: [Volume] { cachedDriveVolumes }

    /// Fired when persistable panel state changes (path, sort) — drives session save.
    var onStateChanged: (() -> Void)?
    /// Fired on cursor/selection change (drives Quick View follow).
    var onCursorChanged: (() -> Void)?

    /// Called by the view when the cursor or selection changed.
    func viewStateChanged() {
        scheduleStatusRefresh()
        view.syncGridCursor()
        onCursorChanged?()
    }

    var statusBar: StatusBarView { view.statusBar }
    var tableView: PanelListView { view.tableView }

    /// Per-panel view mode (details/brief/icons/gallery) — TODOS #58.
    var viewMode: PanelViewMode { view.viewMode }
    /// The panel's current folder path (for the Automation Core context snapshot).
    var directoryPath: String { view.currentPathValue }
    /// The view that should take keyboard focus for the current mode (table or grid).
    var contentResponder: NSView { view.currentContentView }
    func setViewMode(_ mode: PanelViewMode) { view.setViewMode(mode) }
    /// Cycle through all view modes (details → brief → icons → gallery).
    func cycleViewMode() { view.setViewMode(view.viewMode.next) }

    /// Whether the folder-tree column is shown (F-015).
    var treeVisible: Bool { view.isTreeVisible }
    func setTreeVisible(_ visible: Bool) { view.setTreeVisible(visible) }

    init(position: PanelPosition, config: ConfigStore) {
        self.position = position
        self.config = config
        self.model = DirectoryModel()
        self.volumeManager = VolumeManager()
        super.init()
        logger.info("PanelController initialized for \(position) panel")
        // Keep the drive bar live: repopulate it when volumes are mounted/ejected/
        // renamed (e.g. a DMG is attached after launch).
        let wc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification,
                     NSWorkspace.didRenameVolumeNotification] {
            wc.addObserver(self, selector: #selector(volumesChanged), name: name, object: nil)
        }
    }

    /// A volume was mounted/ejected/renamed — rebuild the drive bar on next refresh.
    @objc private func volumesChanged() {
        driveBarPopulated = false
        scheduleStatusRefresh()
    }

    /// Rebuild the drive bar on demand (e.g. after external PFX plugins register
    /// their contributed drives at startup).
    func reloadDriveBar() {
        driveBarPopulated = false
        scheduleStatusRefresh()
    }

    func getSelectionState() -> SelectionState { selectionState }

    /// Visible file paths + start index for the Lister (F3).
    func listerContext() -> (paths: [String], index: Int) { tableView.listerContext() }

    // MARK: - Up / archive navigation (I08/I09)

    /// Go up: parent directory within the current fs, or leave a mounted archive.
    /// Ctrl+PageUp: go up to the parent directory / leave the current archive.
    func goToParent() async { await goUp() }

    /// Ctrl+PageDown: enter the directory or archive (by content) under the cursor.
    func openDirUnderCursor() async { tableView.enterUnderCursor() }

    func goUp() async {
        let cur = await model.getPath()
        if !mountStack.isEmpty, cur == "/" {
            await exitArchive()
            return
        }
        let parent = (cur as NSString).deletingLastPathComponent
        guard parent != cur else { return }
        // Place the cursor on the folder we came out of, not at the top.
        let childName = (cur as NSString).lastPathComponent
        await loadPath(parent, recordHistory: true, focusName: childName)
        tabs.updateActive { $0.path = parent; $0.cursorName = childName }
        refreshTabBar()
    }

    /// Show search results as a virtual panel. When `inNewTab` (Feed to Listbox),
    /// it opens a NEW tab so the current tab's location is never disturbed; branch
    /// view mounts in place.
    func enterResults(_ paths: [String], inNewTab: Bool = true) async {
        if inNewTab { await openNewTab() }  // fresh tab (resets to LocalFS), current tab preserved
        let results = ResultsFS(paths: paths, fsID: "results")
        let hostPath = await model.getPath()
        mountStack.append((fs: fs, returnPath: hostPath, archivePath: hostPath,
                           driveVolume: mountedDriveVolume))
        fs = results
        // A results listing is not the drive it was gathered from: leaving the chip lit and the tab
        // named after the drive would say the panel is still showing it. The frame above holds the
        // drive, so coming back out lights it again.
        setMountedDrive(nil)
        await loadDirectory("/")
    }

    /// Branch view (Ctrl+B / Ctrl+Shift+B): flatten the current directory tree (or
    /// the selected items' trees) into a single flat listing via ResultsFS.
    @discardableResult
    func enterBranchView(selectedOnly: Bool) async -> Int? {
        var roots: [VFSPath]
        if selectedOnly {
            let sel = tableView.selectedItemPaths()
            guard !sel.isEmpty else { return nil }
            roots = sel.map { VFSPath(filesystemId: fs.scheme, path: $0) }
        } else {
            roots = [VFSPath(filesystemId: fs.scheme, path: await model.getPath())]
        }
        var files: [String] = []
        for root in roots {
            if let entry = try? await fs.stat(root), entry.kind != .directory {
                files.append(root.path)
            } else {
                files += await VFSTreeWalker.collectFiles(under: root, on: fs).map { $0.path }
            }
        }
        guard !files.isEmpty else { return nil }
        await enterResults(files, inNewTab: false)   // branch view replaces the current listing
        return files.count
    }

    /// Mount a network (FTP) file system in this panel and open `startPath`.
    /// Navigating up past its root pops back to the previous (local) location.
    ///
    /// `driveVolume` is set when the mount came from a drive-bar volume (a plugin drive such as
    /// TaskManager): that volume, not the path, is what the panel is showing while we are inside.
    func enterNetwork(_ networkFS: VirtualFileSystem, startPath: String,
                      driveVolume: Volume? = nil) async {
        let hostPath = await model.getPath()
        mountStack.append((fs: fs, returnPath: hostPath, archivePath: hostPath,
                           driveVolume: mountedDriveVolume))
        fs = networkFS
        // Before the load: loading is what refreshes the bar, the tab and the path bar, and setting
        // this afterwards would leave all three showing the old volume for as long as it takes.
        // nil for a mount that came from a dialog rather than a drive — an FTP site is not a chip.
        setMountedDrive(driveVolume)
        await loadDirectory(startPath.isEmpty ? "/" : startPath)
        // A content-providing PFX mount (e.g. TaskManager) publishes its own
        // columns and, when volatile, auto-refreshes cursor-stably.
        if let pfx = networkFS as? PFXFileSystem, !pfx.contentFields.isEmpty {
            (view.window?.windowController as? MainWindowController)?
                .panelDidEnterContentMount(pfx, panel: self)
        }
    }

    /// Reload the current directory while keeping the cursor on the same entry
    /// (matched by name) — used by volatile auto-refresh so the selection doesn't
    /// jump as the process list churns.
    func reloadPreservingCursor() async {
        let name = tableView.cursorEntryName()
        await loadPath(await model.getPath(), recordHistory: false, focusName: name)
    }

    /// Start a ~2s repeating reload for a volatile mount, cursor-stable. No-op if
    /// the current fs isn't a volatile PFX mount. Safe to call repeatedly.
    func startVolatileAutoRefresh() {
        stopVolatileAutoRefresh()
        guard (fs as? PFXFileSystem)?.isVolatile == true else { return }
        volatileRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, !Task.isCancelled,
                      (self.fs as? PFXFileSystem)?.isVolatile == true else { return }
                await self.reloadPreservingCursor()
            }
        }
    }

    func stopVolatileAutoRefresh() {
        volatileRefreshTask?.cancel()
        volatileRefreshTask = nil
    }

    /// Resolves a plugin-backed VFS for a local archive path (set by the window
    /// controller); consulted before the built-in zip reader.
    var resolvePluginArchive: ((String) async -> VirtualFileSystem?)?

    /// Formats offered by enabled PCX packer plugins (extension + label), for the
    /// Pack dialog (F-137). Set by the window controller.
    var packerPluginFormats: (() async -> [(ext: String, label: String)])?
    /// Perform a pack via a PCX packer plugin: (archivePath, sourceDir, relative
    /// file names) → success. Set by the window controller (F-137).
    var resolvePackerPack: ((String, String, [String]) async -> Bool)?

    /// Enter a browsable archive at `localPath`: try an associated packer plugin
    /// first, then the built-in zip reader, else open the file externally.
    func enterArchive(_ pathToOpen: String) async {
        var localPath = pathToOpen
        // Nested archive (F-134): when we're already inside an archive/network
        // mount, `pathToOpen` is a vpath, not a local file — extract the inner
        // archive to a temp file and open that.
        if !(fs is LocalFS) {
            let vpath = VFSPath(filesystemId: fs.scheme, path: pathToOpen)
            guard let tmp = (try? await fs.localFileIfAvailable(vpath)) ?? nil else {
                NSSound.beep()
                return
            }
            localPath = tmp.path
            tempExtractedArchives.insert(localPath)
        }
        if let pluginFS = await resolvePluginArchive?(localPath) {
            let hostPath = await model.getPath()
            mountStack.append((fs: fs, returnPath: hostPath, archivePath: localPath,
                               driveVolume: mountedDriveVolume))
            fs = pluginFS
            setMountedDrive(nil)   // an archive inside a drive is not that drive (see `enterResults`)
            await loadDirectory("/")
            return
        }
        guard let archive = ArchiveFS(archiveFileURL: URL(fileURLWithPath: localPath),
                                      fsID: "zip:\(localPath)") else {
            // Not a (readable) archive — e.g. Ctrl+PageDown on a plain file. Beep
            // rather than launching it in an external app.
            NSSound.beep()
            return
        }
        // Encrypted archive: use a remembered Keychain password or prompt (F-136).
        if archive.hasEncryptedEntries {
            _ = resolveArchivePassword(for: archive, localPath: localPath)
        }
        let hostPath = await model.getPath()
        mountStack.append((fs: fs, returnPath: hostPath, archivePath: localPath,
                           driveVolume: mountedDriveVolume))
        fs = archive
        setMountedDrive(nil)   // an archive inside a drive is not that drive (see `enterResults`)
        await loadDirectory("/")
    }

    /// True when the panel is browsing a non-local filesystem (e.g. inside an archive).
    var isInArchive: Bool { !(fs is LocalFS) }

    /// The filesystem this panel is currently browsing (LocalFS, ArchiveFS, or a
    /// network/plugin FS) — used to run searches over the current mount (F-153).
    var currentFileSystem: VirtualFileSystem { fs }

    /// Whether this panel is on something that has to be uploaded to rather than copied into (F-367).
    ///
    /// An archive is deliberately not included: it has its own rewrite path (F-133), and
    /// `currentArchiveZipPath` is what the copy command checks first.
    var isOnNetworkFilesystem: Bool { fs is ResumableFileUploading }

    /// The backing .zip path when this panel is inside a rewritable zip archive
    /// (nil for plugin/network filesystems, which are not rewritten here). F-133.
    var currentArchiveZipPath: String? {
        guard fs is ArchiveFS, let top = mountStack.last,
              !tempExtractedArchives.contains(top.archivePath) else { return nil }
        return top.archivePath
    }

    /// Re-parse the current zip from disk and reload the current subpath (used
    /// after an in-archive edit). Falls back to the archive root if the subpath
    /// is gone.
    func reloadCurrentArchive() async {
        guard let zip = mountStack.last?.archivePath,
              let fresh = ArchiveFS(archiveFileURL: URL(fileURLWithPath: zip), fsID: "zip:\(zip)") else { return }
        let sub = await model.getPath()
        fs = fresh
        watchedArchiveStamp = FileStamp.of(zip)
        await loadDirectory(sub)
    }

    /// A local path for the cursor file (extracting to temp when inside an archive).
    func localPathForCursor() async -> String? {
        guard let p = tableView.cursorItemFullPath() else { return nil }
        if fs is LocalFS { return p }
        let vpath = VFSPath(filesystemId: fs.scheme, path: p)
        guard let url = (try? await fs.localFileIfAvailable(vpath)) ?? nil else { return nil }
        return url.path
    }

    /// Extract items (archive-relative paths) from the current fs into a local dir.
    ///
    /// Nothing is written outside `destDir`. The names being turned into local paths come from the
    /// listing — a zip's central directory, or an FTP server's LIST — and a member called ".." walks
    /// the write up into the parent folder; `PathContainment` is where that is spelled out, and the
    /// archive extractor asks it the same question. A refused name is skipped, not fatal: the honest
    /// members beside it still arrive.
    func extractItems(_ items: [String], to destDir: String) async {
        for item in items {
            let name = (item as NSString).lastPathComponent
            guard let dest = PathContainment.childPath(name, under: destDir, root: destDir) else {
                logger.error("refused to extract \(name, privacy: .public): it would leave the destination")
                continue
            }
            await extractNode(item, to: dest, root: destDir)
        }
    }

    private func extractNode(_ archivePath: String, to destPath: String, root: String) async {
        let vpath = VFSPath(filesystemId: fs.scheme, path: archivePath)
        guard let entry = try? await fs.stat(vpath) else { return }
        if entry.kind == .directory {
            try? FileManager.default.createDirectory(atPath: destPath, withIntermediateDirectories: true)
            do {
                for try await batch in fs.list(vpath) {
                    for child in batch.entries {
                        guard let childDest = PathContainment.childPath(child.name, under: destPath,
                                                                        root: root) else {
                            logger.error("refused \(child.name, privacy: .public): it would leave the destination")
                            continue
                        }
                        await extractNode((archivePath as NSString).appendingPathComponent(child.name),
                                          to: childDest, root: root)
                    }
                }
            } catch { logger.error("extract list failed: \(error)") }
        } else if let resumable = fs as? ResumableFileDownloading {
            // Straight to the destination, and continuing a partial file when there is one (F-212).
            // The generic path below loads the whole file into memory, writes a temp copy and then copies
            // that to the destination — three times the work, and no way to resume a 4 GB download that
            // stopped at 99 %.
            do {
                let result = try await resumable.downloadFile(vpath, to: URL(fileURLWithPath: destPath),
                                                              resume: true)
                if result.resumedAt > 0 {
                    logger.info("resumed \(destPath, privacy: .public) at \(result.resumedAt) bytes")
                }
            } catch {
                logger.error("download failed: \(error)")
            }
        } else if let url = try? await fs.localFileIfAvailable(vpath) {
            try? FileManager.default.removeItem(atPath: destPath)
            try? FileManager.default.copyItem(atPath: url.path, toPath: destPath)
        }
    }

    private func exitArchive() async {
        guard let frame = mountStack.popLast() else { return }
        let wasContentMount = (fs as? PFXFileSystem)?.contentFields.isEmpty == false
        // Tear down a live network connection (FTP keep-alive/control, SSH session)
        // when leaving its mount so it doesn't leak.
        if let net = fs as? DisconnectableFileSystem { await net.disconnect() }
        fs = frame.fs
        // Left the drive, so neither the panel nor the tab is on it any more — otherwise the next
        // tab switch or restart would put the user back inside a drive they walked out of.
        setMountedDrive(frame.driveVolume)
        await loadDirectory(frame.returnPath)
        tableView.focusEntry(named: (frame.archivePath as NSString).lastPathComponent)
        if wasContentMount {
            (view.window?.windowController as? MainWindowController)?.panelDidLeaveContentMount(panel: self)
        }
    }

    /// Leave the current network mount (cm_FtpDisconnect): disconnect and pop back
    /// to the host filesystem. No-op when not on a network mount.
    func leaveNetworkMount() async {
        guard fs is DisconnectableFileSystem else { return }
        await exitArchive()
    }

    /// Reset to the local filesystem (used when switching tabs — tabs are local).
    private func resetToLocalFS() {
        stopVolatileAutoRefresh()
        if !mountStack.isEmpty || !(fs is LocalFS) {
            // Disconnect any live network filesystems on the way out (current + stacked).
            let toClose = ([fs] + mountStack.map { $0.fs }).compactMap { $0 as? DisconnectableFileSystem }
            if !toClose.isEmpty { Task { for net in toClose { await net.disconnect() } } }
            fs = mountStack.first?.fs ?? LocalFS()
            mountedDriveVolume = mountStack.first?.driveVolume
            mountStack.removeAll()
        }
    }

    // MARK: - Loading / sorting

    func loadDirectory(_ path: String) async {
        await loadDirectory(path, recordHistory: true)
    }

    /// User navigation within the active tab: loads and syncs the active tab's path.
    /// A locked tab keeps its directory — navigating it opens a new (unlocked) tab
    /// instead (TC parity, when enabled on the Options "Tabs" page).
    func loadDirectory(_ path: String, recordHistory: Bool) async {
        if tabLockedOpensNewTab, tabs.active.locked, path != tabs.active.path {
            let cur = tabs.active
            captureCursorIntoActiveTab()
            tabs.open(PanelTabState(path: path, sortColumn: cur.sortColumn, sortAscending: cur.sortAscending),
                      activate: true)
            await switchToActiveTab()
            return
        }
        await loadPath(path, recordHistory: recordHistory, focusName: nil)
        tabs.updateActive { $0.path = path; $0.cursorName = nil }
        refreshTabBar()
    }

    /// Navigate to `path` and place the cursor on `name` (used to reveal a file
    /// after jumping to its parent folder).
    func loadDirectory(_ path: String, selecting name: String?) async {
        await loadPath(path, recordHistory: true, focusName: name)
        tabs.updateActive { $0.path = path; $0.cursorName = name }
        refreshTabBar()
    }

    /// Core loader — updates the view and history but does NOT touch the tab model.
    private func loadPath(_ path: String, recordHistory: Bool, focusName: String?) async {
        do {
            let snapshot = try await model.load(path, fs: fs)
            let volume = isInArchive ? nil : await volumeManager.getVolume(for: path)
            view.update(with: snapshot, volume: volume, rootLabel: mountedDriveVolume?.name)
            if let focusName { tableView.focusEntry(named: focusName) } else { tableView.focusParent() }
            if recordHistory { history.push(path) }
            scheduleStatusRefresh()
            onStateChanged?()
            startWatching(path)
        } catch {
            logger.error("Failed to load directory \(path): \(error)")
        }
    }

    func goBack() async {
        if let path = history.back() {
            await loadPath(path, recordHistory: false, focusName: nil)
            tabs.updateActive { $0.path = path }
            refreshTabBar()
        }
    }

    func goForward() async {
        if let path = history.forward() {
            await loadPath(path, recordHistory: false, focusName: nil)
            tabs.updateActive { $0.path = path }
            refreshTabBar()
        }
    }

    /// Snapshot of this panel's navigation history (for the Alt+Down list).
    var navigationHistory: NavigationHistory { history }

    /// Restore the back/forward stack from a persisted session.
    func restoreHistory(entries: [String], index: Int) {
        history = NavigationHistory(entries: entries, index: index)
    }

    /// Jump to a history entry by index (from the history dropdown).
    func goToHistoryIndex(_ i: Int) async {
        if let path = history.go(to: i) {
            await loadPath(path, recordHistory: false, focusName: nil)
            tabs.updateActive { $0.path = path }
            refreshTabBar()
        }
    }

    // MARK: - Tabs (I06-T01)

    /// The local directory this panel is anchored to: its current path, or — inside a mount, whose
    /// own root reads as "/" — the directory that mount was entered from. A new tab is local, so
    /// taking "/" from a mounted drive at face value would open it at the startup disk's root.
    private func localAnchorPath() async -> String {
        isInArchive ? (mountStack.first?.returnPath ?? NSHomeDirectory()) : await getCurrentPath()
    }

    func openNewTab() async {
        captureCursorIntoActiveTab()
        let path = await localAnchorPath()
        let cur = tabs.active
        tabs.open(PanelTabState(path: path, sortColumn: cur.sortColumn, sortAscending: cur.sortAscending),
                  activate: true)
        await switchToActiveTab()
    }

    /// Open a new tab for the current directory WITHOUT switching to it (F-008,
    /// cm_OpenNewTabBg). The active tab and its view stay put.
    func openNewTabInBackground() async {
        captureCursorIntoActiveTab()
        let cur = tabs.active
        tabs.open(PanelTabState(path: await localAnchorPath(), sortColumn: cur.sortColumn,
                                sortAscending: cur.sortAscending),
                  activate: false)
        refreshTabBar()
        onStateChanged?()
    }

    /// Close every tab except the active one (F-008, cm_CloseAllTabs).
    func closeAllTabs() async {
        await closeOtherTabs(exceptAt: tabs.activeIndex)
    }

    /// Reorder a tab by drag (F-008). The active tab stays active; no reload since
    /// the shown directory is unchanged.
    func reorderTab(from source: Int, to destination: Int) {
        guard source != destination else { return }
        captureCursorIntoActiveTab()
        tabs.move(from: source, to: destination)
        refreshTabBar()
        onStateChanged?()
    }

    /// Navigate this panel to `path` from a command-line launch parameter: either
    /// replacing the current tab or opening a fresh one (`-Tab`).
    func openFromLaunch(path: String, inNewTab: Bool) async {
        if inNewTab {
            captureCursorIntoActiveTab()
            let cur = tabs.active
            tabs.open(PanelTabState(path: path, sortColumn: cur.sortColumn, sortAscending: cur.sortAscending),
                      activate: true)
            await switchToActiveTab()
        } else {
            await loadDirectory(path)
        }
    }

    /// Open the directory under the cursor in a new tab (TC's Ctrl+↑). Falls back to
    /// the current directory when the cursor isn't on a folder.
    func openDirUnderCursorInNewTab() async {
        let path: String
        // Not inside a mount: an entry there is a process or a remote item, and its "directory
        // path" is a path in the mount that a local tab cannot open.
        if !isInArchive, let dir = tableView.cursorDirectoryPath() { path = dir }
        else { path = await localAnchorPath() }
        captureCursorIntoActiveTab()
        let cur = tabs.active
        // "Open in background" (Options → Tabs) keeps focus on the current tab.
        tabs.open(PanelTabState(path: path, sortColumn: cur.sortColumn, sortAscending: cur.sortAscending),
                  activate: tabOpenInForeground)
        if tabOpenInForeground { await switchToActiveTab() } else { refreshTabBar() }
    }

    func closeCurrentTab() async {
        guard tabs.count > 1 else { return }
        captureCursorIntoActiveTab()
        _ = tabs.closeActive()
        await switchToActiveTab()
    }

    func closeTab(at index: Int) async {
        guard tabs.count > 1 else { return }
        captureCursorIntoActiveTab()
        _ = tabs.close(at: index)
        await switchToActiveTab()
    }

    func selectTab(_ index: Int) async {
        captureCursorIntoActiveTab()
        tabs.select(index)
        await switchToActiveTab()
    }

    /// Open a new tab showing the same directory (+sort) as the tab at `index`.
    func duplicateTab(at index: Int) async {
        guard tabs.tabs.indices.contains(index) else { return }
        captureCursorIntoActiveTab()
        let src = tabs.tabs[index]
        // Including its drive: duplicating a tab that shows TaskManager and getting the startup
        // disk's root is not a duplicate of anything. A new tab, which is a different intent, stays
        // local — see `openNewTab`.
        tabs.open(PanelTabState(path: src.path, sortColumn: src.sortColumn, sortAscending: src.sortAscending,
                                driveVolume: src.driveVolume),
                  activate: true)
        await switchToActiveTab()
    }

    /// Close every tab except the one at `index`.
    func closeOtherTabs(exceptAt index: Int) async {
        guard tabs.count > 1, tabs.tabs.indices.contains(index) else { return }
        captureCursorIntoActiveTab()
        while tabs.count > index + 1 { _ = tabs.close(at: tabs.count - 1) }
        while tabs.count > 1 { _ = tabs.close(at: 0) }   // keeper shifts down to 0
        tabs.select(0)
        await switchToActiveTab()
    }

    // MARK: - Tab context menu (right-click a tab)

    private var contextTabIndex = 0

    func showTabContextMenu(_ index: Int, in view: NSView) {
        contextTabIndex = index
        let menu = NSMenu()
        func add(_ title: String, _ selector: Selector) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        add(String(localized: "New Tab"), #selector(ctxNewTab))
        add(String(localized: "Duplicate Tab"), #selector(ctxDuplicateTab))
        menu.addItem(.separator())
        add(String(localized: "Close Tab"), #selector(ctxCloseTab))
        add(String(localized: "Close Other Tabs"), #selector(ctxCloseOthers))
        menu.addItem(.separator())
        add(tabs.tabs.indices.contains(index) && tabs.tabs[index].locked
            ? String(localized: "Unlock Tab") : String(localized: "Lock Tab"), #selector(ctxToggleLock))
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }
    }

    @objc private func ctxNewTab() { Task { @MainActor in await openNewTab() } }
    @objc private func ctxDuplicateTab() { Task { @MainActor in await duplicateTab(at: contextTabIndex) } }
    @objc private func ctxCloseTab() { Task { @MainActor in await closeTab(at: contextTabIndex) } }
    @objc private func ctxCloseOthers() { Task { @MainActor in await closeOtherTabs(exceptAt: contextTabIndex) } }
    @objc private func ctxToggleLock() { Task { @MainActor in await selectTab(contextTabIndex); await toggleLockTab() } }

    func nextTab() async { captureCursorIntoActiveTab(); tabs.next(); await switchToActiveTab() }
    func prevTab() async { captureCursorIntoActiveTab(); tabs.previous(); await switchToActiveTab() }
    func toggleLockTab() async { tabs.toggleLockActive(); refreshTabBar(); onStateChanged?() }

    private func captureCursorIntoActiveTab() {
        tabs.updateActive { $0.cursorName = tableView.cursorEntryName() }
    }

    /// Load the active tab's path + sort + cursor — and re-mount its drive when the tab is on one.
    private func switchToActiveTab() async {
        resetToLocalFS()
        let tab = tabs.active
        let descriptor = Self.descriptor(from: tab.sortColumn, ascending: tab.sortAscending)
        await model.sort(by: descriptor)
        // The local path first, then the drive on top of it: the mount records where it was entered
        // from, so going up out of the restored drive lands in this tab's own directory rather than
        // wherever the panel happened to be standing.
        await loadPath(tab.path, recordHistory: true, focusName: tab.cursorName)
        if let sentinel = tab.driveVolume { await remountDrive(sentinel) }
        tableView.updateSortArrows(descriptor)
        refreshTabBar()
        onStateChanged?()
    }

    /// Re-enter the plugin drive a tab was left on (or restored with). A drive whose plugin is no
    /// longer loaded cannot be restored, and the tab stops claiming to be on one rather than
    /// carrying a name nothing can reach — otherwise it would keep the title of a drive that is not
    /// there for as long as the session lives.
    private func remountDrive(_ sentinel: String) async {
        guard sentinel.hasPrefix("pfxmount:"),
              let wc = view.window?.windowController as? MainWindowController else { return }
        let pluginId = String(sentinel.dropFirst("pfxmount:".count))
        // Not activating: restoring a tab must not decide which panel has the focus, and both
        // panels restore their tabs at startup — the second would silently win.
        if !wc.mountPluginVolume(pluginId: pluginId, into: self, activating: false) {
            tabs.updateActive { $0.driveVolume = nil }
        }
    }

    private func refreshTabBar() {
        // A tab on a plugin drive is titled with the drive, not with its path: that path is the
        // mount's own "/", which would title the tab "/" and claim the panel is at the startup
        // disk's root. Resolved through the registry rather than stored, so a renamed — or removed
        // — drive is not remembered under a name it no longer has.
        let titles = tabs.tabs.map { tab in
            tab.driveVolume.flatMap { Self.driveName(for: $0) } ?? Self.tabTitle(for: tab.path)
        }
        let locked = tabs.tabs.map { $0.locked }
        view.updateTabBar(titles: titles, activeIndex: tabs.activeIndex, locked: locked)
    }

    /// The display name of the drive-bar volume with this sentinel path, or nil if no loaded plugin
    /// contributes it any more.
    static func driveName(for sentinel: String) -> String? {
        FileSystemPluginRegistry.shared.driveVolumes().first { $0.path == sentinel }?.name
    }

    /// Export tabs for session persistence (captures the live cursor first).
    func exportTabs() -> (states: [PanelTabState], activeIndex: Int) {
        captureCursorIntoActiveTab()
        return (tabs.tabs, tabs.activeIndex)
    }

    /// Restore tabs from a saved session and display the active one.
    func importTabs(_ states: [PanelTabState], activeIndex: Int) async {
        guard !states.isEmpty else { return }
        tabs = PanelTabs(tabs: states, activeIndex: activeIndex)
        await switchToActiveTab()
    }

    static func descriptor(from column: String, ascending: Bool) -> DirectoryModel.SortDescriptor {
        switch column {
        case "ext": return .ext(ascending: ascending)
        case "size": return .size(ascending: ascending)
        case "date": return .date(ascending: ascending)
        default: return .name(ascending: ascending)
        }
    }

    static func tabTitle(for path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty || name == "/" ? "/" : name
    }

    // MARK: - Watch the current directory (F-361)

    /// Whether directory watching is wanted at all. Off is a legitimate choice: on a slow network
    /// mount or a folder something writes to constantly, a refresh per change is a nuisance.
    var watchDirectories = true

    /// Watch `path` and refresh this panel when its contents change.
    ///
    /// The filesystem decides whether it can be watched: `watch(_:)` yields a stream for a local
    /// directory and nil for an archive, an FTP site or a plugin mount — so the "local only" condition
    /// costs nothing here. Started after every load and replaced, so navigating away stops the old
    /// watcher instead of accumulating one per directory, which is what the previous version did.
    func startWatching(_ path: String) {
        stopWatching()
        guard watchDirectories else { return }
        if isInArchive { startWatchingArchiveFile(); return }
        guard let stream = fs.watch(VFSPath(filesystemId: fs.scheme, path: path)) else { return }
        watchTask = Task { @MainActor [weak self] in
            for await _ in stream {
                guard let self, !Task.isCancelled else { return }
                // Not while a dialog is up: a rename, an overwrite prompt or a properties sheet is
                // about the listing as it was when it opened, and re-listing underneath it changes
                // what the user is answering about.
                guard NSApp.modalWindow == nil else { continue }
                // Not while an in-cell rename is open — the field editor would be destroyed.
                guard !self.tableView.isInlineEditing else { continue }
                await self.reloadPreservingCursor()
            }
        }
    }

    /// Inside an archive there is nothing to watch — and yet there is: the listing on screen was
    /// parsed out of a local file, and that file can be watched even though the archive cannot (F-384).
    /// Another program rewriting the .zip, or this app doing it from a second window, otherwise leaves
    /// the panel showing members that no longer exist, and Enter on one of them fails for no visible
    /// reason.
    ///
    /// The watcher is on the *containing folder*, because that is what FSEvents watches, so it wakes
    /// for every sibling too. The stamp is what decides: only the archive's own bytes matter.
    private func startWatchingArchiveFile() {
        guard let archive = currentArchiveZipPath else { return }
        let folder = (archive as NSString).deletingLastPathComponent
        guard let stream = LocalFS().watch(LocalFS.path(folder)) else { return }
        watchedArchiveStamp = FileStamp.of(archive)
        watchTask = Task { @MainActor [weak self] in
            for await _ in stream {
                guard let self, !Task.isCancelled else { return }
                guard NSApp.modalWindow == nil, !self.tableView.isInlineEditing else { continue }
                let now = FileStamp.of(archive)
                guard now != self.watchedArchiveStamp else { continue }
                self.watchedArchiveStamp = now
                // Gone rather than rewritten: leave what is on screen. Re-parsing nothing would empty
                // the panel, and the file may be a moment away from being renamed back into place.
                guard now != nil else { continue }
                await self.reloadCurrentArchive()
            }
        }
    }

    func stopWatching() {
        watchTask?.cancel()
        watchTask = nil
        watchedArchiveStamp = nil
    }

    func getCurrentPath() async -> String { await model.getPath() }

    // MARK: - Checksums (I17-T04)

    /// Compute the checksum listing for the selected files (cursor file if none
    /// selected) and return it as text plus a suggested output filename — the
    /// caller decides whether to save it or copy it to the clipboard.
    func checksumText(algorithm: ChecksumAlgorithm) async
        -> (text: String, suggestedName: String, directory: String?)? {
        let selected = tableView.selectedFilePaths()
        let picks = selected.isEmpty ? (tableView.cursorItemFullPath().map { [$0] } ?? []) : selected
        let names = picks.map { ($0 as NSString).lastPathComponent }.filter { $0 != ".." && !$0.isEmpty }
        guard !names.isEmpty else { return nil }
        let dir = await model.getPath()
        let baseDir = VFSPath(filesystemId: fs.scheme, path: dir)
        let entries = await ChecksumEngine.create(filenames: names, baseDir: baseDir, on: fs, algorithm: algorithm)
        guard !entries.isEmpty else { return nil }
        let text = ChecksumFile.generate(entries, format: .for(algorithm))
        let suggested = names.count == 1
            ? "\(names[0]).\(algorithm.fileExtension)"
            : "checksums.\(algorithm.fileExtension)"
        return (text, suggested, (fs is LocalFS) ? dir : nil)
    }

    /// Verify the checksum file under the cursor against the files in its directory.
    func verifyChecksumsUnderCursor() async -> (fileName: String, results: [ChecksumEngine.VerifyResult])? {
        guard let path = tableView.cursorItemFullPath() else { return nil }
        let ext = (path as NSString).pathExtension
        let algo = ChecksumEngine.algorithm(forExtension: ext)
        guard let data = await readAllData(VFSPath(filesystemId: fs.scheme, path: path)) else { return nil }
        let entries = ChecksumFile.parse(String(decoding: data, as: UTF8.self), format: .for(algo))
        guard !entries.isEmpty else { return nil }
        let baseDir = VFSPath(filesystemId: fs.scheme, path: await model.getPath())
        let results = await ChecksumEngine.verify(entries, baseDir: baseDir, on: fs, algorithm: algo)
        return ((path as NSString).lastPathComponent, results)
    }

    /// Scan the current directory tree for byte-identical duplicate files,
    /// preserving the group structure. `isLocal` says whether the mount's paths
    /// are real local files (so the results window may offer deletion).
    func findDuplicateGroups() async -> (groups: [DuplicateGroup], isLocal: Bool)? {
        let dir = VFSPath(filesystemId: fs.scheme, path: await model.getPath())
        let files = await DuplicateFinder.collectFiles(under: dir, on: fs)
        guard !files.isEmpty else { return nil }
        let groups = await DuplicateFinder.find(paths: files, on: fs)
        return (groups, fs is LocalFS)
    }

    /// Read the whole cursor file into memory (name + bytes) so the caller can
    /// encode it and route the result to a file or the clipboard. Guards against
    /// absurdly large inputs. `directory` is the local folder (nil off local disk).
    func cursorFileData() async -> (name: String, data: Data, directory: String?)? {
        guard let path = cursorFilePath() else { return nil }
        guard let data = await readAllData(VFSPath(filesystemId: fs.scheme, path: path)),
              data.count <= 512 * 1024 * 1024 else { return nil }
        let dir = await model.getPath()
        return ((path as NSString).lastPathComponent, data, (fs is LocalFS) ? dir : nil)
    }

    /// The current directory path when it is real local disk, else nil (used to
    /// pre-point a save panel).
    func currentDirectoryIfLocal() async -> String? {
        (fs is LocalFS) ? await model.getPath() : nil
    }

    /// Decode the cursor file, auto-detecting Base64 / uuencode / xxencode
    /// (F-096). Drops a known encoded extension, else appends ".decoded".
    func decodeCursorBase64() async -> String? {
        guard let path = cursorFilePath() else { return nil }
        let encodedExts = [".b64", ".uue", ".uu", ".xxe", ".hex"]
        let out: String
        if let ext = encodedExts.first(where: { path.lowercased().hasSuffix($0) }) {
            out = String(path.dropLast(ext.count))
        } else {
            out = path + ".decoded"
        }
        let src = VFSPath(filesystemId: fs.scheme, path: path)
        let dst = VFSPath(filesystemId: fs.scheme, path: out)
        do { try await EncodeDecodeEngine.decodeAuto(src, to: dst, on: fs) } catch { return nil }
        await reload()
        return (out as NSString).lastPathComponent
    }

    /// Split the cursor file into `partSize`-byte parts in the current directory.
    func splitCursorFile(partSize: Int64) async -> (parts: Int, name: String)? {
        guard let path = cursorFilePath() else { return nil }
        let src = VFSPath(filesystemId: fs.scheme, path: path)
        let dir = VFSPath(filesystemId: fs.scheme, path: await model.getPath())
        guard let info = try? await SplitCombineEngine.split(src, partSize: partSize, into: dir, on: fs) else { return nil }
        await reload()
        return (SplitInfo.partCount(size: info.size, partSize: partSize), info.filename)
    }

    /// Combine parts described by the cursor's .crc (or .NNN) file.
    func combineFromCursor() async -> (name: String, crcOK: Bool)? {
        guard let path = cursorFilePath() else { return nil }
        let crcPath: String
        if path.hasSuffix(".crc") {
            crcPath = path
        } else if let r = path.range(of: #"\.\d{3,}$"#, options: .regularExpression) {
            crcPath = String(path[..<r.lowerBound]) + ".crc"
        } else {
            return nil
        }
        let dir = VFSPath(filesystemId: fs.scheme, path: await model.getPath())
        guard let result = try? await SplitCombineEngine.combine(
                crcPath: VFSPath(filesystemId: fs.scheme, path: crcPath), into: dir, on: fs) else { return nil }
        await reload()
        return (result.info.filename, result.crcOK)
    }

    /// Total occupied space of the selection (or cursor item). Local-only for now.
    func occupiedSpace() async -> OccupiedSpace? {
        guard fs is LocalFS else { return nil }
        var paths = tableView.selectedItemPaths()
        if paths.isEmpty, let c = tableView.cursorItemFullPath(), (c as NSString).lastPathComponent != ".." {
            paths = [c]
        }
        guard !paths.isEmpty else { return OccupiedSpace(bytes: 0, files: 0, folders: 0) }
        return await OccupiedSpaceCalculator().measure(paths)
    }

    /// Apply POSIX permissions (and optionally BSD flags, owner/group, and the
    /// modification date — F-094) to the selected items (or cursor item).
    func changeAttributes(mode: UInt16, recursive: Bool, bsdFlags: UInt32? = nil,
                          modified: Date? = nil, ownerName: String? = nil,
                          groupName: String? = nil) async -> (changed: Int, failed: Int)? {
        var paths = tableView.selectedItemPaths()
        if paths.isEmpty, let c = tableView.cursorItemFullPath(), (c as NSString).lastPathComponent != ".." {
            paths = [c]
        }
        guard !paths.isEmpty else { return nil }
        let vpaths = paths.map { VFSPath(filesystemId: fs.scheme, path: $0) }
        let r = await AttributeEngine.apply(posixMode: mode, modified: modified, bsdFlags: bsdFlags,
                                            ownerName: ownerName, groupName: groupName,
                                            to: vpaths, on: fs, recursive: recursive)
        await reload()
        return r
    }

    /// Rows for the file-list formatter. `namesFilter` nil = all entries (excluding "..").
    func fileListRows(namesFilter: Set<String>?) -> [FileListRow] {
        tableView.currentEntries()
            .filter { $0.name != ".." && (namesFilter == nil || namesFilter!.contains($0.name)) }
            .map { FileListRow(name: $0.name, ext: $0.ext, size: $0.size, modified: $0.modified) }
    }

    /// The plain text of the current directory listing (for printing).
    func fileListText(format: FileListFormat) -> String {
        FileListFormatter.format(fileListRows(namesFilter: nil), as: format)
    }

    /// Populate the Comment column from the current directory's descript.ion — but
    /// only when that opt-in column is actually visible, so the file read is skipped
    /// otherwise. Safe to call repeatedly (on every listing / column change).
    func refreshComments() {
        guard tableView.hasColumn(PanelColumn.comment.rawValue) else { return }
        let path = view.currentPathValue
        guard !path.isEmpty else { return }
        let dir = VFSPath(filesystemId: fs.scheme, path: path)
        Task { [weak self] in
            guard let self else { return }
            let map = await CommentStore.comments(inDir: dir, on: self.fs)
            await MainActor.run { self.tableView.setComments(map) }
        }
    }

    /// The cursor item's name and current comment (nil if cursor isn't a file).
    func cursorCommentContext() async -> (name: String, current: String)? {
        guard let path = cursorFilePath() else { return nil }
        let name = (path as NSString).lastPathComponent
        let dir = VFSPath(filesystemId: fs.scheme, path: await model.getPath())
        var current = await CommentStore.comment(for: name, inDir: dir, on: fs) ?? ""
        // Fall back to the macOS Finder comment when there's no descript.ion one (F-023).
        if current.isEmpty, fs is LocalFS, let finder = FinderComment.read(path) { current = finder }
        return (name, current)
    }

    /// Set (or clear) the cursor item's descript.ion comment, keeping the macOS
    /// Finder comment in sync (F-023).
    @discardableResult
    func setCursorComment(_ comment: String?) async -> Bool {
        guard let path = cursorFilePath() else { return false }
        let name = (path as NSString).lastPathComponent
        let dir = VFSPath(filesystemId: fs.scheme, path: await model.getPath())
        do { try await CommentStore.setComment(comment, for: name, inDir: dir, on: fs) } catch { return false }
        if fs is LocalFS { FinderComment.write(comment, to: path) }   // mirror into the Finder comment
        await reload()
        return true
    }

    /// Image metadata for the cursor item (extracting from an archive if needed).
    func cursorImageInfo() async -> (name: String, info: ImageInfo)? {
        guard let path = await localPathForCursor() else { return nil }
        guard let info = ImageInfoProvider.info(at: URL(fileURLWithPath: path)) else { return nil }
        let name = tableView.cursorItemFullPath().map { ($0 as NSString).lastPathComponent }
            ?? (path as NSString).lastPathComponent
        return (name, info)
    }

    /// The cursor item's leaf name (local FS only), for link creation.
    func cursorItemName() async -> String? {
        guard fs is LocalFS, let p = cursorFilePath() else { return nil }
        return (p as NSString).lastPathComponent
    }

    /// Create a link of `kind` named `name` in the current directory, pointing at
    /// the cursor item. Local FS only.
    func createLink(kind: LinkKind, name: String) async -> Bool {
        guard fs is LocalFS, let target = cursorFilePath() else { return false }
        let linkPath = (await model.getPath() as NSString).appendingPathComponent(name)
        do { try LinkMaker.createLink(kind: kind, at: linkPath, target: target) } catch { return false }
        await reload()
        return true
    }

    /// The cursor's path if it is a real file (not the ".." entry).
    private func cursorFilePath() -> String? {
        guard let path = tableView.cursorItemFullPath(), (path as NSString).lastPathComponent != ".." else { return nil }
        return path
    }

    private func readAllData(_ path: VFSPath) async -> Data? {
        guard let stream = try? await fs.openRead(path) else { return nil }
        var data = Data()
        do {
            for try await chunk in stream { if let d = chunk as? Data { data.append(d) } }
        } catch { return nil }
        try? await stream.close()
        return data
    }

    func getSortDescriptor() async -> DirectoryModel.SortDescriptor { await model.getSortDescriptor() }

    func sort(by column: PanelSortColumn, ascending: Bool) async {
        let descriptor: DirectoryModel.SortDescriptor
        switch column {
        case .name: descriptor = .name(ascending: ascending)
        case .ext: descriptor = .ext(ascending: ascending)
        case .size: descriptor = .size(ascending: ascending)
        case .date: descriptor = .date(ascending: ascending)
        }
        await model.sort(by: descriptor)
        tabs.updateActive { $0.sortColumn = column.rawValue; $0.sortAscending = ascending }
        let path = await model.getPath()
        do {
            let snapshot = try await model.load(path, fs: fs)
            let volume = isInArchive ? nil : await volumeManager.getVolume(for: path)
            view.update(with: snapshot, volume: volume, rootLabel: mountedDriveVolume?.name)
            tableView.updateSortArrows(descriptor)
            scheduleStatusRefresh()
            onStateChanged?()
        } catch {
            logger.error("Failed to reload \(path) after sort: \(error)")
        }
    }

    /// Current sort as a persistable (column key, ascending) pair.
    func currentSort() async -> (column: String, ascending: Bool) {
        let d = await model.getSortDescriptor()
        switch d {
        case .name(let a): return ("name", a)
        case .ext(let a): return ("ext", a)
        case .size(let a): return ("size", a)
        case .date(let a): return ("date", a)
        }
    }

    /// Apply a persisted sort (column key + direction) without a user click.
    func applySort(column: String, ascending: Bool) async {
        let col = PanelSortColumn(rawValue: column) ?? .name
        await sort(by: col, ascending: ascending)
    }

    // MARK: - Selection operations (PanelControllerProtocol)

    func toggleMarkAtCursor() async { tableView.toggleMarkAtCursor() }
    func markAll() async { tableView.markAll() }
    func unmarkAll() async { tableView.unmarkAll() }
    func invertSelection() async { tableView.invertMarks() }
    func restoreSelection() async { tableView.restoreSelection() }
    func selectSameExtension() async { tableView.selectSameExtensionAtCursor() }
    func toggleHiddenFiles() async { tableView.toggleHiddenFiles() }
    func setHiddenFiles(_ show: Bool) { tableView.setHiddenFiles(show) }
    func isHiddenShown() -> Bool { tableView.isShowingHiddenFiles }
    func calculateAllDirectorySizes() async { tableView.calculateAllDirectorySizes() }
    func setDisplayOptions(sizeStyle: String, bracketDirs: Bool, dateFormat: String) {
        tableView.applyDisplayOptions(sizeStyle: sizeStyle, bracketDirs: bracketDirs, dateFormat: dateFormat)
    }
    func setMouseMode(_ mode: String) { tableView.mouseMode = mode }
    func setTypeColors(_ config: String) { tableView.setTypeColors(config) }
    func setZebraStripes(_ on: Bool) { tableView.zebraStripes = on }   // F-032
    func setPanelFontSize(_ size: Int) { tableView.setPanelFontSize(size) }   // F-272
    func setDriveBarVisible(_ v: Bool) { view.setDriveBarVisible(v) }   // F-270
    func setStatusBarVisible(_ v: Bool) { view.setStatusBarVisible(v) }   // F-270
    func setTabBarVisible(_ v: Bool) { view.setTabBarVisible(v) }   // F-270
    func setPathBarVisible(_ v: Bool) { view.setPathBarVisible(v) }   // F-270
    /// Apply the natural-sort option to this panel's model and re-sort (F-026).
    func setNaturalSort(_ on: Bool) {
        Task { @MainActor in
            await model.setNaturalSort(on)
            if !view.currentPathValue.isEmpty { await reload() }   // avoid a premature reload at init
        }
    }
    func setQuickSearchMode(_ mode: String) { tableView.quickSearchMode = mode }

    // Copy/move defaults from the Options "Copy/Delete" page (F-271). Cached here
    // (pushed from the window controller) and read by defaultCopyOptions().
    var copyPreserveMetadata = true
    var copyUseClone = true
    var copyOnlyNewer = false
    var copySpeedLimitKBps = 0
    func setCopyDefaults(preserveMetadata: Bool, useClone: Bool, onlyNewer: Bool, speedLimitKBps: Int) {
        copyPreserveMetadata = preserveMetadata
        copyUseClone = useClone
        copyOnlyNewer = onlyNewer
        copySpeedLimitKBps = speedLimitKBps
    }

    // Pack defaults from the Options "Zip/Packer" page (F-274). Stored as raw
    // strings/ints so this file needs no PCArchive import; packSelection maps
    // packDefaultFormatRaw to a PackFormat.
    var packDefaultFormatRaw = "zip"
    var packDefaultLevel = 5
    func setPackDefaults(format: String, level: Int) {
        packDefaultFormatRaw = format
        packDefaultLevel = level
    }

    // Tabs defaults from the Options "Tabs" page (F-274/I06).
    var tabOpenInForeground = true
    var tabLockedOpensNewTab = true
    func setTabDefaults(openInForeground: Bool, lockedOpensNewTab: Bool) {
        tabOpenInForeground = openInForeground
        tabLockedOpensNewTab = lockedOpensNewTab
    }
    func applyAppearance() {
        view.isHighlighted = view.isHighlighted // re-tint path bar
        tableView.reloadForAppearance()
        view.reapplyChromeTheme()
    }

    func showSelectByMask() async { presentMaskDialog(unselect: false) }
    func showUnselectByMask() async { presentMaskDialog(unselect: true) }

    func showProperties() async {
        guard let path = tableView.currentCursorFullPath() else { return }
        await presentProperties(path: path)
    }

    // MARK: - Dialog presentation

    private func presentMaskDialog(unselect: Bool) {
        let dialog = SelectUnselectDialog(type: unselect ? .unselectByMask : .selectByMask)
        dialog.onConfirmMask = { [weak self] mask, includeDirs in
            self?.tableView.applySelectionMask(mask, unselect: unselect, includeDirectories: includeDirs)
        }
        activeDialog = dialog
        dialog.runModalDialog()
        activeDialog = nil
    }

    func presentProperties(path: String) async {
        let props = await Task.detached { FilePropertiesReader.read(path: path) }.value
        let dialog = PropertiesDialog(properties: props)
        activeDialog = dialog
        dialog.showWindow(nil)
        dialog.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Status bar (coalesced)

    func scheduleStatusRefresh() {
        guard !statusRefreshScheduled else { return }
        statusRefreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.statusRefreshScheduled = false
            Task { await self.refreshStatusBar() }
        }
    }

    private func refreshStatusBar() async {
        let path = await model.getPath()
        let volume = isInArchive ? nil : await volumeManager.getVolume(for: path)
        let sort = await model.getSortDescriptor()
        let summary = await tableView.selectionSummary()
        statusBar.update(path: path,
                         volume: volume,
                         selected: summary.selected,
                         total: summary.total,
                         selectedBytes: summary.selectedBytes,
                         totalBytes: summary.totalBytes,
                         selectedFiles: summary.selectedFiles,
                         totalFiles: summary.totalFiles,
                         selectedDirs: summary.selectedDirs,
                         totalDirs: summary.totalDirs,
                         sortDescriptor: sort)
        await refreshDriveBar(path: path)
    }

    /// Populate the drive bar once, then highlight the volume owning `path`.
    private func refreshDriveBar(path: String) async {
        if !driveBarPopulated {
            // Mounted volumes + drives contributed by file-system plugins (iCloud, …).
            let pluginVolumes = FileSystemPluginRegistry.shared.driveVolumes()
            cachedDriveVolumes = DriveBarModel.display(await volumeManager.getVolumes() + pluginVolumes)
            view.driveBar.setVolumes(cachedDriveVolumes)
            driveBarPopulated = true
        }
        view.driveBar.setCurrentIndex(DriveBarModel.currentIndex(in: cachedDriveVolumes, for: path,
                                                                 mountedVolumePath: mountedDriveVolume?.path))
    }

    // MARK: - Volume support

    func getCurrentVolume() async -> Volume? {
        await volumeManager.getVolume(for: await model.getPath())
    }

    func getVolumes() async -> [Volume] { await volumeManager.getVolumes() }

    func loadDirectoryFromVolume(_ volumePath: String) async {
        // A drive-bar click to a local volume must first leave any open mount
        // (TaskManager/network/archive) — otherwise the local path would be looked
        // up through the mounted filesystem and the mount would stay open.
        if isInArchive { leaveMountToLocal() }
        await loadDirectory(volumePath)
    }

    /// Fully unwind to the local filesystem (drops the whole mount stack), and, if
    /// we were on a content mount, restore that panel's normal columns + stop the
    /// volatile auto-refresh.
    private func leaveMountToLocal() {
        let wasContentMount = (fs as? PFXFileSystem)?.contentFields.isEmpty == false
        fs = mountStack.first?.fs ?? LocalFS()
        // As in `exitArchive`: the tab followed the panel into the drive and follows it back out.
        setMountedDrive(mountStack.first?.driveVolume)
        mountStack.removeAll()
        if wasContentMount, let wc = view.window?.windowController as? MainWindowController {
            wc.panelDidLeaveContentMount(panel: self)
        } else {
            stopVolatileAutoRefresh()
        }
    }

    func saveCurrentPathForVolume() async {
        let path = await model.getPath()
        if let volume = await volumeManager.getVolume(for: path) { volumeLastPath[volume.id] = path }
    }

    func getLastPath(for volumeId: String) -> String? { volumeLastPath[volumeId] }
}

/// Main window that does not shrink its frame to the content's Auto Layout
/// minimum — AppKit otherwise clamps this window's width to the panels' minimum,
/// so it can't be widened or maximized. We only enforce a sane floor here.
final class MainWindow: NSWindow {
    /// Invoked when Tab / Shift-Tab is pressed, to switch the active panel instead
    /// of running AppKit's default key-view-loop focus traversal.
    var onTabSwitch: (() -> Void)?

    /// Invoked after the first responder changes.
    ///
    /// AppKit posts no notification for this, and polling for it would be a timer running forever to
    /// catch something that happens a few times a minute. Overriding the one method every route goes
    /// through — clicks, `makeFirstResponder`, the key-view loop — is both cheaper and exact.
    var onFirstResponderChange: (() -> Void)?

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        let changed = super.makeFirstResponder(responder)
        if changed { onFirstResponderChange?() }
        return changed
    }

    override func selectNextKeyView(_ sender: Any?) {
        if let onTabSwitch { onTabSwitch() } else { super.selectNextKeyView(sender) }
    }

    override func selectPreviousKeyView(_ sender: Any?) {
        if let onTabSwitch { onTabSwitch() } else { super.selectPreviousKeyView(sender) }
    }
}

/// Hosts the window's content (button bar + split view + command line). Being an
/// NSViewController lets the NSSplitViewController participate in proper view
/// controller containment; `onLayout` fires whenever the content view resizes.
final class ContentViewController: NSViewController {
    var onLayout: (() -> Void)?
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1024, height: 768))
        view.autoresizingMask = [.width, .height]
    }
    override func viewDidLayout() {
        super.viewDidLayout()
        onLayout?()
    }
}

/// Panel view - contains the path bar, the list table view, and the status bar.
final class PanelView: NSView {
    private var _backgroundColor: NSColor?
    private var _isHighlighted = false

    let position: PanelPosition
    let tableView: PanelListView
    let iconGrid = IconGridView()
    private let contentScroll = NSScrollView()
    private let treeView = PanelTreeView()                  // F-015: optional folder-tree column

    /// Repaint the panel's folder tree in the current theme.
    func applyTreeTheme() { treeView.applyTheme() }

    #if DEBUG
    /// Diagnostic: the panel's folder tree (F-015).
    var treeForAutomation: PanelTreeView { treeView }
    #endif
    private var treeWidthConstraint: NSLayoutConstraint?
    private(set) var isTreeVisible = false
    private(set) var viewMode: PanelViewMode = .details
    private var currentPath = ""
    /// The panel's current directory path (sync read of the last-loaded snapshot).
    var currentPathValue: String { currentPath }
    private let tabBar = TabBarView()
    private let pathBar: PathBarView
    let driveBar = DriveBarView()
    /// What the chrome around the listing says the panel is showing — for the automation report,
    /// which is the only way to read back bars that are drawn rather than built from controls.
    var chromeForAutomation: (tabs: String, crumb: String) {
        (tabBar.titlesForAutomation, pathBar.crumbForAutomation)
    }
    let statusBar: StatusBarView
    private let filterLabel = NSTextField(labelWithString: "")
    weak var controller: PanelController?
    // Toggleable bar heights (F-270): collapsed to 0 + hidden when off.
    private var driveBarHeightConstraint: NSLayoutConstraint!
    private var statusBarHeightConstraint: NSLayoutConstraint!
    private var tabBarHeightConstraint: NSLayoutConstraint!
    private var pathBarHeightConstraint: NSLayoutConstraint!

    /// Show/hide the drive bar (F-270); collapses its height so no gap remains.
    func setDriveBarVisible(_ visible: Bool) {
        driveBar.isHidden = !visible
        driveBarHeightConstraint.constant = visible ? 24 : 0
    }

    /// Show/hide the status bar (F-270).
    func setStatusBarVisible(_ visible: Bool) {
        statusBar.isHidden = !visible
        statusBarHeightConstraint.constant = visible ? Metrics.statusBarHeight : 0
    }

    /// Show/hide the tab bar (F-270). Tabs stay reachable via Ctrl+Tab.
    func setTabBarVisible(_ visible: Bool) {
        tabBar.isHidden = !visible
        tabBarHeightConstraint.constant = visible ? 26 : 0
    }

    /// Show/hide the path (breadcrumb) bar (F-270).
    func setPathBarVisible(_ visible: Bool) {
        pathBar.isHidden = !visible
        pathBarHeightConstraint.constant = visible ? 28 : 0
    }

    // Quick View embed (F-118): an overlay covering the file-list area.
    private var quickViewOverlay: NSView?

    /// Embed `overlay` over the file list (Quick View, F-118), or pass nil to
    /// restore the normal list. The overlay is pinned to the content scroll frame.
    func setQuickViewOverlay(_ overlay: NSView?) {
        quickViewOverlay?.removeFromSuperview()
        quickViewOverlay = nil
        contentScroll.isHidden = overlay != nil
        guard let overlay else { return }
        overlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlay, positioned: .above, relativeTo: contentScroll)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: contentScroll.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: contentScroll.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: contentScroll.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: contentScroll.bottomAnchor),
        ])
        quickViewOverlay = overlay
    }

    var hasQuickViewOverlay: Bool { quickViewOverlay != nil }

    init(position: PanelPosition, controller: PanelController) {
        self.position = position
        self.controller = controller
        self.tableView = PanelListView()
        self.pathBar = PathBarView(position: position)
        self.statusBar = StatusBarView(position: position)
        super.init(frame: .zero)
        // The file list is where a keyboard user spends the whole session, and it announced nothing:
        // an NSTableView with no label is read as "table" (I19 T06). Which side it is matters, because
        // the two are told apart by nothing else.
        tableView.setAccessibilityLabel(position == .left
            ? String(localized: "File list, left panel")
            : String(localized: "File list, right panel"))
        setup()
    }

    required init?(coder: NSCoder) {
        self.position = .left
        self.tableView = PanelListView()
        self.pathBar = PathBarView(position: .left)
        self.statusBar = StatusBarView(position: .left)
        super.init(coder: coder)
    }

    private func setup() {
        // Explicit layer-backing for the panel container so its custom-drawn
        // subviews composite predictably inside the NSSplitView item wrapper.
        wantsLayer = true
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        pathBar.translatesAutoresizingMaskIntoConstraints = false
        let scrollView = contentScroll
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true   // used by brief mode's column-major flow
        scrollView.documentView = tableView
        statusBar.translatesAutoresizingMaskIntoConstraints = false

        driveBar.translatesAutoresizingMaskIntoConstraints = false
        treeView.translatesAutoresizingMaskIntoConstraints = false
        treeView.isHidden = true
        treeView.onSelect = { [weak controller] path in
            Task { @MainActor in await controller?.loadDirectory(path) }
        }
        addSubview(pathBar)
        addSubview(treeView)
        addSubview(scrollView)
        addSubview(statusBar)

        driveBar.onSelect = { [weak controller, weak self] volumePath in
            // A non-local plugin volume (e.g. "TaskManager") carries a "pfxmount:"
            // sentinel path: connect + mount the plugin here rather than navigate.
            if volumePath.hasPrefix("pfxmount:") {
                let pluginId = String(volumePath.dropFirst("pfxmount:".count))
                (self?.window?.windowController as? MainWindowController)?
                    .mountPluginVolume(pluginId: pluginId, into: controller)
                return
            }
            Task { @MainActor in await controller?.loadDirectoryFromVolume(volumePath) }
        }
        driveBar.onGoTo = { [weak controller] path in
            Task { @MainActor in await controller?.loadDirectoryFromVolume(path) }
        }
        driveBar.onManageFavorites = { [weak self] in
            (self?.window?.windowController as? MainWindowController)?.runCommandNamed("cm_DirectoryHotlist")
        }
        driveBar.favoritesProvider = { [weak self] in
            (self?.window?.windowController as? MainWindowController)?.favoriteEntries() ?? []
        }
        driveBar.onEject = { [weak self] volume in
            (self?.window?.windowController as? MainWindowController)?.ejectVolume(volume)
        }
        // Add the tab bar + drive bar LAST so they are frontmost siblings. Added
        // first (backmost) they never receive a live draw pass in this layer-backed
        // split-view panel. The clean custom-drawn drive bar only paints its own
        // 24pt bounds, so being frontmost doesn't cover the list. (#179)
        addSubview(tabBar)
        addSubview(driveBar)

        tabBar.onSelect = { [weak controller] i in Task { @MainActor in await controller?.selectTab(i) } }
        tabBar.onClose = { [weak controller] i in Task { @MainActor in await controller?.closeTab(at: i) } }
        tabBar.onNewTab = { [weak controller] in Task { @MainActor in await controller?.openNewTab() } }
        tabBar.onReorder = { [weak controller] from, to in controller?.reorderTab(from: from, to: to) }
        tabBar.onContextMenu = { [weak controller, weak tabBar] index in
            if let tabBar { controller?.showTabContextMenu(index, in: tabBar) }
        }
        // Grid index 0 is the synthetic ".." row, so subtract 1 to map back to the
        // table's visible-index model (-1 == "..").
        iconGrid.onCursorChanged = { [weak controller] index in controller?.tableView.focusVisibleIndex(index - 1) }
        iconGrid.onActivate = { [weak controller] index in controller?.tableView.activateVisibleIndex(index - 1) }
        iconGrid.onDropFiles = { [weak controller] paths, move in
            Task { @MainActor in await controller?.performDrop(paths: paths, move: move) }
        }

        pathBar.onPathClick = { [weak controller] path in
            Task { @MainActor in await controller?.loadDirectory(path) }
        }

        // Header right-click column menu — context-aware (mount vs file system).
        tableView.columnsMenuData = { [weak self, weak controller] in
            guard let wc = self?.window?.windowController as? MainWindowController,
                  let controller else { return ([], []) }
            return wc.columnsMenu(for: controller)
        }
        tableView.onToggleColumn = { [weak self, weak controller] fieldID in
            guard let wc = self?.window?.windowController as? MainWindowController,
                  let controller else { return }
            wc.toggleColumn(fieldID, panel: controller)
        }
        tableView.onConfigureColumns = { [weak self, weak controller] in
            guard let wc = self?.window?.windowController as? MainWindowController,
                  let controller else { return }
            wc.configureColumns(panel: controller)
        }

        tableView.onNavigate = { [weak controller] path in
            Task { @MainActor in await controller?.loadDirectory(path) }
        }
        tableView.onGoUp = { [weak controller] in
            Task { @MainActor in await controller?.goUp() }
        }
        tableView.onEnterArchive = { [weak controller] path in
            Task { @MainActor in await controller?.enterArchive(path) }
        }
        tableView.onDropFiles = { [weak controller] paths, move, intoFolder in
            Task { @MainActor in await controller?.performDrop(paths: paths, move: move, into: intoFolder) }
        }
        tableView.onSpringLoadFolder = { [weak controller] path in
            Task { @MainActor in await controller?.loadDirectory(path) }   // F-067 spring-load
        }
        tableView.onSortColumn = { [weak controller] column, ascending in
            guard let controller else { return }
            Task { @MainActor in
                await controller.sort(by: column.toPanelSortColumn(), ascending: ascending)
            }
        }
        tableView.onSelectionOrCursorChanged = { [weak controller] in
            controller?.viewStateChanged()
        }
        tableView.onShowSelectDialog = { [weak controller] unselect in
            Task { @MainActor in
                if unselect { await controller?.showUnselectByMask() }
                else { await controller?.showSelectByMask() }
            }
        }
        tableView.onShowProperties = { [weak controller] path in
            Task { @MainActor in await controller?.presentProperties(path: path) }
        }
        tableView.onRunCommand = { [weak self] name in
            guard let self else { return }
            (self.window?.windowController as? MainWindowController)?.runCommandNamed(name)
        }
        tableView.onActivate = { [weak self] in
            guard let self, let wc = self.window?.windowController as? MainWindowController else { return }
            self.position == .left ? wc.activateLeftPanel() : wc.activateRightPanel()
        }
        tableView.onSwitchPanel = { [weak self] in
            (self?.window?.windowController as? MainWindowController)?.toggleActivePanel()
        }
        tableView.onFilterChanged = { [weak self] text in
            guard let self else { return }
            if let text {
                self.filterLabel.stringValue = "🔍 \(text)"
                self.filterLabel.isHidden = false
            } else {
                self.filterLabel.isHidden = true
            }
        }
        tableView.onTypeToCommandLine = { [weak self] s in
            (self?.window?.windowController as? MainWindowController)?.routeTypingToCommandLine(s)
        }
        tableView.onAppendToCommandLine = { [weak self] s in
            (self?.window?.windowController as? MainWindowController)?.appendToCommandLine(s)
        }
        if let controller { tableView.setSelectionState(controller.getSelectionState()) }

        filterLabel.translatesAutoresizingMaskIntoConstraints = false
        filterLabel.font = Fonts.system13
        filterLabel.textColor = Theme.current.selectedText
        filterLabel.backgroundColor = Theme.current.listBackground
        filterLabel.drawsBackground = true
        filterLabel.isHidden = true
        addSubview(filterLabel)

        driveBarHeightConstraint = driveBar.heightAnchor.constraint(equalToConstant: 24)
        statusBarHeightConstraint = statusBar.heightAnchor.constraint(equalToConstant: Metrics.statusBarHeight)
        tabBarHeightConstraint = tabBar.heightAnchor.constraint(equalToConstant: 26)
        pathBarHeightConstraint = pathBar.heightAnchor.constraint(equalToConstant: 28)
        // The four bars total 102 pt and the chain from the panel's top to its bottom is otherwise
        // fully determined, so a panel shorter than that has no solution — which happens during window
        // setup, before the real frame arrives, and would happen again in a very short window. Almost
        // every conflict the regression harness reports traces back here.
        //
        // The bars are what should yield: the list between them has already collapsed to nothing by
        // then, and chrome giving up a point is invisible where an unsatisfiable chain is a log full of
        // broken constraints. 999 rather than a lower value so nothing else can outrank them.
        for constraint in [driveBarHeightConstraint, statusBarHeightConstraint,
                           tabBarHeightConstraint, pathBarHeightConstraint] {
            constraint?.priority = .init(999)
        }
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabBarHeightConstraint,

            driveBar.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            driveBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            driveBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            driveBarHeightConstraint,

            pathBar.topAnchor.constraint(equalTo: driveBar.bottomAnchor),
            pathBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            pathBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            pathBarHeightConstraint,

            treeView.topAnchor.constraint(equalTo: pathBar.bottomAnchor),
            treeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            treeView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            scrollView.topAnchor.constraint(equalTo: pathBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: treeView.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            statusBarHeightConstraint,

            filterLabel.trailingAnchor.constraint(equalTo: pathBar.trailingAnchor, constant: -8),
            filterLabel.centerYAnchor.constraint(equalTo: pathBar.centerYAnchor)
        ])
        treeWidthConstraint = treeView.widthAnchor.constraint(equalToConstant: 0)
        // How wide the tree column *should* be, not a rule about the world: the column and the file
        // list together span the panel edge to edge, and during setup the panel is still zero wide, so
        // as a required constraint 200 pt has no solution. The last conflict shape left in every panel
        // scenario was this one.
        treeWidthConstraint?.priority = .init(999)
        treeWidthConstraint?.isActive = true
    }

    // MARK: - Folder tree (F-015)

    /// Show/hide the leading folder-tree column. When shown, it is revealed to the
    /// current directory so the selection matches the list.
    func setTreeVisible(_ visible: Bool) {
        guard visible != isTreeVisible else { return }
        isTreeVisible = visible
        treeView.isHidden = !visible
        treeWidthConstraint?.constant = visible ? PanelTreeView.defaultWidth : 0
        if visible { treeView.reveal(path: currentPath) }
    }

    var isHighlighted: Bool {
        get { _isHighlighted }
        set {
            _isHighlighted = newValue
            pathBar.setActive(newValue)
            tableView.isActivePanel = newValue
            needsDisplay = true
        }
    }

    var backgroundColor: NSColor? {
        get { _backgroundColor }
        set { _backgroundColor = newValue; needsDisplay = true }
    }

    /// Update with a new directory snapshot. `rootLabel` is the mounted drive's name when the
    /// listing is one (see `PathBarView.update`).
    func update(with snapshot: DirectorySnapshot, volume: Volume? = nil, rootLabel: String? = nil) {
        tableView.update(with: snapshot)
        pathBar.update(with: snapshot.path, volume: volume, rootLabel: rootLabel)
        currentPath = snapshot.path
        if usesGrid { refreshGrid() }
        if isTreeVisible { treeView.reveal(path: snapshot.path) }
        controller?.refreshComments()   // fills the opt-in descript.ion Comment column
    }

    // MARK: - View modes (TODOS #58)

    /// Whether the current mode is rendered by the icon grid rather than the table.
    /// Brief (column-major list), icons and gallery use the grid; details uses the table.
    private var usesGrid: Bool { viewMode == .brief || viewMode == .icons || viewMode == .gallery }

    /// The view that should hold keyboard focus for the current mode.
    var currentContentView: NSView { usesGrid ? iconGrid : tableView }

    /// Bumped on every grid rebuild so stale async thumbnail callbacks (for a
    /// directory we've since left) can detect they no longer apply.
    private var gridGeneration = 0

    /// Switch the panel between table- and grid-based rendering by swapping the
    /// scroll view's document view. Cursor/selection stay in the table model, which
    /// the grid mirrors via its callbacks.
    func setViewMode(_ mode: PanelViewMode) {
        guard mode != viewMode else { return }
        viewMode = mode
        if usesGrid {
            configureGridForMode()
            refreshGrid()
            contentScroll.documentView = iconGrid
            iconGrid.relayout()
            window?.makeFirstResponder(iconGrid)
        } else {
            contentScroll.documentView = tableView
            window?.makeFirstResponder(tableView)
        }
        // Exchanging the scroll view's document view breaks the key-view loop, and AppKit does not
        // rebuild it by itself (I19 T06): after switching the view mode, Tab reached nothing in the whole
        // window — sixteen controls unreachable and the loop left open. The same shape as the Settings
        // page swap, and found the same way: by a scenario that switches the mode before measuring.
        KeyboardLoop.rebuild(for: window)
    }

    /// Cell geometry per grid mode: compact column-major rows for brief, medium
    /// cells for icons, large cells for the gallery.
    private func configureGridForMode() {
        switch viewMode {
        case .brief:
            iconGrid.configure(layout: GridLayout(itemWidth: 200, itemHeight: 18, spacing: 4, edgeInset: 8),
                               iconSize: 15, columnMajor: true, nameOnly: true)
        case .gallery:
            iconGrid.configure(layout: GridLayout(itemWidth: 160, itemHeight: 150, spacing: 16, edgeInset: 16),
                               iconSize: 120)
        default:
            iconGrid.configure(layout: GridLayout(itemWidth: 110, itemHeight: 92, spacing: 12, edgeInset: 12),
                               iconSize: 48)
        }
    }

    /// Rebuild the grid items from the table's current visible entries and mirror
    /// the cursor (table cursor -1 == ".." → grid index 0). In gallery mode, kick
    /// off async QuickLook thumbnails that replace the placeholder icons.
    func refreshGrid() {
        gridGeneration &+= 1
        let entries = tableView.currentVisibleEntries()
        iconGrid.setItems(gridItems(from: entries), cursor: max(0, tableView.cursorRow + 1))
        if viewMode == .gallery { requestThumbnails(for: entries, generation: gridGeneration) }
    }

    /// Generate QuickLook thumbnails for the gallery and swap them in as they
    /// arrive (grid index = entry index + 1 for the synthetic "..").
    private func requestThumbnails(for entries: [VFSEntry], generation: Int) {
        guard !currentPath.isEmpty else { return }
        let scale = window?.backingScaleFactor ?? 2
        let px = CGSize(width: 128, height: 128)
        for (i, entry) in entries.enumerated() where !PanelEntryHelpers.isDirectoryLike(entry.kind) {
            let gridIndex = i + 1
            let url = URL(fileURLWithPath: (currentPath as NSString).appendingPathComponent(entry.name))
            let request = QLThumbnailGenerator.Request(fileAt: url, size: px, scale: scale,
                                                       representationTypes: .thumbnail)
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
                guard let rep else { return }
                Task { @MainActor in
                    guard let self, self.gridGeneration == generation else { return }
                    self.iconGrid.setThumbnail(rep.nsImage, at: gridIndex)
                }
            }
        }
    }

    /// Mirror the table's cursor onto the grid without rebuilding items. Called on
    /// every cursor change so programmatic moves (goUp's focusEntry, type-ahead)
    /// reach the grid too — `update(with:)` runs before the cursor is positioned.
    func syncGridCursor() {
        guard usesGrid else { return }
        iconGrid.setCursor(max(0, tableView.cursorRow + 1))
    }

    /// Build grid items (with a synthetic ".." first) using real Finder icons.
    private func gridItems(from entries: [VFSEntry]) -> [IconGridView.Item] {
        let ws = NSWorkspace.shared
        var items: [IconGridView.Item] = [
            IconGridView.Item(name: "..", icon: ws.icon(for: .folder), isDirectory: true)
        ]
        for entry in entries {
            let isDir = PanelEntryHelpers.isDirectoryLike(entry.kind)
            let fullPath = currentPath.isEmpty ? nil : (currentPath as NSString).appendingPathComponent(entry.name)
            let icon = fullPath.map { ws.icon(forFile: $0) } ?? ws.icon(for: isDir ? .folder : .data)
            items.append(IconGridView.Item(name: entry.name, icon: icon, isDirectory: isDir, path: fullPath))
        }
        return items
    }

    /// Refresh the tab strip.
    func updateTabBar(titles: [String], activeIndex: Int, locked: [Bool]) {
        tabBar.applyTheme()
        tabBar.setTabs(titles: titles, activeIndex: activeIndex, locked: locked)
    }

    /// Re-apply theme colors to all chrome bars (light/dark appearance change).
    func reapplyChromeTheme() {
        statusBar.applyTheme()
        tabBar.applyTheme()
        driveBar.applyTheme()
        pathBar.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let wc = window?.windowController as? MainWindowController {
            position == .left ? wc.activateLeftPanel() : wc.activateRightPanel()
        }
    }
}

// MARK: - ContributionHost (contribution behavior ABI host services)

extension MainWindowController: ContributionHost {
    func contribInvokeCommand(_ id: String) { runCommandNamed(id) }

    /// Run the generic PFX connect+mount for the file-system plugin registered
    /// under `pluginId` (its bundle path). Host-orchestrated because building the
    /// VirtualFileSystem is a host concern; no plugin-specific code here.
    func contribConnectFileSystem(pluginId: String) -> Bool {
        guard let plugin = FileSystemPluginRegistry.shared.plugin(id: pluginId),
              plugin.connectTitle != nil else { return false }
        plugin.connect(host: self)
        return true
    }

    /// Connect + mount a non-local file-system plugin volume into `panel` (from a
    /// drive-bar click on its "pfxmount:" sentinel). The click is the intent, so
    /// there is no interactive dialog — connect() mounts the plugin at "/".
    ///
    /// `activating` is false when a panel is restoring a tab rather than following a click: a
    /// restore must not decide which panel has the focus. Returns whether a plugin was there to
    /// mount, so a tab restoring a drive whose plugin is gone can stop calling itself that drive.
    @discardableResult
    func mountPluginVolume(pluginId: String, into panel: PanelController?, activating: Bool = true) -> Bool {
        if activating, let panel { activePanel = panel }
        guard let plugin = FileSystemPluginRegistry.shared.plugin(id: pluginId) else { return false }
        // The volume the user clicked, handed to the panel through `fsMount` so the bar can keep the
        // chip selected and the tab and path bar can say which drive this is: a plugin drive lists at
        // its own "/", which tells all three nothing. Looked up in the same list the bar drew its
        // chips from, so what the panel calls the drive is what the user clicked, letter for letter.
        // `connect` calls `fsMount` synchronously, so both are read before they clear.
        let sentinel = "pfxmount:\(pluginId)"
        pendingDriveVolume = FileSystemPluginRegistry.shared.driveVolumes().first { $0.path == sentinel }
        pendingMountPanel = panel
        defer { pendingDriveVolume = nil; pendingMountPanel = nil }
        plugin.connect(host: self)
        return true
    }

    func contribRegisterToolWindow(window: UnsafeMutableRawPointer,
                                   editMenu: UnsafeMutableRawPointer?,
                                   contentMenu: UnsafeMutableRawPointer?, title: String) {
        let nsWindow = Unmanaged<NSWindow>.fromOpaque(window).takeUnretainedValue()
        let edit = editMenu.map { Unmanaged<NSMenu>.fromOpaque($0).takeUnretainedValue() }
        let content = contentMenu.map { Unmanaged<NSMenu>.fromOpaque($0).takeUnretainedValue() }
        toolWindowMenus[ObjectIdentifier(nsWindow)] = (edit, content, title)
        // If the window is already key, install its bar now.
        if nsWindow.isKeyWindow {
            NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: nsWindow)
        }
    }

    /// The `descript.ion` comment for a path, for a plugin that shows it (F-372).
    ///
    /// Synchronous, because the caller is a view being drawn — so this reads through the *local*
    /// filesystem rather than the panel's VFS. A plugin view sits beside a local listing; asking the
    /// panel's async filesystem from a drawing pass would mean either blocking the main thread or
    /// answering "no comment" and correcting it a moment later.
    /// What is written *about* a file, for the comment search (F-373).
    ///
    /// The host's own comment: the directory's `descript.ion`, or the macOS Finder comment when there is
    /// none. `contribFileComment` already falls back between the two, and the user asked whether this text
    /// is written about the file without caring which of them answered.
    ///
    /// A plugin's note is deliberately *not* joined in here. The Notes plugin exposes its note as an
    /// ordinary content field, which the content-field condition in this dialog can already filter on —
    /// one mechanism for "a plugin knows something about this file", rather than a second path that only
    /// one plugin benefits from.
    func searchableComment(forPath path: String) -> String? {
        contribFileComment(path)
    }

    func contribFileComment(_ path: String) -> String? {
        let dir = (path as NSString).deletingLastPathComponent
        let file = dir + "/" + CommentStore.fileName
        // Through `DescriptionFile.decode`, the same reading the Comment column uses. Reading the file
        // as UTF-8 instead — which this did — fails outright on the UTF-16 descript.ion Total Commander
        // writes (F-374): the decode threw, the code fell through to the Finder comment, and a plugin
        // asking about a TC-annotated file was told there was no comment while the column showed one.
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: file)) else {
            return FinderComment.read(path)          // no descript.ion: fall back to the Finder comment
        }
        let name = (path as NSString).lastPathComponent
        return DescriptionFile(parsing: DescriptionFile.decode(data).text).comment(for: name)
            ?? FinderComment.read(path)
    }

    func contribSetFileComment(_ comment: String?, path: String) {
        // The plugin ABI is synchronous and has no way to carry a failure back, so this stays
        // fire-and-forget; the automation tool calls the same method and does report one.
        Task { @MainActor in try? await self.setFileComment(comment, path: path) }
    }

    /// Set or clear the `descript.ion` comment for a local path, keeping the Finder comment in step.
    ///
    /// One implementation for the plugin ABI and the `set_comment` automation tool: two would drift, and
    /// the interesting part — the Finder mirror and telling the column to re-read — is easy to forget.
    func setFileComment(_ comment: String?, path: String) async throws {
        let fs = LocalFS()
        let dir = VFSPath(filesystemId: fs.scheme, path: (path as NSString).deletingLastPathComponent)
        let name = (path as NSString).lastPathComponent
        try await CommentStore.setComment(comment, for: name, inDir: dir, on: fs)
        FinderComment.write(comment, to: path)       // same mirror the host's own editor keeps (F-023)
        // The Comment column reads separately, so it has to be told.
        for panel in [leftPanelController, rightPanelController] { panel?.refreshComments() }
    }

    func contribOpenPath(_ path: String) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return }
        let target = isDir.boolValue ? path : (path as NSString).deletingLastPathComponent
        Task { @MainActor in await activePanel?.loadDirectory(target) }
    }

    /// Navigate a specific panel (side 0 = left, 1 = right) to `path`; a file
    /// navigates to its parent folder and is selected there.
    func contribOpenPathInPanel(side: Int, path: String) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return }
        guard let panel = (side == 1 ? rightPanelController : leftPanelController) else { return }
        let isDirectory = isDir.boolValue
        let target = isDirectory ? path : (path as NSString).deletingLastPathComponent
        activePanel = panel
        Task { @MainActor in
            if isDirectory {
                await panel.loadDirectory(target)
            } else {
                await panel.loadDirectory(target, selecting: (path as NSString).lastPathComponent)
            }
        }
    }

    /// Show the plugin view `viewId` in the sidebar, rooted at `root`.
    func contribPresentSidebarView(viewId: String, root: String) {
        diskMapRoot = root
        ViewContainerRegistry.shared.refresh(host: self)   // `when` now passes → mounted
        if !previewIsVisible { togglePreviewPanel() }
        previewPanel.selectPluginView(id: viewId)
    }

    /// Remove the on-demand sidebar view and reset its state.
    func contribDismissSidebarView(viewId: String) {
        diskMapRoot = nil
        ViewContainerRegistry.shared.refresh(host: self)
    }

    /// Let the viewer reach the Notes plugin, if it is installed (F-379).
    ///
    /// Installed from here because the registry is rebuilt whenever the enabled plugins change, and the
    /// bridge must then point at the new one; disabling the plugin clears it and the viewer loses the
    /// command and the group with it.
    private func installNoteBridge(registry: ContentFieldRegistry) {
        let fieldID = "\(Self.noteProviderSlug).\(Self.noteLinesFieldID)"
        guard registry.allQualifiedFields().contains(where: { $0.qualifiedID == fieldID }) else {
            ListerNoteBridge.shared = nil
            return
        }
        ListerNoteBridge.shared = ListerNoteBridge(
            annotatedLines: { path in
                let display = await registry.value(qualifiedID: fieldID,
                                                   forFileAt: URL(fileURLWithPath: path)).display
                return ContentFieldValues.lineNumbers(display)
            },
            editNote: { [weak self] target in
                guard let self else { return }
                // Published through the ordinary context, which is how every other plugin reads host
                // state; the plugin picks it up in its own command handler and stores the note under
                // that key, so the overview and the search find it without knowing about viewers.
                self.pendingNoteTarget = target
                Task { @MainActor in
                    // Cleared as soon as the command has read it: a target left standing would send the
                    // *next* plain "edit note" to a line in a file the user is no longer looking at.
                    defer { self.pendingNoteTarget = nil }
                    _ = await ContributionRegistry.shared.dispatch("plugin.notes.edit", host: self)
                }
            })
    }

    /// The Notes plugin's provider slug and its "Note lines" field id (see `PDXContentProvider.fieldID`).
    private static let noteProviderSlug = "notes"
    private static let noteLinesFieldID = "note_lines"

    func contribAugmentContext(_ context: inout ContributionContext) {
        // Only meaningful for the one command that reads it, and cleared by whoever set it — a stale
        // target would silently send the next plain "edit note" to a line in some other file.
        context.set("noteTarget", pendingNoteTarget)
        context.set("diskMapActive", diskMapRoot != nil)
        context.set("sidebarViewRoot", diskMapRoot)
        context.set("dir", cachedActiveCwd)
        // Which panel is active, in the same 0 = left / 1 = right terms `openPathInPanel` takes, so a
        // plugin that produces files can put them in the *other* panel — beside the input rather than
        // on top of it, which is what F5 and the compare tools do.
        context.set("activeSide", activePanel === rightPanelController ? "1" : "0")
        // Config root so a plugin (e.g. the AI assistant) can persist its own data
        // under the same (possibly -ConfigRoot-overridden) location as the host.
        context.set("configRoot", configPaths.mainConfig.deletingLastPathComponent().path)
        // AI cloud endpoint (the AI plugin reads these to pick its provider).
        context.set("AI.CloudBaseURL", cachedCloudBase)
        context.set("AI.CloudModel", cachedCloudModel)
        // Theme colours, so a plugin's own views can match the host (F-338). Pure addition: a
        // plugin that reads none of these keys behaves exactly as before. Read from the cache —
        // this function runs on every keystroke and every menu validation.
        //
        // Filled on demand if applyAppearance has not run yet: plugins are loaded before the config
        // is read, so an early context query would otherwise be answered with no theme at all and a
        // plugin would see "this host does not support themes". The dictionary always has entries
        // once built, so empty is an unambiguous "not computed yet".
        if Theme.pluginContext.isEmpty {
            Theme.pluginContext = Theme.pluginContextValues(
                colors: Theme.current,
                isDark: Self.appearanceIsDark(themeId: themeId, setting: appearanceSetting),
                themeId: themeId)
        }
        for (key, value) in Theme.pluginContext { context.set(key, value) }
    }

    /// Long-term AI memory file (under the config root, beside the chat sessions).
    var automationMemoryURL: URL {
        configPaths.mainConfig.deletingLastPathComponent().appendingPathComponent("aichat/memory.json")
    }

    // Expose the automation core + policy to contribution plugins (e.g. the AI plugin).
    func contribAutomationCore() -> AutomationCore? { automationCore }
    func contribAutomationPolicy() async -> PermissionPolicy { await currentAutonomyPolicy() }

    /// Emit a panel-changed event on the Automation Core event bus.
    func emitPanelEvent(_ side: HostEvent.PanelSide) {
        let ctrl = side == .left ? leftPanelController : rightPanelController
        hostEventBus.emit(.panelChanged(side: side, path: ctrl?.directoryPath ?? ""))
    }

    /// Emit a cursor-changed event on the Automation Core event bus.
    func emitCursorEvent(_ side: HostEvent.PanelSide) {
        let ctrl = side == .left ? leftPanelController : rightPanelController
        hostEventBus.emit(.cursorChanged(side: side, path: ctrl?.tableView.cursorItemFullPath()))
    }

    // MARK: - Automation Core host helpers (reach the private registries)

    /// The active panel's folder, or Home if none.
    func automationActivePath() -> String { activePanel?.directoryPath ?? NSHomeDirectory() }

    // MARK: - AppleScript adapter (F-296)

    var scriptActiveFolder: String { activePanel?.directoryPath ?? NSHomeDirectory() }
    var scriptInactiveFolder: String {
        let inactive = (activePanel === leftPanelController) ? rightPanelController : leftPanelController
        return inactive?.directoryPath ?? ""
    }
    var scriptSelectionPaths: [String] { activePanel?.tableView.selectedOrCursorPathsSync() ?? [] }

    /// Navigate a panel to `path` (side 0=left, 1=right, nil=active). Returns the
    /// resulting folder for the script.
    @discardableResult
    func scriptGoTo(path: String, side: Int?) -> String {
        let target = side ?? (activePanel === leftPanelController ? 0 : 1)
        contribOpenPathInPanel(side: target, path: path)
        return path
    }

    /// Select entries in the active panel by a wildcard mask; returns the new selection.
    @discardableResult
    func scriptSelect(mask: String) -> [String] {
        activePanel?.tableView.applySelectionMask(mask, unselect: false, includeDirectories: true)
        return activePanel?.tableView.selectedOrCursorPathsSync() ?? []
    }

    /// Copy or move the active panel's selection to `dest` via the background queue.
    func scriptTransferSelection(copy: Bool, to dest: String) {
        let items = activePanel?.tableView.selectedOrCursorPathsSync() ?? []
        guard !items.isEmpty else { return }
        let kind: OperationKind = copy
            ? .copy(items: items, toDirectory: dest, options: CopyOptions())
            : .move(items: items, toDirectory: dest, options: CopyOptions())
        TransferManager.shared.enqueue(kind, title: (copy ? "Copy " : "Move ") + "\(items.count) item(s)")
    }

    func scriptRunCommand(_ id: String) { runCommandNamed(id) }

    /// All registered commands (id/name/category/help/implemented) for `list_commands`.
    func automationCommands() async -> [[String: Any]] {
        await commandRegistry.getAllCommands().map {
            ["id": $0.id, "name": $0.name, "category": $0.category, "help": $0.help, "implemented": $0.implemented]
        }
    }

    /// One command by id, for classifying what `run_command` is about to do.
    func automationCommand(named id: String) async -> PCCommand? {
        await commandRegistry.getAllCommands().first { $0.name == id }
    }

    /// Enabled plugins (name/type) for `list_plugins`.
    func automationPlugins() async -> [[String: Any]] {
        await pluginManager.enabledPlugins().map {
            ["name": $0.manifest.name, "type": String(describing: $0.manifest.type)]
        }
    }

    /// Start the MCP server if enabled in config. Loopback-only; connect an external
    /// agent with a stdio bridge, e.g. Claude Code: {"command":"nc","args":["127.0.0.1","<port>"]}.
    func startMCPServerIfEnabled() async {
        guard await mainConfig.bool("Automation", "MCPServerEnabled", default: false) else { return }
        let port = UInt16(clamping: await mainConfig.int("Automation", "MCPPort", default: 8790))
        let token = await mainConfig.string("Automation", "MCPAuthToken", default: "")
        startMCPServer(port: port, authToken: token)
    }

    /// Start the loopback MCP server on `port` (no-op if already running). If
    /// `authToken` is non-empty, clients must authenticate with it first.
    func startMCPServer(port: UInt16, authToken: String = "") {
        guard mcpServer == nil else { return }
        let server = MCPSocketServer(mcp: MCPServer(core: automationCore, policy: .standard), authToken: authToken)
        do {
            try server.start(port: port) { p in NSLog("[mcp] MCP server listening on 127.0.0.1:\(p)") }
            mcpServer = server
        } catch {
            NSLog("[mcp] failed to start MCP server: \(error)")
        }
    }

    func stopMCPServer() { mcpServer?.stop(); mcpServer = nil }

    // AI plugin config (aichat/config.json) — shared with the plugin, which reads it
    // when building a chat. Kept as a plain dict here to avoid coupling the host to the
    // plugin's Codable type; only the two keys the settings page edits are touched.
    private static func aiPluginConfigURL(root: URL) -> URL {
        root.appendingPathComponent("aichat/config.json")
    }
    static func readAIPluginConfig(root: URL) -> [String: Any] {
        guard let d = try? Data(contentsOf: aiPluginConfigURL(root: root)),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }
    static func writeAIPluginConfig(root: URL, field: String, value: String) {
        var dict = readAIPluginConfig(root: root)
        dict[field] = value
        let url = aiPluginConfigURL(root: root)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) {
            try? d.write(to: url, options: .atomic)
        }
    }

    // Cloud API key storage — same Keychain the plugin reads via the crypt callback
    // (service "com.peachcommander.contrib", account "AI.CloudKey").
    private static let aiKeyService = "com.peachcommander.contrib"
    private static let aiKeyAccount = "AI.CloudKey"
    static func saveCloudKeyToKeychain(_ value: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: aiKeyService,
                                kSecAttrAccount as String: aiKeyAccount]
        SecItemDelete(q as CFDictionary)
        guard !value.isEmpty else { return }
        var add = q; add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
    static func cloudKeyExists() -> Bool {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: aiKeyService,
                                kSecAttrAccount as String: aiKeyAccount,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        return SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess
    }

    /// The permission policy for new AI sessions, from the AI.Autonomy setting.
    func currentAutonomyPolicy() async -> PermissionPolicy {
        // Off unless asked for, and asked for in Settings rather than in a dialog. Every other
        // capability the assistant has is something a file manager's assistant is *for*; running a
        // program of its choosing is not, and the first time somebody meets that capability should
        // not be in a modal with a command already written in it.
        //
        // Autonomous is deliberately not exempt. "Do not ask me about writes" is a statement about
        // file operations, made before this existed; reading it as "and you may run programs" would
        // be putting words in the user's mouth.
        let shell = await mainConfig.bool("AI", "AllowShell", default: false)
        switch await mainConfig.string("AI", "Autonomy", default: "confirm") {
        case "readonly":   return .readOnly
        case "autonomous":
            let allowed = shell ? Set(Capability.allCases) : Set(Capability.allCases).subtracting([.shell])
            return PermissionPolicy(autonomy: .autonomous, allowed: allowed)
        default:           return shell ? .standardWithShell : .standard
        }
    }

    /// Run a bounded file search and return the matching absolute paths.
    func automationSearch(mask: String, text: String?, startDirectory: String,
                          maxDepth: Int, limit: Int) async -> [String] {
        let query = SearchQuery(nameMask: mask.isEmpty ? "*" : mask,
                                startDirectory: startDirectory, maxDepth: maxDepth, contentText: text)
        var hits: [String] = []
        for await hit in FileSearchEngine().search(query, fs: LocalFS()) {
            hits.append(hit.path)
            if hits.count >= limit { break }
        }
        return hits
    }
}

// MARK: - ToolHost (in-process tool host services)

extension MainWindowController: ToolHost {
    func toolCursorPath() -> String? { activePanel?.tableView.cursorItemFullPath() }
    func toolSelectionPaths() async -> [String] { await activePanel?.selectedOrCursorPaths() ?? [] }

    func toolLocalCursorPath() async -> String? {
        guard let panel = activePanel else { return nil }
        if panel.isInArchive { return await panel.localPathForCursor() }
        // A real file under the cursor (not a directory or "..").
        return panel.tableView.cursorDirectoryPath() == nil ? panel.tableView.cursorItemFullPath() : nil
    }
    var toolParentWindow: NSWindow? { window }

    func toolMoveToTrash(_ paths: [String]) {
        NSWorkspace.shared.recycle(paths.map { URL(fileURLWithPath: $0) }) { [weak self] _, _ in
            Task { @MainActor in await self?.activePanel?.reload() }
        }
    }

    func toolDeletePermanently(_ paths: [String]) {
        for p in paths { try? FileManager.default.removeItem(atPath: p) }
        Task { @MainActor in await activePanel?.reload() }
    }

    func toolReloadActivePanel() { Task { @MainActor in await activePanel?.reload() } }
    func toolPresentInfo(_ title: String, _ message: String) { presentInfo(title, message) }
}

// MARK: - FileSystemHost (PFX plugin host services)

extension MainWindowController: FileSystemHost {
    func fsMount(_ fs: VirtualFileSystem, startPath: String) {
        // Read here, not in the Task: `mountPluginVolume` clears it as soon as `connect` returns,
        // which is long before the mount is actually loaded. nil for a connect that came from a
        // dialog rather than a drive chip — then there is no chip to keep selected.
        let driveVolume = pendingDriveVolume
        let target = pendingMountPanel ?? activePanel
        Task { @MainActor in
            await target?.enterNetwork(fs, startPath: startPath, driveVolume: driveVolume)
        }
    }
    var fsParentWindow: NSWindow? { window }
    func fsPresentInfo(_ title: String, _ message: String) { presentInfo(title, message) }
}

/// Modal secure prompt for an encrypted archive's password (F-136). Returns nil
/// if cancelled or empty. Shared by the archive-enter and unpack flows.
@MainActor
fileprivate func promptArchivePassword(name: String) -> (password: String, remember: Bool)? {
    let alert = NSAlert()
    alert.messageText = String(localized: "Password Required")
    alert.informativeText = String(format: String(localized: "“%@” is password-protected. Enter its password to continue."), name)
    let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    let remember = NSButton(checkboxWithTitle: String(localized: "Remember password in Keychain"),
                            target: nil, action: nil)
    let stack = NSStackView(views: [field, remember])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.frame = NSRect(x: 0, y: 0, width: 280, height: 52)
    field.widthAnchor.constraint(equalToConstant: 260).isActive = true
    alert.accessoryView = stack
    alert.addButton(withTitle: String(localized: "OK"))
    alert.addButton(withTitle: String(localized: "Cancel"))
    guard alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty else { return nil }
    return (field.stringValue, remember.state == .on)
}

/// Keychain service for remembered archive passwords (F-136).
private let archivePasswordService = "PeachCommander.archive"

/// Resolve the password for an encrypted archive at `localPath`: reuse a valid
/// Keychain-remembered one if present, else prompt (and remember on request).
/// Sets `archive.password` and returns it, or nil if the user cancelled.
@MainActor fileprivate func resolveArchivePassword(for archive: ArchiveFS, localPath: String) -> String? {
    let store = KeychainSecretStore()
    if let saved = (try? store.password(service: archivePasswordService, account: localPath)) ?? nil, !saved.isEmpty {
        archive.password = saved
        if archive.passwordIsValid() { return saved }
        try? store.deletePassword(service: archivePasswordService, account: localPath)   // stale
    }
    guard let result = promptArchivePassword(name: (localPath as NSString).lastPathComponent) else { return nil }
    archive.password = result.password
    if result.remember, archive.passwordIsValid() {
        try? store.setPassword(result.password, service: archivePasswordService, account: localPath)
    }
    return result.password
}
