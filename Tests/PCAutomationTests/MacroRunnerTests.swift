// SPDX-License-Identifier: Apache-2.0
// The sequencer (F-478), driven through its injected invoker so no core, bridge or file system is
// involved — and the macro path through DefaultAutomationCore, which is where the permission gate,
// the plan rows and the audit log actually meet.

import XCTest
@testable import PCAutomation

private func ok(_ json: Any? = nil) -> AutomationOutcome {
    .ok(payload: json.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.fragmentsAllowed]) })
}

/// Records every step the runner asked for, and answers each one from a script.
private actor Recorder {
    var calls: [(tool: String, arguments: Data?, policy: PermissionPolicy)] = []
    private var answers: [String: AutomationOutcome]
    init(answers: [String: AutomationOutcome] = [:]) { self.answers = answers }

    func invoke(_ tool: String, _ arguments: Data?,
                _ policy: PermissionPolicy) -> AutomationOutcome {
        calls.append((tool, arguments, policy))
        return answers[tool] ?? ok()
    }
    var tools: [String] { calls.map(\.tool) }
    var policies: [PermissionPolicy] { calls.map(\.policy) }
    func arguments(_ index: Int) -> [String: Any] {
        guard let d = calls[index].arguments,
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }
}

/// Panel selection a fake step can change, so a test can prove the runner re-reads it.
private actor Selection {
    private(set) var paths: [String]
    init(_ paths: [String]) { self.paths = paths }
    func set(_ paths: [String]) { self.paths = paths }
}

/// File-private rather than a stored property: the runner now takes a *provider*, and a closure that
/// reads an instance property has to capture `self`.
private let context = MacroContext(activeDirectory: "/a", inactiveDirectory: "/b",
                                   cursorPath: "/a/f.txt", selection: ["/a/f.txt", "/a/g.txt"],
                                   startedAt: Date(timeIntervalSince1970: 0))

final class MacroRunnerTests: XCTestCase {

    private func runner(_ recorder: Recorder) -> MacroRunner {
        MacroRunner { tool, arguments, policy in await recorder.invoke(tool, arguments, policy) }
    }

