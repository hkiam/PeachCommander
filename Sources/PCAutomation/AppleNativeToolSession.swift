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
        // Through SummaryStore, which is the definition. Written out here by hand, this produced a
        // key the panel's AI column could never match: `NSNumber.stringValue` rounds a Double to
        // about six decimals where interpolation does not, so the two dylibs agreed on the file and
        // disagreed on the string. (The column had a second bug of its own — the 1970 epoch against
        // this one's 2001 — so it had never matched at all.)
        let size = (o["size"] as? NSNumber)?.int64Value ?? -1
        let modified = (o["modified"] as? NSNumber)?.doubleValue ?? -1
        return SummaryStore.fingerprint(path: path, size: size, modified: modified)
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

/// A file name proposed by the model, with its reason. Guided generation, so what comes back
/// is a name and not a sentence containing one — the difference between a button the user can
/// press and a line they have to retype.
@available(macOS 26, *)
@Generable struct GeneratedName {
    @Guide(description: "the new file name including its extension, no path, no quotes") var newName: String
    @Guide(description: "one short sentence saying why, in the language of the file") var reason: String
}


/// A comment proposed for a file, with the tags that belong beside it. Guided generation, so
/// what comes back is a comment and a word list — not a sentence describing both, which is what
/// a file manager would then have to parse before it could store either.
@available(macOS 26, *)
@Generable struct GeneratedComment {
    @Guide(description: "one sentence saying what the file is for, in the language of the file")
    var comment: String
    @Guide(description: "up to four single-word tags, lower case, no punctuation")
    var tags: [String]
}

/// A table pulled out of a file, as a typed value the model fills cell by cell. Guided generation
/// is what makes this worth doing on a small model at all: a table asked for as text comes back
/// with a missing separator row or a stray sentence after it often enough to be useless, and a
/// typed schema cannot.
@available(macOS 26, *)
@Generable struct GeneratedTableRow {
    @Guide(description: "the cell values, one per column, in header order") var cells: [String]
}

@available(macOS 26, *)
@Generable struct GeneratedTable {
    @Guide(description: "the column headers") var headers: [String]
    @Guide(description: "the data rows") var rows: [GeneratedTableRow]
}

/// One topic and the category it was put in. A pair rather than two lists, because two lists let
/// the model return four topics and three categories, and nothing downstream could tell which was
/// missing.
@available(macOS 26, *)
@Generable struct GeneratedTopicGroup {
    @Guide(description: "the topic, copied exactly as it was given to you") var topic: String
    @Guide(description: "the category it belongs to") var category: String
}

@available(macOS 26, *)
@Generable struct GeneratedTopicGroups {
    @Guide(description: "one entry for each topic you were given") var groups: [GeneratedTopicGroup]
}

/// The three short facts a file manager can act on: what kind of thing a file is, what it is
/// about, and the date it concerns. Guided generation, so each comes back as its own value rather
/// than as a sentence something would have to parse — and `date` can come back empty, which is
/// what a model should do when a document has no date rather than inventing one.
@available(macOS 26, *)
@Generable struct GeneratedFacts {
    @Guide(description: "exactly one of the categories you were given, copied as written")
    var kind: String
    @Guide(description: "two or three words naming what this file is about, lower case, no punctuation")
    var topic: String
    @Guide(description: "the document's own full date as YYYY-MM-DD, only if it states day, month and year; otherwise empty")
    var date: String
}

/// Where one file belongs when a folder is tidied up. The subfolder is a plain name and never a
/// path: the caller creates it inside the folder being organised, so a model that answered with
/// a path would be proposing a move out of it.
@available(macOS 26, *)
/// The folders a whole batch should be sorted into, chosen before any file is assigned.
///
/// Asking per file with a growing list of "folders chosen so far" was measured to fail in both
/// directions at once: for the first file the model answered with that file's own base name, and
/// the instruction to prefer an existing folder then pulled every other file into it — one folder
/// for four unrelated documents, named after one of them. Choosing the categories while looking at
/// the whole set is what makes them categories.
@available(macOS 26, *)
@Generable struct GeneratedFolders {
    @Guide(description: "two to six short folder names, each one path component, in the language of the file names")
    var folders: [String]
}

@available(macOS 26, *)
@Generable struct GeneratedFolder {
    @Guide(description: "the subfolder name, one path component, no slashes")
    var subfolder: String
    @Guide(description: "a few words saying why, in the language of the file name")
    var reason: String
}

