// SPDX-License-Identifier: Apache-2.0
// Macro.swift — a named sequence of automation steps (F-478).
//
// A macro is data, not code: a list of tool names with argument templates, stored under the config
// root as `macros.json`. It runs through the same `AutomationCore` the assistant and the MCP server
// use, so a macro cannot do anything the policy would not let a tool call do, and every step it
// takes lands in the audit log with its inverse where one exists.
//
// Deliberately not a scripting language. There are no conditions, no loops and no variables beyond
// the placeholders below. Anything that needs those is a script (F-477) — which a macro step can
// call — and keeping the two apart is what lets a macro be presented as a list of rows a person
// reads and strikes out before it runs.

import Foundation

/// One argument value in a macro step, as it appears in `macros.json`.
///
/// Encodes transparently as the underlying JSON value, so the file reads like the tool call it
/// becomes: `"destination": "%T"`, `"sources": "%S"`, `"max_bytes": 4096`.
public enum MacroArgument: Sendable, Equatable {
    /// A template string; may carry placeholders (see `MacroPlaceholders`).
    case text(String)
    /// A list whose elements are each templates.
    case list([String])
    case number(Double)
    case flag(Bool)
}

extension MacroArgument: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .text(s); return }
        if let b = try? c.decode(Bool.self) { self = .flag(b); return }
        if let d = try? c.decode(Double.self) { self = .number(d); return }
        if let l = try? c.decode([String].self) { self = .list(l); return }
        throw DecodingError.dataCorruptedError(
            in: c, debugDescription: "a macro argument must be a string, number, boolean or list of strings")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let s):   try c.encode(s)
        case .list(let l):   try c.encode(l)
        case .number(let d): try c.encode(d)
        case .flag(let b):   try c.encode(b)
        }
    }
}

/// One step: a tool from the catalogue and the arguments to call it with.
public struct MacroStep: Codable, Sendable, Equatable {
    public let tool: String
    public var arguments: [String: MacroArgument]
    /// What the row says when the macro is presented for approval. Optional — a step without one is
    /// described from its tool and arguments, which is enough for `move` and not for much else.
    public var note: String?

    public init(tool: String, arguments: [String: MacroArgument] = [:], note: String? = nil) {
        self.tool = tool; self.arguments = arguments; self.note = note
    }
}

public struct Macro: Codable, Sendable, Equatable {
    /// Stable, and part of the command name the rest of the app sees (`mc_<id>`), so it may only
    /// hold what a command id may hold. `MacroStore` sanitises on the way in.
    public let id: String
    public var title: String
    /// An SF Symbol name for the button bar, when the user picked one.
    public var icon: String?
    public var steps: [MacroStep]

    public init(id: String, title: String, icon: String? = nil, steps: [MacroStep] = []) {
        self.id = id; self.title = title; self.icon = icon; self.steps = steps
    }

    /// The command name this macro answers to everywhere a `cm_*` name is accepted.
    public var commandName: String { "mc_" + id }

    /// Step ids are positional, and that is on purpose: the id has to mean the same thing to the
    /// sheet that shows the rows and to the runner that skips them, and a reordered macro is a
    /// different macro. One-based, because the rows are read by a person.
    public static func stepID(_ index: Int) -> String { String(index + 1) }
}

/// What a macro amounts to, so the permission gate can be applied to the macro as a whole rather
/// than to each of its steps in turn.
public enum MacroPlan {

    /// The capability invoking this macro really needs: the most demanding of its steps.
    ///
    /// Fails closed, twice over. A step naming a tool this build does not have counts as `.write`
    /// (the same rule and the same reason as `AutomationCommandInfo.unknown`), and an empty macro
    /// counts as `.read` because it does nothing. Ranked by how much a mistake costs, not by the
    /// declaration order of the enum.
    public static func capability(of macro: Macro,
                                  tools: [ToolDefinition] = AutomationCatalog.tools) -> Capability {
        let byName = Dictionary(tools.map { ($0.name, $0.capability) }, uniquingKeysWith: { a, _ in a })
        return macro.steps.reduce(Capability.read) { worst, step in
            let cap = byName[step.tool] ?? .write
            return rank(cap) > rank(worst) ? cap : worst
        }
    }

