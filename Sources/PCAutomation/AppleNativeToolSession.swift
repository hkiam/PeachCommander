// SPDX-License-Identifier: Apache-2.0
// AppleNativeToolSession.swift - native FoundationModels tool-calling for the on-device
// Apple model, replacing the fragile text convention for that provider.
//
// The on-device model is small: with the text convention it emits malformed calls
// (`search(query: …)`) and fabricates conversation turns. Native tool-calling uses
// guided generation (constrained decoding), so the model's tool choice and arguments
// are ALWAYS structurally valid, and FoundationModels drives the tool loop internally.
//
// We keep the safety model: every native tool routes through the same AutomationCore,
// so PermissionPolicy still gates writes/deletes and plan-then-confirm still applies —
// a gated tool suspends inside its `call`, asks the ConfirmationBroker (the UI), and
// only proceeds after the user confirms. Reads run immediately.
//
// macOS 26 + Apple Intelligence only; everything is availability- and canImport-gated,
// so older systems and non-Apple providers are unaffected (they use ToolCallProtocol).

import Foundation
import OSLog

/// Asked mid-turn to confirm a gated plan (write/delete/config). Returns the user's
/// decision. Implemented by the UI; a headless caller may auto-decide.
public protocol ConfirmationBroker: Sendable {
    func confirmPlan(_ plan: String) async -> Bool
}

#if canImport(FoundationModels)
import FoundationModels
import NaturalLanguage

/// Shared execution context for the native tools: runs a tool through the core under
/// the current policy, resolving plan-then-confirm via the broker. A reference type so
/// the policy can be updated between turns while the tool instances stay fixed.
@available(macOS 26, *)
final class NativeToolContext: @unchecked Sendable {
    let core: AutomationCore
    var policy: PermissionPolicy
    let broker: ConfirmationBroker?
    let onProgress: (@Sendable (String) async -> Void)?
    /// Where folded summaries are kept between runs, so the panel's AI column can show what
    /// the assistant has already worked out about a file. Nil = keep them for this run only.
    let summaryStore: SummaryStore?

    init(core: AutomationCore, policy: PermissionPolicy,
         broker: ConfirmationBroker?, onProgress: (@Sendable (String) async -> Void)?,
         summaryStore: SummaryStore? = nil) {
        self.core = core; self.policy = policy; self.broker = broker; self.onProgress = onProgress
        self.summaryStore = summaryStore
    }

    /// Bytes of file text the on-device model can take in one turn.
    ///
    /// Measured against the real model on macOS 26.4: a 4 KB slice is summarised correctly,
    /// 8 KB throws `exceededContextWindowSize`. The Automation Core's own default is 64 KB,
    /// which is right for a cloud model and 16× too much for this one — so the budget lives
    /// with the provider that has the window, not in the shared core.
    static let readBudget = 4096

    /// Execute tool `name` and return the result with the notes the *model* needs to read it
    /// correctly. Use `runRaw` from Swift: the notes are prose appended to a JSON payload, so
    /// they are help for a reader and noise for a parser.
    func run(_ name: String, _ args: [String: Any]) async -> String {
        let payload = await runRaw(name, args)
        // Nudge the small model to chain search/list → read_file for CONTENTS (it otherwise
        // answers from names alone or fabricates).
        if name == "search" || name == "list_directory" {
            return payload + "\n\n[Note: this lists file names/paths only, NOT their "
                + "contents. To read what is inside a file, call read_file with its path.]"
        }
        // A slice must not be mistaken for the file. Saying so in the result is what stops the
        // model summarising the first 4 KB of a report as the report.
        if name == "read_file", Self.readWasTruncated(payload) {
            return payload + "\n\n[Note: this is only the beginning of the file — more "
                + "remains. Do NOT describe this as the whole file. To cover all of it, "
                + "call summarize_file with the same path.]"
        }
        return payload
    }

    /// Execute tool `name` with JSON `args`, returning the payload verbatim.
    /// Gated tools wait for the broker; a decline is reported back to the model.
    func runRaw(_ name: String, _ args: [String: Any]) async -> String {
        #if DEBUG
        // With the arguments: "the model called search" and "the model called search with the
        // user's subject in the file-name mask" look the same without them, and only the second
        // one explains the answer the user got.
        NSLog("[native] tool: %@ %@", name, Self.debugArguments(args))
        #endif
        await onProgress?(name)
        let json = (try? JSONSerialization.data(withJSONObject: args)) ?? Data("{}".utf8)
        do {
            let outcome = try await core.invoke(tool: name, arguments: json, policy: policy)
            switch outcome {
            case .ok(let payload):
                return payload.flatMap { String(data: $0, encoding: .utf8) } ?? "OK"
            case .refused(let reason):
                return "Refused: \(reason)"
            case .failed(let error):
                return "Failed: \(error)"
            case .needsConfirmation(let plan, let token):
                guard await (broker?.confirmPlan(plan) ?? false) else {
                    return "The user declined this action. Do NOT attempt any other or "
                        + "alternative action; simply acknowledge that you will not make "
                        + "changes, and stop."
                }
                let done = try await core.confirm(token: token)
                if case .ok(let p) = done { return p.flatMap { String(data: $0, encoding: .utf8) } ?? "Done." }
                if case .failed(let e) = done { return "Failed: \(e)" }
                return "Done."
            }
        } catch {
            return "Failed: \(error)"
        }
    }

    #if DEBUG
    static func debugArguments(_ args: [String: Any]) -> String {
        args.keys.sorted().map { key in
            let value = "\(args[key] ?? "")"
            return "\(key)=\(value.count > 200 ? String(value.prefix(200)) + "…" : value)"
        }.joined(separator: " ")
    }
    #endif

