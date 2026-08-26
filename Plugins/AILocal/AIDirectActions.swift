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
    case summarize, explain, rename, comment, organize

    /// The command ids these take over from the chat.
    static func forCommand(_ id: String) -> AIDirectAction? {
        switch id {
        case "plugin.ai.skill.summarize":        return .summarize
        case "plugin.ai.skill.explain":          return .explain
        case "plugin.ai.skill.suggest-rename":   return .rename
        case "plugin.ai.skill.suggest-comment":  return .comment
        case "plugin.ai.folderskill.organize":   return .organize
        default:                                 return nil
        }
    }
}

enum AIDirect {

    /// Take `id` if it is a direct action and the on-device model is the one in use.
    ///
    /// A configured cloud model keeps the old behaviour: these actions are shaped around a 4096
    /// token window, and a model that does not have that limit is better served by the chat, which
    /// can follow up. Returns true when it handled the command.
    static func handle(_ id: String, _ svc: PcHostServices) -> Bool {
        guard let action = AIDirectAction.forCommand(id), isOnDevice(svc) else { return false }
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            Task { @MainActor in await DirectActionRunner(svc).run(action) }
            return true
        }
        #endif
        return false
    }

    /// Is the on-device model the one this chat would use? Mirrors `AIPlugin.pickProvider`'s
    /// decision without building a provider: preference "cloud" (or "auto" with an endpoint
    /// configured) means cloud, and everything else means on-device if it is actually there.
    private static func isOnDevice(_ svc: PcHostServices) -> Bool {
        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { return false }
        let root = AIHost.configRoot(svc)
        let preference = AIPluginConfig.load(root: root).modelPreference
        let base = ProcessInfo.processInfo.environment["PEACHCMD_AI_BASE"]
            ?? AIHost.context(svc, "AI.CloudBaseURL")
        let cloudConfigured = (base?.isEmpty == false)
        if preference == "cloud" || (preference == "auto" && cloudConfigured) { return false }
        return SystemLanguageModel.default.availability == .available
        #else
        return false
        #endif
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

    init(_ svc: PcHostServices) {
        self.svc = svc
        let core = RemoteAutomationCore(services: svc)
        self.core = core
        let root = AIHost.configRoot(svc)
        // The same store the panel's AI Summary column reads. Until now only a chat turn ever
        // wrote it, which is why that column was empty for anyone who never chatted.
        let summaries = SummaryStore(url: URL(fileURLWithPath: root)
            .appendingPathComponent("aichat/summaries.json"))
        self.session = AppleNativeToolSession(directActionsOn: core, policy: .standard,
                                              summaryStore: summaries)
        self.progress = AIProgressSheet(parent: AIHost.parentWindow(svc))
    }

    func run(_ action: AIDirectAction) async {
        switch action {
        case .summarize, .explain: await summarize()
        case .rename:              await rename()
        case .comment:             await comment()
        case .organize:            await organize()
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
        var proposals: [(path: String, comment: String)] = []
        for (i, path) in paths.enumerated() {
            if progress.isCancelled { break }
            progress.update((path as NSString).lastPathComponent, done: i, total: paths.count)
            guard let out = try? await session.suggestComment(path: path) else { continue }
            let tags = out.tags.isEmpty ? "" : "  [\(out.tags.joined(separator: ", "))]"
            proposals.append((path, out.comment + tags))
        }
        progress.end()
        guard !proposals.isEmpty else { return }

        let rows = proposals.map {
            AIProposalSheet.Row(id: $0.path, text: ($0.path as NSString).lastPathComponent,
                                detail: $0.comment)
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

    private func applyComments(_ proposals: [(path: String, comment: String)]) async {
        var failure: String?
        for p in proposals {
            // The set_comment TOOL, not services.setFileComment: the tool is audited and the
            // action shows up in "what the assistant did", which a direct write would not.
            if let why = await perform("set_comment", ["path": p.path, "comment": p.comment]) {
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
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [])
            .filter { name in
                guard DirectActionPlan.isOrganisable(name) else { return false }
                let full = (folder as NSString).appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: full, isDirectory: &isDir) else { return false }
                return !isDir.boolValue
            }
            .sorted()
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

    // MARK: - Talking to the core

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
