// SPDX-License-Identifier: Apache-2.0
// PluginDecompiler.swift - Shared engine runner for decompiler plugins (F-345).
//
// Add this file to a plugin's swiftc sources (see Tools/build-*-plugin.sh). It turns "show me
// this opaque file as readable text" into configuration rather than code, so a plugin for a new
// format supplies a detect string and a `kind`, and inherits everything else.
//
// The design follows one rule the host already applies to text formatters: **the plugin does not
// decompile, it drives engines.** No decompiler is bundled. That is partly a licence question —
// JD-Core, the best-known Java decompiler, is GPLv3 and could not ship inside an Apache-2.0 app —
// and partly a longevity one: engines improve, and swapping a JAR should not require a release.
//
// An engine is data:
//
//     [cfr]
//     kinds  = class, jar
//     tool   = java
//     args   = -jar {engine} {input}
//     engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
//     output = stdout
//
// `kinds` is the only format-specific field, which is what makes this reusable: a future .dex
// plugin adds `kinds = dex` pointing at jadx, a .wasm one at wasm2wat, and no code here changes.

import Foundation

// Every type carries the `Plugin` prefix. This file is compiled *into* plugins, so a bare name
// like `DecompilerEngine` is a collision waiting to happen with whatever the plugin author already
// has — PluginSyntax.swift hit exactly that with `SyntaxLanguage` against PCFoundation's own.

// MARK: - Errors

/// Why no source could be produced. The cases are distinct because the view must say something
/// different for each: "install an engine" is a setup problem, "the engine crashed" is not, and
/// neither is "this is not a class file".
enum PluginDecompileError: Error, Equatable {
    /// No engine is configured or installed for this kind of file.
    case noEngine(kind: String)
    /// An engine is configured but its tool or JAR is missing from disk.
    case engineMissing(engine: String, path: String)
    /// The engine ran and failed; carries its own diagnostics, which are usually the useful part.
    case engineFailed(engine: String, exitCode: Int32, message: String)
    /// The engine produced nothing at all.
    case emptyOutput(engine: String)
    /// The engine ran too long and was stopped.
    case timedOut(engine: String, seconds: Int)
    /// The input is not what this plugin claims to read.
    case notReadable(String)

    /// A short line for the view's status area — specific about the cause, never just "failed".
    var userMessage: String {
        switch self {
        case .noEngine(let kind):
            return "No decompiler engine is installed for .\(kind) files."
        case .engineMissing(let engine, let path):
            return "\(engine) is configured but \(path) does not exist."
        case .engineFailed(let engine, let code, let message):
            let detail = message.split(separator: "\n").first.map(String.init) ?? ""
            return "\(engine) exited \(code)\(detail.isEmpty ? "" : ": \(detail)")"
        case .emptyOutput(let engine):
            return "\(engine) produced no output."
        case .timedOut(let engine, let seconds):
            return "\(engine) did not finish within \(seconds) seconds and was stopped."
        case .notReadable(let why):
            return why
        }
    }
}

// MARK: - Engines

/// How an engine hands its result back.
enum PluginDecompilerOutput: String {
    /// Source is written to stdout — the common case, and the only one that needs no temp files.
    case stdout
    /// The engine insists on writing files; it is given a temp directory and the files are
    /// concatenated. Vineflower works this way unless told otherwise.
    case directory
}

/// How an engine is driven when the input is a whole archive rather than one class.
///
/// Separate arguments rather than reusing `args`, because the two invocations differ in kind and not
/// just in degree: single-class runs mostly print to stdout, whole-archive runs must write a tree of
/// files, and the flag that switches a decompiler between them is engine-specific. Keeping them
/// apart also means adding archive support cannot change what already works for one class.
struct PluginDecompilerArchiveSupport: Equatable {
    /// Argument template. Must place output under `{outdir}`, since that is what is read back.
    let args: [String]
    /// Seconds before the engine is stopped. A whole JAR is minutes of work where one class is
    /// seconds, so this is deliberately not the single-file timeout.
    let timeout: Int

    static let defaultTimeout = 300
}

/// One decompiler engine, as data.
struct PluginDecompilerEngine: Equatable {
    let id: String
    let name: String
    /// Input kinds this engine handles, lowercased and without a dot ("class", "jar", "dex").
    let kinds: [String]
    /// The executable. Resolved through PATH when it is not an absolute path.
    let tool: String
    /// Argument template. `{input}`, `{engine}` and `{outdir}` are substituted.
    let args: [String]
    /// Optional payload the tool runs — a JAR for the JVM engines.
    let enginePath: String?
    let output: PluginDecompilerOutput
    /// Shown when the engine is missing, so the message can name a licence and a download.
    let note: String?
    /// Seconds before the engine is stopped. Decompilers do get stuck — obfuscated bytecode is a
    /// known way to send one into a loop — and without a limit the view would say "Decompiling…"
    /// for ever with no way back.
    let timeout: Int
    /// How to run this engine over a whole archive, or nil if it cannot do one.
    ///
    /// `javap` is the honest nil here: it prints one class and has no notion of a JAR.
    let archive: PluginDecompilerArchiveSupport?

    func handles(kind: String) -> Bool { kinds.contains(kind.lowercased()) }

    /// Whether this engine can turn `kind` into a *tree* of sources rather than a single result.
    func handlesArchive(kind: String) -> Bool { archive != nil && handles(kind: kind) }

    static let defaultTimeout = 30
}

