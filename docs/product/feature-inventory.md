# Feature Inventory — Total Commander Parity Catalog

Master checklist for feature parity. **Grep by ID (F-xxx), do not load the whole file.**

- **Prio:** P1 = core parity (must), P2 = full parity (should), P3 = optional/macOS extra.
- **Status:** `todo` | `in-progress` | `done` | `n/a-macos` (with rationale) | `post-1.0`.
- Update the Status column the moment a feature is implemented AND tested.
- Source references: TC feature list (ghisler.com/featurel.htm), TC 11 help, plugin
  SDKs (ghisler.github.io).

## 1. Main window & panels

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-001 | Dual fixed panels, vertical split, adjustable splitter (%) | Splitter draggable, double-click = 50% | SPEC-001 | I01 | P1 | done |
| F-002 | Horizontal panel arrangement option (above/below) | Menu: Show > Vertical arrangement; ev: cm_HorizontalPanels | SPEC-001 | I05 | P2 | done |
| F-003 | One active panel concept; inactive panel dimmed header | Active path bar highlighted | SPEC-001 | I01 | P1 | done |
| F-004 | Function key button bar (F3..F8) at bottom, clickable | Shows key labels + actions; Ctrl/Alt modifiers relabel | SPEC-001 | I01 | P1 | done |
| F-005 | Command line above function keys, always-type-to-cmdline option | Focus model per TC; ev: symbol:CommandLineView ev: symbol:onTypeToCommandLine | SPEC-001 | I06 | P1 | done |
| F-006 | Drive/volume button bar per panel + drive dropdown combo | macOS: volumes, incl. eject button; ev: symbol:DriveBarView ev: symbol:isEjectable | SPEC-001 | I02 | P1 | done |
| F-007 | Current path bar with click-to-segment navigation | TC: click = dropdown of parents | SPEC-001 | I02 | P1 | done |
| F-008 | Tabbed panels: new/close/lock tabs, drag-reorder, tab options | Ctrl+T/W, locked tabs with *; ev: cm_OpenNewTab ev: cm_LockTab ev: symbol:reorderTab | SPEC-001 | I06 | P1 | done |
| F-009 | Status bar per panel: "x of y files selected, n of m KB" | Exact TC wording | SPEC-003 | I03 | P1 | done |
| F-010 | Main button bar (toolbar) with user-definable buttons | Icons, tooltips, drag-to-add, .bar file format | SPEC-014 | I13 | P1 | done |
| F-011 | Vertical button bar option | Off by default; ev: cm_VerticalButtonBar | SPEC-014 | I13 | P3 | done |
| F-012 | Window title shows active path; option % free space etc. | path (tilde) + free space | SPEC-001 | I02 | P2 | done |
| F-013 | Full-screen & window state restore on launch | Panels, tabs, paths, sort restored | SPEC-013 | I05 | P1 | done |
| F-014 | Flat/da Vinci-free TC visual style: dense rows, classic colors, cursor bar | See ui-reference.md; theme file | SPEC-001 | I01 | P1 | done |
| F-015 | Separate trees / tree panel view (Ctrl+F8) | One tree per panel + shared-tree option; one tree per panel done; a shared tree across both panels is not built; ev: cm_SrcTree ev: scenario:tree-view | SPEC-016 | I17 | P2 | partial |