/// A conversation that drives the file manager via the on-device Apple model using
/// native tool-calling. Holds a stateful LanguageModelSession so context carries
/// across turns; the tools execute through the shared AutomationCore.
@available(macOS 26, *)
public actor AppleNativeToolSession {
    private let ctx: NativeToolContext

    /// A session for the direct actions. The model is offered no tools, ever.
    ///
    /// This used to be one of two initialisers; the other built a chat that handed the model
    /// thirty-two tools, and their schemas were what the window went on. Measured on macOS 26.4:
    /// 3442 of 4096 tokens, leaving 473 for the file, the question and the answer together — so
    /// it could not read a 4 KB slice. Each direct action is instead one generation over one
    /// file's text, and the window is the file's.
    ///
    /// Reading still goes through the Automation Core, so the policy and the audit log apply as
    /// they always did; it is simply the caller that decides to read, not the model.
    public init(directActionsOn core: AutomationCore, policy: PermissionPolicy,
                broker: ConfirmationBroker? = nil,
                onProgress: (@Sendable (String) async -> Void)? = nil,
                summaryStore: SummaryStore? = nil) {
        let ctx = NativeToolContext(core: core, policy: policy, broker: broker,
                                    onProgress: onProgress, summaryStore: summaryStore)
        self.ctx = ctx
    }

    /// Read a file and propose a name for it, as data rather than prose.
    public func suggestFileName(path: String) async throws -> (newName: String, reason: String) {
        let content = await readable(path, maxBytes: NativeToolContext.readBudget)
        let current = (path as NSString).lastPathComponent
        // Named, not described. A German invoice was proposed "Repair_Bill_4711.txt" with the
        // language left implicit — the same failure the folding code measured four times out of
        // four before it started naming the language outright.
        let language = NativeToolContext.languageName(of: content)
        let session = LanguageModelSession(
            instructions: "You name files. Keep the existing extension. Use only characters that "
                + "are safe in a file name, and no path. Keep it short — a few words, not a "
                + "summary of the contents."
                + NativeToolContext.languageClause(language)
                + (language == nil ? "" : " Name the file in that language."))
        let out = try await session.respond(
            to: "The file is currently called \"\(current)\". Propose a clearer, descriptive name "
                + "based on what it contains. Do not keep any part of the current name unless it "
                + "already says something about the contents — \"scan_0042\" does not.\n\n"
                + "Contents (may be truncated):\n\(content)",
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


    /// Summarise a whole file, however long it is, and keep the result for the AI column.
    ///
    /// The folding itself lives on the context, because it needs the read tool and the summary
    /// store. This is the way in from outside the module: the chat reaches the folding through
    /// the `summarize_file` tool, and a direct action has no tools to reach it through.
    public func summarize(file path: String) async -> String {
        // A picture has no slices to fold: what there is to say about it fits in one description,
        // and reading a JPEG's bytes as text produces mojibake for a model to hallucinate over.
        guard !DirectActionPlan.isImage((path as NSString).lastPathComponent) else {
            let described = await readable(path, maxBytes: NativeToolContext.readBudget)
            guard !described.isEmpty else { return "" }
            let language = NativeToolContext.languageName(of: described)
            return await NativeToolContext.generate(
                "Say in two or three sentences what this picture is and what it shows."
                + NativeToolContext.languageClause(language)
                + "\n\n" + described)
        }
        return await ctx.summarizeWholeFile(path: path)
    }

    /// The text an action should reason about: the file's own text, or — for a picture — the words
    /// Vision could read on it and what it appears to show.
    ///
    /// This is the whole of image understanding, and it is deliberately not a new action. Apple
    /// Intelligence is text-only, so a picture becomes readable by being described first; once it
    /// is, every action that already asks "what is this file" works on a scan or a photograph with
    /// nothing else changed. Naming, commenting, explaining and classifying all came for free.
    ///
    /// A picture with nothing on it and nothing recognisable in it comes back empty, and the
    /// caller treats that as it treats an empty file.
    func readable(_ path: String, maxBytes: Int) async -> String {
        guard DirectActionPlan.isImage((path as NSString).lastPathComponent) else {
            let raw = await ctx.runRaw("read_file", ["path": path, "max_bytes": maxBytes])
            return raw.hasPrefix("Failed:") || raw.hasPrefix("Refused:")
                ? "" : NativeToolContext.readContent(raw)
        }
        let raw = await ctx.runRaw("describe_image", ["path": path])
        guard let data = raw.data(using: .utf8),
              let described = try? JSONDecoder().decode(ImageDescription.self, from: data),
              !described.isEmpty else { return "" }
        var parts: [String] = []
        // The words first and unlabelled, for two reasons. A scan is a document that happens to be
        // pixels, and a model handed "beach, sand" above an invoice's text names the file after the
        // beach. And the caller works out the language from this string: an English scaffolding
        // sentence in front of German text was enough to make it name a German invoice "receipt".
        if !described.text.isEmpty {
            parts.append(String(described.text.prefix(maxBytes)))
        }
        // Kept even when there is text. Suppressing them looked right — a scanned invoice's own
        // words should outweigh "document, text" — and made the classification measurably WORSE,
        // one run in four instead of two in three. The labels are apparently what tells the model
        // it is looking at a page rather than at prose.
        if !described.labels.isEmpty {
            parts.append("[" + described.labels.joined(separator: ", ") + "]")
        }
        return parts.joined(separator: "\n\n")
    }

    /// How much of a file one read takes in. Public because a caller showing a partial result has
    /// to be able to say how partial it is, and "the beginning" is not an answer somebody can act on.
    public static var readSliceBytes: Int { NativeToolContext.readBudget }

    /// Read the beginning of a file and pull a table out of it.
    ///
    /// One slice, and that bound is the honest part: a 4096-token window holds a few dozen rows,
    /// not a database export. A log, a measurement series or a CSV somebody exported badly is
    /// exactly the size this helps with, and the caller is told how much was read so it can say so.
    ///
    /// Guided generation and no tools, like every other direct action — the table arrives as cells
    /// rather than as text that has to be parsed back into cells.
    public func tabulate(file path: String) async throws -> (table: DirectActionPlan.Table, truncated: Bool) {
        // Through `readable`, so a screenshot of a table is a table: Vision reads the cells and the
        // model arranges them. That is the case this is most useful for — a picture of a table is
        // the one shape a file manager cannot do anything with otherwise.
        let content = await readable(path, maxBytes: NativeToolContext.readBudget)
        guard !content.isEmpty else { return (DirectActionPlan.Table(headers: [], rows: []), false) }
        let truncated = DirectActionPlan.isImage((path as NSString).lastPathComponent)
            ? false
            : NativeToolContext.readWasTruncated(
                await ctx.runRaw("stat_path", ["path": path])) || content.utf8.count >= NativeToolContext.readBudget
        let language = NativeToolContext.languageName(of: content)
        let session = LanguageModelSession(
            instructions: "You turn data into a table. Use the column names the data itself uses, "
                + "and take the values from the data — never invent a row."
                + NativeToolContext.languageClause(language))
        let out = try await session.respond(
            to: "Turn the following into a table.\n\n\(content)",
            generating: GeneratedTable.self).content
        return (DirectActionPlan.table(headers: out.headers, rows: out.rows.map(\.cells)), truncated)
    }

    /// What this file *is* — as opposed to what it says, which is `summarize(file:)`.
    ///
    /// Two menu entries used to run the same code, which is a defect and not a nuance. The
    /// distinction that earns them both: a summary is for prose and reads the whole file; this
    /// answers "what is this and what would I use it for" from the opening alone, which is the
    /// right question for a config file, a script or a data dump — the cases where a summary of
    /// the text is the wrong shape of answer entirely.
    ///
    /// One slice, one generation. No folding: the answer does not get better for having seen
    /// page nine.
    public func explain(file path: String) async throws -> String {
        let content = await readable(path, maxBytes: NativeToolContext.readBudget)
        let current = (path as NSString).lastPathComponent
        let language = NativeToolContext.languageName(of: content)
        let session = LanguageModelSession(
            instructions: "You say what a file is and what someone would use it for, in three "
                + "sentences at most. Describe its kind and purpose, not its contents line by "
                + "line. If it is configuration, code or data, say what it configures, does or "
                + "records." + NativeToolContext.languageClause(language))
        return try await session.respond(
            to: "The file is called \"\(current)\". What is it, and what would someone use it "
                + "for?\n\nIt begins:\n\(content)").content
    }

    /// Propose a comment and tags for a file, from what it says rather than what it is called.
    ///
    /// One slice, not the whole file: a comment says what a document *is*, and that is settled in
    /// its opening. Folding a long file here would cost a generation per 4 KB for a sentence.
    public func suggestComment(path: String) async throws -> (comment: String, tags: [String]) {
        let content = await readable(path, maxBytes: NativeToolContext.readBudget)
        let current = (path as NSString).lastPathComponent
        // The language NAMED, not described. Measured in the folding code next door: asking for
        // "the same language as the text" gave an English answer to a German file four times out
        // of four, and naming the language is what this model follows.
        let language = NativeToolContext.languageName(of: content)
        let session = LanguageModelSession(
            instructions: "You describe a file in one short sentence."
                + NativeToolContext.languageClause(language))
        let out = try await session.respond(
            to: "The file is called \"\(current)\". Write a one-sentence comment saying what it "
                + "is for, and up to four short tags.\n\nContents (may be truncated):\n\(content)",
            generating: GeneratedComment.self).content
        return (out.comment.trimmingCharacters(in: .whitespacesAndNewlines),
                DirectActionPlan.sanitize(tags: out.tags))
    }

    /// The folders a folder-tidy should use, chosen once while looking at every name.
    ///
    /// One generation for the whole batch. The language is left to the names themselves rather than
    /// detected: `NLLanguageRecognizer` on a list of file names is guessing at tokens, not reading
    /// prose — asked about "dokument1.txt dokument2.txt notizen.txt" it answered Polish, and every
    /// category came back as "tekstowe".
    ///
    /// What comes back is filtered by `DirectActionPlan`:
    /// a name that is really one of the files is not a category, and two spellings of one folder
    /// are one folder.
    public func proposeFolders(forNames names: [String]) async throws -> [String] {
        // Every clause here answers a measured failure. "As few as sensibly possible" alone made
        // the model answer with the file names for a set of two — both were then dropped as
        // non-categories and the action reported that nothing groups at all. Naming a KIND, being
        // told the count, and being forbidden the file names is what produces categories.
        let session = LanguageModelSession(
            instructions: "You group files into folders by what KIND of thing they are — Invoices, "
                + "Photos, Contracts. A folder name is a category, never the name of a document. "
                + "Answer with folder names only: no paths, and never a file name. Name the "
                + "folders in the same language as the file names you are given.")
        let out = try await session.respond(
            to: "Propose folders for these \(names.count) files. Use FEWER folders than there are "
                + "files — a folder holding one file has grouped nothing. One folder for all of "
                + "them is a fine answer when they are all the same kind.\n\n"
                + names.joined(separator: "\n"),
            generating: GeneratedFolders.self).content
        let usable = DirectActionPlan.usableFolders(out.folders, fileNames: names)
        guard usable.isEmpty else { return usable }

        // Everything came back as a file name, so nothing survived the filter and the action would
        // report that a folder full of related documents groups into nothing. On a small set this
        // happens intermittently — the same two files pass one run and fail the next — so it is
        // worth one blunter second ask rather than a shrug.
        let retry = try await session.respond(
            to: "Do not repeat the file names. Name the KIND of thing these \(names.count) files "
                + "are — one or two words, like Invoices or Photos. One category for all of them "
                + "is a fine answer.\n\n" + names.joined(separator: "\n"),
            generating: GeneratedFolders.self).content
        let second = DirectActionPlan.usableFolders(retry.folders, fileNames: names)
        guard second.isEmpty else { return second }
        // Neither ask produced a category. If the names all begin with the same word, that word is
        // the category and no model is needed to see it.
        return DirectActionPlan.commonPrefixCategory(of: names).map { [$0] } ?? []
    }

    /// What this file is, is about, and is dated — in one generation.
    ///
    /// The kind is chosen from a closed list the caller worked out over the whole selection, for
    /// the same reason folders are: categories only exist relative to a set, and a model asked
    /// per file invents a new one each time. Topic and date are per file by nature, and asking for
    /// all three together is what keeps this at one generation per file instead of three.
    public func facts(forFile path: String, among kinds: [String]) async throws -> AIFileFacts {
        let name = (path as NSString).lastPathComponent
        let peek = await readable(path, maxBytes: 1024)
        let language = NativeToolContext.languageName(of: peek.isEmpty ? name : peek)
        let session = LanguageModelSession(
            instructions: "You describe a file in a few words so it can be filed and renamed. "
                + "Give a category from the list you are handed, a short topic, and the document's "
                + "own date ONLY if it states a full day, month and year. \"Summer 2023\" or "
                + "\"March\" is not a date — answer with nothing rather than filling in a day. "
                + "Never today's date, and never a guess."
                + NativeToolContext.languageClause(language))
        // With no categories on offer, the categories are not mentioned at all. Writing
        // "Categories: none" put the word *none* into the answer — as the topic, on its way into a
        // file name — because a small model given a field and no options fills it with what it saw.
        let offered = kinds.isEmpty ? "Leave the category empty.\n\n"
                                    : "Categories: \(kinds.joined(separator: ", "))\n\n"
        // No special pleading for scans here. Handed a category list and a ".png", this model
        // answers "Photos" for a scanned invoice however it is asked — and the Classify action
        // never hands it one: it asks for topic and date with no categories at all, then works the
        // categories out from the topics afterwards. The topic for a scan is reliable, and that is
        // the value this path is asked for.
        let out = try await session.respond(
            to: offered + "The file is called \"\(name)\"."
                + (peek.isEmpty ? "" : "\n\nIt begins:\n\(peek)"),
            generating: GeneratedFacts.self).content
        // The date is checked against the text rather than taken on trust — see `dateSupported`.
        let date = DirectActionPlan.sanitize(date: out.date)
        return AIFileFacts(kind: DirectActionPlan.snap(out.kind, to: kinds) ?? "",
                           topic: DirectActionPlan.sanitize(topic: out.topic),
                           date: DirectActionPlan.dateSupported(date, by: peek) ? date : "")
    }

    /// Group topics into categories, and say which topic went where — in one generation.
    ///
    /// Two earlier shapes failed measurably. Proposing categories from FILE NAMES gave "Dokument"
    /// for everything, because `dokument1.txt` carries no meaning. Proposing them from the topics
    /// and then matching by string gave English categories for German topics ("Financial" for
    /// "rechnung") — and even in one language a category is a synonym of its members, not a
    /// substring of them, so no amount of matching would have joined them.
    ///
    /// So the model does the assigning as well, and the language is NAMED from the topics, which
    /// are words taken from the files' own contents and therefore worth detecting on.
    public func groupTopics(_ topics: [String]) async throws -> [String: String] {
        let unique = Array(Set(topics.filter { !DirectActionPlan.isPlaceholder($0) })).sorted()
        guard unique.count > 1 else { return [:] }
        let language = NativeToolContext.languageName(of: unique.joined(separator: " "))
        let session = LanguageModelSession(
            instructions: "You sort topics into a few categories and say which topic went where. "
                + "Use fewer categories than there are topics. A category is a kind of document — "
                + "Invoices, Contracts, Travel — never a copy of one topic."
                + NativeToolContext.languageClause(language)
                + (language == nil ? "" : " Name the categories in that language."))
        let out = try await session.respond(
            to: "Sort these \(unique.count) topics into categories:\n\n"
                + unique.joined(separator: "\n"),
            generating: GeneratedTopicGroups.self).content

        var mapping: [String: String] = [:]
        for pair in out.groups {
            // The model is asked to echo the topic; snapping puts a paraphrase back on the one it
            // meant, and drops an answer that resembles none of them.
            guard let topic = DirectActionPlan.snap(pair.topic, to: unique) else { continue }
            let category = DirectActionPlan.sanitize(folder: pair.category, matching: [])
            guard !category.isEmpty, !DirectActionPlan.isPlaceholder(category) else { continue }
            mapping[topic] = category
        }
        return mapping
    }

    /// Which of `folders` this file belongs in, or an empty name when none of them fits.
    ///
    /// A closed list, deliberately: the model choosing from names it can see is the thing small
    /// models are good at, and it is what stops the answer being a fresh near-synonym per file.
    public func assignFolder(forFile path: String,
                             among folders: [String]) async throws -> (subfolder: String, reason: String) {
        guard !folders.isEmpty else { return ("", "") }
        let name = (path as NSString).lastPathComponent
        // A peek, not a read: the name carries most of the signal, and the rest is what rescues
        // "scan001.pdf" from being sorted by its number.
        let peek = await readable(path, maxBytes: 1024)
        let session = LanguageModelSession(
            instructions: "You file documents. Choose exactly one of the folders you are given, "
                + "copying its name as written. If none of them fits, answer with an empty name.")
        let out = try await session.respond(
            to: "Folders: \(folders.joined(separator: ", "))\n\n"
                + "Which one does \"\(name)\" belong in?"
                + (peek.isEmpty ? "" : "\n\nIt begins:\n\(peek)"),
            generating: GeneratedFolder.self).content
        // Snapped to the list rather than trusted: an answer nothing in the list resembles means
        // "none fits", and a file that stays where it is beats a folder nobody asked for.
        let cleaned = DirectActionPlan.sanitize(folder: out.subfolder, matching: folders)
        return (DirectActionPlan.snap(cleaned, to: folders) ?? "", out.reason)
    }

    private static let log = Logger(subsystem: "com.peachcommander", category: "AI")
}

#endif