/// Input kinds where one file yields many sources, so the result belongs in a tree.
///
/// `dex` and `apk` are in here with `jar`: a dex holds a whole Android app, and concatenating that
/// into one buffer — which is what the single-file path does — is unreadable at any size.
///
/// Exactly the kinds a built-in engine claims, and a test holds it to that. `.war`, `.ear` and
/// `.aar` were in here first and came straight back out: nothing described could decompile one, so
/// F3 on such a file would have opened a view that could only ever apologise.
let pluginDecompilerArchiveKinds: Set<String> = ["jar", "apk", "dex"]

// MARK: - Built-in engine descriptors

extension PluginDecompilerEngine {
    /// Engines the plugin knows how to drive. Descriptors only — nothing is bundled.
    ///
    /// Ordered by preference: CFR and Vineflower produce Java source and are permissively
    /// licensed (MIT and Apache-2.0), so they can be recommended without a licence caveat.
    /// `javap` comes last but needs no download at all: it is part of any JDK, and bytecode is a
    /// far better answer than an empty window.
    static func builtIns(engineDirectory: String) -> [PluginDecompilerEngine] {
        func jar(_ name: String) -> String { (engineDirectory as NSString).appendingPathComponent(name) }
        return [
            PluginDecompilerEngine(
                id: "cfr", name: "CFR", kinds: ["class", "jar"],
                tool: "java", args: ["-jar", "{engine}", "{input}"],
                enginePath: jar("cfr.jar"), output: .stdout,
                note: "CFR — MIT licence. Download cfr.jar from https://github.com/leibnitz27/cfr/releases",
                timeout: defaultTimeout,
                archive: PluginDecompilerArchiveSupport(
                    args: ["-jar", "{engine}", "{input}", "--outputdir", "{outdir}"],
                    timeout: PluginDecompilerArchiveSupport.defaultTimeout)),
            PluginDecompilerEngine(
                id: "vineflower", name: "Vineflower", kinds: ["class", "jar"],
                tool: "java", args: ["-jar", "{engine}", "{input}", "{outdir}"],
                enginePath: jar("vineflower.jar"), output: .directory,
                note: "Vineflower — Apache-2.0 licence. Download vineflower.jar from "
                    + "https://github.com/Vineflower/vineflower/releases", timeout: defaultTimeout,
                // Same invocation as the single-file case — it already writes into a directory.
                // Given a JAR, a FernFlower-derived engine may write a *JAR of sources* rather than
                // a tree; the reader expands one if it finds it, so either shape works.
                archive: PluginDecompilerArchiveSupport(
                    args: ["-jar", "{engine}", "{input}", "{outdir}"],
                    timeout: PluginDecompilerArchiveSupport.defaultTimeout)),
            PluginDecompilerEngine(
                id: "procyon", name: "Procyon", kinds: ["class", "jar"],
                tool: "java", args: ["-jar", "{engine}", "{input}"],
                enginePath: jar("procyon.jar"), output: .stdout,
                note: "Procyon — Apache-2.0 licence. Download procyon-decompiler.jar from "
                    + "https://github.com/mstrobel/procyon/releases", timeout: defaultTimeout,
                archive: PluginDecompilerArchiveSupport(
                    args: ["-jar", "{engine}", "-jar", "{input}", "-o", "{outdir}"],
                    timeout: PluginDecompilerArchiveSupport.defaultTimeout)),
            // Android. The proof that this design carries a new format: one descriptor and one
            // clause in the plugin's detect string, no change to the runner — `output: .directory`
            // and `{outdir}` already existed for Vineflower.
            PluginDecompilerEngine(
                id: "jadx", name: "jadx (Android)", kinds: ["dex", "apk", "jar"],
                tool: "jadx", args: ["--no-res", "-d", "{outdir}", "{input}"],
                enginePath: nil, output: .directory,
                note: "jadx — Apache-2.0 licence. Install with `brew install jadx`, or download "
                    + "from https://github.com/skylot/jadx/releases",
                timeout: 120,   // a dex holds a whole app; 30 s is not enough
                archive: PluginDecompilerArchiveSupport(
                    args: ["--no-res", "-d", "{outdir}", "{input}"],
                    timeout: PluginDecompilerArchiveSupport.defaultTimeout)),
            PluginDecompilerEngine(
                id: "javap", name: "javap (bytecode)", kinds: ["class"],
                tool: "javap", args: ["-c", "-p", "-constants", "{input}"],
                enginePath: nil, output: .stdout,
                note: "javap ships with any JDK — no download needed, but it shows bytecode "
                    + "rather than Java source.", timeout: defaultTimeout,
                // Nothing to put here: javap prints one class and has no notion of an archive.
                archive: nil),
        ]
    }
}

// MARK: - Registry

/// Resolves which engine to use, from built-in descriptors plus the user's own.
struct PluginDecompilerRegistry {
    private(set) var engines: [PluginDecompilerEngine]
    /// Warnings from parsing the user's file, surfaced rather than swallowed.
    private(set) var warnings: [String] = []

    /// Where user engines and JARs live.
    static func engineDirectory(configRoot: String) -> String {
        (configRoot as NSString).appendingPathComponent("decompilers")
    }

    /// Built-ins plus `decompilers.ini` from the engine directory.
    ///
    /// The user's engines come **first**, because a configured tool is an explicit instruction —
    /// the same rule the host applies to text formatters. Otherwise someone who went to the
    /// trouble of describing their own decompiler would still get a built-in, which is the
    /// opposite of what configuring one means. An entry that reuses a built-in id replaces it in
    /// place, so pointing CFR at another path or adding flags needs no new id.
    init(configRoot: String) {
        let dir = Self.engineDirectory(configRoot: configRoot)
        var builtIns = PluginDecompilerEngine.builtIns(engineDirectory: dir)
        var user: [PluginDecompilerEngine] = []
        let iniPath = (dir as NSString).appendingPathComponent("decompilers.ini")
        if let text = try? String(contentsOfFile: iniPath, encoding: .utf8) {
            let parsed = Self.parse(text, engineDirectory: dir)
            warnings = parsed.warnings
            for engine in parsed.engines {
                if let i = builtIns.firstIndex(where: { $0.id == engine.id }) { builtIns[i] = engine }
                else { user.append(engine) }
            }
        }
        // The user's timeouts applied here and nowhere else: every consumer goes through this
        // registry, so a setting cannot be honoured on one path and ignored on another.
        let options = PluginDecompilerOptions.read(configRoot: configRoot)
        engines = (user + builtIns).map { $0.withTimeouts(options) }
    }

