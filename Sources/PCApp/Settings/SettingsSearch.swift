// SPDX-License-Identifier: Apache-2.0
// SettingsSearch.swift - Reading the settings pages back to build the search index, and the result list
// the search field shows (F-408).
//
// The index is *harvested from the built pages* rather than written down beside them. A hand-kept table
// of "setting name → page" is a second copy of the UI, and the copy is wrong within a release: this
// project has the evidence for it — the drive bar came to disagree with the panel exactly that way
// (F-402). Walking the real view tree cannot drift, it finds settings nobody remembered to list, and it
// is already how `settingsdump` reads this window for the automation harness.
//
// What a *result* is, is the one judgement here: a control the user can operate. The wrapping paragraphs
// under a control are not results — a search list of paragraphs is unreadable — but their words are
// keywords for the control above them, because "bak" is in the note and not in the title.

import AppKit
import PCFoundation

/// Turns settings pages into searchable entries plus the controls they point at.
@MainActor
struct SettingsSearchHarvester {
    /// One harvested control: the entry describing it, and the view to reveal.
    struct Target {
        /// The page the control lives on, as the source list titles it.
        let page: String
        /// Nil for a page itself — "open the page and that is the whole answer".
        let control: NSView?
    }

    private(set) var entries: [SettingsSearchEntry] = []
    private(set) var targets: [Target] = []

    /// Harvest one page: its title becomes a result of its own, then every control on it.
    ///
    /// The page as a result matters more than it looks: typing "ftp" should offer the FTP page even
    /// though no control on it is called that, and a page whose controls are all built lazily by a
    /// plugin still has a name worth finding.
    mutating func add(page title: String, view: NSView?) {
        append(name: title, page: title, keywords: [], control: nil)
        guard let view else { return }
        var pending: [String] = []          // labels seen since the last control, awaiting their control
        var lastEntry: Int?                 // the entry that trailing prose belongs to
        walk(view) { node in
            switch node {
            case .prose(let text):
                // Explanation *after* a control belongs to it; before one, it is a caption for what
                // follows. Both are keywords, and which of the two it is decides whose.
                if let lastEntry, pending.isEmpty {
                    entries[lastEntry] = entries[lastEntry].adding(keywords: [text])
                } else {
                    pending.append(text)
                }
            case .label(let text):
                pending.append(text)
            case .control(let control, let ownTitle, let extra):
                let name = ownTitle ?? pending.last ?? ""
                guard !name.isEmpty else { pending.removeAll(); return }
                // A label consumed as the control's *name* is not also a keyword for it.
                let labels = ownTitle == nil ? pending.dropLast() : pending[...]
                append(name: Self.tidy(name), page: title, keywords: Array(labels) + extra,
                       control: control)
                lastEntry = entries.count - 1
                pending.removeAll()
            }
        }
    }

    private mutating func append(name: String, page: String, keywords: [String], control: NSView?) {
        entries.append(SettingsSearchEntry(name: name, page: page, keywords: keywords,
                                          ref: targets.count))
        targets.append(Target(page: page, control: control))
    }

    /// What a node in a settings page can be, for indexing purposes.
    private enum Node {
        /// A control the user operates, its own title if it has one, and extra searchable words (a
        /// popup's items, so "Norton Commander" finds the mouse-mode row).
        case control(NSView, String?, [String])
        /// A short label — a row caption like "Quick search:".
        case label(String)
        /// A wrapping explanation: findable, never a result.
        case prose(String)
    }

    /// Depth-first in view order, which is reading order for the stacks these pages are made of.
    private func walk(_ view: NSView, _ visit: (Node) -> Void) {
        for subview in view.subviews {
            if let node = Self.classify(subview) { visit(node) }
            // A control's own subviews are its internals (a popup's cell, a table's rows) and never
            // more settings; descending into them produced a result per table column.
            if !(subview is NSControl) { walk(subview, visit) }
        }
    }

