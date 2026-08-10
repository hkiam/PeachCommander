// SPDX-License-Identifier: Apache-2.0
// terminalplugin.swift — an embedded terminal with tabs (F-381).
//
// The emulator is SwiftTerm (MIT, pinned in project.yml, compiled in by Tools/build-terminal-plugin.sh
// — referenced, never copied into this repository). Writing one instead was never seriously on the
// table: a terminal that runs `top` and Claude Code needs the alternate screen buffer, scroll regions,
// cursor addressing, 256-colour and true-colour SGR, bracketed paste, SGR-1006 mouse reporting, wide
// characters and combining marks, and a resize path that sends SIGWINCH with the right winsize.
//
// What this file is responsible for is everything around it.
//
// **A session is not a view.** One pseudo-terminal, one child process, one scrollback — owned by the
// pool below and merely *shown* by whatever view is on screen. That separation is the whole design and
// it is not decoration: switching tabs must not restart `top`, and neither must moving the terminal
// from the dock to the side panel. The host already refuses to rebuild a view that merely moved; this
// is the other half, on the plugin's side of the ABI.
//
// It is also what makes mixing work — a quick shell in the narrow side panel and something long-lived
// in the wide dock — because two mounted views are two windows onto one pool rather than two terminals
// that know nothing of each other.
//
// **The shell is the user's.** Their `$SHELL`, started as a login shell, in the folder the panel is
// looking at. Autocomplete, history, Ctrl+R, the prompt and every alias are the shell's job, and
// anything reimplemented here would be a worse zsh. `-l` is what gives the child the PATH the user
// actually has, since an app launched from Finder does not inherit one.
//
// **Teardown has to be real.** SIGHUP to the process *group*, not the process: a shell that started
// `make -j8` has children, and killing only the shell orphans them. Measured, with the app still
// running: without `PcCloseView` two background jobs survive; with it but without the group signal,
// one does; correct is none.

import AppKit

/// Quote a path for a POSIX shell, the way the host's own ShellQuoting does.
///
/// Repeated here rather than shared because the host's copy is Swift in another module and this file
/// is compiled into a plugin. The rule is the one that cannot be got wrong: wrap in single quotes and
/// write a contained single quote as `'\''`. A name with a space, a quote, a `$` or a newline in it
/// then arrives as exactly one argument.
func shellQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

// MARK: - Settings

/// The plugin's own settings, in the plugin's own file.
///
/// Under the host's config root so an isolated `-ConfigRoot` is honoured, and in a directory of its
/// own so that removing the plugin leaves nothing behind in the host's `peachcmd.ini` — which is what
/// "fully removable" has to mean in practice.
final class TerminalSettings {
    static let shared = TerminalSettings()

    /// May the terminal steer the file panel when its shell reports a new folder?
    ///
    /// Off, and it stays off until asked. A panel that moves on its own the first time someone types
    /// `cd` is startling, and the direction people expect is the other one.
    ///
    /// Read from the file rather than cached: it is a few hundred bytes, it is consulted at most once
    /// per shell prompt, and reading it means a change takes effect at once instead of at the next
    /// launch. Caching this would buy nothing measurable and cost the thing people notice.
    var panelFollowsTerminal: Bool {
        get { stored()?.panelFollowsTerminal ?? false }
        set { try? JSONEncoder().encode(Stored(panelFollowsTerminal: newValue)).write(to: url) }
    }

    private func stored() -> Stored? {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
    }

    private struct Stored: Codable { var panelFollowsTerminal: Bool }

    private let url: URL = {
        let root: URL
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-ConfigRoot"), i + 1 < args.count {
            root = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        } else if let env = ProcessInfo.processInfo.environment["PEACHCMD_CONFIG_ROOT"], !env.isEmpty {
            root = URL(fileURLWithPath: env, isDirectory: true)
        } else {
            root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("PeachCommander", isDirectory: true)
        }
        let base = root.appendingPathComponent("terminal", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("config.json")
    }()

    private init() {}

    /// The line the user would have to add to their shell's startup file for any of this to happen.
    ///
    /// **Shown, never written.** Editing somebody's `.zshrc` behind their back is not a thing an
    /// application gets to do, however convenient — and this is the one place where the feature cannot
    /// work without their cooperation, so the honest move is to say exactly what is needed and stop.
    ///
    /// macOS does ship an OSC 7 hook in `/etc/zshrc`, and it is guarded by
    /// `[[ $TERM_PROGRAM == Apple_Terminal ]]` — so it fires for Apple's terminal and for nothing else,
    /// including this one.
    static let shellSnippet = """
    # Report the working directory to the terminal (OSC 7), for Peach Commander
    autoload -Uz add-zsh-hook
    _pc_osc7() { printf '\\033]7;file://%s%s\\007' "$HOST" "${PWD// /%20}" }
    add-zsh-hook precmd _pc_osc7
    """
}

