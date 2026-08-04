# Keyboard Shortcuts — Complete Map

Two shipped schemes (F-254):
- **TC Classic** (default): preserves TC keys 1:1 where macOS allows; `Ctrl` stays
  `Ctrl` (⌃). This is what TC users' muscle memory expects.
- **macOS Native**: same commands on ⌘ where idiomatic (⌘C copy files, ⌘F search…).

Below: TC key -> command (cm_ name) -> notes. Implement via PCCommands key map files
(`Resources/keymap-tc-classic.ini`, `keymap-macos.ini`). F-keys require "Use F1, F2…
as standard function keys" hint in onboarding, or users press Fn.

## Function keys

| Key | Command | Action |
|---|---|---|
| F1 | cm_HelpIndex | Help |
| F2 | cm_RereadSource | Refresh active panel (also Ctrl+R) |
| F3 | cm_List | View file (Lister) |
| F4 | cm_Edit | Edit file |
| F5 | cm_Copy | Copy selection to other panel |
| F6 | cm_RenMov | Move/rename to other panel |
| F7 | cm_MkDir | New directory |
| F8 / Del | cm_Delete | Delete (to Trash) |
| F9 | cm_ActivateMenu | Focus menu bar |
| Alt+F1 / Alt+F2 | cm_LeftOpenDrives / cm_RightOpenDrives | Volume dropdown left/right |
| Alt+F3 | cm_ListExternal | Alternate viewer |
| Alt+F4 | cm_Exit | Quit (macOS: also ⌘Q) |
| Alt+F5 | cm_PackFiles | Pack |
| Alt+Shift+F5 | cm_MovePackFiles | Pack & delete originals |
| Alt+F7 | cm_SearchFor | Find files |
| Alt+F9 | cm_UnpackFiles | Unpack |
| Alt+F10 | cm_DirectoryTreeDlg | Tree dialog of current drive |
| Shift+F2 | cm_CompareDirs | Compare directories (mark differing) |
| Shift+F3 | cm_ListOnly | View file under cursor (ignore selection) |
| Shift+F4 | cm_EditNewFile | Create new text file & edit |
| Shift+F5 | cm_CopySamepanel | Copy in same dir (rename copy) |
| Shift+F6 | cm_RenameOnly | Rename in place (inline editor) |
| Shift+F8 | cm_DeleteReal | Delete bypassing Trash |
| Shift+F10 | cm_ContextMenu | Context menu for selection |
| Ctrl+F3..F6 | cm_SrcByName/Ext/Size/DateTime | Sort by name/ext/size/date (macOS scheme: Alt+Cmd+1..4 — see the note below) |
| Ctrl+F1 / Ctrl+F2 | cm_SrcShort / cm_SrcLong | Brief / Full view (macOS scheme: Cmd+1 / Cmd+2) |
| Ctrl+Shift+F1 | cm_SrcThumbs | Thumbnail view |
| Ctrl+F8 | cm_SrcTree | Tree view in panel (macOS scheme: Cmd+3) |
| Ctrl+F9 / Ctrl+Shift+F9 | cm_PrintFile / cm_PrintFileList | Print |
| Ctrl+F10..F12 | cm_SrcAllFiles / cm_SrcExeFiles / cm_SrcUserSpec | File type filter presets |

> **Ctrl+F1…F8 belongs to macOS.** That whole row drives Full Keyboard Access — focusing the menu bar,
> the Dock, the toolbar — and it is switched on precisely by people who work without a mouse, so those
> shortcuts never reach the app for them. The TC Classic scheme keeps them because they are Total
> Commander's, and the **macOS** scheme uses Cmd+1/2/3 for the view modes and Alt+Cmd+1…4 for sorting
> instead. `Tools/check-hotkeys.py` holds this: the exceptions are listed there with their reasons.

## Ctrl combos (⌃ in TC Classic, most also on ⌘ in macOS Native)

