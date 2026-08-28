// SPDX-License-Identifier: Apache-2.0
// MacroPlaceholders.swift — resolving a macro step's argument templates (F-478).
//
// Two forms, and the split is not cosmetic:
//
//   Bare letters — %P %N %T %M %S — are the Total Commander tokens the button bar and usercmd.ini
//   already use, and they mean here exactly what they mean there. A user who has written a button
//   has already learned them. Text values are expanded through `ParamExpander` itself, so the two
//   cannot drift apart.
//
//   Braces — %{date:yyyy-MM}, %{1} — are extensions. They are in braces because the letters are
//   taken: `%M` is "the name under the cursor in the other panel", so a date macro could not spell
//   month as `%M` without silently meaning something else in a button. Measured against the
//   alternative of a second token table, this keeps one.
//
// ONE deliberate difference from the button bar, and it is the important one: there, `%S` becomes a
// list of shell words, quoted for a command line. Here it becomes a JSON *array of absolute paths*,
// because that is what `copy`, `move` and `move_to_trash` take. A selection expanded into a single
// space-joined string would be one file name containing spaces to every one of them.

import Foundation
import PCFoundation

/// The panel state a macro's templates are resolved against.
///
/// `selection` holds absolute paths, unlike `ParamContext.selectedNames`, which holds leaf names.
/// Both are needed: the leaf names are what `%N`-style tokens mean, the absolute paths are what the
/// tools take.
public struct MacroContext: Sendable, Equatable {
    public var activeDirectory: String
    public var inactiveDirectory: String
    public var cursorPath: String?
    public var selection: [String]
    /// The moment the macro started, for `%{date:…}`. Passed in rather than read from the clock, so
    /// a macro's steps all agree about "now" and so a test can pin it.
    public var startedAt: Date
    /// What the user answered for each `%{ask:…}` in this run, keyed by the question.
    ///
    /// Collected once, *before* the plan is built, and carried unchanged from there — which is the
    /// only arrangement under which the rows a person approved are the rows that run. Asking when the
    /// step is reached would put the value after the approval, and the approved row would have been a
    /// guess about it.
    public var answers: [String: String]

    public init(activeDirectory: String, inactiveDirectory: String = "", cursorPath: String? = nil,
                selection: [String] = [], startedAt: Date, answers: [String: String] = [:]) {
        self.activeDirectory = activeDirectory
        self.inactiveDirectory = inactiveDirectory
        self.cursorPath = cursorPath
        self.selection = selection
        self.startedAt = startedAt
        self.answers = answers
    }

    /// The same state in the button bar's vocabulary, so text templates go through the one expander.
    var paramContext: ParamContext {
        ParamContext(sourceDir: activeDirectory,
                     cursorName: cursorPath.map { ($0 as NSString).lastPathComponent } ?? "",
                     targetDir: inactiveDirectory,
                     targetName: "",
                     selectedNames: selection.map { ($0 as NSString).lastPathComponent })
    }
}

/// A value a macro asks for when it runs — `%{ask:Which folder?}`, or with a default after the first
/// `=`: `%{ask:Which folder?=Archive}`.
///
/// The one thing a macro has that a list of fixed steps does not, and the reason it is a *token*
/// rather than a step type: "move the selection into a folder you name" is the commonest macro there
/// is, and expressing it otherwise would need either a variable or a fixed destination. This needs
/// neither, and keeps the promise the whole design rests on — the macro is still a list of rows a
/// person reads, and by the time they read it the answers are already in them.
public struct MacroQuestion: Sendable, Equatable, Hashable {
    /// What the user is asked. Written by whoever wrote the macro, so it is their words in their
    /// language and is never translated.
    public let prompt: String
    /// What the field starts out holding.
    public let defaultValue: String
    /// Whether the macro supplied one. A question without a default may still be answered with an
    /// empty string; the difference is what happens when nobody is there to ask.
    public let hasDefault: Bool

    static let tokenPrefix = "ask:"