    private static func rank(_ c: Capability) -> Int {
        switch c {
        case .read:       return 0
        case .navigate:   return 1
        case .network:    return 2
        case .runCommand: return 3
        case .config:     return 4
        case .write:      return 5
        case .delete:     return 6
        case .script:     return 7
        case .shell:      return 8
        }
    }

    /// The macro as rows the user can strike out — one row per step, in order.
    ///
    /// Without a context the rows show the templates as written. That is honest and unreadable: a row
    /// saying `move destination=%T/%{date:yyyy-MM} sources=%S` asks the reader to know the placeholder
    /// language before they can agree to anything, and this dialog is the one place a person who has
    /// never seen it is asked to decide.
    public static func rows(of macro: Macro) -> [PlanItem] {
        macro.steps.enumerated().map { index, step in
            PlanItem(id: Macro.stepID(index), text: step.note ?? describe(step))
        }
    }

    /// The rows with every placeholder that *can* be resolved resolved, so they read as the actions
    /// they are: "Move a.txt into “2026-08”".
    ///
    /// A step whose argument references an earlier step's result cannot be resolved before that step
    /// has run, and such a row says so rather than showing a guess — the one case the unresolved form
    /// was right about.
    public static func rows(of macro: Macro, resolvedWith context: MacroContext) -> [PlanItem] {
        macro.steps.enumerated().map { index, step in
            let id = Macro.stepID(index)
            if let note = step.note { return PlanItem(id: id, text: note) }
            // Argument by argument, not all-or-nothing: one placeholder that cannot be resolved yet
            // used to drop the whole row back to the raw template, so a reader saw
            // `move destination=%T/%{date:yyyy-MM} sources=%S` because of the one part that was still
            // to come. Everything that *can* be resolved is, and only the rest stands in for itself.
            let earlier = macro.steps.prefix(index).map(\.tool)
            var arguments: [String: Any] = [:]
            for (key, value) in step.arguments {
                do {
                    let one = try MacroPlaceholders.resolve([key: value], context: context, results: [:])
                    if let resolved = one[key] { arguments[key] = resolved.jsonValue }
                } catch {
                    arguments[key] = standIn(error: error, earlier: earlier)
                }
            }
            return PlanItem(id: id,
                            text: describe(tool: step.tool, arguments: arguments) ?? describe(step))
        }
    }

    /// What to show in place of an argument that cannot be resolved until an earlier step has run.
    ///
    /// One piece of text whatever the tool wanted: `describe`'s list accessor reads a lone string as a
    /// one-element list, so the same stand-in works in `sources` and in `path`. Guessing the shape from
    /// the token cannot work — a `%{1}` is list-valued in one and a path in the other, and the template
    /// says neither.
    private static func standIn(error: Error, earlier: [String]) -> String {
        let text: String
        switch error {
        case MacroPlaceholderError.unknownStepReference(let step):
            text = "the result of step \(step)"
        case MacroPlaceholderError.expandedToNothing(let token)
                where token == MacroPlaceholders.selectionToken:
            // A `%S` that is empty now is a problem only if nothing is going to fill it. Announcing
            // "nothing is selected" above a macro that selects its own files is worse than saying
            // nothing at all.
            text = earlier.contains("set_selection") ? "what an earlier step selects"
                                                     : "nothing (nothing is selected)"
        case MacroPlaceholderError.expandedToNothing(let token):
            text = "nothing (“\(token)” is empty)"
        default:
            text = "a value that cannot be worked out yet"
        }
        return text
    }


    /// One line for a step with no note of its own: the tool and its arguments, shortest key first
    /// so the destination of a `move` is not buried behind its sources.
    static func describe(_ step: MacroStep) -> String {
        let parts = step.arguments.keys.sorted().map { key -> String in
            switch step.arguments[key] {
            case .text(let s):   return "\(key)=\(s)"
            case .list(let l):   return "\(key)=[\(l.joined(separator: ", "))]"
            case .number(let d): return "\(key)=\(d == d.rounded() ? String(Int(d)) : String(d))"
            case .flag(let b):   return "\(key)=\(b)"
            case nil:            return key
            }
        }
        return parts.isEmpty ? step.tool : "\(step.tool) \(parts.joined(separator: " "))"
    }