    private func threeSteps() -> Macro {
        Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/out")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%S"), "destination": .text("%T/out")]),
            MacroStep(tool: "open_path", arguments: ["path": .text("%T/out")]),
        ])
    }

    func test_stepsRunInOrderWithResolvedArguments() async throws {
        let r = Recorder()
        let report = await runner(r).run(threeSteps(), context: { context }, policy: .standard)
        let tools = await r.tools
        let first = await r.arguments(0)
        let second = await r.arguments(1)
        XCTAssertEqual(tools, ["make_directory", "move", "open_path"])
        XCTAssertEqual(first["path"] as? String, "/b/out")
        XCTAssertEqual(second["sources"] as? [String], ["/a/f.txt", "/a/g.txt"])
        XCTAssertNil(report.stoppedAt)
        XCTAssertEqual(report.ranCount, 3)
        XCTAssertEqual(report.steps.map(\.step), ["1", "2", "3"])
    }

    func test_skippedStepsAreNotRunAndAreReportedAsSkipped() async throws {
        let r = Recorder()
        let report = await runner(r).run(threeSteps(), context: { context }, policy: .standard,
                                         skipping: ["2"])
        let tools = await r.tools
        XCTAssertEqual(tools, ["make_directory", "open_path"])
        XCTAssertEqual(report.steps.map(\.outcome), ["ok", "skipped", "ok"])
        XCTAssertEqual(report.ranCount, 2)
    }

    /// **The safety property.** The macro-level approval satisfies "must I ask?", and nothing else: the
    /// allow-list handed to each step is the session's, untouched.
    func test_stepsRunAutonomouslyButWithTheSessionsAllowList() async throws {
        let r = Recorder()
        let policy = PermissionPolicy(autonomy: .confirmWrites, allowed: [.read, .navigate, .write])
        _ = await runner(r).run(threeSteps(), context: { context }, policy: policy)
        let seen = await r.policies
        XCTAssertFalse(seen.isEmpty)
        for p in seen {
            XCTAssertEqual(p.autonomy, .autonomous)
            XCTAssertEqual(p.allowed, [.read, .navigate, .write])
            XCTAssertFalse(p.permits(.shell), "raising autonomy must not widen the allow-list")
            XCTAssertFalse(p.permits(.script))
        }
    }

    func test_aFailedStepStopsTheRunAndLaterStepsDoNotRun() async throws {
        let r = Recorder(answers: ["move": .failed(error: "the destination is read-only")])
        let report = await runner(r).run(threeSteps(), context: { context }, policy: .standard)
        let tools = await r.tools
        XCTAssertEqual(tools, ["make_directory", "move"], "open_path must not run")
        XCTAssertEqual(report.steps.map(\.outcome), ["ok", "failed"])
        XCTAssertEqual(report.stoppedAt, "step 2 (move): the destination is read-only")
    }

    func test_aRefusedStepStopsTheRunAndSaysWhy() async throws {
        let r = Recorder(answers: ["move": .refused(reason: "not allowed")])
        let report = await runner(r).run(threeSteps(), context: { context }, policy: .standard)
        XCTAssertEqual(report.steps.last?.outcome, "refused")
        XCTAssertEqual(report.stoppedAt, "step 2 (move): not allowed")
    }

    /// A step asking for a second confirmation is reported, never auto-confirmed. Confirming it here
    /// would turn one approval of a list of rows into a blanket yes to whatever came next.
    func test_aStepAskingForConfirmationIsReportedRatherThanConfirmed() async throws {
        let r = Recorder(answers: ["move": .needsConfirmation(plan: "Move 2 items", token: "t")])
        let report = await runner(r).run(threeSteps(), context: { context }, policy: .standard)
        let tools = await r.tools
        XCTAssertEqual(report.steps.last?.outcome, "failed")
        XCTAssertEqual(tools, ["make_directory", "move"])
        XCTAssertTrue(report.stoppedAt?.contains("second confirmation") == true, report.stoppedAt ?? "")
    }

    /// A macro naming itself is one step long, so there is no depth limit that would make nesting safe.
    func test_aMacroCannotRunAnotherMacro() async throws {
        let r = Recorder()
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "run_macro", arguments: ["macro_id": .text("m")])])
        let report = await runner(r).run(m, context: { context }, policy: .standard)
        let tools = await r.tools
        XCTAssertEqual(tools, [], "the step must not even reach the invoker")
        XCTAssertEqual(report.steps.map(\.outcome), ["refused"])
        XCTAssertTrue(report.stoppedAt?.contains("cannot run another macro") == true)
    }

    func test_anUnresolvableArgumentFailsTheStepWithAReadableReason() async throws {
        let r = Recorder()
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "move", arguments: ["sources": .text("%{4}")])])
        let report = await runner(r).run(m, context: { context }, policy: .standard)
        let tools = await r.tools
        XCTAssertEqual(tools, [])
        XCTAssertTrue(report.stoppedAt?.contains("result of step 4") == true, report.stoppedAt ?? "")
    }

    /// **A step changes what the next step is about.** The runner held one snapshot first, and the
    /// effect was that `set_selection` as step one did nothing for a `%S` in step three: the selection
    /// had changed, the snapshot had not, and the macro reported "nothing is selected" about files it
    /// had just marked itself.
    func test_aLaterStepSeesWhatAnEarlierStepDidToThePanels() async throws {
        let selection = Selection(["/a/f.txt"])
        let r = Recorder()
        let runner = MacroRunner { tool, arguments, policy in
            if tool == "set_selection" { await selection.set(["/a/one.pdf", "/a/two.pdf"]) }
            return await r.invoke(tool, arguments, policy)
        }
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "set_selection", arguments: ["mask": .text("*.pdf")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%S"),
                                                "destination": .text("%T/out")]),
        ])
        let report = await runner.run(m, context: {
            MacroContext(activeDirectory: "/a", inactiveDirectory: "/b",
                         selection: await selection.paths,
                         startedAt: Date(timeIntervalSince1970: 0))
        }, policy: .standard)
        XCTAssertNil(report.stoppedAt, report.stoppedAt ?? "")
        let second = await r.arguments(1)
        XCTAssertEqual(second["sources"] as? [String], ["/a/one.pdf", "/a/two.pdf"],
                       "the move must act on what step one selected, not on the state before it")
    }

    func test_aLaterStepCanUseAnEarlierStepsResult() async throws {
        let r = Recorder(answers: ["merge_files": ok("/b/merged.csv")])
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "merge_files", arguments: ["destination": .text("%T/merged.csv")]),
            MacroStep(tool: "open_path", arguments: ["path": .text("%{1}")]),
        ])
        let report = await runner(r).run(m, context: { context }, policy: .standard)
        XCTAssertNil(report.stoppedAt, report.stoppedAt ?? "")
        let second = await r.arguments(1)
        XCTAssertEqual(second["path"] as? String, "/b/merged.csv")
    }
}