    /// Did a `read_file` result stop short of the end of the file?
    static func readWasTruncated(_ payload: String) -> Bool {
        guard let d = payload.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return false }
        return (o["truncated"] as? Bool) ?? false
    }

    /// The text of a `read_file` result (the payload is JSON), or the raw string.
    static func readContent(_ payload: String) -> String {
        guard let d = payload.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let c = o["content"] as? String else { return payload }
        return c
    }

    /// Folded summaries from this session, keyed by path and modification time. The small
    /// model calls a tool twice as readily as once, and this one costs a generation per 4 KB —
    /// so the second call answers from the first instead of re-reading the file.
    private var summaries: [String: String] = [:]

    /// Read a whole file in `readBudget`-sized slices and fold the slice summaries into one.
    /// Each generation gets its own tool-less session and sees a single slice, so the context
    /// window is never the limit — the file length only costs time.
    func summarizeWholeFile(path: String, sliceLimit: Int = 24) async -> String {
        await onProgress?(Self.progressName)
        let stamp = await Self.fingerprint(of: path, via: self)
        if let cached = summaries[stamp] { return cached }
        // A summary made in an earlier session is still a summary of this file.
        if let stored = summaryStore?.summary(for: stamp) {
            summaries[stamp] = stored
            return stored
        }
        var offset = 0
        var partials: [String] = []
        // The language of the file, named rather than described. Measured: asking for "the same
        // language as the text" gave an English summary of a German file 4 times out of 4 (and one
        // empty answer); naming the language is what this model follows.
        var language: String?
        while partials.count < sliceLimit {
            let payload = await runRaw("read_file", ["path": path, "offset": offset,
                                                     "max_bytes": Self.readBudget])
            if payload.hasPrefix("Failed:") || payload.hasPrefix("Refused:") {
                return partials.isEmpty ? payload : partials.joined(separator: "\n")
            }
            let slice = Self.readContent(payload)
            let bytes = slice.utf8.count
            if bytes == 0 { break }
            offset += bytes
            // Per slice, not once at the start. A long file takes a generation per slice, and the
            // chat's watchdog is there to catch a model that is stuck — it has to be able to tell
            // that apart from one that is working, and this is what tells it.
            await onProgress?("\(Self.progressName):\(partials.count + 1)/\(Self.sliceEstimate(payload))")
            if language == nil { language = Self.languageName(of: slice) }
            let label = partials.isEmpty ? "beginning" : "continuation"
            let summary = await Self.generate(
                "Summarise the following \(label) of a file in two or three sentences. "
                + "Report only what it says.\(Self.languageClause(language))\n\n\(slice)")
            partials.append(summary)
            if !Self.readWasTruncated(payload) { break }
        }
        guard !partials.isEmpty else { return "The file is empty." }
        let folded = await fold(partials, language: language)
        summaries[stamp] = folded
        summaryStore?.save(folded, for: stamp, path: path)
        return folded
    }

    /// Fold section summaries into one, in as many rounds as it takes.
    ///
    /// This used to be a single generation over every partial, with a comment asserting that "the
    /// section summaries are short, so they fit in one window together". That is an assumption, and
    /// the model decides how long a "two or three sentence" summary is. A ten-slice file produced a
    /// fold prompt the model reported as 4100 tokens against a limit of 4096 — so the feature whose
    /// whole point is that length costs time rather than failing, failed on length after all, at the
    /// last step. Measured, and nondeterministically: the same file and the same code passed three
    /// runs and failed the fourth.
    ///
    /// Folding in rounds bounds every prompt. The result of a round is itself foldable, so the tree
    /// closes however many sections there were.
    private func fold(_ partials: [String], language: String?) async -> String {
        var level = partials
        while level.count > 1 {
            let groups = Self.foldGroups(level, budget: Self.foldBudget)
            // Nothing left to combine — every partial is over budget on its own. Fold them together
            // anyway rather than looping: an over-long prompt may still be answered, and dropping a
            // section to stay under a budget would silently summarise the wrong file.
            if groups.count >= level.count { break }
            var next: [String] = []
            for group in groups {
                next.append(group.count == 1 ? group[0]
                            : await Self.generate(Self.foldPrompt(group, language: language)))
            }
            level = next
        }
        guard level.count > 1 else { return level.first ?? "The file is empty." }
        return await Self.generate(Self.foldPrompt(level, language: language))
    }

    /// How much folded text one generation may see, in bytes.
    ///
    /// Smaller than `readBudget` on purpose: the fold prompt carries its instructions *and* every
    /// partial it is given, and the window counts tokens while this counts bytes — so the headroom
    /// has to cover both the overhead and the conversion.
    static let foldBudget = 2048

    /// Group `partials` in order so each group stays under `budget`, keeping neighbours together.
    ///
    /// In order and adjacent, because the sections are consecutive parts of one file: folding
    /// section 1 with section 9 would produce a summary that reads as though the middle were missing.
    /// A partial longer than the budget on its own becomes its own group — refusing it would mean
    /// dropping a section, which is worse than one long prompt.
    static func foldGroups(_ partials: [String], budget: Int) -> [[String]] {
        var groups: [[String]] = []
        var current: [String] = []
        var size = 0
        for partial in partials {
            let cost = partial.utf8.count
            if !current.isEmpty, size + cost > budget {
                groups.append(current)
                current = []
                size = 0
            }
            current.append(partial)
            size += cost
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }

    /// The fold instruction.
    ///
    /// "the same language as the summaries", not "the user's language": measured, a German file
    /// summarised through English fold prompts came back in English 4 times out of 4, because the
    /// model relays the language it was handed. The slices are in the file's language, so this
    /// carries it through.
    static func foldPrompt(_ partials: [String], language: String?) -> String {
        "These are summaries of consecutive sections of one file. Combine them into a "
        + "single coherent summary of the whole file. Do not mention sections or "
        + "summaries.\(languageClause(language))\n\n"
        + partials.enumerated().map { "Section \($0.offset + 1): \($0.element)" }
            .joined(separator: "\n\n")
    }

    /// The English name of the dominant language of `text`, or nil when it cannot be told.
    static func languageName(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(1000)))
        guard let code = recognizer.dominantLanguage else { return nil }
        return Locale(identifier: "en").localizedString(forIdentifier: code.rawValue)
    }

    /// " Write in German." — an instruction naming the language, or nothing when unknown.
    static func languageClause(_ language: String?) -> String {
        guard let language else { return "" }
        return " Write in \(language)."
    }

    /// The activity name the folding reports. `<name>:<n>/<m>` counts the slices.
    static let progressName = "summarize_file"

    /// How many slices this file will take, from what the first read reported about its size.
    static func sliceEstimate(_ payload: String) -> Int {
        guard let d = payload.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let total = o["total_bytes"] as? Int, total > 0 else { return 1 }
        return max(1, Int((Double(total) / Double(readBudget)).rounded(.up)))
    }

    /// Path plus size and modification time: enough to notice the file changed under us.
    private static func fingerprint(of path: String, via ctx: NativeToolContext) async -> String {
        let payload = await ctx.runRaw("stat_path", ["path": path])
        guard let d = payload.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return path }
        let size = (o["size"] as? NSNumber)?.stringValue ?? "?"
        let modified = (o["modified"] as? NSNumber)?.stringValue ?? "?"
        return "\(path)|\(size)|\(modified)"
    }

    /// Fold a conversation down to a few sentences, for when the context window fills.
    static func summarize(conversation: String) async -> String {
        let slice = String(conversation.suffix(6000))   // the recent part is what matters
        let out = await generate(
            "Summarise this conversation between a user and a file-manager assistant in at most "
            + "four sentences: what the user wants, what has been established, what is still "
            + "open. Keep file names and paths that were agreed on, and write in the SAME "
            + "LANGUAGE the user is speaking.\n\n" + slice)
        return out.hasPrefix("(this section") ? "" : out
    }

    /// One short generation with no tools and no history — the unit the folding is built from.
    static func generate(_ prompt: String) async -> String {
        let session = LanguageModelSession(
            instructions: "You summarise text faithfully and briefly, always in the same language "
                + "as the text you are given.")
        do { return try await session.respond(to: prompt).content }
        catch { return "(this section could not be summarised: \(error))" }
    }
}

