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

extension MacroArgument {
    /// The value as it goes into JSON — and as `MacroPlan.describe` wants it, so a step can be
    /// described without first being resolved against a context. A template stays a template here:
    /// `%S` describes as `%S`, which is what a row showing an *unresolved* step should say.
    public var jsonValue: Any {
        switch self {
        case .text(let s):   return s
        case .list(let l):   return l
        case .number(let d): return d == d.rounded() && abs(d) < 1e15 ? Int(d) : d
        case .flag(let b):   return b
        }
    }
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
    /// Fails closed, three times over. A step naming a tool this build does not have counts as
    /// `.write` (the same rule and the same reason as `AutomationCommandInfo.unknown`); a
    /// `run_command` step counts as `.write` unless a resolver says otherwise (see below); and an
    /// empty macro counts as `.read` because it does nothing. Ranked by how much a mistake costs, not
    /// by the declaration order of the enum.
    ///
    /// **`run_command` is the case that matters.** Its *declared* capability is `.runCommand`, which
    /// is not a mutating capability, so a macro whose steps are all `run_command` used to be decided
    /// `.allow` — no plan, no confirmation — and then ran `cm_DeleteReal` under the raised autonomy
    /// the approval was supposed to buy. Measured: a one-step macro deleting files under
    /// `PermissionPolicy.standard`, with nothing shown to the user. The floor here closes that
    /// without needing a host; `capability(of:tools:resolvingCommands:)` then buys the precision
    /// back, so a macro that only sorts a panel is not gated like a delete.
    public static func capability(of macro: Macro,
                                  tools: [ToolDefinition] = AutomationCatalog.tools) -> Capability {
        capability(of: macro, tools: tools, commandCapabilities: [:])
    }

    /// The same, with `run_command` steps resolved to what their command really does.
    ///
    /// The resolver is the host's own classification — the one `invoke` already applies to a direct
    /// `run_command` call — so a macro and a bare tool call are judged by the same rule. A command the
    /// resolver has never heard of keeps the `.write` floor.
    public static func capability(of macro: Macro, tools: [ToolDefinition],
                                  resolvingCommands resolve: (String) async -> Capability?) async -> Capability {
        var resolved: [String: Capability] = [:]
        for step in macro.steps where step.tool == "run_command" {
            guard case .text(let id)? = step.arguments["command_id"], resolved[id] == nil else { continue }
            if let capability = await resolve(id) { resolved[id] = capability }
        }
        return capability(of: macro, tools: tools, commandCapabilities: resolved)
    }

    private static func capability(of macro: Macro, tools: [ToolDefinition],
                                   commandCapabilities: [String: Capability]) -> Capability {
        let byName = Dictionary(tools.map { ($0.name, $0.capability) }, uniquingKeysWith: { a, _ in a })
        return macro.steps.reduce(Capability.read) { worst, step in
            var cap = byName[step.tool] ?? .write
            if step.tool == "run_command" {
                if case .text(let id)? = step.arguments["command_id"] {
                    cap = commandCapabilities[id] ?? .write
                } else {
                    cap = .write
                }
            }
            return rank(cap) > rank(worst) ? cap : worst
        }
    }

    /// The prefix every macro command name carries — `Macro.commandName`, and nothing else: the
    /// registry drops a macro whose name collides with a built-in, and every built-in is `cm_*`.
    ///
    /// So a `run_command` step naming an `mc_*` id is a macro calling a macro, and refusing it is the
    /// same rule the runner applies to a literal `run_macro` step. Without this the guard is a
    /// formality: `run_command("mc_itself")` reaches the command registry, which runs the macro, which
    /// runs the step again — and because `runCommandNamed` dispatches into a detached main-actor task
    /// there is nothing to unwind, so it does not recurse so much as accumulate until the window stops
    /// answering.
    public static let macroCommandPrefix = "mc_"

