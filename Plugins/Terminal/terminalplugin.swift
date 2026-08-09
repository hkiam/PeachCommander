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
final class TerminalContainerView: NSView {

    private static let tabBarHeight: CGFloat = 26
    private static let statusHeight: CGFloat = 14

    /// The sessions *this* view shows, in tab order. A subset of the pool: another mounted view may
    /// hold others, which is what lets a quick shell live in the side panel while something long
    /// runs in the dock.
    private var tabs: [TerminalSession] = []
    private var selected = 0

    private let tabStrip = NSStackView()
    private let addButton = NSButton(title: "+", target: nil, action: nil)
    private let content = NSView()
    private let status = NSTextField(labelWithString: "")
    private var container: String
    /// Kept so a new tab can start where the panel is looking. The host guarantees the services table
    /// stays valid for the view's lifetime; the struct is copied rather than the pointer held.
    private var services: PcHostServices?

    init(container: String, services: PcHostServices?) {
        self.container = container
        self.services = services
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

        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        status.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingMiddle
        status.translatesAutoresizingMaskIntoConstraints = false
        addSubview(status)

        // One point below required on the top inset, for the same reason the dock's own header is:
        // a collapsed view is zero points tall, and "content starts below the tab bar" and "content
        // reaches the bottom" cannot both hold in zero points.
        let contentTop = content.topAnchor.constraint(equalTo: topAnchor, constant: Self.tabBarHeight)
        contentTop.priority = .required - 1

        NSLayoutConstraint.activate([
            tabStrip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            tabStrip.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            tabStrip.heightAnchor.constraint(equalToConstant: Self.tabBarHeight - 4),
            addButton.leadingAnchor.constraint(equalTo: tabStrip.trailingAnchor, constant: 4),
            addButton.centerYAnchor.constraint(equalTo: tabStrip.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 20),
            contentTop,
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: status.topAnchor),
            status.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            status.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            status.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            status.heightAnchor.constraint(equalToConstant: Self.statusHeight),
        ])
        newTab()
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
        tabs.append(session)
        selected = tabs.count - 1
        showSelected()
        return session
    }

    func selectTab(_ index: Int) {
        guard tabs.indices.contains(index), index != selected else { return }
        selected = index
        showSelected()
    }

    /// Close the tab, and with it the session — this is the one place a session ends by request.
    func closeTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        TerminalPool.close(tabs.remove(at: index))
        if tabs.isEmpty { newTab() }     // an empty terminal is not a state worth showing
        else { selected = min(selected, tabs.count - 1); showSelected() }
    }

    var selectedSession: TerminalSession? { tabs.indices.contains(selected) ? tabs[selected] : nil }

    private func showSelected() {
        guard let session = selectedSession else { return }
        // Hide rather than remove: taking a session's view out of the hierarchy and putting it back
        // makes AppKit re-run its geometry, and the pseudo-terminal would be resized twice for a tab
        // switch that changed nothing about its size.
        for tab in tabs where tab.view.superview === content { tab.view.isHidden = tab !== session }
        if session.view.superview !== content {
            session.view.isHidden = false
            content.addSubview(session.view)
            NSLayoutConstraint.activate([
                session.view.topAnchor.constraint(equalTo: content.topAnchor),
                session.view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                session.view.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                session.view.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        }
        refreshChrome()
        window?.makeFirstResponder(session.view)
        // Force the constraint engine to run before asking the session to start. A tab created after
        // the view is on screen has constraints but no frame yet, and a shell started against a
        // zero-width view is told it has no columns — measured: the second tab reported 0×0 and never
        // recovered, because a pseudo-terminal's size is pushed again only when it *changes*.
        layoutSubtreeIfNeeded()
        // The size, and only then the shell — on the next turn of the run loop.
        //
        // `TerminalView.setFrameSize` recomputes the grid only once its cell dimensions are known and
        // returns early otherwise, and those are not known until the view has been through a display
        // cycle. For the first tab that costs nothing: the window is still settling and another resize
        // follows. For a tab created into a view that already has its final geometry, no further
        // resize ever comes — so the terminal kept SwiftTerm's default 80×25 while showing 125
        // columns, and every line the shell printed wrapped in the wrong place. Measured twice: doing
        // this synchronously after `layoutSubtreeIfNeeded` is still too early.
        DispatchQueue.main.async { [weak self, weak session] in
            guard let session, session.view.superview != nil else { return }
            session.view.setFrameSize(session.view.frame.size)
            session.startIfNeeded()
            self?.refreshChrome()
        }
    }

    @objc private func newTabPressed() { newTab() }
    @objc private func tabPressed(_ sender: NSButton) { selectTab(sender.tag) }

    private func refreshChrome() {
        for view in tabStrip.arrangedSubviews { tabStrip.removeArrangedSubview(view); view.removeFromSuperview() }
        for (i, tab) in tabs.enumerated() {
            let button = NSButton(title: tab.title, target: self, action: #selector(tabPressed(_:)))
            button.tag = i
            button.bezelStyle = .recessed
            button.setButtonType(.pushOnPushOff)
            button.state = i == selected ? .on : .off
            button.font = .systemFont(ofSize: 11)
            tabStrip.addArrangedSubview(button)
        }
        // One line a scenario can assert on without a parser, and a line a user can read: which tab of
        // how many, what is running, how big the terminal thinks it is, and where it is docked.
        if let s = selectedSession {
            status.stringValue = "tab \(selected + 1)/\(tabs.count) · session \(s.id) · \(s.title) · "
                + "\(s.cols)×\(s.rows)" + (container.isEmpty ? "" : " · \(container)")
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
        case "theme":     needsDisplay = true
        default:          break
        }
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

    /// The view is going away for good: end every session it holds.
    ///
    /// Only the sessions in *this* view's tabs. Another mounted view's sessions are not this one's to
    /// end, which is the point of the pool being shared.
    func teardown() {
        for tab in tabs { TerminalPool.close(tab) }
        tabs.removeAll()
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
