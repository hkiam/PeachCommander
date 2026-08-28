// SPDX-License-Identifier: Apache-2.0
// MacroRecorder.swift — building a macro out of what just happened (F-478).
//
// There is no recorder in the usual sense. Nothing watches the user and nothing has to be switched on
// first: what happened is already written down, in two records the app keeps anyway, so "make a macro
// out of that" is a read rather than a recording.
//
// **Two sources, one list.** The audit log holds what went through the Automation Core — the
// assistant, an MCP client, another macro. The app's own operation history (F-402) holds what the user
// did by hand: F5, F6, F7, F8, a rename in the panel. Both are read, because "what I just did" does not
// distinguish between them and a recorder that offered only the first was empty for anybody who had not
// switched the assistant on.
//
// Turning an entry back into a step is literal by default: the arguments are the ones that ran. A
// *guessed* generalisation is the failure mode here — a macro that quietly means "the folder I happened
// to be in that day" is worse than one whose paths are visibly absolute and can be edited. So the
// substitution into `%S`, `%P` and `%T` is offered rather than applied (`generalised(_:context:)`), the
// sheet shows what each row will say before anything is saved, and the recorded form is what you get if
// you do not ask.

import Foundation

/// Something that happened and might be worth repeating, from whichever of the two records holds it.
///
/// A separate type rather than `AuditEntry` everywhere, because an `AuditEntry` means "the Automation
/// Core did this" — it carries a capability and an inverse — and a manual F5 did not go through the
/// Core and has neither. Flattening the two would have the recorder claim a provenance the second kind
/// does not have.
public struct RecordedAction: Sendable, Equatable {
    /// Which record this came from. Shown in the sheet, because "the assistant moved these" and "you
    /// moved these" are different enough that a reader wants to know which list they are looking at.
    public enum Source: Sendable, Equatable {
        case automation
        case panel
    }

    public let at: Date
    public let tool: String
    /// The exact arguments, as JSON, or nil when they were not kept — over `argumentsJSONCap`, or an
    /// operation the history records without enough to repeat.
    public let argumentsJSON: String?
    public let succeeded: Bool
    /// What to call it when the arguments cannot be turned into a sentence.
    public let summary: String
    public let source: Source

    public init(at: Date, tool: String, argumentsJSON: String?, succeeded: Bool,
                summary: String, source: Source) {
        self.at = at; self.tool = tool; self.argumentsJSON = argumentsJSON
        self.succeeded = succeeded; self.summary = summary; self.source = source
    }

    /// An audit entry as a candidate action.
    public init(_ entry: AuditEntry) {
        self.init(at: Date(timeIntervalSince1970: entry.at), tool: entry.tool,
                  argumentsJSON: entry.argumentsJSON, succeeded: entry.outcome == "ok",
                  summary: "\(entry.tool) \(entry.arguments)", source: .automation)
    }

    /// What a file operation carried out in the panels amounts to.
    ///
    /// The host says *which* operation and on what; the tool name and argument shape are decided here,
    /// because they belong to the catalogue and have to match it exactly — a step naming `trash`
    /// instead of `move_to_trash` is a macro that fails the pre-flight. The host keeps only its own
    /// encoding, which is the part this module has no business knowing.
    public enum PanelOperation: Sendable, Equatable {
        case copy(items: [String], destination: String)
        case move(items: [String], destination: String)
        case trash([String])
        case deletePermanently([String])
        /// Leaf names within `directory`, old → new.
        case rename(pairs: [(old: String, new: String)], directory: String)
        case makeDirectory(String)

        public static func == (a: PanelOperation, b: PanelOperation) -> Bool {
            a.call?.tool == b.call?.tool && a.callJSON == b.callJSON
        }

