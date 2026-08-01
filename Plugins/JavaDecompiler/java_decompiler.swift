// SPDX-License-Identifier: Apache-2.0
// java_decompiler.swift — F3 on a .class file shows Java source (F-345).
//
// A PLX lister that decompiles *nothing itself*. All it does is pick an engine — CFR, Vineflower,
// Procyon, javap, or one the user configured — run it, and show what comes back. The machinery
// lives in Plugins/SDK/PluginDecompiler.swift so the next format (dex, wasm, pyc) inherits it.
//
// No engine is bundled. The best-known Java decompiler, JD-Core, is GPLv3 and could not ship
// inside an Apache-2.0 app; the permissive alternatives are better maintained anyway. That
// constraint turned into the feature the user asked for: engines are interchangeable.
//
// Files inside archives need no special handling. F3 on an entry in a JAR or ZIP goes through the
// host's `localPathForCursor`, which extracts to a temp file and opens the lister on that — so a
// plugin that claims .class already works inside archives.

import AppKit
import os

/// Diagnostics. A plugin that shells out to tools the user installed has to be able to answer
/// "which engine ran, and what did it say" — otherwise a missing JAR or a bad argument line is
/// invisible. os.Logger, not NSLog: NSLog does not reach the unified log from this app.
let log = Logger(subsystem: "com.peachcommander", category: "JavaDecompiler")

// MARK: - The view

final class DecompiledView: NSView {
    private let scroll = NSScrollView()
    private let text = NSTextView()
    private let status = NSTextField(labelWithString: "")
    private let enginePopup = NSPopUpButton()
    private let revealButton = NSButton(title: L("Engine Folder…"), target: nil, action: nil)

    private let path: String
    private let kind: String
    private let registry: DecompilerRegistry
    /// Engines that can handle this file, in preference order; the popup mirrors it.
    private let candidates: [DecompilerEngine]
    /// Decompiled text per engine id, so switching back and forth is instant.
    private var cache: [String: String] = [:]

