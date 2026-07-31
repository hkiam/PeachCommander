// SPDX-License-Identifier: Apache-2.0
// notes.swift — "Sticky notes" as an external plugin (Notes.pdxplugin).
//
// Two facets on one bundle: a PDX content field ("Note") that marks folders/files
// which have a note (a subtle ● column), and contribution commands "Edit Note…" /
// "Notes Overview…". Notes are markdown, keyed globally / per-directory / per-file,
// stored under ~/Library/Application Support/PeachCommander/notes/. The editor
// shows a live markdown preview; external links open normally and internal links
// (peach://<path> or a filesystem path) are resolved in the host via the openPath
// service. Self-contained (Foundation + AppKit); talks to the host only through
// the PcHostServices C-ABI.

import AppKit

// MARK: - Host services reference (copied from the transient services pointer;
// the host token + callbacks are stable for the app's lifetime, see the host's
// persistent contribution bridge).

struct HostRef {
    let host: UnsafeMutableRawPointer?
    let openPathFn: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void)?
    let presentInfoFn: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void)?
    let registerToolWindowFn: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void)?

    init(_ svc: PcHostServices) {
        host = svc.host
        openPathFn = svc.openPath
        presentInfoFn = svc.presentInfo
        registerToolWindowFn = svc.registerToolWindow
    }
    func openPath(_ p: String) { p.withCString { openPathFn?(host, $0) } }
    func present(_ t: String, _ m: String) { t.withCString { tp in m.withCString { mp in presentInfoFn?(host, tp, mp) } } }
    func registerToolWindow(_ window: NSWindow, edit: NSMenu, content: NSMenu, title: String) {
        title.withCString {
            registerToolWindowFn?(host,
                Unmanaged.passUnretained(window).toOpaque(),
                Unmanaged.passUnretained(edit).toOpaque(),
                Unmanaged.passUnretained(content).toOpaque(), $0)
        }
    }
}

// MARK: - Markdown rendering + image-dropping source view

let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "heic", "webp", "bmp"]

/// Plain-text markdown editor that accepts dropped image files (inserting a
/// markdown image link) instead of embedding them as rich-text attachments.
final class MarkdownSourceTextView: NSTextView {
    var onDropImage: ((URL) -> Void)?

    private func droppedImages(_ sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? [])
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedImages(sender).isEmpty ? super.draggingEntered(sender) : .copy
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let imgs = droppedImages(sender)
        guard let first = imgs.first else { return super.performDragOperation(sender) }
        imgs.forEach { onDropImage?($0) }
        _ = first
        return true
    }
}

extension NotesStore {
    /// Render markdown to an attributed string, resolving `![](path)` images
    /// (relative paths are under the notes base dir) as inline attachments.
    static func render(_ source: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        func appendText(_ s: String) {
            if !s.isEmpty, let a = try? NSAttributedString(markdown: Data(s.utf8), options: opts, baseURL: nil) {
                out.append(a)
            } else if !s.isEmpty {
                out.append(NSAttributedString(string: s))
            }
        }
        let ns = source as NSString
        let re = try! NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)]+)\)"#)
        var loc = 0
        re.enumerateMatches(in: source, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m else { return }
            if m.range.location > loc {
                appendText(ns.substring(with: NSRange(location: loc, length: m.range.location - loc)))
            }
            let path = ns.substring(with: m.range(at: 1))
            let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : shared.baseDir.appendingPathComponent(path)
            if let img = NSImage(contentsOf: url) {
                let att = NSTextAttachment(); att.image = img
                out.append(NSAttributedString(attachment: att))
                out.append(NSAttributedString(string: "\n"))
            } else {
                appendText(ns.substring(with: m.range))
            }
            loc = m.range.location + m.range.length
        }
        if loc < ns.length { appendText(ns.substring(from: loc)) }
        out.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: out.length))
        return out
    }
}