        var call: (tool: String, arguments: [String: Any])? {
            switch self {
            case .copy(let items, let destination):
                guard !items.isEmpty, !destination.isEmpty else { return nil }
                return ("copy", ["sources": items, "destination": destination])
            case .move(let items, let destination):
                guard !items.isEmpty, !destination.isEmpty else { return nil }
                return ("move", ["sources": items, "destination": destination])
            case .trash(let items):
                guard !items.isEmpty else { return nil }
                return ("move_to_trash", ["paths": items])
            case .deletePermanently(let items):
                guard !items.isEmpty else { return nil }
                return ("delete_permanently", ["paths": items])
            case .rename(let pairs, let directory):
                guard !pairs.isEmpty, !directory.isEmpty else { return nil }
                return ("rename_batch", ["old_names": pairs.map(\.old), "new_names": pairs.map(\.new),
                                         "directory": directory])
            case .makeDirectory(let path):
                guard !path.isEmpty else { return nil }
                return ("make_directory", ["path": path])
            }
        }

        var callJSON: String? {
            guard let arguments = call?.arguments,
                  let data = try? JSONSerialization.data(withJSONObject: arguments,
                                                         options: [.sortedKeys])
            else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }

    /// A panel operation as a candidate action, or nil when it holds nothing to repeat.
    public static func panel(_ operation: PanelOperation, summary: String, at: Date) -> RecordedAction? {
        guard let call = operation.call, let json = operation.callJSON else { return nil }
        return RecordedAction(at: at, tool: call.tool, argumentsJSON: json, succeeded: true,
                              summary: summary, source: .panel)
    }
}

public enum MacroRecorder {

    /// Why a recorded action cannot be turned into a step.
    ///
    /// A case rather than a sentence, for the reason `PlanPhrase` exists: the sheet shows these to a
    /// person and had been showing them in English under translated chrome, while `Candidate.text`
    /// keeps the English for anything that logs it.
    public enum Unavailable: String, Sendable, Equatable, Codable, CaseIterable {
        case nesting            // a macro cannot run another macro
        case didNotSucceed      // the action failed or was refused
        case argumentsTooLarge  // over `argumentsJSONCap` — a `write_file` carrying a document
        case notEnoughRecorded  // a panel operation the history keeps only by name
        case unreadableArguments

        /// The English sentence, for a log or a harness report.
        public var english: String {
            switch self {
            case .nesting:            return "a macro cannot run another macro"
            case .didNotSucceed:      return "this action did not succeed"
            case .argumentsTooLarge:  return "its arguments were too large to record in full"
            case .notEnoughRecorded:  return "not enough of it was recorded to repeat it"
            case .unreadableArguments: return "its arguments could not be read back"
            }
        }
    }

    /// One candidate step, and whether it can be replayed at all.
    public struct Candidate: Sendable, Equatable {
        public let id: String
        public let tool: String
        /// What the row reads, in English. The host renders `phrase` instead where there is one.
        public let text: String
        /// The same row as a key and its values, so the sheet can say it in the user's language.
        public let phrase: PlanPhrase?
        /// Which record it came from.
        public let source: RecordedAction.Source
        /// The step, when there is one. Nil when the entry cannot be replayed.
        public let step: MacroStep?
        /// Why it cannot, when it cannot.
        public let unavailable: Unavailable?

        public var isReplayable: Bool { step != nil }
    }

