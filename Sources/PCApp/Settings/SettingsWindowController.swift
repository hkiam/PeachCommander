// SPDX-License-Identifier: Apache-2.0
// SettingsWindowController.swift - Settings (Options) dialog for I05
//
// A "dumb" synchronous view: it is constructed with a snapshot of the
// current values and reports every change immediately through the
// `onSetBool`/`onSetString` callbacks. It never reads from or writes to
// ConfigStore (or any other app state) directly.

import AppKit
import PCFoundation

/// Immutable snapshot of the settings values shown by `SettingsWindowController`.
public struct SettingsSnapshot: Sendable {
    public var showHidden: Bool
    public var iconMode: String        // "none" | "standard" | "all"
    public var appearance: String      // "light" | "dark"
    public var theme: String           // "system" (default) | a Theme.palettes id
    public var confirmDelete: Bool
    public var deleteToTrash: Bool
    public var selectDirsWithMask: Bool
    public var verifyAfterCopy: Bool
    public var quickSearchMode: String   // "direct" | "ctrlalt" | "cmdline" | "off"
    public var mouseMode: String         // "left" (Windows) | "nc" (Norton Commander)
    public var bracketsAroundDirs: Bool
    public var naturalSort: Bool       // F-026: numeric ("file2 < file10") ordering
    public var alternatingRows: Bool   // F-032: zebra row background
    public var fontSize: Int           // F-272: panel-list font size (points)
    public var sizeStyle: String       // "kb" | "dynamic" | "bytes"
    public var dateFormat: String      // Unicode pattern; "" = system locale
    public var showButtonBar: Bool = true   // F-342
    public var showDriveBar: Bool = true    // F-270
    public var showStatusBar: Bool = true   // F-270
    public var showTabBar: Bool = true      // F-270
    public var showPathBar: Bool = true     // F-270
    public var showCommandLine: Bool
    public var showFunctionKeys: Bool
    // Copy/Delete page (F-271)
    public var copyPreserveMetadata: Bool
    public var copyCloneCopy: Bool
    public var copyOnlyNewer: Bool
    public var copySpeedLimitKBps: Int
    // Zip/Packer page (F-274)
    public var packDefaultFormat: String   // PackFormat raw value, e.g. "zip"
    public var packLevel: Int              // 0…9
    public var packArchiveExtensions: String = ""  // F-274: extra extensions treated as archives
    // Tabs page
    public var tabOpenInForeground: Bool
    public var tabLockedOpensNewTab: Bool
    // FTP page
    public var ftpKeepAliveSeconds: Int    // 0 = off
    // AI page
    public var aiMCPEnabled: Bool = false          // Automation.MCPServerEnabled
    public var aiMCPPort: Int = 8790               // Automation.MCPPort
    public var aiMCPToken: String = ""             // Automation.MCPAuthToken ("" = no auth)
    public var aiAutonomy: String = "confirm"      // AI.Autonomy: "readonly" | "confirm" | "autonomous"
    public var aiCloudBase: String = ""            // AI.CloudBaseURL ("" = on-device)
    public var aiCloudModel: String = "local"      // AI.CloudModel
    public var aiHasCloudKey: Bool = false         // whether a Cloud API key is stored (Keychain)
    // Assistant preferences owned by the AI plugin (aichat/config.json), surfaced here
    // so all AI settings live on one page. Routed via the "AIPlugin.*" keyPaths.
    public var aiModelPreference: String = "auto"  // "auto" | "local" | "cloud"
    public var aiSystemPrompt: String = ""         // "" = built-in default
    // Colors page (F-272): custom panel colours as "RRGGBB" hex, "" = theme default.
    public var customForeground: String = ""
    public var customBackground: String = ""
    public var customSelection: String = ""
    public var customCursor: String = ""

    public init(showHidden: Bool, iconMode: String, appearance: String, theme: String = "system",
                confirmDelete: Bool, deleteToTrash: Bool, selectDirsWithMask: Bool,
                bracketsAroundDirs: Bool, naturalSort: Bool = true, alternatingRows: Bool = false,
                fontSize: Int = 13, sizeStyle: String,
                dateFormat: String = PanelDateFormatter.defaultPattern,
                showCommandLine: Bool = true, showFunctionKeys: Bool = true,
                showButtonBar: Bool = true,
                showDriveBar: Bool = true, showStatusBar: Bool = true,
                showTabBar: Bool = true, showPathBar: Bool = true,
                verifyAfterCopy: Bool = false, quickSearchMode: String = "direct",
                mouseMode: String = "left",
                copyPreserveMetadata: Bool = true, copyCloneCopy: Bool = true,
                copyOnlyNewer: Bool = false, copySpeedLimitKBps: Int = 0,
                packDefaultFormat: String = "zip", packLevel: Int = 5,
                packArchiveExtensions: String = "",
                tabOpenInForeground: Bool = true, tabLockedOpensNewTab: Bool = true,
                ftpKeepAliveSeconds: Int = 0,
                aiMCPEnabled: Bool = false, aiMCPPort: Int = 8790, aiMCPToken: String = "",
                aiAutonomy: String = "confirm",
                aiCloudBase: String = "", aiCloudModel: String = "local", aiHasCloudKey: Bool = false,
                aiModelPreference: String = "auto", aiSystemPrompt: String = "",
                customForeground: String = "", customBackground: String = "",
                customSelection: String = "", customCursor: String = "") {
        self.aiMCPEnabled = aiMCPEnabled
        self.aiMCPPort = aiMCPPort
        self.aiMCPToken = aiMCPToken
        self.aiAutonomy = aiAutonomy
        self.aiCloudBase = aiCloudBase
        self.aiCloudModel = aiCloudModel
        self.aiHasCloudKey = aiHasCloudKey
        self.aiModelPreference = aiModelPreference
        self.aiSystemPrompt = aiSystemPrompt
        self.customForeground = customForeground
        self.customBackground = customBackground
        self.customSelection = customSelection
        self.customCursor = customCursor
        self.showHidden = showHidden
        self.iconMode = iconMode
        self.appearance = appearance
        self.theme = theme
        self.confirmDelete = confirmDelete
        self.deleteToTrash = deleteToTrash
        self.selectDirsWithMask = selectDirsWithMask
        self.verifyAfterCopy = verifyAfterCopy
        self.quickSearchMode = quickSearchMode
        self.mouseMode = mouseMode
        self.bracketsAroundDirs = bracketsAroundDirs
        self.naturalSort = naturalSort
        self.alternatingRows = alternatingRows
        self.fontSize = fontSize
        self.sizeStyle = sizeStyle
        self.dateFormat = dateFormat
        self.showButtonBar = showButtonBar
        self.showDriveBar = showDriveBar
        self.showStatusBar = showStatusBar
        self.showTabBar = showTabBar
        self.showPathBar = showPathBar
        self.showCommandLine = showCommandLine
        self.showFunctionKeys = showFunctionKeys
        self.copyPreserveMetadata = copyPreserveMetadata
        self.copyCloneCopy = copyCloneCopy
        self.copyOnlyNewer = copyOnlyNewer
        self.copySpeedLimitKBps = copySpeedLimitKBps
        self.packDefaultFormat = packDefaultFormat
        self.packLevel = packLevel
        self.packArchiveExtensions = packArchiveExtensions
        self.tabOpenInForeground = tabOpenInForeground
        self.tabLockedOpensNewTab = tabLockedOpensNewTab
        self.ftpKeepAliveSeconds = ftpKeepAliveSeconds
    }
}

