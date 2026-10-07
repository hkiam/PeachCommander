// SPDX-License-Identifier: Apache-2.0
// GitSettings.swift — Settings ▸ Git: the store behind it, and the page itself.
//
// Phase 8. The decisions that change how the plugin talks to git — how a pull joins diverged branches,
// whether a first push sets an upstream, how often to fetch, what the history shows, how commits are
// made — had no place at all; each was a fixed choice in the code. They live in `git.ini` under the
// host's configuration root (so a scripted `-ConfigRoot` run never touches the reader's own), the model
// and its parsing in `PluginGit.Settings`, which is where they are tested.
//
// Name and e-mail are different: they are git's (`user.name`, `user.email`), so the page reads and
// writes them with `git config --global` — a commit made in a terminal carries the same ones.

import AppKit

/// The current settings, read once and re-read after the page saves. Changing them posts
/// `GitSettingsStore.changed`, which the panel follows.
enum GitSettingsStore {
    static let changed = Notification.Name("PCGitSettingsChanged")

    /// The host's configuration root; set from `PcMakeView` and `PcRunCommand` whenever the host says it.
    nonisolated(unsafe) static var configRoot = NSHomeDirectory() + "/Library/Application Support/PeachCommander"
    private nonisolated(unsafe) static var cached: PluginGit.Settings?
    private static let lock = NSLock()

    static var fileURL: URL {
        URL(fileURLWithPath: configRoot).appendingPathComponent("Git", isDirectory: true)
            .appendingPathComponent("git.ini")
    }

    static var current: PluginGit.Settings {
        lock.lock(); defer { lock.unlock() }
        if let cached { return cached }
        let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let settings = PluginGit.Settings.parse(text)
        cached = settings
        return settings
    }

    static func save(_ settings: PluginGit.Settings) {
        let url = fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? settings.serialized().write(to: url, atomically: true, encoding: .utf8)
        lock.lock(); let program = cached?.gitProgram; cached = settings; lock.unlock()
        if program != settings.gitProgram { PluginGitRepo.forgetExecutable() }
        NotificationCenter.default.post(name: changed, object: nil)
    }

    /// Take the host's configuration root, when it answers `configRoot`.
    static func adoptConfigRoot(_ services: PcHostServices) {
        guard let get = services.getContext else { return }
        var buffer = [CChar](repeating: 0, count: 4096)
        if "configRoot".withCString({ get(services.host, $0, &buffer, 4096) }) == 1 {
            let root = String(cString: buffer)
            if !root.isEmpty, root != configRoot {
                configRoot = root
                lock.lock(); cached = nil; lock.unlock()
            }
        }
    }
}

/// The page under Settings ▸ Git.
@MainActor
final class GitSettingsView: NSView {
    private var settings = GitSettingsStore.current

    private let gitProgram = NSTextField()
    private let userName = NSTextField()
    private let userEmail = NSTextField()
    private let pullMode = NSPopUpButton()
    private let pushSetsUpstream = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fetchPrunes = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoFetch = NSPopUpButton()
    private let pageSize = NSPopUpButton()
    private let showRemoteBranches = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showTags = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showStashes = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dateStyle = NSPopUpButton()
    private let signCommits = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let signOff = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let runHooks = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let subjectLength = NSTextField()
    private let ignoreWhitespace = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let contextLines = NSTextField()
    private let cloneRecursive = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let gitVersion = NSTextField(labelWithString: "")