| Key | Command | Action |
|---|---|---|
| Ctrl+A | cm_SelectAll | Select all |
| Ctrl+B | cm_DirBranch | Branch view (flatten subdirs) |
| Ctrl+Shift+B | cm_DirBranchSel | Branch view of selected |
| Ctrl+C / X / V | cm_CopyToClipboard / cm_CutToClipboard / cm_PasteFromClipboard | Clipboard file ops |
| Ctrl+D | cm_DirectoryHotlist | Hotlist popup |
| Ctrl+F | cm_FtpConnect | FTP connection manager |
| Ctrl+Shift+F | cm_FtpDisconnect | Disconnect |
| Ctrl+N | cm_FtpNew | New FTP/URL connection |
| Ctrl+I | cm_SwitchToTargetPanel | Focus other panel (like Tab) |
| Ctrl+L | cm_CalcSpace | Occupied space of selection |
| Ctrl+M | cm_MultiRenameFiles | Multi-rename tool |
| Ctrl+Shift+M | cm_ChangeTransferMode | FTP transfer mode |
| Ctrl+P | cm_AddPathToCmdline | Copy path into command line |
| Ctrl+Q | cm_SrcQuickview | Quick View panel |
| Ctrl+R | cm_RereadSource | Refresh |
| Ctrl+S | cm_QuickFilter | Quick filter (visible files) |
| Ctrl+T | cm_OpenNewTab | New tab |
| Ctrl+Shift+T | cm_OpenNewTabBg | New tab in background |
| Ctrl+W / Ctrl+F4 | cm_CloseCurrentTab | Close tab |
| Ctrl+Shift+W | cm_CloseAllTabs | Close all tabs |
| Ctrl+Tab / Ctrl+Shift+Tab | cm_NextTab / cm_PrevTab | Cycle tabs |
| Ctrl+U | cm_Exchange | Swap panels |
| Ctrl+Shift+U | cm_ExchangeWithTabs | Swap panels incl. tabs |
| Ctrl+Z | cm_EditComment | Edit file comment |
| Ctrl+Enter | (cmdline) | Append name under cursor to command line |
| Ctrl+Shift+Enter | (cmdline) | Append full path to command line |
| Ctrl+PgDn | cm_OpenDirUnderCursor | Enter dir/archive under cursor |
| Ctrl+PgUp | cm_GoToParent | Parent directory |
| Ctrl+\\ | cm_GoToRoot | Root of volume |
| Ctrl+Left/Right | cm_TransferLeft/Right | Open item under cursor in other panel |
| Ctrl+Up/Down | cm_OpenDirUnderCursorInNewTab (Up=other panel) | Item in new tab |
| Ctrl+Home/End | (list) | First/last entry |

## Navigation & selection basics

| Key | Action |
|---|---|
| Tab | Switch active panel |
| Enter | Open/execute under cursor; run command line if non-empty & focused |
| Backspace | Parent directory |
| Insert | Toggle selection, move down |
| Space | Toggle selection (+ calc dir size) |
| Num+ / Num- / Num* | Select / unselect by mask / invert selection |
| Ctrl+Num+ / Ctrl+Num- | Select all / none |
| Alt+Num+ | Select all with same extension |
| Num / | Restore previous selection |
| Shift+Arrows/PgUp/PgDn/Home/End | Range select (Windows-style option) |
| Alt+Left / Alt+Right | History back / forward |
| Alt+Down | History list dropdown |
| Alt+Enter | Info/properties dialog (macOS: Get Info-like own dialog) |
| Alt+Shift+Enter | Calculate all dir sizes in view |
| Letter keys | Command line (default) / quick search per config; Ctrl+Alt+Letter = quick search (TC default) |
| Esc | Cancel dialog / clear command line / close Quick View |

## macOS-reserved conflicts (handle in keymap)

| TC key | Conflict | Resolution (TC Classic scheme) |
|---|---|---|
| Ctrl+Left/Right/Up/Down | Mission Control/Spaces | Detect & offer remap hint; alt: Ctrl+Shift+arrows |
| F11/F12 | Show Desktop / volume | Use in-app when app focused w/ Fn, else remapped |
| Alt+F4 | n/a on macOS | Also ⌘Q |
| Cmd keys in TC Classic | none used by TC | Standard macOS bindings (⌘Q ⌘, ⌘H ⌘M ⌘W window) remain active |

Full command list with ids: see `menus-and-commands.md`. Keymap file format: SPEC-014 §5.
