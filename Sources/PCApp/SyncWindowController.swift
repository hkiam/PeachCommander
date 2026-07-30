// SPDX-License-Identifier: Apache-2.0
// SyncWindowController.swift - Synchronize Directories (I12 T05/T06, F-192)
//
// Dialog: two directory lines, a file mask, the comparison options (with
// subdirs / by content / ignore date / asymmetric), a Compare button that scans
// both trees and classifies each item via SyncModel, a colored result grid, and
// a Synchronize button that executes the copies/deletes. Local filesystem only
// for now (archive/FTP sides are F-193 → I15). Presets (F-194) are deferred.

import AppKit
import PCArchive
import PCFoundation

/// One side of a sync: a local directory, or a whole `.zip` archive (F-193). A zip
/// side compares/updates from the archive root; timestamps in a zip are unreliable
/// (ZipWriter re-stamps on write), so the UI forces content comparison for it.
enum SyncSide: Sendable, Equatable {
    case localDir(String)
    case zip(String)   // on-disk .zip path

    var isZip: Bool { if case .zip = self { return true } else { return false } }
    var path: String { switch self { case .localDir(let p), .zip(let p): return p } }
}

/// Recursive scanner producing SyncItems for two sides (local dirs and/or a zip).
enum SyncScanner {
    private struct Meta { var size: Int64; var modified: Date; var isDir: Bool }