## 2. File listing & views

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-020 | Full view: name, ext, size, date, attr columns | TC column defaults; ext as own column | SPEC-002 | I01 | P1 | done |
| F-021 | Brief view (multi-column names only, Ctrl+F1) | Horizontal scrolling grid | SPEC-002 | I05 | P1 | done |
| F-022 | Thumbnail view with async thumbnails | QLThumbnailGenerator, cached | SPEC-002 | I17 | P2 | done |
| F-023 | Comments view / file comments (Ctrl+Z edits descript.ion) | descript.ion (incl. UTF-16 and TC's multi-line extension, F-374) + Finder comment sync; a comment follows the file through copy, move, rename and the undo of a rename (F-372), and the Notes plugin's sidebar shows and edits the same comment; ev: symbol:CommentStore ev: symbol:FinderComment ev: test:DescriptionFileTests ev: test:CommentCarryTests ev: scenario:comment-carry ev: scenario:notes-sidebar ev: scenario:find-comments ev: test:SearchCommentsTests ev: scenario:tc-descript ev: file:Tools/check-descript-format.sh; a note can also be bound to a *line* of a file rather than the file as a whole — the viewer asks the plugin which lines carry one, offers them in its marks panel and writes new ones for the line under the caret, all through the ordinary content-field and context mechanisms, so nothing in the viewer knows what a note is (F-379); ev: symbol:ContentFieldValues ev: test:ContentFieldValuesTests ev: scenario:viewer-note-lines ev: scenario:viewer-note-write; the AI assistant can read and write the same comment through `get_comment`/`set_comment`, gated like any other write — the plan it asks the user to approve quotes the words it wants to attach (F-380); ev: test:CommentToolsTests ev: scenario:tc-comment-sidebar | SPEC-016 | I17 | P2 | done |
| F-024 | Custom columns sets w/ content-plugin fields, per-view rules | Switchable sets, auto-switch by location; sets are stored per context (per side, and per mount as "mount:<qualifier>"); ev: symbol:ColumnSet ev: test:ColumnSetTests | SPEC-002+012 | I16 | P2 | done |
| F-025 | Sort by name/ext/size/date (Ctrl+F3..F6), reverse, as-columns-click | Stable sort; dirs first | SPEC-002 | I02 | P1 | done |
| F-026 | Natural/logical number sorting option + per-locale collation | TC: "alphabetical, like Explorer" choices; ev: symbol:naturalSort ev: test:PanelDateFormatterTests | SPEC-002 | I02 | P2 | done |
| F-027 | Directories always first; dirs sorted by name option | | SPEC-002 | I02 | P1 | done |
| F-028 | Show hidden/system files toggle (macOS: dotfiles + hidden flag) | Ctrl+H (TC 11) | SPEC-002 | I03 | P1 | done |
| F-029 | File icons: per-type, async load, EXE/app icons; icon off mode | NSWorkspace icon cache | SPEC-002 | I03 | P1 | done |
| F-030 | Size display: bytes/KB/dynamic; directory sizes on Space/Alt+Shift+Enter | Space calculates dir size under cursor | SPEC-002 | I03 | P1 | done |
| F-031 | Date format per system locale + custom format option | ev: test:PanelDateFormatterTests | SPEC-002 | I02 | P2 | done |
| F-032 | Row colors: by file type masks, alternating background, selection colors | Color config dialog; ev: symbol:TypeColorsWindowController ev: scenario:details-view | SPEC-013 | I05 | P2 | done |
| F-033 | Auto-refresh on FS changes (FSEvents), incl. size/date updates | TC: WatchDirs; coalesced | SPEC-002 | I04 | P1 | done |
| F-034 | Branch view (Ctrl+B): current dir + all subdirs flattened | Also selected-dirs variant Shift+Ctrl+B | SPEC-016 | I17 | P1 | done |
| F-035 | Filter field / quick filter (Ctrl+S) narrowing visible files | Live wildcard filter; ev: symbol:WildcardMask ev: test:WildcardMaskTests | SPEC-003 | I06 | P1 | done |
| F-036 | Symlink display (arrow overlay), follow/into behavior, show target | macOS aliases + symlinks + firmlinks; ev: symbol:symlinkTarget ev: symbol:resolveAlias | SPEC-002 | I03 | P1 | done |
| F-037 | Free/total disk space in header; occupied by selection (Ctrl+L) | | SPEC-016 | I17 | P2 | done |
| F-038 | File attributes column macOS-mapped (perms rwx, flags, xattr badge) | TC attr HRSA -> POSIX/BSD flags; ev: symbol:PosixPermissions ev: symbol:bsdFlags | SPEC-002 | I03 | P2 | done |

## 3. Navigation & selection

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-050 | Cursor navigation: arrows, Home/End, PgUp/PgDn; cursor ≠ selection | NC model | SPEC-003 | I02 | P1 | done |
| F-051 | Enter: open dir / launch file / enter archive; Ctrl+PgDn force-enter | Also for app bundles: enter as dir w/ modifier | SPEC-003 | I02 | P1 | done |
| F-052 | Backspace / Ctrl+PgUp: parent dir; cursor lands on dir we came from | Position memory per dir | SPEC-003 | I02 | P1 | done |
| F-053 | Tab switches active panel; Shift+Tab option | | SPEC-003 | I01 | P1 | done |
| F-054 | Insert: toggle select + advance; Space: toggle + dir size calc | | SPEC-003 | I03 | P1 | done |
| F-055 | Num+ / Num- / Num*: select/deselect/invert by wildcard dialog | Expand selection dialog w/ masks; the one mask matcher behind select-by-wildcard, the quick filter, the search's name masks, the sync filter and the type-colour rules translated a mask to a regex escaping only the dot, so every other metacharacter kept its regex meaning — a mask of "Bericht (2026).pdf" missed the file of that name and matched "Bericht 2026.pdf" instead, i.e. selected the wrong file; eight of twelve realistic cases were wrong. Only * and ? mean anything now; ev: symbol:WildcardMask ev: test:WildcardMaskTests | SPEC-003 | I03 | P1 | done |
| F-056 | Num / : restore selection before last operation | Selection history (1 level min) | SPEC-003 | I03 | P2 | done |
| F-057 | Ctrl+A select all; Ctrl+Num+ all; same-ext selection (Alt+Num+) | ev: symbol:WildcardMask ev: test:WildcardMaskTests | SPEC-003 | I03 | P1 | done |
| F-058 | Shift+arrows range select (Windows style option) | Left mouse selection mode option too | SPEC-003 | I03 | P2 | done |
| F-059 | Mouse: right-click select mode (NC style) vs left (Windows style) | Config option, default NC-right; ev: symbol:setMouseMode | SPEC-003 | I05 | P2 | done |
| F-060 | Quick search: type letters to jump (opts: with/without Ctrl+Alt, search dialog) | TC quick search modes incl. filter mode; ev: symbol:TypeAheadSearch ev: cm_QuickFilter | SPEC-003 | I06 | P1 | done |
| F-061 | Directory hotlist (Ctrl+D): add/remove/configure, submenus | hotlist.ini; menu with shortcuts 1..9; ev: cm_DirectoryHotlist ev: symbol:HotlistManagerWindowController | SPEC-003 | I06 | P1 | done |
| F-062 | History per panel (Alt+Down list; Alt+Left/Right back/forward) | Persisted across restart; ev: cm_HistoryList ev: cm_HistoryBack ev: symbol:NavigationHistory | SPEC-003 | I06 | P1 | done |
| F-063 | Ctrl+Left/Right: open item under cursor in other panel | Dir; else current folder | SPEC-003 | I06 | P1 | done |
| F-064 | Target=source (Ctrl+= / cm_CopyOtherPanel dir) ; swap panels Ctrl+U | Also Ctrl+Shift+U swap incl. tabs; ev: cm_TargetEqualSource ev: cm_ExchangeWithTabs | SPEC-003 | I06 | P1 | done |
| F-065 | Go to root (Ctrl+\\) ; go to home (~) | macOS: / and $HOME; ev: cm_GoToRoot ev: cm_GoToHome | SPEC-003 | I02 | P1 | done |
| F-066 | cd command in command line w/ env vars, ~, relative paths, UNC->smb | Autocomplete paths (Tab/Shift+Tab) | SPEC-001 | I06 | P1 | done |
| F-067 | Drag & drop: internal (copy/move w/ modifiers), to/from Finder, to buttons | Spring-loaded folders optional; ev: symbol:springLoadTimer ev: symbol:onDropFiles | SPEC-004 | I04/I13 | P1 | done |
| F-068 | "Open with" context menu + native macOS context menu merge | NSMenu services + our commands; ev: symbol:NSSharingServicePicker ev: cm_ContextMenu | SPEC-015 | I18 | P1 | done |

## 4. File operations

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-080 | F5 Copy with dialog: target path editable, wildcard rename, options | Queue checkbox, "only newer", tree copy; ev: symbol:promptTarget ev: symbol:splitTargetMask | SPEC-004 | I04 | P1 | done |
| F-081 | F6 Move (same dialog); Shift+F6 inline rename in panel | ev: cm_RenMov ev: symbol:beginInlineRename | SPEC-004 | I04 | P1 | done |
| F-082 | F7 MkDir: create nested paths `a/b/c` in one go, multiple via \| ".." used to create the folder outside the directory the panel is showing — invisible to the user, with the listing unchanged and nothing said; "." reported the parent back as newly created, and a whitespace-only entry reported success while creating nothing. All three refused now. A leading "/" still means "here", and a backslash is part of the name (it is a separator on Windows, not on macOS); ev: symbol:MkDirEngine ev: test:MkDirEngineTests | | SPEC-004 | I04 | P1 | done |
| F-083 | F8/Del delete: to Trash by default; Shift+F8 bypass Trash | Uses NSWorkspace recycle; permanent delete confirm | SPEC-004 | I04 | P1 | done |
| F-084 | Progress dialog: per-file + total %, speed, remaining, pause/resume/cancel | Speed-limit option (KB/s); ev: symbol:ProgressDialog ev: symbol:speedLimitKBps | SPEC-004 | I04 | P1 | done |
| F-085 | Background transfer manager (F5-F2 queue); multiple queues; sequential ops | TC background transfer manager window | SPEC-004 | I04 | P1 | done |
| F-086 | Overwrite dialog: overwrite/skip/rename/append, all-variants, compare, preview | Thumbnails + custom fields in dialog; ev: symbol:OverwriteResolver ev: scenario:keys-overwrite | SPEC-004 | I04 | P1 | done |
| F-087 | Copy preserves: dates, permissions, xattrs, resource forks, symlinks, ACLs opts | copyfile(3); options per config; checked against the system's own stat/xattr/ls -le rather than through the same Foundation layer the engine writes with: mode (including a restrictive 0600 that must not be widened), mtime, xattrs, resource fork, ACL, and symlinks copied as links — relative targets kept verbatim; verified by turning metadata copying off and watching five of them fail; ev: symbol:CopyEngine ev: test:CopyMetadataTests | SPEC-004 | I04 | P1 | done |
| F-088 | APFS clonefile instant copy on same volume (opt-out) | macOS bonus; falls back transparently; the clone fast path and the streaming path are checked against each other *and* against the source, so both cannot pass by having lost the same thing; clone bytes compared to the original; ev: test:CopyMetadataTests | SPEC-004 | I18 | P3 | done |
| F-089 | Error handling: retry/skip/skip-all/abort per file; error log window | Continue-on-error mode; per-item retry/skip/abort in CopyEngine and MoveEngine; ev: symbol:ErrorLogWindowController ev: symbol:resolveError | SPEC-004 | I04 | P1 | done |
| F-090 | Verify after copy option (checksum) | foreground copy; CRC-32; the setting used to apply to foreground copies only — with nothing saying so, while the background queue is what one picks for the large copies worth verifying; both now run it through one method, and a missing or unreadable target counts as a mismatch; ev: symbol:verifyCopiedItems ev: scenario:bg-copy-verify | SPEC-004 | I17 | P2 | done |
| F-091 | Copy/paste files via clipboard (Cmd+C/X/V interop with Finder) | TC Ctrl+C/X/V parity; ev: symbol:ClipboardState ev: cm_CopyNamesToClip | SPEC-004 | I04 | P1 | done |
| F-092 | Copy names/paths to clipboard (Ctrl+Shift+C etc., cm_CopyNames…) | Full set of cm_Copy*ToClip; the TSV form — what "copy file details" puts on the clipboard for a spreadsheet — had no escaping at all, so a tab in a file name shifted the columns and a line break split the row: six files became eight lines. The CSV guard compared Characters against "\n" and "\r", and a CRLF is one Character equal to neither, so such a name went through unquoted. Both fixed and pinned, backslash included so an escape can still be told from a literal; ev: symbol:FileListFormatter ev: test:FileListFormatterTests | SPEC-014 | I13 | P2 | done |
| F-093 | Create/edit symlink dialog; hardlink; macOS alias creation | TC: NTFS links -> POSIX equivalents; symlink/hardlink/alias checked with stat and the bytes on disk, not with the Foundation calls that created them: the hard link shares the target's inode and raises its link count, the alias starts with the "book" magic and still resolves after the target is renamed, a relative symlink is not rewritten absolute; ev: symbol:LinkMaker ev: test:LinkMakerTests | SPEC-004 | I17 | P2 | done |
| F-094 | Change attributes dialog (Ctrl+Enter? no: Files>Change attr): perms, flags, dates, recursive, plugin fields | incl. chmod octal + owner if privileged; ev: symbol:AttributesDialog ev: symbol:PosixPermissions | SPEC-016 | I17 | P1 | done |
| F-095 | Split file (Files>Split) into N-byte parts + .crc; Combine parts | split streams; combine now streams the parts too rather than holding each one whole in memory; a .crc sidecar written on Windows (CRLF, optional BOM) used to be rejected outright, which defeated the format's whole purpose; round trips pinned for empty files, exact division, one-byte parts, missing parts and non-ASCII names; ev: symbol:SplitCombineEngine ev: test:SplitCombineEngineTests | SPEC-016 | I17 | P2 | done |
| F-096 | Encode/decode: Base64/UUE/MIME/XXE; binary-safe | ev: symbol:Base64Codec ev: symbol:UUCodec ev: test:Base64CodecTests | SPEC-016 | I17 | P2 | done |
| F-097 | Create/verify checksums: CRC32, MD5, SHA-1/256/512, BLAKE3; .sfv/.md5 files | the digests are checked against Python's hashlib and zlib.crc32, and the parser against checksum files written by the system's own shasum and md5 — including the CRLF+BOM form, which used to parse to nothing so a Windows-written .sfv verified no files at all; BLAKE3 is *not* implemented (crc32/md5/sha1/sha256/sha512 are); ev: file:Tools/check-checksums.sh ev: test:ChecksumFileTests ev: test:ChecksumEngineTests | SPEC-016 | I17 | P1 | done |
| F-098 | Print file lists / print file (via macOS print) | Export list as txt/csv too | SPEC-016 | I17 | P3 | done |
| F-099 | Privileged operations: prompt for admin when EPERM (SMJobBless/askpass) | chmod, delete and saving a root-owned file in the editor retry as administrator; copy and move do not; ev: symbol:PrivilegedRunner ev: symbol:offerPrivilegedSave | SPEC-004 | I18 | P2 | partial |
| F-100 | Long-path, weird-name safety: NFC/NFD unicode, colon/slash mapping, >1023 chars | macOS specifics; tests; ev: test:PathResolverTests ev: symbol:precomposedStringWithCanonicalMapping | SPEC-004 | I04 | P1 | done |
| F-101 | Undo last file op where possible (move/rename/copy) | Finder-like undo stack, TC has none — extra; Edit ▸ Undo (⌘Z) routes to the panel; copy/move/rename are undoable; ev: symbol:registerUndo | SPEC-004 | I18 | P3 | done |

## 5. Viewer (Lister) & Quick View

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-110 | F3 Lister window: text mode w/ ANSI/ASCII/variable codepages, UTF-8/16 | Autodetect encoding; manual switch; the 64 KB sample is trimmed to a character boundary before it is judged (a UTF-8 file whose sample ended mid-character was read as CP1252) and the BOM is not part of the text (F-376); ev: symbol:EncodingDetector ev: test:EncodingDetectorBoundaryTests; the syntax-highlighted code view — used for files between 4 and 16 MiB — built its line ranges by comparing each Character against "\n", and a CRLF is one Character equal to neither, so a Windows-style file of that size became a *single* line six million characters wide: not merely a wrong count, but a view that never finished laying out. Below 4 MiB AppKit does the wrapping and was never affected, which is why nobody saw it; ev: scenario:viewer-crlf-lines ev: symbol:CodeListerView | SPEC-005 | I07 | P1 | done |
| F-111 | Hex mode + binary (fixed width) mode | Offsets, byte grouping; ev: symbol:HexDocument ev: symbol:HexFormatter | SPEC-005 | I07 | P1 | done |
| F-112 | Huge files: instant open via mmap, files > memory, 2^63 bytes | Scroll a 50 GB file smoothly; ev: symbol:LineIndexer ev: test:HexDocumentTests | SPEC-005 | I07 | P1 | done |
| F-113 | Search in viewer (F7/Ctrl+F, F3 next), hex search, case opts | Also from command line arg; ev: symbol:ByteSearch ev: symbol:applyInitialSearch | SPEC-005 | I07 | P1 | done |
| F-114 | Wrap/unwrap, font config, fit-to-window images | ev: symbol:applyWrap ev: symbol:wrapText | SPEC-005 | I07 | P1 | done |
| F-115 | Image display (all NSImage/ImageIO formats), zoom, next/prev in dir (n/p) | Animated GIF ok; ev: symbol:zoomImage ev: symbol:NSImageView | SPEC-005 | I07 | P1 | done |
| F-116 | HTML/RTF display modes | WKWebView (local only, JS off) / NSAttributedString; ev: symbol:WKWebView ev: symbol:MarkdownRenderer | SPEC-005 | I07 | P2 | done |
| F-117 | Multimedia playback (audio/video) via AVKit | TC uses codecs/plugins; ev: symbol:AVPlayerView ev: cm_List | SPEC-005 | I07 | P2 | done |
| F-118 | Quick View panel (Ctrl+Q) inside inactive panel | Follows cursor; same engines as Lister; ev: cm_SrcQuickview ev: symbol:updateQuickView | SPEC-005 | I07 | P1 | done |
| F-119 | Lister plugins (PLX) integration + multiple viewers per type (1..n switch) | ev: symbol:PLXLister ev: plugin:SampleLister | SPEC-012 | I16 | P1 | done |
| F-120 | View files inside archives (extract-to-temp transparently) | Via VFS; ev: symbol:ArchiveFS ev: test:SearchInArchiveTests ev: test:ArchiveExtractorTests | SPEC-007 | I09 | P1 | done |
| F-121 | Copy text selection, save-as, print from Lister | ev: symbol:NSPrintOperation ev: symbol:docCopy | SPEC-005 | I07 | P2 | done |
| F-122 | F4 edit: open in configured editor (default TextEdit/VS Code detect); Shift+F4 new file | Editor per extension config; the built-in editor outlines JSON/YAML/XML and navigates, selects, folds, transforms, copies a jq/XPath path and validates by structure (F-368 … F-371); ev: symbol:FileAssociations ev: cm_Edit ev: symbol:StructureOutline ev: symbol:StructureNavigation ev: test:StructurePathTests ev: test:StructureValidatorTests ev: scenario:editor-structure ev: scenario:editor-validate ev: scenario:editor-yaml-outline ev: symbol:EditorFolding ev: symbol:StructureTransforms ev: test:StructureTransformsTests | SPEC-004 | I04 | P1 | done |
| F-123 | Quick Look integration (Space alternative / dedicated key) | Cmd+Y (cm_QuickLook) | SPEC-015 | I18 | P3 | done |

## 6. Archives

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-130 | Enter archive like a directory (zip, tar, gz, bz2, xz, 7z, rar-read, iso, cab, cpio, lzh) | libarchive read; ev: symbol:ShellArchiveSource ev: test:ArchiveFSTests; the listing is checked against Python's zipfile/tarfile over a generated corpus — stored/deflated, ustar/GNU/PAX, gzip, long names, Unicode (F-377); ev: file:Tools/check-archive-listing.sh | SPEC-007 | I09 | P1 | done |
| F-131 | Unpack (Alt+F9): all/selected, with paths, overwrite handling | a crafted member named "../../evil.txt" used to be written outside the folder the user chose ("zip slip") while the extraction reported success; members that would land outside the destination are skipped now, and the harmless ones still arrive; ev: symbol:ArchiveExtractor ev: test:ArchiveExtractorTests | SPEC-007 | I09 | P1 | done |
| F-132 | Pack (Alt+F5): zip/tar/tgz/tbz/txz; options: compression level, store paths, encrypt (zip AES), self-extracting n/a | Move-to-archive option; TC parity; a file whose name begins with a dash used to be read by the packer as a switch, so packing that folder failed outright in every format (and a file called "-C" would have made tar change directory and archive something else) — the names are now passed after "--"; the written archives are read back by Python's zipfile/tarfile and by 7z, and the compression level is checked by comparing a stored against a maximum archive; ev: symbol:PackEngine ev: file:Tools/check-pack-formats.sh ev: test:PackEngineTests | SPEC-007 | I09 | P1 | done |
| F-133 | Copy INTO archive with F5 (add), delete/rename inside archive (F8/F6 rewrite) | zip targets only; the earlier note that cross-panel F5 add was pending is stale; ev: symbol:addToArchive ev: test:ArchiveEditorTests | SPEC-007 | I09 | P1 | done |
| F-134 | Archive-in-archive browsing (nested) | temp extraction chain; nested is browse-only; ev: test:ArchiveFSTests ev: test:ArchiveExtractorTests | SPEC-007 | I09 | P2 | done |
| F-135 | Test archive integrity command | checked by damaging an archive rather than by reading the code: one flipped byte inside a member's compressed data is reported, three damaged members are reported as three, and an intact archive is not called damaged; ev: symbol:ZipReader ev: test:ZipReaderTests | SPEC-007 | I09 | P2 | done |
| F-136 | Password-protected archives: prompt, keychain option; zip AES + 7z | the password used to be passed as "-p<password>", which puts it in the process's argument list where `ps` shows it in full to anything running as the same user for as long as the archive takes to write (measured on a running pack); it now goes to the packer on standard input, and a test asserts it never appears in the arguments; ev: symbol:PackEngine ev: test:PackEngineTests | SPEC-007 | I09 | P1 | done |
| F-137 | Packer plugins (PCX) extend formats; per-extension packer association | ev: symbol:resolvePackerPack ev: plugin:SamplePacker | SPEC-012 | I14 | P1 | done |
| F-138 | Background packing/unpacking through operation queue | | SPEC-007 | I09 | P1 | done |
| F-139 | Copy directly between two archives | via temp; queue-composed; zip targets only — the archive is rewritten by ArchiveEditor; ev: symbol:copyInto ev: test:ArchiveEditorTests | SPEC-007 | I09 | P2 | partial |

## 7. Search

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-150 | Alt+F7 Find Files dialog: name masks (multi, exclude), start dirs, depth limit | TC search dialog tabs: General/Advanced/Plugins/Load-Save; ev: symbol:optionsTabView ev: scenario:find-files | SPEC-008 | I10 | P1 | done |
| F-151 | Full-text search: encodings, whole-word, case, regex, NOT-containing, hex | Streaming, mmap, parallel; a file's comment is searched too when asked for, under the same rules (F-373); ev: symbol:SearchTemplate ev: test:FileSearchEngineTests ev: test:SearchCommentsTests ev: scenario:find-comments | SPEC-008 | I10 | P1 | done |
| F-152 | Advanced filters: date range, age, size, attributes | ev: symbol:FindFilesWindowController | SPEC-008 | I10 | P1 | done |
| F-153 | Search in archives; search in selected files/dirs only | | SPEC-008 | I10 | P2 | done |
| F-154 | Regex engine for names + content (ICU/NSRegularExpression) | TC regex dialect notes in spec; an invalid pattern used to end the search with no results and no word said, which reads exactly like "the term is not in these files" — so the user believes the files are clean and stops looking. The engine still fails closed; the window now says which field and why first. "*" and "*.*" still mean everything even in regex mode and are not compiled; ev: symbol:firstInvalidPattern ev: test:FileSearchEngineTests | SPEC-008 | I10 | P1 | done |
| F-155 | Results: feed to listbox (results become a panel), view/edit from results, goto file | Panel shows virtual search-result dir | SPEC-008 | I10 | P1 | done |
| F-156 | Save/load search templates; use templates in select/color/sync rules | Named templates shared across features | SPEC-008 | I10 | P2 | done |
| F-157 | Plugin (content-field) search criteria with operators | e.g. `duration > 10min`; ev: symbol:contentFieldPopup ev: test:SearchPluginTextTests | SPEC-012 | I16 | P2 | done |
| F-158 | Duplicate file finder (by name/size/content hash) | Part of Find Files "duplicates"; symlinks were already excluded (a link stats as a link, not a file), but two hard links to one file were reported as duplicates — deleting one frees nothing, so the window claimed reclaimable space that does not exist; collapsed by device+inode, and only for a file system whose paths are real files (asking an archive would extract every candidate to learn nothing); ev: symbol:DuplicateFinder ev: test:DuplicateFinderTests | SPEC-008 | I17 | P1 | done |
| F-159 | Spotlight-accelerated mode (optional toggle) | macOS extra: NSMetadataQuery prefilter; Spotlight answers a different question from the walker — it has no notion of a regular expression, a depth limit or a selection scope — and that was said only in the checkbox's tooltip, which is no help at the moment it matters. The result line now names whichever of them was set and did not apply; the predicate itself substitutes through %@ rather than string-building, so a mask cannot alter the query; ev: symbol:SpotlightPredicate ev: test:SpotlightPredicateTests | SPEC-015 | I18 | P3 | done |

## 8. Multi-rename tool

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-170 | Ctrl+M dialog on selection; live preview grid old->new | Non-destructive until Start | SPEC-009 | I11 | P1 | done |
| F-171 | Placeholders: [N], [N#-#], [E], [C] counter w/ start/step/digits, [d] date/time parts, [P] parent | Full TC placeholder table in spec | SPEC-009 | I11 | P1 | done |
| F-172 | Content-plugin fields as placeholders `[=plugin.field]` | | SPEC-012 | I16 | P2 | done |
| F-173 | Search & replace incl. regex + subst, case conversion modes | Upper/lower/first-letter rules | SPEC-009 | I11 | P1 | done |
| F-174 | Edit names via external editor (export list, re-import) | ev: test:RenameByEditorTests | SPEC-009 | I11 | P2 | done |
| F-175 | Undo rename (log kept), rename result log, collision handling | the rename list comes back from the user's own editor, and a CRLF one used to leave a carriage return in every new file name — legal on macOS, so it succeeded silently; ev: symbol:RenameByEditor ev: test:RenameByEditorTests; the batch staging that survives a cycle (a→b together with b→a) now lives in RenameBatchEngine where it can be tested — the forward direction was right, but *undo* was single-phase and silently did nothing at all for a swap or a rotation; names the batch could not deliver are reported instead of dropped; ev: symbol:RenameBatchEngine ev: test:RenameBatchEngineTests ev: scenario:comment-carry | SPEC-009 | I11 | P1 | done |
| F-176 | Save/load rename presets | | SPEC-009 | I11 | P2 | done |

## 9. Compare & synchronize

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-190 | Compare by content: side-by-side diff, binary + text, editable panes, per-diff nav | TC's built-in editor-diff; editable panes with block merge are in; ev: symbol:DiffWindowController ev: test:LineDiffTests | SPEC-010 | I12 | P1 | done |
| F-191 | Compare directories (mark newer/different), mark-same hiding | cm_CompareDirs etc.; holds, including the macOS trap it is easiest to fail: the same name arrives decomposed from one volume and composed from another, and seen as two files each side would be marked "only here" and a sync would copy both ways for ever — Swift compares Strings canonically, so it already matches, and that is pinned because it is invisible in the source; ev: symbol:DirCompareMarker ev: test:DirCompareMarkerTests | SPEC-010 | I12 | P1 | done |
| F-192 | Synchronize dirs dialog: filters, subdirs, by content/date/size, asymmetric, preview list, copy left/right/delete | Full TC sync semantics incl. ZIP targets; ev: symbol:SyncScanner ev: test:SyncModelTests | SPEC-010 | I12 | P1 | done |
| F-193 | Sync with archive as one side; sync via FS plugins (FTP) | a whole .zip may be one side (content comparison forced, since ZipWriter re-stamps); an FTP site or a plugin filesystem may not; ev: symbol:SyncSide ev: symbol:walkZip | SPEC-010 | I15 | P2 | partial |
| F-194 | Save sync sessions/presets | ev: test:SyncPresetStoreTests | SPEC-010 | I12 | P2 | done |

## 10. Network: FTP & friends

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-210 | FTP connection manager (Ctrl+F): stored sessions, folders, master password->Keychain | wcx_ftp.ini analog, pw in Keychain; the rule that no secret reaches ftp-sites.ini was stated in three comments and checked nowhere; a test now serializes a site carrying a proxy password and asserts neither the value nor a password-shaped key appears, while the non-secret fields still do (so it cannot pass by writing nothing). An authenticated proxy was unusable: the model had proxyUser/proxyPassword and the ini a proxyuser key, but the connection manager offered no fields — added, with the password in the Keychain like the site's own; ev: symbol:FtpCredentials ev: test:FtpSiteTests ev: test:FtpCredentialsTests | SPEC-011 | I15 | P1 | done |
| F-211 | Quick connect (Ctrl+N) with URL ftp:// ftps:// sftp:// | ev: symbol:FtpURL ev: symbol:FtpConnectionManagerWindowController | SPEC-011 | I15 | P1 | done |
| F-212 | FTP: passive/active, proxy (HTTP/SOCKS4/5), resume, keep-alive, MLSD/LIST parsers | passive/active, HTTP and SOCKS5 proxy, keep-alive, MLSD and REST-based resume in both directions; ev: symbol:NWFTPActiveTransport ev: symbol:NetProxy ev: symbol:keepAliveTask ev: test:FTPResumeTests ev: scenario:sftp-upload; the LIST/MLSD parsers are exercised against the shapes real servers emit — vsftpd, ProFTPD, wu-ftpd, IIS, RFC 3659 — including names with runs of spaces, which used to be collapsed and therefore unopenable (F-378); ev: test:FTPListingTests | SPEC-011 | I15 | P1 | done |
| F-213 | FTPS (TLS explicit/implicit) via Network.framework | implicit FTPS only (TLS from the first byte); explicit AUTH TLS is declared in FtpSite but the transport does not negotiate it; ev: symbol:NWProtocolTLS | SPEC-011 | I15 | P1 | partial |
| F-214 | SFTP via libssh2 plugin (key auth, agent, known_hosts) | TC does this via plugin too; downloads stream to disk and resume by seeking (F-366); attribute changes reach the server (F-364) | ev: symbol:SFTPSession ev: scenario:sftp-download ev: scenario:sftp-attributes | SPEC-011 | I15 | P1 | done |
| F-215 | Background/queued transfers, download list for later, bandwidth limit | ev: symbol:TransferManager ev: symbol:speedLimitKBps | SPEC-011 | I15 | P1 | done |
| F-216 | FXP server-to-server copy | Rarely supported; best effort; not built | SPEC-011 | I15 | P3 | todo |
| F-217 | Custom FTP commands, raw command log window | ev: symbol:FTPConsoleWindowController ev: symbol:rawCommand | SPEC-011 | I15 | P2 | done |
| F-218 | SMB/network shares: mount helper UI (Finder-mount based) + smb:// cd | Replaces TC "Network Neighborhood" | SPEC-011 | I18 | P2 | done |
| F-219 | WebDAV via FS plugin (post-1.0 sample plugin) | ev: plugin:WebDAV | SPEC-012 | — | P3 | done |

## 11. Plugin system

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-230 | Plugin host: load/unload C-ABI dylib bundles, crash-guard logging, version handshake | 4 types: PCX/PFX/PLX/PDX; ev: symbol:PluginHost ev: test:PluginHostTests | SPEC-012 | I14 | P1 | done |
| F-231 | PCX packer API (OpenArchive, ReadHeader(Ex), ProcessFile, PackFiles, DeleteFiles, GetPackerCaps, callbacks…) | Function-for-function WCX port; ev: symbol:PCXArchive ev: plugin:SamplePacker | SPEC-012 | I14 | P1 | done |
| F-232 | PFX file-system API (FsInit, FsFindFirst/Next/Close, FsGet/PutFile, FsMkDir, FsDelete, FsExecuteFile, FsStatusInfo, content-fields…) | WFX port; "Network" root node in panel; ev: symbol:PFXFileSystem ev: plugin:SampleFS | SPEC-012 | I15 | P1 | done |
| F-233 | PLX lister API (ListLoad, ListLoadNext, ListSearchText, ListSendCommand, ListGetPreviewBitmap, detect strings) | NSView* instead of HWND; ev: symbol:PLXLister ev: test:PluginHostTests | SPEC-012 | I16 | P1 | done |
| F-234 | PDX content API (ContentGetSupportedField, ContentGetValue, ContentSetValue, ContentCompareFiles, operators…) | Columns, tooltips, search, rename; ev: symbol:PDXContentProvider ev: test:ContentFieldValuesTests | SPEC-012 | I16 | P1 | done |
| F-235 | Plugin manager UI: install from .zip (pluginst.inf analog), enable/disable, associate extensions, configure | Options > Plugins page; installing from a .zip goes through /usr/bin/unzip, which strips absolute paths and flattens "../" into the destination — measured against a crafted archive, nothing escapes. But an *upgrade* removed the existing bundle before copying the new one and rolled back by deleting the new one, so an upgrade that failed to load left the user with nothing where they had something that worked; the old bundle is moved aside now and put back; ev: symbol:PluginManager ev: test:PluginInstallZipTests | SPEC-012 | I14 | P1 | done |
| F-236 | Plugin SDK: C headers, Swift package, 4 sample plugins, porting guide WCX->PCX etc. | Docs + templates in Plugins/SDK; ev: plugin:SDK ev: plugin:SampleLister | SPEC-012 | I14–I16 | P1 | done |
| F-237 | Built-in plugins shipped: SFTP (PFX), 7z-extra (PCX if needed), file-info PDX sample | Prove each API; each API is proven by a sample plugin; SFTP is built in (PCNet) rather than a PFX plugin; ev: plugin:SampleFS ev: plugin:SamplePacker ev: plugin:SampleContentPlugin | SPEC-012 | I15/I16 | P1 | partial |
| F-238 | Detect strings engine (EXT=, SIZE, FORCE, MULTIMEDIA & parser) | Shared by PLX/PDX; ev: symbol:DetectString ev: test:DetectStringTests | SPEC-012 | I16 | P1 | done |

## 12. Command system, button bar, menus

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-250 | Internal command registry: every action has stable name (cm_*) + numeric id | Superset of TC's TOTALCMD.INC list | SPEC-014 | I02→I13 | P1 | done |
| F-251 | Full TC main menu tree (Files/Mark/Commands/Net/Show/Config/Start) mapped to macOS menu bar | Exact item order per ui-reference; ev: symbol:AppMenu ev: scenario:keys-main | SPEC-014 | I13 | P1 | done |
| F-252 | User menu (Start menu) with user commands (em_*), parameters (%P %N %T %M %S…) | usercmd.ini analog; the %-tokens are substituted into a line handed to /bin/sh, and the values are file names — untrusted input. They used to be wrapped in *double* quotes and only when they contained whitespace, so `$(id).txt`, `` `id`.txt `` and `a;id;b.txt` (all legal macOS names) went in raw and ran when any user command was invoked on that folder; a name containing a double quote broke out. Every value is single-quoted now through one shared quoter, checked by running the expanded line through a real shell; ev: symbol:ShellQuoting ev: symbol:ParamExpander ev: test:ParamExpanderQuotingTests ev: test:ShellQuoteTests | SPEC-014 | I13 | P1 | done |
| F-253 | Button bar: .bar file format, icons, cm_/em_/programs/dirs as buttons, subbars, drag files onto buttons | ev: symbol:ButtonBar ev: test:ButtonBarTests | SPEC-014 | I13 | P1 | done |
| F-254 | Keyboard remapping: any cm_ to any key; per-scheme (TC-classic vs macOS-native) | Two shipped schemes; user overrides | SPEC-014 | I13 | P1 | done |
| F-255 | Command browser dialog (like TC "choose command") with search | Used by buttonbar/keys/menu editors; ev: symbol:CommandBrowserWindowController | SPEC-014 | I13 | P2 | done |
| F-256 | Aliases in command line (cd shortcuts, user aliases) | ev: test:AliasStoreTests | SPEC-014 | I13 | P3 | done |
| F-257 | Main menu user-editable (menu file format) + multiple menu files | .mnu analog, needed for localized menus; ev: test:MenuFileTests ev: symbol:MnuMenuBuilder | SPEC-014 | I19 | P3 | done |

## 13. Configuration

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-270 | Options dialog: Layout page (toggle every UI element live) | TC Config>Options>Layout; ev: symbol:SettingsWindowController ev: scenario:settings | SPEC-013 | I05 | P1 | done |
| F-271 | Options: Operation (mouse mode, quick search mode, deletion, copy defaults) | ev: symbol:setQuickSearchMode ev: symbol:setMouseMode | SPEC-013 | I05 | P1 | done |
| F-272 | Options: Display, Icons, Font & size, Colors (incl. by-type), Tabs, Language | ev: symbol:ThemeFile ev: symbol:displayTypeColors | SPEC-013 | I05 | P1 | done |
| F-273 | Options: Edit/View associations (viewer/editor per type) | internal associations; ev: symbol:AssociationsPageView | SPEC-013 | I07 | P1 | done |
| F-274 | Options: Packer, Zip settings; Plugins page; FTP page | ev: symbol:packDefaultFormat ev: symbol:PluginsWindowController | SPEC-013 | I09/I14/I15 | P1 | done |
| F-275 | INI-based config files, human-editable, reload w/o restart where safe | ADR-007; paths in configuration.md; "human-editable" is now checked rather than asserted: the serializer used to rebuild every pair as key=value, so the first save reformatted the whole file — `Appearance = dark` became `Appearance=dark` on lines nobody had touched. Untouched lines are written back verbatim; setting a value changes only that line and keeps its spacing. The Format command asks for `normalizing: true`, because there tidying is the point; a semicolon stays part of a value (a path list would otherwise be cut at the first one); ev: symbol:INIDocument ev: test:INIDocumentTests ev: test:FormattingTests | SPEC-013 | I05 | P1 | done |
| F-276 | Import subset of wincmd.ini (colors, hotlist, buttonbar, ftp sites) | Migration helper, best effort; a CRLF wincmd.ini — i.e. every real one — used to import nothing, because "\r\n" is one Swift Character and the INI parser split on "\n" (F-375); ev: cm_ImportWincmd ev: test:WincmdImporterTests | SPEC-013 | I19 | P3 | done |
| F-277 | Portable-ish mode: config path override via launch arg/env | For tests + power users; ev: symbol:ConfigPaths ev: test:ConfigStoreTests ev: test:LaunchOptionsTests | SPEC-013 | I05 | P2 | done |

## 14. macOS-specific additions (beyond TC)

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-290 | Quick Look panel & thumbnails everywhere | ev: symbol:PreviewPanelView ev: scenario:notes-sidebar | SPEC-015 | I18 | P2 | done |
| F-291 | Finder Tags: column, edit, filter/search by tag | column+edit+filter (tag:red / #blau) done; reading was always locale-independent (it resolves the colour from the trailing index, and says so), but *writing* went through URLResourceValues.tagNames, which stores a bare name — measured: setting "Red" produced "Red\n0", index 0 meaning no colour. So a label applied here was grey in this app's own column, a colourless custom tag in the Finder, and on a German system a second tag beside the "Rot" already on the file. Toggling now matches and writes by colour index; ev: symbol:FinderTagColor ev: test:FinderTagWriteTests | SPEC-015 | I18 | P2 | done |
| F-292 | Share sheet (AirDrop, Mail, Messages) for selection | the share sheet already drops paths that no longer exist and beeps when nothing is left; ev: symbol:NSSharingServicePicker | SPEC-015 | I18 | P3 | done |
| F-293 | Services menu integration + "Open Terminal here" (Terminal/iTerm) | | SPEC-015 | I18 | P2 | done |
| F-294 | Spotlight metadata as content-plugin provider (built-in PDX "mdls") | kMDItem* fields as columns/search; ev: symbol:SpotlightPredicate ev: test:SpotlightPredicateTests | SPEC-015 | I18 | P2 | done |
| F-295 | Dark mode: full support; TC-classic light theme default option | Theme system | SPEC-001 | I05 | P1 | done |
| F-296 | AppleScript/Shortcuts: core verbs (reveal, copy, get selection) | Automation dictionary | SPEC-015 | — | P3 | post-1.0 |
| F-297 | Trash awareness: show Trash, put-back metadata | show done (Go ▸ Trash); the Trash can be opened; "put back" is not offered because macOS exposes no public API for it; ev: cm_GoToTrash | SPEC-015 | I18 | P3 | partial |
| F-298 | Permissions/ACL/xattr inspector-editor dialog | POSIX edit + xattr inspect/remove done; POSIX permissions, xattr inspect/remove and ACL editing (from the Attributes dialog); ev: symbol:ACLEditorWindowController ev: symbol:AttributesDialog | SPEC-015 | I18 | P2 | done |
| F-299 | Full Disk Access onboarding flow (detect & guide to System Settings) | Required for ~/Library etc.; ev: symbol:FullDiskAccessGuide | SPEC-015 | I18 | P1 | done |
| F-300 | Retina/HiDPI assets, trackpad gestures (swipe = history nav) | two-finger swipe walks the panel history; ev: symbol:swipe ev: symbol:backingScaleFactor | SPEC-001 | I19 | P2 | done |

## 15. Distribution & updates

| ID | Feature | Notes | Spec | Iter | Prio | Status |
|---|---|---|---|---|---|---|
| F-310 | Developer ID signing + hardened runtime + notarization + stapling | Tools/release.sh; scripts and entitlements are in place; blocked on an Apple Developer ID for signing, notarization and stapling; ev: file:Tools/codesign-app.sh | DIST | I20 | P1 | partial |
| F-311 | DMG with layout (app + Applications symlink + background) | Tools/make-dmg.sh | DIST | I20 | P1 | done |
| F-312 | Sparkle 2 auto-update: appcast, EdDSA keys, delta updates, channels (beta/stable) | blocked: needs an Apple Developer ID and update-feed hosting | DIST | I20 | P1 | todo |
| F-313 | Crash reporting (local .ips collection + user-consent submit) | No 3rd-party SaaS by default | DIST | I20 | P2 | done |
| F-314 | Versioning: semver + monotonically increasing build number; CHANGELOG.md | | DIST | I20 | P1 | done |
| F-315 | CI release pipeline (GitHub Actions macos): build, test, sign, notarize, appcast | Manual fallback documented | DIST | I20 | P2 | done |
| F-316 | Homebrew cask formula | Post-launch | DIST | — | P3 | post-1.0 |

## 16. Explicitly n/a on macOS (parity exceptions)

| ID | TC feature | Rationale / replacement |
|---|---|---|
| F-330 | Windows registry file system plugin usage | n/a-macos |
| F-331 | Parallel port link / direct cable connection | n/a-macos |
| F-332 | 8.3 short names display | n/a-macos |
| F-333 | NTFS alternate data streams UI | n/a-macos |
| F-334 | Windows shell extensions / Explorer context menu hosts | n/a-macos |
| F-335 | UAC elevation dialogs | n/a-macos |
| F-336 | Volume shadow copy access | n/a-macos |
