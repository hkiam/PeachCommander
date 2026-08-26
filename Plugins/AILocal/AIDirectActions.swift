// SPDX-License-Identifier: Apache-2.0
// AIDirectActions.swift — the "AI ▸" actions that do NOT open the chat.
//
// Every skill command used to begin with `presentAIView`, so summarising a file meant mounting a
// sidebar, starting a conversation and reading the answer out of a transcript. That is why the
// module-level `pending*` globals exist: an action could not run before the panel was mounted.
//
// These four run without any of it. They also offer the model NO tools, which is the whole point:
// measured on macOS 26.4, the chat's tool schemas cost 3442 of the on-device model's 4096 tokens,
// leaving 473 for the file, the question and the answer together — so a 4 KB slice could not fit.
// With no tools the window belongs to the file. See LiveDirectActionTests.
//
// Reading and writing still go through the Automation Core, so the host's autonomy policy and the
// audit log apply exactly as before. What changes is who decides: the reader approves the whole
// list in one sheet, and this code then answers the host's per-action gate for each row it kept.
//
// NOT declared `"async": true` in the manifest, deliberately. That flag would give us the host's
// progress window, but it also moves PcRunCommand off the main thread, where a plugin "may not
// touch AppKit directly" (ContributionModel.swift) — and these actions are a sheet. Returning
// immediately and working inside a @MainActor Task keeps AppKit legal and still never blocks the
// main thread, because every generation suspends at an await.

import AppKit
import PCAutomation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AIDirectAction: String {
    case summarize, explain, rename, comment, organize, find, classify, table

    /// The commands this plugin contributes.
    static func forCommand(_ id: String) -> AIDirectAction? {
        switch id {
        case "plugin.ailocal.summarize": return .summarize
        case "plugin.ailocal.explain":   return .explain
        case "plugin.ailocal.rename":    return .rename
        case "plugin.ailocal.comment":   return .comment
        case "plugin.ailocal.organize":  return .organize
        case "plugin.ailocal.find":      return .find
        case "plugin.ailocal.classify":  return .classify
        case "plugin.ailocal.table":     return .table
        default:                         return nil
        }
    }
}

enum AIDirect {

    /// Take `id` if it is one of ours and the on-device model is actually there.
    ///
    /// No preference to consult: this bundle *is* the on-device assistant, so which model runs is
    /// settled by which plugin the reader enabled rather than by a setting that used to default to
    /// "auto" and quietly picked the path that did not work.
    static func handle(_ id: String, _ svc: PcHostServices) -> Bool {
        guard let action = AIDirectAction.forCommand(id) else { return false }
        #if canImport(FoundationModels)
        if #available(macOS 26, *), SystemLanguageModel.default.availability == .available {
            Task { @MainActor in await DirectActionRunner(svc).run(action) }
            return true
        }
        #endif
        Task { @MainActor in AIDirect.reportUnavailable(svc) }
        return true
    }

    /// Said once, plainly: this plugin has nothing to run on.
    @MainActor
    private static func reportUnavailable(_ svc: PcHostServices) {
        guard let fn = svc.presentInfo else { return }
        let title = String(localized: "AI", comment: "AI: info title")
        let text = String(localized: "Apple Intelligence is not available on this Mac, so the on-device actions cannot run.",
                          comment: "AI: the on-device model is missing entirely")
        title.withCString { t in text.withCString { m in fn(svc.host, t, m) } }
    }
}

#if canImport(FoundationModels)

@available(macOS 26, *)
@MainActor
final class DirectActionRunner {
    private let svc: PcHostServices
    private let core: RemoteAutomationCore
    private let session: AppleNativeToolSession
    private let progress: AIProgressSheet
    private let facts: FileFactStore

    init(_ svc: PcHostServices) {
        self.svc = svc
        let core = RemoteAutomationCore(services: svc)
        self.core = core
        let root = AIHost.configRoot(svc)
        // The same store the panel's AI Summary column reads. Until now only a chat turn ever
        // wrote it, which is why that column was empty for anyone who never chatted.
        let summaries = SummaryStore(url: URL(fileURLWithPath: root)
            .appendingPathComponent("aichat/summaries.json"))
        self.facts = FileFactStore(url: URL(fileURLWithPath: root)
            .appendingPathComponent("aichat/facts.json"))
        self.session = AppleNativeToolSession(directActionsOn: core, policy: .standard,
                                              summaryStore: summaries)
        self.progress = AIProgressSheet(parent: AIHost.parentWindow(svc))
    }