    /// Parses the inside of a `%{…}`, or nil when it is not an `ask:` token.
    public init?(_ token: String) {
        guard token.hasPrefix(Self.tokenPrefix) else { return nil }
        let body = String(token.dropFirst(Self.tokenPrefix.count))
        // Split at the *first* `=`. A prompt containing one is rare and can be written after the
        // default; a rule that hunted for the last would make "Name = ?" mean something surprising.
        if let separator = body.firstIndex(of: "=") {
            prompt = String(body[body.startIndex..<separator]).trimmingCharacters(in: .whitespaces)
            defaultValue = String(body[body.index(after: separator)...])
            hasDefault = true
        } else {
            prompt = body.trimmingCharacters(in: .whitespaces)
            defaultValue = ""
            hasDefault = false
        }
        guard !prompt.isEmpty else { return nil }
    }
}

/// What a macro run has to fix *before* its plan is built, and then hold unchanged.
///
/// Both halves are here for the same reason: the rows a person approves have to be the rows that run.
/// A clock read again at execution time can cross a month boundary between the two; an answer asked
/// for again can come back different. Neither is likely and both are silent, which is what makes them
/// worth ruling out rather than watching for.
public struct MacroInputs: Sendable, Equatable {
    public var startedAt: Date
    public var answers: [String: String]

    public init(startedAt: Date = Date(), answers: [String: String] = [:]) {
        self.startedAt = startedAt
        self.answers = answers
    }
}

/// A resolved argument: JSON-ready.
enum ResolvedArgument: Equatable {
    case text(String)
    case list([String])
    case number(Double)
    case flag(Bool)

    var jsonValue: Any {
        switch self {
        case .text(let s):   return s
        case .list(let l):   return l
        case .number(let d): return d == d.rounded() && abs(d) < 1e15 ? Int(d) : d
        case .flag(let b):   return b
        }
    }
}

enum MacroPlaceholderError: Error, Equatable {
    /// A `%{N}` naming a step that has not run (or does not exist).
    case unknownStepReference(String)
    /// A `%{N.field}` whose step ran, but whose result has no such value — or has one that is neither
    /// a path nor a list of paths. Distinct from `unknownStepReference` because the advice differs:
    /// there the step is wrong, here the field is, and the step's result says which fields exist.
    case unknownStepField(step: String, field: String)
    /// A `%{ask:…}` whose question was never put to anybody. Not a user error: it means the run
    /// reached the resolver without going through the asking, which is a wiring mistake.
    case unanswered(String)
    /// A token that stands for a list expanded to an empty one — `%S` with nothing selected, or a
    /// `%{N}` whose step produced no paths.
    ///
    /// An error rather than an empty argument, for the reason `PlanRows` already gives about striking
    /// out every row: a `move` with no sources is not a smaller move, it is a request that no longer
    /// says anything, and running it reports success for having done nothing. Measured — a macro run
    /// with no selection created the destination folder, reported both steps `ok`, and moved nothing.
    ///
    /// Only for *expanded* tokens. A list written out as `[]` in the file is left alone: `set_tags`
    /// with an empty list is how tags are removed, and that is a real instruction.
    case expandedToNothing(String)
}

public enum MacroPlaceholders {

    /// The selection token, and the only bare letter whose macro meaning differs from the button
    /// bar's. Handled before `ParamExpander` ever sees the template.
    static let selectionToken = "%S"

    /// Every question `macro` asks, in the order they are first written, without repeats.
    ///
    /// Once per *question*, not once per occurrence: a macro that names the same folder in step two and
    /// step four is asking one question, and putting it twice would be asking the user to keep two
    /// answers in agreement by hand. Two `ask:` tokens with the same prompt and different defaults are
    /// still one question — the first default wins, because that is the one the reader met first.
    public static func questions(in macro: Macro) -> [MacroQuestion] {
        var seen = Set<String>()
        var out: [MacroQuestion] = []
        for step in macro.steps {
            // Sorted, so a macro's questions come out in the same order every time. A dictionary's
            // iteration order is not stable across runs, and a dialog whose fields move between two
            // openings of the same macro is one nobody can fill in from memory.
            for key in step.arguments.keys.sorted() {
                let templates: [String]
                switch step.arguments[key] {
                case .text(let t):  templates = [t]
                case .list(let l):  templates = l
                default:            templates = []
                }
                for template in templates {
                    for question in questions(in: template) where seen.insert(question.prompt).inserted {
                        out.append(question)
                    }
                }
            }
        }
        return out
    }