final class MacroThroughCoreTests: XCTestCase {

    private func core(_ macros: [Macro], bridge: FakeBridge = FakeBridge(),
                      audit: AuditLog? = nil) -> DefaultAutomationCore {
        DefaultAutomationCore(bridge: bridge, audit: audit, macros: { macros })
    }

    private func args(_ dict: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: dict)
    }

    private func tidyMacro() -> Macro {
        Macro(id: "tidy", title: "Tidy", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/out")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%S"), "destination": .text("%T/out")]),
        ])
    }

    /// The gate is about what will happen, not about the name of the tool that starts it: a macro whose
    /// steps write is confirmed like a write, even though `run_macro` is one tool call.
    func test_aWritingMacroIsGatedLikeAWrite() async throws {
        let c = core([tidyMacro()])
        let outcome = try await c.invoke(tool: "run_macro", arguments: args(["macro_id": "tidy"]),
                                         policy: .standard)
        guard case .needsConfirmation(let plan, let token) = outcome else {
            return XCTFail("expected a plan, got \(outcome)")
        }
        XCTAssertTrue(plan.contains("Tidy"), plan)
        XCTAssertTrue(plan.contains("2 steps"), plan)
        // And the plan divides into its steps, which PlanRows alone could never work out.
        let rows = await c.planItems(token: token)
        XCTAssertEqual(rows.map(\.id), ["1", "2"])
        // Resolved against the live context and phrased as actions — not as the templates they were
        // written as. This dialog is where somebody who has never seen `%T` is asked to decide.
        XCTAssertEqual(rows[0].text, "Create the folder “out”")
        XCTAssertEqual(rows[1].text, "Move f.txt into “out”")
    }

    func test_aReadOnlyMacroRunsWithoutAsking() async throws {
        let bridge = FakeBridge()
        let m = Macro(id: "look", title: "Look", steps: [
            MacroStep(tool: "list_directory", arguments: ["path": .text("%P")])])
        let outcome = try await core([m], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "look"]), policy: .standard)
        guard case .ok = outcome else { return XCTFail("expected ok, got \(outcome)") }
        let listed = await bridge.listed
        XCTAssertEqual(listed, "/a")
    }

    func test_confirmingWithARowStruckOutSkipsThatStep() async throws {
        let bridge = FakeBridge()
        let c = core([tidyMacro()], bridge: bridge)
        guard case .needsConfirmation(_, let token) = try await c.invoke(
            tool: "run_macro", arguments: args(["macro_id": "tidy"]), policy: .standard)
        else { return XCTFail("expected a plan") }

        let outcome = try await c.confirm(token: token, rejecting: ["1"])
        guard case .ok = outcome else { return XCTFail("expected ok, got \(outcome)") }
        let madeDir = await bridge.madeDir
        let moved = await bridge.moved
        XCTAssertNil(madeDir, "the struck-out make_directory must not run")
        XCTAssertEqual(moved?.dest, "/b/out")
    }

    func test_strikingOutEveryRowIsReportedAsACancellation() async throws {
        let c = core([tidyMacro()])
        guard case .needsConfirmation(_, let token) = try await c.invoke(
            tool: "run_macro", arguments: args(["macro_id": "tidy"]), policy: .standard)
        else { return XCTFail("expected a plan") }
        let outcome = try await c.confirm(token: token, rejecting: ["1", "2"])
        guard case .failed(let error) = outcome else { return XCTFail("expected failure, got \(outcome)") }
        XCTAssertTrue(error.contains("every step was left out"), error)
    }

    /// The end-to-end version of the safety property, and the better half of it: because the macro's
    /// capability is the most demanding of its steps, a macro holding a shell step is refused *whole*
    /// on a session that never got `.shell` — not four steps in, with the folder half tidied.
    func test_aMacroIsRefusedWholeWhenItsMostDemandingStepIsNotPermitted() async throws {
        let bridge = FakeBridge()
        let m = Macro(id: "sh", title: "Shell", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/out")]),
            MacroStep(tool: "run_shell", arguments: ["command": .text("rm -rf /")]),
        ])
        // `.autonomous` so nothing is merely deferred to a confirmation: this must be a refusal.
        let policy = PermissionPolicy(autonomy: .autonomous,
                                      allowed: Set(Capability.allCases).subtracting([.shell]))
        let outcome = try await core([m], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "sh"]), policy: policy)
        guard case .refused(let reason) = outcome else {
            return XCTFail("expected a refusal, got \(outcome)")
        }
        let ranShell = await bridge.ranShell
        let madeDir = await bridge.madeDir
        XCTAssertTrue(reason.contains("shell"), reason)
        XCTAssertNil(ranShell, "the shell must not have run")
        XCTAssertNil(madeDir, "and neither must the step before it")
    }

    /// `MacroPlan.capability` reads each step's *declared* capability, which for `run_command` is
    /// `.runCommand` — not what the command does. So the macro-level gate lets this through, and the
    /// step-level gate is what stops it. That is why the runner keeps the session's allow-list instead
    /// of trusting the macro-level decision, and this is the case that would slip through if it did.
    func test_aStepIsStillGatedByWhatItsCommandActuallyDoes() async throws {
        let bridge = FakeBridge()
        let m = Macro(id: "del", title: "Delete", steps: [
            MacroStep(tool: "run_command", arguments: ["command_id": .text("cm_DeleteReal")])])
        XCTAssertEqual(MacroPlan.capability(of: m), .runCommand, "the macro-level gate sees only this")
        let policy = PermissionPolicy(autonomy: .autonomous,
                                      allowed: Set(Capability.allCases).subtracting([.write]))
        let outcome = try await core([m], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "del"]), policy: policy)
        guard case .failed(let error) = outcome else {
            return XCTFail("expected failure, got \(outcome)")
        }
        let ran = await bridge.ranCommand
        XCTAssertTrue(error.contains("write"), error)
        XCTAssertNil(ran, "the command must not have run")
    }

    func test_anUnknownMacroFails() async throws {
        let outcome = try await core([]).invoke(tool: "run_macro",
                                                arguments: args(["macro_id": "nope"]),
                                                policy: .standard)
        guard case .failed(let error) = outcome else { return XCTFail("expected failure") }
        XCTAssertTrue(error.contains("nope"), error)
    }

    func test_listMacrosNamesEachOneAndWhatItWouldNeed() async throws {
        let outcome = try await core([tidyMacro()]).invoke(tool: "list_macros", arguments: nil,
                                                           policy: .standard)
        guard case .ok(let payload) = outcome, let data = payload else { return XCTFail("expected a payload") }
        let list = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0]["id"] as? String, "tidy")
        XCTAssertEqual(list[0]["command"] as? String, "mc_tidy")
        XCTAssertEqual(list[0]["capability"] as? String, "write")
        XCTAssertEqual((list[0]["steps"] as? [String])?.count, 2)
    }

    /// One step is one line in the log, because every step goes through the core's normal execution
    /// path. That is also what makes `undo_last_action` after a macro take back its last step.
    func test_eachStepIsItsOwnLineInTheAuditLog() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-macro-audit-\(UUID().uuidString).jsonl")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let log = AuditLog(url: url)
        let c = core([tidyMacro()], audit: log)
        guard case .needsConfirmation(_, let token) = try await c.invoke(
            tool: "run_macro", arguments: args(["macro_id": "tidy"]), policy: .standard)
        else { return XCTFail("expected a plan") }
        _ = try await c.confirm(token: token)

        let entries = log.recent(limit: 10)
        XCTAssertEqual(entries.filter { $0.tool == "make_directory" }.count, 1)
        XCTAssertEqual(entries.filter { $0.tool == "move" }.count, 1)
        XCTAssertTrue(entries.contains { $0.tool == "move" && $0.isUndoable },
                      "a move keeps its inverse when it runs inside a macro")
    }

    /// A plan is an answer to the question that was asked. Confirming it must not pick up permissions
    /// the session did not have when the plan was proposed.
    func test_aPlanIsCarriedOutUnderThePolicyItWasProposedUnder() async throws {
        let bridge = FakeBridge()
        let m = Macro(id: "sh", title: "Shell", steps: [
            MacroStep(tool: "run_shell", arguments: ["command": .text("echo hi")])])
        let c = core([m], bridge: bridge)
        guard case .needsConfirmation(_, let token) = try await c.invoke(
            tool: "run_macro", arguments: args(["macro_id": "sh"]), policy: .standardWithShell)
        else { return XCTFail("expected a plan") }
        _ = try await c.confirm(token: token)
        let ranShell = await bridge.ranShell
        XCTAssertEqual(ranShell, "echo hi")
    }
}

