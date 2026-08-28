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
import PCFoundation
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
    /// Rename a batch in one folder, all or nothing (F-447).
    ///
    /// Checked against the folder's actual names before anything moves, so a table the model got wrong
    /// comes back as reasons rather than as half a rename. The engine underneath is the one the
    /// Multi-Rename window uses, which is what makes a swap work — it stages through temporary names —
    /// and what makes the whole batch one entry in the action log rather than forty.
    nonisolated func renameBatch(directory: String, oldNames: [String], newNames: [String])
        async throws -> (renamed: Int, directory: String, problems: [RenameBatchPlan.Problem]) {
        let planned = await plannedRenameBatch(directory: directory, oldNames: oldNames,
                                               newNames: newNames)
        guard planned.problems.isEmpty else { return (0, planned.folder, planned.problems) }

        let outcome = RenameBatchEngine.apply(dir: planned.folder,
                                              pairs: planned.pairs.map { (old: $0.old, new: $0.new) })
        // The engine can still refuse one — a file that vanished between the check and the move. That
        // is reported rather than swallowed, and the ones that did happen are counted.
        let failures = outcome.failed.map { RenameBatchPlan.Problem(name: $0.name, reason: $0.reason) }
        // The same refresh the bridge's other writes do, so the panel does not keep showing the old
        // names until something else happens to reload it.
        await host?.activePanel?.reload()
        return (outcome.log.count, planned.folder, failures)
    }

    nonisolated func renameBatchProblems(directory: String, oldNames: [String],
                                         newNames: [String]) async -> [RenameBatchPlan.Problem] {
        await plannedRenameBatch(directory: directory, oldNames: oldNames, newNames: newNames).problems
    }

    /// The batch resolved against the folder it will run in — one place, so the check the Core makes
    /// before proposing and the check made before applying cannot drift apart.
    private nonisolated func plannedRenameBatch(directory: String, oldNames: [String], newNames: [String])
        async -> (folder: String, pairs: [RenameBatchPlan.Pair], problems: [RenameBatchPlan.Problem]) {
        let folder = directory.isEmpty || directory == "."
            ? await MainActor.run { self.host?.activePanel?.directoryPath ?? "" }
            : directory
        guard !folder.isEmpty else {
            return ("", [], [RenameBatchPlan.Problem(name: "(the batch)",
                                                     reason: "no folder to work in")])
        }
        switch RenameBatchPlan.pair(old: oldNames, new: newNames) {
        case .failure(let problem):
            return (folder, [], [problem])
        case .success(let pairs):
            let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [])
            return (folder, pairs, RenameBatchPlan.problems(in: pairs, existing: existing))
        }
    }

    /// Find files through Spotlight — macOS's own index, so there is nothing of ours to build or keep
    /// current, and no warm-up to wait for (F-446).
    ///
    /// The scope travels back with the result. Without it "nothing found" cannot be read: the model
    /// cannot tell "not anywhere on this disk" from "I only looked in one folder", and neither can the
    /// user. And Spotlight honours the privacy exclusions and the places macOS keeps to itself, so an
    /// empty answer is never proof that a file is absent.
    nonisolated func findFiles(nameMask: String, contentText: String?, kind: String?, withinDays: Int?,
                               largerThanBytes: Int64?, smallerThanBytes: Int64?,
                               scope: String, limit: Int)
        async throws -> (entries: [AutomationEntry], scope: String) {
        var query = SpotlightQuery(nameMask: nameMask,
                                   contentText: (contentText?.isEmpty ?? true) ? nil : contentText,
                                   kind: kind.flatMap { SpotlightQuery.Kind(loose: $0) },
                                   modifiedWithinDays: withinDays,
                                   largerThanBytes: largerThanBytes,
                                   smallerThanBytes: smallerThanBytes)
        // A kind that was asked for and not understood must not silently widen the search to
        // everything: answering about every file when the user said "PDFs" is worse than saying so.
        if let kind, !kind.isEmpty, query.kind == nil {
            return ([], "unknown kind \"\(kind)\" — use one of: "
                    + SpotlightQuery.Kind.allCases.map(\.rawValue).joined(separator: ", "))
        }
        if query.isEmpty {
            return ([], "nothing to look for — give a name, a word inside the files, a kind, "
                    + "a time window or a size")
        }
        let active = await MainActor.run { self.host?.activePanel?.directoryPath ?? "" }
        let resolved = SpotlightSearch.Scope(scope, activeFolder: active)
        // A folder scope with no folder to stand on would search the volume root by accident.
        if case .folder(let p) = resolved, p.isEmpty {
            return ([], "no folder to search in")
        }
        let search = await MainActor.run { SpotlightSearch() }
        let hits = await search.find(query, scope: resolved, limit: max(1, min(limit, 500)))
        let entries = hits.map {
            AutomationEntry(name: ($0.path as NSString).lastPathComponent, path: $0.path,
                            isDirectory: $0.isDirectory, size: $0.size, modified: $0.modified)
        }
        return (entries, resolved.described)
    }

    /// Rank this folder's files against `query`. The reading is here; the ranking is
    /// `SemanticRanker`, in PCAutomation, where a test can reach it.
    nonisolated func semanticSearch(query: String, path: String?, limit: Int) async throws -> [AutomationEntry] {
        let folder: String
        if let path, !path.isEmpty { folder = path }
        else { folder = await MainActor.run { self.host?.activePanel?.directoryPath ?? "" } }
        guard !folder.isEmpty else { return [] }
        let entries = (try? await listDirectory(folder))?.filter { !$0.isDirectory } ?? []
        let embedding = SemanticRanker.embedding(for: query,
                                                 reader: Bundle.main.preferredLocalizations.first)
        let phrase = SemanticRanker.comparablePhrase(query)
        func score(_ text: String) -> Double {
            SemanticRanker.semantic(embedding, phrase: phrase, text: text)
                ?? SemanticRanker.lexical(query: query, text: text)
        }
        // A folder can hold thousands of files and each one costs a read; the cap keeps a
        // "find X here" from turning into a scan of everything.
        var candidates: [SemanticRanker.Candidate] = []
        var byName: [String: AutomationEntry] = [:]
        for entry in entries.prefix(300) {
            // Only the beginning of the file: the ranker decides what of it is worth comparing.
            let sample = (try? await readFile(entry.path, maxBytes: 2048)) ?? ""
            candidates.append(.init(name: entry.name, sample: sample))
            byName[entry.name] = entry
        }
        return SemanticRanker.rank(candidates, limit: limit, score: score).compactMap { byName[$0] }
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

    /// Vision, on the device, with no language model involved — see `ImageReader`, which both this
    /// and the tests call so that one implementation is the only implementation.
    func describeImage(_ path: String) async throws -> ImageDescription {
        try await ImageReader.describe(path: path)
    }

    func getTags(_ path: String) async throws -> [String] {
        FinderTagColor.rawTags(forPath: path)
    }

    /// Written through `FinderTagColor`, which writes the raw `_kMDItemUserTags` xattr rather than
    /// `URLResourceValues.tagNames` — the latter drops the colour, and a colourless tag is not the
    /// thing the reader sees in Finder.
    func setTags(_ path: String, tags: [String]) async throws {
        guard FinderTagColor.writeRawTags(tags, toPath: path) else {
            throw AutomationError.notImplemented("set_tags: could not write the tags on \(path)")
        }
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
    /// Select entries in the active panel by a wildcard mask.
    ///
    /// This threw `notImplemented` while the very same operation had been available to AppleScript since
    /// F-296 — `applySelectionMask` was one call away, and the tool was declared in the catalogue the
    /// whole time. The cost was not the missing tool but what it made *macros*: a macro could only ever
    /// act on what the user had already marked, so "select every PDF and file it away" was not
    /// expressible (F-478).
    ///
    /// It **replaces** the selection, where AppleScript's `select` adds to it. One shared seam with one
    /// honest parameter rather than two implementations: the difference is real and belongs to the
    /// caller, not to the mask matching.
    ///
    /// The two paths still differ in one way this does not fix. `MainWindowController.scriptSelect` —
    /// what AppleScript's `select` and the "Select Items by Mask" Shortcut return — reads the selection
    /// on the line after applying the mask, so its *return value* is the selection from before. The
    /// mask is applied correctly; only what it reports back is stale. Fixing it needs the AppleScript
    /// command to suspend and resume (`NSScriptCommand.suspendExecution`), which is a change to a
    /// shipped verb and not this.
    func setSelection(mask: String) async throws {
        guard let host, let panel = host.activePanel else {
            throw AutomationError.notImplemented("host released")
        }
        // `replacing`, so afterwards exactly the matches are marked. Adding — which is what the
        // keystroke and AppleScript's `select` do — would make a macro depend on what happened to be
        // selected when it started, and would defeat the check below: a mask that matched nothing would
        // still leave the previous selection standing and read as success.
        await panel.tableView.applyingSelectionMask(mask, unselect: false, includeDirectories: true,
                                                    replacing: true)
        // What is marked *now*, from the selection state — not the mask's own count, which counts only
        // newly marked entries and is therefore zero for a mask naming files that were already
        // selected; and not `selectedOrCursorPaths`, which falls back to the cursor and so cannot tell
        // "nothing is selected" from "one thing is under the cursor".
        let marked = await panel.getSelectionState().getSelectedPathList()
        // Refused rather than passed over in silence, and this is the point of implementing the tool at
        // all: `%S` falls back to the file under the cursor when nothing is selected — deliberately, the
        // way a button bar's `%S` does. So a macro whose mask matched nothing would go on to move
        // whatever the cursor happened to be on. The user asked for the PDFs.
        guard !marked.isEmpty else {
            throw AutomationError.operationFailed("Nothing in this folder matches “\(mask)”.")
        }
    }
    func runCommand(_ id: String) async throws { host?.contribInvokeCommand(id) }

    /// `clearContents()` first, because setString alone leaves any other representation of the
    /// previous owner in place — a pasteboard still advertising the last copy's file URLs next to
    /// the new text, which pastes as the old files in anything that prefers them.
    func copyToClipboard(_ text: String) async throws {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

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

    /// Put the macro's questions to the user (F-478).
    ///
    /// On the main actor, because it is a modal; awaited by the Core, which is an actor and suspends
    /// here like anywhere else. The macro's title is passed so the dialog can say which macro is
    /// asking — with a button on the bar and a key on the keyboard, "these values are needed" without
    /// a name is a question about nothing in particular.
    func askForValues(_ questions: [MacroQuestion], forMacro title: String) async -> [String: String]? {
        guard let host else { return nil }
        return MacroAskSheet.present(questions, macroTitle: title, in: host.window)
    }

    // MARK: Write / delete / config (reached only after the policy allows/confirms)

    // Both of these WAIT for the transfer to finish. They used to enqueue and return, so the
    // tool reported success before a single byte had moved: an assistant asked to copy files and
    // then read them raced its own copy, a plan of several steps ran against a queue that had
    // not started, and taking a move back could undo something still in flight. The transfer is
    // still a normal background job — visible, pausable, cancellable in the Transfer Manager —
    // the tool simply does not claim to be done until it is.
    func copy(sources: [String], destination: String) async throws {
        try requireExistingDirectory(destination)
        try await runTransfer(.copy(items: sources, toDirectory: destination, options: CopyOptions()),
                              title: "Copy \(sources.count) item(s)")
    }
    func move(sources: [String], destination: String) async throws {
        try requireExistingDirectory(destination)
        try await runTransfer(.move(items: sources, toDirectory: destination, options: CopyOptions()),
                              title: "Move \(sources.count) item(s)")
    }

    /// Refuse a transfer whose destination folder is not there.
    ///
    /// **Measured, and it destroyed files.** `move` with a destination that does not exist reported
    /// `ok` — no payload, no error, the Transfer Manager finished successfully — and the sources were
    /// gone from where they had been and were nowhere else. Two files, one call, no way back: the audit
    /// entry even carried an inverse that could not restore them.
    ///
    /// The guard is here rather than in the operations engine because this is the layer where a
    /// destination arrives as an arbitrary *string*: the assistant, an MCP client and a macro all name
    /// a folder in text, and any of them can name one that is not there. A panel's own F5/F6 cannot —
    /// its destination is a directory it is displaying. The engine's behaviour is a separate defect and
    /// this does not fix it; it stops the automation surface from reaching it.
    private func requireExistingDirectory(_ path: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw AutomationError.operationFailed(
                "Nothing was moved or copied: the folder “\(path)” does not exist. "
                + "Create it first (make_directory) and try again.")
        }
        guard isDirectory.boolValue else {
            throw AutomationError.operationFailed(
                "Nothing was moved or copied: “\(path)” is a file, not a folder.")
        }
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