/// Copy `url` into the note's attachments dir and insert a markdown image link at
/// the text view's selection.
private func attachImage(_ url: URL, key: String, into tv: NSTextView) {
    let destDir = NotesStore.shared.attachmentsDir(key)
    let dest = destDir.appendingPathComponent(url.lastPathComponent)
    try? FileManager.default.removeItem(at: dest)
    try? FileManager.default.copyItem(at: url, to: dest)
    tv.insertText("![\(url.lastPathComponent)](attachments/\(destDir.lastPathComponent)/\(url.lastPathComponent))",
                  replacementRange: tv.selectedRange())
}

// MARK: - Store

private struct NoteMeta: Codable { var key: String; var file: String; var title: String; var updated: Double }
private struct NoteIndex: Codable { var notes: [NoteMeta] }

final class NotesStore {
    static let shared = NotesStore()
    static let globalKey = "*GLOBAL*"

    let baseDir: URL
    private let indexURL: URL
    private var metas: [String: NoteMeta] = [:]
    private var indexMTime: Date?

    init() {
        let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDir = appSup.appendingPathComponent("PeachCommander/notes", isDirectory: true)
        indexURL = baseDir.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        load()
    }

    private func load() {
        metas.removeAll()
        if let data = try? Data(contentsOf: indexURL),
           let idx = try? JSONDecoder().decode(NoteIndex.self, from: data) {
            for m in idx.notes { metas[m.key] = m }
        }
        indexMTime = (try? FileManager.default.attributesOfItem(atPath: indexURL.path)[.modificationDate] as? Date) ?? nil
    }

    private func reloadIfChanged() {
        let mt = (try? FileManager.default.attributesOfItem(atPath: indexURL.path)[.modificationDate] as? Date) ?? nil
        if mt != indexMTime { load() }
    }

    private func persist() {
        let idx = NoteIndex(notes: Array(metas.values))
        if let data = try? JSONEncoder().encode(idx) { try? data.write(to: indexURL, options: .atomic) }
        indexMTime = (try? FileManager.default.attributesOfItem(atPath: indexURL.path)[.modificationDate] as? Date) ?? nil
    }

    func hasNote(_ key: String) -> Bool { reloadIfChanged(); return metas[key] != nil }

    func body(_ key: String) -> String {
        guard let m = metas[key] else { return "" }
        return (try? String(contentsOf: baseDir.appendingPathComponent(m.file), encoding: .utf8)) ?? ""
    }

    func save(_ key: String, markdown: String) {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { delete(key); return }   // empty note ⇒ remove
        let file = metas[key]?.file ?? (UUID().uuidString + ".md")
        try? markdown.write(to: baseDir.appendingPathComponent(file), atomically: true, encoding: .utf8)
        metas[key] = NoteMeta(key: key, file: file, title: Self.title(from: markdown, key: key),
                              updated: Date().timeIntervalSince1970)
        persist()
    }

    func delete(_ key: String) {
        guard let m = metas[key] else { return }
        try? FileManager.default.removeItem(at: baseDir.appendingPathComponent(m.file))
        metas[key] = nil
        persist()
    }

    /// All notes, newest first.
    func all() -> [(key: String, title: String, updated: Double)] {
        reloadIfChanged()
        return metas.values.sorted { $0.updated > $1.updated }.map { ($0.key, $0.title, $0.updated) }
    }

    func search(_ q: String) -> [(key: String, title: String, updated: Double)] {
        let needle = q.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return all() }
        return all().filter { e in
            e.title.localizedCaseInsensitiveContains(needle)
                || e.key.localizedCaseInsensitiveContains(needle)
                || body(e.key).localizedCaseInsensitiveContains(needle)
        }
    }

    func attachmentsDir(_ key: String) -> URL {
        let stem = (metas[key]?.file as NSString?)?.deletingPathExtension ?? UUID().uuidString
        let dir = baseDir.appendingPathComponent("attachments/\(stem)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func title(from markdown: String, key: String) -> String {
        for raw in markdown.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespaces))
            if !line.isEmpty { return String(line.prefix(80)) }
        }
        return Self.displayName(key)
    }

    static func displayName(_ key: String) -> String {
        key == globalKey ? L("Global") : (key as NSString).lastPathComponent
    }
}