    /// What is wrong with `macro`, in the order the steps are written — empty when it can be run.
    ///
    /// Checked *before* the plan is proposed, for the reason `refusalBeforeAsking` already gives about
    /// `rename_batch`: an action that cannot work must not be put in front of the user for approval,
    /// and for a macro the cost is higher than a wasted decision. A misspelled tool in step four is
    /// found after steps one to three have already changed the disk.
    ///
    /// Only what can be decided from the macro itself. Whether a path exists, whether a mask matches
    /// anything, whether the destination is writable — none of that is knowable here, and pretending
    /// otherwise would trade a late honest failure for an early wrong refusal.
    public static func problems(of macro: Macro,
                                tools: [ToolDefinition] = AutomationCatalog.tools) -> [String] {
        let byName = Dictionary(tools.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        var problems: [String] = []
        for (index, step) in macro.steps.enumerated() {
            let id = Macro.stepID(index)
            if step.tool == "run_macro" {
                problems.append("step \(id): a macro cannot run another macro")
                continue
            }
            if step.tool == "run_command", case .text(let command)? = step.arguments["command_id"],
               command.hasPrefix(macroCommandPrefix) {
                problems.append("step \(id): “\(command)” is a macro, and a macro cannot run another macro")
                continue
            }
            guard let tool = byName[step.tool] else {
                problems.append("step \(id): this build has no tool called “\(step.tool)”")
                continue
            }
            for parameter in tool.parameters where parameter.required {
                if step.arguments[parameter.name] == nil {
                    problems.append("step \(id) (\(step.tool)): the argument “\(parameter.name)” is missing")
                }
            }
        }
        return problems
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
        let needs = dependencies(of: macro)
        return macro.steps.enumerated().map { index, step in
            let id = Macro.stepID(index)
            return PlanItem(id: id, text: step.note ?? describe(step), dependsOn: needs[id] ?? [])
        }
    }

    /// The rows with every placeholder that *can* be resolved resolved, so they read as the actions
    /// they are: "Move a.txt into “2026-08”".
    ///
    /// A step whose argument references an earlier step's result cannot be resolved before that step
    /// has run, and such a row says so rather than showing a guess — the one case the unresolved form
    /// was right about.
    public static func rows(of macro: Macro, resolvedWith context: MacroContext) -> [PlanItem] {
        let needs = dependencies(of: macro)
        return macro.steps.enumerated().map { index, step in
            let id = Macro.stepID(index)
            if let note = step.note { return PlanItem(id: id, text: note, dependsOn: needs[id] ?? []) }
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
            let phrase = self.phrase(tool: step.tool, arguments: arguments)
            return PlanItem(id: id, text: phrase?.english ?? describe(step),
                            dependsOn: needs[id] ?? [], phrase: phrase)
        }
    }

    /// What to show in place of an argument that cannot be resolved until an earlier step has run.
    ///
    /// One piece of text whatever the tool wanted: `describe`'s list accessor reads a lone string as a
    /// one-element list, so the same stand-in works in `sources` and in `path`. Guessing the shape from
    /// the token cannot work — a `%{1}` is list-valued in one and a path in the other, and the template
    /// says neither.
    private static func standIn(error: Error, earlier: [String]) -> String {
        switch error {
        case MacroPlaceholderError.unknownStepReference(let step):
            return StandIn.marker(.resultOfStep, [step])
        case MacroPlaceholderError.unknownStepField(let step, let field):
            // Only reachable once the step has actually produced something: before that there is no
            // result to look a field up in, and the row falls to the case above.
            return StandIn.marker(.fieldOfStep, [field, step])
        case MacroPlaceholderError.unanswered(let prompt):
            // The rows are built *after* the asking, so this is the plan of a macro whose questions
            // could not be put to anybody — a run over MCP, say. It says which one is missing.
            return StandIn.marker(.answerTo, [prompt])
        case MacroPlaceholderError.expandedToNothing(let token)
                where token == MacroPlaceholders.selectionToken:
            // A `%S` that is empty now is a problem only if nothing is going to fill it. Announcing
            // "nothing is selected" above a macro that selects its own files is worse than saying
            // nothing at all.
            return earlier.contains("set_selection")
                ? StandIn.marker(.whatAnEarlierStepSelects) : StandIn.marker(.nothingSelected)
        case MacroPlaceholderError.expandedToNothing(let token):
            return StandIn.marker(.emptyToken, [token])
        default:
            return StandIn.marker(.notWorkedOutYet)
        }
    }


    /// One line for a step with no note of its own: the tool and its arguments, shortest key first
    /// so the destination of a `move` is not buried behind its sources.
    public static func describe(_ step: MacroStep) -> String {
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
        phrase(tool: tool, argumentsJSON: argumentsJSON)?.english
    }

    /// The same row as a phrase, so the host can say it in the user's language.
    ///
    /// This is where the shapes live; `PlanPhrase.english` and the host's renderer are the two sides
    /// of it. Basenames, not paths: a macro's rows are read to tell two similar actions apart, and the
    /// folder they share is the part that does not help — the tooltip carries the whole thing.
    public static func phrase(tool: String, argumentsJSON: String?) -> PlanPhrase? {
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
        /// A few names, and "+2 more" for the rest — itself a phrase, because "more" is a word.
        func list(_ items: [String], limit: Int = 3) -> PlanValue {
            guard items.count > limit else { return .literal(items.joined(separator: ", ")) }
            return .phrase(PlanPhrase(.andMore, literals: [items.prefix(limit).joined(separator: ", ")],
                                      count: items.count - limit))
        }
        /// A value that may itself be a stand-in phrase. `standIn` writes its marker into the argument
        /// as text, and this reads it back out — so a row can be built once and said in any language.
        func value(_ raw: String) -> PlanValue { StandIn.phrase(in: raw).map(PlanValue.phrase)
                                                 ?? .literal(raw) }
        func listOrStandIn(_ key: String) -> PlanValue {
            if let one = d[key] as? String, let phrase = StandIn.phrase(in: one) {
                return .phrase(phrase)
            }
            return list(names(key))
        }

        switch tool {
        case "make_directory":
            return name("path").map { PlanPhrase(.createFolder, [value($0)]) }
        case "move", "copy":
            guard let destination = name("destination") else { return nil }
            let sources = names("sources")
            if sources.isEmpty {
                return PlanPhrase(tool == "move" ? .moveIntoUnnamed : .copyIntoUnnamed,
                                  [value(destination)])
            }
            return PlanPhrase(tool == "move" ? .moveInto : .copyInto,
                              [listOrStandIn("sources"), value(destination)])
        case "rename":
            guard let from = name("path"), let to = d["new_name"] as? String else { return nil }
            return PlanPhrase(.rename, [value(from), value(to)])
        case "rename_batch":
            return PlanPhrase(.renameBatch, count: names("old_names").count)
        case "move_to_trash":
            return PlanPhrase(.trash, [listOrStandIn("paths")])
        case "delete_permanently":
            return PlanPhrase(.deleteForever, [listOrStandIn("paths")])
        case "set_comment":
            guard let path = name("path") else { return nil }
            let comment = (d["comment"] as? String) ?? ""
            return comment.isEmpty ? PlanPhrase(.clearComment, [value(path)])
                                   : PlanPhrase(.setComment, [value(path), value(comment)])
        case "set_tags":
            return name("path").map {
                PlanPhrase(.setTags, [value($0), list(d["tags"] as? [String] ?? [])])
            }
        case "create_file":
            return name("path").map { PlanPhrase(.createFile, [value($0)]) }
        case "write_file":
            return name("path").map { PlanPhrase(.writeFile, [value($0)]) }
        case "merge_files":
            return name("destination").map {
                PlanPhrase(.mergeFiles, [value($0)], count: names("sources").count)
            }
        case "set_config":
            guard let key = d["key"] as? String else { return nil }
            return PlanPhrase(.setConfig, [value(key), value((d["value"] as? String) ?? "")])
        case "set_selection":
            return (d["mask"] as? String).map { PlanPhrase(.selectMask, [value($0)]) }
        case "open_path", "open_in_panel":
            return name("path").map { PlanPhrase(.openPath, [value($0)]) }
        case "run_command":
            return (d["command_id"] as? String).map { PlanPhrase(.runCommand, [value($0)]) }
        case "run_shell":
            return (d["command"] as? String).map { PlanPhrase(.runShell, [value($0)]) }
        default:
            // An unrecognised tool still gets a row, named by its tool and its values' basenames — the
            // alternative is a blank line for anything added to the catalogue after this switch.
            let values = d.keys.sorted().compactMap { key -> String? in
                if let s = d[key] as? String { return (s as NSString).lastPathComponent }
                if let l = d[key] as? [String] {
                    return list(l.map { ($0 as NSString).lastPathComponent }).english
                }
                return nil
            }
            return PlanPhrase(.otherTool, literals: [tool, values.joined(separator: " ")])
        }
    }

    /// The same, from an already-decoded argument dictionary.
    public static func describe(tool: String, arguments: [String: Any]) -> String? {
        phrase(tool: tool, arguments: arguments)?.english
    }

    /// The phrase, from an already-decoded argument dictionary.
    public static func phrase(tool: String, arguments: [String: Any]) -> PlanPhrase? {
        guard let data = try? JSONSerialization.data(withJSONObject: arguments),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return phrase(tool: tool, argumentsJSON: json)
    }

    /// Which earlier steps each step cannot do without, by step id.
    ///
    /// Two kinds of dependency, and both are real enough to have produced a half-run macro:
    ///
    ///   * A `%{n}` or `%{n.field}` names an earlier step's result outright. Skip that step and this
    ///     one fails, after everything between them has already happened.
    ///   * A `%S` depends on the last `set_selection` before it, when there is one. Skip *that* and the
    ///     step no longer acts on the files the macro chose — it acts on whatever the user happened to
    ///     have selected, which is the one outcome nobody asked for. Only counted when a
    ///     `set_selection` precedes it: a macro written to work on the user's own selection has no such
    ///     dependency and must not be reported as having one.
    static func dependencies(of macro: Macro) -> [String: [String]] {
        var out: [String: [String]] = [:]
        var lastSelectionStep: String?
        for (index, step) in macro.steps.enumerated() {
            let id = Macro.stepID(index)
            var needs: [String] = []
            for value in step.arguments.values {
                let templates: [String]
                switch value {
                case .text(let t): templates = [t]
                case .list(let l): templates = l
                case .number, .flag: templates = []
                }
                for template in templates {
                    needs += referencedSteps(in: template)
                    if template.contains(selectionToken), let selection = lastSelectionStep {
                        needs.append(selection)
                    }
                }
            }
            // Only backwards, and only to steps that exist: a forward reference cannot be satisfied
            // anyway, and the runner reports it as such.
            let earlier = Set((0..<index).map(Macro.stepID))
            let kept = Array(Set(needs).intersection(earlier)).sorted { Int($0) ?? 0 < Int($1) ?? 0 }
            if !kept.isEmpty { out[id] = kept }
            if step.tool == "set_selection" { lastSelectionStep = id }
        }
        return out
    }

    /// The token a macro's selection placeholder is spelled with, kept here so `dependencies` does not
    /// have to reach into `MacroPlaceholders` for one character pair.
    private static let selectionToken = "%S"

    /// The step ids a template refers to — `%{2}` and `%{2.destination}` both name step 2.
    private static func referencedSteps(in template: String) -> [String] {
        guard template.contains("%{") else { return [] }
        var out: [String] = []
        var rest = Substring(template)
        while let open = rest.range(of: "%{") {
            guard let close = rest[open.upperBound...].firstIndex(of: "}") else { break }
            let token = rest[open.upperBound..<close]
            let head = token.prefix { $0.isNumber }
            if !head.isEmpty, head.count == token.count || token.dropFirst(head.count).hasPrefix(".") {
                out.append(String(head))
            }
            rest = rest[rest.index(after: close)...]
        }
        return out
    }

    /// A one-line summary for the confirmation text above the rows.
    public static func planText(of macro: Macro) -> String {
        let count = macro.steps.count
        return "Run the macro “\(macro.title)” — \(count) step\(count == 1 ? "" : "s")."
    }
}
