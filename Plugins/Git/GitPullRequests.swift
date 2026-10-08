// SPDX-License-Identifier: Apache-2.0
// GitPullRequests.swift — pull requests, issues and CI status at GitHub and GitLab (phase 9).
//
// The window lists the open pull requests (merge requests at GitLab) and issues of the project the
// remotes point at, shows the selected one with its checks, checks a pull request out into a local
// branch, and opens a new one for the current branch. The panel's header carries the current commit's
// CI verdict as a dot that opens this window.
//
// The service is spoken to with the reader's personal access token, kept in the Keychain through the
// host's `crypt` service (GitHostingToken) — asked for here, in the window, the first time it is needed.
// Requests, answers and the rule that the token only ever goes to the project's own API host are in
// Plugins/SDK/PluginGitHosting.swift, where they are tested.

import AppKit

// MARK: - The token

/// A host's token in the Keychain, remembered for the session once read: a reload of the panel asks for
/// the CI status, and the Keychain need not be asked every time.
@MainActor
enum GitHostingToken {
    private static var cache: [String: String] = [:]

    static func load(_ host: String, _ services: PcHostServices) -> String? {
        if let cached = cache[host] { return cached.isEmpty ? nil : cached }
        var buffer = [CChar](repeating: 0, count: 2048)
        let code = PluginGit.tokenStore(host: host).withCString { store in
            services.crypt?(services.host, Int32(PC_CRYPT_COPY_PASSWORD), store, &buffer, Int32(buffer.count))
        }
        let token = code == Int32(PC_OK) ? String(cString: buffer) : ""
        cache[host] = token
        return token.isEmpty ? nil : token
    }

    static func save(_ token: String, host: String, _ services: PcHostServices) -> Bool {
        var bytes = Array(token.utf8CString)
        let code = PluginGit.tokenStore(host: host).withCString { store in
            services.crypt?(services.host, Int32(PC_CRYPT_SAVE_PASSWORD), store, &bytes, Int32(bytes.count))
        }
        guard code == Int32(PC_OK) else { return false }
        cache[host] = token
        return true
    }

    static func delete(host: String, _ services: PcHostServices) {
        var empty: [CChar] = [0]
        _ = PluginGit.tokenStore(host: host).withCString { store in
            services.crypt?(services.host, Int32(PC_CRYPT_DELETE), store, &empty, 1)
        }
        cache[host] = ""
    }
}

// MARK: - The panel's CI dot

/// CI verdicts by commit, for a while: a finished one does not change, a running one is asked again
/// after a minute.
@MainActor private var ciCache: [String: (status: PluginGit.CIStatus, at: Date)] = [:]
/// The commits whose CI is being asked for right now: a reload while the answer is on its way does not
/// ask again (every save in the repository reloads the panel).
@MainActor private var ciAsking: Set<String> = []

extension GitPanelView {
    func setUpCIButton() {
        ciButton.isBordered = false
        ciButton.bezelStyle = .texturedRounded
        ciButton.imagePosition = .imageOnly
        ciButton.target = self
        ciButton.action = #selector(openPullRequests)
        ciButton.isHidden = true
    }

    @objc func openPullRequests() {
        guard let root else { return }
        showPullRequestsWindow(root: root, services)
    }

    /// The dot for the current commit — only when the remotes are a known project and a token is there;
    /// otherwise nothing, rather than a dot that means "not set up".
    func updateCI() {
        guard let project = hostingProject, let sha = headSHA,
              let token = GitHostingToken.load(project.host, services) else {
            ciButton.isHidden = true
            return
        }
        if let cached = ciCache[sha],
           Date().timeIntervalSince(cached.at) < (cached.status.state == .pending ? 60 : 600) {
            showCI(cached.status)
            return
        }
        guard !ciAsking.contains(sha) else { return }
        ciAsking.insert(sha)
        let client = PluginGitHostingClient(project: project, token: token)
        GitCI.load(client: client, project: project, sha: sha) { [weak self] status in
            ciAsking.remove(sha)
            // No answer is not "no CI": it is not remembered, so the next reload asks again.
            guard let status else { return }
            ciCache[sha] = (status, Date())
            guard let self, self.headSHA == sha else { return }
            self.showCI(status)
        }
    }