    static func scan(left: SyncSide, right: SyncSide, mask: String,
                     withSubdirs: Bool, byContent: Bool, ignoreHidden: Bool = false) -> [SyncItem] {
        let wildcard = WildcardMask(mask.isEmpty ? "*.*" : mask)
        let leftMeta = enumerate(left, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        let rightMeta = enumerate(right, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        // Open each zip once for the content-comparison reads below.
        let leftZip = zipReader(left), rightZip = zipReader(right)

        var keys = Set(leftMeta.keys)
        keys.formUnion(rightMeta.keys)
        var items: [SyncItem] = []
        for key in keys.sorted() {
            let l = leftMeta[key], r = rightMeta[key]
            let isDir = (l?.isDir ?? false) || (r?.isDir ?? false)
            var contentEqual: Bool? = nil
            if byContent, !isDir, let l, let r {
                if l.size != r.size {
                    contentEqual = false
                } else if !left.isZip && !right.isZip {
                    contentEqual = filesEqual((left.path as NSString).appendingPathComponent(key),
                                              (right.path as NSString).appendingPathComponent(key))
                } else {
                    contentEqual = loadData(left, key: key, zip: leftZip) == loadData(right, key: key, zip: rightZip)
                }
            }
            items.append(SyncItem(relativePath: key, isDirectory: isDir,
                                  leftSize: l?.size, leftModified: l?.modified,
                                  rightSize: r?.size, rightModified: r?.modified,
                                  contentEqual: contentEqual))
        }
        return items
    }

    private static func enumerate(_ side: SyncSide, withSubdirs: Bool, wildcard: WildcardMask,
                                  ignoreHidden: Bool) -> [String: Meta] {
        switch side {
        case .localDir(let dir): return walk(dir, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        case .zip(let url): return walkZip(url, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        }
    }

    /// True when any path component is a dotfile — used to skip hidden items (F-192).
    private static func isHiddenRel(_ rel: String) -> Bool {
        rel.split(separator: "/").contains { $0.hasPrefix(".") }
    }

    private static func zipReader(_ side: SyncSide) -> ZipReader? {
        if case .zip(let url) = side { return ZipReader(fileURL: URL(fileURLWithPath: url)) }
        return nil
    }

    /// Enumerate a zip's entries as sync metadata, keyed by POSIX relative path.
    private static func walkZip(_ url: String, withSubdirs: Bool, wildcard: WildcardMask, ignoreHidden: Bool) -> [String: Meta] {
        guard let reader = ZipReader(fileURL: URL(fileURLWithPath: url)) else { return [:] }
        var out: [String: Meta] = [:]
        for e in reader.entries {
            var rel = e.path
            while rel.hasSuffix("/") { rel.removeLast() }
            guard !rel.isEmpty else { continue }
            if !withSubdirs && rel.contains("/") { continue }
            if ignoreHidden, isHiddenRel(rel) { continue }   // F-192
            let leaf = (rel as NSString).lastPathComponent
            if !e.isDirectory, !wildcard.matches(leaf) { continue }
            out[rel] = Meta(size: e.uncompressedSize,
                            modified: e.modified ?? Date(timeIntervalSince1970: 0),
                            isDir: e.isDirectory)
        }
        return out
    }

    /// Load one entry's bytes from a side (for content comparison across a zip).
    private static func loadData(_ side: SyncSide, key: String, zip: ZipReader?) -> Data? {
        switch side {
        case .localDir(let dir):
            return try? Data(contentsOf: URL(fileURLWithPath: (dir as NSString).appendingPathComponent(key)))
        case .zip:
            guard let zip, let e = zip.entries.first(where: { entryKey($0.path) == key }) else { return nil }
            return try? zip.data(for: e)
        }
    }

    /// A zip entry path reduced to the comparison key (no trailing slash).
    private static func entryKey(_ path: String) -> String {
        var s = path
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    private static func walk(_ dir: String, withSubdirs: Bool, wildcard: WildcardMask, ignoreHidden: Bool) -> [String: Meta] {
        let fm = FileManager.default
        let base = (dir as NSString).standardizingPath
        var out: [String: Meta] = [:]
        // Use the path-based enumerator: it yields paths RELATIVE to `base`, so there
        // is no prefix to strip. (The URL enumerator reports resolved paths like
        // /private/tmp/… that don't match a /tmp/… base, silently dropping everything
        // under a symlinked root.)
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        guard let en = fm.enumerator(atPath: base) else { return out }
        for case let rel as String in en {
            let full = (base as NSString).appendingPathComponent(rel)
            let vals = try? URL(fileURLWithPath: full).resourceValues(forKeys: Set(keys))
            let isDir = vals?.isDirectory ?? false
            // Top-level-only mode: include the directory itself but don't descend.
            if !withSubdirs && isDir { en.skipDescendants() }
            // Ignore hidden items (any dotfile component), F-192.
            if ignoreHidden, isHiddenRel(rel) { if isDir { en.skipDescendants() }; continue }
            let leaf = (rel as NSString).lastPathComponent
            if !isDir, !wildcard.matches(leaf) { continue }
            out[rel] = Meta(size: Int64(vals?.fileSize ?? 0),
                            modified: vals?.contentModificationDate ?? Date(timeIntervalSince1970: 0),
                            isDir: isDir)
        }
        return out
    }

    /// Byte-compare two files in chunks (sizes already known equal by the caller).
    private static func filesEqual(_ a: String, _ b: String) -> Bool {
        guard let fa = FileHandle(forReadingAtPath: a), let fb = FileHandle(forReadingAtPath: b) else { return false }
        defer { try? fa.close(); try? fb.close() }
        let chunk = 1 << 16
        while true {
            let da = fa.readData(ofLength: chunk)
            let db = fb.readData(ofLength: chunk)
            if da != db { return false }
            if da.isEmpty { return true }
        }
    }
}

/// Executes classified sync actions against two sides (local dirs and/or a zip).
/// Copies into a zip are batched into a single ArchiveEditor.add rewrite; extraction
/// out of a zip writes files locally. Deleting inside a zip is not supported (F-193
/// MVP) — such actions are reported as skipped.
enum SyncExecutor {
    static func execute(_ results: [SyncResult], left: SyncSide, right: SyncSide,
                        toTrash: Bool) -> [String] {
        let fm = FileManager.default
        var errors: [String] = []
        var zipAdds: [(localPath: String, arcPath: String)] = []   // local → zip, batched
        var zipDeletes: [String] = []                              // entries to delete from the zip (F-192)

        func local(_ side: SyncSide, _ rel: String) -> String {
            (side.path as NSString).appendingPathComponent(rel)
        }

        /// Copy one file/dir from `src` side to `dst` side.
        func copy(rel: String, isDir: Bool, src: SyncSide, dst: SyncSide) {
            switch (src, dst) {
            case (.localDir, .localDir):
                copyLocalToLocal(local(src, rel), local(dst, rel), isDir: isDir)
            case (.localDir, .zip):
                if !isDir { zipAdds.append((localPath: local(src, rel), arcPath: rel)) }
                // Empty-dir entries are implicit via child arc paths; skip standalone dirs.
            case (.zip(let url), .localDir):
                extractFromZip(url, rel: rel, to: local(dst, rel), isDir: isDir)
            case (.zip, .zip):
                errors.append("\(rel): archive-to-archive sync not supported")
            }
        }

        func copyLocalToLocal(_ src: String, _ dst: String, isDir: Bool) {
            do {
                if isDir {
                    try fm.createDirectory(atPath: dst, withIntermediateDirectories: true)
                } else {
                    try fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                           withIntermediateDirectories: true)
                    if fm.fileExists(atPath: dst) { try fm.removeItem(atPath: dst) }
                    try fm.copyItem(atPath: src, toPath: dst)
                }
            } catch { errors.append("\((src as NSString).lastPathComponent): \(error.localizedDescription)") }
        }

        func extractFromZip(_ url: String, rel: String, to dst: String, isDir: Bool) {
            do {
                if isDir {
                    try fm.createDirectory(atPath: dst, withIntermediateDirectories: true)
                    return
                }
                guard let reader = ZipReader(fileURL: URL(fileURLWithPath: url)),
                      let entry = reader.entries.first(where: {
                          var s = $0.path; while s.hasSuffix("/") { s.removeLast() }; return s == rel }) else {
                    errors.append("\(rel): not found in archive"); return
                }
                let data = try reader.data(for: entry)
                try fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                       withIntermediateDirectories: true)
                try data.write(to: URL(fileURLWithPath: dst))
            } catch { errors.append("\(rel): \(error.localizedDescription)") }
        }

        func remove(_ side: SyncSide, _ rel: String) {
            if case .zip = side {                         // batched into one rewrite below (F-192)
                zipDeletes.append(rel); return
            }
            let path = local(side, rel)
            do {
                if toTrash { try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil) }
                else { try fm.removeItem(atPath: path) }
            } catch { errors.append("\((path as NSString).lastPathComponent): \(error.localizedDescription)") }
        }

        // Create dirs (shallowest first), then copy files, then delete (deepest first).
        let creates = results.filter { $0.item.isDirectory && ($0.action == .copyToRight || $0.action == .copyToLeft) }
            .sorted { $0.item.relativePath.count < $1.item.relativePath.count }
        let fileCopies = results.filter { !$0.item.isDirectory && ($0.action == .copyToRight || $0.action == .copyToLeft) }
        let deletes = results.filter { $0.action == .deleteRight || $0.action == .deleteLeft }
            .sorted { $0.item.relativePath.count > $1.item.relativePath.count }

        for r in creates + fileCopies {
            let rel = r.item.relativePath
            if r.action == .copyToRight { copy(rel: rel, isDir: r.item.isDirectory, src: left, dst: right) }
            else { copy(rel: rel, isDir: r.item.isDirectory, src: right, dst: left) }
        }
        // One rewrite for all files copied into the zip.
        if !zipAdds.isEmpty, let zipURL = (left.isZip ? left : right).path as String? {
            do { try ArchiveEditor.add(to: URL(fileURLWithPath: zipURL), entries: zipAdds) }
            catch { errors.append("archive update failed: \(error.localizedDescription)") }
        }
        for r in deletes {
            remove(r.action == .deleteRight ? right : left, r.item.relativePath)
        }
        // One rewrite for all entries deleted from the zip (F-192).
        if !zipDeletes.isEmpty, let zipURL = (left.isZip ? left : right).path as String? {
            do { try ArchiveEditor.remove(from: URL(fileURLWithPath: zipURL), paths: zipDeletes) }
            catch { errors.append("archive delete failed: \(error.localizedDescription)") }
        }
        return errors
    }
}

final class SyncWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    var onClose: (() -> Void)?
    /// Reload the panels after a successful sync.
    var reload: (() async -> Void)?
    /// Where named sync presets are persisted (F-194).
    private let presetStore: SyncPresetStore?
    private let presetPopup = NSPopUpButton()

    private var leftSide: SyncSide
    private var rightSide: SyncSide
    /// A zip side has unreliable timestamps, so comparison is forced to by-content.
    private var hasZipSide: Bool { leftSide.isZip || rightSide.isZip }

    private let leftField = NSTextField()
    private let rightField = NSTextField()
    private let maskField = NSTextField()
    private let subdirsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let byContentButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let ignoreDateButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let asymmetricButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let ignoreHiddenButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)   // F-192
    private let tableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let syncButton = NSButton(title: "", target: nil, action: nil)

