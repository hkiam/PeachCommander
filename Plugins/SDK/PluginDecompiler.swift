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

// MARK: - Errors

/// Why no source could be produced. The cases are distinct because the view must say something
/// different for each: "install an engine" is a setup problem, "the engine crashed" is not, and
/// neither is "this is not a class file".
enum DecompileError: Error, Equatable {
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
enum DecompilerOutput: String {
    /// Source is written to stdout — the common case, and the only one that needs no temp files.
    case stdout
    /// The engine insists on writing files; it is given a temp directory and the files are
    /// concatenated. Vineflower works this way unless told otherwise.
    case directory
}

/// One decompiler engine, as data.
struct DecompilerEngine: Equatable {
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
    let output: DecompilerOutput
    /// Shown when the engine is missing, so the message can name a licence and a download.
    let note: String?
    /// Seconds before the engine is stopped. Decompilers do get stuck — obfuscated bytecode is a
    /// known way to send one into a loop — and without a limit the view would say "Decompiling…"
    /// for ever with no way back.
    let timeout: Int

    func handles(kind: String) -> Bool { kinds.contains(kind.lowercased()) }

    static let defaultTimeout = 30
}

// MARK: - Built-in engine descriptors

extension DecompilerEngine {
    /// Engines the plugin knows how to drive. Descriptors only — nothing is bundled.
    ///
    /// Ordered by preference: CFR and Vineflower produce Java source and are permissively
    /// licensed (MIT and Apache-2.0), so they can be recommended without a licence caveat.
    /// `javap` comes last but needs no download at all: it is part of any JDK, and bytecode is a
    /// far better answer than an empty window.
    static func builtIns(engineDirectory: String) -> [DecompilerEngine] {
        func jar(_ name: String) -> String { (engineDirectory as NSString).appendingPathComponent(name) }
        return [
            DecompilerEngine(
                id: "cfr", name: "CFR", kinds: ["class", "jar"],
                tool: "java", args: ["-jar", "{engine}", "{input}"],
                enginePath: jar("cfr.jar"), output: .stdout,
                note: "CFR — MIT licence. Download cfr.jar from https://github.com/leibnitz27/cfr/releases",
                timeout: defaultTimeout),
            DecompilerEngine(
                id: "vineflower", name: "Vineflower", kinds: ["class", "jar"],
                tool: "java", args: ["-jar", "{engine}", "{input}", "{outdir}"],
                enginePath: jar("vineflower.jar"), output: .directory,
                note: "Vineflower — Apache-2.0 licence. Download vineflower.jar from "
                    + "https://github.com/Vineflower/vineflower/releases", timeout: defaultTimeout),
            DecompilerEngine(
                id: "procyon", name: "Procyon", kinds: ["class", "jar"],
                tool: "java", args: ["-jar", "{engine}", "{input}"],
                enginePath: jar("procyon.jar"), output: .stdout,
                note: "Procyon — Apache-2.0 licence. Download procyon-decompiler.jar from "
                    + "https://github.com/mstrobel/procyon/releases", timeout: defaultTimeout),
            DecompilerEngine(
                id: "javap", name: "javap (bytecode)", kinds: ["class"],
                tool: "javap", args: ["-c", "-p", "-constants", "{input}"],
                enginePath: nil, output: .stdout,
                note: "javap ships with any JDK — no download needed, but it shows bytecode "
                    + "rather than Java source.", timeout: defaultTimeout),
        ]
    }
}

// MARK: - Registry

/// Resolves which engine to use, from built-in descriptors plus the user's own.
struct DecompilerRegistry {
    private(set) var engines: [DecompilerEngine]
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
        var builtIns = DecompilerEngine.builtIns(engineDirectory: dir)
        var user: [DecompilerEngine] = []
        let iniPath = (dir as NSString).appendingPathComponent("decompilers.ini")
        if let text = try? String(contentsOfFile: iniPath, encoding: .utf8) {
            let parsed = Self.parse(text, engineDirectory: dir)
            warnings = parsed.warnings
            for engine in parsed.engines {
                if let i = builtIns.firstIndex(where: { $0.id == engine.id }) { builtIns[i] = engine }
                else { user.append(engine) }
            }
        }
        engines = user + builtIns
    }

    /// Engines that can handle `kind`, in preference order.
    func engines(for kind: String) -> [DecompilerEngine] {
        engines.filter { $0.handles(kind: kind) }
    }

    /// The first engine for `kind` that is actually present on disk.
    func firstAvailable(for kind: String) -> DecompilerEngine? {
        engines(for: kind).first { $0.isAvailable }
    }

    // MARK: Parsing

    /// Parse `decompilers.ini`. Deliberately forgiving in the same way theme files are: a bad
    /// section costs that engine and a warning, never the whole file.
    static func parse(_ text: String, engineDirectory: String)
        -> (engines: [DecompilerEngine], warnings: [String]) {
        var engines: [DecompilerEngine] = []
        var warnings: [String] = []
        var section: String?
        var fields: [String: String] = [:]

        func flush() {
            guard let id = section else { return }
            defer { fields = [:] }
            guard let tool = fields["tool"], !tool.isEmpty else {
                warnings.append("[\(id)]: no `tool`, ignored"); return
            }
            let kinds = (fields["kinds"] ?? "")
                .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
            guard !kinds.isEmpty else {
                warnings.append("[\(id)]: no `kinds`, ignored"); return
            }
            let output = DecompilerOutput(rawValue: (fields["output"] ?? "stdout").lowercased()) ?? .stdout
            engines.append(DecompilerEngine(
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
                timeout: fields["timeout"].flatMap(Int.init) ?? DecompilerEngine.defaultTimeout))
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

extension DecompilerEngine {
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

// MARK: - Running

enum DecompilerRunner {
    /// Run `engine` over `input` and return the source it produced.
    ///
    /// Synchronous on purpose: the caller is a lister view that is already off the main thread for
    /// its load, and threading here would only move the problem. Decompiling a large class takes
    /// seconds, so callers cache the result.
    static func run(_ engine: DecompilerEngine, input: String) -> Result<String, DecompileError> {
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

        let args = engine.args.map { arg -> String in
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
        let deadline = DispatchTime.now() + .seconds(engine.timeout)
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
            return .failure(.timedOut(engine: engine.name, seconds: engine.timeout))
        }

        let stderrText = String(data: errData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            return .failure(.engineFailed(engine: engine.name,
                                          exitCode: process.terminationStatus,
                                          message: stderrText))
        }

        let text: String
        if let outDir {
            text = collect(from: outDir)
        } else {
            text = String(data: outData, encoding: .utf8) ?? ""
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyOutput(engine: engine.name))
        }
        return .success(text)
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