/// Reading the log back through the Core, not just writing it. Added because a real run wrote three
/// correct lines to `aichat/actions.jsonl` and `list_recent_actions` in the same process answered `[]`.
final class AuditTrailReadbackTests: XCTestCase {

    func test_theCoreReadsBackWhatItJustWrote() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-readback-\(UUID().uuidString).jsonl")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let log = AuditLog(url: url)
        let core = DefaultAutomationCore(bridge: FakeBridge(), audit: log)

        _ = try await core.invoke(tool: "make_directory",
                                  arguments: try JSONSerialization.data(withJSONObject: ["path": "/b/x"]),
                                  policy: PermissionPolicy(autonomy: .autonomous))
        XCTAssertEqual(log.recent(limit: 20).count, 1, "the log on disk")

        let outcome = try await core.invoke(
            tool: "list_recent_actions",
            arguments: try JSONSerialization.data(withJSONObject: ["limit": 20]),
            policy: .standard)
        guard case .ok(let payload) = outcome, let data = payload else {
            return XCTFail("expected a payload, got \(outcome)")
        }
        let list = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(list.count, 1, "and the same log through the tool")
        XCTAssertEqual(list.first?["tool"] as? String, "make_directory")
    }
}

/// The plan text for a tool the core has no phrasing for — a plugin's (F-477).
final class ContributedToolPlanTextTests: XCTestCase {

