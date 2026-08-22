// SPDX-License-Identifier: Apache-2.0
// PCCommands - Command Registry for Peach Commander
// This module provides the command registry with TC-compatible command names.

import Foundation
import PCFoundation
import PCVFS

// SelectionState is defined in a separate file within the same module

/// Sort descriptor for panel sorting
public enum PanelSortColumn: String {
    case name
    case ext
    case size
    case date

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "name": self = .name
        case "ext": self = .ext
        case "size": self = .size
        case "date": self = .date
        default: return nil
        }
    }
}

/// Protocol for panel controller (defined in PCApp).
///
/// `@MainActor`-isolated for the same reason as `WindowControllerProtocol`: the methods are
/// `async` and their witnesses can hop, but `currentArchiveZipPath`, `currentFileSystem` and
/// `isOnNetworkFilesystem` are *synchronous* requirements, and a synchronous nonisolated
/// witness has nowhere to hop — it reads main-actor panel state from whatever thread asks
/// (F-436).
@MainActor
public protocol PanelControllerProtocol: AnyObject {
    func getCurrentPath() async -> String
    func loadDirectory(_ path: String) async
    func sort(by column: PanelSortColumn, ascending: Bool) async

    // MARK: - Volume Support (T04)

    /// Get the current volume for this panel
    func getCurrentVolume() async -> Volume?

    /// Get all available volumes
    func getVolumes() async -> [Volume]

    /// Load a directory from a specific volume path
    func loadDirectoryFromVolume(_ volumePath: String) async

    // MARK: - Selection (I03)

    /// Toggle the mark on the entry under the cursor.
    func toggleMarkAtCursor() async
    /// Select all entries.
    func markAll() async
    /// Clear the selection.
    func unmarkAll() async
    /// Invert the selection.
    func invertSelection() async
    /// Restore the previous selection (Num/).
    func restoreSelection() async
    /// Select files sharing the cursor entry's extension.
    func selectSameExtension() async
    /// Present the select-by-mask dialog (Num+).
    func showSelectByMask() async
    /// Present the unselect-by-mask dialog (Num-).
    func showUnselectByMask() async

    // MARK: - View (I03)

    /// Toggle hidden-file visibility.
    func toggleHiddenFiles() async
    /// Present the properties dialog for the cursor entry (Alt+Enter).
    func showProperties() async
    /// Calculate sizes of all directories in view (Alt+Shift+Enter).
    func calculateAllDirectorySizes() async

    // MARK: - File operations (I04)

    /// Current directory path of this panel.
    func currentDirectory() async -> String
    /// Reload this panel's directory listing.
    func reload() async
    /// Copy the selection (or cursor item) into `targetDir` (F5).
    func copySelection(to targetDir: String) async
    /// Copy the selection within this panel's own directory, under a name the user gives (Shift+F5).
    ///
    /// No target directory argument, and that is the point: the other panel is not consulted, so the
    /// command works with one panel maximised and cannot be aimed anywhere by accident.
    func copySelectionSamePanel() async
    /// The backing .zip path when this panel is inside a rewritable archive, else
    /// nil — lets the copy command route "copy INTO an archive" (F-133/F-139).
    var currentArchiveZipPath: String? { get }
    /// The filesystem this panel is browsing — the upload target for the other panel (F-367).
    var currentFileSystem: VirtualFileSystem { get }
    /// Whether this panel needs an upload rather than a local copy (F-367).
    var isOnNetworkFilesystem: Bool { get }
    /// Send the selection to a directory on another panel's filesystem (F-367).
    func uploadSelection(to targetDir: String, on targetFS: VirtualFileSystem) async
    /// Copy the selection into the archive at `archiveZip`, under `subPath`
    /// (extracting first if the source is itself inside an archive — F-139).
    func copyInto(archiveZip: String, subPath: String) async
    /// Move the selection into the archive at `archiveZip`, under `subPath`: the same add,
    /// then the sources are removed once the rewrite succeeded.
    func moveInto(archiveZip: String, subPath: String) async
    /// Re-open the archive this panel is inside (after it was rewritten on disk).
    func reloadCurrentArchive() async
    /// Move the selection (or cursor item) into `targetDir` (F6).
    func moveSelection(to targetDir: String) async
    /// Create a directory in this panel (F7).
    func makeDirectory() async
    /// Delete the selection (or cursor item); permanent bypasses Trash (F8 / Shift+F8).
    func deleteSelection(permanent: Bool) async
    /// Pack the selection into a new .zip in `targetDir` (Alt+F5).
    func packSelection(to targetDir: String) async

    // MARK: - Clipboard & edit (I04 T07/T08)

    /// Write selected file URLs to the pasteboard (Cmd+C).
    func copyToClipboard() async
    /// Write selected file URLs to the pasteboard and mark them cut (Cmd+X).
    func cutToClipboard() async
    /// Paste pasteboard file URLs into this panel (copy, or move if cut) (Cmd+V).
    func pasteFromClipboard() async
    /// Open the cursor file in an editor (F4).
    func editCursorFile() async
    /// Create a new empty file and open it (Shift+F4).
    func editNewFile() async

    // MARK: - Copy names to clipboard (I13 §6, F-092)

    /// Copy the selected (or cursor) leaf names, newline-joined (cm_CopyNamesToClip).
    func copyNamesToClip() async
    /// Copy the selected (or cursor) full paths, newline-joined (cm_CopyFullNamesToClip).
    func copyFullNamesToClip() async
    /// Copy the selected (or cursor) items as VFS URLs (cm_CopyNetNamesToClip).
    func copyNetNamesToClip() async
    /// Copy this panel's current directory path (cm_CopySrcPathToClip).
    func copySrcPathToClip() async
    /// Copy the selected (or cursor) items' visible column details as TSV (cm_CopyFileDetailsToClip).
    func copyFileDetailsToClip() async

    // MARK: - Navigation history (I06 T02)

    /// Go back in this panel's navigation history (Alt+Left).
    func goBack() async
    /// Go forward in this panel's navigation history (Alt+Right).
    func goForward() async
    /// Go up to the parent directory / leave the current archive (Ctrl+PageUp).
    func goToParent() async
    /// Enter the item under the cursor: a directory, or any file opened as an
    /// archive by content — e.g. a .jar/.war (Ctrl+PageDown).
    func openDirUnderCursor() async

    // MARK: - Tabs (I06 T01)

    func openNewTab() async
    func openNewTabInBackground() async
    func openDirUnderCursorInNewTab() async
    func closeCurrentTab() async
    func closeAllTabs() async
    func nextTab() async
    func prevTab() async
    func toggleLockTab() async
}

