// SPDX-License-Identifier: Apache-2.0
// DefaultAutomationCore.swift - the executable Automation Core.
//
// Enforces the PermissionPolicy (refuse / confirm / allow), implements
// plan-then-confirm for gated write/delete/config actions, dispatches tool calls
// to the AutomationHostBridge, and vends the host event stream. AppKit-free and
// unit-tested against a fake bridge; PCApp supplies the real bridge.

import Foundation
import PCFoundation

public actor DefaultAutomationCore: AutomationCore {
    /// Executes a plugin-contributed tool by name + JSON args (KI-06). Returns nil if
    /// the plugin can't handle it.
    public typealias ExternalToolRouter = @Sendable (_ name: String, _ arguments: Data?) async -> AutomationOutcome?

    /// Looks a saved macro up by id (F-478). A closure rather than a `MacroStore`, so the Core never
    /// touches the file system and a test can hand in three macros without one.
    public typealias MacroLookup = @Sendable () -> [Macro]

    private let bridge: AutomationHostBridge
    private let bus: HostEventBus
    private let externalTools: [ToolDefinition]
    private let externalRouter: ExternalToolRouter?
    private let macroLookup: MacroLookup?
    /// Plans awaiting confirmation. The policy is kept with the plan: a confirmation is an answer to
    /// the question that was asked, and the permissions in force when it was asked are part of that
    /// question. Reading the current policy at confirmation time would let a plan proposed under one
    /// allow-list be carried out under another.
    ///
    /// `inputs` is kept for the same reason one step further: for a macro, what the rows *said*
    /// includes whatever its `%{date:…}` steps resolved to and whatever the user typed into its
    /// `%{ask:…}` fields. Taking the clock again at execution time let the approved row and the folder
    /// actually created disagree at a month boundary; asking again would be worse still.
    private var pending: [String: (tool: String, args: Data?, policy: PermissionPolicy,
                                   inputs: MacroInputs, isUndo: Bool)] = [:]
    /// Where executed actions are recorded. Nil in tests that do not care; the host supplies one.
    private let audit: AuditLog?
    /// Timestamps already used, so two actions in the same millisecond stay distinguishable
    /// (the log matches an entry on its time when marking it undone).
    private var lastStamp: Double = 0

    /// - Parameters:
    ///   - externalTools: extra tools contributed by plugins (merged into the catalogue,
    ///     policy-gated by their declared capability).
    ///   - externalRouter: executes a contributed tool by name; the host routes to the
    ///     owning plugin.
    public init(bridge: AutomationHostBridge, bus: HostEventBus = HostEventBus(),
                externalTools: [ToolDefinition] = [], externalRouter: ExternalToolRouter? = nil,
                audit: AuditLog? = nil, macros: MacroLookup? = nil) {
        self.bridge = bridge
        self.bus = bus
        self.externalTools = externalTools
        self.externalRouter = externalRouter
        self.macroLookup = macros
        self.audit = audit
    }

    /// Emit a host event to subscribers (the host calls this via `eventBus`).
    public nonisolated var eventBus: HostEventBus { bus }
    public nonisolated func events() -> AsyncStream<HostEvent> { bus.stream() }
    public nonisolated var tools: [ToolDefinition] { AutomationCatalog.tools + externalTools }
    private nonisolated func toolDefinition(named name: String) -> ToolDefinition? {
        AutomationCatalog.tool(named: name) ?? externalTools.first { $0.name == name }
    }

    public func context() async throws -> AutomationContext { try await bridge.context() }

    public func invoke(tool name: String, arguments: Data?, policy: PermissionPolicy) async throws -> AutomationOutcome {
        // Undo is its own entry point: it looks up the inverse and then goes back through this
        // method to run it, so the gate and the log apply to it exactly as to anything else.
        if name == "undo_last_action" { return try await undoLast(policy: policy) }
        return try await invoke(tool: name, arguments: arguments, policy: policy, isUndo: false)
    }

    /// - Parameter isUndo: an undo is an action and belongs in the log, but it must not itself be
    ///   offered as undoable — otherwise "undo" twice redoes what was undone and the button
    ///   ping-pongs between two states instead of walking back. Threaded through as a parameter
    ///   rather than held in a field: the actor suspends at every `await` in here, so a field
    ///   would also mislabel any tool call that arrived while an undo was in flight.
    private func invoke(tool name: String, arguments: Data?, policy: PermissionPolicy,
                        isUndo: Bool) async throws -> AutomationOutcome {
        guard let tool = toolDefinition(named: name) else { throw AutomationError.unknownTool(name) }
        // `run_command` is judged by what the command does, not by the fact that it is a command.
        // Otherwise the gate is bypassable by construction: `delete_permanently` presents a plan while
        // `run_command("cm_DeleteReal")` deletes the same files with nothing to approve.
        var capability = tool.capability
        var commandLabel: String?
        if name == "run_command", let id = try? Args(arguments).string("command_id") {
            let info = await bridge.commandInfo(id)
            capability = info.capability
            commandLabel = info.label
        }
        // Same substitution for a macro, and the same reason: the gate has to be about what will
        // happen, not about the name of the tool that starts it (F-478). A macro that cannot be found
        // keeps the declared `.write` and then fails in `run` — it must not fall through as a read.
        if name == "run_macro", let macro = macro(named: arguments) {
            // Its `run_command` steps resolved through the same host classification a direct
            // `run_command` gets, so the two are judged alike — and so a macro that only sorts a panel
            // is not held to the `.write` floor those steps otherwise carry.
            capability = await MacroPlan.capability(of: macro, tools: tools) { [bridge] id in
                await bridge.commandInfo(id).capability
            }
            commandLabel = MacroPlan.planText(of: macro)
        }
        // Whatever the macro asks for, asked once and before anything is proposed — so the rows the
        // user reads already hold their answers, and a cancelled question cancels the macro rather
        // than half of it. A bridge with nobody to ask (a socket) answers nil, and the macro is
        // refused with that as its reason instead of running with a value nobody chose.
        var inputs = MacroInputs()
        if name == "run_macro", let macro = macro(named: arguments) {
            let questions = MacroPlaceholders.questions(in: macro)
            if !questions.isEmpty {
                guard let answers = await bridge.askForValues(questions, forMacro: macro.title) else {
                    let outcome = AutomationOutcome.failed(
                        error: "The macro “\(macro.title)” asks for \(questions.count) value(s), "
                             + "and this run had nobody to ask.")
                    record(name, arguments, outcome, capability: capability, isUndo: isUndo)
                    return outcome
                }
                inputs.answers = answers
            }
        }
        // A gated action that cannot work must not be *proposed*. Asking the user to approve a rename
        // that will then fail spends the one moment of their attention on a dead end — and for a batch
        // the plan is a table they would have read carefully first. Measured: a table naming one file
        // twice was presented for approval, and only the confirmation reported the collision.
        if let refusal = await refusalBeforeAsking(tool: name, arguments: arguments) {
            let outcome = AutomationOutcome.failed(error: refusal)
            record(name, arguments, outcome, capability: capability, isUndo: isUndo)
            return outcome
        }
        switch policy.decision(for: capability) {
        case .refuse:
            // The effective capability, not the tool's declared one: refusing `run_command` because it
            // needs "runCommand" would name a permission the session actually has.
            let refusal = AutomationOutcome.refused(
                reason: "The current permissions do not allow '\(capability.rawValue)' actions.")
            // Recorded, though nothing ran. An attempt to delete that the policy stopped is
            // exactly what someone opens this log to find out about.
            record(name, arguments, refusal, capability: capability, isUndo: isUndo)
            return refusal
        case .confirm:
            let token = UUID().uuidString
            pending[token] = (name, arguments, policy, inputs, isUndo)
            return .needsConfirmation(plan: planText(tool: name, arguments: arguments,
                                                      commandLabel: commandLabel), token: token)
        case .allow:
            return await execute(name, arguments, policy: policy, inputs: inputs, isUndo: isUndo)
        }
    }

    /// Why a gated action should be refused instead of proposed, or nil to go ahead.
    ///
    /// Only for what can be decided cheaply and definitely. A copy whose destination fills up halfway
    /// cannot be foreseen, so it is not checked here; a rename table that aims two files at one name
    /// can, so it is.
    private func refusalBeforeAsking(tool name: String, arguments: Data?) async -> String? {
        // A macro that does not exist cannot work, and asking the user to approve running it spends
        // their attention on a dead end — then fails at the confirmation, which is the worst place to
        // learn the macro was deleted or renamed (F-478).
        if name == "run_macro" {
            let id = (try? Args(arguments).string("macro_id")) ?? ""
            guard let macro = macro(named: arguments) else { return "There is no macro called “\(id)”." }
            // Every step checked against the catalogue before any of them runs. A misspelled tool or a
            // missing required argument in step four is otherwise found after steps one to three have
            // changed the disk — and for a macro that is not a wasted decision, it is a half-done job.
            let problems = MacroPlan.problems(of: macro, tools: tools)
            guard problems.isEmpty else {
                return "The macro “\(macro.title)” cannot run: \(problems.joined(separator: "; "))."
            }
            return nil
        }
        guard name == "rename_batch" else { return nil }
        let a = Args(arguments)
        let problems = await bridge.renameBatchProblems(
            directory: (try? a.string("directory")) ?? "",
            oldNames: (try? a.strings("old_names")) ?? [],
            newNames: (try? a.strings("new_names")) ?? [])
        guard !problems.isEmpty else { return nil }
        // Every reason at once: a model's mistake in a batch is usually systematic, and one message per
        // row is what lets it be fixed in one more turn instead of ten.
        return "Nothing was renamed. "
            + problems.map { "\($0.name): \($0.reason)" }.joined(separator: "; ")
    }

    public func confirm(token: String) async throws -> AutomationOutcome {
        try await confirm(token: token, rejecting: [])
    }

    /// `async` to match the requirement exactly. Declared synchronously it still compiled — an async
    /// requirement accepts a sync witness — but the call site then had two candidates, this one and the
    /// protocol extension's `async` default, and `await` picked the async one. Which returns `[]`. So
    /// every plan looked indivisible and nothing said why (F-450).
    public func planItems(token: String) async -> [PlanItem] {
        guard let p = pending[token] else { return [] }
        // A macro's rows are its steps, which `PlanRows` cannot see: the arguments hold an id, and
        // resolving it needs the macro lookup this actor holds (F-478).
        if p.tool == "run_macro", let macro = macro(named: p.args) {
            // Resolved against the live context, so the rows read as the actions they are rather than as
            // the templates they were written as. Falls back to the templates if the context is
            // unavailable — a plan with unreadable rows still beats no plan.
            guard let snapshot = try? await bridge.context() else { return MacroPlan.rows(of: macro) }
            return MacroPlan.rows(of: macro, resolvedWith: MacroContext(
                activeDirectory: snapshot.activePanelPath,
                inactiveDirectory: snapshot.inactivePanelPath,
                cursorPath: snapshot.cursorPath,
                selection: snapshot.selection,
                startedAt: p.inputs.startedAt,
                answers: p.inputs.answers))
        }
        return PlanRows.of(tool: p.tool, arguments: p.args)
    }

    /// The macro a `run_macro` call names, or nil when there is no such macro.
    private func macro(named arguments: Data?) -> Macro? {
        guard let id = try? Args(arguments).string("macro_id"), let all = macroLookup?() else { return nil }
        return all.first { $0.id == id }
    }

    public func confirm(token: String, rejecting rejected: Set<String>) async throws -> AutomationOutcome {
        guard let p = pending.removeValue(forKey: token) else {
            return .failed(error: "Unknown or already-used confirmation token.")
        }
        // The rows the user struck out are removed from the arguments, so what is skipped is skipped by
        // the tool and not by a second opinion somewhere downstream (F-450).
        guard let filtered = PlanRows.arguments(tool: p.tool, arguments: p.args, rejecting: rejected)
        else {
            // Every row struck out. That is a cancellation, and saying so beats reporting a successful
            // action that touched nothing.
            return .failed(error: "Nothing left to do — every item was left out.")
        }
        return await execute(p.tool, filtered, policy: p.policy, inputs: p.inputs, isUndo: p.isUndo)
    }

    /// Number of plans awaiting confirmation (tests/diagnostics).
    public var pendingCount: Int { pending.count }

    // MARK: - Dispatch

    /// - Parameter policy: the session's policy, carried to `run` for the one tool that needs it —
    ///   `run_macro`, whose steps go back through `invoke` and must be held to the same allow-list.
    ///   Threaded as a parameter and not kept in a field, for the reason the `isUndo` comment gives:
    ///   this actor suspends at every `await`, so a field would hand one session's permissions to
    ///   whichever call arrived while another was in flight.
    /// - Parameter inputs: what was fixed when this action was decided — the instant, and the answers
    ///   to any questions it asked. Only `run_macro` reads them.
    private func execute(_ name: String, _ arguments: Data?, policy: PermissionPolicy,
                         inputs: MacroInputs, isUndo: Bool) async -> AutomationOutcome {
        let outcome = await run(name, arguments, policy: policy, inputs: inputs)
        record(name, arguments, outcome, isUndo: isUndo)
        return outcome
    }

    /// Write the action to the audit log. Every consumer goes through `execute`, so this is the
    /// one place that has to remember — the alternative is a log that is complete until someone
    /// adds a call site.
    private func record(_ name: String, _ arguments: Data?, _ outcome: AutomationOutcome,
                        capability: Capability? = nil, isUndo: Bool) {
        guard let audit else { return }
        // Reads are not recorded: they change nothing, and a log of every list_directory buries
        // the entries someone opens the log to find.
        let capability = capability ?? toolDefinition(named: name)?.capability ?? .read
        guard capability != .read, capability != .navigate else { return }
        var stamp = Date().timeIntervalSince1970
        if stamp <= lastStamp { stamp = lastStamp + 0.001 }
        lastStamp = stamp
        let dictionary = (arguments.flatMap {
            try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
        var entry = AuditEntry(at: stamp, tool: name, capability: capability.rawValue,
                               arguments: Self.readableArguments(dictionary),
                               outcome: "ok", detail: nil)
        // The exact arguments too, when they fit — this is what lets a macro be built from what the
        // user just did. Sorted keys so a log line is stable to diff.
        if let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
           data.count <= argumentsJSONCap {
            entry.argumentsJSON = String(data: data, encoding: .utf8)
        }
        switch outcome {
        case .ok: break
        case .refused(let reason):            entry.outcome = "refused"; entry.detail = reason
        case .failed(let error):              entry.outcome = "failed";  entry.detail = error
        // Unreachable: a plan awaiting confirmation is recorded when it runs, not when it is
        // proposed, so that one action is one line.
        case .needsConfirmation(let plan, _): entry.outcome = "pending"; entry.detail = plan
        }
        if entry.outcome == "ok", !isUndo, let inverse = AuditInverse.of(tool: name, arguments: dictionary),
           let data = try? JSONSerialization.data(withJSONObject: inverse.arguments),
           let text = String(data: data, encoding: .utf8) {
            entry.undoTool = inverse.tool
            entry.undoArguments = text
        } else {
            entry.undoUnavailable = isUndo ? "this action undid an earlier one"
                                           : AuditInverse.unavailableReason(tool: name)
        }
        audit.append(entry)
    }

    /// Arguments as one short line: a `write_file` carries a whole document, and the log is
    /// read by a person.
    static func readableArguments(_ dictionary: [String: Any]) -> String {
        dictionary.keys.sorted().map { key in
            let value = dictionary[key]
            if let text = value as? String {
                return "\(key)=\(text.count > 60 ? String(text.prefix(60)) + "…" : text)"
            }
            if let list = value as? [Any] { return "\(key)=[\(list.count)]" }
            return "\(key)=\(value ?? "")"
        }.joined(separator: " ")
    }

    /// Take back the most recent action that has an inverse. Runs under `policy`, so a session
    /// that may not write may not undo either.
    public func undoLast(policy: PermissionPolicy) async throws -> AutomationOutcome {
        guard let audit else { return .failed(error: "No action log is being kept.") }
        guard let entry = audit.lastUndoable() else {
            let last = audit.recent(limit: 1).first
            let reason = last?.undoUnavailable ?? "there is nothing to undo"
            return .failed(error: "Nothing to undo — \(reason).")
        }
        guard let tool = entry.undoTool, let text = entry.undoArguments else {
            return .failed(error: "Nothing to undo.")
        }
        let outcome = try await invoke(tool: tool, arguments: Data(text.utf8), policy: policy,
                                       isUndo: true)
        // A gated undo is carried out: the user asked for exactly this, by name.
        if case .needsConfirmation(_, let token) = outcome {
            let done = try await confirm(token: token)
            if case .ok = done { audit.markUndone(entry) }
            return done
        }
        if case .ok = outcome { audit.markUndone(entry) }
        return outcome
    }

    /// The recorded actions, newest first.
    ///
    /// `async` to match the requirement exactly — the same trap as `planItems`, one method over, and it
    /// had the same effect. Declared synchronously it still compiled (an async requirement accepts a
    /// sync witness), but `list_recent_actions` writes `await auditTrail(…)`, and that `await` picked
    /// the protocol extension's async default instead. Which returns `[]`. So the log was written
    /// correctly and read back empty: measured against a real run that wrote three entries and listed
    /// none, and against `AuditLog.recent`, which had them all along. Nothing caught it because the
    /// tests exercised `AuditLog` directly and never the tool.
    public func auditTrail(limit: Int = 50) async -> [AuditEntry] { audit?.recent(limit: limit) ?? [] }

    private func run(_ name: String, _ arguments: Data?, policy: PermissionPolicy,
                     inputs: MacroInputs) async -> AutomationOutcome {
        // Plugin-contributed tools route to their owning plugin (KI-06).
        if externalTools.contains(where: { $0.name == name }) {
            return await externalRouter?(name, arguments) ?? .failed(error: "No handler for '\(name)'.")
        }
        do {
            let a = Args(arguments)
            switch name {
            case "get_context":   return .ok(payload: try encode(try await bridge.context()))
            case "list_directory": return .ok(payload: try encode(try await bridge.listDirectory(try a.string("path"))))
            case "stat_path":     return .ok(payload: try encode(try await bridge.stat(try a.string("path"))))
            case "read_file":
                // A caller that asked for a slice needs to know it got one. Without this the model
                // summarises the first few kilobytes of a long document and presents it as a summary
                // of the whole — a wrong answer is worse than a refusal, and the small on-device
                // model has to read in slices (its context window is a few thousand tokens).
                let path = try a.string("path")
                let maxBytes = a.int("max_bytes", default: 65536)
                let offset = a.int("offset", default: 0)
                let text = try await bridge.readFile(path, maxBytes: maxBytes, offset: offset)
                let total = (try? await bridge.stat(path).size) ?? 0
                let end = Int64(offset) + Int64(text.utf8.count)
                return .ok(payload: try json(["content": text,
                                              "offset": offset,
                                              "bytes": text.utf8.count,
                                              "total_bytes": Int(total),
                                              "truncated": end < total]))
            case "search":        return .ok(payload: try encode(try await bridge.search(queryJSON: try a.object("query"))))
            case "hash_file":
                let h = try await bridge.hashFile(try a.string("path"), algorithm: (try? a.string("algorithm")) ?? "sha256")
                return .ok(payload: try json(["hash": h.hash, "algorithm": h.algorithm]))
            case "write_file":
                try await bridge.writeFile(try a.string("path"), content: try a.string("content"))
                return .ok(payload: nil)
            case "merge_files":
                let r = try await bridge.mergeFiles(sources: (try? a.strings("sources")) ?? [],
                                                    destination: try a.string("destination"))
                return .ok(payload: try json(["destination": r.destination,
                                              "files_merged": r.count, "rows": r.rows]))
            case "semantic_search":
                return .ok(payload: try encode(try await bridge.semanticSearch(query: try a.string("query"),
                                                                               path: try? a.string("path"),
                                                                               limit: a.int("limit", default: 10))))
            case "find_files":
                let found = try await bridge.findFiles(nameMask: (try? a.string("name")) ?? "",
                                                       contentText: try? a.string("text"),
                                                       kind: try? a.string("kind"),
                                                       withinDays: a.optionalInt("within_days"),
                                                       largerThanBytes: a.optionalInt("larger_than_bytes")
                                                           .map(Int64.init),
                                                       smallerThanBytes: a.optionalInt("smaller_than_bytes")
                                                           .map(Int64.init),
                                                       scope: (try? a.string("scope")) ?? "",
                                                       limit: a.int("limit", default: 50))
                // The scope travels with the result. Without it "nothing found" is unreadable: the
                // model cannot tell "not on this disk" from "I looked in one folder", and neither can
                // the reader (F-446).
                return .ok(payload: try json(["scope": found.scope,
                                              "count": found.entries.count,
                                              "entries": found.entries.map { e -> [String: Any] in
                                                  var row: [String: Any] = ["name": e.name, "path": e.path,
                                                                            "isDirectory": e.isDirectory,
                                                                            "size": e.size]
                                                  // The date is the point of "from last month", so it
                                                  // travels with the row rather than costing a stat_path
                                                  // per hit.
                                                  if let d = e.modified {
                                                      row["modified"] = ISO8601DateFormatter().string(from: d)
                                                  }
                                                  return row
                                              }]))
            case "get_config":
                let v = try await bridge.getConfig(try a.string("key"))
                return .ok(payload: try json(["value": v ?? ""]))
            case "remember":
                try await bridge.remember(try a.string("text")); return .ok(payload: try json(["ok": true]))
            case "recall":
                let notes = try await bridge.recall((try? a.string("query")) ?? "", limit: a.int("limit", default: 10))
                return .ok(payload: try json(["notes": notes]))
            case "get_comment":
                // "" rather than a missing key: an agent that has to tell "no comment" from "the tool
                // did not answer" will get it wrong, and the difference does not matter here.
                return .ok(payload: try json(["comment": try await bridge.getComment(try a.string("path")) ?? ""]))
            case "describe_image":
                return .ok(payload: try encode(try await bridge.describeImage(try a.string("path"))))
            case "get_tags":
                return .ok(payload: try json(["tags": try await bridge.getTags(try a.string("path"))]))
            case "set_tags":
                try await bridge.setTags(try a.string("path"), tags: (try? a.strings("tags")) ?? [])
                return .ok(payload: nil)
            case "set_comment":
                let text = try a.string("comment")
                try await bridge.setComment(try a.string("path"), comment: text.isEmpty ? nil : text)
                return .ok(payload: nil)
            case "list_recent_actions":
                let entries = await auditTrail(limit: a.int("limit", default: 20))
                return .ok(payload: try encode(entries))
            case "undo_last_action":
                // Runs under the policy of the session asking for it; `undoing` keeps the undo
                // itself out of the undo history.
                return .failed(error: "handled before dispatch")
            case "list_commands": return .ok(payload: try await bridge.listCommandsJSON())
            case "list_plugins":  return .ok(payload: try await bridge.listPluginsJSON())
            case "open_path":     try await bridge.openPath(try a.string("path")); return .ok(payload: nil)
            case "open_in_panel": try await bridge.openInPanel(try a.string("path"), side: try a.string("side")); return .ok(payload: nil)
            case "set_selection": try await bridge.setSelection(mask: try a.string("mask")); return .ok(payload: nil)
            case "copy_to_clipboard":
                let text = try a.string("text")
                try await bridge.copyToClipboard(text)
                // What landed there, counted. Without it the model has to claim success from the
                // absence of an error, and "I copied the three names" is a sentence it should be
                // able to check before writing.
                return .ok(payload: try json([
                    "characters": text.count,
                    "lines": text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count]))
            case "run_command":   try await bridge.runCommand(try a.string("command_id")); return .ok(payload: nil)
            case "list_macros":   return .ok(payload: try encode(await macroSummaries()))
            case "run_macro":     return try await runMacro(a, policy: policy, inputs: inputs)
            case "run_shell":
                let out = try await bridge.runShell(try a.string("command"))
                return .ok(payload: try json(["output": out]))
            case "copy":          try await bridge.copy(sources: try a.strings("sources"), destination: try a.string("destination")); return .ok(payload: nil)
            case "move":          try await bridge.move(sources: try a.strings("sources"), destination: try a.string("destination")); return .ok(payload: nil)
            case "rename":        try await bridge.rename(path: try a.string("path"), newName: try a.string("new_name")); return .ok(payload: nil)
            case "rename_batch":
                let outcome = try await bridge.renameBatch(directory: (try? a.string("directory")) ?? "",
                                                           oldNames: try a.strings("old_names"),
                                                           newNames: try a.strings("new_names"))
                // The refusals travel back as the tool's result, so the model can fix the batch and
                // try again rather than being told only that it failed.
                if !outcome.problems.isEmpty {
                    return .failed(error: "Nothing was renamed. "
                                   + outcome.problems.map { "\($0.name): \($0.reason)" }
                                       .joined(separator: "; "))
                }
                return .ok(payload: try json(["renamed": outcome.renamed, "directory": outcome.directory]))
            case "make_directory": try await bridge.makeDirectory(try a.string("path")); return .ok(payload: nil)
            case "set_config":    try await bridge.setConfig(try a.string("key"), try a.string("value")); return .ok(payload: nil)
            case "move_to_trash": try await bridge.moveToTrash(try a.strings("paths")); return .ok(payload: nil)
            case "delete_permanently": try await bridge.deletePermanently(try a.strings("paths")); return .ok(payload: nil)
            default: throw AutomationError.notImplemented(name)
            }
        } catch let e as AutomationError {
            return .failed(error: Self.readableError(e, tool: name))
        } catch {
            return .failed(error: error.localizedDescription)
        }
    }

    /// A failure the *model* can act on. The failure text goes back into the conversation as the
    /// tool's result, and `missingArgument("path")` — a Swift enum printed with `String(describing:)`
    /// — was observed producing a paragraph of speculation about permissions and installed tools
    /// instead of a second call with the argument supplied. Saying which argument is missing, and
    /// what the tool takes, is the difference between a retry and a dead end.
    static func readableError(_ error: AutomationError, tool name: String) -> String {
        switch error {
        case .missingArgument(let argument):
            guard let definition = AutomationCatalog.tool(named: name) else {
                return "The argument \"\(argument)\" is required. Call \(name) again with it."
            }
            let expected = definition.parameters
                .map { "\($0.name) (\($0.type.rawValue))\($0.required ? "" : ", optional")" }
                .joined(separator: ", ")
            return "\(name) needs the argument \"\(argument)\". Call it again with all required "
                + "arguments. \(name) takes: \(expected.isEmpty ? "no arguments" : expected)."
        case .unknownTool(let unknown):
            return "There is no tool called \"\(unknown)\". Use one of the tools you were given."
        case .notImplemented(let what):
            return "Not available here: \(what)."
        case .operationFailed(let detail):
            return detail
        }
    }

    // MARK: - Macros (F-478)

    /// What `list_macros` returns: enough to choose one and to see what it would do, without the
    /// argument templates — those are for the editor, and a model does not get to rewrite them.
    private struct MacroSummary: Encodable {
        let id: String
        let title: String
        let command: String
        let capability: String
        let steps: [String]
    }

    private func macroSummaries() async -> [MacroSummary] {
        var out: [MacroSummary] = []
        for macro in macroLookup?() ?? [] {
            // The capability the gate will really apply, resolved the same way `invoke` resolves it —
            // otherwise the answer here and the decision there disagree about any macro holding a
            // `run_command` step, and this listing is what a caller uses to decide whether to ask.
            let capability = await MacroPlan.capability(of: macro, tools: tools) { [bridge] id in
                await bridge.commandInfo(id).capability
            }
            out.append(MacroSummary(id: macro.id, title: macro.title, command: macro.commandName,
                                    capability: capability.rawValue,
                                    steps: MacroPlan.rows(of: macro).map(\.text)))
        }
        return out
    }

    /// Run a macro's steps in order.
    ///
    /// The steps go through `invoke` on this same actor, so each one is gated, dispatched and
    /// **logged** exactly as it would be if it had been called directly — one line per step, with its
    /// inverse where one exists. Reentrancy is fine and intended: this actor suspends at every
    /// `await` in `invoke` already.
    private func runMacro(_ a: Args, policy: PermissionPolicy,
                          inputs: MacroInputs) async throws -> AutomationOutcome {
        let id = try a.string("macro_id")
        guard let macro = (macroLookup?() ?? []).first(where: { $0.id == id }) else {
            return .failed(error: "There is no macro called “\(id)”.")
        }
        let skip = Set((try? a.strings("skip_steps")) ?? [])
        // Every row struck out is a cancellation, and it is reported as one. Same wording as
        // `confirm(token:rejecting:)`, because from the user's side it is the same act.
        if !macro.steps.isEmpty, skip.count >= macro.steps.count {
            return .failed(error: "Nothing left to do — every step was left out.")
        }
        // One start time for the whole run, so every `%{date:…}` in it agrees — and it is the instant
        // the plan was built, not this one, so the rows the user approved and the folders the run
        // creates cannot disagree. The panel state is read again for each step, because a step changes
        // what the next one is about.
        let bridge = self.bridge
        let context: MacroRunner.ContextProvider = {
            guard let snapshot = try? await bridge.context() else {
                return MacroContext(activeDirectory: "", startedAt: inputs.startedAt,
                                    answers: inputs.answers)
            }
            return MacroContext(activeDirectory: snapshot.activePanelPath,
                                inactiveDirectory: snapshot.inactivePanelPath,
                                cursorPath: snapshot.cursorPath,
                                selection: snapshot.selection,
                                startedAt: inputs.startedAt, answers: inputs.answers)
        }
        // `runMacro` is only reached after `invoke` decided `.allow` or the user confirmed, so
        // autonomy is satisfied for the macro as a whole. The runner raises autonomy for the steps and
        // leaves this allow-list alone — which is what keeps a `run_shell` step refused on a session
        // that never got `.shell`.
        // Straight back through the public `invoke`, so a step is gated, dispatched and logged exactly
        // as a direct call would be. Reentering this actor is intended and safe: `invoke` already
        // suspends at every `await`, and the runner holds no actor state of its own.
        let runner = MacroRunner { tool, arguments, stepPolicy in
            try await self.invoke(tool: tool, arguments: arguments, policy: stepPolicy)
        }
        let report = await runner.run(macro, context: context, policy: policy, skipping: skip)
        if let stopped = report.stoppedAt {
            // Reported as a failure even though earlier steps succeeded: a half-run macro is not a
            // success. How far it got is part of the message, not only of the payload — a `.failed`
            // carries nothing but its string to the caller, so "the macro stopped at step 3" used to
            // leave the one question a person has next ("then what has already happened to my files?")
            // answerable only by opening the action log.
            let done = report.ranCount
            let progress = done == 0 ? "Nothing had run yet."
                : "\(done) of \(macro.steps.count) steps had already been carried out."
            return .failed(error: "The macro stopped at \(stopped). \(progress)")
        }
        return .ok(payload: try encode(report))
    }

    /// A human-readable description of what a gated action will do (best-effort).
    private func planText(tool: String, arguments: Data?, commandLabel: String? = nil) -> String {
        let a = Args(arguments)
        switch tool {
        case "copy":  return "Copy \((try? a.strings("sources").count) ?? 0) item(s) to \((try? a.string("destination")) ?? "?")."
        case "move":  return "Move \((try? a.strings("sources").count) ?? 0) item(s) to \((try? a.string("destination")) ?? "?")."
        case "rename": return "Rename \((try? a.string("path")) ?? "?") to \((try? a.string("new_name")) ?? "?")."
        case "rename_batch":
            // A table, not a count. "Rename 40 files" is not something anybody can agree to, and this
            // is the one gated action whose whole value is that the user sees the pairing before it
            // happens (F-447).
            let old = (try? a.strings("old_names")) ?? []
            let new = (try? a.strings("new_names")) ?? []
            guard case .success(let pairs) = RenameBatchPlan.pair(old: old, new: new) else {
                return "Rename \(old.count) file(s) — but the two lists do not line up."
            }
            return RenameBatchPlan.table(pairs)
        case "make_directory": return "Create folder \((try? a.string("path")) ?? "?")."
        case "write_file":
            let p = (try? a.string("path")) ?? "?"
            let n = (try? a.string("content"))?.count ?? 0
            return "Write \(n) characters to \(p)."
        case "merge_files":
            let n = (try? a.strings("sources"))?.count
            let dst = (try? a.string("destination")) ?? "?"
            return "Merge \(n.map { "\($0)" } ?? "the selected") file(s) into \(dst)."
        case "set_tags":
            let path = (try? a.string("path")) ?? "?"
            let tags = (try? a.strings("tags")) ?? []
            // The tags themselves: the reader is approving these words being attached to their
            // file, where Spotlight and every Finder window will show them.
            return tags.isEmpty ? "Remove the tags from \(path)."
                                : "Tag \(path) with \(tags.joined(separator: ", "))."
        case "set_comment":
            let path = (try? a.string("path")) ?? "?"
            let text = (try? a.string("comment")) ?? ""
            // The text itself, not its length: the user is being asked to approve *these words* being
            // attached to their file, and "write 34 characters" does not let them decide that.
            return text.isEmpty ? "Remove the comment on \(path)."
                                : "Set the comment on \(path) to “\(text)”."
        case "run_shell":
            // The command itself, verbatim and in full. Anything else — a summary, a truncation, the
            // tool's name — asks the user to approve something they cannot check, and this is the one
            // tool where the exact characters are the whole decision.
            guard let cmd = try? a.string("command") else { return "Run a shell command." }
            return "Run “\(cmd)” in a terminal tab. Its output is also written to a file so the "
                 + "assistant can read it."
        case "set_config": return "Set \((try? a.string("key")) ?? "?") = \((try? a.string("value")) ?? "?")."
        case "move_to_trash": return "Move \((try? a.strings("paths").count) ?? 0) item(s) to the Trash."
        case "delete_permanently": return "Permanently delete \((try? a.strings("paths").count) ?? 0) item(s). This cannot be undone."
        case "run_command":
            // Name the command, not the tool. "Run run_command." is what the default produced, and
            // approving that is not a decision anybody could make.
            guard let id = try? a.string("command_id") else { return "Run a command." }
            return commandLabel.map { "\($0) (\(id))." } ?? "Run the command \(id)."
        case "run_macro":
            // `commandLabel` is the macro's own plan text, set in `invoke`. Falling back to the id
            // rather than to "Run run_macro", for the same reason as above.
            guard let id = try? a.string("macro_id") else { return "Run a macro." }
            return commandLabel ?? "Run the macro “\(id)”."
        default: return Self.planTextForOtherTool(tool, arguments)
        }
    }

    /// The plan text for a tool this switch has no phrasing for — in practice, one contributed by a
    /// plugin.
    ///
    /// "Run run_applescript." was what the old default produced, and the `run_command` case above
    /// already says why that is not a decision anybody can make. Two rules, both borrowed from cases
    /// that earned them:
    ///
    ///   * A tool whose arguments are a single string is one where *that string is the decision* — a
    ///     script, a command line, a query. It is quoted in full, like `run_shell`'s command, because a
    ///     summary asks the user to approve something they cannot check.
    ///   * Anything else gets its arguments named rather than dropped.
    ///
    /// Generic on purpose: the core does not know a plugin's tool names and should not learn them.
    static func planTextForOtherTool(_ tool: String, _ arguments: Data?) -> String {
        let dictionary = (arguments.flatMap {
            try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
        guard !dictionary.isEmpty else { return "Run \(tool)." }
        let strings = dictionary.compactMapValues { $0 as? String }
        if strings.count == 1, dictionary.count == 1, let (key, value) = strings.first {
            // Capped, but generously: a script long enough to hit this is one the reader was going to
            // scroll anyway, and cutting it at sixty characters would hide what it does.
            let body = value.count > 4000 ? String(value.prefix(4000)) + "\n…" : value
            return "Run \(tool) with \(key):\n\n\(body)"
        }
        return "Run \(tool) — \(readableArguments(dictionary))."
    }

    private func encode<T: Encodable>(_ v: T) throws -> Data { try JSONEncoder().encode(v) }
    private func json(_ dict: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: dict) }
}

/// Minimal typed accessor over a tool's JSON arguments.
private struct Args {
    private let dict: [String: Any]
    init(_ data: Data?) {
        dict = (try? JSONSerialization.jsonObject(with: data ?? Data())) as? [String: Any] ?? [:]
    }
    func string(_ k: String) throws -> String {
        guard let v = dict[k] as? String else { throw AutomationError.missingArgument(k) }
        return v
    }
    func strings(_ k: String) throws -> [String] {
        guard let v = dict[k] as? [String] else { throw AutomationError.missingArgument(k) }
        return v
    }
    func int(_ k: String, default d: Int) -> Int { (dict[k] as? Int) ?? d }
    /// Nil when the key is absent — which is a different filter from "zero" and has to stay one
    /// (`within_days: 0` would mean "modified in the last no days").
    ///
    /// A number that arrives as a string is accepted too: a model asked for an integer sometimes sends
    /// "30", and refusing that would fail the request on JSON typing rather than on substance.
    func optionalInt(_ k: String) -> Int? {
        if let n = dict[k] as? Int { return n }
        if let d = dict[k] as? Double { return Int(d) }
        if let s = dict[k] as? String { return Int(s.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
    func object(_ k: String) throws -> Data {
        guard let v = dict[k] else { throw AutomationError.missingArgument(k) }
        return try JSONSerialization.data(withJSONObject: v)
    }
}