/// A terminal view that treats ⌘-click as "show me this file".
///
/// The bridge back to the file manager, and the reason to embed a terminal rather than launch
/// Terminal.app (plan §6). A path printed by `ls`, a compiler error, `git status` — one click and the
/// panel is looking at it.
///
/// Only ⌘-click, and only when the word under the pointer resolves to something that exists. A plain
/// click still selects, a double-click still selects a word, and a ⌘-click on prose does nothing
/// rather than something surprising: refusing quietly is better than navigating somewhere arbitrary
/// because a sentence happened to contain a slash.
final class PCTerminalView: LocalProcessTerminalView {
    /// Called with an existing path the user ⌘-clicked. Set by the session.
    var onRevealPath: ((String) -> Void)?
    /// Where relative paths are relative to.
    var workingDirectory: (() -> String?)?

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command), let path = pathUnderPointer(event) else {
            super.mouseDown(with: event)
            return
        }
        onRevealPath?(path)
    }

    /// Resolve a word from the scrollback as a path on this machine, or nil.
    func resolvePath(_ word: String) -> String? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",;:\"')]}"))
        guard !trimmed.isEmpty else { return nil }
        var candidate = (trimmed as NSString).expandingTildeInPath
        if !candidate.hasPrefix("/") {
            guard let cwd = workingDirectory?() else { return nil }
            candidate = (cwd as NSString).appendingPathComponent(candidate)
        }
        candidate = (candidate as NSString).standardizingPath
        return FileManager.default.fileExists(atPath: candidate) ? candidate : nil
    }

    private func pathUnderPointer(_ event: NSEvent) -> String? {
        let hit = calculateMouseHit(with: event)
        // The emulator already knows where a "word or expression" begins and ends — the same rule a
        // double-click uses — so a path with dots and slashes in it comes back whole.
        selection.selectWordOrExpression(at: Position(col: hit.grid.col, row: hit.grid.row),
                                         in: terminal.displayBuffer)
        let word = selection.getSelectedText().trimmingCharacters(in: .whitespacesAndNewlines)
        selection.active = false
        setNeedsDisplay(bounds)
        // Trailing punctuation is how paths appear in prose and in compiler output:
        // "see main.swift:" — handled by resolvePath, which the automation path shares.
        return resolvePath(word)
    }
}

// MARK: - Sessions

/// One pseudo-terminal, its child process and its scrollback.
///
/// Outlives every view that shows it. The view hierarchy is where it is *displayed*; ownership is the
/// pool's, and only the pool ends it.
final class TerminalSession: NSObject, LocalProcessTerminalViewDelegate {

    /// Stable across the session's life, so a view can say which of several it is showing.
    let id: Int
    let view = PCTerminalView(frame: .zero)
    /// What the running program calls itself (OSC 0/1/2), else the shell's name.
    private(set) var title: String
    /// The terminal's size, read from the emulator rather than mirrored from its delegate.
    ///
    /// `sizeChanged` fires on a *change*. A session added to a view that already has its final
    /// geometry is the right size from its first layout and therefore never reports one — which had
    /// the second tab showing 0×0 while its shell was running perfectly well. Asking the source cannot
    /// go stale that way.
    var cols: Int { view.getTerminal().cols }
    var rows: Int { view.getTerminal().rows }
    private(set) var exited = false
    /// Where the shell was started, and where OSC 7 says it is now.
    private(set) var directory: String?
    private var started = false

    /// Called whenever anything a view might display has changed.
    var onChange: (() -> Void)?
    /// Called when the shell reports a new working directory (OSC 7), if it reports one at all.
    var onDirectoryChange: ((String) -> Void)?
    /// Called with a path the user ⌘-clicked in the scrollback.
    var onRevealPath: ((String) -> Void)? {
        didSet { view.onRevealPath = onRevealPath }
    }

    static var loginShell: String {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? ""
        return FileManager.default.isExecutableFile(atPath: shell) ? shell : "/bin/zsh"
    }

    init(id: Int, directory: String?) {
        self.id = id
        self.directory = directory
        self.title = (Self.loginShell as NSString).lastPathComponent
        super.init()
        view.processDelegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        // Relative paths resolve against wherever the shell says it is — falling back to where it was
        // started, since OSC 7 is something the user has to arrange and most will not have.
        view.workingDirectory = { [weak self] in self?.directory }
    }