// MARK: - Editor window

final class NoteEditorWindow: NSWindowController, NSWindowDelegate {
    private let key: String
    private let host: HostRef
    private let editor: WYSIWYGEditorView
    private var registeredMenus: [NSMenu] = []
    var onClose: (() -> Void)?

    init(key: String, host: HostRef) {
        self.key = key; self.host = host
        self.editor = WYSIWYGEditorView(key: key)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 560),
                         styleMask: [.titled, .closable, .resizable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.title = String(format: L("Note — %@"), NotesStore.displayName(key))
        super.init(window: w)
        w.delegate = self
        editor.translatesAutoresizingMaskIntoConstraints = false
        if let content = w.contentView {
            content.addSubview(editor)
            NSLayoutConstraint.activate([
                editor.topAnchor.constraint(equalTo: content.topAnchor),
                editor.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                editor.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                editor.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        }
        editor.loadMarkdown(NotesStore.shared.body(key))
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.center(); showWindow(nil); window?.makeKeyAndOrderFront(nil)
        let edit = makeEditMenu(), note = makeNoteMenu()
        registeredMenus = [edit, note]
        host.registerToolWindow(window!, edit: edit, content: note, title: L("Note"))
    }

    @objc private func saveNote() { NotesStore.shared.save(key, markdown: editor.markdown()) }

    private func makeEditMenu() -> NSMenu {
        let m = NSMenu(title: L("Edit"))
        item(m, L("Cut"), #selector(NSText.cut(_:)), "x"); item(m, L("Copy"), #selector(NSText.copy(_:)), "c")
        item(m, L("Paste"), #selector(NSText.paste(_:)), "v"); item(m, L("Select All"), #selector(NSText.selectAll(_:)), "a")
        return m
    }
    private func makeNoteMenu() -> NSMenu {
        let m = NSMenu(title: L("Note"))
        item(m, L("Save"), #selector(saveNote), "s", target: self)
        return m
    }
    private func item(_ menu: NSMenu, _ title: String, _ sel: Selector, _ key: String, target: AnyObject? = nil) {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key); i.target = target; menu.addItem(i)
    }

    func windowWillClose(_ notification: Notification) {
        saveNote()   // autosave
        onClose?()
    }
}

// MARK: - Overview window

final class NotesOverviewWindow: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private let host: HostRef
    private let table = NSTableView()
    private let searchField = NSSearchField()
    private var rows: [(key: String, title: String, updated: Double)] = []
    var onClose: (() -> Void)?
    var onEdit: ((String) -> Void)?

    init(host: HostRef) {
        self.host = host
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 460),
                         styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.title = L("Notes Overview")
        super.init(window: w)
        w.delegate = self
        buildUI()
        reload()
    }
    required init?(coder: NSCoder) { fatalError() }
    func show() { window?.center(); showWindow(nil); window?.makeKeyAndOrderFront(nil) }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        searchField.placeholderString = L("Search notes…"); searchField.target = self; searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(searchField)
        for (id, title, w) in [("title", L("Note"), CGFloat(300)), ("key", L("Location"), 300)] {
            let c = NSTableColumn(identifier: .init(id)); c.title = title; c.width = w; table.addTableColumn(c)
        }
        table.dataSource = self; table.delegate = self; table.doubleAction = #selector(editSelected); table.target = self
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        let reveal = NSButton(title: L("Reveal"), target: self, action: #selector(revealSelected))
        let edit = NSButton(title: L("Edit"), target: self, action: #selector(editSelected))
        let remove = NSButton(title: L("Remove"), target: self, action: #selector(removeSelected))
        for b in [reveal, edit, remove] { b.bezelStyle = .rounded }
        let bar = NSStackView(views: [reveal, edit, remove, NSView()]); bar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(bar)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            bar.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            bar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
        ])
    }

    func reload() { rows = NotesStore.shared.search(searchField.stringValue); table.reloadData() }
    @objc private func searchChanged() { reload() }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return nil }
        let text = tableColumn?.identifier.rawValue == "key"
            ? (rows[row].key == NotesStore.globalKey ? L("Global") : (rows[row].key as NSString).abbreviatingWithTildeInPath)
            : rows[row].title
        return NSTextField(labelWithString: text)
    }