    /// Which kind of node a view is, or nil for chrome that is neither.
    private static func classify(_ view: NSView) -> Node? {
        if let popup = view as? NSPopUpButton {
            return .control(popup, nil, popup.itemTitles + actionWords(popup))
        }
        if let button = view as? NSButton {
            let title = button.title.trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? nil : .control(button, title, actionWords(button))
        }
        if let field = view as? NSTextField {
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                // An empty *editable* field is still a setting; its name comes from the label before it.
                return field.isEditable ? .control(field, nil, []) : nil
            }
            if field.isEditable { return .control(field, nil, actionWords(field)) }
            // A wrapping label is prose; a one-line one is a caption. `maximumNumberOfLines == 0` means
            // "as many as it takes", which is what `wrappingLabelWithString` sets — the notes under the
            // checkboxes on every page.
            let wraps = field.maximumNumberOfLines != 1
            return (wraps && text.count > 40) ? .prose(text) : .label(text)
        }
        // Everything else that can be operated: sliders, colour wells, segmented controls, steppers.
        if let control = view as? NSControl, !(control is NSTableView) {
            return .control(control, nil, actionWords(control))
        }
        return nil
    }

    /// The words of the action a control calls — `showHiddenChanged:` becomes "show hidden changed".
    ///
    /// This is the one keyword source that is *not* in the language the app is running in, and it is
    /// there on purpose: with a German UI, "hidden" finds nothing by name, while the selector behind
    /// "Versteckte Dateien anzeigen" still says what the setting is. Free, and it cannot drift — it is
    /// read off the control that is wired to it.
    private static func actionWords(_ control: NSControl) -> [String] {
        guard let action = control.action else { return [] }
        var words = ""
        for character in String(describing: action).replacingOccurrences(of: ":", with: "") {
            if character.isUppercase { words.append(" ") }
            words.append(character)
        }
        return [words.lowercased().trimmingCharacters(in: .whitespaces)]
    }

    /// The name as a result should read it: no trailing colon, no double spaces.
    private static func tidy(_ title: String) -> String {
        var name = title.trimmingCharacters(in: .whitespaces)
        while name.hasSuffix(":") || name.hasSuffix("：") { name.removeLast() }
        return name
    }
}

private extension SettingsSearchEntry {
    func adding(keywords extra: [String]) -> SettingsSearchEntry {
        SettingsSearchEntry(name: name, page: page, keywords: keywords + extra, ref: ref)
    }
}

// MARK: - The result list

/// The list a settings search shows in place of a page: one row per matching setting, with the page it
/// lives on beside it.
@MainActor
final class SettingsResultsView: NSView {
    /// Called with the chosen entry's `ref` — on a click, on Return, on a double-click.
    var onChoose: ((Int) -> Void)?

    private let table = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private var results: [SettingsSearchEntry] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        table.headerView = nil
        table.rowHeight = Metrics.rowHeight * 2
        table.backgroundColor = Theme.current.listBackground
        table.usesAlternatingRowBackgroundColors = true
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result")))
        table.dataSource = self
        table.delegate = self
        // A list Tab reaches and a screen reader can name (I19 T06).
        table.setAccessibilityLabel(String(localized: "Search results"))
        table.target = self
        table.action = #selector(rowClicked)
        table.doubleAction = #selector(rowClicked)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        addSubview(scroll)