    /// Start the shell, once, and only when the view has real geometry.
    ///
    /// A pseudo-terminal's size comes from the view's frame. A shell told it has zero columns prints
    /// its prompt where nobody can see it and never recovers, because the size is pushed again only
    /// when it *changes*.
    func startIfNeeded() {
        guard !started, view.window != nil, view.frame.width > 1 else { return }
        started = true
        let shell = Self.loginShell
        view.startProcess(executable: shell, args: ["-l"], environment: nil,
                          execName: "-" + (shell as NSString).lastPathComponent,
                          currentDirectory: directory)
    }

    func send(_ text: String) { view.send(txt: text) }

    /// Resolve a word as ⌘-click would and hand it over if it names something that exists.
    ///
    /// Shared with the click rather than reimplemented beside it: a scenario that exercised a second
    /// copy of the rule would prove nothing about the first.
    func revealIfExists(_ word: String) {
        if let path = view.resolvePath(word) { onRevealPath?(path) }
    }

    /// Wear the host's colours (F-338/F-381).
    ///
    /// A terminal that ignores the theme is the one thing in a dark window that is not dark, and the
    /// ANSI palette is left alone on purpose: those sixteen colours are what programs *ask* for by
    /// number, and repainting them to match a file manager would make `ls --color` lie about which
    /// files are which. Only the surfaces the emulator owns — background, default text, cursor,
    /// selection — follow the theme.
    func applyTheme(_ theme: PluginTheme) {
        view.nativeBackgroundColor = theme.background
        view.nativeForegroundColor = theme.text
        view.caretColor = theme.accent
        view.selectedTextBackgroundColor = theme.selectionBackground
        view.needsDisplay = true
    }

    // MARK: LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        onChange?()
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        // The shell sets this for free and full-screen programs set it themselves, which is why the
        // tab follows it rather than guessing from the process table.
        self.title = title.isEmpty ? (Self.loginShell as NSString).lastPathComponent : title
        onChange?()
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        // OSC 7. No shell emits it here unless the user has asked it to — macOS's own hook is guarded
        // to Apple Terminal — so this is a capability that appears when configured and is absent
        // otherwise. Nothing else in the plugin depends on it.
        guard let directory, let path = Self.localPath(fromOSC7: directory) else { return }
        self.directory = path
        onChange?()
        onDirectoryChange?(path)
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        exited = true
        title = exitCode.map { "exited (\($0))" } ?? "exited"
        onChange?()
    }

    /// Turn an OSC 7 payload into a local directory path, or nil if it is not one.
    ///
    /// The emulator hands the sequence's contents over verbatim — `file://host/path`, percent-encoded
    /// — so the parsing is ours. `URL` does the work, including decoding `%20` back into a space,
    /// which matters because the hook the settings page suggests encodes exactly that.
    ///
    /// **A host that is not this machine is refused.** An `ssh` session inside the terminal reports
    /// the *remote* working directory, and steering the local file panel to a path that happens to
    /// exist on both machines would be quietly wrong in the way that costs someone an afternoon.
    static func localPath(fromOSC7 value: String) -> String? {
        // Some shells send a bare path instead of a URL; take it as it is.
        guard value.hasPrefix("file:") else { return value.hasPrefix("/") ? value : nil }
        guard let url = URL(string: value) else { return nil }
        let host = url.host ?? ""
        if !host.isEmpty, host.lowercased() != "localhost" {
            let short = { (name: String) in name.split(separator: ".").first.map(String.init)?.lowercased() ?? "" }
            guard short(host) == short(ProcessInfo.processInfo.hostName) else { return nil }
        }
        let path = url.path
        return path.isEmpty ? nil : path
    }

    /// Stop the shell and everything it started.
    ///
    /// The group, not the process. SwiftTerm's own `terminate` sends SIGTERM to the shell, and a
    /// SIGTERMed zsh does not hup its jobs — which is why a background `make` survives it and does not
    /// survive this. Escalation is deliberate: SIGHUP is what a closing terminal is supposed to send
    /// and what shells handle gracefully; SIGKILL is for whatever ignored it.
    func teardown() {
        let pid = view.process.shellPid
        if pid > 0 {
            kill(-pid, SIGHUP)          // negative pid: the whole process group
            var waited = 0.0
            var status: Int32 = 0
            while waited < 2.0 {
                if waitpid(pid, &status, WNOHANG) != 0 { break }
                Thread.sleep(forTimeInterval: 0.02)
                waited += 0.02
            }
            if waited >= 2.0 {
                kill(-pid, SIGKILL)
                _ = waitpid(pid, &status, 0)   // never leave a zombie
            }
        }
        view.terminate()
    }
}

