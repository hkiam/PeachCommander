// SPDX-License-Identifier: Apache-2.0
// terminalplugin.swift — an embedded terminal, one session (F-381).
//
// The emulator is SwiftTerm (MIT, pinned in project.yml, compiled in by Tools/build-terminal-plugin.sh
// — referenced, never copied into this repository). Writing one instead was never seriously on the
// table: a terminal that runs `top` and Claude Code needs the alternate screen buffer, scroll regions,
// cursor addressing, 256-colour and true-colour SGR, bracketed paste, SGR-1006 mouse reporting, wide
// characters and combining marks, and a resize path that sends SIGWINCH with the right winsize.
// Getting that subtly wrong is the difference between "works" and "htop redraws garbage".
//
// What this file is responsible for is everything around it.
//
// **The shell is the user's.** Their `$SHELL`, started as a login shell, in the folder the panel is
// looking at. That is not laziness: autocomplete, history, Ctrl+R, the prompt and every alias are the
// shell's job, and anything reimplemented here would be a worse zsh. A login shell is what gives the
// child the PATH the user actually has, since an app launched from Finder does not inherit one.
//
// **Teardown has to be real.** SIGHUP to the process *group*, not the process: a shell that started
// `make -j8` has children, and killing only the shell orphans them. The child is in its own session
// (SwiftTerm's LocalProcess uses login_tty and POSIX_SPAWN_SETSID) which is the only reason the group
// is addressable at all. Then wait, and SIGKILL what is left. Section 5 of the plan goes further —
// confirm-on-close when something is running, a `ps` scenario as an independent witness — and that is
// the next stage; what is here must at least not leak.
//
// **`sendText` is not a test hook.** The host will use it for "open terminal here", for dropping file
// names into the prompt and for the command line's "run in the terminal" option (plan §7). It arrives
// now because it is also how a scenario can drive the thing, and a channel that ships is worth more
// than one that only exists under test.

import AppKit

/// The terminal, its shell, and a status line.
///
/// A wrapper rather than a subclass of `LocalProcessTerminalView`: the status line is ours, and the
/// emulator should stay something we can swap without the surrounding code noticing.
final class TerminalSessionView: NSView, LocalProcessTerminalViewDelegate {

    private let terminal = LocalProcessTerminalView(frame: .zero)
    private let status = NSTextField(labelWithString: "")
    /// What the running program calls itself (OSC 0/1/2), else the shell's name.
    private var programTitle: String
    private var size = (cols: 0, rows: 0)
    /// Where the panel is looking. Used for the shell's initial directory, and remembered afterwards
    /// so that a `cd` sent later has somewhere to go.
    private var hostDirectory: String?
    private var started = false

    /// The shell to run: the user's, or a sane default when `$SHELL` is unset or nonsense.
    private static var loginShell: String {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? ""
        return FileManager.default.isExecutableFile(atPath: shell) ? shell : "/bin/zsh"
    }

