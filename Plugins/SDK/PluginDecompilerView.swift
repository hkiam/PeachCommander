// SPDX-License-Identifier: Apache-2.0
// PluginDecompilerView.swift — the single-document decompiler view, shared by decompiler plugins.
//
// Was Plugins/JavaDecompiler/java_decompiler.swift until a second decompiler plugin needed the same
// view. Nothing here is Java-specific any more: the formats, the language to highlight, the file
// extension to save under and the ids the manifest declares all come from a `PluginDecompilerProfile`.
// A plugin is that profile plus its C exports.
//
// The plugin decompiles *nothing itself*. It picks an engine the user installed, runs it, and shows
// what comes back. No engine is bundled: the best-known Java decompiler is GPLv3 and could not ship
// inside an Apache-2.0 app, and the same licence question decides .NET the same way. That constraint
// turned into the feature — engines are interchangeable.
//
// Files inside archives need no special handling. F3 on an entry in a JAR, a ZIP or a NuGet package
// goes through the host's `localPathForCursor`, which extracts to a temp file and opens the lister on
// that — so a plugin that claims .class or .dll already works inside archives.

import AppKit
import os

/// Diagnostics. A plugin that shells out to tools the user installed has to be able to answer
/// "which engine ran, and what did it say" — otherwise a missing JAR or a bad argument line is
/// invisible. os.Logger, not NSLog: NSLog does not reach the unified log from this app.
let log = Logger(subsystem: "com.peachcommander", category: "Decompiler")

/// A read-only monospaced text view ready to be a scroll view's document view.
///
/// The explicit frame and container settings are not decoration. A bare `NSTextView()` has a zero
/// frame and a zero text container, so it lays out no glyphs at all: the text is in the storage, the
/// panel is on screen, and nothing appears. That is exactly what shipped from a check that read
/// `text.string` back instead of looking at the window — the data was right and the view was blank.
func makeSourceTextView() -> NSTextView {
    let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    view.isEditable = false
    view.isRichText = false
    view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    view.textContainerInset = NSSize(width: 6, height: 6)
    view.minSize = NSSize(width: 0, height: 0)
    view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                          height: CGFloat.greatestFiniteMagnitude)
    view.isVerticallyResizable = true
    // No wrapping, and a container that can grow sideways: every one of these views sits in a scroll
    // view with a horizontal scroller, and wrapping would mean that scroller could never appear.
    // Bytecode is the case that decides it — javap output is columns, and a wrapped column is noise.
    view.isHorizontallyResizable = true
    view.autoresizingMask = [.width, .height]
    view.textContainer?.widthTracksTextView = false
    view.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                               height: CGFloat.greatestFiniteMagnitude)
    return view
}

// MARK: - What the lister ABI can ask of a view

/// The commands `ListSendCommand` and `ListSearchText` forward, whichever view `ListLoad` built.
///
/// A base class rather than a protocol because the entry points recover the view from an opaque
/// pointer, and `Unmanaged<T>` needs a class. Defaults do nothing rather than being abstract: a view
/// that cannot sensibly zoom should decline the command, not crash the host that sent it.
class DecompilerListerView: NSView {
    func find(_ needle: String, matchCase: Bool) -> Bool { false }
    func selectAll() {}
    func changeFontSize(by delta: CGFloat) {}
    func copySelection() {}
}

// MARK: - The view

final class DecompiledView: DecompilerListerView {
    private let profile: PluginDecompilerProfile
    private let scroll = NSScrollView()
    private let text = makeSourceTextView()
    private let status = NSTextField(labelWithString: "")
    private let enginePopup = NSPopUpButton()
    private let revealButton = NSButton(title: L("Engine Folder…"), target: nil, action: nil)
    private let saveButton = NSButton(title: L("Save As…"), target: nil, action: nil)
    private let openButton = NSButton(title: L("Open in Editor"), target: nil, action: nil)
    /// Second pane (F-348). "Compare two engines" and "source next to bytecode" are the same
    /// mechanism with different engine choices, so it is built once.
    private let compareToggle = NSButton(checkboxWithTitle: L("Compare"), target: nil, action: nil)
    private let secondPopup = NSPopUpButton()
    private let secondScroll = NSScrollView()
    private let secondText = makeSourceTextView()
    private var showingSecondPane = false
    private var splitConstraints: [NSLayoutConstraint] = []
    /// The unhighlighted source, kept because Save As and Open in Editor must write the code the
    /// engine produced — not the attributed string the view happens to be showing.
    private var currentSource = ""

