// SPDX-License-Identifier: Apache-2.0
// AppMenu.swift - Main menu bar, wired to the command registry
//
// Every menu item carries its cm_* command name in `representedObject`; the
// target's single action dispatches it through the CommandRegistry (CONVENTIONS:
// no ad-hoc selectors from menu items to controllers).

import AppKit

enum AppMenu {
    /// Build the application's main menu. `commandAction` is invoked for command
    /// items with `sender.representedObject` set to the cm_* name.
    static func build(target: AnyObject, commandAction: Selector) -> NSMenu {
        let main = NSMenu()

        // Application menu
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(withTitle: String(localized: "About \(appName)"),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(command(String(localized: "Settings…"), cmd: "cm_Options",
                                key: ",", mask: .command, target: target, action: commandAction))
        appMenu.addItem(.separator())
        // Standard macOS Services submenu — AppKit populates it from the selection
        // the active panel offers via NSServicesMenuRequestor (see AppDelegate).
        let servicesItem = NSMenuItem(title: String(localized: "Services"), action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: String(localized: "Services"))
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Hide \(appName)"),
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        let quit = appMenu.addItem(withTitle: String(localized: "Quit \(appName)"),
                                   action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = .command

        // File menu
        let fileItem = NSMenuItem()
        main.addItem(fileItem)
        let fileMenu = NSMenu(title: String(localized: "File"))
        fileItem.submenu = fileMenu
        let f3 = String(utf16CodeUnits: [0xF706], count: 1)
        let f4 = String(utf16CodeUnits: [0xF707], count: 1)
        let f5 = String(utf16CodeUnits: [0xF708], count: 1)
        let f6 = String(utf16CodeUnits: [0xF709], count: 1)
        let f7 = String(utf16CodeUnits: [0xF70A], count: 1)
        let f8 = String(utf16CodeUnits: [0xF70B], count: 1)
        let f9 = String(utf16CodeUnits: [0xF70C], count: 1)
        fileMenu.addItem(command(String(localized: "Get Info"), cmd: "cm_Properties",
                                 key: "i", mask: .command, target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "View File"), cmd: "cm_List",
                                 key: f3, mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Edit File"), cmd: "cm_Edit",
                                 key: f4, mask: [], target: target, action: commandAction))
        // "View as Log…" is contributed by the Log Viewer plugin's manifest.
        fileMenu.addItem(command(String(localized: "Edit as Hex…"), cmd: "cm_EditHex",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Compare by Content…"), cmd: "cm_CompareFilesByContent",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Compare by Content (Hex)…"), cmd: "cm_CompareFilesBinary",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(command(String(localized: "Go to Folder…"), cmd: "cm_GotoPath",
                                 key: "g", mask: [.command, .shift], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Open Terminal Here"), cmd: "cm_OpenTerminal",
                                 key: "t", mask: [.command, .option], target: target, action: commandAction))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(command(String(localized: "New Text File…"), cmd: "cm_EditNewFile",
                                 key: f4, mask: .shift, target: target, action: commandAction))
        fileMenu.addItem(.separator())
        fileMenu.addItem(command(String(localized: "Copy…"), cmd: "cm_Copy",
                                 key: f5, mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Move…"), cmd: "cm_RenMov",
                                 key: f6, mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Rename…"), cmd: "cm_RenameOnly",
                                 key: f6, mask: .shift, target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "New Folder…"), cmd: "cm_MkDir",
                                 key: f7, mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Delete"), cmd: "cm_Delete",
                                 key: f8, mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Delete Permanently"), cmd: "cm_DeleteReal",
                                 key: f8, mask: .shift, target: target, action: commandAction))
        fileMenu.addItem(.separator())
        // Not-yet-implemented entries: shown for structure, auto-disabled at startup
        // (KeymapMenu.apply disables items whose command isn't registered).
        fileMenu.addItem(command(String(localized: "Change Attributes…"), cmd: "cm_SetAttrib",
                                 key: "", mask: [], target: target, action: commandAction))
        // "Uninstall Application…" is no longer hard-wired — it is contributed by the
        // Uninstaller plugin's manifest (appears only when that plugin is enabled).
        // Pack + Unpack are kept adjacent as a matching archive pair.
        fileMenu.addItem(command(String(localized: "Pack…"), cmd: "cm_PackFiles",
                                 key: f5, mask: .option, target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Unpack…"), cmd: "cm_UnpackFiles",
                                 key: f9, mask: .option, target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Test Archive(s)"), cmd: "cm_TestArchive",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Calculate Occupied Space…"), cmd: "cm_CalcSpace",
                                 key: "l", mask: .control, target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Edit Comment…"), cmd: "cm_EditComment",
                                 key: "z", mask: .control, target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Split File…"), cmd: "cm_SplitFile",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Combine Files…"), cmd: "cm_CombineFiles",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Create Checksum(s)…"), cmd: "cm_CreateChecksums",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Verify Checksum(s)…"), cmd: "cm_VerifyChecksums",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Find Duplicate Files…"), cmd: "cm_FindDuplicates",
                                 key: "", mask: [], target: target, action: commandAction))
        // Unified: save / copy / print is chosen in the command's dialog.
        fileMenu.addItem(command(String(localized: "File List…"), cmd: "cm_ExportFileList",
                                 key: "9", mask: [.command, .shift], target: target, action: commandAction))
        fileMenu.addItem(.separator())
        fileMenu.addItem(command(String(localized: "Create Symbolic Link…"), cmd: "cm_CreateSymlink",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Create Hard Link…"), cmd: "cm_CreateHardlink",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Create Alias…"), cmd: "cm_CreateAlias",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Image Info…"), cmd: "cm_ImageInfo",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Encode File…"), cmd: "cm_EncodeFile",
                                 key: "", mask: [], target: target, action: commandAction))
        fileMenu.addItem(command(String(localized: "Decode File…"), cmd: "cm_DecodeFile",
                                 key: "", mask: [], target: target, action: commandAction))

        // Edit menu (clipboard)
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: String(localized: "Edit"))
        editItem.submenu = editMenu
        // Standard selectors targeting the first responder (target nil), so Cmd+Z/C/X/V
        // do TEXT undo/copy/paste when a field editor is focused (command line, dialogs,
        // the search window) and FILE undo/copy/paste when a panel is focused (the panel
        // implements undo:/copy:/cut:/paste:). Fixes clipboard/undo shortcuts app-wide.
        AppMenu.editItem(editMenu, String(localized: "Undo"), action: Selector(("undo:")), target: nil, key: "z")
        editMenu.addItem(.separator())
        AppMenu.editItem(editMenu, String(localized: "Copy"), action: #selector(NSText.copy(_:)), target: nil, key: "c")
        AppMenu.editItem(editMenu, String(localized: "Cut"), action: #selector(NSText.cut(_:)), target: nil, key: "x")
        AppMenu.editItem(editMenu, String(localized: "Paste"), action: #selector(NSText.paste(_:)), target: nil, key: "v")
        editMenu.addItem(.separator())
        // Find, through the responder chain (F-381). Whatever is focused and can search answers it —
        // SwiftTerm's terminal view opens its own find bar over the scrollback. Nothing of ours is
        // involved, which is why the scrollback became searchable without a line of search code, and
        // why the item disables itself when the focused thing cannot search.
        //
        // ⌘F was *not* free, though it looked it: the menus bind ⌘⇧F to Find Files and Ctrl+F to the
        // FTP commands, but the macOS key scheme also had ⌘F on Find Files — which the shortcut audit
        // found and a grep of the menus did not. Find Files keeps Alt+F7 and ⌘⇧F, the two routes its
        // own menu item advertises, and ⌘F goes to the thing macOS users expect it to.
        for (title, tag, key, mask) in [
            (String(localized: "Find…"), NSFindPanelAction.showFindPanel, "f", NSEvent.ModifierFlags.command),
            (String(localized: "Find Next"), NSFindPanelAction.next, "g", NSEvent.ModifierFlags.command),
            (String(localized: "Find Previous"), NSFindPanelAction.previous, "g", [.command, .shift]),
        ] {
            let item = NSMenuItem(title: title, action: Selector(("performFindPanelAction:")),
                                  keyEquivalent: key)
            item.keyEquivalentModifierMask = mask
            item.tag = Int(tag.rawValue)
            editMenu.addItem(item)   // target nil → first responder
        }

        // Commands menu (search etc.)
        let cmdItem = NSMenuItem()
        main.addItem(cmdItem)
        let cmdMenu = NSMenu(title: String(localized: "Commands"))
        cmdItem.submenu = cmdMenu
        cmdMenu.addItem(command(String(localized: "Find Files…"), cmd: "cm_SearchFor",
                                key: "f", mask: [.command, .shift], target: target, action: commandAction))
        cmdMenu.addItem(command(String(localized: "Multi-Rename Tool…"), cmd: "cm_MultiRenameFiles",
                                key: "m", mask: .control, target: target, action: commandAction))
        cmdMenu.addItem(command(String(localized: "Edit Names in Editor…"), cmd: "cm_RenameByEditor",
                                key: "", mask: [], target: target, action: commandAction))
        cmdMenu.addItem(command(String(localized: "Background Transfer Manager…"), cmd: "cm_TransferManager",
                                key: "b", mask: [.command, .shift], target: target, action: commandAction))
        cmdMenu.addItem(.separator())
        // The AI Assistant is a removable plugin now; it contributes its own
        // "AI Assistant" command to this menu via PCContributions when installed.
        // "Compare by Content…" lives in the File menu (removed the duplicate here).
        cmdMenu.addItem(command(String(localized: "Synchronize Directories…"), cmd: "cm_SyncDirs",
                                key: "", mask: [], target: target, action: commandAction))
        cmdMenu.addItem(.separator())
        cmdMenu.addItem(command(String(localized: "CD Tree…"), cmd: "cm_DirectoryTreeDlg",
                                key: "", mask: [], target: target, action: commandAction))
        cmdMenu.addItem(command(String(localized: "Branch View"), cmd: "cm_DirBranch",
                                key: "b", mask: .control, target: target, action: commandAction))
        cmdMenu.addItem(command(String(localized: "Branch View (Selected)"), cmd: "cm_DirBranchSel",
                                key: "b", mask: [.control, .shift], target: target, action: commandAction))
        cmdMenu.addItem(command(String(localized: "Open Terminal Here"), cmd: "cm_OpenTerminal",
                                key: "", mask: [], target: target, action: commandAction))
        cmdMenu.addItem(command(String(localized: "Volume Label…"), cmd: "cm_VolumeName",
                                key: "", mask: [], target: target, action: commandAction))
        cmdMenu.addItem(command(String(localized: "System Information…"), cmd: "cm_NetworkGeneral",
                                key: "", mask: [], target: target, action: commandAction))
        cmdMenu.addItem(command(String(localized: "Full Disk Access…"), cmd: "cm_FullDiskAccess",
                                key: "", mask: [], target: target, action: commandAction))
        cmdMenu.addItem(.separator())
        cmdMenu.addItem(command(String(localized: "Run Command Line…"), cmd: "cm_FocusCmdLine",
                                key: "", mask: [], target: target, action: commandAction))

        // Net menu (FTP / network — all items live since I15/F-211).
        let netItem = NSMenuItem()
        main.addItem(netItem)
        let netMenu = NSMenu(title: String(localized: "Net"))
        netItem.submenu = netMenu
        netMenu.addItem(command(String(localized: "FTP Connect…"), cmd: "cm_FtpConnect",
                                key: "f", mask: .control, target: target, action: commandAction))
        netMenu.addItem(command(String(localized: "FTP New Connection…"), cmd: "cm_FtpNew",
                                key: "n", mask: .control, target: target, action: commandAction))
        netMenu.addItem(command(String(localized: "FTP Disconnect"), cmd: "cm_FtpDisconnect",
                                key: "f", mask: [.control, .shift], target: target, action: commandAction))
        netMenu.addItem(command(String(localized: "FTP Show Hidden Files"), cmd: "cm_FtpHiddenFiles",
                                key: "", mask: [], target: target, action: commandAction))
        netMenu.addItem(command(String(localized: "FTP Console…"), cmd: "cm_FtpRawCommand",
                                key: "", mask: [], target: target, action: commandAction))
        netMenu.addItem(.separator())
        // ⇧⌘U, not ⇧⌘D: Go ▸ Desktop has ⇧⌘D — the same key on two items means AppKit picks the first
        // and the other never fires, which is what happened here (U for URL).
        netMenu.addItem(command(String(localized: "Download from URL…"), cmd: "cm_DownloadFromURL",
                                key: "u", mask: [.command, .shift], target: target, action: commandAction))
        netMenu.addItem(.separator())
        // "WebDAV Connect…" is contributed by the WebDAV plugin's manifest (appears
        // only when that plugin is enabled) — no longer hard-wired here.
        netMenu.addItem(command(String(localized: "Mount Network Share…"), cmd: "cm_NetConnect",
                                key: "", mask: [], target: target, action: commandAction))

        // Mark menu
        let markItem = NSMenuItem()
        main.addItem(markItem)
        let markMenu = NSMenu(title: String(localized: "Mark"))
        markItem.submenu = markMenu
        // Cmd+A via the first responder: selects all text in a focused field, or
        // all files when a panel is focused (the panel maps selectAll: to cm_MarkAll).
        AppMenu.editItem(markMenu, String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), target: nil, key: "a")
        markMenu.addItem(command(String(localized: "Unselect All"), cmd: "cm_UnmarkAll",
                                 key: "a", mask: [.command, .shift], target: target, action: commandAction))
        markMenu.addItem(command(String(localized: "Invert Selection"), cmd: "cm_InvertMarks",
                                 key: "", mask: [], target: target, action: commandAction))
        markMenu.addItem(.separator())
        markMenu.addItem(command(String(localized: "Select Group…"), cmd: "cm_SelectByMask",
                                 key: "", mask: [], target: target, action: commandAction))
        markMenu.addItem(command(String(localized: "Unselect Group…"), cmd: "cm_UnselectByMask",
                                 key: "", mask: [], target: target, action: commandAction))
        markMenu.addItem(command(String(localized: "Select Files with Same Extension"), cmd: "cm_SelectSameExt",
                                 key: "", mask: [], target: target, action: commandAction))
        markMenu.addItem(.separator())
        markMenu.addItem(command(String(localized: "Copy Names to Clipboard"), cmd: "cm_CopyNamesToClip",
                                 key: "c", mask: [.command, .control], target: target, action: commandAction))
        markMenu.addItem(command(String(localized: "Copy Full Names to Clipboard"), cmd: "cm_CopyFullNamesToClip",
                                 key: "c", mask: [.command, .control, .shift], target: target, action: commandAction))
        markMenu.addItem(command(String(localized: "Copy Names as URLs"), cmd: "cm_CopyNetNamesToClip",
                                 key: "", mask: [], target: target, action: commandAction))
        markMenu.addItem(command(String(localized: "Copy Source Path"), cmd: "cm_CopySrcPathToClip",
                                 key: "", mask: [], target: target, action: commandAction))
        markMenu.addItem(command(String(localized: "Copy File Details"), cmd: "cm_CopyFileDetailsToClip",
                                 key: "", mask: [], target: target, action: commandAction))
        markMenu.addItem(.separator())
        markMenu.addItem(command(String(localized: "Compare Directories"), cmd: "cm_CompareDirs",
                                 key: "", mask: [], target: target, action: commandAction))
        markMenu.addItem(command(String(localized: "Compare Directories (with Subfolders)"), cmd: "cm_CompareDirsWithSubdirs",
                                 key: "", mask: [], target: target, action: commandAction))
        markMenu.addItem(.separator())
        markMenu.addItem(command(String(localized: "Restore Selection"), cmd: "cm_RestoreSelection",
                                 key: "", mask: [], target: target, action: commandAction))

        // Go menu (navigation)
        let goItem = NSMenuItem()
        main.addItem(goItem)
        let goMenu = NSMenu(title: String(localized: "Go"))
        goItem.submenu = goMenu
        goMenu.addItem(command(String(localized: "Back"), cmd: "cm_HistoryBack",
                               key: "[", mask: .command, target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "Forward"), cmd: "cm_HistoryForward",
                               key: "]", mask: .command, target: target, action: commandAction))
        goMenu.addItem(.separator())
        goMenu.addItem(command(String(localized: "Root"), cmd: "cm_GoToRoot",
                               key: "", mask: [], target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "Home"), cmd: "cm_GoToHome",
                               key: "h", mask: [.command, .shift], target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "Desktop"), cmd: "cm_GoToDesktop",
                               key: "d", mask: [.command, .shift], target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "Downloads"), cmd: "cm_GoToDownloads",
                               key: "l", mask: [.command, .option], target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "Trash"), cmd: "cm_GoToTrash",
                               key: "", mask: [], target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "iCloud Drive"), cmd: "cm_GoToICloud",
                               key: "", mask: [], target: target, action: commandAction))
        goMenu.addItem(.separator())
        goMenu.addItem(command(String(localized: "Connect to Server…"), cmd: "cm_MountShare",
                               key: "k", mask: .command, target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "Directory Hotlist…"), cmd: "cm_DirectoryHotlist",
                               key: "d", mask: .control, target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "Swap Panels"), cmd: "cm_Exchange",
                               key: "u", mask: .control, target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "Swap Panels (with Tabs)"), cmd: "cm_ExchangeWithTabs",
                               key: "u", mask: [.control, .shift], target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "Target = Source"), cmd: "cm_TargetEqualSource",
                               key: "=", mask: .control, target: target, action: commandAction))
        goMenu.addItem(.separator())
        goMenu.addItem(command(String(localized: "Workspaces…"), cmd: "cm_Workspaces",
                               key: "", mask: [], target: target, action: commandAction))
        goMenu.addItem(command(String(localized: "Save Workspace…"), cmd: "cm_SaveWorkspace",
                               key: "s", mask: [.command, .control], target: target, action: commandAction))

        // NOTE: the per-window "Viewer"/"Editor"/… menu is no longer a permanent menu
        // here. It is inserted contextually (see WindowContextMenuProviding /
        // setWindowContextMenu) only while the matching tool window is key, so the
        // main window doesn't show an out-of-place Viewer menu (TODOS #189).

        // Configuration menu (I13 §3)
        let configItem = NSMenuItem()
        main.addItem(configItem)
        let configMenu = NSMenu(title: String(localized: "Configuration"))
        configItem.submenu = configMenu
        // Settings live in exactly one place — this opens the same window the app menu's
        // ⌘, does. It used to be labelled "Options…" here while the app menu called the
        // *same command* "Settings…", so one feature looked like two.
        // No key equivalent here: the app menu's Settings… already owns ⌘, (the macOS convention), and
        // the same key on two items leaves the second one dead.
        configMenu.addItem(command(String(localized: "Settings…"), cmd: "cm_Options",
                                   key: "", mask: [], target: target, action: commandAction))
        configMenu.addItem(.separator())
        // Below: tools with their own windows, not preferences. Labelled exactly like the
        // buttons in the Settings panes that open the same windows ("Manage Plugins…",
        // "Edit Shortcuts…"), so the same wording always means the same destination
        // instead of reading like a second, competing feature.
        configMenu.addItem(command(String(localized: "Manage Plugins…"), cmd: "cm_ConfigPlugins",
                                   key: "", mask: [], target: target, action: commandAction))
        configMenu.addItem(command(String(localized: "Edit Shortcuts…"), cmd: "cm_ConfigKeys",
                                   key: "", mask: [], target: target, action: commandAction))
        configMenu.addItem(command(String(localized: "Customize Toolbar…"), cmd: "cm_ConfigButtonBar",
                                   key: "", mask: [], target: target, action: commandAction))
        configMenu.addItem(command(String(localized: "Columns…"), cmd: "cm_ConfigColumns",
                                   key: "", mask: [], target: target, action: commandAction))
        configMenu.addItem(command(String(localized: "Command Browser…"), cmd: "cm_CommandBrowser",
                                   key: "", mask: [], target: target, action: commandAction))
        configMenu.addItem(.separator())
        // One-off actions, kept apart from the everyday tools above.
        configMenu.addItem(command(String(localized: "Import wincmd.ini…"), cmd: "cm_ImportWincmd",
                                   key: "", mask: [], target: target, action: commandAction))
        configMenu.addItem(command(String(localized: "Edit Menu File…"), cmd: "cm_ConfigMainMenu",
                                   key: "", mask: [], target: target, action: commandAction))
        // The "Keyboard Scheme" submenu is gone: picking a scheme is a preference and it
        // already lives in Settings ▸ Keys, right above "Edit Shortcuts…" where the two
        // belong together. cm_ConfigKeyClassic / cm_ConfigKeyMacOS remain as commands, so
        // the button bar, the command browser and any keymap binding still reach them.

        // Start menu (user commands, I13 §4). Populated dynamically by the window
        // controller; the "Change Start Menu…" item is always the last entry.
        let startItem = NSMenuItem()
        main.addItem(startItem)
        let startMenu = NSMenu(title: String(localized: "Start"))
        startItem.submenu = startMenu
        startMenu.addItem(command(String(localized: "Change Start Menu…"), cmd: "cm_ChangeStartMenu",
                                  key: "", mask: [], target: target, action: commandAction))

        // View menu
        let viewItem = NSMenuItem()
        main.addItem(viewItem)
        let viewMenu = NSMenu(title: String(localized: "View"))
        viewItem.submenu = viewMenu
        viewMenu.addItem(command(String(localized: "Show Hidden Files"), cmd: "cm_SwitchHidSys",
                                 key: "h", mask: .control, target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Calculate All Directory Sizes"), cmd: "cm_CalcAllDirSizes",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Quick View"), cmd: "cm_SrcQuickview",
                                 key: "q", mask: .control, target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Quick Look"), cmd: "cm_QuickLook",
                                 key: "y", mask: .command, target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Bottom Area"), cmd: "cm_BottomArea",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Preview Panel"), cmd: "cm_PreviewPanel",
                                 key: "p", mask: [.command, .shift], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Horizontal Panels"), cmd: "cm_HorizontalPanels",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Button Bar"), cmd: "cm_ButtonBar",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Vertical Button Bar"), cmd: "cm_VerticalButtonBar",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(.separator())
        viewMenu.addItem(command(String(localized: "New Tab"), cmd: "cm_OpenNewTab",
                                 key: "t", mask: .command, target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "New Tab in Background"), cmd: "cm_OpenNewTabBg",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Open Folder in New Tab"), cmd: "cm_OpenDirUnderCursorInNewTab",
                                 key: "t", mask: [.command, .shift], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Close Tab"), cmd: "cm_CloseCurrentTab",
                                 key: "w", mask: .command, target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Close All Tabs"), cmd: "cm_CloseAllTabs",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Next Tab"), cmd: "cm_NextTab",
                                 key: "}", mask: .command, target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Previous Tab"), cmd: "cm_PrevTab",
                                 key: "{", mask: .command, target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Lock Tab"), cmd: "cm_LockTab",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(.separator())
        // View modes (TODOS #58). Full/Brief/Icons/Thumbnails switch the active panel
        // directly; Tree toggles the folder-tree column (F-015).
        viewMenu.addItem(command(String(localized: "Full (Details)"), cmd: "cm_SrcLong",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Brief (Columns)"), cmd: "cm_SrcShort",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Icons"), cmd: "cm_SrcIcons",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Thumbnails (Gallery)"), cmd: "cm_SrcThumbs",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Tree"), cmd: "cm_SrcTree",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Shared Tree"), cmd: "cm_TreeShared",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(command(String(localized: "Reset Layout"), cmd: "cm_ResetLayout",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(.separator())
        viewMenu.addItem(command(String(localized: "Cycle View Mode"), cmd: "cm_CycleViewMode",
                                 key: "m", mask: [.command, .shift], target: target, action: commandAction))
        // Sort submenu (I02) — disabled until sort commands are registered.
        let sortItem = NSMenuItem(title: String(localized: "Sort By"), action: nil, keyEquivalent: "")
        let sortMenu = NSMenu(title: String(localized: "Sort By"))
        sortItem.submenu = sortMenu
        sortMenu.addItem(command(String(localized: "Name"), cmd: "cm_SrcByName",
                                 key: "", mask: [], target: target, action: commandAction))
        sortMenu.addItem(command(String(localized: "Extension"), cmd: "cm_SrcByExt",
                                 key: "", mask: [], target: target, action: commandAction))
        sortMenu.addItem(command(String(localized: "Size"), cmd: "cm_SrcBySize",
                                 key: "", mask: [], target: target, action: commandAction))
        sortMenu.addItem(command(String(localized: "Date"), cmd: "cm_SrcByDateTime",
                                 key: "", mask: [], target: target, action: commandAction))
        sortMenu.addItem(command(String(localized: "Unsorted"), cmd: "cm_SrcUnsorted",
                                 key: "", mask: [], target: target, action: commandAction))
        viewMenu.addItem(sortItem)
        viewMenu.addItem(command(String(localized: "Refresh"), cmd: "cm_RereadSource",
                                 key: "r", mask: .command, target: target, action: commandAction))

        // ── Terminal ────────────────────────────────────────────────────────────────────────────
        //
        // Its own menu, because the alternative was worse and was tried: the terminal's commands sat
        // in View, wedged between "Tree" and "Reset Layout", under a heading called "Bottom Dock" that
        // said nothing about a terminal to anyone who had not built one. A feature people look for by
        // name should be findable by name.
        //
        // Names spelled out rather than shortened. "Switch Between Panel and Terminal" is long for a
        // menu item and it is exactly what the command does — including that pressing it again comes
        // back, which "Go to Terminal" would have promised falsely.
        let terminalItem = NSMenuItem()
        main.addItem(terminalItem)
        let terminalMenu = NSMenu(title: String(localized: "Terminal"))
        terminalItem.submenu = terminalMenu
        // No accelerator set here: it is bound by key *position* in the keymap (F-381), and
        // KeymapMenu draws it onto this item from there like every other remappable command.
        terminalMenu.addItem(command(String(localized: "Switch Between Panel and Terminal"),
                                     cmd: "cm_TerminalFocus",
                                     key: "", mask: [], target: target, action: commandAction))
        terminalMenu.addItem(.separator())
        terminalMenu.addItem(command(String(localized: "New Terminal Tab"), cmd: "cm_TerminalNewTab",
                                     key: "", mask: [], target: target, action: commandAction))
        terminalMenu.addItem(command(String(localized: "Split the Terminal"), cmd: "cm_TerminalSplit",
                                     key: "", mask: [], target: target, action: commandAction))
        terminalMenu.addItem(.separator())
        terminalMenu.addItem(command(String(localized: "Go to the Panel's Folder"),
                                     cmd: "cm_TerminalCdHere",
                                     key: "", mask: [], target: target, action: commandAction))
        terminalMenu.addItem(command(String(localized: "Insert the Selected File Names"),
                                     cmd: "cm_TerminalSendNames",
                                     key: "", mask: [], target: target, action: commandAction))
        terminalMenu.addItem(.separator())
        terminalMenu.addItem(command(String(localized: "Run the Command Line in the Terminal"),
                                     cmd: "cm_TerminalRunCommandLine",
                                     key: "", mask: [], target: target, action: commandAction))

        let windowItem = windowMenuItem()
        let helpItem = helpMenuItem(target: target, commandAction: commandAction)
        // Reorder the top-level bar to the Total Commander menu order (F-251):
        // File · Edit · Mark · Commands · Net · Go · Show(View) · Terminal · Configuration · Start,
        // plus the macOS-standard Window/Help. (Menus are built above in a different
        // order; only their final placement changes here.)
        //
        // Terminal sits after View because that is where the eye goes looking for it — it is about
        // what the window shows — and before Configuration, which is where settings live rather than
        // things you do.
        let ordered = [appItem, fileItem, editItem, markItem, cmdItem, netItem,
                       goItem, viewItem, terminalItem, configItem, startItem, windowItem, helpItem]
        main.removeAllItems()
        for item in ordered { main.addItem(item) }
        return main
    }

    /// Build the main bar from user-supplied command menus (a `.mnu`, F-257): the
    /// standard App and Edit menus, then the given command menus, then the standard
    /// Window and Help menus. Keeps the AppKit essentials (About/Quit, Undo/Copy/
    /// Paste, window list) working while the middle of the bar is data-driven.
    static func build(target: AnyObject, commandAction: Selector, commandMenus: [NSMenu]) -> NSMenu {
        let main = NSMenu()
        main.addItem(appMenuItem(target: target, commandAction: commandAction))
        let editItem = NSMenuItem()
        editItem.submenu = standardEditMenu()
        main.addItem(editItem)
        for menu in commandMenus {
            let item = NSMenuItem()
            item.submenu = menu
            main.addItem(item)
        }
        main.addItem(windowMenuItem())
        main.addItem(helpMenuItem(target: target, commandAction: commandAction))
        return main
    }

    // MARK: - Minimal per-window (tool) menu bar (TODOS)

    /// Build a MINIMAL menu bar for a tool window (viewer/editor/compare/…): the
    /// application menu, a standard Edit menu, the window's own content menu, then
    /// the standard Window and Help menus — without the panel-operation menus.
    static func buildTool(editMenu: NSMenu, contentMenu: NSMenu,
                          target: AnyObject, commandAction: Selector) -> NSMenu {
        buildTool(menus: [editMenu, contentMenu], target: target, commandAction: commandAction)
    }

    /// Build a minimal tool-window bar from an ordered list of the window's own
    /// menus (e.g. File/Edit/View/Search), framed by the App menu and the
    /// standard Window/Help menus.
    static func buildTool(menus: [NSMenu], target: AnyObject, commandAction: Selector) -> NSMenu {
        let main = NSMenu()
        main.addItem(appMenuItem(target: target, commandAction: commandAction))
        for menu in menus {
            let item = NSMenuItem()
            item.submenu = menu
            main.addItem(item)
        }
        main.addItem(windowMenuItem())
        main.addItem(helpMenuItem(target: target, commandAction: commandAction))
        return main
    }

    // MARK: - Reusable standard menus

    /// The application (bold, app-named) menu: About, Settings, Hide, Quit.
    static func appMenuItem(target: AnyObject, commandAction: Selector) -> NSMenuItem {
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(withTitle: String(localized: "About \(appName)"),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(command(String(localized: "Settings…"), cmd: "cm_Options",
                                key: ",", mask: .command, target: target, action: commandAction))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Hide \(appName)"),
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        let quit = appMenu.addItem(withTitle: String(localized: "Quit \(appName)"),
                                   action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = .command
        return appItem
    }

    /// Drop items that appear twice in the same submenu.
    ///
    /// macOS injects AutoFill, Start Dictation and Emoji & Symbols into any menu titled "Edit" when the
    /// bar is installed as the main menu — and this app installs a *cached* bar repeatedly (main window
    /// vs. tool windows), so the injections piled up: three "Emoji & Symbols" entries, two "Start
    /// Dictation…". The extra copies do not get their preferred shortcut either, and AppKit gave one of
    /// them the bare letter **E** — a menu shortcut with no modifier, which fires on any press of "e"
    /// outside a text field. Measured in a dump of the running menu bar (I19 T06).
    static func dropDuplicateItems(in menu: NSMenu) {
        for top in menu.items {
            guard let submenu = top.submenu else { continue }
            var seen = Set<String>()
            for item in submenu.items where !item.isSeparatorItem {
                let identity = item.title + "|" + (item.action.map { NSStringFromSelector($0) } ?? "")
                if !seen.insert(identity).inserted { submenu.removeItem(item) }
            }
        }
    }

    /// A standard Edit menu (Undo/Redo/Cut/Copy/Paste/Select All) routed through the
    /// responder chain — the default for tool windows that don't tailor their own.
    static func standardEditMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Edit"))
        func add(_ title: String, _ sel: Selector, _ key: String, _ mask: NSEvent.ModifierFlags = .command) {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            i.keyEquivalentModifierMask = mask
            menu.addItem(i)   // target nil → first responder
        }
        add(String(localized: "Undo"), Selector(("undo:")), "z")
        add(String(localized: "Redo"), Selector(("redo:")), "z", [.command, .shift])
        menu.addItem(.separator())
        add(String(localized: "Cut"), #selector(NSText.cut(_:)), "x")
        add(String(localized: "Copy"), #selector(NSText.copy(_:)), "c")
        add(String(localized: "Paste"), #selector(NSText.paste(_:)), "v")
        add(String(localized: "Select All"), #selector(NSText.selectAll(_:)), "a")
        menu.addItem(.separator())
        // Find, through the responder chain rather than as a command of ours (F-381).
        //
        // Whatever is focused and knows how to search answers it: SwiftTerm's terminal view opens its
        // own find bar over the scrollback, a text view uses the system find. Nothing of ours is
        // involved, which is why the scrollback became searchable without a line of search code —
        // and why the item disables itself when the focused thing cannot search.
        //
        // ⌘F was free: the app binds ⌘⇧F to Find Files, and Ctrl+F / Ctrl+Shift+F to the FTP
        // commands, so this takes nothing away.
        let find = NSMenuItem(title: String(localized: "Find…"),
                              action: Selector(("performFindPanelAction:")),
                              keyEquivalent: "f")
        find.keyEquivalentModifierMask = .command
        find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        menu.addItem(find)
        let findNext = NSMenuItem(title: String(localized: "Find Next"),
                                  action: Selector(("performFindPanelAction:")),
                                  keyEquivalent: "g")
        findNext.keyEquivalentModifierMask = .command
        findNext.tag = Int(NSFindPanelAction.next.rawValue)
        menu.addItem(findNext)
        let findPrev = NSMenuItem(title: String(localized: "Find Previous"),
                                  action: Selector(("performFindPanelAction:")),
                                  keyEquivalent: "g")
        findPrev.keyEquivalentModifierMask = [.command, .shift]
        findPrev.tag = Int(NSFindPanelAction.previous.rawValue)
        menu.addItem(findPrev)
        return menu
    }

    /// Convenience for tool windows building a tailored Edit menu: appends an item
    /// with an explicit target (nil = responder chain).
    static func editItem(_ menu: NSMenu, _ title: String, action: Selector, target: AnyObject?,
                         key: String = "", mask: NSEvent.ModifierFlags = .command,
                         representedObject: Any? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if !key.isEmpty { item.keyEquivalentModifierMask = mask }
        item.target = target
        item.representedObject = representedObject
        menu.addItem(item)
    }

    /// The standard Window menu (Minimize/Zoom + the app's window list). The caller
    /// should set `NSApp.windowsMenu` to this menu's submenu so AppKit fills in the
    /// window list.
    static func windowMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "Window"))
        item.submenu = menu
        let minimize = menu.addItem(withTitle: String(localized: "Minimize"),
                                    action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        minimize.keyEquivalentModifierMask = .command
        menu.addItem(withTitle: String(localized: "Zoom"),
                     action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Bring All to Front"),
                     action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        return item
    }

    /// The standard Help menu with a version line. Set `NSApp.helpMenu` to the submenu.
    static func helpMenuItem(target: AnyObject, commandAction: Selector) -> NSMenuItem {
        let item = NSMenuItem()
        let appName = ProcessInfo.processInfo.processName
        let menu = NSMenu(title: String(localized: "Help"))
        item.submenu = menu
        let help = menu.addItem(withTitle: String(localized: "\(appName) Help"),
                                action: #selector(NSApplication.showHelp(_:)), keyEquivalent: "?")
        help.keyEquivalentModifierMask = .command
        menu.addItem(.separator())
        menu.addItem(command(String(localized: "Open Source & Third-Party Software…"),
                             cmd: "cm_OpenSourceNotices", key: "", mask: [],
                             target: target, action: commandAction))
        menu.addItem(.separator())
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let build = (info?["CFBundleVersion"] as? String) ?? ""
        let versionText = build.isEmpty ? String(localized: "Version \(version)")
                                        : String(localized: "Version \(version) (\(build))")
        let versionItem = menu.addItem(withTitle: versionText, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        return item
    }

    private static func command(_ title: String,
                                cmd: String,
                                key: String,
                                mask: NSEvent.ModifierFlags,
                                target: AnyObject,
                                action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if !key.isEmpty { item.keyEquivalentModifierMask = mask }
        item.representedObject = cmd
        item.target = target
        return item
    }

}

/// A tool window (viewer, editor, compare, …) that supplies its own menu-bar menu,
/// shown only while that window is key so the main window isn't cluttered with
/// tool-specific menus (TODOS #189).
@MainActor
protocol WindowContextMenuProviding: AnyObject {
    /// Build the menu to show in the bar's contextual slot while this window is key.
    /// Items should target the controller itself so its actions fire directly.
    func makeWindowMenu() -> NSMenu
    /// Build the Edit menu appropriate for this window's content (Copy/Paste/Find/…).
    /// Defaults to the standard responder-chain Edit menu.
    func makeEditMenu() -> NSMenu
    /// The ordered list of the window's own menus, shown between the App menu and
    /// the standard Window/Help menus. Defaults to `[Edit, content]` for windows
    /// that don't opt into the richer document taxonomy (File/Edit/View/Search).
    func toolMenus() -> [NSMenu]
}

extension WindowContextMenuProviding {
    func makeEditMenu() -> NSMenu { AppMenu.standardEditMenu() }
    /// Default content menu is empty; windows either implement this (simple path)
    /// or override `toolMenus()` for the richer File/Edit/View/Search taxonomy.
    func makeWindowMenu() -> NSMenu { NSMenu() }
    func toolMenus() -> [NSMenu] { [makeEditMenu(), makeWindowMenu()] }
}