/// Build a JSON dict, dropping empty-string values so optional args are simply omitted.
@available(macOS 26, *)
private func ntArgs(_ pairs: [String: Any]) -> [String: Any] {
    pairs.filter { !(($0.value as? String)?.isEmpty ?? false) }
}

// MARK: - Native tool definitions (one per catalogue entry)

@available(macOS 26, *)
struct NTGetContext: Tool {
    let ctx: NativeToolContext
    var name: String { "get_context" }
    var description: String { "Get the current UI context: active folder, selection, cursor, tabs and view." }
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String { await ctx.run("get_context", [:]) }
}

@available(macOS 26, *)
struct NTListDirectory: Tool {
    let ctx: NativeToolContext
    var name: String { "list_directory" }
    var description: String { "List the entries of a folder." }
    @Generable struct Arguments {
        @Guide(description: "Absolute path or VFS path to list") var path: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("list_directory", ["path": a.path])
    }
}

@available(macOS 26, *)
struct NTStatPath: Tool {
    let ctx: NativeToolContext
    var name: String { "stat_path" }
    var description: String { "Get metadata (size, kind, dates) for a path." }
    @Generable struct Arguments {
        @Guide(description: "Path to inspect") var path: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("stat_path", ["path": a.path]) }
}

@available(macOS 26, *)
struct NTReadFile: Tool {
    let ctx: NativeToolContext
    var name: String { "read_file" }
    var description: String {
        "Read text from a file, starting at a byte offset. Returns at most "
        + "\(NativeToolContext.readBudget) bytes per call; the result says whether more remains. "
        + "For a whole long file, call summarize_file instead of reading it in slices."
    }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file to read") var path: String
        @Guide(description: "Byte offset to start at; 0 for the beginning") var offset: Int
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("read_file", ["path": a.path, "offset": max(0, a.offset),
                                    "max_bytes": NativeToolContext.readBudget])
    }
}

@available(macOS 26, *)
struct NTHashFile: Tool {
    let ctx: NativeToolContext
    var name: String { "hash_file" }
    var description: String { "Compute the SHA-256 hash of a file's bytes." }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file to hash") var path: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("hash_file", ["path": a.path]) }
}

@available(macOS 26, *)
struct NTWriteFile: Tool {
    let ctx: NativeToolContext
    var name: String { "write_file" }
    var description: String { "Create or overwrite a text file with the given content." }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file to write") var path: String
        @Guide(description: "The full text content to write into the file") var content: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("write_file", ["path": a.path, "content": a.content])
    }
}

@available(macOS 26, *)
struct NTGetComment: Tool {
    let ctx: NativeToolContext
    var name: String { "get_comment" }
    var description: String { "Read the comment attached to a file or folder. Empty when it has none." }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file or folder") var path: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("get_comment", ["path": a.path]) }
}

@available(macOS 26, *)
struct NTSetComment: Tool {
    let ctx: NativeToolContext
    var name: String { "set_comment" }
    var description: String {
        "Attach a short comment to a file or folder describing what it is for, or clear it with an "
        + "empty string. Use this when the user asks you to note, label, annotate or describe a file. "
        + "The comment is stored beside the file and shown in the panel's Comment column."
    }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file or folder") var path: String
        @Guide(description: "The comment text; empty removes the comment") var comment: String
    }
    func call(arguments a: Arguments) async throws -> String {
        // Not ntArgs: an empty comment is how a comment is *removed*, and dropping empty strings
        // would turn "clear this" into a call with no comment argument at all.
        await ctx.run("set_comment", ["path": a.path, "comment": a.comment])
    }
}