/// Protocol for window controller (defined in PCApp).
///
/// `@MainActor`-isolated: nearly every requirement here drives AppKit directly
/// (opens windows, reloads panel table views, mutates the split view). The
/// requirements are synchronous, and a synchronous nonisolated witness has no
/// place to hop — so without this annotation a handler running off the main
/// thread reaches straight into AppKit (F-435).
@MainActor
public protocol WindowControllerProtocol: AnyObject {
    func toggleActivePanel()
    /// Toggle hidden-file visibility globally (both panels) and persist it.
    func toggleHiddenFiles()
    /// Present the Settings/Options window (Cmd+,).
    func showSettings()
    /// Swap the two panels' directories (Ctrl+U).
    func swapPanels()
    /// Swap the two panels including all their tabs (Ctrl+Shift+U, F-064).
    func swapPanelsIncludingTabs()
    /// Point the OTHER panel at the active panel's current directory (F-064,
    /// TC's "target = source").
    func targetEqualsSource() async
    /// Show the directory hotlist popup (Ctrl+D).
    func showHotlist()
    /// Open the Lister (file viewer) for the active panel's cursor file (F3).
    func showLister()
    /// Toggle Quick View (Ctrl+Q): a viewer that follows the active panel's cursor.
    func toggleQuickView()
    /// Open the Find Files dialog (Alt+F7).
    func showFindFiles()
    /// Open the Multi-Rename tool (Ctrl+M).
    func showMultiRename()
    /// Export the selected names to a text editor; re-import + rename on save (F-174).
    func showRenameByEditor()
    /// Compare by content: open the side-by-side diff window for the selected files.
    func showCompareByContent()
    /// Compare by content as a side-by-side hex dump (binary/large files).
    func showCompareBinary()
    /// Prompt for a path and navigate the active panel there (cm_GotoPath).
    func showGotoPath()
    /// Open a terminal at the active panel's current directory (cm_OpenTerminal).
    func openTerminalHere()
    /// Open the cursor file in the built-in text/code editor (cm_Edit / F4).
    func showEditorForCursor()
    /// Prompt for a name, create it in the active panel, and open the editor (Shift+F4).
    func showEditorForNewFile()
    /// Rename the cursor item in place, old name pre-selected (cm_RenameOnly, Shift+F6).
    func showRenameFile()
    /// Open the cursor file in the hex editor (cm_EditHex).
    func showHexEditor()
    /// Prompt for an SMB/AFP/UNC address, mount it and navigate there (cm_MountShare).
    func showMountShare()
    /// Mark files that differ/are-newer between the two panels (cm_CompareDirs).
    /// When `withSubdirs` is true, recurse into subdirectories.
    func compareDirectories(withSubdirs: Bool)
    /// Open the Synchronize Directories dialog for the two panel paths.
    func showSynchronizeDirs()
    /// Open the Start-menu (user commands) editor.
    func showChangeStartMenu()
    /// Run a user command (em_) by name against the current panels.
    func runUserCommand(_ name: String)
    /// Open the button bar (.bar) for editing.
    func showCustomizeToolbar()
    /// Switch the active keyboard scheme ("tc-classic" or "macos") and persist it.
    func setKeyScheme(_ name: String)
    /// Report that a registered-but-not-yet-implemented command was invoked.
    func showNotImplemented(_ name: String)
    /// Open the searchable command browser.
    func showCommandBrowser()
    /// Open the keyboard-shortcuts editor (Keys options page).
    func showKeysEditor()
    /// Open the Plugins options page.
    func showPluginsManager()
    /// Configure the panel's visible columns (cm_ConfigColumns).
    func showColumnsConfig()
    /// Quick-connect to a network location (FTP URL) and mount it (Ctrl+N, F-211).
    func showQuickConnect()
    /// Create a checksum file (.sfv/.md5/.sha256…) for the selected files (F-090).
    func showCreateChecksums()
    /// Verify the checksum file under the cursor against files in its directory.
    func showVerifyChecksums()
    /// Find byte-identical duplicate files under the current directory (SPEC-008 §4).
    func showFindDuplicates()
    /// Base64-encode the cursor file (SPEC-016 §5).
    func showEncodeFile()
    /// Base64-decode the cursor file (SPEC-016 §5).
    func showDecodeFile()
    /// Split the cursor file into parts + a .crc sidecar (SPEC-016 §3).
    func showSplitFile()
    /// Combine split parts (from the cursor .crc/.001) back into the original.
    func showCombineFiles()
    /// Show the occupied space of the selection (Ctrl+L, SPEC-016 §1).
    func showOccupiedSpace()
    /// Change file attributes (POSIX permissions) of the selection (SPEC-016 §2).
    func showChangeAttributes()
    /// Edit the cursor file's comment (descript.ion, Ctrl+Z, SPEC-016 §7).
    func showEditComment()
    /// Export the current directory listing to a text file (SPEC-016 §9).
    func showExportFileList()
    /// Print the current directory listing (SPEC-016 §9).
    func showPrintFileList()
    /// Branch view: flatten the current directory tree into one flat listing (Ctrl+B).
    func showBranchView()
    /// Branch view of the selected items only (Ctrl+Shift+B).
    func showBranchViewSelected()
    /// Create a symbolic link to the cursor item (F-093).
    func showCreateSymlink()
    /// Create a hard link to the cursor item (F-093).
    func showCreateHardlink()
    /// Create a macOS alias to the cursor item (F-093).
    func showCreateAlias()
    /// Show the cursor image's dimensions/metadata (SPEC-012 §5).
    func showImageInfo()
    /// Cycle the active panel's view mode (details → brief → icons → gallery, TODOS #58).
    func cycleActivePanelViewMode()
    /// Set the active panel's view mode directly (View-menu items, TODOS #58).
    func setActivePanelViewMode(_ mode: PanelViewMode)
    /// Toggle the active panel's folder-tree column (cm_SrcTree / Ctrl+F8, F-015).
    func toggleActivePanelTree()
    /// Toggle the one-tree-for-both-panels column (cm_TreeShared, F-015).
    func toggleSharedTree()
    /// Open or close the plugin dock across the bottom of the window (cm_BottomArea, F-381).
    func toggleBottomDock()
    /// Put the window's furniture back the way it ships (cm_ResetLayout, F-381).
    func resetLayout()
    /// Take the embedded terminal to the active panel's folder (cm_TerminalCdHere, F-381).
    func terminalCdHere()
    /// Put the selected file names at the terminal's prompt (cm_TerminalSendNames, F-381).
    func terminalSendNames()
    /// Run the command line in the embedded terminal instead of detached (cm_TerminalRunCommandLine, F-381).
    func toggleRunCommandLineInTerminal()
    /// Move the keyboard between the file panel and the terminal (cm_TerminalFocus, F-381).
    func focusTerminal()
    /// Open another terminal tab (cm_TerminalNewTab, F-381).
    func terminalNewTab()
    /// Show or hide the terminal wherever it is mounted (cm_TerminalToggle, F-388).
    func toggleTerminal()
    /// Split the terminal in two, or put it back together (cm_TerminalSplit, F-381).
    func terminalSplit()
    /// Close the terminal tab that is showing (cm_TerminalCloseTab, F-381).
    func terminalCloseTab()
    /// Show the background transfer manager window (TODOS #135).
    func showTransferManager()
    func showOpenSourceNotices()
    func toggleQuickFilter()
    func showHistoryMenu()
    /// Open the global history palette (cm_History, F-402).
    func showHistoryPalette()
    /// Open the FTP connection manager (saved sites) — cm_FtpConnect.
    func showFtpConnect()
    /// Open the FTP console (protocol log + custom raw command) — cm_FtpRawCommand.
    func showFtpConsole()
    /// Download a file from an HTTP/HTTPS URL into the current folder — cm_DownloadFromURL.
    func showDownloadFromURL()
    /// Disconnect the active panel's network mount (FTP/SFTP) — cm_FtpDisconnect.
    func disconnectActivePanelNetwork()
    /// Import a subset of a Total Commander wincmd.ini (hotlist, button bar, FTP) — cm_ImportWincmd (F-276).
    func showImportWincmd()
    /// Create/edit the user main-menu file (TC .mnu format) — cm_ConfigMainMenu (F-257).
    func showEditMainMenu()
    /// Native Quick Look preview of the selection (Cmd+Y) — cm_QuickLook.
    func showQuickLook()
    /// Explain Full Disk Access and offer to open System Settings — cm_FullDiskAccess.
    /// Eject the removable volume the cursor or the current folder is on (F-006).
    func ejectVolumeUnderCursor()
    func showFullDiskAccessInfo()
    /// Verify the integrity of the archive under the cursor (or the one we are
    /// inside) — cm_TestArchive.
    func showTestArchive()
    /// Unpack the archive under the cursor (or the one we are inside) to a
    /// destination folder — cm_UnpackFiles.
    func showUnpackFiles()
    /// Workspaces hub: load/delete/save named panel layouts — cm_Workspaces.
    func showWorkspaces()
    /// Save the current two-panel layout as a named workspace — cm_SaveWorkspace.
    func showSaveWorkspace()
    /// Toggle the right-hand preview/info sidebar (Info/Activities/Log) — cm_PreviewPanel.
    func togglePreviewPanel()
    /// Toggle horizontal panel arrangement (panels stacked above/below vs side by
    /// side) — cm_HorizontalPanels (F-002).
    func toggleHorizontalPanels()
    /// Toggle the button bar between the top strip and a left column — cm_VerticalButtonBar (F-011).
    /// Show or hide the button bar — cm_ButtonBar (F-342).
    func toggleButtonBar()
    func toggleVerticalButtonBar()
    /// Open the folder under the active panel's cursor in the LEFT panel (else
    /// the active panel's current folder) — Ctrl+Left (cm_TransferLeft).
    func transferToLeftPanel() async
    /// Same, targeting the RIGHT panel — Ctrl+Right (cm_TransferRight).
    func transferToRightPanel() async
}

/// Command handler closure type.
///
/// Handlers must run on the main actor: command dispatch happens on the
/// `CommandRegistry` actor (a background executor), but handlers routinely touch
/// AppKit (open windows, alerts, panels), which must run on the main thread.
///
/// The `@MainActor` on this *type* only carries over to closure literals written
/// at a `handler:` argument — those are inferred main-actor-isolated and hop on
/// entry. A reference to a separately declared `func` keeps that function's own
/// isolation, so a nonisolated `cm_*_handler` runs wherever the registry's
/// continuation happens to be. Every named handler therefore carries its own
/// `@MainActor` (F-435).
public typealias CommandHandler = @MainActor (CommandContext) async throws -> Void

/// Context passed to command handlers
public struct CommandContext {
    /// Active panel controller (left or right)
    public let activePanel: PanelControllerProtocol?

    /// Inactive panel controller
    public let inactivePanel: PanelControllerProtocol?

    /// Window controller reference
    public let windowController: WindowControllerProtocol?

    /// Current selection state (to be implemented in I03)
    public let selection: SelectionState?

    public init(
        activePanel: PanelControllerProtocol?,
        inactivePanel: PanelControllerProtocol?,
        windowController: WindowControllerProtocol?,
        selection: SelectionState? = nil
    ) {
        self.activePanel = activePanel
        self.inactivePanel = inactivePanel
        self.windowController = windowController
        self.selection = selection
    }
}

/// A registered command
public struct PCCommand {
    /// Stable numeric id (TC-compatible where known, >= 20000 for custom)
    public let id: Int

    /// Command name (e.g., "cm_Copy", "cm_OpenDirUnderCursor")
    public let name: String

    /// Category for grouping in command browser
    public let category: String

    /// One-liner help text
    public let help: String

    /// Handler to execute
    public let handler: CommandHandler

