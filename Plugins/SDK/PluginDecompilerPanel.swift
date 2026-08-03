// SPDX-License-Identifier: Apache-2.0
// PluginDecompilerPanel.swift — put decompiled sources into a file panel (F-350).
//
// The plugin's first answer to "show me this JAR as source" was a window of its own, with a tree and
// a search field in it. That was the wrong instinct: Peach Commander already navigates archives,
// already views files with F3, already searches file contents, and already copies things out. A
// second, private version of all four inside a plugin window is a smaller file manager competing
// with the real one.
//
// So this contributes a *command* instead. It decompiles, writes the sources where they can be
// reached as ordinary files, and hands the directory to a panel. From there everything the host can
// do applies unchanged: Enter to descend, F3 with the host's own Java highlighting, Alt+F7 to search
// across the classes, F5 to copy the sources out, compare them, tag them. Nothing here reimplements
// any of it, which is the point.
//
// A lister (`plx`) gets no host services — `ListLoad` is handed a view and a path and nothing else —
// so this could not have been done from F3 at all. Contributions are loaded for any plugin type
// whose manifest declares them, so one bundle can be both.

import AppKit

/// Dispatch a contributed command. Each plugin's `PcRunCommand` is one call to this with its own
/// profile — the ids come from the profile so the code and the manifest cannot drift apart.
func runDecompilerCommand(_ command: String, _ svc: PcHostServices,
                          profile: PluginDecompilerProfile) {
    switch command {
    case profile.commandToSources: decompileToPanel(svc, profile: profile)
    case profile.commandClearCache: clearCache(svc, profile: profile)
    default: break
    }
}

// MARK: - Decompile into a panel

private func decompileToPanel(_ svc: PcHostServices, profile: PluginDecompilerProfile) {
    let configRoot = context(svc, "configRoot") ?? configRoot()
    // The *local* path, so a class inside an archive works too: the host extracts it to a temp file
    // first, exactly as it does for F3. Asking for the plain cursor path would hand a decompiler a
    // VFS path it cannot open.
    guard let path = hostString({ svc.localCursorPath(svc.host, $0, $1) })
            ?? hostString({ svc.cursorPath(svc.host, $0, $1) }) else {
        present(svc, L("Nothing to decompile"), L("Put the cursor on a .class, .jar, .apk or .dex file."))
        return
    }
    let kind = (path as NSString).pathExtension.lowercased()
    // Check the *input* before blaming the setup. Without this the message for a cursor sitting on a
    // folder read "No decompiler engine is installed for . files", which sends someone off to install
    // an engine over a mistake an engine cannot fix.
    guard profile.handles(kind: kind), profile.claims(path) else {
        present(svc, L("Nothing to decompile"),
                String(format: L("%@ is not a class file or an archive of them."),
                       (path as NSString).lastPathComponent))
        return
    }
    let registry = PluginDecompilerRegistry(configRoot: configRoot, profile: profile.id)
    let isArchive = profile.isTree(kind: kind)
    let candidates = isArchive ? registry.archiveEngines(for: kind) : registry.engines(for: kind)
    guard let engine = candidates.first(where: { $0.isAvailable })
            ?? preferred(candidates, configRoot: configRoot, kind: kind) else {
        present(svc, L("No decompiler engine is installed"),
                PluginDecompileError.noEngine(kind: kind).userMessage + "\n\n"
                    + L("“Engine Folder…” in the viewer opens the folder they belong in."))
        return
    }
    guard engine.isAvailable else {
        present(svc, L("No decompiler engine is installed"),
                (engine.missingPath.map { PluginDecompileError.engineMissing(engine: engine.name, path: $0) }
                    ?? .engineMissing(engine: engine.name, path: engine.tool)).userMessage)
        return
    }

    // Which panel receives the result: the one the cursor is *not* in, so the archive stays visible
    // beside its sources — the same convention F5 and the compare tools follow.
    let side = (Int(context(svc, "activeSide") ?? "0") ?? 0) == 0 ? 1 : 0
    let host = svc.host
    let openInPanel = svc.openPathInPanel
    let progress = DecompileProgressPanel(
        title: String(format: L("Decompiling %@ with %@…"), (path as NSString).lastPathComponent, engine.name),
        parent: svc.parentWindow)
    progress.show()

    DispatchQueue.global(qos: .userInitiated).async {
        let result = isArchive
            ? archiveDirectory(engine: engine, path: path, configRoot: configRoot, profile: profile)
            : singleFileDirectory(engine: engine, path: path, configRoot: configRoot, profile: profile)
        DispatchQueue.main.async {
            progress.close()
            switch result {
            case .success(let directory):
                log.info("to panel: \(directory, privacy: .public)")
                directory.withCString { openInPanel?(host, Int32(side), $0) }
            case .failure(let error):
                var message = error.userMessage
                if let note = engine.note { message += "\n\n" + note }
                present(svc, L("Decompiling failed"), message)
            }
        }
    }
}

/// Decompile a whole archive into the cache and return that directory.
///
/// The cache is the delivery mechanism, not an optimisation: the sources have to live somewhere a
/// panel can navigate, and a directory keyed by (file, engine) is already exactly that. Reopening
/// the same archive therefore costs nothing and shows the same paths.
private func archiveDirectory(engine: PluginDecompilerEngine, path: String, configRoot: String,
                              profile: PluginDecompilerProfile) -> Result<String, PluginDecompileError> {
    guard let dir = PluginDecompilerCache.treeDirectory(path: path, engine: engine, configRoot: configRoot,
                                                       profile: profile.id) else {
        return .failure(.notReadable("This file could not be read."))
    }
    if PluginDecompilerCache.treeIsComplete(dir), !PluginDecompilerRunner.sourceFiles(in: dir).isEmpty {
        return .success(dir)
    }
    switch PluginDecompilerRunner.runArchive(engine, input: path, outputDirectory: dir) {
    case .success:
        PluginDecompilerCache.markTreeComplete(dir, configRoot: configRoot, profile: profile.id)
        return .success(dir)
    case .failure(let error):
        return .failure(error)
    }
}