@available(macOS 26, *)
struct NTMergeFiles: Tool {
    let ctx: NativeToolContext
    var name: String { "merge_files" }
    var description: String {
        "Combine/merge/concatenate the currently selected files (e.g. CSV files) into one "
        + "new file. Use this for any 'merge/combine the selected files into a new file' "
        + "request. It operates on the current selection, so you ONLY provide the "
        + "destination file name — do not read the files yourself."
    }
    @Generable struct Arguments {
        @Guide(description: "Name of the new merged file, e.g. combined.csv") var destination: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("merge_files", ["destination": a.destination])
    }
}

@available(macOS 26, *)
struct NTSearch: Tool {
    let ctx: NativeToolContext
    var name: String { "search" }
    var description: String {
        // The mask is a *file name* pattern. Left to itself the small model puts the user's
        // subject in it — "which file is about the roof repair" became mask=*dachreparatur*,
        // which matches nothing and gets reported as "there is no such file".
        "Find files by a NAME pattern, or by exact words occurring inside them. The mask matches "
        + "file names only: to search by content, put the words in `text` and leave `mask` as *. "
        + "For 'which file is about X', prefer semantic_search."
    }
    @Generable struct Arguments {
        @Guide(description: "Filename wildcard mask; use * unless the user named a name pattern") var mask: String
        @Guide(description: "Words to find INSIDE the files; empty for none") var text: String
        @Guide(description: "Absolute folder to search in; empty for the active folder") var path: String
    }
    func call(arguments a: Arguments) async throws -> String {
        var mask = a.mask.trimmingCharacters(in: .whitespaces)
        var text = a.text.trimmingCharacters(in: .whitespaces)
        // Measured against the real model, asked "which file is about the roof repair": it calls
        // search with mask="Dachreparatur" — the subject where the file-name pattern goes —
        // sometimes with the same word in `text` as well. Either way the name pattern matches
        // nothing, and the honest answer to that ("no file has that name") is useless to the
        // user. A mask that is a bare word rather than a pattern is read as what is being looked
        // for; a mask with a wildcard or an extension is left alone, because that is a caller
        // who means it. The description tells the model the right shape; this makes the wrong
        // shape work anyway.
        if Self.isBareWord(mask) {
            if text.isEmpty { text = mask }
            mask = "*"
        }
        return await ctx.run("search", ["query": ntArgs(["mask": mask, "text": text, "path": a.path])])
    }

    /// A word, not a file-name pattern: no wildcard and no extension.
    static func isBareWord(_ mask: String) -> Bool {
        guard !mask.isEmpty, mask != "*" else { return false }
        return !mask.contains("*") && !mask.contains("?") && !mask.contains(".") && !mask.contains("/")
    }
}

@available(macOS 26, *)
struct NTGetConfig: Tool {
    let ctx: NativeToolContext
    var name: String { "get_config" }
    var description: String { "Read a configuration value by its Section.Key." }
    @Generable struct Arguments {
        @Guide(description: "Config key, e.g. Display.NaturalSort") var key: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("get_config", ["key": a.key]) }
}

@available(macOS 26, *)
struct NTListCommands: Tool {
    let ctx: NativeToolContext
    var name: String { "list_commands" }
    var description: String { "List the available commands (id, name, category)." }
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String { await ctx.run("list_commands", [:]) }
}

@available(macOS 26, *)
struct NTListPlugins: Tool {
    let ctx: NativeToolContext
    var name: String { "list_plugins" }
    var description: String { "List enabled plugins and their contributed commands." }
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String { await ctx.run("list_plugins", [:]) }
}

@available(macOS 26, *)
struct NTOpenPath: Tool {
    let ctx: NativeToolContext
    var name: String { "open_path" }
    var description: String { "Open a folder (or reveal a file) in the active panel." }
    @Generable struct Arguments {
        @Guide(description: "Path to open") var path: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("open_path", ["path": a.path]) }
}

@available(macOS 26, *)
struct NTOpenInPanel: Tool {
    let ctx: NativeToolContext
    var name: String { "open_in_panel" }
    var description: String { "Open a path in a specific panel or a new tab." }
    @Generable struct Arguments {
        @Guide(description: "Path to open") var path: String
        @Guide(description: "left, right, or new-tab") var side: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("open_in_panel", ["path": a.path, "side": a.side])
    }
}

@available(macOS 26, *)
struct NTSetSelection: Tool {
    let ctx: NativeToolContext
    var name: String { "set_selection" }
    var description: String { "Select entries in the active panel by a wildcard mask." }
    @Generable struct Arguments {
        @Guide(description: "Wildcard mask, e.g. *.txt") var mask: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("set_selection", ["mask": a.mask]) }
}

@available(macOS 26, *)
struct NTCopy: Tool {
    let ctx: NativeToolContext
    var name: String { "copy" }
    var description: String { "Copy files/folders to a destination folder." }
    @Generable struct Arguments {
        @Guide(description: "Absolute paths to copy") var sources: [String]
        @Guide(description: "Destination folder") var destination: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("copy", ["sources": a.sources, "destination": a.destination])
    }
}

@available(macOS 26, *)
struct NTMove: Tool {
    let ctx: NativeToolContext
    var name: String { "move" }
    var description: String { "Move files/folders to a destination folder." }
    @Generable struct Arguments {
        @Guide(description: "Absolute paths to move") var sources: [String]
        @Guide(description: "Destination folder") var destination: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("move", ["sources": a.sources, "destination": a.destination])
    }
}

@available(macOS 26, *)
struct NTRename: Tool {
    let ctx: NativeToolContext
    var name: String { "rename" }
    var description: String { "Rename a single entry in place." }
    @Generable struct Arguments {
        @Guide(description: "Entry to rename") var path: String
        @Guide(description: "New name (one path component)") var newName: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("rename", ["path": a.path, "new_name": a.newName])
    }
}

@available(macOS 26, *)
struct NTMakeDirectory: Tool {
    let ctx: NativeToolContext
    var name: String { "make_directory" }
    var description: String { "Create a new folder." }
    @Generable struct Arguments {
        @Guide(description: "Folder path to create") var path: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("make_directory", ["path": a.path]) }
}