    /// Engines that can handle `kind`, in preference order.
    func engines(for kind: String) -> [PluginDecompilerEngine] {
        engines.filter { $0.handles(kind: kind) }
    }

    /// Engines that can decompile a whole archive of `kind`, in preference order.
    ///
    /// A separate list rather than filtering at the call site, because "handles .jar" and "can
    /// decompile a .jar in one run" are different claims: javap handles a class and can never do
    /// the second, and offering it in an archive view would produce an engine that always fails.
    func archiveEngines(for kind: String) -> [PluginDecompilerEngine] {
        engines.filter { $0.handlesArchive(kind: kind) }
    }

    /// The first engine for `kind` that is actually present on disk.
    func firstAvailable(for kind: String) -> PluginDecompilerEngine? {
        engines(for: kind).first { $0.isAvailable }
    }

    // MARK: Parsing

    /// Parse `decompilers.ini`. Deliberately forgiving in the same way theme files are: a bad
    /// section costs that engine and a warning, never the whole file.
    static func parse(_ text: String, engineDirectory: String)
        -> (engines: [PluginDecompilerEngine], warnings: [String]) {
        var engines: [PluginDecompilerEngine] = []
        var warnings: [String] = []
        var section: String?
        var fields: [String: String] = [:]

        func flush() {
            guard let id = section else { return }
            defer { fields = [:] }
            // `extends = cfr` inherits a built-in's tool, jar, kinds and output, so a profile that
            // only changes the flags is three lines instead of six. CFR alone has dozens of
            // switches, and a power user wants several presets of the same engine, not one.
            if let base = fields["extends"].flatMap({ baseId in
                PluginDecompilerEngine.builtIns(engineDirectory: engineDirectory)
                    .first { $0.id == baseId.trimmingCharacters(in: .whitespaces) }
            }) {
                for (key, value) in [("tool", base.tool), ("kinds", base.kinds.joined(separator: ",")),
                                     ("output", base.output.rawValue),
                                     ("engine", base.enginePath ?? ""), ("args", base.args.joined(separator: " ")),
                                     ("timeout", String(base.timeout)),
                                     // Inherited too, so a CFR profile that only adds a flag to the
                                     // single-class line keeps working on whole JARs.
                                     ("archive_args", base.archive?.args.joined(separator: " ") ?? ""),
                                     ("archive_timeout", base.archive.map { String($0.timeout) } ?? "")]
                where fields[key] == nil && !value.isEmpty {
                    fields[key] = value
                }
            } else if let missing = fields["extends"] {
                warnings.append("[\(id)]: unknown `extends = \(missing)`, ignored")
            }
            guard let tool = fields["tool"], !tool.isEmpty else {
                warnings.append("[\(id)]: no `tool`, ignored"); return
            }
            let kinds = (fields["kinds"] ?? "")
                .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
            guard !kinds.isEmpty else {
                warnings.append("[\(id)]: no `kinds`, ignored"); return
            }
            let output = PluginDecompilerOutput(rawValue: (fields["output"] ?? "stdout").lowercased()) ?? .stdout
            engines.append(PluginDecompilerEngine(
                id: id, name: fields["name"] ?? id, kinds: kinds,
                // `~` is expanded for the tool too, not just the payload: `tool = ~/bin/mytool`
                // used to be passed through literally and could never be found.
                tool: expandTilde(tool),
                args: splitArguments(fields["args"] ?? ""),
                // A bare file name resolves against the engine folder, which is where the user was
                // told to put jars. Before, `engine = cfr.jar` resolved against the process's
                // working directory — never what was meant.
                enginePath: fields["engine"].map { resolve($0, relativeTo: engineDirectory) },
                output: output, note: fields["note"],
                timeout: fields["timeout"].flatMap(Int.init) ?? PluginDecompilerEngine.defaultTimeout,
                // Absent `archive_args` means "this engine does one class at a time" rather than
                // "use the single-file arguments on a JAR" — guessing the latter would run a tool
                // with flags its author never intended and blame the result on the user's file.
                archive: fields["archive_args"].map { line in
                    PluginDecompilerArchiveSupport(
                        args: splitArguments(line),
                        timeout: fields["archive_timeout"].flatMap(Int.init)
                            ?? PluginDecompilerArchiveSupport.defaultTimeout)
                }))
        }

        for raw in text.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") { continue }
            if let semi = line.firstIndex(of: ";") {
                line = String(line[line.startIndex..<semi]).trimmingCharacters(in: .whitespaces)
                if line.isEmpty { continue }
            }
            if line.hasPrefix("["), line.hasSuffix("]") {
                flush()
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                continue
            }
            guard let eq = line.firstIndex(of: "="), section != nil else {
                warnings.append("ignored: \(line)"); continue
            }
            let key = String(line[line.startIndex..<eq]).trimmingCharacters(in: .whitespaces).lowercased()
            fields[key] = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        }
        flush()
        return (engines, warnings)
    }

    /// Split an argument line on spaces, honouring double quotes so a path with a space survives.
    static func splitArguments(_ line: String) -> [String] {
        var out: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle(); continue }
            if ch == " ", !inQuotes {
                if !current.isEmpty { out.append(current); current = "" }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    static func expandTilde(_ path: String) -> String { (path as NSString).expandingTildeInPath }

    /// Expand `~`, and resolve a relative path against the engine folder rather than the process's
    /// working directory — which for a GUI app is somewhere the user has never heard of.
    static func resolve(_ path: String, relativeTo directory: String) -> String {
        let expanded = expandTilde(path)
        guard !(expanded as NSString).isAbsolutePath else { return expanded }
        return (directory as NSString).appendingPathComponent(expanded)
    }
}