/// Every session this plugin owns, across every mounted view.
///
/// Global because the plugin is the owner and there is exactly one of it per process. A session is
/// only ever ended here, so no view can end one by being taken off screen.
enum TerminalPool {
    private(set) static var sessions: [TerminalSession] = []
    private static var nextId = 1

    static func make(directory: String?) -> TerminalSession {
        let session = TerminalSession(id: nextId, directory: directory)
        nextId += 1
        sessions.append(session)
        return session
    }

    static func close(_ session: TerminalSession) {
        session.teardown()
        session.view.removeFromSuperview()
        sessions.removeAll { $0 === session }
    }
}

// MARK: - The view

/// A tab strip over one session at a time.
///
/// Sized and coloured to match the panel's own tab bar, so the dock does not look like a different
/// application bolted to the bottom of the window.
/// A tab strip over one or two panes, each showing one session.
///
/// Splitting belongs here rather than in the host (plan §3): the dock hands the plugin one `NSView`
/// and what happens inside it is the plugin's business, so "two terminals stacked, then the whole area
/// for one again" needs no host support at all.
///
/// Panes stack vertically, which is the only arrangement worth offering here. The dock is wide and
/// short; splitting it side by side would give each half about sixty columns, and the point of the
/// dock over the side panel was that it has columns to spare.
///
/// **Maximising is not closing.** Collapsing to one pane leaves the other session running in the pool,
/// so it comes back with its scrollback and whatever it was doing. A toggle that quietly killed a
/// build would be worse than no toggle.
final class TerminalContainerView: NSView {

    private static let tabBarHeight: CGFloat = 26
    private static let statusHeight: CGFloat = 14

    /// The sessions *this* view shows, in tab order. A subset of the pool: another mounted view may
    /// hold others, which is what lets a quick shell live in the side panel while something long runs
    /// in the dock.
    private var tabs: [TerminalSession] = []
    /// One entry per pane, each the index into `tabs` of the session that pane shows.
    private var panes: [Int] = [0]
    /// Which pane the tab strip and keyboard act on.
    private var focused = 0

    private let tabStrip = NSStackView()
    private let addButton = NSButton(title: "+", target: nil, action: nil)
    private let splitButton = NSButton(title: "", target: nil, action: nil)
    private let splitView = TerminalSplitView()
    private let status = NSTextField(labelWithString: "")
    private var container: String
    /// Kept so a new tab can start where the panel is looking. The host guarantees the services table
    /// stays valid for the view's lifetime; the struct is copied rather than the pointer held.
    private var services: PcHostServices?
    private var theme: PluginTheme

    init(container: String, services: PcHostServices?) {
        self.container = container
        self.services = services
        self.theme = PluginTheme(services)
        super.init(frame: .zero)
        wantsLayer = true

        tabStrip.orientation = .horizontal
        tabStrip.spacing = 2
        tabStrip.alignment = .centerY
        tabStrip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tabStrip)

        addButton.bezelStyle = .accessoryBarAction
        addButton.isBordered = false
        addButton.toolTip = L("New terminal tab")
        addButton.target = self
        addButton.action = #selector(newTabPressed)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addButton)

        splitButton.bezelStyle = .accessoryBarAction
        splitButton.isBordered = false
        splitButton.image = NSImage(systemSymbolName: "rectangle.split.1x2",
                                    accessibilityDescription: L("Split the terminal"))
        splitButton.target = self
        splitButton.action = #selector(splitPressed)
        splitButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(splitButton)

        splitView.isVertical = false          // horizontal dividers → panes stacked vertically
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        // The gesture that centres the panel splitter (F-001), on the divider that stacks terminals.
        splitView.onDividerDoubleClick = { [weak self] in self?.toggleMaximised() }
        addSubview(splitView)

        status.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingMiddle
        status.translatesAutoresizingMaskIntoConstraints = false
        addSubview(status)

        // One point below required on the top inset, for the same reason the dock's own header is: a
        // collapsed view is zero points tall, and "content starts below the tab bar" and "content
        // reaches the bottom" cannot both hold in zero points.
        let contentTop = splitView.topAnchor.constraint(equalTo: topAnchor, constant: Self.tabBarHeight)
        contentTop.priority = .required - 1