    private func showCI(_ status: PluginGit.CIStatus) {
        guard status.state != .none else { ciButton.isHidden = true; return }
        ciButton.isHidden = false
        ciButton.image = GitCI.image(status.state)
        ciButton.toolTip = GitCI.summary(status) + "\n" + L("Click for the pull requests window.")
    }
}

/// Asking for a commit's CI and saying what came back.
@MainActor
enum GitCI {
    /// Both GitHub calls (check runs and statuses) or GitLab's one, then the verdict — on the main thread.
    /// nil when the service could not be asked (no network, an error status): unknown, not "no CI".
    static func load(client: PluginGitHostingClient, project: PluginGit.HostingProject, sha: String,
                     completion: @escaping @MainActor (PluginGit.CIStatus?) -> Void) {
        let requests = PluginGit.ciRequests(project, sha: sha)
        let answers = AnswerBox(count: requests.count)
        let group = DispatchGroup()
        for (index, request) in requests.enumerated() {
            group.enter()
            client.send(request) { response, _ in
                answers.set(index, response?.ok == true ? response?.data : nil)
                group.leave()
            }
        }
        group.notify(queue: .main) {
            let data = answers.all()
            guard data.contains(where: { $0 != nil }) else {
                MainActor.assumeIsolated { completion(nil) }
                return
            }
            let status = project.kind == .github
                ? PluginGit.parseGitHubCI(checkRuns: data[0], status: data.count > 1 ? data[1] : nil)
                : PluginGit.parseGitLabCI(data[0])
            MainActor.assumeIsolated { completion(status) }
        }
    }

    static func color(_ state: PluginGit.CIState) -> NSColor {
        switch state {
        case .success: return .systemGreen
        case .failure: return .systemRed
        case .pending: return .systemOrange
        case .none: return .tertiaryLabelColor
        }
    }

    static func image(_ state: PluginGit.CIState) -> NSImage? {
        let symbol: String
        switch state {
        case .success: symbol = "checkmark.circle.fill"
        case .failure: symbol = "xmark.circle.fill"
        case .pending: symbol = "clock.fill"
        case .none: symbol = "circle"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: word(state))
        return image?.withSymbolConfiguration(.init(paletteColors: [color(state)]))
    }

    static func word(_ state: PluginGit.CIState) -> String {
        switch state {
        case .success: return L("CI passed")
        case .failure: return L("CI failed")
        case .pending: return L("CI running")
        case .none: return L("No CI")
        }
    }

    static func summary(_ status: PluginGit.CIStatus) -> String {
        ([word(status.state)] + status.checks.map { "  \(symbol($0.state)) \($0.name)" }).joined(separator: "\n")
    }

    static func symbol(_ state: PluginGit.CIState) -> String {
        switch state {
        case .success: return "✓"
        case .failure: return "✗"
        case .pending: return "…"
        case .none: return "·"
        }
    }
}

/// Answers arriving on URLSession's queue, collected by index.
private final class AnswerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Data?]
    init(count: Int) { values = Array(repeating: nil, count: count) }
    func set(_ index: Int, _ data: Data?) { lock.lock(); values[index] = data; lock.unlock() }
    func all() -> [Data?] { lock.lock(); defer { lock.unlock() }; return values }
}

// MARK: - The window

@MainActor
func showPullRequestsWindow(root: String, _ svc: PcHostServices) {
    showToolWindow(title: String(format: L("Pull Requests — %@"), (root as NSString).lastPathComponent),
                   view: GitPullRequestsView(services: svc, root: root), size: NSSize(width: 960, height: 600), svc)
}