@available(macOS 26, *)
struct NTSetConfig: Tool {
    let ctx: NativeToolContext
    var name: String { "set_config" }
    var description: String { "Set a configuration value by its Section.Key." }
    @Generable struct Arguments {
        @Guide(description: "Config key") var key: String
        @Guide(description: "New value") var value: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("set_config", ["key": a.key, "value": a.value])
    }
}

@available(macOS 26, *)
struct NTMoveToTrash: Tool {
    let ctx: NativeToolContext
    var name: String { "move_to_trash" }
    var description: String { "Move files/folders to the Trash (reversible)." }
    @Generable struct Arguments {
        @Guide(description: "Absolute paths to move to the Trash") var paths: [String]
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("move_to_trash", ["paths": a.paths]) }
}

@available(macOS 26, *)
struct NTDeletePermanently: Tool {
    let ctx: NativeToolContext
    var name: String { "delete_permanently" }
    var description: String { "Delete files/folders permanently (NOT reversible)." }
    @Generable struct Arguments {
        @Guide(description: "Absolute paths to delete permanently") var paths: [String]
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("delete_permanently", ["paths": a.paths]) }
}

@available(macOS 26, *)
struct NTRunCommand: Tool {
    let ctx: NativeToolContext
    var name: String { "run_command" }
    var description: String { "Invoke a named command (cm_*) by id." }
    @Generable struct Arguments {
        @Guide(description: "The command id, e.g. cm_PackFiles") var commandId: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("run_command", ["command_id": a.commandId]) }
}

@available(macOS 26, *)
struct NTSemanticSearch: Tool {
    let ctx: NativeToolContext
    var name: String { "semantic_search" }
    var description: String {
        "THE tool for 'which file is about X' / 'find the file about X': ranks the folder's files "
        + "by how well their names AND their contents match a description, even when the file "
        + "name says nothing. Use summarize_file or read_file on a match."
    }
    @Generable struct Arguments {
        @Guide(description: "What to look for, in plain words") var query: String
        @Guide(description: "Folder to search; empty for the active folder") var path: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("semantic_search", ntArgs(["query": a.query, "path": a.path]))
    }
}

@available(macOS 26, *)
struct NTFindFiles: Tool {
    let ctx: NativeToolContext
    var name: String { "find_files" }
    var description: String {
        "THE tool for finding a file when you do not know which folder it is in: it asks the system's "
        + "own file index, so it covers the whole disk or the home folder without walking it. "
        + "\"that PDF from last month\" is kind=pdf with within_days=30; \"all my node_modules "
        + "folders\" is kind=folder with name=node_modules. Leave a field empty to not narrow by it."
    }
    @Generable struct Arguments {
        @Guide(description: "Words or wildcards in the FILE NAME; empty to not filter by name") var name: String
        @Guide(description: "Words to find INSIDE the files; empty to not search contents") var text: String
        @Guide(description: "pdf, image, movie, audio, text, source, archive, folder or application; empty for any")
        var kind: String
        @Guide(description: "Modified in the last N days; 0 for any time")
        var withinDays: Int
        @Guide(description: "Where: home, disk, here, or an absolute path. Empty means home")
        var scope: String
    }
    func call(arguments a: Arguments) async throws -> String {
        // A zero window means "no window", not "the last zero days": the tool argument is optional and
        // `@Generable` has no absent value, so zero is how absence arrives here.
        var args = ntArgs(["name": a.name, "text": a.text, "kind": a.kind, "scope": a.scope])
        if a.withinDays > 0 { args["within_days"] = a.withinDays }
        return await ctx.run("find_files", args)
    }
}

@available(macOS 26, *)
struct NTRenameBatch: Tool {
    let ctx: NativeToolContext
    var name: String { "rename_batch" }
    var description: String {
        "Rename MANY files in one step. Build the new names yourself and pass the two lists in the same "
        + "order; the user sees them as a table and agrees once, and undo takes the whole batch back. "
        + "Use this instead of calling rename over and over — that asks the user once per file."
    }
    @Generable struct Arguments {
        @Guide(description: "The current file names, without a folder") var oldNames: [String]
        @Guide(description: "The new names, in the same order as oldNames") var newNames: [String]
        @Guide(description: "Folder the files are in; empty for the active folder") var directory: String
    }
    func call(arguments a: Arguments) async throws -> String {
        var args: [String: Any] = ["old_names": a.oldNames, "new_names": a.newNames]
        if !a.directory.isEmpty { args["directory"] = a.directory }
        return await ctx.run("rename_batch", args)
    }
}

@available(macOS 26, *)
struct NTRemember: Tool {
    let ctx: NativeToolContext
    var name: String { "remember" }
    var description: String {
        "Save a short note to long-term memory, kept across chats. Use it when the user "
        + "states a durable fact or preference, or asks you to remember something."
    }
    @Generable struct Arguments {
        @Guide(description: "The note to remember, one sentence") var text: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("remember", ["text": a.text]) }
}

@available(macOS 26, *)
struct NTRecall: Tool {
    let ctx: NativeToolContext
    var name: String { "recall" }
    var description: String { "Look up notes saved earlier in long-term memory. Empty query = the most recent notes." }
    @Generable struct Arguments {
        @Guide(description: "Text to match; empty for the most recent notes") var query: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("recall", ntArgs(["query": a.query]))
    }
}

@available(macOS 26, *)
struct NTRecentActions: Tool {
    let ctx: NativeToolContext
    var name: String { "list_recent_actions" }
    var description: String {
        "List what has recently been done to the user's files (tool, arguments, outcome), "
        + "newest first. Use it when the user asks what you did or what changed."
    }
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String { await ctx.run("list_recent_actions", [:]) }
}