/// A page shown in the settings source list.
private enum SettingsPage: Int, CaseIterable {
    case layout
    case display
    case icons
    case operation
    case colors
    case confirmation
    case editView
    case copyDelete
    case zipPacker
    case plugins
    case tabs
    case ftp
    case keys
    case language
    case ai
    case misc

    /// Localized title shown in the source list row (Total Commander ordering).
    var title: String {
        switch self {
        case .layout: return String(localized: "Layout")
        case .display: return String(localized: "Display")
        case .icons: return String(localized: "Icons")
        case .operation: return String(localized: "Operation")
        case .colors: return String(localized: "Colors")
        case .confirmation: return String(localized: "Confirmation")
        case .editView: return String(localized: "Edit/View")
        case .copyDelete: return String(localized: "Copy/Delete")
        case .zipPacker: return String(localized: "Zip/Packer")
        case .plugins: return String(localized: "Plugins")
        case .tabs: return String(localized: "Tabs")
        case .ftp: return String(localized: "FTP")
        case .keys: return String(localized: "Keyboard")
        case .language: return String(localized: "Language")
        case .ai: return String(localized: "AI")
        case .misc: return String(localized: "Misc")
        }
    }
}

/// Settings (Options) window controller. A dumb, synchronous view: the
/// snapshot it is built with only seeds its controls; every later change
/// is reported through `onSetBool`/`onSetString` with a dotted
/// "Section.Key" identifier. Nothing is persisted here.
@MainActor
public final class SettingsWindowController: NSWindowController {
    private let snapshot: SettingsSnapshot
    private let onSetBool: (_ keyPath: String, _ value: Bool) -> Void
    private let onSetString: (_ keyPath: String, _ value: String) -> Void

    private let sourceList = NSTableView()
    private let contentContainer = NSView()
    private var pageViews: [SettingsPage: NSView] = [:]

    // Plugin-contributed settings panes (container "settings"), appended after the
    // fixed built-in pages. Each pane's view is built lazily via PcMakeView and torn
    // down when the window closes.
    private var pluginPanes: [PreviewViewProvider] = []
    private var pluginPaneViews: [String: NSView] = [:]
    private var builtinPageCount: Int { SettingsPage.allCases.count }

    // Plugins page (F-274): installed plugins with enable checkboxes.
    private var pluginRows: [PluginRow] = []
    var onTogglePlugin: ((_ name: String, _ enabled: Bool) -> Void)?
    var onOpenPluginsManager: (() -> Void)?

    /// Supply the installed-plugin rows for the Plugins page (before `showModalless`).
    func setPluginRows(_ rows: [PluginRow]) { pluginRows = rows }

    /// Supply plugin settings panes (call before `showModalless`).
    func setPluginPanes(_ panes: [PreviewViewProvider]) {
        pluginPanes = panes
        sourceList.reloadData()
    }