    func run(_ action: AIDirectAction) async {
        switch action {
        case .summarize:           await summarize()
        case .explain:             await explain()
        case .rename:              await rename()
        case .comment:             await comment()
        case .organize:            await organize()
        case .find:                await findByMeaning()
        case .classify:            await classify()
        case .table:               await makeTable()
        }
    }

    // MARK: - Summarise / explain

    private func summarize() async {
        let paths = AIHost.selectedPaths(svc)
        guard !paths.isEmpty else { return }
        progress.begin(String(localized: "Reading…", comment: "AI: direct action progress title"))
        var parts: [String] = []
        for (i, path) in paths.enumerated() {
            if progress.isCancelled { break }
            progress.update((path as NSString).lastPathComponent, done: i, total: paths.count)
            let text = await session.summarize(file: path)
            parts.append(paths.count == 1 ? text
                         : "\((path as NSString).lastPathComponent)\n\(text)")
        }
        progress.end()
        guard !parts.isEmpty else { return }
        AITextSheet.show(title: String(localized: "Summary", comment: "AI: summary sheet title"),
                         body: parts.joined(separator: "\n\n"), parent: progress.parentWindow)
    }

    // MARK: - Explain

    private func explain() async {
        let paths = AIHost.selectedPaths(svc)
        guard !paths.isEmpty else { return }
        progress.begin(String(localized: "Reading…", comment: "AI: direct action progress title"))
        var parts: [String] = []
        for (i, path) in paths.enumerated() {
            if progress.isCancelled { break }
            progress.update((path as NSString).lastPathComponent, done: i, total: paths.count)
            guard let text = try? await session.explain(file: path) else { continue }
            parts.append(paths.count == 1 ? text
                         : "\((path as NSString).lastPathComponent)\n\(text)")
        }
        progress.end()
        guard !parts.isEmpty else { return }
        AITextSheet.show(title: String(localized: "What this is",
                                       comment: "AI: explain sheet title"),
                         body: parts.joined(separator: "\n\n"), parent: progress.parentWindow)
    }

    // MARK: - Rename by content