@MainActor
final class GitPullRequestsView: NSView {
    private let services: PcHostServices
    private let root: String
    private var theme: PluginTheme
    private var project: PluginGit.HostingProject?
    private var client: PluginGitHostingClient?

    private enum Tab: Int { case pullRequests, issues }
    private var tab = Tab.pullRequests
    private var pulls: [PluginGit.PullRequest] = []
    private var issues: [PluginGit.Issue] = []
    private var defaultBranch: String?
    /// The selected pull request's checks, by number; loaded when it is selected.
    private var checks: [Int: PluginGit.CIStatus] = [:]

    private let header = NSTextField(labelWithString: "")
    private let tabs = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
    private let busy = NSProgressIndicator()
    private let table = GitTable()
    private let detail = NSTextView.scrollableTextView()
    private let statusLine = NSTextField(labelWithString: "")
    private let setupBox = NSStackView()
    private let setupLabel = NSTextField(wrappingLabelWithString: "")
    private let createTokenButton = NSButton()
    private let enterTokenButton = NSButton()
    private let webButton = NSButton()
    private let checkoutButton = NSButton()
    private let createButton = NSButton()
    private let refreshButton = NSButton()
    private let forgetButton = NSButton()
    private var preferredWidth: [NSUserInterfaceItemIdentifier: CGFloat] = [:]

