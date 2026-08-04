# Peach Commander — feature overview

_Generated from `docs/metadata/features.yml` by `docs/scripts/gen-overviews.py`. Do not edit by hand._

**87 features** across 14 categories. AI ships as an optional, removable plugin (on-device Apple Intelligence, optional cloud model). Auto-update (Sparkle) is planned but not yet integrated.

## Navigation

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Dual-pane layout | user | Tab (switch) | ✅ |
| Editable breadcrumb path bar | user | — | ✅ |
| Favorites / directory hotlist | user | Ctrl+D | ✅ |
| Navigation (open, up, history) | user | Enter, Ctrl+PageUp/Down, Alt+Left/Right, Backspace | ✅ |
| Panels notice outside changes | user | — | ✅ |
| Special "go to" directories | user | Cmd+Shift+H | ✅ |
| Swap panels / target = source | expert | Ctrl+U, Ctrl+Shift+U, Ctrl+= | ✅ |

## Panels

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Columns | user, expert | — | ✅ |
| Drive bar | user | — | ✅ |
| Per-panel tabs | user | Cmd+T, Cmd+W, Cmd+}, Cmd+{ | ✅ |
| Quick search & quick filter | user | Ctrl+S (filter) | ✅ |
| Selection / marking | user | Insert, Num+, Num-, Num*, Cmd+A | ✅ |
| Show hidden files | user | Ctrl+H | ✅ |
| Sorting (incl. natural sort) | user | — | ✅ |
| View modes (details/brief/icons/gallery/tree) | user | Cmd+Shift+M, Ctrl+F1, Ctrl+F2, Ctrl+F8 | ✅ |

## File operations

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Background transfer manager | user | Cmd+Shift+B | ✅ |
| Calculate occupied space | user | Ctrl+L | ✅ |
| Change attributes & ACL | expert | — | ✅ |
| Compare & synchronize | expert | — | ✅ |
| Copying files | user | F5 | ✅ |
| Create/verify checksums | expert | — | ✅ |
| Delete (Trash / permanent) | user | F8, Shift+F8 | ✅ |
| Encode / decode | expert | — | ✅ |
| Find duplicate files | expert | — | ✅ |
| Links, aliases & comments | expert | — | ✅ |
| Move / rename | user | F6, Shift+F6 | ✅ |
| Multi-rename tool | expert | Ctrl+M | ✅ |
| New folder / new file | user | F7, Shift+F4 | ✅ |
| Overwrite conflict handling | user | — | ✅ |
| Split / combine files | expert | — | ✅ |

## Archives

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Browse archives as folders | user | — | ✅ |
| Extract / unpack | user | Alt+F9 | ✅ |
| In-place zip edit | expert | — | ✅ |
| Pack (create archive) | user | Alt+F5 | ✅ |

## Search

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Find files | user, expert | Cmd+Shift+F | ✅ |
| Search text provided by plugins | expert | Alt+F7 | ✅ |

## Network & remote

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Attributes on remote servers | expert | — | ✅ |
| Download from URL | user | Cmd+Shift+D | ✅ |
| FTP / FTPS | user, expert | Ctrl+F, Ctrl+N | ✅ |
| FTP console & protocol log | expert | — | ✅ |
| Mount network share | user | Cmd+K | ✅ |
| SFTP / SCP | user, expert | — | ✅ |

## Viewers & editors

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Editor saves as administrator | expert | Cmd+S | ✅ |
| Info page in the side panel | user | — | ✅ |
| Line numbers in the editor | user, expert | — | ✅ |
| Lister / file viewer | user | F3 | ✅ |
| Quick View & Quick Look | user | Ctrl+Q, Cmd+Y | ✅ |
| Syntax highlighting | user, developer | — | ✅ |
| Text/code editor & hex editor | user, expert | F4 | ✅ |

## Customization

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Accessibility for hand-drawn controls | user | — | ✅ |
| Add programs to the button bar by dropping them on it | user | — | ✅ |
| Appearance (light/dark, colors, font) | user | — | ✅ |
| AppleScript | user, developer | — | ✅ |
| Button bar (toolbar) | user, expert | — | ✅ |
| Color themes (incl. Norton Commander) | user | — | ✅ |
| Command system & browser | expert | — | ✅ |
| Full keyboard operation | user, expert | — | ✅ |
| Keyboard shortcuts & schemes | user, expert | — | ✅ |
| Shortcut audit | expert | — | ✅ |
| Start menu & user commands | expert | — | ✅ |
| The app's own windows follow the colour theme | user | — | ✅ |
| User-supplied color themes (themes/*.ini) | user, expert | — | ✅ |
| Workspaces | expert | Cmd+Ctrl+S | ✅ |
| macOS integration | user | — | ✅ |

## Settings

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Configuration & -ConfigRoot | developer, expert | — | ✅ |
| Decompiler plugin settings page | user, expert | — | ✅ |
| Import wincmd.ini | expert | — | ✅ |
| Settings (15 pages) | user, expert | Cmd+, | ✅ |

## Plugins

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| .NET decompiler plugin (F3 on an assembly) | user, expert | Cmd+Shift+N | ✅ |
| AI assistant | user | — | ✅ |
| Decompiled sources in a file panel | user, expert | Cmd+Shift+J | ✅ |
| Disk Map | user | — | ✅ |
| Java decompiler plugin (F3 on a .class file) | user, expert | — | ✅ |
| Plugin ABIs | plugin, sdk | — | ✅ |
| Plugin architecture | developer, plugin | — | ✅ |
| Plugin views follow the colour theme | user, plugin, sdk | — | ✅ |
| Plugins (user view) | user | — | ✅ |

## SDK

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| PluginSDK package | sdk, plugin | — | ✅ |

## Developer

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Architecture & modules | developer | — | ✅ |
| Automation (-AutomationScript) | developer | — | ✅ |
| Build system & onboarding | developer | — | ✅ |
| Layout free of Auto Layout conflicts | internal | — | ✅ |
| Localization (en/de) | developer, plugin | — | ✅ |
| Security & permissions | developer, user | — | ✅ |
| Testing strategy | developer | — | ✅ |

## Distribution

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| Distribution & updates | developer | — | 🅱️ |

## Archives

| Feature | Audiences | Shortcut(s) | Status |
|---|---|---|---|
| ZIP64 archives | user, expert | — | ✅ |