    init(container: String, directory: String?) {
        self.programTitle = (Self.loginShell as NSString).lastPathComponent
        self.hostDirectory = directory
        super.init(frame: .zero)

        terminal.translatesAutoresizingMaskIntoConstraints = false
        terminal.processDelegate = self
        addSubview(terminal)

        status.translatesAutoresizingMaskIntoConstraints = false
        status.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingMiddle
        addSubview(status)

        NSLayoutConstraint.activate([
            terminal.topAnchor.constraint(equalTo: topAnchor),
            terminal.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: trailingAnchor),
            status.topAnchor.constraint(equalTo: terminal.bottomAnchor),
            status.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            status.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            status.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            status.heightAnchor.constraint(equalToConstant: 13),
        ])
        refreshStatus(container: container)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Start the shell once the view is in a window.
    ///
    /// Not in `init`: the pseudo-terminal's size comes from the view's geometry, and a view with no
    /// frame yet reports a nonsense one. A shell told it has 0 columns prints its prompt somewhere
    /// nobody can see and never recovers, because the size is only pushed again when it changes.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !started else { return }
        started = true
        let shell = Self.loginShell
        // `-l`: a login shell, so the child gets the PATH and the environment the user's dotfiles
        // build. An app launched from Finder has neither.
        terminal.startProcess(executable: shell, args: ["-l"], environment: nil,
                              execName: "-" + (shell as NSString).lastPathComponent,
                              currentDirectory: hostDirectory)
    }

    // MARK: - Host context

    func notify(key: String, value: String) {
        switch key {
        case "container":
            refreshStatus(container: value)
        case "dir":
            hostDirectory = value.isEmpty ? nil : value
        case "theme":
            needsDisplay = true
        case "sendText":
            // Straight into the pseudo-terminal, exactly as if it had been typed. The host uses this
            // for "open terminal here" and for dropping file names at the prompt; it is also how a
            // scenario drives the terminal, since nothing outside the plugin can reach the buffer.
            terminal.send(txt: value)
        default:
            break
        }
    }

    private var container = ""

    private func refreshStatus(container: String? = nil) {
        if let container { self.container = container }
        let where_ = self.container.isEmpty ? "" : " · \(self.container)"
        status.stringValue = "\(programTitle) · \(size.cols)×\(size.rows)\(where_)"
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        size = (newCols, newRows)
        refreshStatus()
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        // The shell sets this for free and full-screen programs set it themselves, which is why the
        // status line follows it rather than guessing from the process table.
        programTitle = title.isEmpty ? (Self.loginShell as NSString).lastPathComponent : title
        refreshStatus()
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        // OSC 7. Only some shells emit it, so this is a bonus rather than something to rely on.
        if let directory, !directory.isEmpty { hostDirectory = directory }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        programTitle = exitCode.map { "exited (\($0))" } ?? "exited"
        refreshStatus()
    }

    // MARK: - Teardown

    /// Stop the shell and everything it started.
    ///
    /// The group, not the process. `terminate()` alone leaves a `make -j8` running with no terminal to
    /// print to and nobody to reap it — the classic embedded-terminal leak. Escalation is deliberate:
    /// SIGHUP is what a closing terminal is supposed to send and what shells handle gracefully;
    /// SIGKILL is for whatever ignored it.
    func teardown() {
        let pid = terminal.process.shellPid
        if pid > 0 {
            // Negative pid = the whole process group. The child got its own session from login_tty,
            // so its group id is its pid.
            kill(-pid, SIGHUP)
            // Give it a moment to go on its own before insisting. Two seconds is the plan's figure;
            // this runs on the main thread during teardown, so it polls rather than sleeps through.
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
        terminal.terminate()
    }
}

// MARK: - The contribution ABI

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ container: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    let where_ = container.map { String(cString: $0) } ?? ""
    // The folder the active panel is looking at, so a new terminal opens where the user already is.
    // That is the whole reason to embed one rather than launch Terminal.app.
    var directory: String?
    if let services {
        let svc = services.pointee
        var buf = [CChar](repeating: 0, count: 4096)
        // "dir" is the same key the host pushes through PcNotifyView as the panel moves, read here
        // through getContext so a view built later still starts in the right place.
        if let fn = svc.getContext, "dir".withCString({ fn(svc.host, $0, &buf, 4096) }) != 0 {
            let path = String(cString: buf)
            if !path.isEmpty { directory = path }
        }
    }
    return Unmanaged.passRetained(TerminalSessionView(container: where_, directory: directory)).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    (Unmanaged<NSView>.fromOpaque(view).takeUnretainedValue() as? TerminalSessionView)?.teardown()
    Unmanaged<NSView>.fromOpaque(view).release()
}

@_cdecl("PcNotifyView")
public func PcNotifyView(_ view: UnsafeMutableRawPointer?, _ key: UnsafePointer<CChar>?,
                         _ value: UnsafePointer<CChar>?) {
    guard let view, let key else { return }
    let target = Unmanaged<NSView>.fromOpaque(view).takeUnretainedValue() as? TerminalSessionView
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