        NSLayoutConstraint.activate([
            tabStrip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            tabStrip.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            tabStrip.heightAnchor.constraint(equalToConstant: Self.tabBarHeight - 4),
            addButton.leadingAnchor.constraint(equalTo: tabStrip.trailingAnchor, constant: 4),
            addButton.centerYAnchor.constraint(equalTo: tabStrip.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 20),
            splitButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 2),
            splitButton.centerYAnchor.constraint(equalTo: tabStrip.centerYAnchor),
            splitButton.widthAnchor.constraint(equalToConstant: 20),
            contentTop,
            splitView.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: status.topAnchor),
            status.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            status.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            status.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            status.heightAnchor.constraint(equalToConstant: Self.statusHeight),
        ])
        newTab()
        applyTheme()
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Tabs

    /// The folder the active panel is looking at, asked freshly so a *new* tab opens where the user is
    /// now rather than where they were when the dock opened.
    private func hostDirectory() -> String? {
        guard let svc = services, let fn = svc.getContext else { return nil }
        var buf = [CChar](repeating: 0, count: 4096)
        guard "dir".withCString({ fn(svc.host, $0, &buf, 4096) }) != 0 else { return nil }
        let path = String(cString: buf)
        return path.isEmpty ? nil : path
    }

    @discardableResult
    func newTab() -> TerminalSession {
        let session = TerminalPool.make(directory: hostDirectory())
        session.onChange = { [weak self] in self?.refreshChrome() }
        session.onDirectoryChange = { [weak self] path in self?.steerPanel(to: path) }
        session.onRevealPath = { [weak self] path in self?.revealInPanel(path) }
        session.applyTheme(theme)
        tabs.append(session)
        panes[focused] = tabs.count - 1
        rebuildPanes()
        return session
    }

    func selectTab(_ index: Int) {
        guard tabs.indices.contains(index), panes[focused] != index else { return }
        panes[focused] = index
        rebuildPanes()
    }

    /// Close the tab, and with it the session — the one place a session ends by request.
    func closeTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        TerminalPool.close(tabs.remove(at: index))
        if tabs.isEmpty { panes = [0]; focused = 0; newTab(); return }
        // Panes pointing past the end, or at the tab that just went, fall back to a neighbour rather
        // than to nothing: a pane showing no session is a grey rectangle with no way out of it.
        panes = panes.map { min($0 >= index ? max($0 - 1, 0) : $0, tabs.count - 1) }
        rebuildPanes()
    }

    var selectedSession: TerminalSession? {
        let index = panes.indices.contains(focused) ? panes[focused] : 0
        return tabs.indices.contains(index) ? tabs[index] : nil
    }

    // MARK: Splitting

    var isSplit: Bool { panes.count > 1 }

    /// Add a second pane, showing a new session, and focus it.
    func split() {
        guard panes.count == 1 else { return }
        let session = TerminalPool.make(directory: hostDirectory())
        session.onChange = { [weak self] in self?.refreshChrome() }
        session.onDirectoryChange = { [weak self] path in self?.steerPanel(to: path) }
        session.onRevealPath = { [weak self] path in self?.revealInPanel(path) }
        session.applyTheme(theme)
        tabs.append(session)
        panes.append(tabs.count - 1)
        focused = 1
        rebuildPanes()
    }

    /// Collapse to the focused pane. The other pane's session keeps running and keeps its tab.
    func maximise() {
        guard panes.count > 1 else { return }
        panes = [panes[focused]]
        focused = 0
        rebuildPanes()
    }

    func toggleMaximised() { isSplit ? maximise() : split() }

    @objc private func splitPressed() { toggleMaximised() }

    // MARK: Layout

    /// Rebuild the pane stack and put each pane's session into it.
    private func rebuildPanes() {
        for view in splitView.arrangedSubviews { splitView.removeArrangedSubview(view); view.removeFromSuperview() }
        // Detach every session view first: one that stayed in a pane that no longer exists would be
        // retained by a dead superview and never shown again.
        for tab in tabs { tab.view.removeFromSuperview() }

        for index in panes {
            let holder = NSView()
            holder.translatesAutoresizingMaskIntoConstraints = false
            splitView.addArrangedSubview(holder)
            guard tabs.indices.contains(index) else { continue }
            let session = tabs[index]
            session.view.isHidden = false
            holder.addSubview(session.view)
            NSLayoutConstraint.activate([
                session.view.topAnchor.constraint(equalTo: holder.topAnchor),
                session.view.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
                session.view.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
                session.view.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
            ])
        }
        refreshChrome()
        if let session = selectedSession { window?.makeFirstResponder(session.view) }
        layoutSubtreeIfNeeded()
        // Halve it. NSSplitView gives a newly added pane whatever is left over rather than an even
        // share, and left over is almost nothing: measured, splitting the dock at its default height
        // gave the second terminal **one row**. Nobody would call that a split.
        if panes.count == 2, splitView.bounds.height > 0 {
            splitView.setPosition(splitView.bounds.height / 2, ofDividerAt: 0)
            layoutSubtreeIfNeeded()
        }

        // The size, and only then the shell — on the next turn of the run loop.
        //
        // `TerminalView.setFrameSize` recomputes the grid only once its cell dimensions are known and
        // returns early otherwise, and those are not known until the view has been through a display
        // cycle. For the first tab that costs nothing: the window is still settling and another resize
        // follows. For a tab or pane created into a view that already has its final geometry, no
        // further resize ever comes — so the terminal kept SwiftTerm's default 80×25 while showing 125
        // columns, and every line the shell printed wrapped in the wrong place. Measured twice: doing
        // this synchronously after `layoutSubtreeIfNeeded` is still too early.
        //
        // Every visible pane, not just the focused one: splitting halves the height of *both*.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for index in self.panes where self.tabs.indices.contains(index) {
                let session = self.tabs[index]
                guard session.view.superview != nil else { continue }
                session.view.setFrameSize(session.view.frame.size)
                session.startIfNeeded()
            }
            self.refreshChrome()
        }
    }

    @objc private func newTabPressed() { newTab() }
    @objc private func tabPressed(_ sender: NSButton) { selectTab(sender.tag) }

    private func refreshChrome() {
        for view in tabStrip.arrangedSubviews { tabStrip.removeArrangedSubview(view); view.removeFromSuperview() }
        let shown = Set(panes)
        for (i, tab) in tabs.enumerated() {
            let button = NSButton(title: tab.title, target: self, action: #selector(tabPressed(_:)))
            button.tag = i
            button.bezelStyle = .recessed
            button.setButtonType(.pushOnPushOff)
            // On when the tab is on screen at all, so a split shows both of its sessions as current —
            // marking only the focused one would say the other had gone somewhere.
            button.state = shown.contains(i) ? .on : .off
            button.font = .systemFont(ofSize: 11)
            tabStrip.addArrangedSubview(button)
        }
        splitButton.toolTip = isSplit ? L("Use the whole area for one terminal") : L("Split the terminal")
        // One line a scenario can assert on without a parser, and a line a user can read: which pane of
        // how many, which tab of how many, what is running, how big the terminal thinks it is, and
        // where it is docked.
        if let s = selectedSession {
            let index = panes.indices.contains(focused) ? panes[focused] : 0
            // What is running, where it is, how big — in that order, because that is the order the
            // questions are asked in.
            let cwd = s.directory.map { " · \(($0 as NSString).abbreviatingWithTildeInPath)" } ?? ""
            var line = "\(s.title)\(cwd) · \(s.cols)×\(s.rows)"
            if !container.isEmpty { line += " · \(container)" }
            // Bookkeeping only when there is any. "pane 1/1 · tab 1/1 · session 1" told the user
            // nothing they could not see, and it was the first thing the eye hit.
            if tabs.count > 1 { line += " · tab \(index + 1)/\(tabs.count) · session \(s.id)" }
            if panes.count > 1 { line += " · pane \(focused + 1)/\(panes.count)" }
            status.stringValue = line
        }
    }

    // MARK: Host context

    func notify(key: String, value: String) {
        switch key {
        case "container": container = value; refreshChrome()
        case "sendText":  selectedSession?.send(value)
        case "revealPath":
            // The same entry point ⌘-click takes. A click cannot be scripted, so what a scenario can
            // exercise is the resolution and the hand-off — which is where the work is.
            selectedSession?.revealIfExists(value)
        case "dropPaths":
            // The same entry point a real drop takes. A drag cannot be scripted, so what a scenario
            // can exercise is the other end — which is where the quoting lives and where it matters.
            insertPaths(value.split(separator: "\n").map(String.init).filter { !$0.isEmpty })
        case "newTab":    newTab()
        case "selectTab": if let i = Int(value) { selectTab(i - 1) }   // 1-based, as the status line reads
        case "closeTab":  if let i = Int(value) { closeTab(i - 1) }
        case "split":     split()
        case "maximise":  maximise()
        // What a menu item wants: one key that splits and then puts it back, so the host does not
        // have to track a layout it cannot see.
        case "toggleSplit": toggleMaximised()
        case "focusPane": if let i = Int(value), panes.indices.contains(i - 1) { focused = i - 1; refreshChrome() }
        case "theme":
            // Re-read rather than trusting the id: the host sends the theme's name, and what a name
            // means is exactly what may have changed.
            theme = PluginTheme(services)
            applyTheme()
        default:          break
        }
    }

    /// Take the active panel to where the shell says it is — if the user asked for that.
    ///
    /// Only from the *focused* session: with two panes open, a background build printing its way
    /// through a tree would otherwise drag the panel along behind it.
    private func steerPanel(to path: String) {
        guard TerminalSettings.shared.panelFollowsTerminal,
              let svc = services, let open = svc.openPathInPanel,
              let session = selectedSession, session.directory == path else { return }
        // Whichever panel is active, in the 0 = left / 1 = right terms the host uses.
        var side: Int32 = 0
        if let get = svc.getContext {
            var buf = [CChar](repeating: 0, count: 8)
            let ok = "activeSide".withCString { key in get(svc.host, key, &buf, 8) }
            if ok != 0, String(cString: buf) == "1" { side = 1 }
        }
        path.withCString { open(svc.host, side, $0) }
    }

    /// Show a ⌘-clicked path in the file panel.
    ///
    /// Unconditional, unlike `steerPanel`: this is a click the user just made *on that path*, not a
    /// side effect of the shell moving around. There is nothing to gate — they asked.
    private func revealInPanel(_ path: String) {
        guard let svc = services, let open = svc.openPathInPanel else { return }
        var side: Int32 = 0
        if let get = svc.getContext {
            var buf = [CChar](repeating: 0, count: 8)
            let ok = "activeSide".withCString { key in get(svc.host, key, &buf, 8) }
            if ok != 0, String(cString: buf) == "1" { side = 1 }
        }
        // A folder is opened; a file has its folder opened, since a panel shows folders. The host
        // puts the cursor on the file when handed one, which is the behaviour `openPathInPanel`
        // already has for every other plugin that uses it.
        path.withCString { open(svc.host, side, $0) }
    }

    // MARK: Dropping files

    /// Put dropped paths at the prompt, quoted and separated by spaces.
    ///
    /// Inserted, never executed. Dropping a file onto a terminal means "I want to talk about this
    /// file", and deciding on the user's behalf what to do with it would be both presumptuous and
    /// occasionally destructive.
    func insertPaths(_ paths: [String]) {
        guard !paths.isEmpty, let session = selectedSession else { return }
        session.send(paths.map(shellQuoted).joined(separator: " ") + " ")
        window?.makeFirstResponder(session.view)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedPaths(from: sender).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let paths = droppedPaths(from: sender)
        guard !paths.isEmpty else { return false }
        insertPaths(paths)
        return true
    }

    private func droppedPaths(from sender: NSDraggingInfo) -> [String] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                        options: options) as? [URL] ?? []
        return urls.map(\.path)
    }

    /// Focus given to this view belongs to the terminal inside it.
    ///
    /// The host focuses whatever `PcMakeView` returned, which is this container — and a container is
    /// not something that reads keys, so typing went nowhere. Redirecting rather than refusing keeps
    /// the host's side simple: it can go on focusing "the plugin's view" without knowing what is in
    /// it, which is the whole point of the view being opaque across the ABI.
    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        // Accept, then hand off on the next turn of the run loop. Calling `makeFirstResponder` from
        // inside this method starts a second transition while the first is still running, and AppKit
        // resolves that by giving up on both: measured, the window itself ended up first responder and
        // the toggle appeared to do nothing at all.
        DispatchQueue.main.async { [weak self] in
            guard let self, let session = self.selectedSession, session.view.window != nil else { return }
            self.window?.makeFirstResponder(session.view)
        }
        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        selectedSession?.startIfNeeded()
    }

    override func layout() {
        super.layout()
        // The first real geometry is the earliest moment a shell can be told a truthful size.
        selectedSession?.startIfNeeded()
    }

    /// Paint this view and every session in it in the host's colours.
    private func applyTheme() {
        layer?.backgroundColor = theme.windowBackground.cgColor
        status.textColor = theme.secondaryText
        for tab in tabs { tab.applyTheme(theme) }
        needsDisplay = true
    }

    /// The view is going away for good: end every session it holds.
    ///
    /// Only the sessions in *this* view's tabs. Another mounted view's sessions are not this one's to
    /// end, which is the point of the pool being shared.
    func teardown() {
        for tab in tabs { TerminalPool.close(tab) }
        tabs.removeAll()
        panes = [0]
    }
}