@available(macOS 26, *)
struct NTUndoLast: Tool {
    let ctx: NativeToolContext
    var name: String { "undo_last_action" }
    var description: String {
        "Undo the most recent change that can be undone (a rename or a move). Use it when the "
        + "user asks to take back what was just done. It answers with why if it cannot."
    }
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String { await ctx.run("undo_last_action", [:]) }
}

@available(macOS 26, *)
struct NTRunShell: Tool {
    let ctx: NativeToolContext
    var name: String { "run_shell" }
    var description: String { "Run a shell command in a visible terminal tab and return what it printed." }
    @Generable struct Arguments {
        @Guide(description: "The command line, exactly as it should be run") var command: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("run_shell", ["command": a.command]) }
}

/// Summarise a whole file, however long, by reading it in slices and folding the slice
/// summaries together (map-reduce).
///
/// This is the tool the on-device model cannot be without. Its context window holds a few
/// thousand tokens — measured on this machine, a 4 KB slice is answerable and an 8 KB one is
/// not — so "summarise this file" over anything longer than a note either fails outright or,
/// worse, silently summarises the first slice and presents it as the whole. The folding runs
/// in Swift, with a fresh tool-less session per slice, so no single generation ever sees more
/// than one slice and the window can't overflow.
@available(macOS 26, *)
struct NTSummarizeFile: Tool {
    let ctx: NativeToolContext
    var name: String { "summarize_file" }
    var description: String {
        "Summarise a whole file of any length — reads it completely, in slices. Use this for "
        + "'summarise/explain/what is in this file' whenever the file may be longer than a "
        + "few thousand bytes, INSTEAD OF read_file. The result is the finished summary: "
        + "report it to the user and call no further tools."
    }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file to summarise") var path: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.summarizeWholeFile(path: a.path)
    }
}

// Guided-generation types for reliable STRUCTURED output (KI-09): the model fills a
// typed schema (constrained decoding) instead of free text, so a table is always
// well-formed.
@available(macOS 26, *)
@Generable struct GeneratedTableRow {
    @Guide(description: "the cell values, one per column, in header order") var cells: [String]
}
/// A file name proposed by the model, with its reason. Guided generation, so what comes back
/// is a name and not a sentence containing one — the difference between a button the user can
/// press and a line they have to retype.
@available(macOS 26, *)
@Generable struct GeneratedName {
    @Guide(description: "the new file name including its extension, no path, no quotes") var newName: String
    @Guide(description: "one short sentence saying why, in the language of the file") var reason: String
}

@available(macOS 26, *)
@Generable struct GeneratedTable {
    @Guide(description: "the column headers") var headers: [String]
    @Guide(description: "the data rows") var rows: [GeneratedTableRow]
}

