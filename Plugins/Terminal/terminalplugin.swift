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

// MARK: - Sessions

/// One pseudo-terminal, its child process and its scrollback.
///
/// Outlives every view that shows it. The view hierarchy is where it is *displayed*; ownership is the
/// pool's, and only the pool ends it.
final class TerminalSession: NSObject, LocalProcessTerminalViewDelegate {

    /// Stable across the session's life, so a view can say which of several it is showing.
    let id: Int
    let view = LocalProcessTerminalView(frame: .zero)
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
        // OSC 7. Only some shells emit it, so this is a bonus rather than something to rely on.
        if let directory, !directory.isEmpty { self.directory = directory }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        exited = true
        title = exitCode.map { "exited (\($0))" } ?? "exited"
        onChange?()
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
            status.stringValue = "pane \(focused + 1)/\(panes.count) · tab \(index + 1)/\(tabs.count) · "
                + "session \(s.id) · \(s.title) · \(s.cols)×\(s.rows)"
                + (container.isEmpty ? "" : " · \(container)")
        }
    }

    // MARK: Host context

    func notify(key: String, value: String) {
        switch key {
        case "container": container = value; refreshChrome()
        case "sendText":  selectedSession?.send(value)
        case "newTab":    newTab()
        case "selectTab": if let i = Int(value) { selectTab(i - 1) }   // 1-based, as the status line reads
        case "closeTab":  if let i = Int(value) { closeTab(i - 1) }
        case "split":     split()
        case "maximise":  maximise()
        case "focusPane": if let i = Int(value), panes.indices.contains(i - 1) { focused = i - 1; refreshChrome() }
        case "theme":
            // Re-read rather than trusting the id: the host sends the theme's name, and what a name
            // means is exactly what may have changed.
            theme = PluginTheme(services)
            applyTheme()
        default:          break
        }
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

// MARK: - The contribution ABI

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ container: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    let where_ = container.map { String(cString: $0) } ?? ""
    let view = TerminalContainerView(container: where_, services: services?.pointee)
    return Unmanaged.passRetained(view).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
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
