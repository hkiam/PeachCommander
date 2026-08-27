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

    public init(activeDirectory: String, inactiveDirectory: String = "", cursorPath: String? = nil,
                selection: [String] = [], startedAt: Date) {
        self.activeDirectory = activeDirectory
        self.inactiveDirectory = inactiveDirectory
        self.cursorPath = cursorPath
        self.selection = selection
        self.startedAt = startedAt
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
        if let step = stepReference(trimmed) {
            let value = try stepValue(step, results: results)
            if case .list(let l) = value, l.isEmpty {
                throw MacroPlaceholderError.expandedToNothing("%{\(step)}")
            }
            return value
        }

        // Brace tokens first: ParamExpander passes an unknown `%x` through verbatim, so `%{…}` would
        // survive it untouched — but only by luck, and relying on that would make this depend on the
        // expander's handling of a token it has never heard of.
        var text = try expandBraces(in: template, context: context, results: results)

        // `%S` inside a longer string has no list to become, so it falls back to the button bar's
        // reading: the leaf names, space-separated. Unquoted, because a macro argument is a value and
        // not a shell word — quoting it would put literal apostrophes into a file name.
        text = ParamExpander.expand(text, context: context.paramContext, quoting: false)
        return .text(text)
    }

    /// `%{1}` → `"1"`, or nil when `trimmed` is not a bare step reference.
    private static func stepReference(_ trimmed: String) -> String? {
        guard trimmed.hasPrefix("%{"), trimmed.hasSuffix("}") else { return nil }
        let inner = String(trimmed.dropFirst(2).dropLast())
        guard !inner.isEmpty, inner.allSatisfy(\.isNumber) else { return nil }
        return inner
    }

    /// An earlier step's payload as an argument.
    ///
    /// Only the two shapes that need no interpretation: a JSON string becomes text, a JSON array of
    /// strings becomes a list. Anything else — an object, a number, a payload that is not JSON — is
    /// refused rather than guessed at, because guessing here means passing the wrong paths to a
    /// `move`. No result schema is invented for tools that do not have one.
    private static func stepValue(_ step: String, results: [String: Data?]) throws -> ResolvedArgument {
        guard let entry = results[step] else { throw MacroPlaceholderError.unknownStepReference(step) }
        // `.fragmentsAllowed`, because the two shapes accepted here are both fragments at the top
        // level. A tool returning a bare `"/tmp/merged.csv"` is the most useful case there is for
        // chaining, and without this flag it was the one case that could never be read.
        guard let data = entry,
              let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else { throw MacroPlaceholderError.unknownStepReference(step) }
        if let s = json as? String { return .text(s) }
        if let l = json as? [String] { return .list(l) }
        throw MacroPlaceholderError.unknownStepReference(step)
    }

    /// Substitute every `%{…}` in `template`.
    private static func expandBraces(in template: String, context: MacroContext,
                                     results: [String: Data?]) throws -> String {
        guard template.contains("%{") else { return template }
        var out = ""
        var rest = Substring(template)
        while let open = rest.range(of: "%{") {
            out += rest[rest.startIndex..<open.lowerBound]
            guard let close = rest[open.upperBound...].firstIndex(of: "}") else {
                // Unterminated: emit the rest verbatim. A template a person is still typing must not
                // become an error somewhere else.
                out += rest[open.lowerBound...]
                return out
            }
            let token = String(rest[open.upperBound..<close])
            out += try braceValue(token, context: context, results: results)
            rest = rest[rest.index(after: close)...]
        }
        out += rest
        return out
    }

    private static func braceValue(_ token: String, context: MacroContext,
                                   results: [String: Data?]) throws -> String {
        if token.allSatisfy(\.isNumber), !token.isEmpty {
            switch try stepValue(token, results: results) {
            case .text(let s):   return s
            // A list inside a longer string has to become *something*; a comma is the one separator
            // that is not also a legal path character on this platform.
            case .list(let l):   return l.joined(separator: ", ")
            case .number(let d): return String(describing: d)
            case .flag(let b):   return String(b)
            }
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