    /// The `ask:` tokens in one template.
    static func questions(in template: String) -> [MacroQuestion] {
        guard template.contains("%{") else { return [] }
        var out: [MacroQuestion] = []
        var rest = Substring(template)
        while let open = rest.range(of: "%{") {
            guard let close = rest[open.upperBound...].firstIndex(of: "}") else { break }
            if let question = MacroQuestion(String(rest[open.upperBound..<close])) { out.append(question) }
            rest = rest[rest.index(after: close)...]
        }
        return out
    }

    /// Resolve one step's arguments against `context` and the results of the steps already run.
    ///
    /// `results` is indexed by step id (`"1"`, `"2"`, …) and holds each earlier step's payload as it
    /// came back from the core.
    static func resolve(_ arguments: [String: MacroArgument], context: MacroContext,
                        results: [String: Data?]) throws -> [String: ResolvedArgument] {
        var out: [String: ResolvedArgument] = [:]
        for (key, value) in arguments {
            switch value {
            case .number(let d): out[key] = .number(d)
            case .flag(let b):   out[key] = .flag(b)
            case .list(let l):
                // Each element resolved as text, then flattened: an element that is a bare list
                // token contributes its whole list, so ["%S", "%T/keep.txt"] is a valid source list.
                var flat: [String] = []
                for element in l {
                    switch try resolveTemplate(element, context: context, results: results) {
                    case .list(let inner): flat.append(contentsOf: inner)
                    case .text(let s):     flat.append(s)
                    case .number(let d):   flat.append(String(describing: d))
                    case .flag(let b):     flat.append(String(b))
                    }
                }
                out[key] = .list(flat)
                // An explicit list is the user's own, so `[]` written out stays `[]`. But a list whose
                // elements were all tokens that expanded to nothing is the empty-selection case again,
                // wearing brackets.
                if flat.isEmpty, !l.isEmpty {
                    throw MacroPlaceholderError.expandedToNothing(l.joined(separator: ", "))
                }
            case .text(let template):
                out[key] = try resolveTemplate(template, context: context, results: results)
            }
        }
        return out
    }

    /// Resolve a single template.
    ///
    /// A template that is *exactly* one list-valued token becomes a list; anything else becomes a
    /// string. That rule is what lets `"sources": "%S"` read naturally in the file while
    /// `"destination": "%T/%{date:yyyy-MM}"` still works — and it is checked before substitution, so
    /// a selection containing a `%` cannot turn a string into a list.
    static func resolveTemplate(_ template: String, context: MacroContext,
                                results: [String: Data?]) throws -> ResolvedArgument {
        let trimmed = template.trimmingCharacters(in: .whitespaces)
        if trimmed == selectionToken {
            guard !context.selection.isEmpty else {
                throw MacroPlaceholderError.expandedToNothing(selectionToken)
            }
            return .list(context.selection)
        }
        if let reference = StepReference(trimmed.hasPrefix("%{") && trimmed.hasSuffix("}")
                                            ? String(trimmed.dropFirst(2).dropLast()) : "") {
            let value = try stepValue(reference, results: results)
            if case .list(let l) = value, l.isEmpty {
                throw MacroPlaceholderError.expandedToNothing(trimmed)
            }
            return value
        }

        // ONE pass, through the one expander. Both token families are substituted by
        // `ParamExpander.expand` as it walks the template, so nothing a step result or a file name
        // contains is ever read as a template in turn — see the `brace` parameter's documentation for
        // the defect that arrangement fixes.
        //
        // `%S` inside a longer string has no list to become, so it falls back to the button bar's
        // reading: the leaf names, space-separated. Unquoted, because a macro argument is a value and
        // not a shell word — quoting it would put literal apostrophes into a file name.
        let text = try ParamExpander.expand(template, context: context.paramContext, quoting: false,
                                            brace: { token in
            try braceValue(token, context: context, results: results)
        })
        return .text(text)
    }

    /// A `%{…}` token that names an earlier step's result: `1`, or `2.destination`.
    ///
    /// The field selector exists because almost nothing returns a bare value. `%{2}` was written for
    /// "a tool returning `/tmp/merged.csv`", and no tool in the catalogue does: every payload that is
    /// not `nil` is a JSON *object*, so the documented way to use one step's output in the next could
    /// never resolve. `%{2.destination}` reaches the one value out of it that the next step wants.
    struct StepReference: Equatable {
        let step: String
        let field: String?