// MARK: - Availability

extension PluginDecompilerEngine {
    /// Whether this engine can run right now: its tool resolves and its payload exists.
    var isAvailable: Bool { resolvedTool != nil && missingPath == nil }

    /// The path that is missing, if any — so the message can name it instead of saying "not found".
    var missingPath: String? {
        guard let enginePath else { return nil }
        return FileManager.default.fileExists(atPath: enginePath) ? nil : enginePath
    }

    /// Absolute path of the tool, looked up in PATH when it is a bare name.
    ///
    /// PATH is searched by hand rather than via `/usr/bin/env`, because a GUI app inherits a much
    /// shorter PATH than a shell and the usual Homebrew locations have to be considered too.
    var resolvedTool: String? {
        if tool.contains("/") {
            return FileManager.default.isExecutableFile(atPath: tool) ? tool : nil
        }
        var dirs = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        dirs += ["/usr/bin", "/bin", "/usr/local/bin", "/opt/homebrew/bin",
                 "/usr/libexec", "/Library/Java/JavaVirtualMachines"]
        for dir in dirs {
            let candidate = (dir as NSString).appendingPathComponent(tool)
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }
}

// MARK: - Result cache

/// Decompiled output cached on disk, keyed by what can invalidate it.
///
/// Decompiling costs seconds; reopening the same class should not. The key is (path, size,
/// modification time, engine id, engine arguments) — size and mtime because the file may have been
/// rebuilt, and the arguments because a profile with different flags is a different result even
/// though the engine id is the same.
///
/// Failures are never cached. A missing engine or a crash is a condition of the *system*, not of
/// the file, and caching it would mean installing the engine did not help until something evicted
/// the entry.
enum PluginDecompilerCache {
    /// Old entries are dropped past this age so the folder cannot grow without bound. The default;
    /// the settings page can change it (F-352).
    static let maximumAge: TimeInterval = 30 * 24 * 3600

    static func maximumAge(configRoot: String) -> TimeInterval {
        TimeInterval(PluginDecompilerOptions.read(configRoot: configRoot).cacheMaxAgeDays) * 24 * 3600
    }

    static func directory(configRoot: String) -> String {
        (PluginDecompilerRegistry.engineDirectory(configRoot: configRoot) as NSString)
            .appendingPathComponent("cache")
    }

    /// A stable, filesystem-safe key. Hashing rather than sanitising the path: paths contain
    /// characters a file name cannot, and are longer than a file name may be.
    ///
    /// `variant` separates results the same engine produces under different invocations — a whole
    /// archive and a single class share an engine id but are not each other's cache entry.
    static func key(path: String, engine: PluginDecompilerEngine, variant: String = "") -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int,
              let modified = attrs[.modificationDate] as? Date else { return nil }
        let material = [path, String(size), String(Int(modified.timeIntervalSince1970)),
                        engine.id, engine.args.joined(separator: " "), variant]
            .joined(separator: "\u{1}")
        // FNV-1a: enough to distinguish inputs, and no dependency on CryptoKit for a cache name.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in Array(material.utf8) {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return String(hash, radix: 36)
    }

    static func read(path: String, engine: PluginDecompilerEngine, configRoot: String) -> String? {
        guard let key = key(path: path, engine: engine) else { return nil }
        let file = (directory(configRoot: configRoot) as NSString).appendingPathComponent(key)
        return try? String(contentsOfFile: file, encoding: .utf8)
    }

    static func write(_ source: String, path: String, engine: PluginDecompilerEngine, configRoot: String) {
        guard let key = key(path: path, engine: engine) else { return }
        let dir = directory(configRoot: configRoot)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? source.write(toFile: (dir as NSString).appendingPathComponent(key),
                          atomically: true, encoding: .utf8)
        prune(dir, maximumAge: maximumAge(configRoot: configRoot))
    }

    // MARK: Whole-archive results

    /// Marker written once a run finished, so a directory left behind by a crash or a timeout is not
    /// mistaken for a complete result. Without it a half-decompiled JAR would be served from cache
    /// for ever, and the only symptom would be classes quietly missing from the tree.
    static let completionMarker = ".pc-complete"

    /// Where a whole-archive result for this (file, engine) pair belongs.
    ///
    /// A directory rather than one concatenated file: the tree view reads single classes on demand,
    /// so a 40 MB result costs one file read per click instead of 40 MB of memory per open.
    static func treeDirectory(path: String, engine: PluginDecompilerEngine, configRoot: String) -> String? {
        guard let key = key(path: path, engine: engine,
                            variant: engine.archive?.args.joined(separator: " ") ?? "archive") else { return nil }
        // The archive's name in the directory name, because this directory is opened *in a file panel*
        // (F-350) and its last component becomes the tab's title. A pure hash made that tab read
        // "tree-28au0ddiogk2x", which tells the person looking at it nothing at all. The hash stays —
        // it is what keeps two archives of the same name apart.
        return (directory(configRoot: configRoot) as NSString)
            .appendingPathComponent(safeName((path as NSString).lastPathComponent) + "-" + key)
    }

