// SPDX-License-Identifier: Apache-2.0
// GitCommitDetailView.swift — the panel's Commit tab: everything git knows about one commit.
//
// Phase 6. Author and committer are shown apart because they differ exactly when it matters (a rebase,
// a cherry-pick, a patch applied for someone else); the parents are links that select that commit in
// the history; the signature line is git's own `%G?` verdict, so a signed history can be checked at a
// glance without a terminal.

import AppKit

@MainActor
final class GitCommitDetailView: NSView, NSTextViewDelegate {
    /// A parent link was clicked.
    var onSelectCommit: ((String) -> Void)?

    private let textView = NSTextView()
    private let scroll = NSScrollView()
    private var theme: PluginTheme
    /// The commit being loaded; a result for any other is dropped (the selection moved on meanwhile).
    private var loading: String?
    /// The commit on screen. Asked for again — every panel reload re-reports the selection — it is left
    /// alone: re-reading would run gpg for `%G?` and throw away the reader's text selection and scroll.
    private var shown: String?

    init(theme: PluginTheme) {
        self.theme = theme
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.delegate = self
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        applyTheme(theme)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyTheme(_ theme: PluginTheme) {
        self.theme = theme
        textView.backgroundColor = theme.background
        scroll.backgroundColor = theme.background
        textView.linkTextAttributes = [.foregroundColor: theme.accent, .cursor: NSCursor.pointingHand]
    }

    func show(commit: PluginGit.Commit, root: String) {
        guard commit.hash != shown, commit.hash != loading else { return }
        loading = commit.hash
        let hash = commit.hash
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.run(["-C", root] + PluginGit.detailsArguments(hash))
            let details = result.ok ? PluginGit.parseDetails(result.out) : nil
            DispatchQueue.main.async {
                guard let self, self.loading == hash else { return }
                self.loading = nil
                self.shown = hash
                self.render(details, fallback: commit)
            }
        }
    }

    private func render(_ details: PluginGit.CommitDetails?, fallback: PluginGit.Commit) {
        let out = NSMutableAttributedString()
        let body = NSFont.systemFont(ofSize: 11)
        let label: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium),
                                                     .foregroundColor: theme.secondaryText]
        let value: [NSAttributedString.Key: Any] = [.font: body, .foregroundColor: theme.text]
        let mono: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                                                    .foregroundColor: theme.text]
        func row(_ name: String, _ text: NSAttributedString) {
            out.append(NSAttributedString(string: name + "\t", attributes: label))
            out.append(text)
            out.append(NSAttributedString(string: "\n", attributes: value))
        }
        guard let details else {
            out.append(NSAttributedString(string: fallback.subject, attributes: value))
            textView.textStorage?.setAttributedString(out)
            return
        }
        let dates = gitDateFormatter
        row(L("Author"), NSAttributedString(
            string: "\(details.authorName) <\(details.authorEmail)>   \(dates.string(from: details.authorDate))",
            attributes: value))
        if details.committerEmail != details.authorEmail || details.commitDate != details.authorDate {
            row(L("Committer"), NSAttributedString(
                string: "\(details.committerName) <\(details.committerEmail)>   \(dates.string(from: details.commitDate))",
                attributes: value))
        }
        row(L("Hash"), NSAttributedString(string: details.hash, attributes: mono))
        if !details.parents.isEmpty {
            let links = NSMutableAttributedString()
            for (index, parent) in details.parents.enumerated() {
                if index > 0 { links.append(NSAttributedString(string: "  ", attributes: mono)) }
                var attributes = mono
                attributes[.link] = "gitcommit:\(parent)"
                links.append(NSAttributedString(string: String(parent.prefix(10)), attributes: attributes))
            }
            row(details.parents.count > 1 ? L("Parents") : L("Parent"), links)
        }
        let refs = details.refs.filter { !$0.name.hasSuffix("/HEAD") }.map(\.name)
        if !refs.isEmpty { row(L("Refs"), NSAttributedString(string: refs.joined(separator: ", "), attributes: value)) }
        if let signature = signatureText(details.signature) {
            row(L("Signature"), NSAttributedString(string: signature, attributes: value))
        }
        // The labels line up on one tab stop, and a long value wraps under its value, not under its label.
        // Only the field rows: the message below keeps its own line breaks without an indent.
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: 84)]
        paragraph.defaultTabInterval = 84
        paragraph.headIndent = 84
        out.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: out.length))
        out.append(NSAttributedString(string: "\n", attributes: value))
        let lines = details.message.components(separatedBy: "\n")
        out.append(NSAttributedString(string: lines.first ?? "", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: theme.text]))
        let rest = lines.dropFirst().joined(separator: "\n")
        if !rest.isEmpty { out.append(NSAttributedString(string: "\n" + rest, attributes: value)) }
        textView.textStorage?.setAttributedString(out)
    }

    /// git's `%G?` letters, said in words. N (no signature) says nothing at all: most histories are unsigned.
    private func signatureText(_ letter: String) -> String? {
        switch letter {
        case "G": return L("Good signature")
        case "U": return L("Good signature, untrusted key")
        case "X", "Y": return L("Good signature, expired")
        case "R": return L("Good signature, revoked key")
        case "B": return L("Bad signature")
        case "E": return L("Signed, but the key is not available")
        default: return nil
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let text = link as? String, text.hasPrefix("gitcommit:") else { return false }
        onSelectCommit?(String(text.dropFirst("gitcommit:".count)))
        return true
    }
}