        /// Parses the inside of the braces, or nil when it is not a step reference at all.
        init?(_ inner: String) {
            let parts = inner.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            guard let head = parts.first, !head.isEmpty, head.allSatisfy(\.isNumber) else { return nil }
            step = String(head)
            guard parts.count == 2 else { field = nil; return }
            let name = String(parts[1])
            // A trailing dot names no field; treating it as "no field" would silently answer with the
            // whole payload instead of saying the token is wrong.
            guard !name.isEmpty else { return nil }
            field = name
        }

        var text: String { field.map { "%{\(step).\($0)}" } ?? "%{\(step)}" }
    }

    /// An earlier step's payload — or one named value out of it — as an argument.
    private static func stepValue(_ reference: StepReference,
                                  results: [String: Data?]) throws -> ResolvedArgument {
        guard let entry = results[reference.step] else {
            throw MacroPlaceholderError.unknownStepReference(reference.step)
        }
        // `.fragmentsAllowed`, because a bare string or array is a fragment at the top level. No tool
        // in this build returns one, but a plugin-contributed tool may, and the flag costs nothing.
        guard let data = entry,
              let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else { throw MacroPlaceholderError.unknownStepReference(reference.step) }
        guard let field = reference.field else { return try value(of: json, reference: reference) }
        guard let object = json as? [String: Any], let selected = object[field] else {
            throw MacroPlaceholderError.unknownStepField(step: reference.step, field: field)
        }
        return try value(of: selected, reference: reference)
    }

    /// A decoded payload — or one field out of it — as an argument.
    ///
    /// Only the two shapes that need no interpretation: a JSON string becomes text, a JSON array of
    /// strings becomes a list. Anything else — an object, a number, a mixed array — is refused rather
    /// than guessed at, because guessing here means passing the wrong paths to a `move`. No result
    /// schema is invented for tools that do not have one.
    private static func value(of json: Any, reference: StepReference) throws -> ResolvedArgument {
        if let s = json as? String { return .text(s) }
        if let l = json as? [String] { return .list(l) }
        if let field = reference.field {
            throw MacroPlaceholderError.unknownStepField(step: reference.step, field: field)
        }
        throw MacroPlaceholderError.unknownStepReference(reference.step)
    }

    private static func braceValue(_ token: String, context: MacroContext,
                                   results: [String: Data?]) throws -> String {
        if let reference = StepReference(token) {
            switch try stepValue(reference, results: results) {
            case .text(let s):   return s
            // A list inside a longer string has to become *something*; a comma is the one separator
            // that is not also a legal path character on this platform.
            case .list(let l):   return l.joined(separator: ", ")
            case .number(let d): return String(describing: d)
            case .flag(let b):   return String(b)
            }
        }
        if let question = MacroQuestion(token) {
            // The answer, or the default when the user left it as it was. An answer that is present
            // and empty is still an answer — clearing a field is how `set_comment` removes a comment,
            // and second-guessing that would take the choice away.
            if let answer = context.answers[question.prompt] { return answer }
            guard question.hasDefault else {
                throw MacroPlaceholderError.unanswered(question.prompt)
            }
            return question.defaultValue
        }
        if token.hasPrefix("date:") {
            let format = String(token.dropFirst("date:".count))
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format.isEmpty ? "yyyy-MM-dd" : format
            return f.string(from: context.startedAt)
        }
        // Unknown token, left as it was written. The macro editor validates; the runner does not
        // invent a value, and a step that ends up with a literal `%{whatever}` in a path fails
        // visibly at the tool rather than quietly on a path that lost a component.
        return "%{" + token + "}"
    }

    /// The arguments as JSON, ready for `AutomationCore.invoke`.
    static func json(_ resolved: [String: ResolvedArgument]) throws -> Data? {
        guard !resolved.isEmpty else { return nil }
        return try JSONSerialization.data(
            withJSONObject: resolved.mapValues(\.jsonValue), options: [.sortedKeys])
    }
}