    /// The recent actions as macro candidates, newest first.
    ///
    /// Both records are merged and re-sorted by time, because the two of them interleave: a user copies
    /// a folder by hand, asks the assistant to rename what is in it, and then wants a macro of the pair.
    /// Read actions never reach either record, so what comes back is the changes: exactly the set
    /// somebody means by "what I just did".
    public static func candidates(from actions: [RecordedAction]) -> [Candidate] {
        actions.sorted { $0.at > $1.at }.enumerated().map { index, action in
            let id = String(index + 1)
            // Built from the *verbatim* arguments where there are any, not from the log's readable
            // line: that one is clipped at 60 characters per value for a log reader, and a row reading
            // "move destination=/private/tmp/claude-501/-Users-maik1-Sources-github-PeachCom…" tells
            // nobody which move it was. What distinguishes two moves is the file name, which is at the
            // end of a path — exactly the part clipping removes.
            let phrase = MacroPlan.phrase(tool: action.tool, argumentsJSON: action.argumentsJSON)
            let text = phrase?.english ?? action.summary
            // `run_macro` is skipped as a candidate: recording it would build a macro that runs a
            // macro, which the runner refuses anyway. Better to say so here than to offer a row that
            // cannot work.
            func candidate(_ step: MacroStep?, _ unavailable: Unavailable?) -> Candidate {
                Candidate(id: id, tool: action.tool, text: text, phrase: phrase,
                          source: action.source, step: step, unavailable: unavailable)
            }
            if action.tool == "run_macro" { return candidate(nil, .nesting) }
            guard action.succeeded else { return candidate(nil, .didNotSucceed) }
            guard let json = action.argumentsJSON else {
                // Named precisely for the audit log, where this has one cause and a fix: the arguments
                // were over `argumentsJSONCap`, which in practice means a `write_file` carrying a whole
                // document. A panel action never reaches here — `RecordedAction.panel` returns nil
                // rather than a candidate it cannot build — so the general wording is the fallback.
                return candidate(nil, action.source == .automation
                                 ? .argumentsTooLarge : .notEnoughRecorded)
            }
            guard let step = step(tool: action.tool, argumentsJSON: json) else {
                return candidate(nil, .unreadableArguments)
            }
            return candidate(step, nil)
        }
    }

    /// The audit log alone, for the callers that have no history to offer.
    public static func candidates(from entries: [AuditEntry]) -> [Candidate] {
        candidates(from: entries.map(RecordedAction.init))
    }

    /// Build a macro from the candidates the user kept.
    ///
    /// `keeping` names rows to include; the steps come out in the order they *happened*, not the order
    /// they were listed. The list is newest-first because that is how somebody looks for what they just
    /// did, and a macro has to run oldest-first or it undoes itself.
    ///
    /// - Parameter following: the panel state to write the steps in terms of, when the user asked for
    ///   that. Nil keeps the recorded paths.
    public static func macro(id: String, title: String, from candidates: [Candidate],
                             keeping kept: Set<String>,
                             following context: MacroContext? = nil) -> Macro {
        let steps = candidates
            .filter { kept.contains($0.id) }
            .compactMap(\.step)
            .map { step in context.map { generalised(step, context: $0) } ?? step }
            .reversed()
        return Macro(id: id, title: title, steps: Array(steps))
    }

    // MARK: - Following the panels instead of the files

    /// The keys whose value is "the files this step acts on".
    ///
    /// Named rather than guessed from the shape, because not every list of strings is a selection:
    /// `rename_batch`'s `old_names` is a list too, and turning *that* into `%S` would produce a macro
    /// renaming whatever happens to be selected to a fixed list of names.
    private static let selectionKeys: Set<String> = ["sources", "paths"]