/// A conversation that drives the file manager via the on-device Apple model using
/// native tool-calling. Holds a stateful LanguageModelSession so context carries
/// across turns; the tools execute through the shared AutomationCore.
@available(macOS 26, *)
public actor AppleNativeToolSession {
    private let ctx: NativeToolContext
    private let instructions: String
    private var llm: LanguageModelSession
    /// The tool names the session was built with, so a policy change can be recognised as
    /// one that changes the offered set (and only then costs a rebuild).
    private var offeredTools: [String]
    private let onPartial: (@Sendable (String) async -> Void)?

    public init(core: AutomationCore, policy: PermissionPolicy, instructions: String,
                broker: ConfirmationBroker? = nil,
                onProgress: (@Sendable (String) async -> Void)? = nil,
                onPartial: (@Sendable (String) async -> Void)? = nil,
                summaryStore: SummaryStore? = nil) {
        let ctx = NativeToolContext(core: core, policy: policy, broker: broker,
                                    onProgress: onProgress, summaryStore: summaryStore)
        self.ctx = ctx
        self.instructions = instructions
        self.onPartial = onPartial
        let tools = Self.makeTools(ctx, policy: policy)
        self.offeredTools = tools.map(\.name)
        self.llm = LanguageModelSession(tools: tools, instructions: instructions)
    }

    /// Apply a new policy. A tool the session may not use is not offered to the model at
    /// all: offering it produces a round of attempts answered with "Refused", and on a model
    /// with a few thousand tokens of context those rounds are the budget for the real answer.
    /// The transcript carries over, so the conversation is not restarted for a setting change.
    public func setPolicy(_ p: PermissionPolicy) {
        ctx.policy = p
        let tools = Self.makeTools(ctx, policy: p)
        let names = tools.map(\.name)
        guard names != offeredTools else { return }
        offeredTools = names
        llm = LanguageModelSession(tools: tools, transcript: llm.transcript)
    }

    /// Produce a well-formed Markdown table from data IN the instruction via guided
    /// generation (constrained decoding fills a typed schema — always valid). Uses a
    /// fresh tool-less session: guided generation + tool-calling don't mix reliably
    /// (the model returns prose after a tool call), so reading happens separately.
    public func generateMarkdownTable(_ instruction: String) async throws -> String {
        let session = LanguageModelSession(instructions: "You produce structured tabular data.")
        let t = try await session.respond(to: instruction, generating: GeneratedTable.self).content
        var md = "| " + t.headers.joined(separator: " | ") + " |\n"
        md += "| " + t.headers.map { _ in "---" }.joined(separator: " | ") + " |\n"
        for r in t.rows { md += "| " + r.cells.joined(separator: " | ") + " |\n" }
        return md
    }

    /// Read a file and propose a name for it, as data rather than prose.
    public func suggestFileName(path: String) async throws -> (newName: String, reason: String) {
        let raw = await ctx.runRaw("read_file", ["path": path, "max_bytes": NativeToolContext.readBudget])
        let content = NativeToolContext.readContent(raw)
        let current = (path as NSString).lastPathComponent
        let session = LanguageModelSession(
            instructions: "You name files. Keep the existing extension. Use only characters that "
                + "are safe in a file name, and no path.")
        let out = try await session.respond(
            to: "The file is currently called \"\(current)\". Propose a clearer, descriptive name "
                + "based on what it contains.\n\nContents (may be truncated):\n\(content)",
            generating: GeneratedName.self).content
        return (Self.sanitize(name: out.newName, fallbackFrom: current), out.reason)
    }

    /// A model-proposed name has to be usable as one: no directories, no separators, and the
    /// original extension if the model dropped it.
    static func sanitize(name: String, fallbackFrom current: String) -> String {
        var candidate = (name as NSString).lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        if candidate.hasPrefix(".") { candidate.removeFirst() }
        if candidate.isEmpty { return current }
        let wanted = (current as NSString).pathExtension
        if !wanted.isEmpty, (candidate as NSString).pathExtension.lowercased() != wanted.lowercased() {
            candidate += "." + wanted
        }
        return String(candidate.prefix(200))
    }

    /// Read a file through the core, then guided-generate a Markdown table from its
    /// contents — the two reliable steps combined (used by the "Make a table" action).
    public func tabulateFile(path: String) async throws -> String {
        let raw = await ctx.run("read_file", ["path": path])
        let content: String
        if let d = raw.data(using: .utf8),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let c = o["content"] as? String { content = c } else { content = raw }
        return try await generateMarkdownTable("Turn the following data into a Markdown table.\n\nData:\n\(content)")
    }

    /// Why a turn failed. Every FoundationModels error used to reach the user as one
    /// catch-all "invalid tool call" message, which told them to rephrase even when the
    /// cause was a full context window or a model that hadn't finished downloading —
    /// and the raw cause was logged only in DEBUG builds, so a shipped build gave no
    /// way to tell those apart. Each kind now has its own message and retry answer.
    private enum TurnFailure {
        case inputRejected   // the input guardrail refused the prompt as sent
        case badToolCall     // the model's tool arguments didn't deserialize
        case contextFull     // the conversation no longer fits the window
        case modelNotReady   // assets missing / still downloading
        case rateLimited
        case busy            // a request is already running on this session
        case refused         // the model declined to answer
        case unknown
    }

    private static func classify(_ error: Error) -> TurnFailure {
        guard let e = error as? LanguageModelSession.GenerationError else { return .unknown }
        switch e {
        // Both arrive when the guardrail rejects the *input*: the locale case is what a
        // path-dominated prompt trips, whatever language the user actually wrote in.
        case .unsupportedLanguageOrLocale, .guardrailViolation: return .inputRejected
        case .decodingFailure, .unsupportedGuide:               return .badToolCall
        case .exceededContextWindowSize:                        return .contextFull
        case .assetsUnavailable:                                return .modelNotReady
        case .rateLimited:                                      return .rateLimited
        case .concurrentRequests:                               return .busy
        case .refusal:                                          return .refused
        @unknown default:                                       return .unknown
        }
    }

    private static func message(for failure: TurnFailure) -> String {
        // Localized like every other user-facing text in the app: these are read by the person
        // in front of the chat, and the chat around them speaks their language. `String(localized:)`
        // resolves in the main bundle, which is the app whose catalogue holds these keys.
        switch failure {
        case .inputRejected:
            return String(localized: "The on-device model refused that request before answering. Ask in plain words, or switch to a cloud model in Settings ▸ AI.",
                          comment: "AI: the on-device input guardrail rejected the prompt")
        case .badToolCall:
            return String(localized: "I couldn’t do that reliably — the on-device model called a tool incorrectly. Try one step at a time, or switch to a cloud model in Settings ▸ AI.",
                          comment: "AI: the model produced an invalid tool call")
        case .contextFull:
            return String(localized: "This conversation is too long for the on-device model. Start a new chat, or switch to a cloud model in Settings ▸ AI.",
                          comment: "AI: the model's context window is full")
        case .modelNotReady:
            return String(localized: "Apple Intelligence isn’t ready yet — the on-device model is still downloading. Try again shortly.",
                          comment: "AI: the on-device model is unavailable")
        case .rateLimited:
            return String(localized: "The on-device model is busy right now. Please try again in a moment.",
                          comment: "AI: the model is rate-limited")
        case .busy:
            return String(localized: "A request is still running in this chat. Wait for it, or press Stop.",
                          comment: "AI: a request is already in flight")
        case .refused:
            return String(localized: "The on-device model declined to answer that.",
                          comment: "AI: the model refused")
        case .unknown:
            return String(localized: "I couldn’t do that — the on-device model failed unexpectedly. Try again, or switch to a cloud model in Settings ▸ AI.",
                          comment: "AI: an unexpected model failure")
        }
    }

    /// Send a user message and run the whole native tool loop to a final answer,
    /// streaming the growing answer text through `onPartial` (cumulative snapshots).
    /// The small on-device model can throw or return an empty answer, so a turn gets a
    /// second attempt — but only where a second attempt can change the outcome.
    public func send(_ text: String) async throws -> String {
        var failure: TurnFailure?
        var prompt = text
        for attempt in 0..<2 {
            do {
                var final = ""
                var snapshots = 0
                for try await partial in llm.streamResponse(to: prompt) {
                    final = partial.content
                    snapshots += 1
                    await onPartial?(final)
                }
                #if DEBUG
                NSLog("[native] streamed %d snapshots (attempt %d)", snapshots, attempt + 1)
                #endif
                if !final.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return final }
                failure = nil   // an empty answer is not an error; retry once
            } catch {
                let kind = Self.classify(error)
                failure = kind
                // Always logged, not just in DEBUG: this is the only record of WHY a turn
                // failed, and the user-facing message is deliberately coarse.
                Self.log.error("on-device turn failed (attempt \(attempt + 1, privacy: .public)): \(String(describing: error), privacy: .public)")
                switch kind {
                case .inputRejected:
                    // Resending the same text is refused the same way every time; the one
                    // thing that can change the verdict is different text. It is the paths
                    // in the composed header that read as non-natural language, so retry
                    // with those reduced to names — the model keeps what it needs and has
                    // get_context for the exact paths.
                    let safe = ChatComposer.stripPaths(prompt)
                    guard safe != prompt, !safe.isEmpty else { return Self.message(for: kind) }
                    prompt = safe
                case .contextFull:
                    // The window is full, not the conversation over. Fold what was said so far
                    // into a short summary, start a session that holds it, and ask again — the
                    // alternative is telling the user to abandon a chat they are in the middle of.
                    guard attempt == 0, await compactTranscript() else {
                        return Self.message(for: kind)
                    }
                case .modelNotReady, .busy, .refused:
                    return Self.message(for: kind)   // a retry cannot change these
                case .badToolCall, .rateLimited, .unknown:
                    break                            // a retry may
                }
            }
        }
        // Failed even after the second attempt: report the kind, and don't abort the chat.
        if let failure { return Self.message(for: failure) }
        return ""
    }

    /// Start the session over, carrying a summary of the conversation instead of all of it.
    ///
    /// What fills the window is mostly *tool output* — the file contents the model read — and
    /// none of that is worth carrying: the conclusions drawn from it are in the answers. So the
    /// recovery is the fresh session; the summary is what keeps the thread. Returns false only
    /// when there is nothing left to drop, i.e. the very first turn was itself too large, where
    /// saying so is more use than trying the same thing again.
    private func compactTranscript() async -> Bool {
        let transcript = llm.transcript
        let said = Self.spokenText(of: transcript)
        // A transcript of just the instructions and the prompt that failed: nothing to drop.
        guard transcript.count > 2 else { return false }
        var carried = ""
        if said.count > 200 {
            let summary = await NativeToolContext.summarize(conversation: said)
            // Summarising something short can make it longer; then it is not a summary.
            if !summary.isEmpty, summary.count < said.count { carried = summary }
        }
        Self.log.notice("compacted transcript (\(transcript.count, privacy: .public) entries, \(said.count, privacy: .public) chars said → \(carried.count, privacy: .public) carried)")
        let tools = Self.makeTools(ctx, policy: ctx.policy)
        offeredTools = tools.map(\.name)
        llm = LanguageModelSession(
            tools: tools,
            instructions: carried.isEmpty ? instructions
                                          : instructions + "\n\nEarlier in this conversation: " + carried)
        return true
    }

    /// What was actually said — the user's prompts and the model's answers, in order. Tool
    /// calls and their output are left out: they are the bulk of the transcript and the least
    /// worth carrying, since the conclusions drawn from them are in the answers.
    static func spokenText(of transcript: Transcript) -> String {
        var lines: [String] = []
        for entry in transcript {
            switch entry {
            case .prompt(let p):
                lines.append("User: " + text(of: p.segments))
            case .response(let r):
                lines.append("Assistant: " + text(of: r.segments))
            case .instructions, .toolCalls, .toolOutput:
                continue
            @unknown default:
                continue
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func text(of segments: [Transcript.Segment]) -> String {
        segments.compactMap { if case .text(let t) = $0 { return t.content } else { return nil } }
            .joined(separator: " ")
    }

    private static let log = Logger(subsystem: "com.peachcommander", category: "AI")
}

@available(macOS 26, *)
extension AppleNativeToolSession: NativeTurnRunner {
    public func runTurn(_ text: String, policy: PermissionPolicy) async throws -> String {
        #if DEBUG
        NSLog("[native] runTurn (native tool-calling path)")
        #endif
        setPolicy(policy)
        return try await send(text)
    }

    public func makeTable(fromFile path: String) async throws -> String? {
        try await tabulateFile(path: path)
    }

    public func suggestName(forFile path: String) async throws -> (newName: String, reason: String)? {
        try await suggestFileName(path: path)
    }

    /// Every native tool, in catalogue order. `summarize_file` is the one that has no
    /// catalogue entry: summarising needs a model, and the Automation Core deliberately has
    /// none — so it is a capability of this session, gated as the read it is built from.
    static func allTools(_ ctx: NativeToolContext) -> [any Tool] {
        [NTGetContext(ctx: ctx), NTListDirectory(ctx: ctx), NTStatPath(ctx: ctx), NTReadFile(ctx: ctx),
         NTSummarizeFile(ctx: ctx), NTHashFile(ctx: ctx), NTSemanticSearch(ctx: ctx), NTSearch(ctx: ctx),
         NTFindFiles(ctx: ctx),
         NTGetConfig(ctx: ctx), NTRemember(ctx: ctx), NTRecall(ctx: ctx),
         NTGetComment(ctx: ctx), NTRecentActions(ctx: ctx), NTListCommands(ctx: ctx), NTListPlugins(ctx: ctx),
         NTOpenPath(ctx: ctx), NTOpenInPanel(ctx: ctx), NTSetSelection(ctx: ctx),
         NTCopy(ctx: ctx), NTMove(ctx: ctx), NTRename(ctx: ctx), NTMakeDirectory(ctx: ctx),
         NTRenameBatch(ctx: ctx),
         NTWriteFile(ctx: ctx), NTMergeFiles(ctx: ctx), NTSetComment(ctx: ctx),
         NTSetConfig(ctx: ctx), NTMoveToTrash(ctx: ctx), NTDeletePermanently(ctx: ctx),
         NTUndoLast(ctx: ctx), NTRunCommand(ctx: ctx), NTRunShell(ctx: ctx)]
    }

    /// The tools `policy` permits. The capability comes from `AutomationCatalog`, so the
    /// native path and the text/MCP paths gate on the same declaration rather than on two
    /// lists that can drift apart.
    static func makeTools(_ ctx: NativeToolContext, policy: PermissionPolicy) -> [any Tool] {
        allTools(ctx).filter { policy.permits(capability(of: $0.name)) }
    }

    /// `summarize_file` reads, and nothing else; everything else is declared.
    static func capability(of toolName: String) -> Capability {
        if toolName == "summarize_file" { return .read }
        return AutomationCatalog.tool(named: toolName)?.capability ?? .read
    }
}
#endif