    private static let fetchChoices = [0, 5, 15, 30, 60]
    private static let pageChoices = [100, 300, 1000, 3000]

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: 600))
        build()
        show()
        loadIdentity()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Layout

    private func build() {
        for (button, title) in [
            (pushSetsUpstream, L("The first push of a branch sets its upstream")),
            (fetchPrunes, L("Fetch removes remote branches that are gone on the server")),
            (showRemoteBranches, L("Show remote branches")),
            (showTags, L("Show tags")),
            (showStashes, L("Show stashes")),
            (signCommits, L("Sign commits (GPG or SSH, as git is configured)")),
            (signOff, L("Add a Signed-off-by line")),
            (runHooks, L("Run the repository's commit hooks")),
            (ignoreWhitespace, L("Ignore whitespace changes in a commit's changes")),
            (cloneRecursive, L("Clone with submodules")),
        ] as [(NSButton, String)] {
            button.title = title
            button.target = self
            button.action = #selector(changed)
        }
        pullMode.addItems(withTitles: [L("Fast-forward only (refuse when the branches diverged)"),
                                       L("Merge"), L("Rebase")])
        autoFetch.addItems(withTitles: Self.fetchChoices.map { $0 == 0 ? L("Never") : String(format: L("Every %lld minutes"), $0) })
        pageSize.addItems(withTitles: Self.pageChoices.map { String(format: L("%lld commits"), $0) })
        dateStyle.addItems(withTitles: [L("Relative (2 hours ago)"), L("Date and time")])
        for popUp in [pullMode, autoFetch, pageSize, dateStyle] {
            popUp.target = self
            popUp.action = #selector(changed)
        }
        for field in [gitProgram, subjectLength, contextLines] {
            field.target = self
            field.action = #selector(changed)
            field.delegate = self
        }
        for field in [userName, userEmail] {
            field.target = self
            field.action = #selector(identityChanged)
            field.delegate = self
        }
        gitProgram.placeholderString = L("Found automatically")
        userName.placeholderString = L("Name for commits")
        userEmail.placeholderString = L("E-mail for commits")
        gitVersion.textColor = .secondaryLabelColor
        gitVersion.font = .systemFont(ofSize: 11)

        let rows = NSStackView(views: [
            heading(L("Git and identity")),
            row(L("Git program:"), gitProgram),
            gitVersion,
            row(L("Name:"), userName),
            row(L("E-mail:"), userEmail),
            note(L("Name and e-mail are git's own settings for all repositories (git config --global). Repository Settings can give a single repository others.")),
            heading(L("Synchronizing")),
            row(L("Pull:"), pullMode),
            pushSetsUpstream,
            fetchPrunes,
            row(L("Fetch in the background:"), autoFetch),
            cloneRecursive,
            heading(L("History")),
            row(L("Load at a time:"), pageSize),
            showRemoteBranches, showTags, showStashes,
            row(L("Dates:"), dateStyle),
            heading(L("Commits")),
            signCommits, signOff, runHooks,
            row(L("Mark the subject past (characters):"), subjectLength, fieldWidth: 60),
            heading(L("Changes")),
            ignoreWhitespace,
            row(L("Lines of context around a change:"), contextLines, fieldWidth: 60),
        ])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 8
        rows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rows)
        for field in [gitProgram, userName, userEmail] {
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        }
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            rows.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            // The bottom gives the page its height: the host sizes a contributed page by what it says it
            // needs, and a page pinned only at the top is nothing tall (the Docker page's lesson).
            bottomAnchor.constraint(greaterThanOrEqualTo: rows.bottomAnchor, constant: 18),
        ])
    }

    private func heading(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func note(_ text: String) -> NSView {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 520
        return label
    }

    /// A label and a control on one line; the label does not grow (two views hugging at the same priority
    /// make AppKit split the row between them — the defect the Docker connect dialog shipped with).
    private func row(_ title: String, _ control: NSView, fieldWidth: CGFloat? = nil) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        let stack = NSStackView(views: [label, control])
        stack.orientation = .horizontal
        stack.spacing = 8
        if let fieldWidth { control.widthAnchor.constraint(equalToConstant: fieldWidth).isActive = true }
        return stack
    }

    // MARK: Values

    private func show() {
        gitProgram.stringValue = settings.gitProgram
        pullMode.selectItem(at: PluginGit.Settings.PullMode.allCases.firstIndex(of: settings.pullMode) ?? 0)
        pushSetsUpstream.state = settings.pushSetsUpstream ? .on : .off
        fetchPrunes.state = settings.fetchPrunes ? .on : .off
        autoFetch.selectItem(at: Self.fetchChoices.firstIndex(of: settings.autoFetchMinutes)
                             ?? Self.fetchChoices.firstIndex { $0 >= settings.autoFetchMinutes } ?? 0)
        pageSize.selectItem(at: Self.pageChoices.firstIndex(of: settings.historyPageSize)
                            ?? Self.pageChoices.firstIndex { $0 >= settings.historyPageSize } ?? 1)
        showRemoteBranches.state = settings.showRemoteBranches ? .on : .off
        showTags.state = settings.showTags ? .on : .off
        showStashes.state = settings.showStashes ? .on : .off
        dateStyle.selectItem(at: settings.dateStyle == .relative ? 0 : 1)
        signCommits.state = settings.signCommits ? .on : .off
        signOff.state = settings.signOff ? .on : .off
        runHooks.state = settings.runHooks ? .on : .off
        subjectLength.stringValue = String(settings.subjectLength)
        ignoreWhitespace.state = settings.diffIgnoreWhitespace ? .on : .off
        contextLines.stringValue = String(settings.diffContextLines)
        cloneRecursive.state = settings.cloneRecursive ? .on : .off
        showGitVersion()
    }

    /// Which git this is — so a wrong path is noticed here, not at the next commit.
    private func showGitVersion() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let path = PluginGitRepo.executable()
            let version = path == nil ? "" : PluginGitRepo.run(["--version"]).out.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { [weak self] in
                self?.gitVersion.stringValue = path.map { "\($0) — \(version)" } ?? L("Git was not found on this Mac.")
                self?.gitVersion.textColor = path == nil ? .systemRed : .secondaryLabelColor
            }
        }
    }

    /// Read the controls back and save. A number emptied or typed wrong keeps its value (`parse` clamps).
    @objc private func changed() {
        settings.gitProgram = gitProgram.stringValue.trimmingCharacters(in: .whitespaces)
        settings.pullMode = PluginGit.Settings.PullMode.allCases[max(0, pullMode.indexOfSelectedItem)]
        settings.pushSetsUpstream = pushSetsUpstream.state == .on
        settings.fetchPrunes = fetchPrunes.state == .on
        settings.autoFetchMinutes = Self.fetchChoices[max(0, autoFetch.indexOfSelectedItem)]
        settings.historyPageSize = Self.pageChoices[max(0, pageSize.indexOfSelectedItem)]
        settings.showRemoteBranches = showRemoteBranches.state == .on
        settings.showTags = showTags.state == .on
        settings.showStashes = showStashes.state == .on
        settings.dateStyle = dateStyle.indexOfSelectedItem == 0 ? .relative : .absolute
        settings.signCommits = signCommits.state == .on
        settings.signOff = signOff.state == .on
        settings.runHooks = runHooks.state == .on
        settings.subjectLength = Int(subjectLength.stringValue).map { min(max($0, 20), 200) } ?? settings.subjectLength
        settings.diffIgnoreWhitespace = ignoreWhitespace.state == .on
        settings.diffContextLines = Int(contextLines.stringValue).map { min(max($0, 0), 50) } ?? settings.diffContextLines
        settings.cloneRecursive = cloneRecursive.state == .on
        // Return and the end of editing both land here, and so does every focus change: only a real
        // change is written — each save reloads every open panel.
        if settings != GitSettingsStore.current { GitSettingsStore.save(settings) }
        show()
    }

    // MARK: Identity (git's own settings)

    private var loadedName = "", loadedEmail = ""

    private func loadIdentity() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let name = PluginGitRepo.run(["config", "--global", "user.name"]).out.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = PluginGitRepo.run(["config", "--global", "user.email"]).out.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { [weak self] in
                self?.loadedName = name; self?.loadedEmail = email
                self?.userName.stringValue = name
                self?.userEmail.stringValue = email
            }
        }
    }

    /// Written only when it changed — and an emptied field removes the setting rather than setting "".
    @objc private func identityChanged() {
        let name = userName.stringValue.trimmingCharacters(in: .whitespaces)
        let email = userEmail.stringValue.trimmingCharacters(in: .whitespaces)
        var calls: [[String]] = []
        if name != loadedName {
            calls.append(name.isEmpty ? ["config", "--global", "--unset", "user.name"] : ["config", "--global", "user.name", name])
        }
        if email != loadedEmail {
            calls.append(email.isEmpty ? ["config", "--global", "--unset", "user.email"] : ["config", "--global", "user.email", email])
        }
        guard !calls.isEmpty else { return }
        loadedName = name; loadedEmail = email
        DispatchQueue.global(qos: .utility).async { for call in calls { _ = PluginGitRepo.run(call) } }
    }
}

extension GitSettingsView: NSTextFieldDelegate {
    /// Saved when a field loses focus as well as on Return: a settings page has no OK button.
    func controlTextDidEndEditing(_ notification: Notification) {
        if let field = notification.object as? NSTextField, field === userName || field === userEmail {
            identityChanged()
        } else {
            changed()
        }
    }
}
