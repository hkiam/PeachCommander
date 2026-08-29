# Menus & Internal Command Registry

## 1. Main menu tree (TC order, macOS menu bar)

Items marked (I nn) get enabled in that iteration; build the full tree in I13 with
disabled placeholders so the structure is visible early.

```
Peach Commander  (macOS standard)
  About Peach Commander | Check for Updates… (I20) | Settings… ⌘, (I05) | Quit ⌘Q

Files
  Change Attributes… (I17)
  Pack… Alt+F5 (I09) | Unpack… Alt+F9 (I09) | Test Archive (I09)
  Compare by Content… (I12)
  Associate With… (I07, internal associations)
  Internal Associations… (I07)
  Calculate Occupied Space… Ctrl+L (I17)
  Multi-Rename Tool… Ctrl+M (I11)
  Edit Comment… Ctrl+Z (I17)
  Print > File List / File List to File / File (I17)
  Split File… / Combine Files… (I17)
  Encode (MIME/UUE/XXE)… / Decode… (I17)
  Create Checksums… / Verify Checksums… (I17)
  Properties Alt+Enter (I03)
  Quit (macOS: in app menu)

Mark
  Select Group… Num+ | Unselect Group… Num- | Select All Ctrl+Num+ |
  Unselect All Ctrl+Num- | Invert Selection Num* | Restore Selection Num/
  Select All with Same Extension Alt+Num+ (all I03)
  Compare Directories Shift+F2 (I12) | Mark Newer, Hide Same (I12)
  Copy Names to Clipboard / Copy Full Names / Copy Details… (I13)

Commands
  CD Tree… Alt+F10 (I17) | Search… Alt+F7 (I10)
  Volume Label… (I17) | System Information… (I17)
  Synchronize Dirs… (I12) | Compare Dirs (I12)
  Open Terminal Here (I18)
  Open Desktop Folder / Home / Downloads … (I06)
  Directory Hotlist Ctrl+D (I06)
  Go Back Alt+Left / Forward Alt+Right / History Alt+Down (I06)
  Branch View Ctrl+B (I17)
  Run Command Line… (I06)

Net
  FTP Connect… Ctrl+F (I15) | FTP New Connection… Ctrl+N (I15)
  FTP Disconnect (I15) | FTP Show Hidden Files (I15)
  FTP Download From List… (I15) | FTP Transfer Mode (I15)
  Network Neighborhood -> Mount Network Share… (I18)
  PORT Connection to Other PC -> n/a-macos (hidden)

Show
  Brief Ctrl+F1 | Full Ctrl+F2 | Comments (I17) | Thumbnails Ctrl+Shift+F1 (I17)
  Tree Ctrl+F8 (I17) | Quick View Ctrl+Q (I07)
  Vertical Arrangement (I05)
  All Files Ctrl+F10 | Programs Ctrl+F11 | Custom Ctrl+F12 (I06 filters)
  Only Selected Files (I06)
  Sort submenu: by Name/Ext/Size/Date/Unsorted, Reversed (I02)
  Custom Columns submenu (I16)
  Refresh F2/Ctrl+R (I02)

Configuration
  Options… (I05, == Settings)
  Customize Toolbar… (I13)
  Change Start Menu… (I13)
  Change Main Menu… (I19)
  Command Browser… (I13)
  Macro from Recent Actions… | Manage Macros… | Edit Macros… (F-478)
  Save Position (I05) | Save Settings (I05)

Start  (user menu, I13)
  user-defined em_ commands; Change Start Menu… opens editor

Window (macOS standard) | Help (F1 -> bundled help, link to docs)
```

## 2. Command registry (cm_*)

Design (SPEC-014): central `CommandRegistry` in PCCommands. Every command:

```swift
struct PCCommand {
  let id: Int          // stable numeric id, TC-compatible where known
  let name: String     // "cm_Copy"
  let category: String // "File operations"
  let help: String     // one-liner shown in command browser & tooltips
  let handler: CommandHandler // executed with CommandContext (panels, selection)
}
```

Rules:
- Names and numeric ids copied from TC's TOTALCMD.INC where a 1:1 command exists
  (fetch reference: https://www.ghisler.ch/wiki/index.php/List_of_Internal_Commands
  when implementing I13). Our own commands use ids >= 20000 and prefix `cm_Pc`.
- `em_` prefix = user-defined commands from usercmd.ini analog (SPEC-014 §4).
- Everything invocable: menu items, toolbar buttons, F-key bar, keymap, command
  line (`cm_CopyNamesToClip` typed directly works — TC behavior), AppleScript later.
- Parameters for user commands / buttons (SPEC-014 §4): `%P` source path, `%N` name
  under cursor, `%T` target path, `%M` target name, `%S` selected names list,
  `%L/%F/%D/%W` list-file variants, `%%` literal. Quoting rules per TC help.

## 3. Command line semantics (SPEC-001 §5)

- Non-empty command line + Enter: execute as shell command in current dir
  (`/bin/zsh -lc`), output window option; `cd <path>` navigates panel instead.
- `cm_*` / `em_*` names execute commands. Leading `cd`, env expansion, `~`.
- Ctrl+Enter appends name under cursor; Ctrl+Shift+Enter full path (quoted).
- History dropdown persisted (Alt+F8 opens it in TC — support both).