    init(services: PcHostServices, root: String) {
        self.services = services
        self.root = root
        self.theme = PluginTheme(services)
        super.init(frame: NSRect(x: 0, y: 0, width: 960, height: 600))
        build()
        applyTheme()
        start()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var detailText: NSTextView { detail.documentView as! NSTextView }

    // MARK: Building

    private func build() {
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.lineBreakMode = .byTruncatingMiddle
        tabs.segmentCount = 2
        tabs.setLabel(L("Pull requests"), forSegment: 0)
        tabs.setLabel(L("Issues"), forSegment: 1)
        tabs.selectedSegment = 0
        tabs.target = self
        tabs.action = #selector(tabChanged)
        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false
        for (button, title, action) in [
            (refreshButton, L("Refresh"), #selector(refresh)),
            (webButton, L("Open on the Web"), #selector(openOnWeb)),
            (checkoutButton, L("Check out…"), #selector(checkOut)),
            (createButton, L("New pull request…"), #selector(createPullRequest)),
            (createTokenButton, L("Create a token on the web…"), #selector(createToken)),
            (enterTokenButton, L("Enter token…"), #selector(enterToken)),
            (forgetButton, L("Remove token…"), #selector(forgetToken)),
        ] as [(NSButton, String, Selector)] {
            button.title = title
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.target = self
            button.action = action
        }
        let top = NSStackView(views: [header, busy, tabs, refreshButton])
        top.orientation = .horizontal
        top.spacing = 8
        header.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        setupLabel.font = .systemFont(ofSize: 12)
        setupBox.setViews([setupLabel, NSStackView(views: [createTokenButton, enterTokenButton])], in: .top)
        setupBox.orientation = .vertical
        setupBox.alignment = .leading
        setupBox.spacing = 8
        setupBox.isHidden = true

        table.rowHeight = 20
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.allowsMultipleSelection = false
        for (id, title, width) in [("number", "#", 50), ("title", L("Title"), 360), ("author", L("Author"), 110),
                                   ("branch", L("Branch"), 220), ("updated", L("Updated"), 110)] as [(String, String, CGFloat)] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = width
            column.minWidth = min(width, 40)
            column.resizingMask = [.autoresizingMask, .userResizingMask]
            preferredWidth[column.identifier] = width
            table.addTableColumn(column)
        }
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(openOnWeb)
        table.onEnter = { [weak self] in self?.openOnWeb() }
        table.menu = gitMenu([
            (L("Open on the Web"), #selector(openOnWeb)),
            (L("Check out…"), #selector(checkOut)),
            (nil, nil),
            (L("Copy link"), #selector(copyLink)),
        ], target: self)
        let tableScroll = NSScrollView()
        tableScroll.documentView = table
        tableScroll.hasVerticalScroller = true
        tableScroll.autohidesScrollers = true
        tableScroll.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(clipFrameChanged),
                                               name: NSView.frameDidChangeNotification, object: tableScroll.contentView)

        detailText.isEditable = false
        detailText.isRichText = true
        detailText.textContainerInset = NSSize(width: 6, height: 6)
        let split = NSSplitView()
        split.isVertical = false
        split.dividerStyle = .thin
        split.addArrangedSubview(tableScroll)
        split.addArrangedSubview(detail)
        let share = tableScroll.heightAnchor.constraint(equalTo: split.heightAnchor, multiplier: 0.55)
        share.priority = .init(500)
        share.isActive = true

        statusLine.font = .systemFont(ofSize: 11)
        statusLine.textColor = .secondaryLabelColor
        statusLine.lineBreakMode = .byTruncatingTail
        statusLine.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [statusLine, NSView(), forgetButton, webButton, checkoutButton, createButton])
        footer.orientation = .horizontal
        footer.spacing = 8

        let stack = NSStackView(views: [top, setupBox, split, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        for view in [top, setupBox, split, footer] as [NSView] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
        }
        split.setContentHuggingPriority(.init(1), for: .vertical)
        for view in [top, setupBox, footer] { view.setHuggingPriority(.defaultHigh, for: .vertical) }
        updateButtons()
    }

    func applyTheme() {
        theme = PluginTheme(services)
        wantsLayer = true
        layer?.backgroundColor = theme.windowBackground.cgColor
        header.textColor = theme.text
        setupLabel.textColor = theme.text
        table.backgroundColor = theme.background
        detailText.backgroundColor = theme.background
        table.reloadData()
        showDetail()
    }

    @objc private func clipFrameChanged() { gitFitColumns(table, preferred: preferredWidth) }

    // MARK: Setting up

    /// Which project, and whether there is a token for it: read the remotes, then the Keychain.
    private func start() {
        busy.startAnimation(nil)
        let root = self.root, kinds = GitSettingsStore.current.hostKinds
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let remotes = PluginGit.parseRemotes(PluginGitRepo.run(["-C", root] + PluginGit.remotesArguments).out)
            let project = PluginGit.hostingProject(remotes: remotes, kinds: kinds)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.project = project
                self.connect()
            }
        }
    }

    private func connect() {
        guard let project else {
            header.stringValue = (root as NSString).lastPathComponent
            showSetup(L("The remotes of this repository point at neither GitHub nor GitLab. For a self-hosted server, name its kind under Settings ▸ Git ▸ Hosting."),
                      tokenButtons: false)
            return
        }
        header.stringValue = String(format: L("%@ at %@"), project.path, project.host)
        guard let token = GitHostingToken.load(project.host, services) else {
            showSetup(String(format: L("A personal access token for %@ lets this window read and open pull requests and see CI. It is kept in the Keychain and sent only to %@."),
                             project.host, URL(string: project.apiBase)?.host ?? project.host),
                      tokenButtons: true)
            return
        }
        setupBox.isHidden = true
        client = PluginGitHostingClient(project: project, token: token)
        refresh()
    }

    private func showSetup(_ text: String, tokenButtons: Bool) {
        setupLabel.stringValue = text
        createTokenButton.isHidden = !tokenButtons
        enterTokenButton.isHidden = !tokenButtons
        setupBox.isHidden = false
        client = nil
        pulls = []; issues = []
        table.reloadData()
        showDetail()
        updateButtons()
    }

    @objc private func createToken() {
        guard let project, let url = URL(string: PluginGit.tokenCreationURL(project)) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func enterToken() {
        guard let project else { return }
        let alert = NSAlert()
        alert.messageText = String(format: L("Token for %@"), project.host)
        alert.informativeText = project.kind == .github
            ? L("A classic token with the “repo” scope, or a fine-grained one with read and write access to pull requests and read access to checks.")
            : L("A personal access token with the “api” scope.")
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 22))
        alert.accessoryView = field
        alert.addButton(withTitle: L("Save"))
        alert.addButton(withTitle: L("Cancel"))
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let token = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        guard GitHostingToken.save(token, host: project.host, services) else {
            GitCommitActions.report(services, L("Pull requests"), L("The token could not be stored in the Keychain."))
            return
        }
        connect()
    }

    @objc private func forgetToken() {
        guard let project else { return }
        let alert = NSAlert()
        alert.messageText = String(format: L("Remove the token for %@ from the Keychain?"), project.host)
        alert.informativeText = L("The token itself stays valid at the service; revoke it there if it is no longer needed.")
        alert.addButton(withTitle: L("Remove"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        GitHostingToken.delete(host: project.host, services)
        connect()
    }

    // MARK: Loading

    @objc private func tabChanged() {
        tab = Tab(rawValue: tabs.selectedSegment) ?? .pullRequests
        table.tableColumn(withIdentifier: .init("branch"))?.title = tab == .pullRequests ? L("Branch") : L("Labels")
        table.reloadData()
        showDetail()
        updateButtons()
    }

    @objc func refresh() {
        guard let client, let project else { return }
        busy.startAnimation(nil)
        statusLine.stringValue = ""
        let requests = [PluginGit.pullRequestsRequest(project), PluginGit.issuesRequest(project), PluginGit.projectRequest(project)]
        let answers = ResponseBox(count: requests.count)
        let group = DispatchGroup()
        for (index, request) in requests.enumerated() {
            group.enter()
            client.send(request) { response, error in
                answers.set(index, response, error)
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            MainActor.assumeIsolated { self?.received(answers.all(), kind: project.kind) }
        }
    }

    private func received(_ answers: [(PluginGitHostingClient.Response?, String?)], kind: PluginGit.HostKind) {
        busy.stopAnimation(nil)
        let (pullsAnswer, pullsError) = answers[0]
        guard let pullsAnswer else {
            statusLine.stringValue = pullsError ?? L("No answer.")
            return
        }
        if pullsAnswer.status == 401 {
            // A token that was revoked or mistyped: said, and the buttons to replace it shown.
            showSetup(L("The service did not accept the token (401). Enter a new one."), tokenButtons: true)
            return
        }
        guard pullsAnswer.ok else {
            statusLine.stringValue = PluginGit.apiErrorMessage(pullsAnswer.data, status: pullsAnswer.status)
            return
        }
        pulls = PluginGit.parsePullRequests(pullsAnswer.data, kind: kind) ?? []
        if let issuesAnswer = answers[1].0, issuesAnswer.ok { issues = PluginGit.parseIssues(issuesAnswer.data, kind: kind) ?? [] }
        if let projectAnswer = answers[2].0, projectAnswer.ok { defaultBranch = PluginGit.parseDefaultBranch(projectAnswer.data) }
        checks = [:]
        table.reloadData()
        if table.numberOfRows > 0, table.selectedRow < 0 {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        // Asked here as well: a row that stays selected across the reload posts no selection change,
        // and its checks were just thrown away with the rest.
        if let pull = selectedPull { loadChecks(pull) }
        showDetail()
        updateButtons()
        let remaining = PluginGit.rateLimitRemaining(pullsAnswer.headers)
        statusLine.stringValue = String(format: L("%lld open pull request(s), %lld open issue(s)."), pulls.count, issues.count)
            + (remaining.map { " " + String(format: L("%lld requests left this hour."), $0) } ?? "")
    }

    // MARK: Selection

    private var selectedPull: PluginGit.PullRequest? {
        tab == .pullRequests && pulls.indices.contains(table.selectedRow) ? pulls[table.selectedRow] : nil
    }

    private var selectedIssue: PluginGit.Issue? {
        tab == .issues && issues.indices.contains(table.selectedRow) ? issues[table.selectedRow] : nil
    }

    private var selectedURL: String? { selectedPull?.webURL ?? selectedIssue?.webURL }

    private func updateButtons() {
        let connected = client != nil
        webButton.isEnabled = selectedURL != nil
        checkoutButton.isEnabled = selectedPull != nil
        createButton.isEnabled = connected
        refreshButton.isEnabled = connected
        tabs.isEnabled = connected
        forgetButton.isHidden = !connected
    }

    private func showDetail() {
        let text = NSMutableAttributedString()
        func add(_ string: String, _ font: NSFont, _ color: NSColor) {
            text.append(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]))
        }
        let bold = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let body = NSFont.systemFont(ofSize: 12)
        let small = NSFont.systemFont(ofSize: 11)
        if let pull = selectedPull {
            add("#\(pull.number)  \(pull.title)\n", bold, theme.text)
            add(String(format: L("%@ wants to merge %@ into %@"), pull.author, pull.sourceBranch, pull.targetBranch)
                + (pull.isDraft ? " · " + L("draft") : "") + "\n\n", small, theme.secondaryText)
            if let status = checks[pull.number] {
                add(GitCI.summary(status) + "\n\n", small, GitCI.color(status.state))
            } else if pull.headSHA != nil {
                add(L("Checks are being read…") + "\n\n", small, theme.secondaryText)
            }
            add(pull.body.isEmpty ? L("No description.") : pull.body, body, theme.text)
        } else if let issue = selectedIssue {
            add("#\(issue.number)  \(issue.title)\n", bold, theme.text)
            add(issue.author + (issue.labels.isEmpty ? "" : " · " + issue.labels.joined(separator: ", ")) + "\n\n",
                small, theme.secondaryText)
            add(issue.body.isEmpty ? L("No description.") : issue.body, body, theme.text)
        }
        detailText.textStorage?.setAttributedString(text)
    }

    private func loadChecks(_ pull: PluginGit.PullRequest) {
        guard checks[pull.number] == nil, let sha = pull.headSHA, let client, let project else { return }
        GitCI.load(client: client, project: project, sha: sha) { [weak self] status in
            self?.checks[pull.number] = status ?? PluginGit.CIStatus.none
            if self?.selectedPull?.number == pull.number { self?.showDetail() }
        }
    }

    // MARK: Actions

    @objc private func openOnWeb() {
        guard let link = selectedURL, let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func copyLink() {
        if let link = selectedURL { gitCopyToClipboard(link) }
    }

    /// The pull request's commits into a local branch of its own (`pr/12`, `mr/12`), then switched to —
    /// a fork's branch included, since both services publish every pull request under a ref.
    @objc private func checkOut() {
        guard let pull = selectedPull, let project else { return }
        let fetch = PluginGit.fetchPullRequestArguments(project, number: pull.number)
        let alert = NSAlert()
        alert.messageText = String(format: L("Check out #%lld as %@?"), pull.number, fetch.branch)
        alert.informativeText = L("Its commits are fetched into that branch, replacing an older copy of it, and the branch is checked out. Local changes stay as they are; git refuses if they would be overwritten.")
        alert.addButton(withTitle: L("Check out"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let root = self.root, box = ServicesBox(services)
        let update = PluginGit.updatePullRequestArguments(project, number: pull.number)
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Already on that branch: git will not fetch into it, so it is brought forward instead.
            let current = PluginGitRepo.status(root: root)?.branch
            var result: (out: String, ok: Bool) = ("", true)
            let calls = current == fetch.branch ? update : [fetch.arguments, ["switch", fetch.branch]]
            for call in calls {
                result = PluginGitRepo.run(["-C", root] + call, combined: true)
                if !result.ok { break }
            }
            DispatchQueue.main.async {
                self?.busy.stopAnimation(nil)
                PluginGitRepo.invalidate()
                box.services.reloadActivePanel?(box.services.host)
                if result.ok {
                    self?.statusLine.stringValue = String(format: L("%@ checked out."), fetch.branch)
                } else {
                    GitCommitActions.report(box.services, L("Pull requests"), result.out)
                }
            }
        }
    }

    /// A pull request for the current branch: pushed first when it has no upstream yet, prefilled from
    /// its commits, into the project's default branch unless the reader picks another.
    @objc private func createPullRequest() {
        guard let project, let client else { return }
        let root = self.root
        busy.startAnimation(nil)
        let base = defaultBranch ?? "main"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let status = PluginGitRepo.status(root: root)
            let range = "\(project.remote)/\(base)..HEAD"
            let subjects = PluginGitRepo.run(["-C", root, "log", "--format=%s", range]).out
                .split(separator: "\n").map(String.init)
            let first = subjects.count == 1 ? PluginGitRepo.run(["-C", root, "log", "-1", "--format=%B"]).out : nil
            let remoteBranches = PluginGitRepo.run(["-C", root, "for-each-ref", "--format=%(refname:lstrip=3)",
                                                     "refs/remotes/\(project.remote)"]).out
                .split(separator: "\n").map(String.init).filter { $0 != "HEAD" }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                guard let status, !status.detached, !status.branch.isEmpty else {
                    GitCommitActions.report(self.services, L("Pull requests"), L("Check out a branch first: a pull request is made from a branch."))
                    return
                }
                let draft = PluginGit.pullRequestDraft(subjects: subjects, firstMessage: first)
                let push = PluginGit.pushBeforePullRequest(branch: status.branch, upstream: status.upstream,
                                                           ahead: status.ahead, remote: project.remote)
                self.askForPullRequest(project: project, client: client, branch: status.branch,
                                       push: push, bases: remoteBranches, base: base, draft: draft)
            }
        }
    }

    private func askForPullRequest(project: PluginGit.HostingProject, client: PluginGitHostingClient, branch: String,
                                   push: [String]?, bases: [String], base: String, draft: (title: String, body: String)) {
        let alert = NSAlert()
        alert.messageText = String(format: L("New pull request from %@"), branch)
        alert.informativeText = push == nil ? "" : String(format: L("The branch is pushed to %@ first."), project.remote)
        let width: CGFloat = 460
        let title = NSTextField(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        title.stringValue = draft.title
        title.placeholderString = L("Title")
        let bodyScroll = NSTextView.scrollableTextView()
        bodyScroll.frame = NSRect(x: 0, y: 0, width: width, height: 140)
        bodyScroll.borderType = .bezelBorder
        let body = bodyScroll.documentView as! NSTextView
        body.string = draft.body
        body.font = .systemFont(ofSize: 12)
        body.isRichText = false
        let basePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        let candidates = bases.filter { $0 != branch }
        basePopup.addItems(withTitles: candidates.isEmpty ? [base] : candidates)
        basePopup.selectItem(withTitle: base)
        let draftBox = NSButton(checkboxWithTitle: L("Draft"), target: nil, action: nil)
        let baseRow = NSStackView(views: [NSTextField(labelWithString: L("Into:")), basePopup, draftBox])
        baseRow.orientation = .horizontal
        let stack = NSStackView(views: [title, bodyScroll, baseRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: width, height: 210)
        title.widthAnchor.constraint(equalToConstant: width).isActive = true
        bodyScroll.widthAnchor.constraint(equalToConstant: width).isActive = true
        bodyScroll.heightAnchor.constraint(equalToConstant: 140).isActive = true
        alert.accessoryView = stack
        alert.addButton(withTitle: L("Create"))
        alert.addButton(withTitle: L("Cancel"))
        alert.window.initialFirstResponder = title
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let request = PluginGit.createPullRequestRequest(project, title: title.stringValue, body: body.string, head: branch,
                                                         base: basePopup.titleOfSelectedItem ?? base,
                                                         draft: draftBox.state == .on)
        let root = self.root, box = ServicesBox(services)
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let push {
                let push = PluginGitRepo.run(["-C", root] + push, combined: true)
                guard push.ok else {
                    DispatchQueue.main.async {
                        self?.busy.stopAnimation(nil)
                        GitCommitActions.report(box.services, L("Pull requests"), push.out)
                    }
                    return
                }
            }
            client.send(request) { response, error in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self?.busy.stopAnimation(nil)
                        guard let response, response.ok, let created = PluginGit.parseCreated(response.data, kind: project.kind) else {
                            let message = response.map { PluginGit.apiErrorMessage($0.data, status: $0.status) } ?? error ?? L("No answer.")
                            GitCommitActions.report(box.services, L("Pull requests"), message)
                            return
                        }
                        self?.statusLine.stringValue = String(format: L("#%lld created."), created.number)
                        if let url = URL(string: created.webURL) { NSWorkspace.shared.open(url) }
                        self?.refresh()
                    }
                }
            }
        }
    }

    /// For the verification dump.
    func automationSummary() -> [String] {
        ["prProject=\(project.map { "\($0.kind.rawValue) \($0.path)" } ?? "<none>")",
         "prConnected=\(client != nil)", "prSetup=\(setupBox.isHidden ? "" : setupLabel.stringValue)",
         "prRows=\(table.numberOfRows)"]
    }
}

/// Responses arriving on URLSession's queue, collected by index.
private final class ResponseBox: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [(PluginGitHostingClient.Response?, String?)]
    init(count: Int) { values = Array(repeating: (nil, nil), count: count) }
    func set(_ index: Int, _ response: PluginGitHostingClient.Response?, _ error: String?) {
        lock.lock(); values[index] = (response, error); lock.unlock()
    }
    func all() -> [(PluginGitHostingClient.Response?, String?)] { lock.lock(); defer { lock.unlock() }; return values }
}

extension GitPullRequestsView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { tab == .pullRequests ? pulls.count : issues.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier.rawValue else { return nil }
        let field = (tableView.makeView(withIdentifier: .init("GitPRText"), owner: self) as? NSTextField) ?? {
            let f = NSTextField(labelWithString: "")
            f.identifier = .init("GitPRText")
            f.lineBreakMode = .byTruncatingTail
            f.font = .systemFont(ofSize: 12)
            return f
        }()
        field.textColor = theme.text
        let updated: Date?
        switch tab {
        case .pullRequests:
            guard pulls.indices.contains(row) else { return nil }
            let pull = pulls[row]
            updated = pull.updated
            switch id {
            case "number": field.stringValue = "#\(pull.number)"
            case "title": field.stringValue = (pull.isDraft ? "[" + L("draft") + "] " : "") + pull.title
            case "author": field.stringValue = pull.author
            case "branch": field.stringValue = "\(pull.sourceBranch) → \(pull.targetBranch)"
            default: field.stringValue = ""
            }
        case .issues:
            guard issues.indices.contains(row) else { return nil }
            let issue = issues[row]
            updated = issue.updated
            switch id {
            case "number": field.stringValue = "#\(issue.number)"
            case "title": field.stringValue = issue.title
            case "author": field.stringValue = issue.author
            case "branch": field.stringValue = issue.labels.joined(separator: ", ")
            default: field.stringValue = ""
            }
        }
        if id == "updated" { field.stringValue = updated.map { gitDisplayDate($0) } ?? "" }
        if id == "number" || id == "updated" || id == "author" { field.textColor = theme.secondaryText }
        return field
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if let pull = selectedPull { loadChecks(pull) }
        showDetail()
        updateButtons()
    }
}

extension GitPullRequestsView: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(checkOut): return selectedPull != nil
        default: return selectedURL != nil
        }
    }
}