        emptyLabel.stringValue = String(localized: "No setting matches that.")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            emptyLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
        ])
    }

    /// Repaint after a theme change: this list draws its own background, so nothing else can do it.
    func applyTheme() {
        table.backgroundColor = Theme.current.listBackground
        table.needsDisplay = true
    }

    /// Show `results`; an empty list says so rather than looking like a page that failed to load.
    func show(_ results: [SettingsSearchEntry]) {
        self.results = results
        emptyLabel.isHidden = !results.isEmpty
        table.reloadData()
        if !results.isEmpty { table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
    }

    /// Return in the search field acts on the highlighted row, which is the first one until the reader
    /// moves it — so a search followed by Return goes where the eye already is.
    func chooseSelected() {
        let row = table.selectedRow >= 0 ? table.selectedRow : 0
        guard results.indices.contains(row) else { return }
        onChoose?(results[row].ref)
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        let row = max(0, min(results.count - 1, (table.selectedRow < 0 ? 0 : table.selectedRow) + delta))
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    /// Diagnostic: the rows as shown, in order (automation).
    func dump() -> String {
        "count=\(results.count)\n" + results.enumerated()
            .map { "\($0.offset + 1)|\($0.element.name)|\($0.element.page)" }
            .joined(separator: "\n") + "\n"
    }

    @objc private func rowClicked() {
        let row = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
        guard results.indices.contains(row) else { return }
        onChoose?(results[row].ref)
    }
}

extension SettingsResultsView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("SettingsResultCell")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? SettingsResultCell)
            ?? SettingsResultCell(identifier: id)
        cell.configure(name: results[row].name, page: results[row].page)
        return cell
    }
}

/// A result row: the setting on top, the page it lives on underneath — the second line is the answer to
/// "where is it", which is the question being asked.
private final class SettingsResultCell: NSView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let pageLabel = NSTextField(labelWithString: "")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        nameLabel.font = Fonts.system13
        nameLabel.lineBreakMode = .byTruncatingTail
        pageLabel.font = .systemFont(ofSize: 11)
        pageLabel.textColor = .secondaryLabelColor
        pageLabel.lineBreakMode = .byTruncatingTail
        for label in [nameLabel, pageLabel] {
            label.maximumNumberOfLines = 1
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            ])
        }
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            pageLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(name: String, page: String) {
        nameLabel.stringValue = name
        nameLabel.toolTip = name
        pageLabel.stringValue = page
    }
}

// MARK: - Showing the reader what they navigated to

/// A brief tint behind a control, so "it jumped to the setting" is something the eye can catch.
///
/// A focus ring was the first attempt and it is invisible where it matters: AppKit draws one for a
/// programmatic first responder on a checkbox *only* when Full Keyboard Access is on, so on a default
/// Mac the window changed page and nothing pointed at the setting. This fades out by itself, which also
/// means there is nothing to clean up if the reader immediately clicks elsewhere.
@MainActor
enum SettingsSpotlight {
    /// The tint's own identifier, so a diagnostic can answer "is something pointing at this control"
    /// without guessing from layer colours.
    static let identifier = NSUserInterfaceItemIdentifier("SettingsSpotlight")

    /// True while a tint for `control` is on screen.
    ///
    /// Presence, not `alphaValue`: an `animator()` sets the model value to its target at once and
    /// interpolates only what is drawn, so asking about the alpha reports "already invisible" a
    /// millisecond in. The tint is removed when the animation ends, which is the fact worth reading.
    static func isFlashing(_ control: NSView) -> Bool {
        control.superview?.subviews.contains { $0.identifier == identifier } ?? false
    }

    static func flash(_ control: NSView) {
        guard let parent = control.superview else { return }
        let tint = NSView(frame: control.frame.insetBy(dx: -5, dy: -3))
        tint.identifier = identifier
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.38).cgColor
        tint.layer?.cornerRadius = 5
        parent.addSubview(tint, positioned: .below, relativeTo: control)
        control.scrollToVisible(control.bounds)
        // Held, then faded — two steps on purpose. Animating a view that has only just been added leaves
        // *nothing* on screen: the animator sets the model alpha to its target at once and the layer has
        // no committed value to interpolate from. Measured, with a screenshot: the state said a tint was
        // there and the picture showed a plain checkbox.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.8
                tint.animator().alphaValue = 0
            } completionHandler: {
                tint.removeFromSuperview()
            }
        }
    }
}
