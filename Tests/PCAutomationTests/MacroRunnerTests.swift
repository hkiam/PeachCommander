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

    /// The backstop for the same rule the pre-flight applies: a `macros.json` written by hand reaches
    /// the runner without the Core's check, and a self-calling macro must not get past it there either.
    func test_aRunCommandStepNamingAMacroIsRefusedByTheRunnerToo() async throws {
        let recorder = Recorder()
        let m = Macro(id: "loop", title: "Loop", steps: [
            MacroStep(tool: "run_command", arguments: ["command_id": .text("mc_loop")])])
        let report = await runner(recorder).run(m, context: { context }, policy: .standard)
        XCTAssertEqual(report.steps.map(\.outcome), ["refused"])
        let tools = await recorder.tools
        XCTAssertEqual(tools, [], "nothing may reach the invoker")
        XCTAssertTrue(report.stoppedAt?.contains("cannot run another macro") == true,
                      report.stoppedAt ?? "")
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

    /// A macro whose steps are all `run_command` must still be *shown* before it runs.
    ///
    /// It was not. `run_command` is declared `.runCommand`, which is not a mutating capability, so the
    /// macro-level decision came out `.allow` — no plan, no confirmation — and the step then re-entered
    /// `invoke` under the raised autonomy that approval was supposed to buy. Measured before the fix:
    /// this exact macro returned `.ok` under `PermissionPolicy.standard` and `cm_DeleteReal` ran, with
    /// nothing put in front of the user at any point.
    func test_aMacroOfCommandsIsStillPutInFrontOfTheUser() async throws {
        let bridge = FakeBridge()
        let m = Macro(id: "del", title: "Delete", steps: [
            MacroStep(tool: "run_command", arguments: ["command_id": .text("cm_DeleteReal")])])
        // Without a host to ask, the floor: a `run_command` step is assumed to change something.
        XCTAssertEqual(MacroPlan.capability(of: m), .write)
        let outcome = try await core([m], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "del"]), policy: .standard)
        guard case .needsConfirmation = outcome else {
            return XCTFail("expected a plan, got \(outcome)")
        }
        let ran = await bridge.ranCommand
        XCTAssertNil(ran, "nothing may run before the plan is confirmed")
    }

    /// The floor is a floor, not a verdict: asked, the host says a refresh changes nothing, and a macro
    /// that only refreshes is not gated like a delete.
    func test_aMacroOfHarmlessCommandsIsNotGatedLikeAWrite() async throws {
        let bridge = FakeBridge()
        let m = Macro(id: "refresh", title: "Refresh", steps: [
            MacroStep(tool: "run_command", arguments: ["command_id": .text("cm_RereadSource")])])
        let outcome = try await core([m], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "refresh"]), policy: .standard)
        guard case .ok = outcome else { return XCTFail("expected ok, got \(outcome)") }
        let ran = await bridge.ranCommand
        XCTAssertEqual(ran, "cm_RereadSource")
    }

    /// The step-level gate is still there, and still keeps the session's allow-list: a macro approved
    /// as a whole does not get to do what the session may not do.
    func test_aStepIsStillGatedByWhatItsCommandActuallyDoes() async throws {
        let bridge = FakeBridge()
        let m = Macro(id: "del", title: "Delete", steps: [
            MacroStep(tool: "run_command", arguments: ["command_id": .text("cm_DeleteReal")])])
        let policy = PermissionPolicy(autonomy: .autonomous,
                                      allowed: Set(Capability.allCases).subtracting([.write]))
        let outcome = try await core([m], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "del"]), policy: policy)
        guard case .refused(let reason) = outcome else {
            return XCTFail("expected a refusal, got \(outcome)")
        }
        let ran = await bridge.ranCommand
        XCTAssertTrue(reason.contains("write"), reason)
        XCTAssertNil(ran, "the command must not have run")
    }

    /// `run_command("mc_…")` is a macro calling a macro through the command registry, and it recurses
    /// without bound: the registry runs the macro, the macro runs the step, and the host dispatches
    /// each round into its own detached task, so nothing ever returns to be stopped. Refused before
    /// the plan is proposed.
    func test_aMacroCannotRunAnotherMacroThroughTheCommandRegistry() async throws {
        let bridge = FakeBridge()
        let m = Macro(id: "loop", title: "Loop", steps: [
            MacroStep(tool: "run_command", arguments: ["command_id": .text("mc_loop")])])
        let outcome = try await core([m], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "loop"]), policy: .standard)
        guard case .failed(let error) = outcome else {
            return XCTFail("expected a refusal, got \(outcome)")
        }
        XCTAssertTrue(error.contains("cannot run another macro"), error)
        let ran = await bridge.ranCommand
        XCTAssertNil(ran)
    }

    /// A step that cannot work is found before the plan is proposed, not four steps in — the rule
    /// `rename_batch` already followed. Nothing has run by the time the user is told.
    func test_aMacroWithAnUnrunnableStepIsRefusedBeforeAnyOfItRuns() async throws {
        let bridge = FakeBridge()
        let m = Macro(id: "typo", title: "Typo", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/out")]),
            MacroStep(tool: "reticulate_splines"),
            MacroStep(tool: "move", arguments: ["destination": .text("%T/out")]),
        ])
        let outcome = try await core([m], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "typo"]), policy: .standard)
        guard case .failed(let error) = outcome else {
            return XCTFail("expected a refusal, got \(outcome)")
        }
        XCTAssertTrue(error.contains("reticulate_splines"), error)
        // And the missing `sources` of the third step, in the same message: a macro is fixed in an
        // editor, and one problem per run is one round trip per typo.
        XCTAssertTrue(error.contains("sources"), error)
        let madeDir = await bridge.madeDir
        XCTAssertNil(madeDir, "step 1 must not have run")
    }

    /// A macro that stops halfway says how far it got. `.failed` carries nothing but its string, so
    /// without this the next question — what has already happened to my files? — was answerable only
    /// by opening the action log.
    func test_aStoppedMacroSaysHowManyStepsHadAlreadyRun() async throws {
        let bridge = FakeBridge()
        // Step 2 refers to a step that has not run: past the pre-flight, which cannot know what a
        // placeholder will resolve to, and into the runner, which stops there.
        let m = Macro(id: "half", title: "Half", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/out")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%{9}"),
                                                "destination": .text("%T/out")]),
        ])
        let outcome = try await core([m], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "half"]),
                    policy: PermissionPolicy(autonomy: .autonomous))
        guard case .failed(let error) = outcome else {
            return XCTFail("expected failure, got \(outcome)")
        }
        XCTAssertTrue(error.contains("1 of 2 steps had already been carried out"), error)
    }

    private func askingMacro() -> Macro {
        Macro(id: "ask", title: "Ask", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/%{ask:Folder=Archive}")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%S"),
                                                "destination": .text("%T/%{ask:Folder=Archive}")]),
        ])
    }

    /// The answer has to be *in the plan*. A macro that asked when it reached the step would have been
    /// approved on a guess about what the user was going to type.
    func test_theAnswerIsInTheRowsBeforeTheyAreApproved() async throws {
        let bridge = FakeBridge()
        await bridge.setAskAnswers(["Folder": "Rechnungen"])
        let core = self.core([askingMacro()], bridge: bridge)
        let outcome = try await core.invoke(tool: "run_macro", arguments: args(["macro_id": "ask"]),
                                            policy: .standard)
        guard case .needsConfirmation(_, let token) = outcome else {
            return XCTFail("expected a plan, got \(outcome)")
        }
        let rows = await core.planItems(token: token)
        XCTAssertTrue(rows[0].text.contains("Rechnungen"), rows[0].text)
        let asked = await bridge.askCount
        XCTAssertEqual(asked, 1, "one question, asked once, however many steps use it")
    }

    /// And carried from the plan to the run: asking again on confirmation could come back different,
    /// and then the approved rows were about something else.
    func test_theAnswerIsNotAskedForASecondTimeWhenTheRunStarts() async throws {
        let bridge = FakeBridge()
        await bridge.setAskAnswers(["Folder": "Rechnungen"])
        let core = self.core([askingMacro()], bridge: bridge)
        guard case .needsConfirmation(_, let token) = try await core.invoke(
            tool: "run_macro", arguments: args(["macro_id": "ask"]), policy: .standard) else {
            return XCTFail("expected a plan")
        }
        _ = try await core.confirm(token: token, rejecting: [])
        let asked = await bridge.askCount
        let madeDir = await bridge.madeDir
        XCTAssertEqual(asked, 1)
        XCTAssertEqual(madeDir, "/b/Rechnungen")
    }

    /// Cancelling the question cancels the macro, before anything is proposed and long before anything
    /// runs.
    func test_cancellingTheQuestionRunsNothing() async throws {
        let bridge = FakeBridge()
        await bridge.setAskAnswers(nil)
        let outcome = try await core([askingMacro()], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "ask"]), policy: .standard)
        guard case .failed(let error) = outcome else {
            return XCTFail("expected failure, got \(outcome)")
        }
        XCTAssertTrue(error.contains("nobody to ask"), error)
        let madeDir = await bridge.madeDir
        XCTAssertNil(madeDir)
    }

    /// A macro with no questions must not put a dialog in front of anybody.
    func test_aMacroWithNoQuestionsAsksNothing() async throws {
        let bridge = FakeBridge()
        _ = try await core([tidyMacro()], bridge: bridge)
            .invoke(tool: "run_macro", arguments: args(["macro_id": "tidy"]), policy: .standard)
        let asked = await bridge.askCount
        XCTAssertEqual(asked, 0)
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