    private func rename() async {
        let paths = AIHost.selectedPaths(svc)
        guard !paths.isEmpty, let directory = paths.first.map({ ($0 as NSString).deletingLastPathComponent })
        else { return }
        progress.begin(String(localized: "Proposing names…", comment: "AI: direct action progress title"))
        var proposals: [(old: String, new: String)] = []
        var reasons: [String: String] = [:]
        for (i, path) in paths.enumerated() {
            if progress.isCancelled { break }
            let old = (path as NSString).lastPathComponent
            progress.update(old, done: i, total: paths.count)
            guard let out = try? await session.suggestFileName(path: path) else { continue }
            proposals.append((old, out.newName))
            reasons[old] = out.reason
        }
        progress.end()
        guard !proposals.isEmpty else { return }

        let batch = DirectActionPlan.renameBatch(
            directory: directory, proposals: proposals,
            occupied: Set((try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []))
        guard !batch.isEmpty else {
            note(skippedMessage(batch.skipped) ?? String(localized: "No new names to apply.",
                                                          comment: "AI: nothing to rename"))
            return
        }
        let rows = zip(batch.oldNames, batch.newNames).map { old, new in
            AIProposalSheet.Row(id: old, text: "\(old)  →  \(new)",
                                detail: reasons[old] ?? "")
        }
        AIProposalSheet.ask(
            title: String(localized: "Rename by content", comment: "AI: rename sheet title"),
            message: skippedMessage(batch.skipped) ?? "",
            rows: rows,
            applyTitle: String(localized: "Rename", comment: "AI: apply renames"),
            parent: progress.parentWindow) { [weak self] kept in
                guard let self, !kept.isEmpty else { return }
                Task { @MainActor in await self.applyRenames(batch, keeping: Set(kept)) }
            }
    }

    private func applyRenames(_ batch: DirectActionPlan.RenameBatch, keeping: Set<String>) async {
        // Filtered here rather than through `confirm(token:rejecting:)`: the two lists are
        // positional, and the one place that knows how to keep them aligned is the type that
        // built them. Dropping a name from one list only renames the wrong file.
        var olds: [String] = [], news: [String] = []
        for (old, new) in zip(batch.oldNames, batch.newNames) where keeping.contains(old) {
            olds.append(old); news.append(new)
        }
        guard !olds.isEmpty else { return }
        let failure = await perform("rename_batch", ["old_names": olds, "new_names": news,
                                                     "directory": batch.directory])
        finish(failure, done: String(format: String(localized: "Renamed %lld file(s).",
                                                    comment: "AI: renames applied"), olds.count))
    }

    // MARK: - Comment / tags

    private func comment() async {
        let paths = AIHost.selectedPaths(svc)
        guard !paths.isEmpty else { return }
        progress.begin(String(localized: "Reading…", comment: "AI: direct action progress title"))
        var proposals: [(path: String, comment: String, tags: [String])] = []
        for (i, path) in paths.enumerated() {
            if progress.isCancelled { break }
            progress.update((path as NSString).lastPathComponent, done: i, total: paths.count)
            guard let out = try? await session.suggestComment(path: path) else { continue }
            proposals.append((path, out.comment, out.tags))
        }
        progress.end()
        guard !proposals.isEmpty else { return }

        let rows = proposals.map { p in
            AIProposalSheet.Row(id: p.path, text: (p.path as NSString).lastPathComponent,
                                detail: p.tags.isEmpty ? p.comment
                                    : p.comment + "   " + p.tags.map { "#" + $0 }.joined(separator: " "))
        }
        AIProposalSheet.ask(
            title: String(localized: "Suggested comments", comment: "AI: comment sheet title"),
            message: "", rows: rows,
            applyTitle: String(localized: "Set comments", comment: "AI: apply comments"),
            parent: progress.parentWindow) { [weak self] kept in
                guard let self, !kept.isEmpty else { return }
                let keep = Set(kept)
                let chosen = proposals.filter { keep.contains($0.path) }
                Task { @MainActor in await self.applyComments(chosen) }
            }
    }

    private func applyComments(_ proposals: [(path: String, comment: String, tags: [String])]) async {
        var failure: String?
        for p in proposals {
            // The set_comment TOOL, not services.setFileComment: the tool is audited and the
            // action shows up in "what the assistant did", which a direct write would not.
            if let why = await perform("set_comment", ["path": p.path, "comment": p.comment]) {
                failure = why; break
            }
            guard !p.tags.isEmpty else { continue }
            // Real Finder tags, not words glued onto the comment. They were being concatenated
            // into the comment text, where nothing could search or colour them — the app has
            // written the `_kMDItemUserTags` xattr, with colours, all along.
            //
            // The tags already there are read first and handed over, which is what makes tagging
            // forty files undoable in one step instead of forty manual corrections.
            let existing = await readTags(p.path)
            let merged = existing + p.tags.filter { new in
                !existing.contains { $0.caseInsensitiveCompare(new) == .orderedSame }
            }
            if let why = await perform("set_tags", ["path": p.path, "tags": merged,
                                                    "previous_tags": existing]) {
                failure = why; break
            }
        }
        finish(failure, done: String(format: String(localized: "Commented %lld file(s).",
                                                    comment: "AI: comments applied"), proposals.count))
    }

    // MARK: - Organise a folder

    /// How many files one tidy-up will look at. It costs a generation per file, so an unbounded
    /// run over a download folder is minutes of work nobody asked for. The cap is stated in the
    /// sheet rather than applied quietly.
    private static let organizeLimit = 60

    private func organize() async {
        guard let folder = AIHost.context(svc, "dir") else { return }
        var isDir: ObjCBool = false
        func organisable(_ name: String, in dir: String) -> Bool {
            guard DirectActionPlan.isOrganisable(name) else { return false }
            let full = (dir as NSString).appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: full, isDirectory: &isDir) else { return false }
            return !isDir.boolValue
        }
        // A marked selection means "these"; nothing marked means "this folder". `selectedPaths`
        // falls back to the cursor, which would have turned an unmarked folder into one file.
        let marked = AIHost.markedCount(svc) > 1
            ? AIHost.selectedPaths(svc).map { ($0 as NSString).lastPathComponent }
                .filter { organisable($0, in: folder) }.sorted()
            : []
        let files = marked.isEmpty
            ? ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [])
                .filter { organisable($0, in: folder) }.sorted()
            : marked
        guard files.count > 1 else { return }
        let considered = Array(files.prefix(Self.organizeLimit))