    /// False for registered-but-not-yet-implemented placeholder commands (I13 T01):
    /// they appear in the command browser / menus (auto-disabled) and, when invoked
    /// directly, report "not yet implemented".
    public let implemented: Bool

    public init(
        id: Int,
        name: String,
        category: String,
        help: String,
        implemented: Bool = true,
        handler: @escaping CommandHandler
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.help = help
        self.implemented = implemented
        self.handler = handler
    }
}

/// Command registry - central dispatcher for all commands
public actor CommandRegistry {
    private let logger = PCFoundationLogger.logger

    private var commands: [Int: PCCommand] = [:]
    private var commandNames: [String: PCCommand] = [:]

    /// Initialize with default commands
    public init() {
        // Commands are registered at first use to avoid actor isolation issues
    }

    /// Register a command (asserts no duplicate id/name)
    public func register(_ command: PCCommand) {
        // Check for duplicate ID
        if commands[command.id] != nil {
            logger.error("Duplicate command ID \(command.id) for \(command.name)")
            assertionFailure("Duplicate command ID: \(command.id)")
        }

        // Check for duplicate name
        if commandNames[command.name] != nil {
            logger.error("Duplicate command name \(command.name)")
            assertionFailure("Duplicate command name: \(command.name)")
        }

        commands[command.id] = command
        commandNames[command.name] = command

        logger.debug("Registered command: \(command.name) (id: \(command.id))")
    }

    /// Execute a command by name
    public func execute(_ name: String, context: CommandContext) async throws {
        guard let command = commandNames[name] else {
            logger.error("Unknown command: \(name)")
            throw CommandError.unknownCommand(name)
        }

        logger.debug("Executing command: \(name)")
        try await command.handler(context)
    }

    /// Execute a command by ID
    public func execute(id: Int, context: CommandContext) async throws {
        guard let command = commands[id] else {
            logger.error("Unknown command ID: \(id)")
            throw CommandError.unknownCommand("id:\(id)")
        }

        logger.debug("Executing command ID: \(id)")
        try await command.handler(context)
    }

    /// Get a command by name
    public func getCommand(_ name: String) -> PCCommand? {
        commandNames[name]
    }

    /// Get all registered commands
    public func getAllCommands() -> [PCCommand] {
        Array(commands.values)
    }

    // MARK: - Default Commands


    // MARK: - TC Command Definitions

    /// cm_GoToParent - Go to parent directory
    static let cm_GoToParent = PCCommand(
        id: 1,
        name: "cm_GoToParent",
        category: "Navigation",
        help: "Navigate to parent directory",
        handler: cm_GoToParent_handler
    )

    /// cm_OpenDirUnderCursor - Open directory under cursor
    static let cm_OpenDirUnderCursor = PCCommand(
        id: 2,
        name: "cm_OpenDirUnderCursor",
        category: "Navigation",
        help: "Open directory under cursor or navigate to it",
        handler: cm_OpenDirUnderCursor_handler
    )

    static let cm_TransferLeft = PCCommand(id: 30095, name: "cm_TransferLeft", category: "Navigation",
        help: "Open the folder under the cursor in the left panel (Ctrl+Left)",
        handler: { ctx in await ctx.windowController?.transferToLeftPanel() })
    static let cm_TransferRight = PCCommand(id: 30096, name: "cm_TransferRight", category: "Navigation",
        help: "Open the folder under the cursor in the right panel (Ctrl+Right)",
        handler: { ctx in await ctx.windowController?.transferToRightPanel() })

    /// cm_SwitchPanel - Switch active panel (Tab)
    static let cm_SwitchPanel = PCCommand(
        id: 3,
        name: "cm_SwitchPanel",
        category: "Panel",
        help: "Switch active panel (Tab)",
        handler: cm_SwitchPanel_handler
    )

    /// cm_SortByName - Sort by name
    static let cm_SortByName = PCCommand(
        id: 4,
        name: "cm_SortByName",
        category: "Sort",
        help: "Sort by name (ascending)",
        handler: cm_SortByName_handler
    )

    /// cm_SortByNameDesc - Sort by name (descending)
    static let cm_SortByNameDesc = PCCommand(
        id: 5,
        name: "cm_SortByNameDesc",
        category: "Sort",
        help: "Sort by name (descending)",
        handler: cm_SortByNameDesc_handler
    )

    /// cm_SortByExt - Sort by extension
    static let cm_SortByExt = PCCommand(
        id: 6,
        name: "cm_SortByExt",
        category: "Sort",
        help: "Sort by extension (ascending)",
        handler: cm_SortByExt_handler
    )

    /// cm_SortByExtDesc - Sort by extension (descending)
    static let cm_SortByExtDesc = PCCommand(
        id: 7,
        name: "cm_SortByExtDesc",
        category: "Sort",
        help: "Sort by extension (descending)",
        handler: cm_SortByExtDesc_handler
    )

    /// cm_SortBySize - Sort by size
    static let cm_SortBySize = PCCommand(
        id: 8,
        name: "cm_SortBySize",
        category: "Sort",
        help: "Sort by size (ascending)",
        handler: cm_SortBySize_handler
    )

    /// cm_SortBySizeDesc - Sort by size (descending)
    static let cm_SortBySizeDesc = PCCommand(
        id: 9,
        name: "cm_SortBySizeDesc",
        category: "Sort",
        help: "Sort by size (descending)",
        handler: cm_SortBySizeDesc_handler
    )

    /// cm_SortByDate - Sort by date
    static let cm_SortByDate = PCCommand(
        id: 10,
        name: "cm_SortByDate",
        category: "Sort",
        help: "Sort by date (ascending)",
        handler: cm_SortByDate_handler
    )

    /// cm_SortByDateDesc - Sort by date (descending)
    static let cm_SortByDateDesc = PCCommand(
        id: 11,
        name: "cm_SortByDateDesc",
        category: "Sort",
        help: "Sort by date (descending)",
        handler: cm_SortByDateDesc_handler
    )

    // MARK: - Command Handlers

    @MainActor
    private static func cm_GoToParent_handler(_ context: CommandContext) async throws {
        // Go up / leave the archive, placing the cursor on the folder we came from.
        await context.activePanel?.goToParent()
    }

    @MainActor
    private static func cm_OpenDirUnderCursor_handler(_ context: CommandContext) async throws {
        // Enter the directory, or open any file as an archive by content (.jar etc.).
        await context.activePanel?.openDirUnderCursor()
    }

    @MainActor
    private static func cm_SwitchPanel_handler(_ context: CommandContext) async throws {
        guard let windowController = context.windowController else { return }
        windowController.toggleActivePanel()
    }

    @MainActor
    private static func cm_SortByName_handler(_ context: CommandContext) async throws {
        try await sortPanel(.name, ascending: true, context: context)
    }

    @MainActor
    private static func cm_SortByNameDesc_handler(_ context: CommandContext) async throws {
        try await sortPanel(.name, ascending: false, context: context)
    }

    @MainActor
    private static func cm_SortByExt_handler(_ context: CommandContext) async throws {
        try await sortPanel(.ext, ascending: true, context: context)
    }

    @MainActor
    private static func cm_SortByExtDesc_handler(_ context: CommandContext) async throws {
        try await sortPanel(.ext, ascending: false, context: context)
    }

    @MainActor
    private static func cm_SortBySize_handler(_ context: CommandContext) async throws {
        try await sortPanel(.size, ascending: true, context: context)
    }

    @MainActor
    private static func cm_SortBySizeDesc_handler(_ context: CommandContext) async throws {
        try await sortPanel(.size, ascending: false, context: context)
    }

    @MainActor
    private static func cm_SortByDate_handler(_ context: CommandContext) async throws {
        try await sortPanel(.date, ascending: true, context: context)
    }

    @MainActor
    private static func cm_SortByDateDesc_handler(_ context: CommandContext) async throws {
        try await sortPanel(.date, ascending: false, context: context)
    }

    private static func sortPanel(_ column: PanelSortColumn, ascending: Bool, context: CommandContext) async throws {
        guard let panel = context.activePanel else { return }
        await panel.sort(by: column, ascending: ascending)
    }

    // MARK: - Default Commands Registration

    /// Register all default commands (must be called from an actor context)
    public func registerDefaultCommands() {
        // Navigation commands (I01)
        register(Self.cm_GoToParent)
        register(Self.cm_OpenDirUnderCursor)
        register(Self.cm_TransferLeft)
        register(Self.cm_TransferRight)

        // Panel switching (I01)
        register(Self.cm_SwitchPanel)

        // Sort commands (I02)
        register(Self.cm_SortByName)
        register(Self.cm_SortByNameDesc)
        register(Self.cm_SortByExt)
        register(Self.cm_SortByExtDesc)
        register(Self.cm_SortBySize)
        register(Self.cm_SortBySizeDesc)
        register(Self.cm_SortByDate)
        register(Self.cm_SortByDateDesc)

        // Volume commands (T04)
        register(Self.cm_DriveCombo)
        register(Self.cm_FreeSpaceLabel)

        // Selection commands (T01/T02/T03)
        register(Self.cm_ToggleMark)
        register(Self.cm_MarkAll)
        register(Self.cm_UnmarkAll)
        register(Self.cm_InvertMarks)
        register(Self.cm_RestoreSelection)
        register(Self.cm_SelectSameExt)
        register(Self.cm_SelectByMask)
        register(Self.cm_UnselectByMask)

        // View commands (I03-T06/T07)
        register(Self.cm_SwitchHidSys)
        register(Self.cm_Properties)
        register(Self.cm_CalcAllDirSizes)

        // File operation commands (I04)
        register(Self.cm_Copy)
        register(Self.cm_RenMov)
        register(Self.cm_MkDir)
        register(Self.cm_Delete)
        register(Self.cm_DeleteReal)
        register(Self.cm_PackFiles)
        register(Self.cm_CopyToClipboard)
        register(Self.cm_CutToClipboard)
        register(Self.cm_PasteFromClipboard)
        register(Self.cm_Edit)
        register(Self.cm_EditNewFile)
        register(Self.cm_Options)
        register(Self.cm_HistoryBack)
        register(Self.cm_HistoryForward)
        register(Self.cm_Exchange)
        register(Self.cm_TargetEqualSource)
        register(Self.cm_ExchangeWithTabs)
        register(Self.cm_GoToHome)
        register(Self.cm_GoToRoot)
        register(Self.cm_QuickFilter)
        register(Self.cm_HistoryList)
        register(Self.cm_History)
        register(Self.cm_GoToDesktop)
        register(Self.cm_GoToDownloads)
        register(Self.cm_GoToTrash)
        register(Self.cm_GoToICloud)
        register(Self.cm_OpenNewTab)
        register(Self.cm_OpenNewTabBg)
        register(Self.cm_OpenDirUnderCursorInNewTab)
        register(Self.cm_CloseCurrentTab)
        register(Self.cm_CloseAllTabs)
        register(Self.cm_NextTab)
        register(Self.cm_PrevTab)
        register(Self.cm_LockTab)
        register(Self.cm_DirectoryHotlist)
        register(Self.cm_List)
        register(Self.cm_SrcQuickview)
        register(Self.cm_SearchFor)
        register(Self.cm_MultiRenameFiles)
        register(Self.cm_RenameByEditor)
        register(Self.cm_CompareFilesByContent)
        register(Self.cm_CompareFilesBinary)
        register(Self.cm_GotoPath)
        register(Self.cm_OpenTerminal)
        register(Self.cm_CopySamepanel)
        register(Self.cm_RenameOnly)
        register(Self.cm_EditHex)
        register(Self.cm_MountShare)
        register(Self.cm_CompareDirs)
        register(Self.cm_CompareDirsWithSubdirs)
        register(Self.cm_SyncDirs)
        register(Self.cm_ChangeStartMenu)
        register(Self.cm_ConfigButtonBar)
        register(Self.cm_CommandBrowser)
        register(Self.cm_ConfigKeys)
        register(Self.cm_ConfigPlugins)
        register(Self.cm_ConfigColumns)
        register(Self.cm_FtpNew)
        register(Self.cm_NetConnect)
        register(Self.cm_CreateChecksums)
        register(Self.cm_VerifyChecksums)
        register(Self.cm_FindDuplicates)
        register(Self.cm_EncodeFile)
        register(Self.cm_DecodeFile)
        register(Self.cm_SplitFile)
        register(Self.cm_CombineFiles)
        register(Self.cm_CalcSpace)
        register(Self.cm_SetAttrib)
        register(Self.cm_EditComment)
        register(Self.cm_ExportFileList)
        register(Self.cm_PrintFileList)
        register(Self.cm_DirBranch)
        register(Self.cm_DirBranchSel)
        register(Self.cm_CreateSymlink)
        register(Self.cm_CreateHardlink)
        register(Self.cm_CreateAlias)
        register(Self.cm_ImageInfo)
        register(Self.cm_CycleViewMode)
        register(Self.cm_TransferManager)
        register(Self.cm_FtpConnect)
        register(Self.cm_FtpDisconnect)
        register(Self.cm_FtpRawCommand)
        register(Self.cm_DownloadFromURL)
        register(Self.cm_OpenSourceNotices)
        register(Self.cm_ImportWincmd)
        register(Self.cm_ConfigMainMenu)
        register(Self.cm_QuickLook)
        register(Self.cm_EjectVolume)
        register(Self.cm_FullDiskAccess)
        register(Self.cm_TestArchive)
        register(Self.cm_UnpackFiles)
        register(Self.cm_Workspaces)
        register(Self.cm_SaveWorkspace)
        register(Self.cm_PreviewPanel)
        register(Self.cm_HorizontalPanels)
        register(Self.cm_ButtonBar)
        register(Self.cm_VerticalButtonBar)
        register(Self.cm_SrcLong)
        register(Self.cm_SrcShort)
        register(Self.cm_SrcIcons)
        register(Self.cm_SrcThumbs)
        register(Self.cm_SrcTree)
        register(Self.cm_TreeShared)
        register(Self.cm_BottomArea)
        register(Self.cm_ResetLayout)
        register(Self.cm_TerminalCdHere)
        register(Self.cm_TerminalSendNames)
        register(Self.cm_TerminalRunCommandLine)
        register(Self.cm_TerminalFocus)
        register(Self.cm_TerminalNewTab)
        register(Self.cm_TerminalToggle)
        register(Self.cm_TerminalSplit)
        register(Self.cm_TerminalCloseTab)
        register(Self.cm_ConfigKeyClassic)
        register(Self.cm_ConfigKeyMacOS)
        register(Self.cm_CopyNamesToClip)
        register(Self.cm_CopyFullNamesToClip)
        register(Self.cm_CopyNetNamesToClip)
        register(Self.cm_CopySrcPathToClip)
        register(Self.cm_CopyFileDetailsToClip)
        // TC-named aliases mapping to already-implemented behaviour.
        register(Self.cm_SelectAll)
        register(Self.cm_RereadSource)
        register(Self.cm_SwitchToTargetPanel)
        // Not-yet-implemented placeholders (I13 T01): registered so menus/keymap/
        // the command browser can reference them; auto-disabled in the UI.
        registerStubCommands()
    }

    static let cm_SelectAll = PCCommand(id: 2001, name: "cm_SelectAll", category: "Mark",
        help: "Select all files", handler: { ctx in await ctx.activePanel?.markAll() })
    static let cm_RereadSource = PCCommand(id: 540, name: "cm_RereadSource", category: "View",
        help: "Refresh the active panel (F2)", handler: { ctx in await ctx.activePanel?.reload() })
    static let cm_SwitchToTargetPanel = PCCommand(id: 2002, name: "cm_SwitchToTargetPanel", category: "Navigation",
        help: "Switch to the other panel", handler: { ctx in ctx.windowController?.toggleActivePanel() })

    static let cm_CopyNamesToClip = PCCommand(id: 2017, name: "cm_CopyNamesToClip", category: "Mark",
        help: "Copy names to clipboard", handler: { ctx in await ctx.activePanel?.copyNamesToClip() })
    static let cm_CopyFullNamesToClip = PCCommand(id: 2018, name: "cm_CopyFullNamesToClip", category: "Mark",
        help: "Copy names with full path to clipboard", handler: { ctx in await ctx.activePanel?.copyFullNamesToClip() })
    static let cm_CopyNetNamesToClip = PCCommand(id: 2036, name: "cm_CopyNetNamesToClip", category: "Mark",
        help: "Copy names as URLs to clipboard", handler: { ctx in await ctx.activePanel?.copyNetNamesToClip() })
    static let cm_CopySrcPathToClip = PCCommand(id: 2029, name: "cm_CopySrcPathToClip", category: "Mark",
        help: "Copy source path to clipboard", handler: { ctx in await ctx.activePanel?.copySrcPathToClip() })
    static let cm_CopyFileDetailsToClip = PCCommand(id: 2019, name: "cm_CopyFileDetailsToClip", category: "Mark",
        help: "Copy file details to clipboard", handler: { ctx in await ctx.activePanel?.copyFileDetailsToClip() })

    static let cm_SearchFor = PCCommand(id: 30043, name: "cm_SearchFor", category: "Search",
        help: "Find files (Alt+F7)", handler: { ctx in ctx.windowController?.showFindFiles() })
    static let cm_MultiRenameFiles = PCCommand(id: 30044, name: "cm_MultiRenameFiles", category: "Files",
        help: "Multi-rename tool (Ctrl+M)", handler: { ctx in ctx.windowController?.showMultiRename() })
    static let cm_RenameByEditor = PCCommand(id: 30120, name: "cm_RenameByEditor", category: "Files",
        help: "Edit the selected file names in a text editor, then rename on save",
        handler: { ctx in ctx.windowController?.showRenameByEditor() })
    static let cm_CompareFilesByContent = PCCommand(id: 30045, name: "cm_CompareFilesByContent", category: "Files",
        help: "Compare files by content", handler: { ctx in ctx.windowController?.showCompareByContent() })
    static let cm_CompareFilesBinary = PCCommand(id: 30080, name: "cm_CompareFilesBinary", category: "Files",
        help: "Compare files as hex/binary", handler: { ctx in ctx.windowController?.showCompareBinary() })
    static let cm_GotoPath = PCCommand(id: 30081, name: "cm_GotoPath", category: "Navigation",
        help: "Go to folder by typing a path", handler: { ctx in ctx.windowController?.showGotoPath() })
    static let cm_OpenTerminal = PCCommand(id: 30082, name: "cm_OpenTerminal", category: "Commands",
        help: "Open a terminal in the current directory", handler: { ctx in ctx.windowController?.openTerminalHere() })
    static let cm_CopySamepanel = PCCommand(id: 40011, name: "cm_CopySamepanel", category: "Files",
        help: "Copy under a new name in the same folder (Shift+F5)", handler: cm_CopySamepanel_handler)
    static let cm_RenameOnly = PCCommand(id: 30084, name: "cm_RenameOnly", category: "Files",
        help: "Rename the file under the cursor (Shift+F6)", handler: { ctx in ctx.windowController?.showRenameFile() })
    static let cm_EditHex = PCCommand(id: 30085, name: "cm_EditHex", category: "Files",
        help: "Edit the cursor file as hex", handler: { ctx in ctx.windowController?.showHexEditor() })
    static let cm_MountShare = PCCommand(id: 30086, name: "cm_MountShare", category: "Network",
        help: "Connect to a network share (SMB/AFP)", handler: { ctx in ctx.windowController?.showMountShare() })
    static let cm_CompareDirs = PCCommand(id: 30046, name: "cm_CompareDirs", category: "Mark",
        help: "Mark newer/differing files in both panels", handler: { ctx in ctx.windowController?.compareDirectories(withSubdirs: false) })
    static let cm_CompareDirsWithSubdirs = PCCommand(id: 30047, name: "cm_CompareDirsWithSubdirs", category: "Mark",
        help: "Compare directories including subdirectories", handler: { ctx in ctx.windowController?.compareDirectories(withSubdirs: true) })
    static let cm_SyncDirs = PCCommand(id: 30048, name: "cm_SyncDirs", category: "Commands",
        help: "Synchronize directories", handler: { ctx in ctx.windowController?.showSynchronizeDirs() })
    static let cm_ChangeStartMenu = PCCommand(id: 30049, name: "cm_ChangeStartMenu", category: "Configuration",
        help: "Edit the Start (user commands) menu", handler: { ctx in ctx.windowController?.showChangeStartMenu() })
    static let cm_ConfigButtonBar = PCCommand(id: 30050, name: "cm_ConfigButtonBar", category: "Configuration",
        help: "Customize the button bar", handler: { ctx in ctx.windowController?.showCustomizeToolbar() })
    static let cm_CommandBrowser = PCCommand(id: 30053, name: "cm_CommandBrowser", category: "Configuration",
        help: "Browse all commands", handler: { ctx in ctx.windowController?.showCommandBrowser() })
    static let cm_ConfigKeys = PCCommand(id: 30054, name: "cm_ConfigKeys", category: "Configuration",
        help: "Edit keyboard shortcuts", handler: { ctx in ctx.windowController?.showKeysEditor() })
    static let cm_ConfigPlugins = PCCommand(id: 30055, name: "cm_ConfigPlugins", category: "Configuration",
        help: "Manage plugins", handler: { ctx in ctx.windowController?.showPluginsManager() })
    static let cm_ConfigColumns = PCCommand(id: 30110, name: "cm_ConfigColumns", category: "Configuration",
        help: "Configure the panel's visible columns", handler: { ctx in ctx.windowController?.showColumnsConfig() })
    static let cm_FtpNew = PCCommand(id: 30060, name: "cm_FtpNew", category: "Network",
        help: "New FTP/URL connection (Ctrl+N)", handler: { ctx in ctx.windowController?.showQuickConnect() })
    static let cm_NetConnect = PCCommand(id: 30061, name: "cm_NetConnect", category: "Network",
        help: "Connect to a network location", handler: { ctx in ctx.windowController?.showQuickConnect() })
    static let cm_CreateChecksums = PCCommand(id: 30062, name: "cm_CreateChecksums", category: "Files",
        help: "Create checksum file(s)", handler: { ctx in ctx.windowController?.showCreateChecksums() })
    static let cm_VerifyChecksums = PCCommand(id: 30063, name: "cm_VerifyChecksums", category: "Files",
        help: "Verify checksum file(s)", handler: { ctx in ctx.windowController?.showVerifyChecksums() })
    static let cm_FindDuplicates = PCCommand(id: 30064, name: "cm_FindDuplicates", category: "Files",
        help: "Find duplicate files in the current folder", handler: { ctx in ctx.windowController?.showFindDuplicates() })
    static let cm_EncodeFile = PCCommand(id: 30065, name: "cm_EncodeFile", category: "Files",
        help: "Encode the file (Base64)", handler: { ctx in ctx.windowController?.showEncodeFile() })
    static let cm_DecodeFile = PCCommand(id: 30066, name: "cm_DecodeFile", category: "Files",
        help: "Decode the file (Base64)", handler: { ctx in ctx.windowController?.showDecodeFile() })
    static let cm_SplitFile = PCCommand(id: 30067, name: "cm_SplitFile", category: "Files",
        help: "Split a file into pieces", handler: { ctx in ctx.windowController?.showSplitFile() })
    static let cm_CombineFiles = PCCommand(id: 30068, name: "cm_CombineFiles", category: "Files",
        help: "Combine split files", handler: { ctx in ctx.windowController?.showCombineFiles() })
    static let cm_CalcSpace = PCCommand(id: 30069, name: "cm_CalcSpace", category: "Files",
        help: "Calculate occupied space of the selection (Ctrl+L)", handler: { ctx in ctx.windowController?.showOccupiedSpace() })
    static let cm_SetAttrib = PCCommand(id: 30070, name: "cm_SetAttrib", category: "Files",
        help: "Change attributes", handler: { ctx in ctx.windowController?.showChangeAttributes() })
    static let cm_EditComment = PCCommand(id: 30071, name: "cm_EditComment", category: "Files",
        help: "Edit file comment (Ctrl+Z)", handler: { ctx in ctx.windowController?.showEditComment() })
    static let cm_ExportFileList = PCCommand(id: 30072, name: "cm_ExportFileList", category: "Files",
        help: "Export the file list to a text file", handler: { ctx in ctx.windowController?.showExportFileList() })
    static let cm_PrintFileList = PCCommand(id: 30073, name: "cm_PrintFileList", category: "Files",
        help: "Print the file list (Ctrl+Shift+F9)", handler: { ctx in ctx.windowController?.showPrintFileList() })
    static let cm_DirBranch = PCCommand(id: 30074, name: "cm_DirBranch", category: "Navigation",
        help: "Branch view: flatten subdirectories (Ctrl+B)", handler: { ctx in ctx.windowController?.showBranchView() })
    static let cm_DirBranchSel = PCCommand(id: 30075, name: "cm_DirBranchSel", category: "Navigation",
        help: "Branch view of the selection (Ctrl+Shift+B)", handler: { ctx in ctx.windowController?.showBranchViewSelected() })
    static let cm_CreateSymlink = PCCommand(id: 30076, name: "cm_CreateSymlink", category: "Files",
        help: "Create a symbolic link", handler: { ctx in ctx.windowController?.showCreateSymlink() })
    static let cm_CreateHardlink = PCCommand(id: 30077, name: "cm_CreateHardlink", category: "Files",
        help: "Create a hard link", handler: { ctx in ctx.windowController?.showCreateHardlink() })
    static let cm_CreateAlias = PCCommand(id: 30078, name: "cm_CreateAlias", category: "Files",
        help: "Create a macOS alias", handler: { ctx in ctx.windowController?.showCreateAlias() })
    static let cm_CycleViewMode = PCCommand(id: 30087, name: "cm_CycleViewMode", category: "View",
        help: "Cycle the active panel's view mode (details/brief/icons/gallery)",
        handler: { ctx in ctx.windowController?.cycleActivePanelViewMode() })
    static let cm_TransferManager = PCCommand(id: 30089, name: "cm_TransferManager", category: "Commands",
        help: "Show the background transfer manager",
        handler: { ctx in ctx.windowController?.showTransferManager() })
    static let cm_FtpConnect = PCCommand(id: 30092, name: "cm_FtpConnect", category: "Network",
        help: "Open the FTP connection manager",
        handler: { ctx in ctx.windowController?.showFtpConnect() })
    static let cm_FtpDisconnect = PCCommand(id: 30108, name: "cm_FtpDisconnect", category: "Network",
        help: "Disconnect the current FTP/SFTP session",
        handler: { ctx in ctx.windowController?.disconnectActivePanelNetwork() })
    static let cm_FtpRawCommand = PCCommand(id: 30121, name: "cm_FtpRawCommand", category: "Network",
        help: "Open the FTP console: raw protocol log + send custom commands",
        handler: { ctx in ctx.windowController?.showFtpConsole() })
    static let cm_DownloadFromURL = PCCommand(id: 30122, name: "cm_DownloadFromURL", category: "Network",
        help: "Download a file from an HTTP/HTTPS URL into the current folder",
        handler: { ctx in ctx.windowController?.showDownloadFromURL() })
    static let cm_OpenSourceNotices = PCCommand(id: 30109, name: "cm_OpenSourceNotices", category: "Help",
        help: "Show open-source and third-party software notices",
        handler: { ctx in ctx.windowController?.showOpenSourceNotices() })
    static let cm_ImportWincmd = PCCommand(id: 30106, name: "cm_ImportWincmd", category: "Configuration",
        help: "Import hotlist, button bar and FTP sites from a Total Commander wincmd.ini",
        handler: { ctx in ctx.windowController?.showImportWincmd() })
    static let cm_ConfigMainMenu = PCCommand(id: 30107, name: "cm_ConfigMainMenu", category: "Configuration",
        help: "Create or edit the user main-menu file (.mnu)",
        handler: { ctx in ctx.windowController?.showEditMainMenu() })
    static let cm_QuickLook = PCCommand(id: 30093, name: "cm_QuickLook", category: "View",
        help: "Quick Look preview of the selection",
        handler: { ctx in ctx.windowController?.showQuickLook() })
    static let cm_EjectVolume = PCCommand(id: 30123, name: "cm_EjectVolume", category: "Commands",
        help: "Eject the removable volume the cursor or the current folder is on",
        handler: { ctx in ctx.windowController?.ejectVolumeUnderCursor() })
    static let cm_FullDiskAccess = PCCommand(id: 30094, name: "cm_FullDiskAccess", category: "Configuration",
        help: "Full Disk Access: explain and open System Settings",
        handler: { ctx in ctx.windowController?.showFullDiskAccessInfo() })
    static let cm_TestArchive = PCCommand(id: 30097, name: "cm_TestArchive", category: "Files",
        help: "Test archive integrity (verify CRCs)",
        handler: { ctx in ctx.windowController?.showTestArchive() })
    static let cm_UnpackFiles = PCCommand(id: 30103, name: "cm_UnpackFiles", category: "Files",
        help: "Unpack archive(s) to a destination folder (Alt+F9)",
        handler: { ctx in ctx.windowController?.showUnpackFiles() })
    static let cm_Workspaces = PCCommand(id: 30098, name: "cm_Workspaces", category: "Configuration",
        help: "Workspaces: load, delete, or save a named panel layout",
        handler: { ctx in ctx.windowController?.showWorkspaces() })
    static let cm_SaveWorkspace = PCCommand(id: 30099, name: "cm_SaveWorkspace", category: "Configuration",
        help: "Save the current layout as a named workspace",
        handler: { ctx in ctx.windowController?.showSaveWorkspace() })
    static let cm_PreviewPanel = PCCommand(id: 30102, name: "cm_PreviewPanel", category: "View",
        help: "Toggle the preview/info sidebar (Info, Activities, Log)",
        handler: { ctx in ctx.windowController?.togglePreviewPanel() })
    static let cm_HorizontalPanels = PCCommand(id: 30104, name: "cm_HorizontalPanels", category: "View",
        help: "Arrange the two file panels above/below each other instead of side by side",
        handler: { ctx in ctx.windowController?.toggleHorizontalPanels() })
    static let cm_ButtonBar = PCCommand(id: 30114, name: "cm_ButtonBar", category: "View",
        help: "Show or hide the button bar",
        handler: { ctx in ctx.windowController?.toggleButtonBar() })
    static let cm_VerticalButtonBar = PCCommand(id: 30105, name: "cm_VerticalButtonBar", category: "View",
        help: "Dock the button bar as a left-hand column instead of the top strip",
        handler: { ctx in ctx.windowController?.toggleVerticalButtonBar() })
    static let cm_SrcLong = PCCommand(id: 306, name: "cm_SrcLong", category: "View",
        help: "Full (details) view (Ctrl+F2)",
        handler: { ctx in ctx.windowController?.setActivePanelViewMode(.details) })
    static let cm_SrcShort = PCCommand(id: 305, name: "cm_SrcShort", category: "View",
        help: "Brief view (Ctrl+F1)",
        handler: { ctx in ctx.windowController?.setActivePanelViewMode(.brief) })
    static let cm_SrcIcons = PCCommand(id: 30088, name: "cm_SrcIcons", category: "View",
        help: "Icon view",
        handler: { ctx in ctx.windowController?.setActivePanelViewMode(.icons) })
    static let cm_SrcThumbs = PCCommand(id: 302, name: "cm_SrcThumbs", category: "View",
        help: "Thumbnail (gallery) view (Ctrl+Shift+F1)",
        handler: { ctx in ctx.windowController?.setActivePanelViewMode(.gallery) })
    static let cm_SrcTree = PCCommand(id: 304, name: "cm_SrcTree", category: "View",
        help: "Show/hide the folder tree in the panel (Ctrl+F8)",
        handler: { ctx in ctx.windowController?.toggleActivePanelTree() })
    static let cm_TreeShared = PCCommand(id: 307, name: "cm_TreeShared", category: "View",
        help: "Show/hide one folder tree for both panels",
        handler: { ctx in ctx.windowController?.toggleSharedTree() })
    // Named for what the user sees rather than for the mechanism: the menu says "Bottom Area", and a
    // command called cm_ToggleDock sent anyone searching the command browser looking for a dock. The
    // house style has no Toggle prefix either — cm_PreviewPanel, cm_ButtonBar.
    static let cm_BottomArea = PCCommand(id: 308, name: "cm_BottomArea", category: "View",
        help: "Show or hide the area across the bottom of the window, where the terminal lives",
        handler: { ctx in ctx.windowController?.toggleBottomDock() })
    static let cm_ResetLayout = PCCommand(id: 309, name: "cm_ResetLayout", category: "View",
        help: "Put panels, dock and side panel back where they started",
        handler: { ctx in ctx.windowController?.resetLayout() })
    static let cm_TerminalCdHere = PCCommand(id: 310, name: "cm_TerminalCdHere", category: "Terminal",
        help: "Change the embedded terminal to the active panel's folder",
        handler: { ctx in ctx.windowController?.terminalCdHere() })
    static let cm_TerminalSendNames = PCCommand(id: 311, name: "cm_TerminalSendNames", category: "Terminal",
        help: "Put the selected file names at the terminal's prompt",
        handler: { ctx in ctx.windowController?.terminalSendNames() })
    static let cm_TerminalFocus = PCCommand(id: 313, name: "cm_TerminalFocus", category: "Terminal",
        help: "Move the keyboard between the file panel and the terminal",
        handler: { ctx in ctx.windowController?.focusTerminal() })
    static let cm_TerminalNewTab = PCCommand(id: 314, name: "cm_TerminalNewTab", category: "Terminal",
        help: "Open another terminal tab",
        handler: { ctx in ctx.windowController?.terminalNewTab() })
    // Not the same as cm_BottomArea, which is the furniture: this one follows the terminal wherever the
    // user has put it, and it is in the Terminal menu where they look for it (F-388).
    static let cm_TerminalToggle = PCCommand(id: 317, name: "cm_TerminalToggle", category: "Terminal",
        help: "Show or hide the terminal, keeping its tabs and whatever is running in them",
        handler: { ctx in ctx.windowController?.toggleTerminal() })
    static let cm_TerminalCloseTab = PCCommand(id: 316, name: "cm_TerminalCloseTab", category: "Terminal",
        help: "Close the terminal tab that is showing, asking first if something is running in it",
        handler: { ctx in ctx.windowController?.terminalCloseTab() })
    static let cm_TerminalSplit = PCCommand(id: 315, name: "cm_TerminalSplit", category: "Terminal",
        help: "Split the terminal in two, or put it back together",
        handler: { ctx in ctx.windowController?.terminalSplit() })
    // cm_Terminal* throughout, so the six of them sort together in the command browser.
    static let cm_TerminalRunCommandLine = PCCommand(id: 312, name: "cm_TerminalRunCommandLine", category: "Terminal",
        help: "Run the command line in the terminal instead of detached, so prompts and output are visible",
        handler: { ctx in ctx.windowController?.toggleRunCommandLineInTerminal() })
    static let cm_ImageInfo = PCCommand(id: 30079, name: "cm_ImageInfo", category: "Files",
        help: "Show image dimensions/metadata", handler: { ctx in ctx.windowController?.showImageInfo() })
    static let cm_ConfigKeyClassic = PCCommand(id: 30051, name: "cm_ConfigKeyClassic", category: "Configuration",
        help: "Use the TC Classic keyboard scheme", handler: { ctx in ctx.windowController?.setKeyScheme("tc-classic") })
    static let cm_ConfigKeyMacOS = PCCommand(id: 30052, name: "cm_ConfigKeyMacOS", category: "Configuration",
        help: "Use the macOS Native keyboard scheme", handler: { ctx in ctx.windowController?.setKeyScheme("macos") })

    static let cm_DirectoryHotlist = PCCommand(id: 30040, name: "cm_DirectoryHotlist", category: "Navigation",
        help: "Show directory hotlist (Ctrl+D)", handler: { ctx in ctx.windowController?.showHotlist() })
    static let cm_List = PCCommand(id: 30041, name: "cm_List", category: "View",
        help: "View file under cursor (F3)", handler: { ctx in ctx.windowController?.showLister() })
    static let cm_SrcQuickview = PCCommand(id: 30042, name: "cm_SrcQuickview", category: "View",
        help: "Quick View (Ctrl+Q)", handler: { ctx in ctx.windowController?.toggleQuickView() })

    static let cm_OpenNewTab = PCCommand(id: 30030, name: "cm_OpenNewTab", category: "Tabs",
        help: "Open a new tab (Cmd+T)", handler: { ctx in await ctx.activePanel?.openNewTab() })
    static let cm_OpenDirUnderCursorInNewTab = PCCommand(id: 30056, name: "cm_OpenDirUnderCursorInNewTab", category: "Tabs",
        help: "Open the folder under the cursor in a new tab", handler: { ctx in await ctx.activePanel?.openDirUnderCursorInNewTab() })
    static let cm_OpenNewTabBg = PCCommand(id: 30057, name: "cm_OpenNewTabBg", category: "Tabs",
        help: "Open a new tab in the background (Ctrl+Shift+T)", handler: { ctx in await ctx.activePanel?.openNewTabInBackground() })
    static let cm_CloseCurrentTab = PCCommand(id: 30031, name: "cm_CloseCurrentTab", category: "Tabs",
        help: "Close the current tab (Cmd+W)", handler: { ctx in await ctx.activePanel?.closeCurrentTab() })
    static let cm_CloseAllTabs = PCCommand(id: 30058, name: "cm_CloseAllTabs", category: "Tabs",
        help: "Close all tabs except the current one", handler: { ctx in await ctx.activePanel?.closeAllTabs() })
    static let cm_NextTab = PCCommand(id: 30032, name: "cm_NextTab", category: "Tabs",
        help: "Next tab (Ctrl+Tab)", handler: { ctx in await ctx.activePanel?.nextTab() })
    static let cm_PrevTab = PCCommand(id: 30033, name: "cm_PrevTab", category: "Tabs",
        help: "Previous tab (Ctrl+Shift+Tab)", handler: { ctx in await ctx.activePanel?.prevTab() })
    static let cm_LockTab = PCCommand(id: 30034, name: "cm_LockTab", category: "Tabs",
        help: "Lock/unlock the current tab", handler: { ctx in await ctx.activePanel?.toggleLockTab() })

    static let cm_Options = PCCommand(id: 30010, name: "cm_Options", category: "View",
        help: "Open Settings (Cmd+,)", handler: cm_Options_handler)
    static let cm_HistoryBack = PCCommand(id: 30020, name: "cm_HistoryBack", category: "Navigation",
        help: "Go back (Alt+Left)", handler: { ctx in await ctx.activePanel?.goBack() })
    static let cm_HistoryForward = PCCommand(id: 30021, name: "cm_HistoryForward", category: "Navigation",
        help: "Go forward (Alt+Right)", handler: { ctx in await ctx.activePanel?.goForward() })
    static let cm_Exchange = PCCommand(id: 30022, name: "cm_Exchange", category: "Navigation",
        help: "Swap panels (Ctrl+U)", handler: { ctx in ctx.windowController?.swapPanels() })
    static let cm_TargetEqualSource = PCCommand(id: 30028, name: "cm_TargetEqualSource", category: "Navigation",
        help: "Show the active panel's folder in the other panel (target = source)",
        handler: { ctx in await ctx.windowController?.targetEqualsSource() })
    static let cm_ExchangeWithTabs = PCCommand(id: 30029, name: "cm_ExchangeWithTabs", category: "Navigation",
        help: "Swap panels including all tabs (Ctrl+Shift+U)",
        handler: { ctx in ctx.windowController?.swapPanelsIncludingTabs() })
    static let cm_GoToHome = PCCommand(id: 30023, name: "cm_GoToHome", category: "Navigation",
        help: "Go to Home folder", handler: { ctx in await ctx.activePanel?.loadDirectory(NSHomeDirectory()) })
    static let cm_GoToDesktop = PCCommand(id: 30024, name: "cm_GoToDesktop", category: "Navigation",
        help: "Go to Desktop", handler: { ctx in
            await ctx.activePanel?.loadDirectory((NSHomeDirectory() as NSString).appendingPathComponent("Desktop")) })
    static let cm_GoToDownloads = PCCommand(id: 30025, name: "cm_GoToDownloads", category: "Navigation",
        help: "Go to Downloads", handler: { ctx in
            await ctx.activePanel?.loadDirectory((NSHomeDirectory() as NSString).appendingPathComponent("Downloads")) })
    static let cm_GoToTrash = PCCommand(id: 30026, name: "cm_GoToTrash", category: "Navigation",
        help: "Go to Trash", handler: { ctx in
            await ctx.activePanel?.loadDirectory((NSHomeDirectory() as NSString).appendingPathComponent(".Trash")) })
    static let cm_GoToICloud = PCCommand(id: 30027, name: "cm_GoToICloud", category: "Navigation",
        help: "Go to iCloud Drive", handler: { ctx in
            await ctx.activePanel?.loadDirectory((NSHomeDirectory() as NSString)
                .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")) })
    static let cm_GoToRoot = PCCommand(id: 30111, name: "cm_GoToRoot", category: "Navigation",
        help: "Go to the volume root (/)", handler: { ctx in await ctx.activePanel?.loadDirectory("/") })
    static let cm_QuickFilter = PCCommand(id: 30112, name: "cm_QuickFilter", category: "View",
        help: "Quick filter of visible files (Ctrl+S)",
        handler: { ctx in ctx.windowController?.toggleQuickFilter() })
    /// The global history palette (F-402): folders, files, operations and commands in one searchable
    /// window. Distinct from `cm_HistoryList`, which is the *active panel's* folder dropdown — one is
    /// "where was I in this panel", the other is "where have I been at all, and what did I do".
    static let cm_History = PCCommand(id: 30115, name: "cm_History", category: "Navigation",
        help: "Show the global history (folders, files, operations, commands) — Cmd+Shift+H",
        handler: { ctx in ctx.windowController?.showHistoryPalette() })
    static let cm_HistoryList = PCCommand(id: 30113, name: "cm_HistoryList", category: "Navigation",
        help: "Show the folder history list (Alt+Down)",
        handler: { ctx in ctx.windowController?.showHistoryMenu() })

    // MARK: - File Operation Commands (I04)

    static let cm_Copy = PCCommand(id: 40000, name: "cm_Copy", category: "Files",
        help: "Copy selection to the other panel (F5)", handler: cm_Copy_handler)
    static let cm_RenMov = PCCommand(id: 40001, name: "cm_RenMov", category: "Files",
        help: "Move/rename selection to the other panel (F6)", handler: cm_RenMov_handler)
    static let cm_MkDir = PCCommand(id: 40002, name: "cm_MkDir", category: "Files",
        help: "Create a new directory (F7)", handler: cm_MkDir_handler)
    static let cm_Delete = PCCommand(id: 40003, name: "cm_Delete", category: "Files",
        help: "Delete selection to Trash (F8)", handler: cm_Delete_handler)
    static let cm_DeleteReal = PCCommand(id: 40004, name: "cm_DeleteReal", category: "Files",
        help: "Delete selection permanently (Shift+F8)", handler: cm_DeleteReal_handler)
    static let cm_PackFiles = PCCommand(id: 40010, name: "cm_PackFiles", category: "Files",
        help: "Pack selection to a ZIP (Alt+F5)", handler: cm_PackFiles_handler)
    static let cm_CopyToClipboard = PCCommand(id: 40005, name: "cm_CopyToClipboard", category: "Files",
        help: "Copy selected files to the clipboard (Cmd+C)", handler: cm_CopyToClipboard_handler)
    static let cm_CutToClipboard = PCCommand(id: 40006, name: "cm_CutToClipboard", category: "Files",
        help: "Cut selected files to the clipboard (Cmd+X)", handler: cm_CutToClipboard_handler)
    static let cm_PasteFromClipboard = PCCommand(id: 40007, name: "cm_PasteFromClipboard", category: "Files",
        help: "Paste files from the clipboard (Cmd+V)", handler: cm_PasteFromClipboard_handler)
    static let cm_Edit = PCCommand(id: 40008, name: "cm_Edit", category: "Files",
        help: "Edit the file under the cursor (F4)", handler: cm_Edit_handler)
    static let cm_EditNewFile = PCCommand(id: 40009, name: "cm_EditNewFile", category: "Files",
        help: "Create and edit a new text file (Shift+F4)", handler: cm_EditNewFile_handler)

    // MARK: - View Commands (I03-T06/T07)

    /// cm_SwitchHidSys - Toggle hidden/system files (Ctrl+H)
    static let cm_SwitchHidSys = PCCommand(
        id: 30000,
        name: "cm_SwitchHidSys",
        category: "View",
        help: "Toggle hidden/system files (Ctrl+H)",
        handler: cm_SwitchHidSys_handler
    )

    /// cm_Properties - Show properties dialog (Alt+Enter)
    static let cm_Properties = PCCommand(
        id: 30001,
        name: "cm_Properties",
        category: "View",
        help: "Show properties of the item under cursor (Alt+Enter)",
        handler: cm_Properties_handler
    )

    /// cm_CalcAllDirSizes - Calculate all directory sizes in view (Alt+Shift+Enter)
    static let cm_CalcAllDirSizes = PCCommand(
        id: 30002,
        name: "cm_CalcAllDirSizes",
        category: "View",
        help: "Calculate sizes of all directories in view (Alt+Shift+Enter)",
        handler: cm_CalcAllDirSizes_handler
    )

    /// cm_SelectByMask - Select files by wildcard mask (Num+)
    static let cm_SelectByMask = PCCommand(
        id: 30003,
        name: "cm_SelectByMask",
        category: "Selection",
        help: "Select a group of files by mask (Num+)",
        handler: cm_SelectByMask_handler
    )

    /// cm_UnselectByMask - Unselect files by wildcard mask (Num-)
    static let cm_UnselectByMask = PCCommand(
        id: 30004,
        name: "cm_UnselectByMask",
        category: "Selection",
        help: "Unselect a group of files by mask (Num-)",
        handler: cm_UnselectByMask_handler
    )

    // MARK: - Volume Commands (T04)

    /// cm_DriveCombo - Show drive selection dropdown
    static let cm_DriveCombo = PCCommand(
        id: 20000,
        name: "cm_DriveCombo",
        category: "Volume",
        help: "Show drive selection dropdown (Alt+F1)",
        handler: cm_DriveCombo_handler
    )

    /// cm_FreeSpaceLabel - Show free space label
    static let cm_FreeSpaceLabel = PCCommand(
        id: 20001,
        name: "cm_FreeSpaceLabel",
        category: "Volume",
        help: "Show free space label (Alt+F2)",
        handler: cm_FreeSpaceLabel_handler
    )

    // MARK: - Volume Command Handlers

    @MainActor
    private static func cm_DriveCombo_handler(_ context: CommandContext) async throws {
        // This will be implemented in T04 with the actual dropdown UI
        PCFoundationLogger.info("cm_DriveCombo: Drive selection dropdown")
    }

    @MainActor
    private static func cm_FreeSpaceLabel_handler(_ context: CommandContext) async throws {
        // This will be implemented in T04 with the actual free space display
        PCFoundationLogger.info("cm_FreeSpaceLabel: Free space label")
    }

    // MARK: - Selection Commands (T01/T02)

    /// cm_ToggleMark - Toggle mark on cursor row
    static let cm_ToggleMark = PCCommand(
        id: 100,
        name: "cm_ToggleMark",
        category: "Selection",
        help: "Toggle mark on cursor row (Insert)",
        handler: cm_ToggleMark_handler
    )

    /// cm_MarkAll - Select all files
    static let cm_MarkAll = PCCommand(
        id: 101,
        name: "cm_MarkAll",
        category: "Selection",
        help: "Select all files (Ctrl+Num+, / Mark All)",
        handler: cm_MarkAll_handler
    )

    /// cm_UnmarkAll - Clear all selection
    static let cm_UnmarkAll = PCCommand(
        id: 102,
        name: "cm_UnmarkAll",
        category: "Selection",
        help: "Clear all selection (Ctrl+Num+- / Mark None)",
        handler: cm_UnmarkAll_handler
    )

    /// cm_InvertMarks - Invert selection
    static let cm_InvertMarks = PCCommand(
        id: 103,
        name: "cm_InvertMarks",
        category: "Selection",
        help: "Invert selection (Num*)",
        handler: cm_InvertMarks_handler
    )

    /// cm_RestoreSelection - Restore previous selection
    static let cm_RestoreSelection = PCCommand(
        id: 104,
        name: "cm_RestoreSelection",
        category: "Selection",
        help: "Restore previous selection (Num/)",
        handler: cm_RestoreSelection_handler
    )

    /// cm_SelectSameExt - Select files with same extension
    static let cm_SelectSameExt = PCCommand(
        id: 105,
        name: "cm_SelectSameExt",
        category: "Selection",
        help: "Select files with same extension (Alt+Num+)",
        handler: cm_SelectSameExt_handler
    )
}

// MARK: - Selection Command Handlers

@MainActor
private func cm_ToggleMark_handler(_ context: CommandContext) async throws {
    await context.activePanel?.toggleMarkAtCursor()
}

@MainActor
private func cm_MarkAll_handler(_ context: CommandContext) async throws {
    await context.activePanel?.markAll()
}

@MainActor
private func cm_UnmarkAll_handler(_ context: CommandContext) async throws {
    await context.activePanel?.unmarkAll()
}

@MainActor
private func cm_InvertMarks_handler(_ context: CommandContext) async throws {
    await context.activePanel?.invertSelection()
}

@MainActor
private func cm_RestoreSelection_handler(_ context: CommandContext) async throws {
    await context.activePanel?.restoreSelection()
}

@MainActor
private func cm_SelectSameExt_handler(_ context: CommandContext) async throws {
    await context.activePanel?.selectSameExtension()
}

@MainActor
private func cm_SelectByMask_handler(_ context: CommandContext) async throws {
    await context.activePanel?.showSelectByMask()
}

@MainActor
private func cm_UnselectByMask_handler(_ context: CommandContext) async throws {
    await context.activePanel?.showUnselectByMask()
}

@MainActor
private func cm_SwitchHidSys_handler(_ context: CommandContext) async throws {
    context.windowController?.toggleHiddenFiles()
}

@MainActor
private func cm_Properties_handler(_ context: CommandContext) async throws {
    await context.activePanel?.showProperties()
}

@MainActor
private func cm_CalcAllDirSizes_handler(_ context: CommandContext) async throws {
    await context.activePanel?.calculateAllDirectorySizes()
}

@MainActor
private func cm_Options_handler(_ context: CommandContext) async throws {
    context.windowController?.showSettings()
}

@MainActor
private func cm_Copy_handler(_ context: CommandContext) async throws {
    guard let active = context.activePanel, let inactive = context.inactivePanel else { return }
    let target = await inactive.currentDirectory()
    // Target panel is inside a rewritable archive → add the selection into it
    // (F-133 for a local source, F-139 for an archive-to-archive copy).
    if let zip = inactive.currentArchiveZipPath {
        await active.copyInto(archiveZip: zip, subPath: target)
        await inactive.reloadCurrentArchive()   // re-open the rewritten zip
    } else if inactive.isOnNetworkFilesystem {
        // A network target needs an upload, not a local copy against a remote path string (F-367).
        await active.uploadSelection(to: target, on: inactive.currentFileSystem)
        await inactive.reload()
    } else {
        await active.copySelection(to: target)
        await inactive.reload()
    }
}

/// Shift+F5 — the copy stays in this panel and gets a new name.
///
/// Only the active panel is involved, which is the whole difference from `cm_Copy`: there is no
/// "other side" to read, so it works with one panel maximised as well.
@MainActor
private func cm_CopySamepanel_handler(_ context: CommandContext) async throws {
    guard let active = context.activePanel else { return }
    await active.copySelectionSamePanel()
}

@MainActor
private func cm_RenMov_handler(_ context: CommandContext) async throws {
    guard let active = context.activePanel, let inactive = context.inactivePanel else { return }
    let target = await inactive.currentDirectory()
    // Mirror cm_Copy: a target panel inside a rewritable archive means "add to the archive",
    // here followed by removing the sources. Without this branch the move fell through to an
    // ordinary filesystem move whose destination was the panel's path *inside* the zip, so it
    // never touched the archive.
    if let zip = inactive.currentArchiveZipPath {
        await active.moveInto(archiveZip: zip, subPath: target)
        await inactive.reloadCurrentArchive()   // re-open the rewritten zip
        await active.reload()
    } else {
        await active.moveSelection(to: target)
        await active.reload()
        await inactive.reload()
    }
}

@MainActor
private func cm_MkDir_handler(_ context: CommandContext) async throws {
    await context.activePanel?.makeDirectory()
}

@MainActor
private func cm_Delete_handler(_ context: CommandContext) async throws {
    await context.activePanel?.deleteSelection(permanent: false)
}

@MainActor
private func cm_DeleteReal_handler(_ context: CommandContext) async throws {
    await context.activePanel?.deleteSelection(permanent: true)
}

@MainActor
private func cm_PackFiles_handler(_ context: CommandContext) async throws {
    guard let active = context.activePanel, let inactive = context.inactivePanel else { return }
    let target = await inactive.currentDirectory()
    await active.packSelection(to: target)
    await inactive.reload()
}

@MainActor
private func cm_CopyToClipboard_handler(_ context: CommandContext) async throws {
    await context.activePanel?.copyToClipboard()
}

@MainActor
private func cm_CutToClipboard_handler(_ context: CommandContext) async throws {
    await context.activePanel?.cutToClipboard()
}

@MainActor
private func cm_PasteFromClipboard_handler(_ context: CommandContext) async throws {
    await context.activePanel?.pasteFromClipboard()
}

@MainActor
private func cm_Edit_handler(_ context: CommandContext) async throws {
    context.windowController?.showEditorForCursor()
}

@MainActor
private func cm_EditNewFile_handler(_ context: CommandContext) async throws {
    context.windowController?.showEditorForNewFile()
}

/// Command execution error
public enum CommandError: Error {
    case unknownCommand(String)
}