    /// A file name reduced to something safe and short enough to be one path component.
    static func safeName(_ name: String) -> String {
        let cleaned = name.map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" ? $0 : "_" }
        return String(cleaned.prefix(60))
    }

    /// Whether `dir` holds a result that finished.
    /// Where a single class's `.java` file belongs, named so a panel tab reads the class's name.
    static func fileDirectory(path: String, engine: PluginDecompilerEngine, configRoot: String) -> String? {
        guard let key = key(path: path, engine: engine, variant: "single-dir") else { return nil }
        let stem = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        return (directory(configRoot: configRoot) as NSString)
            .appendingPathComponent(safeName(stem) + "-" + key)
    }

    static func treeIsComplete(_ dir: String) -> Bool {
        FileManager.default.fileExists(
            atPath: (dir as NSString).appendingPathComponent(completionMarker))
    }

    static func markTreeComplete(_ dir: String, configRoot: String) {
        _ = FileManager.default.createFile(
            atPath: (dir as NSString).appendingPathComponent(completionMarker), contents: nil)
        // Prune the folder this result sits in, which is the cache root — derived from `dir` rather
        // than rebuilt from configRoot, so the two can never disagree about where the cache is.
        prune((dir as NSString).deletingLastPathComponent,
              maximumAge: maximumAge(configRoot: configRoot))
    }

    /// How many results are cached, and how much disk they take.
    ///
    /// Shown in the options window and used by the "clear cache" command, so both can say what they
    /// are about to remove rather than asking for blind confirmation.
    static func entryCount(configRoot: String) -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: directory(configRoot: configRoot)))?
            .filter { !$0.hasPrefix(".") }.count ?? 0
    }

    static func sizeInBytes(configRoot: String) -> Int64 {
        let dir = directory(configRoot: configRoot)
        guard let e = FileManager.default.enumerator(atPath: dir) else { return 0 }
        var total: Int64 = 0
        for case let rel as String in e {
            let full = (dir as NSString).appendingPathComponent(rel)
            if let size = (try? FileManager.default.attributesOfItem(atPath: full))?[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    /// Drop entries older than `maximumAge`. Cheap enough to run on every write: the folder holds
    /// one small file per (file, engine) pair a user has actually looked at.
    private static func prune(_ dir: String, maximumAge: TimeInterval = maximumAge) {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: dir) else { return }
        let cutoff = Date().addingTimeInterval(-maximumAge)
        for name in names {
            let file = (dir as NSString).appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: file),
                  let modified = attrs[.modificationDate] as? Date, modified < cutoff else { continue }
            try? fm.removeItem(atPath: file)
        }
    }
}

// MARK: - Preferred engine

/// Which engine the user last chose, per input kind.
///
/// A separate small file rather than a section in `decompilers.ini`: that file is hand-written and
/// rewriting it to record a menu choice would reformat someone's own comments.
enum PluginDecompilerPreference {
    private static func file(configRoot: String) -> String {
        (PluginDecompilerRegistry.engineDirectory(configRoot: configRoot) as NSString)
            .appendingPathComponent("preferred.ini")
    }

    static func read(configRoot: String) -> [String: String] {
        guard let text = try? String(contentsOfFile: file(configRoot: configRoot), encoding: .utf8) else {
            return [:]
        }
        var out: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix(";"), !trimmed.hasPrefix("["),
                  let eq = trimmed.firstIndex(of: "=") else { continue }
            out[String(trimmed[trimmed.startIndex..<eq]).trimmingCharacters(in: .whitespaces).lowercased()] =
                String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        }
        return out
    }

    /// Forget the preference for `kind`, so the first *available* engine wins again.
    ///
    /// Distinct from setting the first engine's id: "no preference" keeps following what is installed,
    /// while an id freezes today's answer even after a better engine appears.
    static func clear(forKind kind: String, configRoot: String) {
        set(engine: nil, forKind: kind, configRoot: configRoot)
    }

    static func set(engine id: String?, forKind kind: String, configRoot: String) {
        var values = read(configRoot: configRoot)
        if let id { values[kind.lowercased()] = id } else { values.removeValue(forKey: kind.lowercased()) }
        let body = ["; Engine chosen last for each file kind — written by the decompiler plugin.",
                    "[Preferred]"]
            + values.keys.sorted().map { "\($0) = \(values[$0]!)" }
        let path = file(configRoot: configRoot)
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                 withIntermediateDirectories: true)
        try? body.joined(separator: "\n").appending("\n").write(toFile: path, atomically: true, encoding: .utf8)
    }
}

// MARK: - Running