    init(path: String, configRoot: String) {
        self.path = path
        self.configRootPath = configRoot
        self.kind = (path as NSString).pathExtension.lowercased()
        self.registry = DecompilerRegistry(configRoot: configRoot)
        self.candidates = registry.engines(for: kind.isEmpty ? "class" : kind)
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        build()
        // Prefer an engine that is actually installed; otherwise show the first one so the view
        // can explain what to install rather than presenting an empty popup.
        log.info("open \((path as NSString).lastPathComponent, privacy: .public): \(self.candidates.count) engine(s), available: \(self.candidates.filter(\.isAvailable).map(\.id).joined(separator: ","), privacy: .public)")
        let initial = candidates.firstIndex { $0.isAvailable } ?? 0
        if !candidates.isEmpty {
            enginePopup.selectItem(at: initial)
            run(candidates[initial])
        } else {
            show(error: .noEngine(kind: kind))
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        text.isEditable = false
        text.isRichText = false
        text.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        text.textContainerInset = NSSize(width: 6, height: 6)
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        for (i, engine) in candidates.enumerated() {
            // Mark what cannot run, so the popup explains the situation instead of silently
            // failing when the user picks an engine they have not installed.
            let suffix = engine.isAvailable ? "" : " — " + L("not installed")
            enginePopup.addItem(withTitle: engine.name + suffix)
            enginePopup.lastItem?.tag = i
        }
        enginePopup.target = self
        enginePopup.action = #selector(engineChanged)
        enginePopup.translatesAutoresizingMaskIntoConstraints = false
        enginePopup.isEnabled = candidates.count > 1

        revealButton.target = self
        revealButton.action = #selector(revealEngineFolder)
        revealButton.bezelStyle = .rounded
        revealButton.translatesAutoresizingMaskIntoConstraints = false

        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.translatesAutoresizingMaskIntoConstraints = false

        for v in [scroll, enginePopup, revealButton, status] { addSubview(v) }
        NSLayoutConstraint.activate([
            enginePopup.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            enginePopup.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            revealButton.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            revealButton.leadingAnchor.constraint(equalTo: enginePopup.trailingAnchor, constant: 8),
            status.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            status.leadingAnchor.constraint(equalTo: revealButton.trailingAnchor, constant: 12),
            status.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: enginePopup.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: Running

    @objc private func engineChanged() {
        let i = enginePopup.selectedItem?.tag ?? 0
        guard candidates.indices.contains(i) else { return }
        run(candidates[i])
    }

    @objc private func revealEngineFolder() {
        // Created on demand, never at launch: making directories in someone's configuration for a
        // feature they may never use is not ours to decide.
        try? FileManager.default.createDirectory(atPath: engineDirectory, withIntermediateDirectories: true)
        writeReadmeIfMissing()
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: engineDirectory)])
    }

    private let configRootPath: String
    private var engineDirectory: String {
        DecompilerRegistry.engineDirectory(configRoot: configRootPath)
    }

    /// A note in the engine folder naming the engines, their licences and where to get them —
    /// the alternative to downloading anything on the user's behalf.
    private func writeReadmeIfMissing() {
        let readme = (engineDirectory as NSString).appendingPathComponent("README.txt")
        guard !FileManager.default.fileExists(atPath: readme) else { return }
        var lines = [
            "Decompiler engines for Peach Commander",
            "======================================",
            "",
            "Put an engine's .jar in this folder. Nothing is downloaded for you: these are",
            "third-party programs with their own licences, and the app neither fetches nor",
            "updates them.",
            "",
        ]
        for engine in DecompilerEngine.builtIns(engineDirectory: engineDirectory) {
            lines.append("* \(engine.name)")
            if let note = engine.note { lines.append("  \(note)") }
            if let p = engine.enginePath {
                lines.append("  expected at: \((p as NSString).lastPathComponent)")
            }
            lines.append("")
        }
        lines += [
            "To add your own engine, create decompilers.ini in this folder:",
            "",
            "    [myengine]",
            "    name   = My Decompiler",
            "    kinds  = class",
            "    tool   = java",
            "    args   = -jar {engine} {input}",
            "    engine = ~/path/to/engine.jar",
            "    output = stdout          ; or: directory",
            "",
            "{input}, {engine} and {outdir} are substituted when the engine runs.",
        ]
        try? lines.joined(separator: "\n").write(toFile: readme, atomically: true, encoding: .utf8)
    }

    private func run(_ engine: DecompilerEngine) {
        if let cached = cache[engine.id] {
            text.string = cached
            status.stringValue = engine.name
            return
        }
        guard engine.isAvailable else {
            show(error: engine.missingPath.map { .engineMissing(engine: engine.name, path: $0) }
                    ?? .engineMissing(engine: engine.name, path: engine.tool),
                 note: engine.note)
            return
        }
        status.stringValue = String(format: L("Decompiling with %@…"), engine.name)
        text.string = ""
        // Off the main thread: a large class takes seconds, and the viewer window is already on
        // screen — blocking here would freeze it mid-open.
        let file = path
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = DecompilerRunner.run(engine, input: file)
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let source):
                    log.info("\(engine.id, privacy: .public) produced \(source.count) characters")
                    self.cache[engine.id] = source
                    self.text.string = source
                    self.status.stringValue = engine.name
                case .failure(let error):
                    log.warning("\(engine.id, privacy: .public): \(error.userMessage, privacy: .public)")
                    self.show(error: error, note: engine.note)
                }
            }
        }
    }

    private func show(error: DecompileError, note: String? = nil) {
        status.stringValue = error.userMessage
        var body = [error.userMessage, ""]
        if let note, !note.isEmpty { body += [note, ""] }
        if case .noEngine = error {
            body.append(L("Install one of these engines, then reopen this file:"))
            body.append("")
            for engine in candidates.isEmpty
                ? DecompilerEngine.builtIns(engineDirectory: engineDirectory) : candidates {
                body.append("  • \(engine.name)")
                if let n = engine.note { body.append("    \(n)") }
            }
            body.append("")
            body.append(L("“Engine Folder…” opens the folder they belong in."))
        }
        text.string = body.joined(separator: "\n")
    }

    // MARK: Viewer commands

    func find(_ needle: String, matchCase: Bool) -> Bool {
        let haystack = text.string
        let options: String.CompareOptions = matchCase ? [] : [.caseInsensitive]
        guard let range = haystack.range(of: needle, options: options) else { return false }
        let ns = NSRange(range, in: haystack)
        text.scrollRangeToVisible(ns)
        text.setSelectedRange(ns)
        return true
    }

    func selectAll() { text.setSelectedRange(NSRange(location: 0, length: (text.string as NSString).length)) }

    func copySelection() {
        let sel = text.selectedRange()
        let content = sel.length > 0 ? (text.string as NSString).substring(with: sel) : text.string
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
}

