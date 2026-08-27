// SPDX-License-Identifier: Apache-2.0
// MacroRunner.swift — running a macro's steps in order (F-478).
//
// The runner does not gate anything. By the time it is called the macro has been through the same
// `PermissionPolicy` decision as any single tool — refused, or approved once with the rows the user
// left in — and its job is only to carry out what was approved.
//
// That approval is why the steps run with autonomy raised to `.autonomous`: the user has already
// agreed to this list. The **allow-list is not touched**, and that distinction is the whole safety
// story here. Raising autonomy answers "must I ask?"; it does not answer "may this session do it at
// all". A macro holding a `run_shell` step still gets `.refused` for that step on a session without
// `.shell`, and the macro reports which step and why.
//
// One step is one line in the audit log, with its own inverse where one exists, because every step
// goes through the core's normal execution path. So `undo_last_action` after a macro takes back its
// last step — not the whole macro. Stated here because it is a design decision and not an oversight:
// a macro-wide undo would have to invert steps a tool cannot invert, and a button offering it would
// be lying about the ones it cannot.

import Foundation

/// What running a macro produced.
public struct MacroRunReport: Sendable, Equatable, Codable {
    public struct StepReport: Sendable, Equatable, Codable {
        public let step: String          // the step id ("1", "2", …)
        public let tool: String
        public let outcome: String       // "ok" | "skipped" | "refused" | "failed"
        public let detail: String?
    }
    public let macro: String
    public let steps: [StepReport]
    /// Set when the run stopped early; names the step and the reason.
    public let stoppedAt: String?

    public var ranCount: Int { steps.filter { $0.outcome == "ok" }.count }
}

public struct MacroRunner: Sendable {

    /// Runs one tool call. Injected rather than taking an `AutomationCore`, for two reasons: the core
    /// that runs a macro is the same actor that would be re-entered here, and a closure lets a test
    /// drive the whole sequencer with no core, no bridge and no file system.
    public typealias StepInvoker =
        @Sendable (_ tool: String, _ arguments: Data?, _ policy: PermissionPolicy) async throws -> AutomationOutcome

    /// Yields the panel state as it is *now*.
    ///
    /// A provider rather than one snapshot, because a step changes what the next step is about. The
    /// runner took a fixed `MacroContext` first, and the effect was that `set_selection` as a step one
    /// did nothing for a `%S` in step three: the selection had changed, the snapshot had not, and the
    /// macro reported "nothing is selected" about files it had just marked itself. Measured on a
    /// three-step macro that selected every PDF and then moved them.
    ///
    /// `startedAt` is the one thing the provider must hold *fixed* across calls, so every `%{date:…}` in
    /// one run agrees — see `MacroContext.startedAt`.
    public typealias ContextProvider = @Sendable () async -> MacroContext

    let invoke: StepInvoker

    public init(invoke: @escaping StepInvoker) { self.invoke = invoke }

    /// Run `macro`, leaving out the steps whose ids are in `skipping`.
    ///
    /// Stops at the first step that is refused or fails. Not a policy choice — a macro is a sequence
    /// where step two usually assumes step one happened, and carrying on past a failed
    /// `make_directory` means a `move` into a folder that is not there.
    public func run(_ macro: Macro, context: @escaping ContextProvider, policy: PermissionPolicy,
                    skipping: Set<String> = []) async -> MacroRunReport {
        // Same allow-list, no confirmation. See the file comment.
        let stepPolicy = PermissionPolicy(autonomy: .autonomous, allowed: policy.allowed)
        var reports: [MacroRunReport.StepReport] = []
        var results: [String: Data?] = [:]
        var stoppedAt: String?

        for (index, step) in macro.steps.enumerated() {
            let id = Macro.stepID(index)
            if skipping.contains(id) {
                reports.append(.init(step: id, tool: step.tool, outcome: "skipped", detail: nil))
                continue
            }
            // A macro calling a macro is refused, not executed. There is no depth limit that would
            // make it safe — a macro naming itself is one step long — and nesting was never asked
            // for. Refused per step rather than rejected when the macro is saved, so a macros.json
            // written by hand cannot get a run into an unbounded recursion either.
            if step.tool == "run_macro" {
                let detail = "a macro cannot run another macro"
                reports.append(.init(step: id, tool: step.tool, outcome: "refused", detail: detail))
                stoppedAt = "step \(id) (\(step.tool)): \(detail)"
                break
            }
            let arguments: Data?
            do {
                // Read afresh for every step: what the previous step did to the panels is part of what
                // this step means.
                let resolved = try MacroPlaceholders.resolve(step.arguments, context: await context(),
                                                             results: results)
                arguments = try MacroPlaceholders.json(resolved)
            } catch {
                let detail = Self.describe(error)
                reports.append(.init(step: id, tool: step.tool, outcome: "failed", detail: detail))
                stoppedAt = "step \(id) (\(step.tool)): \(detail)"
                break
            }
            do {
                let outcome = try await invoke(step.tool, arguments, stepPolicy)
                switch outcome {
                case .ok(let payload):
                    results[id] = payload
                    reports.append(.init(step: id, tool: step.tool, outcome: "ok", detail: nil))
                case .refused(let reason):
                    reports.append(.init(step: id, tool: step.tool, outcome: "refused", detail: reason))
                    stoppedAt = "step \(id) (\(step.tool)): \(reason)"
                case .failed(let error):
                    reports.append(.init(step: id, tool: step.tool, outcome: "failed", detail: error))
                    stoppedAt = "step \(id) (\(step.tool)): \(error)"
                case .needsConfirmation(let plan, _):
                    // Unreachable under `.autonomous`, and reported rather than confirmed if it ever
                    // happens. Auto-confirming here would turn one approval of a list of rows into a
                    // blanket yes to whatever a step asked next, which is the opposite of what the
                    // user agreed to.
                    let detail = "asked for a second confirmation: \(plan)"
                    reports.append(.init(step: id, tool: step.tool, outcome: "failed", detail: detail))
                    stoppedAt = "step \(id) (\(step.tool)): \(detail)"
                }
            } catch {
                let detail = Self.describe(error)
                reports.append(.init(step: id, tool: step.tool, outcome: "failed", detail: detail))
                stoppedAt = "step \(id) (\(step.tool)): \(detail)"
            }
            if stoppedAt != nil { break }
        }
        return MacroRunReport(macro: macro.id, steps: reports, stoppedAt: stoppedAt)
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case MacroPlaceholderError.unknownStepReference(let step):
            return "it refers to the result of step \(step), which has no usable value"
        case MacroPlaceholderError.expandedToNothing(let token):
            return token == MacroPlaceholders.selectionToken
                ? "nothing is selected, so there is nothing for this step to act on"
                : "“\(token)” came out empty, so there is nothing for this step to act on"
        case AutomationError.unknownTool(let name):
            return "this build has no tool called “\(name)”"
        case AutomationError.missingArgument(let name):
            return "the argument “\(name)” is missing"
        case AutomationError.notImplemented(let name):
            return "“\(name)” is not available here"
        case AutomationError.operationFailed(let reason):
            return reason
        default:
            return String(describing: error)
        }
    }
}