enum PluginDecompilerRunner {
    /// Run `engine` over `input` and return the source it produced.
    ///
    /// Synchronous on purpose: the caller is a lister view that is already off the main thread for
    /// its load, and threading here would only move the problem. Decompiling a large class takes
    /// seconds, so callers cache the result.
    static func run(_ engine: PluginDecompilerEngine, input: String) -> Result<String, PluginDecompileError> {
        guard let toolPath = engine.resolvedTool else {
            return .failure(.engineMissing(engine: engine.name, path: engine.tool))
        }
        if let missing = engine.missingPath {
            return .failure(.engineMissing(engine: engine.name, path: missing))
        }

        var outDir: String?
        if engine.output == .directory {
            let dir = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("pc-decompile-\(ProcessInfo.processInfo.globallyUniqueString)")
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            outDir = dir
        }
        defer { if let outDir { try? FileManager.default.removeItem(atPath: outDir) } }

        switch execute(engine, args: engine.args, timeout: engine.timeout,
                       input: input, outDir: outDir, toolPath: toolPath) {
        case .failure(let error):
            return .failure(error)
        case .success(let stdout):
            let text = outDir.map { collect(from: $0) } ?? stdout
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failure(.emptyOutput(engine: engine.name))
            }
            return .success(text)
        }
    }

    /// Run `engine` over a whole archive, writing its tree into `outputDirectory`.
    ///
    /// The directory belongs to the caller — the cache, in practice — so the result survives the
    /// call and single classes can be read from it later. Returns the relative paths of the source
    /// files produced, sorted, or a failure describing what the engine did.
    static func runArchive(_ engine: PluginDecompilerEngine, input: String,
                           outputDirectory: String) -> Result<[String], PluginDecompileError> {
        guard let archive = engine.archive else {
            return .failure(.notReadable("\(engine.name) cannot decompile a whole archive."))
        }
        guard let toolPath = engine.resolvedTool else {
            return .failure(.engineMissing(engine: engine.name, path: engine.tool))
        }
        if let missing = engine.missingPath {
            return .failure(.engineMissing(engine: engine.name, path: missing))
        }
        let fm = FileManager.default
        // A leftover from a previous, unfinished attempt would otherwise be mixed with this one's
        // output and the tree would show classes from two runs.
        try? fm.removeItem(atPath: outputDirectory)
        do { try fm.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true) }
        catch { return .failure(.notReadable(error.localizedDescription)) }

        if case .failure(let error) = execute(engine, args: archive.args, timeout: archive.timeout,
                                              input: input, outDir: outputDirectory, toolPath: toolPath) {
            return .failure(error)
        }
        expandNestedArchives(in: outputDirectory)
        let files = sourceFiles(in: outputDirectory)
        guard !files.isEmpty else { return .failure(.emptyOutput(engine: engine.name)) }
        return .success(files)
    }

    /// Extensions worth showing in a tree of decompiled sources.
    ///
    /// A whitelist and not a blacklist: engines drop all sorts of things next to the source —
    /// manifests, resources, their own logs — and listing what belongs is a shorter, more stable
    /// rule than guessing what does not.
    static let sourceExtensions: Set<String> = ["java", "kt", "smali", "txt", "scala", "groovy"]

    /// Relative paths of the source files under `directory`, sorted so the tree is stable.
    static func sourceFiles(in directory: String) -> [String] {
        let fm = FileManager.default
        guard let e = fm.enumerator(atPath: directory) else { return [] }
        return (e.allObjects as? [String] ?? [])
            .filter { sourceExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .sorted()
    }

    /// Expand a JAR or ZIP of sources the engine may have written instead of a tree.
    ///
    /// FernFlower-derived engines given a JAR answer with a JAR — of `.java` files, which is the
    /// right content in the wrong container. Unpacking it here keeps that quirk out of both the
    /// engine descriptors and the view: whatever an engine's habit is, the cache holds a tree.
    private static func expandNestedArchives(in directory: String) {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory) else { return }
        for name in names where ["jar", "zip"].contains((name as NSString).pathExtension.lowercased()) {
            let full = (directory as NSString).appendingPathComponent(name)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-qq", "-o", full, "-d", directory]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return }
            process.waitUntilExit()
            if process.terminationStatus == 0 { try? fm.removeItem(atPath: full) }
        }
    }

    /// Start the tool, feed it nothing, read both pipes, and stop it if it overruns.
    ///
    /// Shared by the single-file and whole-archive paths so there is exactly one place that spawns a
    /// process: the watchdog, the closed stdin and the concurrent pipe reads are each a bug that was
    /// fixed once, and a second copy would be a second place to forget them.
    private static func execute(_ engine: PluginDecompilerEngine, args template: [String], timeout: Int,
                                input: String, outDir: String?,
                                toolPath: String) -> Result<String, PluginDecompileError> {
        let args = template.map { arg -> String in
            arg.replacingOccurrences(of: "{input}", with: input)
                .replacingOccurrences(of: "{engine}", with: engine.enginePath ?? "")
                .replacingOccurrences(of: "{outdir}", with: outDir ?? "")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        process.arguments = args
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        // Explicitly nothing on stdin. A tool invoked with the wrong flags may wait for input, and
        // whether it then blocks depended on how the app happened to be launched — inherited stdin
        // from a terminal keeps it waiting, from Finder it does not. That is not a property a
        // viewer should have.
        process.standardInput = FileHandle.nullDevice
        // Read both pipes while the process runs. A decompiler can emit more than a pipe buffer
        // holds, and waiting first would deadlock on exactly the large classes this is for.
        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        for (pipe, sink) in [(out, { outData.append($0) }), (err, { errData.append($0) })] {
            group.enter()
            DispatchQueue.global().async {
                sink(pipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }
        }
        do { try process.run() } catch {
            return .failure(.engineMissing(engine: engine.name, path: toolPath))
        }

        // Stop an engine that will not finish. Decompilers do get stuck, and the alternative is a
        // view that says "Decompiling…" for ever while a JVM burns a core in the background.
        let deadline = DispatchTime.now() + .seconds(timeout)
        var timedOut = false
        let watchdog = DispatchWorkItem {
            guard process.isRunning else { return }
            timedOut = true
            process.terminate()
            // SIGTERM is enough for a JVM; the kill is the backstop for a tool that ignores it.
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
        DispatchQueue.global().asyncAfter(deadline: deadline, execute: watchdog)
        process.waitUntilExit()
        watchdog.cancel()
        group.wait()
        if timedOut {
            return .failure(.timedOut(engine: engine.name, seconds: timeout))
        }

        guard process.terminationStatus == 0 else {
            return .failure(.engineFailed(engine: engine.name,
                                          exitCode: process.terminationStatus,
                                          message: String(data: errData, encoding: .utf8) ?? ""))
        }
        // Only stdout. What a directory-writing engine produced is the caller's business, because the
        // two callers want it in different shapes: one concatenated string, or a tree left on disk.
        return .success(String(data: outData, encoding: .utf8) ?? "")
    }

    /// Read one file out of a whole-archive result.
    ///
    /// Files stay on disk and are read when clicked rather than held in memory: a decompiled JAR runs
    /// to tens of megabytes, and the view only ever shows one class at a time.
    static func readSource(_ relativePath: String, from directory: String) -> String? {
        try? String(contentsOfFile: (directory as NSString).appendingPathComponent(relativePath),
                    encoding: .utf8)
    }

    /// Concatenate what a directory-writing engine produced, in a stable order.
    private static func collect(from directory: String) -> String {
        let fm = FileManager.default
        guard let e = fm.enumerator(atPath: directory) else { return "" }
        let files = (e.allObjects as? [String] ?? []).sorted()
        var parts: [String] = []
        for rel in files {
            let full = (directory as NSString).appendingPathComponent(rel)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue else { continue }
            guard let body = try? String(contentsOfFile: full, encoding: .utf8) else { continue }
            parts.append(files.count > 1 ? "// ---- \(rel)\n\(body)" : body)
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Tree of a whole-archive result

/// One node of the package tree built from a decompiled archive.
///
/// A class rather than a struct because an NSOutlineView identifies rows by object, and value
/// semantics would hand it a fresh copy on every query.
final class PluginDecompilerNode {
    let name: String
    /// Relative path inside the result directory, for a leaf; nil for a package.
    let relativePath: String?
    private(set) var children: [PluginDecompilerNode] = []

    init(name: String, relativePath: String? = nil) {
        self.name = name
        self.relativePath = relativePath
    }

    var isLeaf: Bool { relativePath != nil }

    /// The shallowest leaf, or nil if there is none.
    ///
    /// Breadth-first, not depth-first: packages sort before classes, so descending first finds a
    /// class several packages down and showing it means expanding all of them — opening a JAR would
    /// unfold a branch nobody asked for. The shallowest class is usually already on screen.
    static func shallowestLeaf(in nodes: [PluginDecompilerNode]) -> PluginDecompilerNode? {
        var level = nodes
        while !level.isEmpty {
            if let leaf = level.first(where: \.isLeaf) { return leaf }
            level = level.flatMap(\.children)
        }
        return nil
    }

    /// Build the tree from the relative paths an engine produced.
    ///
    /// Single-child packages are collapsed into one row — `com/example/app` instead of three levels
    /// with nothing to choose in them, which is what makes a Java tree navigable at all. Sorted with
    /// packages before classes so the shape does not change as the caller's order does.
    static func tree(from paths: [String]) -> [PluginDecompilerNode] {
        let root = PluginDecompilerNode(name: "")
        for path in paths {
            let parts = path.split(separator: "/").map(String.init)
            guard let leaf = parts.last else { continue }
            var node = root
            for part in parts.dropLast() {
                if let existing = node.children.first(where: { $0.name == part && !$0.isLeaf }) {
                    node = existing
                } else {
                    let child = PluginDecompilerNode(name: part)
                    node.children.append(child)
                    node = child
                }
            }
            node.children.append(PluginDecompilerNode(name: leaf, relativePath: path))
        }
        root.collapseSingleChildPackages()
        root.sortRecursively()
        return root.children
    }

    /// Merge a package that contains nothing but one package into its parent.
    private func collapseSingleChildPackages() {
        for child in children { child.collapseSingleChildPackages() }
        children = children.map { child in
            var current = child
            while !current.isLeaf, current.children.count == 1, let only = current.children.first,
                  !only.isLeaf {
                let merged = PluginDecompilerNode(name: current.name + "/" + only.name)
                merged.children = only.children
                current = merged
            }
            return current
        }
    }

    private func sortRecursively() {
        children.sort {
            $0.isLeaf == $1.isLeaf ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                                   : !$0.isLeaf
        }
        for child in children { child.sortRecursively() }
    }
}

/// Searching every class in a decompiled archive at once.
///
/// The point of decompiling a whole JAR rather than one class: finding where a string, a call or a
/// constant actually occurs, without knowing which class to open first.
enum PluginDecompilerSearch {
    /// One file that matched, and where.
    struct Hit: Equatable {
        let relativePath: String
        /// 1-based line of the first match, for a status line the user can act on.
        let line: Int
        /// The matching line, trimmed, so the result list shows the code and not just a file name.
        let excerpt: String
    }

    /// Total bytes read before the scan gives up.
    ///
    /// A cap, not a limit on usefulness: an obfuscated Android app decompiles to hundreds of
    /// megabytes, and reading all of it to answer one query would freeze the view for minutes. The
    /// caller is told the scan was capped, so a partial answer is never presented as a complete one.
    static let byteBudget = 64 * 1024 * 1024

    /// Files under `directory` containing `needle`, in the order given.
    ///
    /// `isCancelled` is consulted per file so a typed query can abandon a scan the next keystroke
    /// made irrelevant.
    static func scan(files: [String], in directory: String, for needle: String, matchCase: Bool,
                     isCancelled: () -> Bool = { false }) -> (hits: [Hit], capped: Bool) {
        guard !needle.isEmpty else { return ([], false) }
        let options: String.CompareOptions = matchCase ? [] : [.caseInsensitive]
        var hits: [Hit] = []
        var budget = byteBudget
        for file in files {
            if isCancelled() { return (hits, false) }
            guard budget > 0 else { return (hits, true) }
            guard let body = PluginDecompilerRunner.readSource(file, from: directory) else { continue }
            budget -= body.utf8.count
            guard body.range(of: needle, options: options) != nil else { continue }
            // Only now split into lines: doing it for every file would cost far more than the
            // whole-string check that rules most of them out.
            for (i, line) in body.components(separatedBy: .newlines).enumerated()
            where line.range(of: needle, options: options) != nil {
                hits.append(Hit(relativePath: file, line: i + 1,
                                excerpt: line.trimmingCharacters(in: .whitespaces)))
                break
            }
        }
        // Every file was read, so the answer is complete even if the budget ended up at zero.
        return (hits, false)
    }
}

// MARK: - Options

/// The settings a decompiler plugin exposes, in a file of its own.
///
/// Not in `decompilers.ini`: that file is hand-written, and rewriting it to record a checkbox would
/// reformat someone's comments away. Not in the host's `peachcmd.ini` either — an optional plugin
/// must not leave settings behind in the host's configuration when it is removed, and a host page for
/// a plugin that may not be installed is dead UI. This is the plugin's own file, next to its engines.
struct PluginDecompilerOptions: Equatable {
    /// Whether F3 on a whole archive opens the decompiled tree.
    ///
    /// Off means the plugin does not claim `.jar`/`.apk`/`.dex` for the viewer at all, so F3 falls
    /// back to the host's own viewer. Worth having as a switch because the panel route — decompile to
    /// sources, then use the file manager — is the better answer for most work, and someone who works
    /// that way should be able to stop a plugin window opening on F3.
    var claimArchives: Bool = true
    /// Whether the plugin may run an engine while the *host* is searching.
    ///
    /// The host asks before it searches (its own "search text provided by plugins" option); this is
    /// the plugin's side of the same consent, so a machine where decompiling is too slow can refuse
    /// once instead of the user remembering not to tick a box.
    var allowSearchDecompile: Bool = true
    /// Seconds for one class, and for a whole archive. Zero means "use the engine's own value".
    var classTimeout: Int = 0
    var archiveTimeout: Int = 0
    /// Days a cached result survives.
    var cacheMaxAgeDays: Int = 30

    static func file(configRoot: String) -> String {
        (PluginDecompilerRegistry.engineDirectory(configRoot: configRoot) as NSString)
            .appendingPathComponent("options.ini")
    }

    /// Read the options, falling back to the defaults for anything missing or unparsable.
    ///
    /// Forgiving in the same way the theme and engine files are: a mangled line costs that one setting
    /// rather than the whole file, because the alternative is a plugin that silently stops working
    /// because of a stray character.
    static func read(configRoot: String) -> PluginDecompilerOptions {
        var options = PluginDecompilerOptions()
        guard let text = try? String(contentsOfFile: file(configRoot: configRoot), encoding: .utf8) else {
            return options
        }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix(";"), !trimmed.hasPrefix("#"),
                  !trimmed.hasPrefix("["), let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eq]).trimmingCharacters(in: .whitespaces).lowercased()
            var value = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            // Strip a trailing comment, the way the engine file's parser does. This file is written
            // *with* such comments — `ClaimArchives = 1   ; F3 on a .jar …` — so not stripping them
            // read every value as unparsable: the numbers fell back to their defaults and the flags
            // came back false, which turned "on" into "off" on the first round trip.
            for marker in [";", "#"] {
                if let i = value.range(of: marker)?.lowerBound {
                    value = String(value[value.startIndex..<i]).trimmingCharacters(in: .whitespaces)
                }
            }
            switch key {
            case "claimarchives": options.claimArchives = boolean(value)
            case "searchdecompile": options.allowSearchDecompile = boolean(value)
            case "classtimeout": options.classTimeout = Int(value) ?? 0
            case "archivetimeout": options.archiveTimeout = Int(value) ?? 0
            case "maxagedays": options.cacheMaxAgeDays = Int(value) ?? 30
            default: break
            }
        }
        return options
    }

    static func boolean(_ value: String) -> Bool {
        ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    func write(configRoot: String) {
        let body = [
            "; Options for the decompiler plugin — written by its settings page.",
            "[Options]",
            "ClaimArchives   = \(claimArchives ? 1 : 0)   ; F3 on a .jar/.apk/.dex opens the decompiled tree",
            "SearchDecompile = \(allowSearchDecompile ? 1 : 0)   ; may decompile while the host searches",
            "ClassTimeout    = \(classTimeout)   ; seconds for one class (0 = the engine's own value)",
            "ArchiveTimeout  = \(archiveTimeout)   ; seconds for a whole archive (0 = the engine's own)",
            "MaxAgeDays      = \(cacheMaxAgeDays)   ; how long a cached result survives",
        ].joined(separator: "\n") + "\n"
        let path = Self.file(configRoot: configRoot)
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                 withIntermediateDirectories: true)
        try? body.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

extension PluginDecompilerEngine {
    /// This engine with the user's timeouts applied, where they set any.
    ///
    /// Applied here rather than at each call site so no path can forget it: an engine that ignored the
    /// configured limit would look like the setting does nothing.
    func withTimeouts(_ options: PluginDecompilerOptions) -> PluginDecompilerEngine {
        PluginDecompilerEngine(
            id: id, name: name, kinds: kinds, tool: tool, args: args, enginePath: enginePath,
            output: output, note: note,
            timeout: options.classTimeout > 0 ? options.classTimeout : timeout,
            archive: archive.map {
                PluginDecompilerArchiveSupport(
                    args: $0.args,
                    timeout: options.archiveTimeout > 0 ? options.archiveTimeout : $0.timeout)
            })
    }
}
