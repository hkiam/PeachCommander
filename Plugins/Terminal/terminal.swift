// SPDX-License-Identifier: Apache-2.0
// terminal.swift — the Terminal plugin, stage one: everything except the terminal (F-381).
//
// The plan (docs/analysis/terminal-plugin-plan.md, §11) puts the skeleton before the emulator, and on
// purpose: "prove removability *before* there is anything to lose". A plugin that cannot be pulled
// back out is a plugin nobody should install, and that is far cheaper to find out now than after a
// pseudo-terminal, a process group and a scrollback buffer are hanging off it.
//
// It is not an empty box, though. Three things the host has so far only been able to claim about
// itself are witnessed here, from the other side of the C ABI:
//
//   * **A moved view is re-parented, not rebuilt.** Every call to `PcMakeView` takes the next instance
//     number, and the view shows it. Drag it from the dock to the side panel and the number must not
//     change — the host counts its own `PcMakeView`/`PcCloseView` calls and says the same thing, but
//     the plugin's own count is not the host marking its own homework.
//   * **A re-parented view is told where it landed.** `PcNotifyView(view, "container", …)` was added
//     with nothing to receive it. The view shows the container it believes it is in and how many
//     notifications it has had.
//   * **The keyboard.** The manifest declares `rawKeyboard`, so this view keeps F5 and Ctrl+B instead
//     of the file panel taking them. There is nothing here yet that needs them; there will be, and the
//     rule is easier to test against a view that displays what it received than against a shell.
//
// Deliberately *one* view, not two. The plan sketched a dock view and a sidebar view declared
// separately, which is now the wrong shape: since placement became the user's, one view can be moved
// wherever it is wanted. Two views means two terminals, which is a question for when there are
// sessions to put in them.

import AppKit

/// Instance counter. Every `PcMakeView` takes the next number, and a view that was re-parented rather
/// than rebuilt keeps the one it had — which is the whole claim, so it is displayed rather than logged.
private let instanceLock = NSLock()
private var instanceCount = 0

private func nextInstance() -> Int {
    instanceLock.lock(); defer { instanceLock.unlock() }
    instanceCount += 1
    return instanceCount
}

/// What will become the terminal. For now it reports its own circumstances.
final class TerminalPlaceholderView: NSView {
    private let instance: Int
    private var container: String
    private var notifications = 0
    private let label = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")

    init(viewId: String, container: String) {
        self.instance = nextInstance()
        self.container = container
        super.init(frame: .zero)
        wantsLayer = true

        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.alignment = .center
        label.stringValue = L("Terminal")

        // Monospaced, because every number in it is meant to be compared with the one beside it, and
        // because this is the font the thing that replaces this view will use.
        detail.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        detail.alignment = .center

        for view in [label, detail] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),
            detail.centerXAnchor.constraint(equalTo: centerXAnchor),
            detail.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
        ])
        applyTheme()
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Take a host context change. Only `container` and `theme` mean anything here yet; the rest are
    /// counted, so a scenario can tell "the host said nothing" from "the host said something else".
    func notify(key: String, value: String) {
        notifications += 1
        switch key {
        case "container": container = value
        case "theme": applyTheme()
        default: break
        }
        refresh()
    }

    private func refresh() {
        // One line, in a shape a scenario can assert on without a parser.
        detail.stringValue = "instance=\(instance) container=\(container) notified=\(notifications)"
    }

    private func applyTheme() {
        label.textColor = .labelColor
        detail.textColor = .secondaryLabelColor
    }

    /// The host asks the *view* whether it is willing to go away — a terminal will have something to
    /// say here once it has a process. For now it always is.
    func teardown() {}
}

// MARK: - The contribution ABI

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ container: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    let id = viewId.map { String(cString: $0) } ?? ""
    // The container is passed at build time so a plugin can render for the room it is in — 26 columns
    // in the side panel against 161 in the dock is not a difference a terminal can ignore.
    let where_ = container.map { String(cString: $0) } ?? ""
    return Unmanaged.passRetained(TerminalPlaceholderView(viewId: id, container: where_)).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    (Unmanaged<NSView>.fromOpaque(view).takeUnretainedValue() as? TerminalPlaceholderView)?.teardown()
    Unmanaged<NSView>.fromOpaque(view).release()
}

@_cdecl("PcNotifyView")
public func PcNotifyView(_ view: UnsafeMutableRawPointer?, _ key: UnsafePointer<CChar>?,
                         _ value: UnsafePointer<CChar>?) {
    guard let view, let key else { return }
    let target = Unmanaged<NSView>.fromOpaque(view).takeUnretainedValue() as? TerminalPlaceholderView
    target?.notify(key: String(cString: key), value: value.map { String(cString: $0) } ?? "")
}

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    // No commands yet. The symbol exists because `ContribPlugin.hasBehavior` is `PcRunCommand != nil`:
    // without it the host treats the bundle as carrying no contribution behaviour at all and never
    // asks it for a view.
}

// Deliberately no `PcSafeToUnload`. `PluginLibrary` only calls `dlclose` on a library that exports it,
// and a terminal's threads will outlive the last view's teardown by however long a child takes to die.
// Unloading the code out from under a thread that is still reading a file descriptor is a crash on
// quit, and the host already makes this trade for every other plugin. See plan §10.
