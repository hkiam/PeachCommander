// SPDX-License-Identifier: Apache-2.0
// GitBlameView.swift — who last touched each line, and when.
//
// Phase 2 of docs/analysis/git-plugin-plan.md (F-417). `git blame --porcelain` per line, in a table:
// commit, author, date, line number, text. Selecting a line and pressing Enter opens that commit's
// version of the file against its parent in the host's compare window — the same handover the panel and
// the log use, so "why is this line here" ends in a diff rather than in a hash the reader has to copy.
//
// The reference products draw blame in the editor's gutter. That is the better place and it is the host's
// gutter, not a plugin's: it needs a service for annotating lines in the viewer, which the plan records as
// host work (§6). A table is what a plugin can do well today, and it answers the same question.

import AppKit

@MainActor
final class GitBlameView: NSView {
    private let services: PcHostServices
    private let root: String
    private let path: String
    private var lines: [PluginGit.BlameLine] = []

    private let header = NSTextField(labelWithString: "")
    private let table = NSTableView()
    private let busy = NSProgressIndicator()

    init(services: PcHostServices, root: String, path: String) {
        self.services = services
        self.root = root
        self.path = path
        super.init(frame: NSRect(x: 0, y: 0, width: 760, height: 460))
        build()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.lineBreakMode = .byTruncatingMiddle
        header.stringValue = String(format: L("Blame: %@"), path)

        for (id, title, width) in [("commit", L("Commit"), 80), ("author", L("Author"), 130),
                                   ("date", L("Date"), 90), ("line", "", 46),
                                   ("text", "", 420)] as [(String, String, CGFloat)] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
        table.rowHeight = 16
        table.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(diffSelected)

        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [header, scroll, busy])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        let height = scroll.heightAnchor.constraint(greaterThanOrEqualTo: heightAnchor, multiplier: 0.7)
        height.priority = .init(999)
        height.isActive = true
    }

    private func reload() {
        busy.startAnimation(nil)
        let root = self.root, path = self.path
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.run(["-C", root] + PluginGit.blameArguments + [path])
            let parsed = result.ok ? PluginGit.parseBlame(result.out) : []
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.lines = parsed
                self.table.reloadData()
                if parsed.isEmpty {
                    self.header.stringValue = String(format: L("Blame: %@"), path) + " — "
                        + (result.ok ? L("No lines.") : result.out.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
    }

    /// The commit behind the selected line, compared with its parent.
    @objc private func diffSelected() {
        guard lines.indices.contains(table.selectedRow) else { return }
        let line = lines[table.selectedRow]
        guard !line.isUncommitted else {
            services.presentInfo?(services.host, L("Git"), L("That line is not committed yet."))
            return
        }
        let root = self.root, path = self.path
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let newer = PluginGitRepo.writeBlob(root: root, spec: "\(line.hash):\(path)",
                                                path: path, base: .head)
            let parentResult = PluginGitRepo.run(["-C", root, "rev-parse", "\(line.hash)^"])
            let parent = parentResult.ok
                ? parentResult.out.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            let older = parent.flatMap {
                PluginGitRepo.writeBlob(root: root, spec: "\($0):\(path)", path: path, base: .index)
            } ?? PluginGitRepo.writeEmptyBlob(path: path)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                guard let newer, let older else {
                    self.services.presentInfo?(self.services.host, L("Git"),
                                               L("That version could not be read."))
                    return
                }
                let short = String(line.hash.prefix(8))
                let leftTitle = parent.map { "\(String($0.prefix(8))):\(path)" } ?? L("(added)")
                older.withCString { a in
                    newer.withCString { b in
                        leftTitle.withCString { at in
                            "\(short):\(path)".withCString { bt in
                                self.services.compareFiles?(self.services.host, a, b, at, bt)
                            }
                        }
                    }
                }
            }
        }
    }
}

extension GitBlameView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { lines.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, lines.indices.contains(row) else { return nil }
        let line = lines[row]
        let identifier = NSUserInterfaceItemIdentifier("GitBlameCell")
        let field = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField)
            ?? {
                let f = NSTextField(labelWithString: "")
                f.identifier = identifier
                f.usesSingleLineMode = true
                f.lineBreakMode = .byTruncatingTail
                f.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                return f
            }()
        switch tableColumn.identifier.rawValue {
        case "commit":
            field.stringValue = line.isUncommitted ? L("(uncommitted)") : String(line.hash.prefix(8))
            field.textColor = line.isUncommitted ? .secondaryLabelColor : .labelColor
        case "author":
            field.stringValue = line.author
        case "date":
            field.stringValue = line.isUncommitted ? "" : Self.dateFormatter.string(from: line.date)
        case "line":
            field.stringValue = String(line.line)
            field.alignment = .right
        default:
            field.stringValue = line.text
            field.toolTip = line.summary
            field.alignment = .left
        }
        return field
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .none; return f
    }()
}
