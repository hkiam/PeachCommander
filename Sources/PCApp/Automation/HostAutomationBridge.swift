// SPDX-License-Identifier: Apache-2.0
// HostAutomationBridge.swift - the PCApp implementation of AutomationHostBridge.
//
// Wires the Automation Core to the real file manager: panels, the background op
// engine (TransferManager), the command bridge, and ConfigStore. Reuses the same
// accessors the contribution/tool bridges use, so the agent, the (planned) MCP
// server and the Python plugin all drive the app through one audited seam.
//
// v1 scope: context, config get/set, navigation, run-command, copy/move (via the
// background transfer queue), trash/delete, mkdir/rename, and local directory
// listing / stat / file read. Not yet wired (return .notImplemented): structured
// search, command/plugin enumeration, select-by-mask — follow-up increments.

import AppKit
import Foundation
import PCAutomation
import PCOperations
import NaturalLanguage
import CryptoKit

@MainActor
final class HostAutomationBridge: AutomationHostBridge {
    private weak var host: MainWindowController?
    init(host: MainWindowController) { self.host = host }

    // MARK: Context / reads

    func context() async throws -> AutomationContext {
        guard let host else { throw AutomationError.notImplemented("host released") }
        let active = host.activePanel
        let inactive = (active === host.leftPanelController) ? host.rightPanelController : host.leftPanelController
        let selection = await active?.selectedOrCursorPaths() ?? []
        return AutomationContext(
            activePanelPath: active?.directoryPath ?? "",
            inactivePanelPath: inactive?.directoryPath ?? "",
            cursorPath: active?.tableView.cursorItemFullPath(),
            selection: selection,
            tabPaths: active.map { [$0.directoryPath] } ?? [],
            viewMode: active?.viewMode.rawValue ?? "details")
    }

    // The reads below are `nonisolated` on a @MainActor class on purpose: they touch the file
    // system and nothing else in the app, and the assistant is exactly the feature that asks
    // for them on large inputs. Left on the main actor, "hash these files" or "summarise this
    // report" froze the window for as long as the I/O took — the plugin waits on a background
    // thread either way, so the main thread was blocked for no one's benefit.

    // MARK: Paths

    /// The path a tool was given, resolved to one that exists — see `AutomationPath`, where the
    /// rules live so they can be tested against the cases the model actually produces.
    nonisolated func resolveExisting(_ path: String) async -> String {
        let active = await MainActor.run { self.host?.activePanel?.directoryPath ?? "" }
        return AutomationPath.resolveExisting(path, activeFolder: active,
                                              exists: { FileManager.default.fileExists(atPath: $0) })
    }

    /// For a path being *created*: resolved by its parent, so a new file lands where the user is
    /// looking rather than in the process's working directory.
    nonisolated func resolveForWriting(_ path: String) async -> String {
        let active = await MainActor.run { self.host?.activePanel?.directoryPath ?? "" }
        return AutomationPath.resolveForWriting(path, activeFolder: active,
                                                exists: { FileManager.default.fileExists(atPath: $0) })
    }

    nonisolated func listDirectory(_ path: String) async throws -> [AutomationEntry] {
        let fm = FileManager.default
        let path = await resolveExisting(path)
        return try fm.contentsOfDirectory(atPath: path).map { name in
            let full = (path as NSString).appendingPathComponent(name)
            let attrs = try? fm.attributesOfItem(atPath: full)
            return AutomationEntry(name: name, path: full,
                                   isDirectory: (attrs?[.type] as? FileAttributeType) == .typeDirectory,
                                   size: (attrs?[.size] as? NSNumber)?.int64Value ?? 0,
                                   modified: attrs?[.modificationDate] as? Date)
        }
    }

    nonisolated func stat(_ path: String) async throws -> AutomationEntry {
        let path = await resolveExisting(path)
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        return AutomationEntry(name: (path as NSString).lastPathComponent, path: path,
                               isDirectory: (attrs[.type] as? FileAttributeType) == .typeDirectory,
                               size: (attrs[.size] as? NSNumber)?.int64Value ?? 0,
                               modified: attrs[.modificationDate] as? Date)
    }