    private let path: String
    private let kind: String
    private let registry: PluginDecompilerRegistry
    /// Engines that can handle this file, in preference order; the popup mirrors it.
    private let candidates: [PluginDecompilerEngine]
    /// Decompiled text per engine id, so switching back and forth is instant.
    private var cache: [String: String] = [:]

    init(path: String, configRoot: String, profile: PluginDecompilerProfile) {
        self.path = path
        self.configRootPath = configRoot
        self.profile = profile
        self.kind = (path as NSString).pathExtension.lowercased()
        self.registry = PluginDecompilerRegistry(configRoot: configRoot, profile: profile.id)
        // Every engine for this kind, whatever result shape it produces: when the tree view declined
        // because no archive-capable engine is installed, this view is what is left to show monodis's
        // listing, and filtering the list here would leave it empty.
        self.candidates = registry.engines(
            for: profile.handles(kind: kind) ? kind : (profile.singleKinds.sorted().first ?? kind))
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        build()
        // Prefer an engine that is actually installed; otherwise show the first one so the view
        // can explain what to install rather than presenting an empty popup.
        log.info("open \((path as NSString).lastPathComponent, privacy: .public): \(self.candidates.count) engine(s), available: \(self.candidates.filter(\.isAvailable).map(\.id).joined(separator: ","), privacy: .public)")
        // The engine chosen last for this kind wins, if it is still installed. Someone who prefers
        // Vineflower should not have to pick it again for every file.
        let preferred = PluginDecompilerPreference.read(configRoot: configRoot)[kind]
        let initial = candidates.firstIndex { $0.id == preferred && $0.isAvailable }
            ?? candidates.firstIndex { $0.isAvailable } ?? 0
        if !candidates.isEmpty {
            enginePopup.selectItem(at: initial)
            run(candidates[initial])
        } else {
            show(error: .noEngine(kind: kind))
        }
        // Debug hook, like PC_AI_PROBE in the AI plugin: the compare checkbox cannot be clicked
        // from a script, and the layout swap is the part worth verifying automatically.
        if ProcessInfo.processInfo.environment["PC_DECOMPILE_COMPARE"] != nil {
            compareToggle.state = .on
            toggleCompare()
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
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

        for (button, action) in [(revealButton, #selector(revealEngineFolder)),
                                 (saveButton, #selector(saveAs)),
                                 (openButton, #selector(openInEditor))] {
            button.target = self
            button.action = action
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
            // Nothing to save or open until an engine has produced something.
            if button !== revealButton { button.isEnabled = false }
        }

        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.translatesAutoresizingMaskIntoConstraints = false

        secondScroll.documentView = secondText
        secondScroll.hasVerticalScroller = true
        secondScroll.hasHorizontalScroller = true
        secondScroll.autohidesScrollers = true
        secondScroll.translatesAutoresizingMaskIntoConstraints = false
        secondScroll.isHidden = true
        for (i, engine) in candidates.enumerated() {
            secondPopup.addItem(withTitle: engine.name + (engine.isAvailable ? "" : " — " + L("not installed")))
            secondPopup.lastItem?.tag = i
        }
        secondPopup.target = self
        secondPopup.action = #selector(secondEngineChanged)
        secondPopup.translatesAutoresizingMaskIntoConstraints = false
        secondPopup.isHidden = true
        compareToggle.target = self
        compareToggle.action = #selector(toggleCompare)
        compareToggle.translatesAutoresizingMaskIntoConstraints = false
        // Nothing to compare against with a single engine.
        compareToggle.isEnabled = candidates.count > 1

        for v in [scroll, secondScroll, enginePopup, revealButton, saveButton, openButton,
                  compareToggle, secondPopup, status] { addSubview(v) }
        NSLayoutConstraint.activate([
            enginePopup.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            enginePopup.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            revealButton.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            revealButton.leadingAnchor.constraint(equalTo: enginePopup.trailingAnchor, constant: 8),
            status.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            saveButton.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            saveButton.leadingAnchor.constraint(equalTo: revealButton.trailingAnchor, constant: 8),
            openButton.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            openButton.leadingAnchor.constraint(equalTo: saveButton.trailingAnchor, constant: 8),
            compareToggle.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            compareToggle.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 12),
            secondPopup.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            secondPopup.leadingAnchor.constraint(equalTo: compareToggle.trailingAnchor, constant: 6),
            status.leadingAnchor.constraint(equalTo: secondPopup.trailingAnchor, constant: 12),
            status.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: enginePopup.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            secondScroll.topAnchor.constraint(equalTo: scroll.topAnchor),
            secondScroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            secondScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        applyPaneLayout()
    }

    // MARK: Two panes (F-348)

    /// One set of constraints per state, swapped as a pair.
    ///
    /// Deactivating the old set before activating the new one matters: leaving the single-pane
    /// trailing edge attached while adding the split would make the two contradict each other, and
    /// Auto Layout resolves that by breaking one at random.
    private func applyPaneLayout() {
        NSLayoutConstraint.deactivate(splitConstraints)
        splitConstraints = showingSecondPane
            ? [scroll.trailingAnchor.constraint(equalTo: secondScroll.leadingAnchor, constant: -1),
               scroll.widthAnchor.constraint(equalTo: secondScroll.widthAnchor)]
            : [scroll.trailingAnchor.constraint(equalTo: trailingAnchor)]
        NSLayoutConstraint.activate(splitConstraints)
        secondScroll.isHidden = !showingSecondPane
        secondPopup.isHidden = !showingSecondPane
    }

    @objc private func toggleCompare() {
        showingSecondPane = compareToggle.state == .on
        applyPaneLayout()
        guard showingSecondPane else { return }
        // Open the second pane on a *different* engine than the first — comparing an engine with
        // itself is the one thing this cannot be for. Prefer a bytecode view next to source, which
        // is the pairing worth having.
        let firstIndex = enginePopup.selectedItem?.tag ?? 0
        let choice = candidates.firstIndex { $0.id == "javap" && $0.isAvailable && $0.id != candidates[firstIndex].id }
            ?? candidates.indices.first { $0 != firstIndex && candidates[$0].isAvailable }
        guard let choice else {
            secondText.string = L("No second engine is installed.")
            return
        }
        secondPopup.selectItem(withTag: choice)
        runSecond(candidates[choice])
    }

    @objc private func secondEngineChanged() {
        let i = secondPopup.selectedItem?.tag ?? 0
        guard candidates.indices.contains(i) else { return }
        runSecond(candidates[i])
    }

    /// The second pane reuses the same cache and runner; only the destination view differs.
    private func runSecond(_ engine: PluginDecompilerEngine) {
        if let cached = cache[engine.id] ?? PluginDecompilerCache.read(path: path, engine: engine,
                                                                      configRoot: configRootPath) {
            cache[engine.id] = cached
            showSecond(cached)
            return
        }
        guard engine.isAvailable else {
            secondText.string = (engine.missingPath.map {
                PluginDecompileError.engineMissing(engine: engine.name, path: $0)
            } ?? .engineMissing(engine: engine.name, path: engine.tool)).userMessage
            return
        }
        secondText.string = String(format: L("Decompiling with %@…"), engine.name)
        let file = path
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginDecompilerRunner.run(engine, input: file)
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let source):
                    self.cache[engine.id] = source
                    PluginDecompilerCache.write(source, path: file, engine: engine,
                                                configRoot: self.configRootPath,
                                                profile: self.profile.id)
                    self.showSecond(source)
                case .failure(let error):
                    self.secondText.string = error.userMessage
                }
            }
        }
    }

    private func showSecond(_ source: String) {
        let font = secondText.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        secondText.textStorage?.setAttributedString(
            PluginSyntax.highlight(source, language: profile.language, palette: .system, font: font))
    }

    // MARK: Running

    @objc private func engineChanged() {
        let i = enginePopup.selectedItem?.tag ?? 0
        guard candidates.indices.contains(i) else { return }
        PluginDecompilerPreference.set(engine: candidates[i].id, forKind: kind, configRoot: configRootPath)
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
        PluginDecompilerRegistry.engineDirectory(configRoot: configRootPath)
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
        // This plugin's engines only. Both decompiler plugins write into the same folder, and a README
        // that listed the other platform's engines would read like advice to install them.
        let kinds = profile.singleKinds.union(profile.treeKinds)
        for engine in PluginDecompilerEngine.builtIns(engineDirectory: engineDirectory)
        where kinds.contains(where: { engine.handles(kind: $0) }) {
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
            "    engine  = engine.jar     ; a bare name is looked up in this folder",
            "    output  = stdout         ; or: directory",
            "    timeout = 30             ; seconds before the engine is stopped",
            "",
            "For F3 on a whole .jar, .apk or .dex, add how the engine is driven over an",
            "archive. Without these two lines the engine is offered for single classes only —",
            "the single-file arguments are never reused on an archive, because that would run",
            "the tool with flags its author never meant:",
            "",
            "    archive_args    = {input} --outputdir {outdir}",
            "    archive_timeout = 300    ; a whole archive is minutes, not seconds",
            "",
            "The result must end up under {outdir}; that directory is what gets read back. An",
            "engine that writes a .jar of sources there instead of a tree is fine — it is",
            "unpacked automatically.",
            "",
            "{input}, {engine} and {outdir} are substituted when the engine runs.",
            "Your own entries take precedence over the built-in ones.",
        ]
        try? lines.joined(separator: "\n").write(toFile: readme, atomically: true, encoding: .utf8)
    }

    private func run(_ engine: PluginDecompilerEngine) {
        if let cached = cache[engine.id] {
            display(cached, engine: engine)
            return
        }
        // Disk cache before spawning anything: reopening a class you looked at yesterday should be
        // instant, and decompiling is measured in seconds.
        if let onDisk = PluginDecompilerCache.read(path: path, engine: engine, configRoot: configRootPath,
                                                   profile: profile.id) {
            cache[engine.id] = onDisk
            display(onDisk, engine: engine)
            log.info("\(engine.id, privacy: .public): served from cache")
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
            let result = PluginDecompilerRunner.run(engine, input: file)
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let source):
                    log.info("\(engine.id, privacy: .public) produced \(source.count) characters")
                    self.cache[engine.id] = source
                    // Only successes are cached — a missing engine is a condition of the system,
                    // and caching it would mean installing the engine changed nothing.
                    PluginDecompilerCache.write(source, path: file, engine: engine,
                                                configRoot: self.configRootPath,
                                                profile: self.profile.id)
                    self.display(source, engine: engine)
                case .failure(let error):
                    log.warning("\(engine.id, privacy: .public): \(error.userMessage, privacy: .public)")
                    self.show(error: error, note: engine.note)
                }
            }
        }
    }

    /// Show decompiled source, highlighted for the host's theme.
    ///
    /// Highlighting is skipped above `PluginSyntax.maximumLength` and the status line says so, so a
    /// very large result appears immediately as plain text instead of stalling the view.
    private func display(_ source: String, engine: PluginDecompilerEngine) {
        currentSource = source
        // System-colour fallbacks, not the host's palette. A lister plugin is handed the parent
        // view and a path — `ListLoad` has no PcHostServices — so it cannot read the theme bridge
        // at all. The fallbacks are dynamic system colours, so they still follow light and dark;
        // what they cannot follow is a *named* palette. Fixing that means widening the lister ABI,
        // which is a bigger decision than this feature.
        let font = text.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let tooBig = source.utf16.count > PluginSyntax.maximumLength
        text.textStorage?.setAttributedString(
            PluginSyntax.highlight(source, language: profile.language, palette: .system, font: font))
        status.stringValue = tooBig
            ? String(format: L("%@ — too large to highlight"), engine.name)
            : engine.name
        saveButton.isEnabled = true
        openButton.isEnabled = true
    }

    /// Write the source somewhere the user chooses.
    @objc private func saveAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFileName
        panel.allowedFileTypes = [profile.sourceExtension, "txt"]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try currentSource.write(to: url, atomically: true, encoding: .utf8) }
        catch { status.stringValue = error.localizedDescription }
    }

    /// Hand the source to whatever opens .java on this Mac.
    ///
    /// A temp file and NSWorkspace, not the host's editor: a lister plugin is given the parent view
    /// and a path, not the host-services table, so it has no way to ask Peach Commander to open
    /// anything. Opening the user's real editor is arguably what they want anyway.
    @objc private func openInEditor() {
        let dir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("pc-decompiled-\(ProcessInfo.processInfo.globallyUniqueString)")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let file = (dir as NSString).appendingPathComponent(suggestedFileName)
        do {
            try currentSource.write(toFile: file, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(URL(fileURLWithPath: file))
        } catch {
            status.stringValue = error.localizedDescription
        }
    }

    /// `Hello.class` becomes `Hello.java`; a javap dump stays `.txt` since it is not source.
    private var suggestedFileName: String {
        let stem = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        return stem + (profile.isBytecodeListing(currentSource) ? ".txt" : "." + profile.sourceExtension)
    }

    private func show(error: PluginDecompileError, note: String? = nil) {
        status.stringValue = error.userMessage
        var body = [error.userMessage, ""]
        if let note, !note.isEmpty { body += [note, ""] }
        if case .noEngine = error {
            body.append(L("Install one of these engines, then reopen this file:"))
            body.append("")
            for engine in candidates.isEmpty
                ? PluginDecompilerEngine.builtIns(engineDirectory: engineDirectory) : candidates {
                body.append("  • \(engine.name)")
                if let n = engine.note { body.append("    \(n)") }
            }
            body.append("")
            body.append(L("“Engine Folder…” opens the folder they belong in."))
        }
        text.string = body.joined(separator: "\n")
    }

    // MARK: Viewer commands

    override func find(_ needle: String, matchCase: Bool) -> Bool {
        let haystack = text.string
        let options: String.CompareOptions = matchCase ? [] : [.caseInsensitive]
        guard let range = haystack.range(of: needle, options: options) else { return false }
        let ns = NSRange(range, in: haystack)
        text.scrollRangeToVisible(ns)
        text.setSelectedRange(ns)
        return true
    }

    override func selectAll() { text.setSelectedRange(NSRange(location: 0, length: (text.string as NSString).length)) }

    /// Font size, as the lister ABI offers via PC_LC_FONTPLUS / PC_LC_FONTMINUS. Decompiled source
    /// is dense, so the viewer's zoom keys have to work here — ignoring commands the ABI defines
    /// makes them look broken rather than unimplemented.
    override func changeFontSize(by delta: CGFloat) {
        let current = text.font?.pointSize ?? 12
        let size = min(32, max(8, current + delta))
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        // Both panes: zooming one half of a comparison would defeat the comparison.
        for view in [text, secondText] {
            view.font = font
            // The attributed string carries its own font, so re-apply it over the whole range or
            // only newly typed text would change size — and this view is not editable.
            view.textStorage?.addAttribute(.font, value: font,
                                           range: NSRange(location: 0, length: view.textStorage?.length ?? 0))
        }
    }

    override func copySelection() {
        let sel = text.selectedRange()
        let content = sel.length > 0 ? (text.string as NSString).substring(with: sel) : text.string
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
}


/// The host's configuration directory, where engines and `decompilers.ini` live.
///
/// Internal, not private: the contribution facet in panel_command.swift needs the same answer, and
/// two copies of "where does this app keep its configuration" is how they end up disagreeing.
///
/// Resolved the same way `ConfigPaths` does, including the -ConfigRoot override, so a scripted or
/// sandboxed run finds the same folder the rest of the app uses.
func configRoot() -> String {
    let args = ProcessInfo.processInfo.arguments
    if let i = args.firstIndex(of: "-ConfigRoot"), i + 1 < args.count { return args[i + 1] }
    if let env = ProcessInfo.processInfo.environment["PEACHCMD_CONFIG_ROOT"], !env.isEmpty { return env }
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
    return appSupport.appendingPathComponent("PeachCommander").path
}

// MARK: - Building the right view

/// The view `ListLoad` should return for `file`, or nil to let the host use its own viewer.
///
/// Declining is a real answer, not a failure: `.dll` and `.exe` name native binaries as well as
/// managed assemblies, and the detect string cannot tell them apart. `embedPlugin` falls back to the
/// built-in representation when this returns nil, so a native binary still opens as hex.
func makeDecompilerListerView(_ file: UnsafeMutablePointer<CChar>?,
                              profile: PluginDecompilerProfile) -> UnsafeMutableRawPointer? {
    guard let file, let path = String(validatingUTF8: file),
          FileManager.default.isReadableFile(atPath: path) else { return nil }
    guard profile.claims(path) else {
        log.info("\(profile.id, privacy: .public): declined \((path as NSString).lastPathComponent, privacy: .public)")
        return nil
    }
    let root = configRoot()
    // One file in, many sources out — an archive, a dex, a .NET assembly — gets the tree view; a
    // single class gets the single-source view. The decision is the file's kind and not the engine's,
    // because it has to be made before any engine has run.
    let kind = (path as NSString).pathExtension.lowercased()
    // The *engine* decides the shape, not only the kind. Java never showed this: a .class has one
    // engine shape and a JAR another. .NET does — ILSpy writes a project tree from an assembly while
    // monodis prints one IL listing of the same file, and someone who installed only Mono would
    // otherwise get a tree view reporting no engine for a file monodis handles perfectly well.
    let wantsTree = profile.isTree(kind: kind)
        && PluginDecompilerRegistry(configRoot: root, profile: profile.id)
            .archiveEngines(for: kind).contains { $0.isAvailable }
    let view: DecompilerListerView = wantsTree
        ? DecompiledArchiveView(path: path, configRoot: root, profile: profile)
        : DecompiledView(path: path, configRoot: root, profile: profile)
    return Unmanaged.passRetained(view).toOpaque()
}