/// An `NSSplitView` whose divider answers a double-click.
///
/// The same gesture that centres the file panels (F-001), because a divider that can be dragged and
/// cannot be double-clicked is a divider people drag to the edge and then cannot get back.
final class TerminalSplitView: NSSplitView {
    var onDividerDoubleClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, arrangedSubviews.count > 1 {
            // Only on the divider itself: a double-click inside a terminal is a word selection and
            // must stay one.
            let point = convert(event.locationInWindow, from: nil)
            if !arrangedSubviews.contains(where: { $0.frame.contains(point) }) {
                onDividerDoubleClick?()
                return
            }
        }
        super.mouseDown(with: event)
    }
}

/// The plugin's page in the host's settings dialog.
///
/// Its job is mostly to explain. The one switch here does nothing on its own: the terminal can only
/// follow the shell if the shell says where it is, and no shell on macOS says so unless the user has
/// arranged it — Apple's own hook in `/etc/zshrc` is guarded to Apple Terminal. So the page shows the
/// exact lines that would be needed, in a field they can select and copy, and does not touch anything.
final class TerminalSettingsView: NSView {

    private let followCheck = NSButton(checkboxWithTitle: L("Let the active panel follow the terminal"),
                                       target: nil, action: nil)
    private let snippet = NSTextView()

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 520, height: 300))

        followCheck.state = TerminalSettings.shared.panelFollowsTerminal ? .on : .off
        followCheck.target = self
        followCheck.action = #selector(followChanged)
        followCheck.translatesAutoresizingMaskIntoConstraints = false
        addSubview(followCheck)

        let explanation = NSTextField(wrappingLabelWithString: L(
            "The terminal can only follow your shell if the shell reports its folder (OSC 7). macOS "
            + "does that for Apple's Terminal only, so it has to be set up once. Peach Commander will "
            + "not edit your shell's startup file: add these lines to ~/.zshrc yourself."))
        explanation.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        explanation.textColor = .secondaryLabelColor
        explanation.translatesAutoresizingMaskIntoConstraints = false
        addSubview(explanation)

        // Selectable, in a monospaced face, because it is meant to be copied and pasted verbatim.
        snippet.string = TerminalSettings.shellSnippet
        snippet.isEditable = false
        snippet.isSelectable = true
        snippet.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        snippet.drawsBackground = true
        snippet.backgroundColor = .textBackgroundColor
        let scroll = NSScrollView()
        scroll.documentView = snippet
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        let copyButton = NSButton(title: L("Copy"), target: self, action: #selector(copySnippet))
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(copyButton)

        NSLayoutConstraint.activate([
            followCheck.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            followCheck.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            explanation.topAnchor.constraint(equalTo: followCheck.bottomAnchor, constant: 10),
            explanation.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            explanation.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: explanation.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            scroll.heightAnchor.constraint(equalToConstant: 92),
            copyButton.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8),
            copyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            copyButton.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func followChanged() {
        TerminalSettings.shared.panelFollowsTerminal = followCheck.state == .on
    }

    @objc private func copySnippet() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(TerminalSettings.shellSnippet, forType: .string)
    }

    /// Diagnostic: everything this page is showing, so a scenario can read it (F-381).
    var automationSummary: String {
        "follow=\(TerminalSettings.shared.panelFollowsTerminal)\nsnippet=\(snippet.string.contains("]7;file://"))\n"
    }
}