    /// `step` with its recorded paths replaced by the placeholders that mean the same thing about the
    /// panels — the difference between a macro that repeats *that* copy and one that repeats the kind
    /// of copy it was.
    ///
    /// Three substitutions, and nothing cleverer:
    ///
    ///   * A list of files that all live in one folder becomes `%S`, the selection. That is what makes
    ///     a recorded "move these four invoices" into "move what I have selected".
    ///   * A path that *is* one of the two panel folders becomes `%P` or `%T`.
    ///   * A path *inside* one of them keeps its tail: `/Users/me/Documents/2026-08` under the other
    ///     panel becomes `%T/2026-08`.
    ///
    /// Applied only when the user asks for it. The recorded form is the honest default — a macro that
    /// quietly meant "the folder I happened to be in that day" is the failure this feature could
    /// otherwise cause — and the sheet shows what each row will say before anything is saved.
    ///
    /// The longer of the two panel folders is tried first, so a panel showing a subfolder of the other
    /// one does not lose to its own parent.
    public static func generalised(_ step: MacroStep, context: MacroContext) -> MacroStep {
        var out = step
        for (key, value) in step.arguments {
            switch value {
            case .list(let items) where selectionKeys.contains(key):
                guard items.count > 0, sharedParent(of: items) != nil else { continue }
                out.arguments[key] = .text(MacroPlaceholders.selectionToken)
            case .text(let path) where selectionKeys.contains(key):
                // A one-item list arrives as a list; a lone string here is a single path, and one file
                // is as much a selection as four.
                guard !path.isEmpty, (path as NSString).isAbsolutePath else { continue }
                out.arguments[key] = .text(MacroPlaceholders.selectionToken)
            case .text(let path):
                if let folded = folded(path, context: context) { out.arguments[key] = .text(folded) }
            case .list(let items):
                let rewritten = items.map { folded($0, context: context) ?? $0 }
                if rewritten != items { out.arguments[key] = .list(rewritten) }
            case .number, .flag:
                continue
            }
        }
        return out
    }

    /// Every step of `macro`, generalised.
    public static func generalised(_ macro: Macro, context: MacroContext) -> Macro {
        var out = macro
        out.steps = macro.steps.map { generalised($0, context: context) }
        return out
    }

    /// The folder every one of `paths` sits in, or nil when they are spread over more than one.
    private static func sharedParent(of paths: [String]) -> String? {
        let parents = Set(paths.map { ($0 as NSString).deletingLastPathComponent })
        guard parents.count == 1, let parent = parents.first, !parent.isEmpty, parent != "/" else {
            return nil
        }
        return parent
    }

    /// `path` written in terms of a panel folder, or nil when it is under neither.
    private static func folded(_ path: String, context: MacroContext) -> String? {
        let folders = [(context.activeDirectory, "%P"), (context.inactiveDirectory, "%T")]
            .filter { !$0.0.isEmpty }
            .sorted { $0.0.count > $1.0.count }
        for (folder, token) in folders {
            if path == folder { return token }
            if path.hasPrefix(folder + "/") { return token + String(path.dropFirst(folder.count)) }
        }
        return nil
    }

    /// A generalised row as a sentence, with the placeholders spelled out.
    ///
    /// `MacroPlan.describe` renders a template as the template — "Move %S into “2026-08”" — which is
    /// exact and is not what somebody who has just ticked a checkbox is reading for. The tokens are the
    /// five the file uses; anything else is left as written, because inventing a phrase for a token
    /// this does not know would be worse than showing it.
    public static func spelledOut(_ text: String) -> String {
        text
            .replacingOccurrences(of: "%S", with: "the selection")
            .replacingOccurrences(of: "%P", with: "this folder")
            .replacingOccurrences(of: "%T", with: "the other folder")
            .replacingOccurrences(of: "%N", with: "the file under the cursor")
    }

    static func step(tool: String, argumentsJSON: String) -> MacroStep? {
        guard let data = argumentsJSON.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }
        var arguments: [String: MacroArgument] = [:]
        for (key, value) in dict {
            guard let argument = argument(for: value) else { return nil }
            arguments[key] = argument
        }
        return MacroStep(tool: tool, arguments: arguments)
    }

    /// A logged JSON value as a macro argument.
    ///
    /// Refuses anything a macro argument cannot hold — a nested object, a mixed array — rather than
    /// flattening it into something that looks close. `NSNumber` has to be tested for booleanness
    /// before numberness: JSONSerialization gives `true` as an NSNumber, and read as a number it would
    /// turn a flag into `1`.
    private static func argument(for value: Any) -> MacroArgument? {
        if let s = value as? String { return .text(s) }
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return .flag(n.boolValue) }
            return .number(n.doubleValue)
        }
        if let list = value as? [String] { return .list(list) }
        if let list = value as? [Any], list.isEmpty { return .list([]) }
        return nil
    }
}