    private var selectedKey: String? { rows.indices.contains(table.selectedRow) ? rows[table.selectedRow].key : nil }
    @objc private func editSelected() { if let k = selectedKey { onEdit?(k) } }
    @objc private func revealSelected() { if let k = selectedKey, k != NotesStore.globalKey { host.openPath(k) } }
    @objc private func removeSelected() { if let k = selectedKey { NotesStore.shared.delete(k); reload() } }

    func windowWillClose(_ notification: Notification) { onClose?() }
}

// MARK: - Sidebar view (follows the active panel's cursor)

final class NotesSidebarView: NSView, NSTextViewDelegate {
    private let header = NSTextField(labelWithString: "")
    private let text = MarkdownSourceTextView()
    private let scroll = NSScrollView()
    private var currentKey = NotesStore.globalKey
    private var dirty = false
    /// Host colour theme (F-338). This view sits in the sidebar, right beside the file panels, so
    /// leaving it in macOS colours is what looks out of place under a theme like Norton.
    private var services: UnsafePointer<PcHostServices>?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 400))
        build()
        loadContext(NotesStore.globalKey)
    }

    func bindServices(_ s: UnsafePointer<PcHostServices>?) {
        services = s
        applyTheme()
    }

    /// Apply the host theme to the editor. Background *and* text together — a themed text colour
    /// on an unthemed background is how you get cyan on white.
    func applyTheme() {
        let theme = PluginTheme(services)
        wantsLayer = true
        layer?.backgroundColor = theme.windowBackground.cgColor
        header.textColor = theme.secondaryText
        text.backgroundColor = theme.background
        text.textColor = theme.text
        // The caret and the selection have to follow too, or they vanish into the new background.
        text.insertionPointColor = theme.text
        text.selectedTextAttributes = [.backgroundColor: theme.selectionBackground,
                                       .foregroundColor: theme.selectionText]
        scroll.backgroundColor = theme.background
        // No highlighting to reassert: the sidebar editor is `isRichText = false` plain text, so
        // `textColor` is the whole story. The WYSIWYG window is a different surface and keeps the
        // system colours — it is a standalone window, not part of the panel area.
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        header.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        header.textColor = .secondaryLabelColor
        header.lineBreakMode = .byTruncatingMiddle
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        text.isRichText = false
        text.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        text.delegate = self
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.registerForDraggedTypes([.fileURL])
        text.onDropImage = { [weak self] url in
            guard let self else { return }
            attachImage(url, key: self.currentKey, into: self.text); self.dirty = true
        }
        scroll.documentView = text; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    /// Switch to the note for `cursorPath` (empty ⇒ the global note), saving the
    /// previous note first if it was edited.
    func setContext(cursorPath: String) {
        saveCurrent()
        loadContext(cursorPath.isEmpty ? NotesStore.globalKey : cursorPath)
    }

    private func loadContext(_ key: String) {
        currentKey = key
        header.stringValue = String(format: L("Note — %@"), NotesStore.displayName(key))
        text.string = NotesStore.shared.body(key)
        dirty = false
    }

    func saveCurrent() {
        guard dirty else { return }
        NotesStore.shared.save(currentKey, markdown: text.string)
        dirty = false
    }

    func textDidChange(_ notification: Notification) { dirty = true }
    func textDidEndEditing(_ notification: Notification) { saveCurrent() }
}

// MARK: - Live window references (kept alive by the plugin)