    nonisolated func readFile(_ path: String, maxBytes: Int) async throws -> String {
        try await readFile(path, maxBytes: maxBytes, offset: 0)
    }

    /// Seeks instead of reading and discarding: a file read in slices is read once per slice,
    /// not once per slice from the beginning. (The protocol's default does the latter, which is
    /// quadratic over a long file.)
    nonisolated func readFile(_ path: String, maxBytes: Int, offset: Int) async throws -> String {
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: await resolveExisting(path)))
        defer { try? handle.close() }
        if offset > 0 { try handle.seek(toOffset: UInt64(offset)) }
        let data = try handle.read(upToCount: max(0, maxBytes)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    func search(queryJSON: Data) async throws -> [AutomationEntry] {
        guard let host else { return [] }
        let d = (try? JSONSerialization.jsonObject(with: queryJSON)) as? [String: Any] ?? [:]
        let mask = (d["mask"] as? String) ?? (d["nameMask"] as? String) ?? "*"
        let text = d["text"] as? String
        let path = (d["path"] as? String) ?? (d["startDirectory"] as? String) ?? ""
        // A relative start directory means the active folder, not the process's working
        // directory. Measured: the model passes "." for "here", and searching the app's own
        // working directory answers a question nobody asked — with "nothing found", which reads
        // as "there is no such file".
        let active = host.automationActivePath()
        let start: String
        if path.isEmpty || path == "." { start = active }
        else if path.hasPrefix("/") { start = path }
        else { start = (active as NSString).appendingPathComponent(path) }
        let depth = d["maxDepth"] as? Int ?? 0
        let paths = await host.automationSearch(mask: mask, text: text, startDirectory: start,
                                                maxDepth: depth, limit: 200)
        var out: [AutomationEntry] = []
        for p in paths { if let e = try? await stat(p) { out.append(e) } }
        return out
    }

    /// Rank a folder's files against a description — by their names AND by the beginning of
    /// what is inside them.
    ///
    /// Names only was the previous behaviour, and it could not answer the question the tool is
    /// named for: "find the invoice about the roof repair" is not a statement about file names.
    /// A bounded prefix of each file is read and scored too, which is what lets a file whose
    /// name says nothing be found by what it says. Still no index — the work is per call, over
    /// one folder, so nothing is built up behind the user's back.
    ///
    /// The embedding follows the query's own language. It was pinned to English, so a German
    /// query fell back to counting shared tokens and the "semantic" part quietly did nothing.
    nonisolated func semanticSearch(query: String, path: String?, limit: Int) async throws -> [AutomationEntry] {
        let folder: String
        if let path, !path.isEmpty { folder = path }
        else { folder = await MainActor.run { self.host?.activePanel?.directoryPath ?? "" } }
        guard !folder.isEmpty else { return [] }
        let entries = (try? await listDirectory(folder))?.filter { !$0.isDirectory } ?? []
        let embedding = Self.embedding(for: query)
        let q = query.lowercased()
        let queryTokens = Set(Self.tokens(of: q))

        func semantic(_ text: String) -> Double? {
            guard let embedding, !text.isEmpty else { return nil }
            let d = embedding.distance(between: q, and: text)   // smaller = closer
            guard d.isFinite, d > 0, d < 2 else { return nil }
            return 2 - d                                        // higher = better
        }
        func lexical(_ text: String) -> Double {
            guard !queryTokens.isEmpty else { return 0 }
            return Double(queryTokens.intersection(Set(Self.tokens(of: text))).count)
                / Double(queryTokens.count)
        }
        func score(_ text: String) -> Double { semantic(text) ?? lexical(text) }

        var scored: [(AutomationEntry, Double)] = []
        // A folder can hold thousands of files and each one costs a read; the cap keeps a
        // "find X here" from turning into a scan of everything.
        for entry in entries.prefix(300) {
            let nameScore = score(Self.readableName(entry.name))
            // Only text-shaped files are worth reading, and only their beginning.
            let sample = (try? await readFile(entry.path, maxBytes: 2048)) ?? ""
            let contentScore = Self.looksLikeText(sample) ? score(Self.condensed(sample)) : 0
            // The name is the stronger signal when it says anything at all; the content is what
            // rescues a file called scan_0001.pdf.txt.
            scored.append((entry, max(nameScore, contentScore * 0.9)))
        }
        // Everything with a score above zero is not an answer: the model reads a list of the
        // whole folder as "these are all about it" and passes that on. Keep what is close to
        // the best match, so a clear winner arrives as one, and a folder with nothing to do
        // with the query comes back empty rather than complete.
        let ranked = scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        guard let best = ranked.first?.1 else { return [] }
        // Relative to the best match, never absolute: an absolute floor threw away the best
        // match too whenever the whole folder scored low, and "no file matches" is a worse
        // answer than a weak one. The best match is always returned; the cutoff only decides
        // how much company it keeps.
        let cutoff = best * 0.7
        return ranked.enumerated()
            .filter { $0.offset == 0 || $0.element.1 >= cutoff }
            .prefix(max(1, limit))
            .map { $0.element.0 }
    }

    /// The sentence embedding for the query's language, English as the fallback.
    nonisolated private static func embedding(for query: String) -> NLEmbedding? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(query)
        if let language = recognizer.dominantLanguage,
           let embedding = NLEmbedding.sentenceEmbedding(for: language) {
            return embedding
        }
        return NLEmbedding.sentenceEmbedding(for: .english)
    }

    nonisolated private static func tokens(of text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// "quartals_bericht-q3.txt" → "quartals bericht q3": separators carry no meaning here.
    nonisolated private static func readableName(_ name: String) -> String {
        (name as NSString).deletingPathExtension
            .replacingOccurrences(of: "[_.\\-]", with: " ", options: .regularExpression)
            .lowercased()
    }

    /// Whether a sample is text at all — a binary read as a string is noise to an embedding.
    nonisolated private static func looksLikeText(_ sample: String) -> Bool {
        guard !sample.isEmpty else { return false }
        let printable = sample.unicodeScalars.prefix(400).filter {
            $0 == "\n" || $0 == "\t" || $0 == "\r" || ($0.value >= 32 && $0.value != 0xFFFD)
        }.count
        return Double(printable) / Double(min(sample.unicodeScalars.count, 400)) > 0.9
    }

    /// The first few hundred characters, whitespace collapsed: an embedding gains nothing from
    /// a page of it, and the distance call is what costs the time.
    nonisolated private static func condensed(_ text: String) -> String {
        String(text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(400)).lowercased()
    }

    /// Hashed in chunks rather than mapped whole: "find duplicates" over a folder of disk
    /// images used to pull each file into memory before hashing it, on the main thread.
    nonisolated func hashFile(_ path: String, algorithm: String) async throws -> (hash: String, algorithm: String) {
        let algo = algorithm.lowercased()
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: await resolveExisting(path)))
        defer { try? handle.close() }
        var sha256 = SHA256(), sha1 = Insecure.SHA1(), md5 = Insecure.MD5()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            switch algo {
            case "sha1": sha1.update(data: chunk)
            case "md5":  md5.update(data: chunk)
            default:     sha256.update(data: chunk)
            }
            await Task.yield()   // a multi-gigabyte file stays cancellable and stays polite
        }
        func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
            digest.map { String(format: "%02x", $0) }.joined()
        }
        switch algo {
        case "sha1": return (hex(sha1.finalize()), "sha1")
        case "md5":  return (hex(md5.finalize()), "md5")
        default:     return (hex(sha256.finalize()), "sha256")
        }
    }

    func getComment(_ path: String) async throws -> String? {
        guard let host else { throw AutomationError.notImplemented("host released") }
        return host.contribFileComment(await resolveExisting(path))
    }

    func setComment(_ path: String, comment: String?) async throws {
        // The host's own method, so the Finder mirror and the Comment column's refresh cannot be
        // forgotten here — and unlike the plugin ABI's version, a failure is reported.
        guard let host else { throw AutomationError.notImplemented("host released") }
        try await host.setFileComment(comment, path: path)
    }

    func writeFile(_ path: String, content: String) async throws {
        let path = await resolveForWriting(path)
        try content.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        Task { @MainActor in await host?.activePanel?.reload() }
    }

    func mergeFiles(sources: [String], destination: String) async throws -> (destination: String, count: Int, rows: Int) {
        let fm = FileManager.default
        // Resolve the inputs: explicit list, otherwise the current panel selection.
        var srcs = sources
        if srcs.isEmpty { srcs = await host?.activePanel?.selectedOrCursorPaths() ?? [] }
        srcs = srcs.filter { p in
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: p, isDirectory: &isDir) && !isDir.boolValue
        }
        guard !srcs.isEmpty else {
            throw AutomationError.missingArgument("no files to merge (select the files first)")
        }
        // Resolve the destination relative to the active folder when it isn't absolute.
        let baseDir = host?.activePanel?.directoryPath ?? (srcs[0] as NSString).deletingLastPathComponent
        var dest = destination.isEmpty ? "merged.txt" : destination
        if !(dest as NSString).isAbsolutePath { dest = (baseDir as NSString).appendingPathComponent(dest) }

        let contents = try srcs.map { try String(contentsOf: URL(fileURLWithPath: $0), encoding: .utf8) }
        let allCSV = srcs.allSatisfy { ($0 as NSString).pathExtension.lowercased() == "csv" }
        var out = ""
        var rows = 0
        if allCSV {
            // Keep the header from the first file; drop a matching header row from the rest.
            var header: String?
            for text in contents {
                var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                if lines.last == "" { lines.removeLast() }
                guard !lines.isEmpty else { continue }
                if header == nil {
                    header = lines.first
                    out += lines.first! + "\n"
                    for l in lines.dropFirst() { out += l + "\n"; rows += 1 }
                } else {
                    if lines.first == header { lines.removeFirst() }
                    for l in lines { out += l + "\n"; rows += 1 }
                }
            }
        } else {
            for text in contents {
                out += text
                if !text.hasSuffix("\n") { out += "\n" }
                rows += 1
            }
        }
        try out.write(to: URL(fileURLWithPath: dest), atomically: true, encoding: .utf8)
        await host?.activePanel?.reload()
        return (dest, srcs.count, rows)
    }

    func remember(_ text: String) async throws {
        guard let url = host?.automationMemoryURL else { return }
        MemoryStore(url: url).add(text, at: Date().timeIntervalSince1970)
    }
    func recall(_ query: String, limit: Int) async throws -> [String] {
        guard let url = host?.automationMemoryURL else { return [] }
        return MemoryStore(url: url).recall(query, limit: limit)
    }

    func listCommandsJSON() async throws -> Data {
        guard let host else { return Data("[]".utf8) }
        return try JSONSerialization.data(withJSONObject: await host.automationCommands())
    }

    func listPluginsJSON() async throws -> Data {
        guard let host else { return Data("[]".utf8) }
        return try JSONSerialization.data(withJSONObject: await host.automationPlugins())
    }

    func getConfig(_ key: String) async throws -> String? {
        guard let host, let (section, k) = Self.splitKey(key) else {
            throw AutomationError.missingArgument("key must be \"Section.Key\"")
        }
        let v = await host.mainConfig.string(section, k, default: "")
        return v.isEmpty ? nil : v
    }

    // MARK: Navigate

    func openPath(_ path: String) async throws { host?.contribOpenPath(path) }
    func openInPanel(_ path: String, side: String) async throws {
        host?.contribOpenPathInPanel(side: side.lowercased() == "right" ? 1 : 0, path: path)
    }
    func setSelection(mask: String) async throws { throw AutomationError.notImplemented("set_selection") }
    func runCommand(_ id: String) async throws { host?.contribInvokeCommand(id) }

    func runShell(_ command: String) async throws -> String {
        guard let host else { throw AutomationError.notImplemented("run_shell") }
        return try await host.runShellVisibly(command)
    }

    /// What `run_command(id)` really amounts to, so the policy can judge the command rather than the
    /// tool that names it.
    ///
    /// Classified by the registry's own category, because a hand-kept list of command ids rots: the
    /// next destructive command added to the app would not be on it, and nothing would say so. The
    /// categories that change something are named here and everything else is free; a command with a
    /// category not listed either way — a new one, or a plugin's — is treated as mutating, so a gap
    /// costs a confirmation instead of a deletion.
    ///
    /// "Network" and "Commands" are in the mutating set for reasons worth naming: they hold
    /// `cm_FtpRawCommand` (sends whatever it is given to the server), `cm_DownloadFromURL` and
    /// `cm_SyncDirs` (both write files), and `cm_OpenTerminal`.
    func commandInfo(_ id: String) async -> AutomationCommandInfo {
        let mutatingCategories: Set<String> = ["Files", "Configuration", "Network", "Commands"]
        let freeCategories: Set<String> = ["View", "Navigation", "Sort", "Selection", "Mark",
                                           "Tabs", "Panel", "Help", "Search", "Volume"]
        guard let host, let command = await host.automationCommand(named: id) else {
            return .unknown
        }
        let capability: Capability
        if mutatingCategories.contains(command.category) {
            capability = .write
        } else if freeCategories.contains(command.category) {
            capability = .runCommand
        } else {
            capability = .write            // an unclassified category: assume it changes something
        }
        return AutomationCommandInfo(capability: capability, label: command.help)
    }

    // MARK: Write / delete / config (reached only after the policy allows/confirms)

    // Both of these WAIT for the transfer to finish. They used to enqueue and return, so the
    // tool reported success before a single byte had moved: an assistant asked to copy files and
    // then read them raced its own copy, a plan of several steps ran against a queue that had
    // not started, and taking a move back could undo something still in flight. The transfer is
    // still a normal background job — visible, pausable, cancellable in the Transfer Manager —
    // the tool simply does not claim to be done until it is.
    func copy(sources: [String], destination: String) async throws {
        try await runTransfer(.copy(items: sources, toDirectory: destination, options: CopyOptions()),
                              title: "Copy \(sources.count) item(s)")
    }
    func move(sources: [String], destination: String) async throws {
        try await runTransfer(.move(items: sources, toDirectory: destination, options: CopyOptions()),
                              title: "Move \(sources.count) item(s)")
    }

    private func runTransfer(_ kind: OperationKind, title: String) async throws {
        let succeeded: Bool = await withCheckedContinuation { continuation in
            TransferManager.shared.enqueue(kind, title: title,
                                           onFinish: { ok in continuation.resume(returning: ok) })
        }
        guard succeeded else {
            throw AutomationError.operationFailed("\(title) did not complete — see the Transfer Manager.")
        }
    }
    func rename(path: String, newName: String) async throws {
        guard !newName.contains("/"), newName != ".", newName != ".." else {
            throw AutomationError.missingArgument("new_name must be a single path component")
        }
        let path = await resolveExisting(path)
        let dst = (path as NSString).deletingLastPathComponent + "/" + newName
        try FileManager.default.moveItem(atPath: path, toPath: dst)
        host?.toolReloadActivePanel()
    }
    func makeDirectory(_ path: String) async throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        host?.toolReloadActivePanel()
    }
    func setConfig(_ key: String, _ value: String) async throws {
        guard let host, let (section, k) = Self.splitKey(key) else {
            throw AutomationError.missingArgument("key must be \"Section.Key\"")
        }
        await host.mainConfig.setString(value, section, k)
    }
    func moveToTrash(_ paths: [String]) async throws { host?.toolMoveToTrash(paths) }
    func deletePermanently(_ paths: [String]) async throws { host?.toolDeletePermanently(paths) }

    private static func splitKey(_ key: String) -> (String, String)? {
        let parts = key.split(separator: ".", maxSplits: 1).map(String.init)
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }
}