    /// One readable line for a step: the tool, and the names a person would recognise.
    ///
    /// Basenames, not paths. A macro's rows are read to tell two similar actions apart, and the folder
    /// they share is the part that does not help; the tooltip carries the whole thing for the case where
    /// the folder is what matters.
    public static func describe(tool: String, argumentsJSON: String?) -> String? {
        guard let json = argumentsJSON, let data = json.data(using: .utf8),
              let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }
        func name(_ key: String) -> String? {
            (d[key] as? String).map { ($0 as NSString).lastPathComponent }
        }
        /// A list argument, from either a list or a lone string.
        ///
        /// Both shapes really occur: `"sources": "%S"` is how the file is written, and a stand-in for an
        /// argument that cannot be resolved yet is one piece of text. Accepting only `[String]` made a
        /// `move` whose sources were either of those read as "Move into “2023-11”" — with the thing
        /// being moved missing from the sentence.
        func names(_ key: String) -> [String] {
            if let list = d[key] as? [String] { return list.map { ($0 as NSString).lastPathComponent } }
            if let one = d[key] as? String { return [(one as NSString).lastPathComponent] }
            return []
        }
        func list(_ items: [String], limit: Int = 3) -> String {
            items.count <= limit ? items.joined(separator: ", ")
                : items.prefix(limit).joined(separator: ", ") + " +\(items.count - limit) more"
        }
        switch tool {
        case "make_directory":
            return name("path").map { "Create the folder “\($0)”" }
        case "move", "copy":
            let verb = tool == "move" ? "Move" : "Copy"
            let sources = names("sources")
            guard let destination = name("destination") else { return nil }
            return sources.isEmpty ? "\(verb) into “\(destination)”"
                : "\(verb) \(list(sources)) into “\(destination)”"
        case "rename":
            guard let from = name("path"), let to = d["new_name"] as? String else { return nil }
            return "Rename “\(from)” to “\(to)”"
        case "rename_batch":
            return "Rename \(names("old_names").count) file(s)"
        case "move_to_trash":
            return "Move \(list(names("paths"))) to the Trash"
        case "delete_permanently":
            return "Permanently delete \(list(names("paths")))"
        case "set_comment":
            guard let path = name("path") else { return nil }
            let comment = (d["comment"] as? String) ?? ""
            return comment.isEmpty ? "Clear the comment on “\(path)”"
                                   : "Comment “\(path)”: \(comment)"
        case "set_tags":
            return name("path").map { "Tag “\($0)”: \(list(d["tags"] as? [String] ?? []))" }
        case "write_file":
            return name("path").map { "Write the file “\($0)”" }
        case "merge_files":
            return name("destination").map { "Merge \(names("sources").count) file(s) into “\($0)”" }
        case "set_config":
            guard let key = d["key"] as? String else { return nil }
            return "Set \(key) = \((d["value"] as? String) ?? "")"
        case "set_selection":
            return (d["mask"] as? String).map { "Select \($0)" }
        case "open_path", "open_in_panel":
            return name("path").map { "Open “\($0)”" }
        case "run_command":
            return (d["command_id"] as? String).map { "Run the command \($0)" }
        case "run_shell":
            return (d["command"] as? String).map { "Run “\($0)” in a terminal" }
        default:
            // An unrecognised tool still gets a row, named by its tool and its values' basenames — the
            // alternative is a blank line for anything added to the catalogue after this switch.
            let values = d.keys.sorted().compactMap { key -> String? in
                if let s = d[key] as? String { return (s as NSString).lastPathComponent }
                if let l = d[key] as? [String] { return list(l.map { ($0 as NSString).lastPathComponent }) }
                return nil
            }
            return values.isEmpty ? tool : "\(tool): \(values.joined(separator: " "))"
        }
    }

    /// The same, from an already-decoded argument dictionary.
    public static func describe(tool: String, arguments: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: arguments),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return describe(tool: tool, argumentsJSON: json)
    }

    /// A one-line summary for the confirmation text above the rows.
    public static func planText(of macro: Macro) -> String {
        let count = macro.steps.count
        return "Run the macro “\(macro.title)” — \(count) step\(count == 1 ? "" : "s")."
    }
}