// MARK: - The contribution ABI

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ container: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    let where_ = container.map { String(cString: $0) } ?? ""
    if where_ == "settings" { return Unmanaged.passRetained(TerminalSettingsView()).toOpaque() }
    let view = TerminalContainerView(container: where_, services: services?.pointee)
    return Unmanaged.passRetained(view).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    // A settings page holds nothing; only the terminal has anything to let go of.
    (Unmanaged<NSView>.fromOpaque(view).takeUnretainedValue() as? TerminalContainerView)?.teardown()
    Unmanaged<NSView>.fromOpaque(view).release()
}

@_cdecl("PcNotifyView")
public func PcNotifyView(_ view: UnsafeMutableRawPointer?, _ key: UnsafePointer<CChar>?,
                         _ value: UnsafePointer<CChar>?) {
    guard let view, let key else { return }
    let target = Unmanaged<NSView>.fromOpaque(view).takeUnretainedValue() as? TerminalContainerView
    target?.notify(key: String(cString: key), value: value.map { String(cString: $0) } ?? "")
}

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    // No commands yet. The symbol exists because `ContribPlugin.hasBehavior` is `PcRunCommand != nil`:
    // without it the host treats the bundle as carrying no contribution behaviour at all and never
    // asks it for a view.
}

// Deliberately no `PcSafeToUnload`. `PluginLibrary` only calls `dlclose` on a library that exports it,
// and a terminal's reader thread outlives the last view's teardown by however long a child takes to
// die. Unloading the code out from under a thread still reading a file descriptor is a crash on quit,
// and the host already makes this trade for every other plugin. See plan §10.
