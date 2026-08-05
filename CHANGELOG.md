# Changelog

All notable changes to Peach Commander are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/) — with the reservation that everything before 1.0 is a beta
and any release may still change behaviour it got wrong.

`docs/distribution/release-and-updates.md` referred to this file before it existed; the releases below
were reconstructed from the git history and the notes in `STATE.md` when it was written.

**Every build so far is unsigned and un-notarized.** macOS will refuse to open it on the first attempt;
`README.md` explains the Control-click route. Signing needs an Apple Developer ID, which the project
does not have.

## [0.3.0] — 2026-08-05

### Added

- **Structure view for JSON, YAML and XML in the editor.** The symbol sidebar lists the keys of a JSON
  or YAML document and the elements of an XML one, nested as the document is; elements are named by
  their `id`, `name` or `key` attribute. A file that does not parse still gets an outline down to the
  point where it breaks. Covers the XML-based formats too — `.plist`, `.svg`, `.csproj`,
  `.storyboard`.
- **Structural navigation and selection** (Ctrl+Cmd with the arrow keys): out to the enclosing node, in
  to the first child, and between siblings — stepping over the whole block in between. Ctrl+Cmd+A
  selects the enclosing node and grows outwards on each press.
- **Copy Structural Path** (Ctrl+Cmd+C) puts the cursor's position on the clipboard in the notation the
  format's own tools take: `.services.web.ports[0]` for `jq`/`yq`, `//server[@id='web-1']/port` as an
  XPath. Keys that are not plain identifiers are quoted, because `.content-type` is a subtraction in
  `jq` and `."content-type"` is the key.
- **Validate Document** (Ctrl+Cmd+V) checks the file and puts the cursor *on the problem*. JSON and XML
  are checked by a real parser; YAML has none on the system, so the check covers what can be decided
  without one — a tab used to indent, indentation that lines up with nothing, a duplicate key, an
  unterminated quote — and says that it is not a full parse.
- **Two problems nothing else in the toolchain reports:** a duplicate key, which every JSON parser
  accepts silently while discarding one of the two values, and a trailing comma, which Apple's parser
  accepts and Python, Go and `jq` refuse.
- **Transformations:** minify to one line, sort keys recursively, escape/unescape as a JSON string, and
  JSON → YAML. Minifying keeps key order and the exact spelling of every number, since `1.0` and `1`
  are not the same version. There is deliberately no YAML → JSON: it needs a YAML parser the system
  does not have.
- **Folding.** Option+Cmd with the arrow keys collapses the node at the cursor, the whole top level, or
  restores everything. Nothing is removed from the document — the text is only not drawn, so saving,
  undo and Find are unaffected. The header line stays visible and is marked, the line numbers skip what
  is hidden, and a cursor placed inside a fold opens it.
- Uploading into an FTP or SFTP panel with F5, with resume (previously the remote path was handed to
  the local copy engine, which either failed or wrote to a same-named local path and reported success).
- Panels notice changes another program makes, through FSEvents rather than polling.
- ZIP64 archives can be read: entries and archives above 4 GB, and more than 65 535 entries.
- Editor: filter the selection through a shell command, line operations (sort, deduplicate, trim),
  line-ending conversion and awareness of a read-only file at open time rather than at save time.

### Changed

- The window's appearance is read from the configuration *before the first frame*: the first paint no
  longer shows the built-in defaults and then corrects itself.
- A `.json` file is reported as JSON in the status line, not as JavaScript.
- The caret is at the start of a file after opening it. It used to be left behind the text, so the
  breadcrumb described the last key in the file while line 1 was on screen.

### Fixed

- The structure parser hung on any document with more than 5 000 nodes — on a background thread,
  silently, in every large JSON file.
- SFTP downloads stream to disk and resume by seeking; they used to be assembled in memory from the
  start.
- Attribute changes over SFTP reach the server. The function that was supposed to apply them was empty
  while the dialog reported success.
- Remote file listings and the copy engine no longer disagree about which side is remote.
- Keyboard operation: `autorecalculatesKeyViewLoop` is false for every window created in code, so Tab
  reached almost nothing. Settings reached the page list and no further; Find Files could be filled in
  but not started.
- `.gitignore` matched `Tools/vm/fixtures/` as well as the generated `Fixtures/` at the root, so the VM
  harness's own fixtures were never committed.

## [0.2.0] — 2026-07-30

### Added

- Decompiler plugins for Java/Android and .NET, inside the Commander rather than beside it: a
  searchable tree for a whole JAR, APK or dex, two engines side by side, results cached on disk.
- A VM regression harness (`Tools/vm/regress.py`) that drives the real app over VNC, counts Auto Layout
  conflicts against a baseline of zero and photographs every standard view.
- Accessibility: labels for every list, tree and hand-drawn control, plus a per-window keyboard gate.
- 19 languages for the UI and the complete in-app Help Book.

### Fixed

- Every Auto Layout conflict in the standard views, measured rather than guessed.
- Search inside archives reaches the plugin.

## [0.1.0] — 2026-07-14

First public beta: dual-pane browsing, the file operation engine, archives, the viewer and editor, FTP,
plugins, and the settings.

[0.3.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.3.0
[0.2.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.2.0
[0.1.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.1.0