    // Layout page controls
    private let commandLineCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let functionKeysCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let buttonBarCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)   // F-342
    private let driveBarCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)   // F-270
    private let statusBarCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)   // F-270
    private let tabBarCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)   // F-270
    private let pathBarCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)   // F-270

    // Display page controls
    private let showHiddenCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let sizeStylePopup = NSPopUpButton()
    private let bracketsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let naturalSortCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)   // F-026
    private let alternatingRowsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)   // F-032
    private let fontSizePopup = NSPopUpButton()   // F-272
    private let dateFormatField = NSTextField()
    private let datePreviewLabel = NSTextField(labelWithString: "")

    // Icons page controls
    private let iconModePopup = NSPopUpButton()

    // Operation page controls
    private let selectDirsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let verifyAfterCopyCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let quickSearchPopup = NSPopUpButton()
    private let mouseModePopup = NSPopUpButton()
    private let mouseModes: [(raw: String, label: String)] = [
        ("left", String(localized: "Left click; right click shows the menu (Windows)")),
        ("nc", String(localized: "Right click marks files (Norton Commander)")),
    ]
    /// Quick-search modes in popup order (raw value, label).
    private let quickSearchModes: [(raw: String, label: String)] = [
        ("direct", String(localized: "Type letters directly")),
        ("ctrlalt", String(localized: "Only with Ctrl+Alt")),
        ("cmdline", String(localized: "Type into the command line")),
        ("off", String(localized: "Off")),
    ]

    // Colors page controls
    private let appearancePopup = NSPopUpButton()
    private let themePopup = NSPopUpButton()
    // F-272: custom panel colour wells (each paired with an "enabled" checkbox).
    private let fgWell = NSColorWell(), fgCheck = NSButton()
    private let bgWell = NSColorWell(), bgCheck = NSButton()
    private let selWell = NSColorWell(), selCheck = NSButton()
    private let curWell = NSColorWell(), curCheck = NSButton()

    // Confirmation page controls
    private let confirmDeleteCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let deleteToTrashCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    // Copy/Delete page controls
    private let preserveMetadataCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let cloneCopyCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let onlyNewerCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    // Tabs page controls
    private let openInForegroundCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let lockedOpensNewTabCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    // Keyboard page controls
    private let keySchemePopup = NSPopUpButton()
    /// Scheme raw values in popup order.
    private let keySchemes: [(raw: String, label: String)] = [
        ("tc-classic", String(localized: "Total Commander (classic)")), ("macos", String(localized: "macOS")),
    ]

    // FTP page controls
    private let ftpKeepAliveField = NSTextField()
    private let speedLimitField = NSTextField()

    // AI page controls
    private let aiMCPCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let aiPortField = NSTextField()
    private let aiTokenField = NSTextField()
    private let aiAutonomyPopup = NSPopUpButton()
    private let aiCloudBaseField = NSTextField()
    private let aiCloudModelField = NSTextField()
    private let aiCloudKeyField = NSSecureTextField()
    private let aiModelPrefPopup = NSPopUpButton()
    private let aiSystemPromptView = NSTextView()
    private let aiModelPrefs: [(raw: String, label: String)] = [
        ("auto", String(localized: "Automatic (cloud if configured, else on-device)")),
        ("local", String(localized: "On-device (Apple Intelligence)")),
        ("cloud", String(localized: "Cloud (configured endpoint)")),
    ]
    private let aiAutonomies: [(raw: String, label: String)] = [
        ("readonly", String(localized: "Read-only (analyze, never change)")),
        ("confirm", String(localized: "Confirm changes (show a plan first)")),
        ("autonomous", String(localized: "Autonomous (act without asking)")),
    ]

    // Language page controls
    private let languagePopup = NSPopUpButton()
    /// Language raw values in popup order ("system" = follow the OS).
    private let languages: [(raw: String, label: String)] = [
        ("system", String(localized: "System default")), ("en", "English"), ("de", "Deutsch"),
    ]

    // Zip/Packer page controls
    private let packFormatPopup = NSPopUpButton()
    private let packLevelPopup = NSPopUpButton()
    private let archiveExtField = NSTextField()   // F-274: extra archive extensions
    /// Format raw values in popup order.
    private let packFormats: [(raw: String, label: String)] = [
        ("zip", "Zip"), ("sevenZip", "7z"), ("tar", "Tar"),
        ("tarGz", "Tar + gzip"), ("tarBz2", "Tar + bzip2"), ("tarXz", "Tar + xz"),
    ]
    /// Compression levels in popup order, paired with 0…9 value.
    private let packLevels: [(value: Int, label: String)] = [
        (0, String(localized: "Store (no compression)")), (1, String(localized: "Fast")),
        (5, String(localized: "Normal")), (9, String(localized: "Maximum")),
    ]

    private let associations: FileAssociations
    private let onSaveAssociations: (FileAssociations) -> Void
    private let configRootPath: String
    private let onOpenConfigFolder: () -> Void
    /// Prepare + reveal the themes folder; the controller owns the paths (F-337).
    private let onOpenThemesFolder: () -> Void
    /// Where to re-read user themes from when the Theme menu opens. nil disables reloading.
    private let themesDirectory: URL?
    private let currentLanguage: String
    private let onSetLanguage: (String) -> Void
    private let currentKeyScheme: String
    private let onSetKeyScheme: (String) -> Void
    private let onEditShortcuts: () -> Void

    public init(snapshot: SettingsSnapshot,
                associations: FileAssociations = FileAssociations(),
                configRootPath: String = "",
                currentLanguage: String = "system",
                currentKeyScheme: String = "tc-classic",
                onSetBool: @escaping (_ keyPath: String, _ value: Bool) -> Void,
                onSetString: @escaping (_ keyPath: String, _ value: String) -> Void,
                onSaveAssociations: @escaping (FileAssociations) -> Void = { _ in },
                onOpenConfigFolder: @escaping () -> Void = {},
                onOpenThemesFolder: @escaping () -> Void = {},
                themesDirectory: URL? = nil,
                onSetLanguage: @escaping (String) -> Void = { _ in },
                onSetKeyScheme: @escaping (String) -> Void = { _ in },
                onEditShortcuts: @escaping () -> Void = {}) {
        self.snapshot = snapshot
        self.associations = associations
        self.configRootPath = configRootPath
        self.currentLanguage = currentLanguage
        self.currentKeyScheme = currentKeyScheme
        self.onSetBool = onSetBool
        self.onSetString = onSetString
        self.onSaveAssociations = onSaveAssociations
        self.onOpenConfigFolder = onOpenConfigFolder
        self.onOpenThemesFolder = onOpenThemesFolder
        self.themesDirectory = themesDirectory
        self.onSetLanguage = onSetLanguage
        self.onSetKeyScheme = onSetKeyScheme
        self.onEditShortcuts = onEditShortcuts

        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 680, 520),
            // Resizable: panes differ enormously in height — the plugin list grows with
            // every installed plugin — and a fixed 440pt window simply cut the rest off.
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Settings")
        // Small enough to fit a laptop screen, large enough that the source list and a
        // pane's controls stay usable.
        window.minSize = NSSize(width: 620, height: 400)
        super.init(window: window)
        setupWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Center the window, show it and make it key/front. Not modal.
    public func showModalless() {
        window?.center()
        showWindow(self)
        window?.makeKeyAndOrderFront(self)
    }

    // MARK: - Window setup

    private func setupWindow() {
        guard let window else { return }
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        let splitContainer = NSView()
        splitContainer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(splitContainer)

        setupSourceList(in: splitContainer)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addSubview(contentContainer)

        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.title = String(localized: "Close")
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.target = self
        closeButton.action = #selector(closeAction)
        content.addSubview(closeButton)

        guard let scrollView = sourceList.enclosingScrollView else { return }

        NSLayoutConstraint.activate([
            splitContainer.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            splitContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            splitContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            splitContainer.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -16),

            scrollView.leadingAnchor.constraint(equalTo: splitContainer.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),
            scrollView.widthAnchor.constraint(equalToConstant: 150),

            contentContainer.leadingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 16),
            contentContainer.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: splitContainer.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),

            closeButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            closeButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])

        selectPage(.layout)
    }

    /// Re-apply the theme to the surfaces this window colours itself (F-339).
    ///
    /// Derived from `Theme.current` every time rather than remembering a previous value, which is
    /// what makes switching back to the default correct: the source list simply gets whatever the
    /// default palette says, exactly as it would on a fresh window.
    public func applyTheme() {
        sourceList.backgroundColor = Theme.current.listBackground
        sourceList.enclosingScrollView?.backgroundColor = Theme.current.listBackground
        sourceList.reloadData()
    }

    private func setupSourceList(in parent: NSView) {
        sourceList.headerView = nil
        sourceList.rowHeight = Metrics.rowHeight + 4
        sourceList.backgroundColor = Theme.current.listBackground
        sourceList.delegate = self
        sourceList.dataSource = self
        sourceList.allowsMultipleSelection = false
        sourceList.allowsEmptySelection = false
        sourceList.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("page")))

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = sourceList
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        parent.addSubview(scrollView)

        sourceList.reloadData()
        sourceList.selectRowIndexes(IndexSet(integer: SettingsPage.layout.rawValue), byExtendingSelection: false)
    }

    // MARK: - Page switching

    private func selectPage(_ page: SettingsPage) {
        mount(pageViews[page] ?? buildAndCachePage(page))
    }

    /// Put `view` in the content area inside a scroll view.
    ///
    /// Panes were previously pinned to top/leading/trailing only, with no bottom anchor and
    /// no scroll view anywhere — so a pane taller than the window did not scroll, it was
    /// silently clipped. On the Plugins pane that hid the "Manage Plugins…" button below the
    /// edge, which looked like a dead button rather than a layout problem. Scrolling here
    /// rather than inside makePageStack covers plugin-contributed panes too, since those
    /// never went through it.
    private func mount(_ view: NSView) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        // The document view must be flipped, or AppKit puts its origin at the bottom left:
        // a pane shorter than the window then sits at the foot of the empty space, and a
        // taller one opens scrolled to its end. Panes arrive as plain NSStackViews (and
        // plugin panes as arbitrary views), none of which are flipped, so they go inside a
        // flipped container rather than being subclassed. Same reason the codebase overrides
        // isFlipped for its other custom scroll contents.
        let document = FlippedContainerView()
        document.translatesAutoresizingMaskIntoConstraints = false
        view.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(view)
        scroll.documentView = document
        contentContainer.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            // The pane fills the container, so the container's height *is* the pane's height.
            view.topAnchor.constraint(equalTo: document.topAnchor),
            view.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            // Match the width so panes reflow instead of scrolling sideways; height stays
            // free so the content decides when a scroller is needed.
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
    }

    /// Mount a plugin-contributed pane (built lazily, cached, pinned to fill).
    private func selectPluginPane(_ index: Int) {
        guard pluginPanes.indices.contains(index) else { return }
        let pane = pluginPanes[index]
        let view: NSView
        if let cached = pluginPaneViews[pane.id] {
            view = cached
        } else if let made = pane.makeView() {
            pluginPaneViews[pane.id] = made
            view = made
        } else { return }
        // Same treatment as the built-in pages: a plugin's pane is arbitrary content, so it
        // gets to scroll rather than being clipped to whatever the window happens to be.
        mount(view)
    }

    private func buildAndCachePage(_ page: SettingsPage) -> NSView {
        let view: NSView
        switch page {
        case .layout: view = buildLayoutPage()
        case .display: view = buildDisplayPage()
        case .icons: view = buildIconsPage()
        case .operation: view = buildOperationPage()
        case .colors: view = buildColorsPage()
        case .confirmation: view = buildConfirmationPage()
        case .editView: view = buildEditViewPage()
        case .copyDelete: view = buildCopyDeletePage()
        case .zipPacker: view = buildZipPackerPage()
        case .plugins: view = buildPluginsPage()
        case .tabs: view = buildTabsPage()
        case .ftp: view = buildFtpPage()
        case .keys: view = buildKeysPage()
        case .language: view = buildLanguagePage()
        case .ai: view = buildAIPage()
        case .misc: view = buildMiscPage()
        }
        pageViews[page] = view
        return view
    }

    // MARK: - Edit/View page (per-extension associations, F-273)

    private func buildEditViewPage() -> NSView {
        AssociationsPageView(associations: associations) { [weak self] updated in
            self?.onSaveAssociations(updated)
        }
    }

    // MARK: - Copy/Delete page (F-271)

    private func buildCopyDeletePage() -> NSView {
        makeCheckbox(preserveMetadataCheckbox,
                     title: String(localized: "Preserve dates, permissions and extended attributes"),
                     isOn: snapshot.copyPreserveMetadata, action: #selector(preserveMetadataChanged))
        makeCheckbox(cloneCopyCheckbox,
                     title: String(localized: "Use clone-copy on the same volume when possible"),
                     isOn: snapshot.copyCloneCopy, action: #selector(cloneCopyChanged))
        makeCheckbox(onlyNewerCheckbox,
                     title: String(localized: "Only replace existing files when the source is newer"),
                     isOn: snapshot.copyOnlyNewer, action: #selector(onlyNewerChanged))
        speedLimitField.stringValue = String(snapshot.copySpeedLimitKBps)
        speedLimitField.alignment = .right
        speedLimitField.target = self
        speedLimitField.action = #selector(speedLimitChanged)
        speedLimitField.translatesAutoresizingMaskIntoConstraints = false
        speedLimitField.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let speedNote = NSTextField(wrappingLabelWithString: String(localized:
            "Limits copy/move and network transfer speed. 0 = unlimited."))
        speedNote.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        speedNote.textColor = .secondaryLabelColor
        return makePageStack(rows: [preserveMetadataCheckbox, cloneCopyCheckbox, onlyNewerCheckbox,
            labeledRow(title: String(localized: "Speed limit (KB/s):"), control: speedLimitField), speedNote])
    }

    @objc private func preserveMetadataChanged() {
        onSetBool("Copy.PreserveMetadata", preserveMetadataCheckbox.state == .on)
    }
    @objc private func cloneCopyChanged() {
        onSetBool("Copy.CloneCopy", cloneCopyCheckbox.state == .on)
    }
    @objc private func onlyNewerChanged() {
        onSetBool("Copy.OnlyNewer", onlyNewerCheckbox.state == .on)
    }
    @objc private func speedLimitChanged() {
        let n = max(0, Int(speedLimitField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
        speedLimitField.stringValue = String(n)
        onSetString("Copy.SpeedLimitKBps", String(n))
    }

    // MARK: - Zip/Packer page (F-274)

    private func buildZipPackerPage() -> NSView {
        let fmtIndex = packFormats.firstIndex { $0.raw == snapshot.packDefaultFormat } ?? 0
        makePopup(packFormatPopup, items: packFormats.map(\.label),
                  selectedIndex: fmtIndex, action: #selector(packFormatChanged))
        let lvlIndex = packLevels.firstIndex { $0.value == snapshot.packLevel }
            ?? packLevels.enumerated().min { abs($0.element.value - snapshot.packLevel) < abs($1.element.value - snapshot.packLevel) }?.offset
            ?? 2
        makePopup(packLevelPopup, items: packLevels.map(\.label),
                  selectedIndex: lvlIndex, action: #selector(packLevelChanged))
        archiveExtField.stringValue = snapshot.packArchiveExtensions
        archiveExtField.placeholderString = "jar war ipa apk"
        archiveExtField.font = Fonts.system13
        archiveExtField.target = self
        archiveExtField.action = #selector(archiveExtChanged)
        archiveExtField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        let hint = NSTextField(labelWithString:
            String(localized: "Additional file extensions to open as archives (space-separated)."))
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        return makePageStack(rows: [
            labeledRow(title: String(localized: "Default format:"), control: packFormatPopup),
            labeledRow(title: String(localized: "Default compression:"), control: packLevelPopup),
            labeledRow(title: String(localized: "Extra archive extensions:"), control: archiveExtField),
            hint,
        ])
    }

    @objc private func archiveExtChanged() {
        onSetString("Pack.ArchiveExtensions", archiveExtField.stringValue.trimmingCharacters(in: .whitespaces))
    }

    @objc private func packFormatChanged() {
        let i = packFormatPopup.indexOfSelectedItem
        onSetString("Pack.DefaultFormat", packFormats.indices.contains(i) ? packFormats[i].raw : "zip")
    }
    @objc private func packLevelChanged() {
        let i = packLevelPopup.indexOfSelectedItem
        onSetString("Pack.Level", String(packLevels.indices.contains(i) ? packLevels[i].value : 5))
    }

    // MARK: - Tabs page (I06)

    private func buildTabsPage() -> NSView {
        makeCheckbox(openInForegroundCheckbox,
                     title: String(localized: "Open new tabs in the foreground"),
                     isOn: snapshot.tabOpenInForeground, action: #selector(openInForegroundChanged))
        makeCheckbox(lockedOpensNewTabCheckbox,
                     title: String(localized: "Navigating a locked tab opens a new tab"),
                     isOn: snapshot.tabLockedOpensNewTab, action: #selector(lockedOpensNewTabChanged))
        return makePageStack(rows: [openInForegroundCheckbox, lockedOpensNewTabCheckbox])
    }

    @objc private func openInForegroundChanged() {
        onSetBool("Tabs.OpenInForeground", openInForegroundCheckbox.state == .on)
    }
    @objc private func lockedOpensNewTabChanged() {
        onSetBool("Tabs.LockedOpensNewTab", lockedOpensNewTabCheckbox.state == .on)
    }

    // MARK: - Keyboard page (F-254): scheme picker + link to the remap grid

    private func buildKeysPage() -> NSView {
        let index = keySchemes.firstIndex { $0.raw == currentKeyScheme } ?? 0
        makePopup(keySchemePopup, items: keySchemes.map(\.label),
                  selectedIndex: index, action: #selector(keySchemeChanged))
        let edit = NSButton(title: String(localized: "Edit Shortcuts…"),
                            target: self, action: #selector(editShortcuts))
        edit.bezelStyle = .rounded
        edit.setContentHuggingPriority(.required, for: .horizontal)
        let note = NSTextField(wrappingLabelWithString: String(localized:
            "Pick a base scheme, then customize individual shortcuts. Your changes layer on top of the scheme."))
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        return makePageStack(rows: [
            labeledRow(title: String(localized: "Scheme:"), control: keySchemePopup),
            edit,
            note,
        ])
    }

    @objc private func keySchemeChanged() {
        let i = keySchemePopup.indexOfSelectedItem
        onSetKeyScheme(keySchemes.indices.contains(i) ? keySchemes[i].raw : "tc-classic")
    }

    @objc private func editShortcuts() { onEditShortcuts() }

    // MARK: - FTP page (I15)

    private func buildAIPage() -> NSView {
        makeCheckbox(aiMCPCheckbox,
                     title: String(localized: "Enable MCP server (let external agents like Claude Code control this app)"),
                     isOn: snapshot.aiMCPEnabled, action: #selector(aiChanged))
        aiPortField.stringValue = String(snapshot.aiMCPPort)
        aiPortField.alignment = .right
        aiPortField.target = self
        aiPortField.action = #selector(aiChanged)
        aiPortField.translatesAutoresizingMaskIntoConstraints = false
        aiPortField.widthAnchor.constraint(equalToConstant: 70).isActive = true
        aiTokenField.stringValue = snapshot.aiMCPToken
        aiTokenField.placeholderString = String(localized: "optional — leave empty for no auth")
        aiTokenField.target = self; aiTokenField.action = #selector(aiChanged)
        for a in aiAutonomies { aiAutonomyPopup.addItem(withTitle: a.label) }
        if let i = aiAutonomies.firstIndex(where: { $0.raw == snapshot.aiAutonomy }) {
            aiAutonomyPopup.selectItem(at: i)
        }
        aiAutonomyPopup.target = self
        aiAutonomyPopup.action = #selector(aiChanged)
        aiCloudBaseField.stringValue = snapshot.aiCloudBase
        aiCloudBaseField.placeholderString = "https://api.openai.com/v1  (empty = on-device)"
        aiCloudBaseField.target = self; aiCloudBaseField.action = #selector(aiChanged)
        aiCloudModelField.stringValue = snapshot.aiCloudModel
        aiCloudModelField.target = self; aiCloudModelField.action = #selector(aiChanged)
        aiCloudKeyField.placeholderString = snapshot.aiHasCloudKey
            ? String(localized: "•••••••• (stored — type to replace)")
            : String(localized: "API key (stored in the Keychain)")
        aiCloudKeyField.target = self; aiCloudKeyField.action = #selector(aiKeyCommitted)

        // Assistant preferences (were a separate plugin pane; merged here).
        for p in aiModelPrefs { aiModelPrefPopup.addItem(withTitle: p.label) }
        if let i = aiModelPrefs.firstIndex(where: { $0.raw == snapshot.aiModelPreference }) {
            aiModelPrefPopup.selectItem(at: i)
        }
        aiModelPrefPopup.target = self; aiModelPrefPopup.action = #selector(aiChanged)

        aiSystemPromptView.string = snapshot.aiSystemPrompt
        aiSystemPromptView.isRichText = false
        aiSystemPromptView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        aiSystemPromptView.delegate = self
        aiSystemPromptView.textContainerInset = NSSize(width: 6, height: 6)
        let promptScroll = NSScrollView()
        promptScroll.documentView = aiSystemPromptView
        promptScroll.hasVerticalScroller = true
        promptScroll.borderType = .bezelBorder
        promptScroll.translatesAutoresizingMaskIntoConstraints = false
        promptScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
        promptScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 440).isActive = true

        let note = NSTextField(wrappingLabelWithString: String(localized: "The assistant runs on-device with Apple Intelligence when available; set a Cloud endpoint to use an OpenAI-compatible model instead (the key is kept in the Keychain, never in config). The MCP server is local-only (127.0.0.1) and off by default; connect an external agent with a stdio bridge to the chosen port, optionally protected by a token. Write actions are always confirmed unless autonomy is raised."))
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        return makePageStack(rows: [
            labeledRow(title: String(localized: "Preferred model:"), control: aiModelPrefPopup),
            labeledRow(title: String(localized: "Cloud endpoint (base URL):"), control: aiCloudBaseField),
            labeledRow(title: String(localized: "Cloud model:"), control: aiCloudModelField),
            labeledRow(title: String(localized: "Cloud API key:"), control: aiCloudKeyField),
            labeledRow(title: String(localized: "Assistant autonomy:"), control: aiAutonomyPopup),
            sectionLabel(String(localized: "Custom system prompt (optional):")),
            promptScroll,
            aiMCPCheckbox,
            labeledRow(title: String(localized: "MCP server port:"), control: aiPortField),
            labeledRow(title: String(localized: "MCP auth token:"), control: aiTokenField),
            note,
        ])
    }

    @objc private func aiChanged() {
        onSetBool("Automation.MCPServerEnabled", aiMCPCheckbox.state == .on)
        onSetString("Automation.MCPPort", String(Int(aiPortField.stringValue) ?? 8790))
        onSetString("Automation.MCPAuthToken", aiTokenField.stringValue.trimmingCharacters(in: .whitespaces))
        onSetString("AI.CloudBaseURL", aiCloudBaseField.stringValue.trimmingCharacters(in: .whitespaces))
        onSetString("AI.CloudModel", aiCloudModelField.stringValue.trimmingCharacters(in: .whitespaces))
        let i = aiAutonomyPopup.indexOfSelectedItem
        onSetString("AI.Autonomy", aiAutonomies.indices.contains(i) ? aiAutonomies[i].raw : "confirm")
        let m = aiModelPrefPopup.indexOfSelectedItem
        onSetString("AIPlugin.ModelPreference", aiModelPrefs.indices.contains(m) ? aiModelPrefs[m].raw : "auto")
    }

    /// The custom system prompt (multiline) persists to the AI plugin's JSON config.
    public func textDidChange(_ notification: Notification) {
        guard (notification.object as? NSTextView) === aiSystemPromptView else { return }
        onSetString("AIPlugin.SystemPrompt", aiSystemPromptView.string)
    }

    /// The API key commits separately so it goes to the Keychain (never config) and
    /// only when actually entered (an empty field leaves the stored key untouched).
    @objc private func aiKeyCommitted() {
        let key = aiCloudKeyField.stringValue
        guard !key.isEmpty else { return }
        onSetString("AI.CloudKey", key)   // host routes this keyPath to the Keychain
        aiCloudKeyField.stringValue = ""
        aiCloudKeyField.placeholderString = String(localized: "•••••••• (stored — type to replace)")
    }

    private func buildFtpPage() -> NSView {
        ftpKeepAliveField.stringValue = String(snapshot.ftpKeepAliveSeconds)
        ftpKeepAliveField.alignment = .right
        ftpKeepAliveField.target = self
        ftpKeepAliveField.action = #selector(ftpKeepAliveChanged)
        ftpKeepAliveField.translatesAutoresizingMaskIntoConstraints = false
        ftpKeepAliveField.widthAnchor.constraint(equalToConstant: 70).isActive = true
        let note = NSTextField(wrappingLabelWithString: String(localized:
            "Sends a keep-alive command to idle FTP connections. 0 disables it; a per-site value overrides this default."))
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        return makePageStack(rows: [
            labeledRow(title: String(localized: "Keep-alive interval (seconds):"), control: ftpKeepAliveField),
            note,
        ])
    }

    @objc private func ftpKeepAliveChanged() {
        let n = max(0, Int(ftpKeepAliveField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
        ftpKeepAliveField.stringValue = String(n)
        onSetString("FTP.KeepAliveSeconds", String(n))
    }

    // MARK: - Language page (F-272 / I19)

    private func buildLanguagePage() -> NSView {
        let index = languages.firstIndex { $0.raw == currentLanguage } ?? 0
        makePopup(languagePopup, items: languages.map(\.label),
                  selectedIndex: index, action: #selector(languageChanged))
        let note = NSTextField(wrappingLabelWithString:
            String(localized: "Changing the language takes effect after restarting PeachCommander."))
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        return makePageStack(rows: [
            labeledRow(title: String(localized: "Interface language:"), control: languagePopup),
            note,
        ])
    }

    @objc private func languageChanged() {
        let i = languagePopup.indexOfSelectedItem
        onSetLanguage(languages.indices.contains(i) ? languages[i].raw : "system")
    }

    // MARK: - Misc page (config folder access)

    private func buildMiscPage() -> NSView {
        let caption = NSTextField(labelWithString: String(localized: "Configuration folder:"))
        let pathField = NSTextField(labelWithString: configRootPath)
        pathField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        pathField.textColor = .secondaryLabelColor
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.toolTip = configRootPath
        pathField.isSelectable = true
        let openButton = NSButton(title: String(localized: "Open Config Folder"),
                                  target: self, action: #selector(openConfigFolder))
        openButton.bezelStyle = .rounded
        openButton.setContentHuggingPriority(.required, for: .horizontal)
        return makePageStack(rows: [caption, pathField, openButton])
    }

    @objc private func openConfigFolder() { onOpenConfigFolder() }

    // MARK: - Layout page

    private func buildLayoutPage() -> NSView {
        makeCheckbox(commandLineCheckbox, title: String(localized: "Show command line"),
                     isOn: snapshot.showCommandLine, action: #selector(commandLineChanged))
        makeCheckbox(functionKeysCheckbox, title: String(localized: "Show function key bar"),
                     isOn: snapshot.showFunctionKeys, action: #selector(functionKeysChanged))
        makeCheckbox(buttonBarCheckbox, title: String(localized: "Show button bar"),
                     isOn: snapshot.showButtonBar, action: #selector(buttonBarChanged))
        makeCheckbox(driveBarCheckbox, title: String(localized: "Show drive bar"),
                     isOn: snapshot.showDriveBar, action: #selector(driveBarChanged))
        makeCheckbox(statusBarCheckbox, title: String(localized: "Show status bar"),
                     isOn: snapshot.showStatusBar, action: #selector(statusBarChanged))
        makeCheckbox(tabBarCheckbox, title: String(localized: "Show tab bar"),
                     isOn: snapshot.showTabBar, action: #selector(tabBarChanged))
        makeCheckbox(pathBarCheckbox, title: String(localized: "Show path bar"),
                     isOn: snapshot.showPathBar, action: #selector(pathBarChanged))
        return makePageStack(rows: [commandLineCheckbox, functionKeysCheckbox, buttonBarCheckbox, driveBarCheckbox,
                                    statusBarCheckbox, tabBarCheckbox, pathBarCheckbox])
    }

    @objc private func commandLineChanged() {
        onSetBool("Layout.CommandLine", commandLineCheckbox.state == .on)
    }
    @objc private func buttonBarChanged() {
        onSetBool("Layout.ButtonBar", buttonBarCheckbox.state == .on)
    }
    @objc private func driveBarChanged() {
        onSetBool("Layout.DriveBar", driveBarCheckbox.state == .on)
    }
    @objc private func statusBarChanged() {
        onSetBool("Layout.StatusBar", statusBarCheckbox.state == .on)
    }
    @objc private func tabBarChanged() {
        onSetBool("Layout.TabBar", tabBarCheckbox.state == .on)
    }
    @objc private func pathBarChanged() {
        onSetBool("Layout.PathBar", pathBarCheckbox.state == .on)
    }
    // MARK: - Plugins page (F-274)

    private func buildPluginsPage() -> NSView {
        var rows: [NSView] = []
        let heading = NSTextField(labelWithString: String(localized: "Installed plugins:"))
        heading.font = .boldSystemFont(ofSize: 13)
        rows.append(heading)
        if pluginRows.isEmpty {
            let empty = NSTextField(labelWithString: String(localized: "(no plugins installed)"))
            empty.textColor = .secondaryLabelColor
            rows.append(empty)
        } else {
            for (i, p) in pluginRows.enumerated() {
                let box = NSButton(checkboxWithTitle: "\(p.name) — \(p.type.uppercased()) v\(p.apiVersion)",
                                   target: self, action: #selector(pluginToggled(_:)))
                box.state = p.enabled ? .on : .off
                box.tag = i
                rows.append(box)
            }
        }
        let manage = NSButton(title: String(localized: "Manage Plugins…"), target: self,
                              action: #selector(openPluginsManager))
        manage.bezelStyle = .rounded
        rows.append(manage)
        return makePageStack(rows: rows)
    }

    @objc private func pluginToggled(_ sender: NSButton) {
        guard pluginRows.indices.contains(sender.tag) else { return }
        onTogglePlugin?(pluginRows[sender.tag].name, sender.state == .on)
    }

    @objc private func openPluginsManager() { onOpenPluginsManager?() }

    @objc private func functionKeysChanged() {
        onSetBool("Layout.FunctionKeys", functionKeysCheckbox.state == .on)
    }

    // MARK: - Display page

    private func buildDisplayPage() -> NSView {
        makeCheckbox(showHiddenCheckbox, title: String(localized: "Show hidden files"),
                     isOn: snapshot.showHidden, action: #selector(showHiddenChanged))
        makePopup(sizeStylePopup,
                  items: [String(localized: "KB"), String(localized: "Dynamic"), String(localized: "Bytes")],
                  selectedIndex: sizeStyleIndex(for: snapshot.sizeStyle), action: #selector(sizeStyleChanged))
        makeCheckbox(bracketsCheckbox, title: String(localized: "Brackets around folder names"),
                     isOn: snapshot.bracketsAroundDirs, action: #selector(bracketsChanged))
        makeCheckbox(naturalSortCheckbox, title: String(localized: "Natural (numeric) sort order"),
                     isOn: snapshot.naturalSort, action: #selector(naturalSortChanged))
        makeCheckbox(alternatingRowsCheckbox, title: String(localized: "Alternating row background"),
                     isOn: snapshot.alternatingRows, action: #selector(alternatingRowsChanged))
        let typeColorsButton = NSButton(title: String(localized: "File-Type Colors…"),
                                        target: self, action: #selector(editTypeColors))   // F-032
        typeColorsButton.bezelStyle = .rounded
        makePopup(fontSizePopup, items: Self.fontSizes.map { "\($0) pt" },
                  selectedIndex: Self.fontSizes.firstIndex(of: snapshot.fontSize) ?? Self.fontSizes.firstIndex(of: 13) ?? 0,
                  action: #selector(fontSizeChanged))

        dateFormatField.stringValue = snapshot.dateFormat
        dateFormatField.placeholderString = String(localized: "empty = system format")
        dateFormatField.target = self
        dateFormatField.action = #selector(dateFormatChanged)
        dateFormatField.translatesAutoresizingMaskIntoConstraints = false
        dateFormatField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        datePreviewLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        datePreviewLabel.textColor = .secondaryLabelColor
        updateDatePreview()

        return makePageStack(rows: [
            showHiddenCheckbox,
            labeledRow(title: String(localized: "Size format:"), control: sizeStylePopup),
            bracketsCheckbox,
            naturalSortCheckbox,
            alternatingRowsCheckbox,
            typeColorsButton,
            labeledRow(title: String(localized: "Font size:"), control: fontSizePopup),
            labeledRow(title: String(localized: "Date format:"), control: dateFormatField),
            datePreviewLabel,
        ])
    }

    /// Show the current date rendered with the entered pattern next to the field.
    private func updateDatePreview() {
        let example = PanelDateFormatter.string(sampleDate, pattern: dateFormatField.stringValue)
        datePreviewLabel.stringValue = String(format: String(localized: "Example: %@"), example)
    }

    /// A fixed, recognizable sample instant (2024-01-31 14:05 local) for previews.
    private let sampleDate = Date(timeIntervalSince1970: 1_706_709_900)

    @objc private func dateFormatChanged() {
        updateDatePreview()
        onSetString("Display.DateFormat", dateFormatField.stringValue.trimmingCharacters(in: .whitespaces))
    }

    @objc private func showHiddenChanged() {
        onSetBool("Configuration.ShowHiddenSystem", showHiddenCheckbox.state == .on)
    }

    @objc private func sizeStyleChanged() {
        let styles = ["kb", "dynamic", "bytes"]
        let index = sizeStylePopup.indexOfSelectedItem
        onSetString("Display.SizeStyle", styles.indices.contains(index) ? styles[index] : "kb")
    }

    @objc private func bracketsChanged() {
        onSetBool("Display.BracketDirs", bracketsCheckbox.state == .on)
    }

    @objc private func naturalSortChanged() {
        onSetBool("Display.NaturalSort", naturalSortCheckbox.state == .on)
    }

    @objc private func alternatingRowsChanged() {
        onSetBool("Display.AlternatingRows", alternatingRowsCheckbox.state == .on)
    }

    /// Opens the by-file-type colour editor (F-032).
    var onEditTypeColors: (() -> Void)?
    @objc private func editTypeColors() { onEditTypeColors?() }

    /// Selectable panel-list font sizes (F-272).
    private static let fontSizes = [10, 11, 12, 13, 14, 16, 18, 20]

    @objc private func fontSizeChanged() {
        let i = fontSizePopup.indexOfSelectedItem
        let size = Self.fontSizes.indices.contains(i) ? Self.fontSizes[i] : 13
        onSetString("Display.FontSize", String(size))
    }

    // MARK: - Icons page

    private func buildIconsPage() -> NSView {
        makePopup(iconModePopup,
                  items: [String(localized: "None"), String(localized: "Standard"), String(localized: "All")],
                  selectedIndex: iconModeIndex(for: snapshot.iconMode), action: #selector(iconModeChanged))
        return makePageStack(rows: [labeledRow(title: String(localized: "Show icons:"), control: iconModePopup)])
    }

    @objc private func iconModeChanged() {
        let modes = ["none", "standard", "all"]
        let index = iconModePopup.indexOfSelectedItem
        onSetString("Configuration.IconMode", modes.indices.contains(index) ? modes[index] : "standard")
    }

    /// Unknown/unrecognized values fall back to "Standard", the sensible default.
    private func iconModeIndex(for mode: String) -> Int {
        switch mode {
        case "none": return 0
        case "all": return 2
        default: return 1
        }
    }

    /// Unknown/unrecognized values fall back to "KB", the sensible default.
    private func sizeStyleIndex(for style: String) -> Int {
        switch style {
        case "dynamic": return 1
        case "bytes": return 2
        default: return 0
        }
    }

    // MARK: - Operation page

    private func buildOperationPage() -> NSView {
        makeCheckbox(selectDirsCheckbox, title: String(localized: "Select directories with Num+ masks"),
                     isOn: snapshot.selectDirsWithMask, action: #selector(selectDirsChanged))
        makeCheckbox(verifyAfterCopyCheckbox, title: String(localized: "Verify files after copy (checksum)"),
                     isOn: snapshot.verifyAfterCopy, action: #selector(verifyAfterCopyChanged))
        let qsIndex = quickSearchModes.firstIndex { $0.raw == snapshot.quickSearchMode } ?? 0
        makePopup(quickSearchPopup, items: quickSearchModes.map(\.label),
                  selectedIndex: qsIndex, action: #selector(quickSearchModeChanged))
        let mmIndex = mouseModes.firstIndex { $0.raw == snapshot.mouseMode } ?? 0
        makePopup(mouseModePopup, items: mouseModes.map(\.label),
                  selectedIndex: mmIndex, action: #selector(mouseModeChanged))
        return makePageStack(rows: [
            selectDirsCheckbox,
            verifyAfterCopyCheckbox,
            labeledRow(title: String(localized: "Quick search:"), control: quickSearchPopup),
            labeledRow(title: String(localized: "Mouse selection:"), control: mouseModePopup),
        ])
    }

    @objc private func mouseModeChanged() {
        let i = mouseModePopup.indexOfSelectedItem
        onSetString("Operation.MouseMode", mouseModes.indices.contains(i) ? mouseModes[i].raw : "left")
    }

    @objc private func selectDirsChanged() {
        onSetBool("Operation.SelectDirs", selectDirsCheckbox.state == .on)
    }

    @objc private func verifyAfterCopyChanged() {
        onSetBool("Operation.VerifyAfterCopy", verifyAfterCopyCheckbox.state == .on)
    }

    @objc private func quickSearchModeChanged() {
        let i = quickSearchPopup.indexOfSelectedItem
        onSetString("Operation.QuickSearchMode", quickSearchModes.indices.contains(i) ? quickSearchModes[i].raw : "direct")
    }

    // MARK: - Confirmation page

    private func buildConfirmationPage() -> NSView {
        makeCheckbox(confirmDeleteCheckbox, title: String(localized: "Confirm before delete"),
                     isOn: snapshot.confirmDelete, action: #selector(confirmDeleteChanged))
        makeCheckbox(deleteToTrashCheckbox, title: String(localized: "Delete to Trash (uncheck = permanent)"),
                     isOn: snapshot.deleteToTrash, action: #selector(deleteToTrashChanged))
        return makePageStack(rows: [confirmDeleteCheckbox, deleteToTrashCheckbox])
    }

    @objc private func confirmDeleteChanged() {
        onSetBool("Operation.ConfirmDelete", confirmDeleteCheckbox.state == .on)
    }

    @objc private func deleteToTrashChanged() {
        onSetBool("Operation.DeleteToTrash", deleteToTrashCheckbox.state == .on)
    }

    // MARK: - Colors page

    private static let appearanceValues = ["system", "light", "dark"]

    private func buildColorsPage() -> NSView {
        // "System" first and selected by default: no palette, the appearance decides — the
        // look Peach Commander has always had. The named palettes are additions.
        makePopup(themePopup, items: Self.themeNames(), selectedIndex: 0, action: #selector(themeChanged))
        selectTheme(snapshot.theme)
        // Re-read the themes folder whenever the menu is opened, so a file the user just saved
        // shows up without restarting the app. menuNeedsUpdate is the only AppKit hook that
        // fires before the popup is displayed.
        themePopup.menu?.delegate = self
        makePopup(appearancePopup,
                  items: [String(localized: "System (follow macOS)"), String(localized: "Light"), String(localized: "Dark")],
                  selectedIndex: max(0, Self.appearanceValues.firstIndex(of: snapshot.appearance) ?? 0),
                  action: #selector(appearanceChanged))

        let heading = NSTextField(labelWithString: String(localized: "Custom panel colors:"))
        heading.font = Fonts.bold13
        let reset = NSButton(title: String(localized: "Reset to defaults"),
                             target: self, action: #selector(resetCustomColors))
        reset.bezelStyle = .rounded

        let themesFolder = NSButton(title: String(localized: "Themes Folder…"),
                                    target: self, action: #selector(openThemesFolder))
        themesFolder.bezelStyle = .rounded
        themesFolder.setContentHuggingPriority(.required, for: .horizontal)
        themesFolder.toolTip = String(localized:
            "Open the folder holding your own theme files. An example is created the first time.")

        // A palette carries its own base, so leaving Appearance live would be a control that
        // silently does nothing.
        appearancePopup.isEnabled = snapshot.theme == "system"

        let themeNote = NSTextField(wrappingLabelWithString: String(localized:
            "A theme brings its own colors and its own light/dark base; Appearance then has no effect. Custom colors below still win."))
        themeNote.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        themeNote.textColor = .secondaryLabelColor

        return makePageStack(rows: [
            labeledRow(title: String(localized: "Theme:"), control: themePopup),
            themesFolder,
            labeledRow(title: String(localized: "Appearance:"), control: appearancePopup),
            themeNote,
            heading,
            colorRow(check: fgCheck, well: fgWell, title: String(localized: "Text:"),
                     hex: snapshot.customForeground, action: #selector(fgChanged)),
            colorRow(check: bgCheck, well: bgWell, title: String(localized: "Background:"),
                     hex: snapshot.customBackground, action: #selector(bgChanged)),
            colorRow(check: selCheck, well: selWell, title: String(localized: "Selected text:"),
                     hex: snapshot.customSelection, action: #selector(selChanged)),
            colorRow(check: curCheck, well: curWell, title: String(localized: "Cursor frame:"),
                     hex: snapshot.customCursor, action: #selector(curChanged)),
            reset,
        ])
    }

    /// A "[✓] Title  [colour well]" row. The checkbox toggles between the custom
    /// colour and the theme default; the well is disabled when unchecked.
    private func colorRow(check: NSButton, well: NSColorWell, title: String,
                          hex: String, action: Selector) -> NSView {
        check.setButtonType(.switch)
        check.title = title
        check.font = Fonts.system13
        check.state = hex.isEmpty ? .off : .on
        check.target = self
        check.action = action
        check.widthAnchor.constraint(equalToConstant: 130).isActive = true
        well.color = NSColor(hexString: hex) ?? .textColor
        well.isEnabled = !hex.isEmpty
        well.target = self
        well.action = action
        well.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let row = NSStackView(views: [check, well])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        return row
    }

    /// Index 0 is "system"; the rest mirror `Theme.palettes` in order — built-ins, then the
    /// user's own. Computed, not stored: `Theme.palettes` grows when a theme file is loaded.
    private static var themeValues: [String] { ["system"] + Theme.palettes.map(\.id) }
    private static func themeNames() -> [String] {
        [String(localized: "System (default)")] + Theme.palettes.map(\.name)
    }

    /// Select the item for `id`, falling back to "System" for an id that no longer exists —
    /// which is what happens when the user deletes the theme file they had selected.
    private func selectTheme(_ id: String) {
        themePopup.selectItem(at: max(0, Self.themeValues.firstIndex(of: id) ?? 0))
        appearancePopup.isEnabled = themePopup.indexOfSelectedItem == 0
    }

    @objc private func themeChanged() {
        let idx = themePopup.indexOfSelectedItem
        let values = Self.themeValues
        onSetString("Colors.Theme", values.indices.contains(idx) ? values[idx] : "system")
        appearancePopup.isEnabled = themePopup.indexOfSelectedItem == 0
    }

    @objc private func openThemesFolder() { onOpenThemesFolder() }

    @objc private func appearanceChanged() {
        let idx = appearancePopup.indexOfSelectedItem
        let value = Self.appearanceValues.indices.contains(idx) ? Self.appearanceValues[idx] : "system"
        onSetString("Colors.Appearance", value)
    }

    /// Push a colour row's current state to config: "" when unchecked, else its hex.
    private func pushColor(_ key: String, check: NSButton, well: NSColorWell) {
        well.isEnabled = check.state == .on
        onSetString(key, check.state == .on ? well.color.hexString : "")
    }

    @objc private func fgChanged()  { pushColor("Colors.Foreground", check: fgCheck, well: fgWell) }
    @objc private func bgChanged()  { pushColor("Colors.Background", check: bgCheck, well: bgWell) }
    @objc private func selChanged() { pushColor("Colors.Selection", check: selCheck, well: selWell) }
    @objc private func curChanged() { pushColor("Colors.Cursor", check: curCheck, well: curWell) }

    @objc private func resetCustomColors() {
        for (check, well) in [(fgCheck, fgWell), (bgCheck, bgWell), (selCheck, selWell), (curCheck, curWell)] {
            check.state = .off; well.isEnabled = false
        }
        for key in ["Colors.Foreground", "Colors.Background", "Colors.Selection", "Colors.Cursor"] {
            onSetString(key, "")
        }
    }

    // MARK: - Small view helpers

    /// Configures a checkbox in place (title, font, initial state, target/action).
    private func makeCheckbox(_ button: NSButton, title: String, isOn: Bool, action: Selector) {
        button.title = title
        button.font = Fonts.system13
        button.state = isOn ? .on : .off
        button.target = self
        button.action = action
    }

    /// Configures a popup in place (items, initial selection, target/action).
    private func makePopup(_ popup: NSPopUpButton, items: [String], selectedIndex: Int, action: Selector) {
        popup.removeAllItems()
        popup.addItems(withTitles: items)
        popup.font = Fonts.system13
        if items.indices.contains(selectedIndex) {
            popup.selectItem(at: selectedIndex)
        }
        popup.target = self
        popup.action = action
    }

    private func labeledRow(title: String, control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = Fonts.system13
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .firstBaseline
        return row
    }

    /// A standalone left-aligned caption for a control that spans the full width
    /// (e.g. above a multiline text area), styled like a row label.
    private func sectionLabel(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = Fonts.system13
        return label
    }

    private func makePageStack(rows: [NSView]) -> NSView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return stack
    }

    @objc private func closeAction() {
        for v in pluginPaneViews.values { v.removeFromSuperview() }
        pluginPanes.forEach { $0.closeView() }
        pluginPaneViews.removeAll()
        close()
    }
}

extension SettingsWindowController: NSTextViewDelegate {}

// MARK: - NSTableViewDataSource / NSTableViewDelegate

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        builtinPageCount + pluginPanes.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let title: String
        if let page = SettingsPage(rawValue: row) {
            title = page.title
        } else if pluginPanes.indices.contains(row - builtinPageCount) {
            title = pluginPanes[row - builtinPageCount].title
        } else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("SettingsPageCell")
        let textField: NSTextField
        if let recycled = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            textField = recycled
        } else {
            textField = NSTextField(labelWithString: "")
            textField.identifier = identifier
            textField.font = Fonts.system13
        }
        textField.stringValue = title
        return textField
    }

    /// Programmatically show a built-in page by its (localized) title. Used by
    /// automation to screenshot a specific page (F-274).
    public func showPage(titled title: String) {
        guard let page = SettingsPage.allCases.first(where: { $0.title == title }) else { return }
        sourceList.selectRowIndexes(IndexSet(integer: page.rawValue), byExtendingSelection: false)
        selectPage(page)
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sourceList.selectedRow
        if let page = SettingsPage(rawValue: row) {
            selectPage(page)
        } else {
            selectPluginPane(row - builtinPageCount)
        }
    }
}


// MARK: - Live theme list (F-337)

extension SettingsWindowController: NSMenuDelegate {
    /// Re-read the themes folder and rebuild the Theme menu just before it opens.
    ///
    /// The alternative — populating once when the page is built — means a theme the user just
    /// saved does not appear until the app is restarted, which makes editing a theme a
    /// restart-per-iteration loop. Rebuilding here costs one small directory read per click.
    public func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === themePopup.menu, let directory = themesDirectory else { return }
        // Remember the id, not the index: reloading can insert or drop items above it.
        let values = Self.themeValues
        let idx = themePopup.indexOfSelectedItem
        let selectedId = values.indices.contains(idx) ? values[idx] : "system"

        // Compare the selected palette's colours across the reload, so a re-apply happens only when
        // the file genuinely changed. Re-applying unconditionally wrote the config and repainted
        // every panel, window and plugin on *every* opening of this menu.
        func colours(of id: String) -> [String: String]? {
            Theme.userPalettes.first { $0.id == id }
                .map { Theme.pluginContextValues(colors: $0.colors, isDark: $0.isDark, themeId: $0.id) }
        }
        let before = colours(of: selectedId)
        ThemeFile.loadUserPalettes(from: directory)
        let after = colours(of: selectedId)

        // Built-in palettes cannot change, so this only ever fires for the user's own themes —
        // exactly the "I edited my theme, show me" case. Items added with a nil action still trigger
        // the popup's own action on selection.
        if before != after { onSetString("Colors.Theme", selectedId) }

        let names = Self.themeNames()
        guard names != menu.items.map(\.title) else { return }   // nothing changed, leave it alone
        menu.removeAllItems()
        for name in names { menu.addItem(withTitle: name, action: nil, keyEquivalent: "") }
        selectTheme(selectedId)
    }
}