        progress.begin(String(localized: "Sorting…", comment: "AI: direct action progress title"))
        // Categories first, once, over every name — see `proposeFolders`. Sorting file by file
        // with a growing list produced one folder named after the first file, and everything in it.
        guard let folders = try? await session.proposeFolders(forNames: considered),
              !folders.isEmpty else {
            progress.end()
            note(String(localized: "Nothing here groups into folders.",
                        comment: "AI: organise found no groups"))
            return
        }
        var assignments: [DirectActionPlan.Assignment] = []
        for (i, name) in considered.enumerated() {
            if progress.isCancelled { break }
            progress.update(name, done: i, total: considered.count)
            let full = (folder as NSString).appendingPathComponent(name)
            guard let out = try? await session.assignFolder(forFile: full, among: folders),
                  !out.subfolder.isEmpty else { continue }
            assignments.append(.init(path: full, subfolder: out.subfolder, reason: out.reason))
        }
        progress.end()

        let groups = DirectActionPlan.groupsWorthMaking(DirectActionPlan.group(assignments))
        guard !groups.isEmpty else {
            note(String(localized: "Nothing here groups into folders.",
                        comment: "AI: organise found no groups"))
            return
        }
        var rows: [AIProposalSheet.Row] = []
        for g in groups {
            for source in g.sources {
                rows.append(.init(id: source,
                                  text: "\((source as NSString).lastPathComponent)  →  \(g.subfolder)/",
                                  detail: ""))
            }
        }
        let capped = files.count > considered.count
            ? String(format: String(localized: "Looked at the first %1$lld of %2$lld files.",
                                    comment: "AI: organise cap"), considered.count, files.count)
            : ""
        AIProposalSheet.ask(
            title: String(localized: "Organize this folder", comment: "AI: organise sheet title"),
            message: capped, rows: rows,
            applyTitle: String(localized: "Move", comment: "AI: apply organise"),
            parent: progress.parentWindow) { [weak self] kept in
                guard let self, !kept.isEmpty else { return }
                Task { @MainActor in await self.applyOrganize(groups, folder: folder, keeping: Set(kept)) }
            }
    }

    private func applyOrganize(_ groups: [DirectActionPlan.Group], folder: String,
                               keeping: Set<String>) async {
        var moved = 0
        var failure: String?
        for g in groups {
            let sources = g.sources.filter { keeping.contains($0) }
            guard !sources.isEmpty else { continue }
            let destination = (folder as NSString).appendingPathComponent(g.subfolder)
            if let why = await perform("make_directory", ["path": destination]) { failure = why; break }
            if let why = await perform("move", ["sources": sources, "destination": destination]) {
                failure = why; break
            }
            moved += sources.count
        }
        finish(failure, done: String(format: String(localized: "Moved %lld file(s).",
                                                    comment: "AI: organise applied"), moved))
    }

    // MARK: - Make a table

    /// Pull a table out of the file under the cursor.
    ///
    /// One file, not a selection: a table is a shape a single document has. And one slice of it —
    /// the window holds a few dozen rows, not a database export — so when the file is longer than
    /// that the sheet says which part it read rather than letting the reader assume it saw all of it.
    private func makeTable() async {
        guard let path = AIHost.cursorPath(svc) else { return }
        progress.begin(String(localized: "Reading…", comment: "AI: direct action progress title"))
        let result = try? await session.tabulate(file: path)
        progress.end()
        guard let result, !result.table.isEmpty else {
            note(String(localized: "No table could be read out of this file.",
                        comment: "AI: tabulate found nothing"))
            return
        }
        let markdown = DirectActionPlan.markdown(result.table)
        let head = result.truncated
            ? String(format: String(localized: "From the first %lld bytes of the file — more remains.",
                                    comment: "AI: the table covers only the beginning"),
                     Int64(AppleNativeToolSession.readSliceBytes)) + "\n\n"
            : ""
        let destination = ((path as NSString).deletingPathExtension) + ".csv"
        AITextSheet.show(
            title: String(localized: "Table", comment: "AI: table sheet title"),
            body: head + markdown, parent: progress.parentWindow,
            extra: (title: String(localized: "Save as CSV…", comment: "AI: save the table"),
                    action: { [weak self] in
                        guard let self else { return }
                        let csv = DirectActionPlan.csv(result.table)
                        Task { @MainActor in await self.saveTable(csv, to: destination) }
                    }))
    }

    private func saveTable(_ csv: String, to destination: String) async {
        // Through write_file, so the reader is shown what is about to be written where and it
        // lands in the action log like every other change.
        let failure = await perform("write_file", ["path": destination, "content": csv])
        finish(failure, done: String(format: String(localized: "Saved %@.",
                                                    comment: "AI: the table was written"),
                                     (destination as NSString).lastPathComponent))
    }

    // MARK: - Classify

    /// Work out what each file IS, what it is about and what date it carries — and keep the answer.
    ///
    /// Changes nothing on disk. What it produces goes into the fact cache, which three things read:
    /// the panel's AI Kind / AI Topic / AI Date columns, and — the reason this action is worth its
    /// generations — the multi-rename mask, where `[=ai_column.ai_topic]-[Y]-[M].[E]` becomes a
    /// rename by what the files are, through the app's existing rename engine.
    ///
    /// The categories are chosen once over the whole selection and then handed to each file, for
    /// the reason folders are: a category only means something relative to a set, and a model asked
    /// per file invents a fresh one every time.
    private func classify() async {
        let paths = AIHost.selectedPaths(svc)
        guard !paths.isEmpty else { return }
        progress.begin(String(localized: "Sorting…", comment: "AI: direct action progress title"))
        // Topic and date first, from each file's own contents. The categories come afterwards,
        // from those topics — asked over file names like "dokument1.txt" the only honest category
        // is "Dokument", and every file gets it.
        var found: [(path: String, facts: AIFileFacts)] = []
        for (i, path) in paths.enumerated() {
            if progress.isCancelled { break }
            progress.update((path as NSString).lastPathComponent, done: i, total: paths.count)
            guard let f = try? await session.facts(forFile: path, among: []), !f.isEmpty else { continue }
            found.append((path, f))
        }
        let kinds = (try? await session.groupTopics(found.map(\.facts.topic))) ?? [:]

        var lines: [String] = []
        var written = 0
        for (path, base) in found {
            // The category came back with the topic it belongs to, so this is a lookup rather
            // than a second question for the model.
            var f = base
            f.kind = kinds[base.topic] ?? ""
            if let stamp = FileFactStore.fingerprint(forFileAt: path) {
                facts.save(f, for: stamp, path: path)
                written += 1
            }
            let parts = [f.kind, f.topic, f.date].filter { !$0.isEmpty }
            lines.append("\((path as NSString).lastPathComponent)\n    \(parts.joined(separator: "  ·  "))")
        }
        progress.end()
        guard written > 0 else {
            note(String(localized: "Nothing could be worked out about these files.",
                        comment: "AI: classify produced nothing"))
            return
        }
        // The columns exist but a reader has to add them once, like any other content column —
        // saying so here is the difference between a feature and a puzzle.
        let hint = String(localized: "Add the AI Kind, AI Topic or AI Date column to see these in the panel, or use [=ai_column.ai_topic] in a multi-rename mask.",
                          comment: "AI: where the classified facts show up")
        AITextSheet.show(title: String(localized: "Classified", comment: "AI: classify sheet title"),
                         body: lines.joined(separator: "\n\n") + "\n\n" + hint,
                         parent: progress.parentWindow)
    }

    // MARK: - Find by meaning

    /// Rank this folder by how close each file is to a phrase.
    ///
    /// No language model is involved: the Automation Core scores names and file openings with
    /// on-device sentence embeddings, falling back to word overlap for a language Apple has no
    /// embedding for. That makes this the one AI action that answers instantly and cannot make
    /// something up — which is also why it belongs in this plugin rather than in a chat, where it
    /// spent its whole existence as a tool nothing could reach.
    private func findByMeaning() async {
        guard let folder = AIHost.context(svc, "dir") else { return }
        AIAskSheet.ask(
            title: String(localized: "Find by meaning", comment: "AI: semantic search title"),
            message: String(localized: "Files in this folder are ranked by how close they are to what you describe. Nothing leaves your Mac.",
                            comment: "AI: semantic search explanation"),
            placeholder: String(localized: "for example: the invoice about the roof",
                                comment: "AI: semantic search placeholder"),
            actionTitle: String(localized: "Search", comment: "AI: run the semantic search"),
            parent: progress.parentWindow) { [weak self] phrase in
                guard let self else { return }
                Task { @MainActor in await self.runSearch(phrase, in: folder) }
            }
    }

    private func runSearch(_ phrase: String, in folder: String) async {
        let data = try? JSONSerialization.data(withJSONObject: ["query": phrase, "path": folder,
                                                                "limit": 15])
        guard let outcome = try? await core.invoke(tool: "semantic_search", arguments: data,
                                                   policy: .standard),
              case .ok(let payload) = outcome, let payload,
              let hits = try? JSONDecoder().decode([AutomationEntry].self, from: payload),
              !hits.isEmpty else {
            note(String(localized: "Nothing here comes close to that.",
                        comment: "AI: semantic search found nothing"))
            return
        }
        AIPickSheet.pick(
            title: String(localized: "Closest matches", comment: "AI: semantic search results"),
            message: phrase, items: hits.map(\.name),
            actionTitle: String(localized: "Show in panel", comment: "AI: reveal a search hit"),
            parent: progress.parentWindow) { [weak self] index in
                guard let self, hits.indices.contains(index), let open = self.svc.openPath else { return }
                hits[index].path.withCString { open(self.svc.host, $0) }
            }
    }

    // MARK: - Talking to the core

    /// The Finder tags a file already has, or none when it cannot be asked.
    private func readTags(_ path: String) async -> [String] {
        let data = try? JSONSerialization.data(withJSONObject: ["path": path])
        guard let outcome = try? await core.invoke(tool: "get_tags", arguments: data, policy: .standard),
              case .ok(let payload) = outcome, let payload,
              let o = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let tags = o["tags"] as? [String] else { return [] }
        return tags
    }

    /// Run one tool and answer the host's gate for it. Returns nil on success, else why not.
    ///
    /// Auto-confirming is not a way around plan-then-confirm: the reader approved this exact list
    /// in the sheet a moment ago, and the host still decides whether the action is permitted at
    /// all — a read-only autonomy setting comes back `.refused` here and is reported, not applied.
    private func perform(_ tool: String, _ arguments: [String: Any]) async -> String? {
        let data = try? JSONSerialization.data(withJSONObject: arguments)
        do {
            switch try await core.invoke(tool: tool, arguments: data, policy: .standard) {
            case .ok:
                return nil
            case .refused(let why):
                return why
            case .failed(let error):
                return error
            case .needsConfirmation(_, let token):
                switch try await core.confirm(token: token) {
                case .failed(let error): return error
                case .refused(let why):  return why
                default:                 return nil
                }
            }
        } catch {
            return "\(error)"
        }
    }

    /// Report the outcome and let the panel catch up with what changed.
    private func finish(_ failure: String?, done: String) {
        if let failure { note(failure) } else { note(done) }
        svc.reloadActivePanel?(svc.host)
    }

    private func note(_ text: String) {
        // The host's own alert is modal too, so a probe run records it rather than raising it.
        if AISheetProbe.dumpPath != nil { AISheetProbe.record(["NOTE", text]); return }
        guard let fn = svc.presentInfo else { return }
        String(localized: "AI", comment: "AI: info title").withCString { t in
            text.withCString { m in fn(svc.host, t, m) }
        }
    }

    /// One line naming what was left out, or nil when nothing was.
    private func skippedMessage(_ skipped: [DirectActionPlan.Skipped]) -> String? {
        guard !skipped.isEmpty else { return nil }
        let unchanged = skipped.filter { $0.reason == .unchanged }.count
        let clashing = skipped.count - unchanged
        var parts: [String] = []
        if unchanged > 0 {
            parts.append(String(format: String(localized: "%lld already had a good name.",
                                               comment: "AI: renames skipped as unchanged"), unchanged))
        }
        if clashing > 0 {
            parts.append(String(format: String(localized: "%lld would have collided and were left out.",
                                               comment: "AI: renames skipped as colliding"), clashing))
        }
        return parts.joined(separator: " ")
    }
}

#endif