    private var results: [SyncResult] = []
    // Per-row state (F-192): included in the sync, and the (possibly overridden)
    // direction/action. Parallel to `results`.
    private var rowIncluded: [Bool] = []
    private var rowAction: [SyncAction] = []

    private static func isActionable(_ a: SyncAction) -> Bool {
        a == .copyToRight || a == .copyToLeft || a == .deleteRight || a == .deleteLeft
    }

    convenience init(leftDir: String, rightDir: String, presetsURL: URL? = nil) {
        self.init(left: .localDir(leftDir), right: .localDir(rightDir), presetsURL: presetsURL)
    }

    init(left: SyncSide, right: SyncSide, presetsURL: URL? = nil) {
        self.leftSide = left
        self.rightSide = right
        self.presetStore = presetsURL.map { SyncPresetStore(url: $0) }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Synchronize Directories")
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() {
        leftField.stringValue = leftSide.path
        rightField.stringValue = rightSide.path
        // A zip side's path is fixed and its timestamps are unreliable, so lock the
        // field and force content comparison (dates ignored).
        if leftSide.isZip { leftField.isEditable = false }
        if rightSide.isZip { rightField.isEditable = false }
        if hasZipSide {
            byContentButton.state = .on;  byContentButton.isEnabled = false
            ignoreDateButton.state = .on; ignoreDateButton.isEnabled = false
        }
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 8
        root.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        for (label, field) in [(String(localized: "Left:"), leftField), (String(localized: "Right:"), rightField)] {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 6
            let l = NSTextField(labelWithString: label)
            l.widthAnchor.constraint(equalToConstant: 44).isActive = true
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 700).isActive = true
            row.addArrangedSubview(l)
            row.addArrangedSubview(field)
            root.addArrangedSubview(row)
        }

        let maskRow = NSStackView()
        maskRow.orientation = .horizontal
        maskRow.spacing = 6
        maskRow.addArrangedSubview(NSTextField(labelWithString: String(localized: "Mask:")))
        maskField.stringValue = "*.*"
        maskField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        maskRow.addArrangedSubview(maskField)
        root.addArrangedSubview(maskRow)

        let opts = NSStackView()
        opts.orientation = .horizontal
        opts.spacing = 14
        subdirsButton.title = String(localized: "With subdirs")
        subdirsButton.state = .on
        byContentButton.title = String(localized: "By content")
        ignoreDateButton.title = String(localized: "Ignore date")
        asymmetricButton.title = String(localized: "Asymmetric (mirror →)")
        ignoreHiddenButton.title = String(localized: "Ignore hidden")
        for b in [subdirsButton, byContentButton, ignoreDateButton, asymmetricButton, ignoreHiddenButton] {
            opts.addArrangedSubview(b)
        }
        root.addArrangedSubview(opts)

        // Preset row (F-194): pick a saved comparison profile, or save/delete one.
        if presetStore != nil {
            let presetRow = NSStackView()
            presetRow.orientation = .horizontal
            presetRow.spacing = 6
            presetRow.addArrangedSubview(NSTextField(labelWithString: String(localized: "Preset:")))
            presetPopup.target = self
            presetPopup.action = #selector(presetSelected)
            presetPopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
            presetRow.addArrangedSubview(presetPopup)
            let saveBtn = NSButton(title: String(localized: "Save Preset…"), target: self, action: #selector(savePreset))
            let delBtn = NSButton(title: String(localized: "Delete Preset"), target: self, action: #selector(deletePreset))
            for b in [saveBtn, delBtn] { b.bezelStyle = .rounded; presetRow.addArrangedSubview(b) }
            root.addArrangedSubview(presetRow)
            reloadPresetPopup()
        }

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        let compare = NSButton(title: String(localized: "Compare"), target: self, action: #selector(compare))
        compare.bezelStyle = .rounded
        compare.keyEquivalent = "\r"
        syncButton.title = String(localized: "Synchronize")
        syncButton.bezelStyle = .rounded
        syncButton.target = self
        syncButton.action = #selector(synchronize)
        syncButton.isEnabled = false
        buttons.addArrangedSubview(compare)
        buttons.addArrangedSubview(syncButton)
        root.addArrangedSubview(buttons)

        // Result grid
        let cols: [(String, CGFloat)] = [("inc", 26), ("name", 356), ("left", 150), ("act", 60), ("right", 150)]
        let titles = ["", String(localized: "Name"), String(localized: "Left"), "", String(localized: "Right")]
        for (i, c) in cols.enumerated() {
            let col = NSTableColumn(identifier: .init(c.0))
            col.title = titles[i]
            col.width = c.1
            tableView.addTableColumn(col)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 18
        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 780).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 300).isActive = true
        root.addArrangedSubview(scroll)

        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        root.addArrangedSubview(statusLabel)
    }

    private func options() -> SyncOptions {
        SyncOptions(byContent: byContentButton.state == .on,
                    ignoreDate: ignoreDateButton.state == .on,
                    asymmetric: asymmetricButton.state == .on)
    }

    // MARK: - Presets (F-194)

    /// Rebuild the popup: a placeholder row + one item per saved preset.
    private func reloadPresetPopup() {
        guard let store = presetStore else { return }
        presetPopup.removeAllItems()
        presetPopup.addItem(withTitle: String(localized: "(none)"))
        for p in store.load() { presetPopup.addItem(withTitle: p.name) }
        presetPopup.selectItem(at: 0)
    }

    /// The current dialog settings as a preset with the given name.
    private func currentPreset(name: String) -> SyncPreset {
        SyncPreset(name: name, options: options(),
                   fileMask: maskField.stringValue, withSubdirs: subdirsButton.state == .on)
    }

    /// Push a preset's settings into the controls.
    private func apply(_ preset: SyncPreset) {
        byContentButton.state = preset.options.byContent ? .on : .off
        ignoreDateButton.state = preset.options.ignoreDate ? .on : .off
        asymmetricButton.state = preset.options.asymmetric ? .on : .off
        maskField.stringValue = preset.fileMask
        subdirsButton.state = preset.withSubdirs ? .on : .off
    }

    @objc private func presetSelected() {
        guard let store = presetStore, presetPopup.indexOfSelectedItem > 0 else { return }
        let name = presetPopup.titleOfSelectedItem ?? ""
        if let preset = store.load().first(where: { $0.name == name }) { apply(preset) }
    }

    @objc private func savePreset() {
        guard let store = presetStore else { return }
        let dialog = InputDialog(title: String(localized: "Save Preset"),
                                 prompt: String(localized: "Preset name:"),
                                 initialValue: presetPopup.indexOfSelectedItem > 0 ? (presetPopup.titleOfSelectedItem ?? "") : "")
        dialog.onConfirm = { [weak self] name in
            guard let self else { return }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            _ = store.upsert(self.currentPreset(name: trimmed))
            self.reloadPresetPopup()
            self.presetPopup.selectItem(withTitle: trimmed)
        }
        dialog.runModalDialog()
    }

    @objc private func deletePreset() {
        guard let store = presetStore, presetPopup.indexOfSelectedItem > 0,
              let name = presetPopup.titleOfSelectedItem else { return }
        _ = store.remove(name: name)
        reloadPresetPopup()
    }

    // MARK: - Actions

    /// Trigger the comparison programmatically (used by automation, F-192).
    func compareNow() { compare() }
    #if DEBUG
    /// Set the "Ignore hidden" option before an automated compare (F-192).
    func automationSetIgnoreHidden(_ on: Bool) { ignoreHiddenButton.state = on ? .on : .off }
    #endif

    @objc private func compare() {
        // Local sides track their editable path field; zip sides are fixed.
        if case .localDir = leftSide { leftSide = .localDir(leftField.stringValue) }
        if case .localDir = rightSide { rightSide = .localDir(rightField.stringValue) }
        let mask = maskField.stringValue
        let withSubdirs = subdirsButton.state == .on
        let byContent = byContentButton.state == .on
        let ignoreHidden = ignoreHiddenButton.state == .on
        let opts = options()
        statusLabel.stringValue = String(localized: "Comparing…")
        syncButton.isEnabled = false
        let (l, r) = (leftSide, rightSide)
        Task.detached(priority: .userInitiated) {
            let items = SyncScanner.scan(left: l, right: r, mask: mask,
                                         withSubdirs: withSubdirs, byContent: byContent,
                                         ignoreHidden: ignoreHidden)
            let classified = SyncModel.classify(items, options: opts)
            await MainActor.run {
                self.results = classified.filter { $0.action != .none }
                self.rowAction = self.results.map(\.action)
                self.rowIncluded = self.results.map { Self.isActionable($0.action) }   // include all actionable by default
                self.tableView.reloadData()
                self.updateStatus()
                self.syncButton.isEnabled = self.results.contains { $0.action != .equal && $0.action != .conflict }
            }
        }
    }

    private func updateStatus() {
        var toRight = 0, toLeft = 0, dels = 0, conflicts = 0
        for (i, r) in results.enumerated() {
            if r.action == .conflict { conflicts += 1; continue }
            guard i < rowIncluded.count, rowIncluded[i] else { continue }   // count only included rows (F-192)
            switch rowAction[i] {
            case .copyToRight: toRight += 1
            case .copyToLeft: toLeft += 1
            case .deleteRight, .deleteLeft: dels += 1
            default: break
            }
        }
        statusLabel.stringValue = String(localized: "→ \(toRight)   ← \(toLeft)   delete \(dels)   conflicts \(conflicts)")
    }

    @objc private func synchronize() {
        // Only included rows, with any per-row direction override applied (F-192).
        let actionable: [SyncResult] = results.enumerated().compactMap { i, r in
            guard i < rowIncluded.count, rowIncluded[i], Self.isActionable(rowAction[i]) else { return nil }
            return SyncResult(action: rowAction[i], item: r.item)
        }
        guard !actionable.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Synchronize \(actionable.count) item(s)?")
        alert.informativeText = statusLabel.stringValue
        alert.addButton(withTitle: String(localized: "Synchronize"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let (l, r) = (leftSide, rightSide)
        statusLabel.stringValue = String(localized: "Synchronizing…")
        Task.detached(priority: .userInitiated) {
            let errors = SyncExecutor.execute(actionable, left: l, right: r, toTrash: true)
            await self.reload?()
            await MainActor.run {
                if errors.isEmpty {
                    self.statusLabel.stringValue = String(localized: "Done — trees synchronized.")
                } else {
                    self.statusLabel.stringValue = String(localized: "Completed with \(errors.count) error(s).")
                }
                self.compare() // re-scan to reflect the new state
            }
        }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let r = results[row]
        let action = rowAction[row]
        // Include checkbox (F-192): only actionable rows can be toggled.
        if tableColumn?.identifier.rawValue == "inc" {
            let box = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleInclude(_:)))
            box.tag = row
            box.state = rowIncluded[row] ? .on : .off
            box.isEnabled = Self.isActionable(action)
            return box
        }
        // Action cell: a clickable glyph that flips direction on copy rows (F-192).
        if tableColumn?.identifier.rawValue == "act" {
            let btn = NSButton(title: Self.actionGlyph(action), target: self, action: #selector(flipDirection(_:)))
            btn.tag = row
            btn.isBordered = false
            btn.contentTintColor = Self.actionColor(action)
            btn.isEnabled = action == .copyToRight || action == .copyToLeft
            btn.toolTip = String(localized: "Click to reverse the copy direction")
            return btn
        }
        let id = NSUserInterfaceItemIdentifier("c")
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField)
            ?? { let f = NSTextField(labelWithString: ""); f.identifier = id; f.isBordered = false; f.drawsBackground = false; return f }()
        switch tableColumn?.identifier.rawValue {
        case "name": field.stringValue = r.item.relativePath + (r.item.isDirectory ? "/" : "")
        case "left": field.stringValue = r.item.leftSize.map { ByteSize($0).formatted(style: .kb) } ?? "—"
        case "right": field.stringValue = r.item.rightSize.map { ByteSize($0).formatted(style: .kb) } ?? "—"
        default: field.stringValue = ""
        }
        // Excluded rows are dimmed; otherwise use the action's colour.
        field.textColor = rowIncluded[row] || !Self.isActionable(action)
            ? Self.actionColor(action) : .disabledControlTextColor
        return field
    }

    @objc private func toggleInclude(_ sender: NSButton) {
        guard rowIncluded.indices.contains(sender.tag) else { return }
        rowIncluded[sender.tag] = sender.state == .on
        tableView.reloadData(forRowIndexes: IndexSet(integer: sender.tag),
                             columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        updateStatus()
    }

    @objc private func flipDirection(_ sender: NSButton) {
        guard rowAction.indices.contains(sender.tag) else { return }
        switch rowAction[sender.tag] {
        case .copyToRight: rowAction[sender.tag] = .copyToLeft
        case .copyToLeft: rowAction[sender.tag] = .copyToRight
        default: return
        }
        tableView.reloadData(forRowIndexes: IndexSet(integer: sender.tag),
                             columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        updateStatus()
    }

    private static func actionGlyph(_ a: SyncAction) -> String {
        switch a {
        case .copyToRight: return "→"
        case .copyToLeft: return "←"
        case .equal: return "="
        case .conflict: return "≠"
        case .deleteRight: return "→🗑"
        case .deleteLeft: return "🗑←"
        case .none: return ""
        }
    }

    private static func actionColor(_ a: SyncAction) -> NSColor {
        switch a {
        case .copyToRight, .copyToLeft: return .systemBlue
        case .equal: return .secondaryLabelColor
        case .conflict: return .systemRed
        case .deleteRight, .deleteLeft: return .systemOrange
        case .none: return .labelColor
        }
    }
}

extension SyncWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { onClose?() }
}
