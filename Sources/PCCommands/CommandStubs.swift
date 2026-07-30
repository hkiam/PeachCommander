// SPDX-License-Identifier: Apache-2.0
// CommandStubs.swift - Not-yet-implemented command placeholders (I13 T01).
//
// Every TC command referenced by a menu item or a shipped keyboard scheme must
// exist in the registry so the UI can display/route it consistently. Features not
// yet built are registered here as placeholders with `implemented: false`: the UI
// auto-disables them, and invoking one directly (e.g. from the command line)
// reports "not yet implemented" via the window controller. As each feature lands
// in its iteration, its real PCCommand replaces the stub entry below.

import Foundation

extension CommandRegistry {
    /// Register all not-yet-implemented placeholder commands.
    func registerStubCommands() {
        var id = 50000
        for (name, help) in Self.stubCommandList {
            let commandName = name
            register(PCCommand(id: id, name: name, category: "Pending", help: help,
                               implemented: false,
                               handler: { ctx in ctx.windowController?.showNotImplemented(commandName) }))
            id += 1
        }
    }

    /// (name, help) for every placeholder command. Ordered for a stable id dump.
    static let stubCommandList: [(String, String)] = [
        ("cm_ActivateMenu", "Focus the menu bar (F9)"),
        ("cm_AddPathToCmdline", "Copy path into the command line (Ctrl+P)"),
        ("cm_ChangeTransferMode", "FTP transfer mode"),
        ("cm_ContextMenu", "Show the context menu (Shift+F10)"),
        ("cm_CopySamepanel", "Copy in the same directory (Shift+F5)"),
        ("cm_DirectoryTreeDlg", "Directory tree dialog (Alt+F10)"),
        ("cm_Exit", "Quit the application"),
        ("cm_FocusCmdLine", "Run command line / focus it"),
        ("cm_FtpHiddenFiles", "Toggle showing hidden files on FTP"),
        ("cm_HelpIndex", "Help (F1)"),
        ("cm_LeftOpenDrives", "Open the left volume dropdown (Alt+F1)"),
        ("cm_ListExternal", "Open in the alternate viewer (Alt+F3)"),
        ("cm_ListOnly", "View the cursor file ignoring the selection (Shift+F3)"),
        ("cm_MovePackFiles", "Pack and delete originals (Alt+Shift+F5)"),
        ("cm_NetworkGeneral", "System information"),
        ("cm_PrintFile", "Print the file (Ctrl+F9)"),
        ("cm_RightOpenDrives", "Open the right volume dropdown (Alt+F2)"),
        ("cm_SrcAllFiles", "Show all files (Ctrl+F10)"),
        ("cm_SrcByDateTime", "Sort by date/time (Ctrl+F6)"),
        ("cm_SrcByExt", "Sort by extension (Ctrl+F4)"),
        ("cm_SrcByName", "Sort by name (Ctrl+F3)"),
        ("cm_SrcBySize", "Sort by size (Ctrl+F5)"),
        ("cm_SrcExeFiles", "Show programs only (Ctrl+F11)"),
        ("cm_SrcUnsorted", "Unsorted"),
        ("cm_SrcUserSpec", "Custom file-type filter (Ctrl+F12)"),
        ("cm_VolumeName", "Set the volume label"),
    ]
}