// MARK: - PLX entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("ListGetDetectString")
public func ListGetDetectString(_ buf: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) {
    guard let buf, maxlen > 0 else { return }
    // Extension first, magic bytes second: CAFEBABE catches a class file whose name was lost.
    let detect = "EXT=\"CLASS\" | ([0]=202 & [1]=254 & [2]=186 & [3]=190)"
    _ = detect.withCString { strlcpy(buf, $0, Int(maxlen)) }
}

@_cdecl("ListLoad")
public func ListLoad(_ parent: UnsafeMutableRawPointer?, _ file: UnsafeMutablePointer<CChar>?,
                     _ showFlags: Int32) -> UnsafeMutableRawPointer? {
    guard let file, let path = String(validatingUTF8: file),
          FileManager.default.isReadableFile(atPath: path) else { return nil }
    let root = configRoot()
    let view = DecompiledView(path: path, configRoot: root)
    return Unmanaged.passRetained(view).toOpaque()
}

@_cdecl("ListCloseWindow")
public func ListCloseWindow(_ listWin: UnsafeMutableRawPointer?) {
    guard let listWin else { return }
    Unmanaged<DecompiledView>.fromOpaque(listWin).release()
}

@_cdecl("ListSearchText")
public func ListSearchText(_ listWin: UnsafeMutableRawPointer?, _ searchString: UnsafeMutablePointer<CChar>?,
                           _ options: Int32) -> Int32 {
    guard let listWin, let searchString, let needle = String(validatingUTF8: searchString) else { return 1 }
    let view = Unmanaged<DecompiledView>.fromOpaque(listWin).takeUnretainedValue()
    return view.find(needle, matchCase: options & 0x0001 != 0) ? 0 : 1
}

@_cdecl("ListSendCommand")
public func ListSendCommand(_ listWin: UnsafeMutableRawPointer?, _ command: Int32, _ parameter: Int32) -> Int32 {
    guard let listWin else { return 1 }
    let view = Unmanaged<DecompiledView>.fromOpaque(listWin).takeUnretainedValue()
    switch command {
    case 1: view.copySelection(); return 0     // PC_LC_COPY
    case 2: view.selectAll(); return 0         // PC_LC_SELECTALL
    default: return 1
    }
}

/// The host's configuration directory, where engines and `decompilers.ini` live.
///
/// Resolved the same way `ConfigPaths` does, including the -ConfigRoot override, so a scripted or
/// sandboxed run finds the same folder the rest of the app uses.
private func configRoot() -> String {
    let args = ProcessInfo.processInfo.arguments
    if let i = args.firstIndex(of: "-ConfigRoot"), i + 1 < args.count { return args[i + 1] }
    if let env = ProcessInfo.processInfo.environment["PEACHCMD_CONFIG_ROOT"], !env.isEmpty { return env }
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
    return appSupport.appendingPathComponent("PeachCommander").path
}