/// Decompile one class and return a directory holding it as a `.java` file.
///
/// A directory even for a single class, because the host is being asked to *navigate* somewhere, and
/// the file is named after the class so the panel shows `Hello.java` rather than a cache key.
private func singleFileDirectory(engine: PluginDecompilerEngine, path: String, configRoot: String,
                                 profile: PluginDecompilerProfile) -> Result<String, PluginDecompileError> {
    let source: String
    if let cached = PluginDecompilerCache.read(path: path, engine: engine, configRoot: configRoot,
                                               profile: profile.id) {
        source = cached
    } else {
        switch PluginDecompilerRunner.run(engine, input: path) {
        case .success(let text):
            PluginDecompilerCache.write(text, path: path, engine: engine, configRoot: configRoot,
                                        profile: profile.id)
            source = text
        case .failure(let error):
            return .failure(error)
        }
    }
    guard let dir = PluginDecompilerCache.fileDirectory(path: path, engine: engine,
                                                       configRoot: configRoot, profile: profile.id) else {
        return .failure(.notReadable("This file could not be read."))
    }
    let stem = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    // javap prints bytecode, not Java; naming that .java would make the host highlight it as source
    // and the user save it as something it is not.
    let name = stem + (profile.isBytecodeListing(source) ? ".txt" : "." + profile.sourceExtension)
    do {
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try source.write(toFile: (dir as NSString).appendingPathComponent(name),
                         atomically: true, encoding: .utf8)
    } catch {
        return .failure(.notReadable(error.localizedDescription))
    }
    return .success(dir)
}

private func preferred(_ candidates: [PluginDecompilerEngine], configRoot: String,
                       kind: String) -> PluginDecompilerEngine? {
    let id = PluginDecompilerPreference.read(configRoot: configRoot)[kind]
    return candidates.first { $0.id == id } ?? candidates.first
}

// MARK: - Clearing the cache

/// Delete every cached result. Offered as a command as well as in the options window, because a
/// stale result after installing a better engine is the one case where the cache is in the way.
private func clearCache(_ svc: PcHostServices, profile: PluginDecompilerProfile) {
    let configRoot = context(svc, "configRoot") ?? configRoot()
    let dir = PluginDecompilerCache.directory(configRoot: configRoot, profile: profile.id)
    let removed = PluginDecompilerCache.entryCount(configRoot: configRoot, profile: profile.id)
    try? FileManager.default.removeItem(atPath: dir)
    present(svc, L("Decompiler cache cleared"),
            String(format: L("%d cached result(s) removed."), removed))
}

// MARK: - Host helpers

/// Read a host string through the (buffer, length) convention the ABI uses.
private func hostString(_ read: (UnsafeMutablePointer<CChar>, Int32) -> Int32) -> String? {
    var buffer = [CChar](repeating: 0, count: 4096)
    let ok = buffer.withUnsafeMutableBufferPointer { raw -> Int32 in
        read(raw.baseAddress!, Int32(raw.count))
    }
    guard ok != 0 else { return nil }
    let value = String(cString: buffer)
    return value.isEmpty ? nil : value
}

/// Internal, not private: the settings view needs the same host context (F-352).
func context(_ svc: PcHostServices, _ key: String) -> String? {
    guard let getContext = svc.getContext else { return nil }
    var buffer = [CChar](repeating: 0, count: 1024)
    let ok = key.withCString { k in
        buffer.withUnsafeMutableBufferPointer { raw in
            getContext(svc.host, k, raw.baseAddress!, Int32(raw.count))
        }
    }
    guard ok != 0 else { return nil }
    let value = String(cString: buffer)
    return value.isEmpty ? nil : value
}

private func present(_ svc: PcHostServices, _ title: String, _ message: String) {
    guard let presentInfo = svc.presentInfo else { return }
    title.withCString { t in message.withCString { m in presentInfo(svc.host, t, m) } }
}

/// A small modal-free panel while an engine runs.
///
/// Whole archives take minutes, and a command that returns instantly with nothing visible looks like
/// it did nothing. Not a sheet: the host's window belongs to the host, and blocking it would stop
/// the user doing anything else while a JVM works.
private final class DecompileProgressPanel {
    private let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 88),
                                styleMask: [.titled, .utilityWindow], backing: .buffered, defer: false)
    private let parent: NSWindow?

    init(title: String, parent: UnsafeMutableRawPointer?) {
        self.parent = parent.map { Unmanaged<NSWindow>.fromOpaque($0).takeUnretainedValue() }
        panel.title = L("Decompiling")
        let label = NSTextField(labelWithString: title)
        label.lineBreakMode = .byTruncatingMiddle
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        let stack = NSStackView(views: [spinner, label])
        stack.orientation = .horizontal
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        panel.contentView = stack
    }

    func show() {
        if let parent {
            let f = parent.frame
            panel.setFrameOrigin(NSPoint(x: f.midX - 190, y: f.midY))
        } else {
            panel.center()
        }
        panel.orderFront(nil)
    }

    func close() { panel.orderOut(nil) }
}