private var editors: [NoteEditorWindow] = []
private var overview: NotesOverviewWindow?

private func openEditor(key: String, host: HostRef) {
    let win = NoteEditorWindow(key: key, host: host)
    editors.append(win)
    win.onClose = { [weak win] in editors.removeAll { $0 === win } }
    win.show()
}

// MARK: - Entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

// Sidebar notes view that follows the active panel's cursor.
@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ container: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    let view = NotesSidebarView()
    view.bindServices(services)
    if let services, let getCtx = services.pointee.getContext {
        var buf = [CChar](repeating: 0, count: 4096)
        let ok = "cursorPath".withCString { getCtx(services.pointee.host, $0, &buf, 4096) }
        if ok != 0 { view.setContext(cursorPath: String(cString: buf)) }
    }
    return Unmanaged.passRetained(view).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    (Unmanaged<NSView>.fromOpaque(view).takeUnretainedValue() as? NotesSidebarView)?.saveCurrent()
    Unmanaged<NSView>.fromOpaque(view).release()
}

@_cdecl("PcNotifyView")
public func PcNotifyView(_ view: UnsafeMutableRawPointer?, _ key: UnsafePointer<CChar>?, _ value: UnsafePointer<CChar>?) {
    guard let view, let key else { return }
    guard let sidebar = Unmanaged<NSView>.fromOpaque(view).takeUnretainedValue() as? NotesSidebarView else { return }
    switch String(cString: key) {
    case "cursorPath": sidebar.setContext(cursorPath: value.map { String(cString: $0) } ?? "")
    case "theme": sidebar.applyTheme()
    default: break
    }
}

// PDX content field: a subtle "●" on rows that have a note.
@_cdecl("ContentGetSupportedField")
public func ContentGetSupportedField(_ index: Int32, _ fieldName: UnsafeMutablePointer<CChar>?,
                                     _ units: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let fieldName, let units else { return Int32(PC_FT_NOMOREFIELDS) }
    guard index == 0 else { units[0] = 0; return Int32(PC_FT_NOMOREFIELDS) }
    // Not localized: the host derives a stable field id from this name (see LOCALIZATION.md).
    _ = "Note".withCString { strlcpy(fieldName, $0, Int(maxlen)) }
    _ = "badge".withCString { strlcpy(units, $0, Int(maxlen)) }   // opt into a name-cell badge
    return Int32(PC_FT_STRING)
}

@_cdecl("ContentGetValue")
public func ContentGetValue(_ fileName: UnsafeMutablePointer<CChar>?, _ fieldIndex: Int32, _ unitIndex: Int32,
                            _ fieldValue: UnsafeMutableRawPointer?, _ maxlen: Int32, _ flags: Int32) -> Int32 {
    guard let fileName, let fieldValue, fieldIndex == 0 else { return Int32(PC_FT_NOSUCHFIELD) }
    let path = String(cString: fileName)
    guard NotesStore.shared.hasNote(path) else { return Int32(PC_FT_FIELDEMPTY) }
    _ = "●".withCString { strlcpy(fieldValue.assumingMemoryBound(to: CChar.self), $0, Int(maxlen)) }
    return Int32(PC_FT_STRING)
}

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let commandId, let services else { return }
    let id = String(cString: commandId)
    let host = HostRef(services.pointee)
    switch id {
    case "plugin.notes.edit":
        var buf = [CChar](repeating: 0, count: 4096)
        let ok = services.pointee.cursorPath.map { $0(host.host, &buf, 4096) } ?? 0
        openEditor(key: ok != 0 ? String(cString: buf) : NotesStore.globalKey, host: host)
    case "plugin.notes.overview":
        if let existing = overview { existing.reload(); existing.show(); return }   // single instance
        let win = NotesOverviewWindow(host: host)
        overview = win
        win.onEdit = { key in openEditor(key: key, host: host) }
        win.onClose = { overview = nil }
        win.show()
    default:
        break
    }
}