    private func text(_ tool: String, _ dict: [String: Any]) -> String {
        DefaultAutomationCore.planTextForOtherTool(
            tool, try! JSONSerialization.data(withJSONObject: dict))
    }

    /// "Run run_applescript." was the old default, and the codebase already says why that is not a
    /// decision anybody can make. Where the arguments are one string, that string is the decision.
    func test_aSingleStringArgumentIsQuotedInFull() {
        let source = "tell application \"Finder\" to empty trash"
        let plan = text("run_applescript", ["source": source])
        XCTAssertTrue(plan.contains(source), plan)
    }

    /// Long enough to scroll, not long enough to hide what it does.
    func test_aVeryLongScriptIsCappedButNotSummarised() {
        let source = String(repeating: "x", count: 5000)
        let plan = text("run_applescript", ["source": source])
        XCTAssertTrue(plan.count > 3000, "not clipped to a summary")
        XCTAssertTrue(plan.hasSuffix("…"), plan.suffix(10).description)
    }

    func test_severalArgumentsAreNamedRatherThanDropped() {
        let plan = text("run_applescript", ["source": "return 1", "timeout_seconds": 3])
        XCTAssertTrue(plan.contains("source="), plan)
        XCTAssertTrue(plan.contains("timeout_seconds=3"), plan)
    }

    func test_noArgumentsFallsBackToTheToolName() {
        XCTAssertEqual(DefaultAutomationCore.planTextForOtherTool("list_scripts", nil),
                       "Run list_scripts.")
    }
}
