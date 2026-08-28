// SPDX-License-Identifier: Apache-2.0
// Building a macro out of the audit log (F-478).

import XCTest
@testable import PCAutomation

final class MacroRecorderTests: XCTestCase {

    private func entry(_ tool: String, _ json: String?, outcome: String = "ok",
                       at: Double = 1) -> AuditEntry {
        var e = AuditEntry(at: at, tool: tool, capability: "write", arguments: "readable…",
                           outcome: outcome, detail: nil)
        e.argumentsJSON = json
        return e
    }

    func test_anEntryBecomesTheStepThatRan() {
        let c = MacroRecorder.candidates(from: [
            entry("make_directory", #"{"path":"/b/out"}"#)])
        XCTAssertEqual(c.count, 1)
        XCTAssertTrue(c[0].isReplayable)
        XCTAssertEqual(c[0].step, MacroStep(tool: "make_directory",
                                            arguments: ["path": .text("/b/out")]))
    }

    /// The paths stay absolute *unless asked*. A recorder that turned `/Users/me/Downloads` back into
    /// `%P` on its own would be guessing that the folder was incidental, and a macro that quietly means
    /// "wherever I happen to be" is worse than one whose paths are visible and editable. The
    /// substitution is offered instead — see `MacroGeneralisationTests`.
    func test_pathsAreNotGeneralisedUnlessAsked() {
        let c = MacroRecorder.candidates(from: [
            entry("move", #"{"destination":"/b/out","sources":["/a/f.txt"]}"#)])
        XCTAssertEqual(c[0].step?.arguments["sources"], .list(["/a/f.txt"]))
        XCTAssertEqual(c[0].step?.arguments["destination"], .text("/b/out"))
    }

    /// `arguments` is clipped at 60 characters per value for a human reader, so a step built from it
    /// would carry half a path. Entries logged before the verbatim field existed say so.
    func test_anEntryWithoutVerbatimArgumentsIsOfferedAsUnavailable() {
        let c = MacroRecorder.candidates(from: [entry("move", nil)])
        XCTAssertFalse(c[0].isReplayable)
        XCTAssertEqual(c[0].unavailable, .argumentsTooLarge)
    }

    /// The row is read to tell two similar actions apart, and what distinguishes them is the file name
    /// — which is at the end of a path, exactly the part the log's readable form clips away.
    func test_aRowReadsAsAnActionAndNotAsAPath() {
        let c = MacroRecorder.candidates(from: [
            entry("move", #"{"destination":"/Users/me/Documents/2026-08","sources":["/Users/me/Downloads/invoice.pdf"]}"#)])
        XCTAssertEqual(c[0].text, "Move invoice.pdf into “2026-08”")
    }

    func test_rowsForTheToolsAMacroUsesMost() {
        func text(_ tool: String, _ json: String) -> String {
            MacroRecorder.candidates(from: [entry(tool, json)])[0].text
        }
        XCTAssertEqual(text("make_directory", #"{"path":"/a/2026-08"}"#),
                       "Create the folder “2026-08”")
        XCTAssertEqual(text("rename", #"{"path":"/a/old.txt","new_name":"new.txt"}"#),
                       "Rename “old.txt” to “new.txt”")
        XCTAssertEqual(text("move_to_trash", #"{"paths":["/a/x","/a/y","/a/z","/a/w"]}"#),
                       "Move x, y, z +1 more to the Trash")
        XCTAssertEqual(text("set_comment", #"{"path":"/a/f.txt","comment":"kept"}"#),
                       "Comment “f.txt”: kept")
        XCTAssertEqual(text("run_command", #"{"command_id":"cm_PackFiles"}"#),
                       "Run the command cm_PackFiles")
    }

    /// A tool added to the catalogue after that switch was written still gets a readable row rather
    /// than a blank one.
    func test_anUnrecognisedToolStillGetsARow() {
        let c = MacroRecorder.candidates(from: [entry("reticulate", #"{"path":"/a/b/spline.dat"}"#)])
        XCTAssertEqual(c[0].text, "reticulate: spline.dat")
    }

    /// With no verbatim arguments there is nothing better than the log's own line, and it is used.
    func test_withoutVerbatimArgumentsTheRowFallsBackToTheLogLine() {
        let c = MacroRecorder.candidates(from: [entry("move", nil)])
        XCTAssertEqual(c[0].text, "move readable…")
    }

    func test_aFailedActionIsNotACandidate() {
        let c = MacroRecorder.candidates(from: [
            entry("move", #"{"sources":["/a"]}"#, outcome: "failed")])
        XCTAssertFalse(c[0].isReplayable)
        XCTAssertEqual(c[0].unavailable, .didNotSucceed)
    }

    func test_aRecordedMacroRunIsNotOfferedBecauseNestingIsRefused() {
        let c = MacroRecorder.candidates(from: [entry("run_macro", #"{"macro_id":"x"}"#)])
        XCTAssertFalse(c[0].isReplayable)
        XCTAssertEqual(c[0].unavailable, .nesting)
    }

    /// The list is newest-first, because that is how somebody looks for what they just did. The macro
    /// has to be oldest-first, or it runs backwards.
    func test_theMacroRunsInTheOrderThingsHappened() {
        let newestFirst = [entry("move", #"{"sources":["/a/f"]}"#, at: 2),
                           entry("make_directory", #"{"path":"/b/out"}"#, at: 1)]
        let c = MacroRecorder.candidates(from: newestFirst)
        let m = MacroRecorder.macro(id: "m", title: "M", from: c, keeping: ["1", "2"])
        XCTAssertEqual(m.steps.map(\.tool), ["make_directory", "move"])
    }

    func test_onlyTheKeptRowsGoIn() {
        let c = MacroRecorder.candidates(from: [
            entry("move", #"{"sources":["/a/f"]}"#, at: 3),
            entry("set_tags", #"{"path":"/a/f","tags":["x"]}"#, at: 2),
            entry("make_directory", #"{"path":"/b/out"}"#, at: 1)])
        let m = MacroRecorder.macro(id: "m", title: "M", from: c, keeping: ["1", "3"])
        XCTAssertEqual(m.steps.map(\.tool), ["make_directory", "move"])
    }

    /// JSONSerialization hands `true` back as an NSNumber, and read as a number it would turn a flag
    /// into 1 — which is a different argument to every tool that takes one.
    func test_aBooleanStaysABoolean() {
        let c = MacroRecorder.candidates(from: [entry("x", #"{"flag":true,"n":3}"#)])
        XCTAssertEqual(c[0].step?.arguments["flag"], .flag(true))
        XCTAssertEqual(c[0].step?.arguments["n"], .number(3))
    }

    /// Refused, not flattened: a nested object has no macro-argument shape, and passing something
    /// "close" would call the tool with arguments nobody wrote.
    func test_anArgumentShapeAMacroCannotHoldIsRefused() {
        let c = MacroRecorder.candidates(from: [entry("search", #"{"query":{"masks":["*.txt"]}}"#)])
        XCTAssertFalse(c[0].isReplayable)
        XCTAssertEqual(c[0].unavailable, .unreadableArguments)
    }

    /// End to end against the log the Core actually writes, rather than against a hand-built entry.
    func test_theCoreWritesEnoughToRebuildTheStep() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-rec-\(UUID().uuidString).jsonl")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let log = AuditLog(url: url)
        let core = DefaultAutomationCore(bridge: FakeBridge(), audit: log)
        _ = try await core.invoke(tool: "make_directory",
                                  arguments: try JSONSerialization.data(withJSONObject: ["path": "/b/out"]),
                                  policy: PermissionPolicy(autonomy: .autonomous))

        let c = MacroRecorder.candidates(from: log.recent(limit: 10))
        XCTAssertEqual(c.count, 1)
        XCTAssertEqual(c[0].step, MacroStep(tool: "make_directory",
                                            arguments: ["path": .text("/b/out")]))
    }

    /// The cap is what keeps a whole document out of the log; the entry then says so instead of
    /// carrying half of one.
    func test_argumentsOverTheCapAreNotRecordedVerbatim() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-rec-\(UUID().uuidString).jsonl")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let log = AuditLog(url: url)
        let core = DefaultAutomationCore(bridge: FakeBridge(), audit: log)
        let big = String(repeating: "x", count: argumentsJSONCap + 100)
        _ = try await core.invoke(
            tool: "write_file",
            arguments: try JSONSerialization.data(withJSONObject: ["path": "/b/f", "content": big]),
            policy: PermissionPolicy(autonomy: .autonomous))

        let entries = log.recent(limit: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries[0].argumentsJSON)
        XCTAssertFalse(MacroRecorder.candidates(from: entries)[0].isReplayable)
    }
}

/// The second record the recorder reads (F-478): what the user did in the panels.
///
/// The history knows how it encoded a copy; this module knows what a copy is called in the catalogue.
/// The seam is `RecordedAction.PanelOperation`, and these are the assertions that keep the two names
/// from drifting — a step naming `trash` instead of `move_to_trash` is a macro that fails its pre-flight.
final class RecordedPanelActionTests: XCTestCase {

    private func step(_ operation: RecordedAction.PanelOperation) throws -> MacroStep {
        let action = try XCTUnwrap(RecordedAction.panel(operation, summary: "x", at: Date()))
        XCTAssertEqual(action.source, .panel)
        let candidates = MacroRecorder.candidates(from: [action])
        return try XCTUnwrap(candidates.first?.step,
                             candidates.first?.unavailable?.english ?? "no candidate")
    }

    func test_everyPanelOperationBecomesAStepTheCatalogueKnows() throws {
        let operations: [RecordedAction.PanelOperation] = [
            .copy(items: ["/a/one.pdf"], destination: "/b"),
            .move(items: ["/a/one.pdf", "/a/two.pdf"], destination: "/b"),
            .trash(["/a/one.pdf"]),
            .deletePermanently(["/a/one.pdf"]),
            .rename(pairs: [(old: "a.txt", new: "b.txt")], directory: "/a"),
            .makeDirectory("/a/new"),
        ]
        for operation in operations {
            let step = try step(operation)
            // The whole point: every one of these must survive the check the Core now runs before it
            // proposes a macro, or the recorder produces macros that cannot run.
            XCTAssertEqual(MacroPlan.problems(of: Macro(id: "m", title: "M", steps: [step])), [],
                           "step \(step.tool)")
        }
    }

    func test_theToolNamesAreTheCataloguesOwn() throws {
        XCTAssertEqual(try step(.trash(["/a/x"])).tool, "move_to_trash")
        XCTAssertEqual(try step(.deletePermanently(["/a/x"])).tool, "delete_permanently")
        XCTAssertEqual(try step(.makeDirectory("/a/new")).tool, "make_directory")
        XCTAssertEqual(try step(.rename(pairs: [(old: "a", new: "b")], directory: "/a")).tool,
                       "rename_batch")
    }

    func test_aRenameCarriesBothNameListsAndItsDirectory() throws {
        let step = try step(.rename(pairs: [(old: "a.txt", new: "b.txt"),
                                            (old: "c.txt", new: "d.txt")], directory: "/a"))
        XCTAssertEqual(step.arguments["old_names"], .list(["a.txt", "c.txt"]))
        XCTAssertEqual(step.arguments["new_names"], .list(["b.txt", "d.txt"]))
        XCTAssertEqual(step.arguments["directory"], .text("/a"))
    }

    /// An operation with nothing in it is not a candidate. It would become a step the runner stops on
    /// ("nothing to act on"), offered from a list of things that supposedly happened.
    func test_anEmptyOperationIsNotOffered() {
        XCTAssertNil(RecordedAction.panel(.trash([]), summary: "x", at: Date()))
        XCTAssertNil(RecordedAction.panel(.copy(items: ["/a"], destination: ""), summary: "x", at: Date()))
        XCTAssertNil(RecordedAction.panel(.makeDirectory(""), summary: "x", at: Date()))
    }

    /// Both records in one list, newest first, whichever order they arrive in.
    func test_theTwoRecordsAreMergedByTime() throws {
        let old = try XCTUnwrap(RecordedAction.panel(.trash(["/a/old.pdf"]), summary: "old",
                                                     at: Date(timeIntervalSince1970: 100)))
        let recent = RecordedAction(at: Date(timeIntervalSince1970: 200), tool: "make_directory",
                                    argumentsJSON: #"{"path":"/a/new"}"#, succeeded: true,
                                    summary: "new", source: .automation)
        let candidates = MacroRecorder.candidates(from: [old, recent])
        XCTAssertEqual(candidates.map(\.tool), ["make_directory", "move_to_trash"])
        XCTAssertEqual(candidates.map(\.source), [.automation, .panel])
        // And the steps come out in the order they *happened* when the macro is built.
        let macro = MacroRecorder.macro(id: "m", title: "M", from: candidates, keeping: ["1", "2"])
        XCTAssertEqual(macro.steps.map(\.tool), ["move_to_trash", "make_directory"])
    }
}


/// Following the panels instead of the recorded files (F-478).
///
/// The recorded form is right by default — a macro that quietly meant "the folder I happened to be in
/// that day" is the failure this could otherwise cause — so what matters here is as much where the
/// substitution *does not* reach as where it does.
final class MacroGeneralisationTests: XCTestCase {

    private let context = MacroContext(activeDirectory: "/Users/me/Downloads",
                                       inactiveDirectory: "/Users/me/Documents",
                                       startedAt: Date(timeIntervalSince1970: 0))

    private func general(_ tool: String, _ arguments: [String: MacroArgument]) -> [String: MacroArgument] {
        MacroRecorder.generalised(MacroStep(tool: tool, arguments: arguments),
                                  context: context).arguments
    }

    func test_filesFromOneFolderBecomeTheSelection() {
        let out = general("move", ["sources": .list(["/Users/me/Downloads/a.pdf",
                                                     "/Users/me/Downloads/b.pdf"]),
                                   "destination": .text("/Users/me/Documents")])
        XCTAssertEqual(out["sources"], .text("%S"))
        XCTAssertEqual(out["destination"], .text("%T"))
    }

    /// The whole point of the feature, in one assertion: the same recording, run tomorrow in another
    /// pair of folders, acts on what is selected there.
    func test_aRecordedMoveBecomesMoveTheSelectionToTheOtherPanel() throws {
        let step = MacroStep(tool: "move",
                             arguments: ["sources": .list(["/Users/me/Downloads/a.pdf"]),
                                         "destination": .text("/Users/me/Documents")])
        let general = MacroRecorder.generalised(step, context: context)
        let elsewhere = MacroContext(activeDirectory: "/tmp/in", inactiveDirectory: "/tmp/out",
                                     selection: ["/tmp/in/x.txt", "/tmp/in/y.txt"],
                                     startedAt: Date())
        let resolved = try MacroPlaceholders.resolve(general.arguments, context: elsewhere, results: [:])
        XCTAssertEqual(resolved["sources"], .list(["/tmp/in/x.txt", "/tmp/in/y.txt"]))
        XCTAssertEqual(resolved["destination"], .text("/tmp/out"))
    }

    func test_aPathInsideAPanelKeepsItsTail() {
        let out = general("make_directory", ["path": .text("/Users/me/Documents/2026-08")])
        XCTAssertEqual(out["path"], .text("%T/2026-08"))
    }

    /// A panel showing a subfolder of the other one must not lose to its own parent.
    func test_theLongerPanelFolderWins() {
        let nested = MacroContext(activeDirectory: "/Users/me/Documents/Invoices",
                                  inactiveDirectory: "/Users/me/Documents",
                                  startedAt: Date())
        let step = MacroStep(tool: "make_directory",
                             arguments: ["path": .text("/Users/me/Documents/Invoices/2026")])
        XCTAssertEqual(MacroRecorder.generalised(step, context: nested).arguments["path"],
                       .text("%P/2026"))
    }

    /// Files spread over two folders are not a selection — `%S` is the selection of *one* panel, and
    /// folding them would produce a macro that acts on files it was never shown.
    func test_filesFromDifferentFoldersAreLeftAlone() {
        let sources: MacroArgument = .list(["/Users/me/Downloads/a.pdf", "/tmp/b.pdf"])
        XCTAssertEqual(general("move", ["sources": sources])["sources"], sources)
    }

    /// A path under neither panel stays a path. There is nothing to fold it into, and a macro that
    /// silently pointed somewhere else would be worse than one that names a folder plainly.
    func test_aPathOutsideBothPanelsIsLeftAlone() {
        XCTAssertEqual(general("make_directory", ["path": .text("/Volumes/Backup/2026")])["path"],
                       .text("/Volumes/Backup/2026"))
    }

    /// `old_names` is a list of strings too, and turning it into `%S` would rename whatever happens to
    /// be selected to a fixed list of names. Only the keys that mean "the files acted on" are folded.
    func test_renameNameListsAreNotASelection() {
        let out = general("rename_batch", ["old_names": .list(["a.txt", "b.txt"]),
                                           "new_names": .list(["c.txt", "d.txt"]),
                                           "directory": .text("/Users/me/Downloads")])
        XCTAssertEqual(out["old_names"], .list(["a.txt", "b.txt"]))
        XCTAssertEqual(out["new_names"], .list(["c.txt", "d.txt"]))
        XCTAssertEqual(out["directory"], .text("%P"), "the directory is a folder and does fold")
    }

    func test_numbersAndFlagsAreUntouched() {
        let out = general("read_file", ["max_bytes": .number(4096), "verbose": .flag(true)])
        XCTAssertEqual(out["max_bytes"], .number(4096))
        XCTAssertEqual(out["verbose"], .flag(true))
    }

    /// With no panels to fold into, nothing changes — the case the sheet uses to decide whether to
    /// offer the option at all.
    func test_withNoPanelFoldersNothingChanges() {
        let empty = MacroContext(activeDirectory: "", startedAt: Date())
        let step = MacroStep(tool: "make_directory", arguments: ["path": .text("/tmp/x")])
        XCTAssertEqual(MacroRecorder.generalised(step, context: empty), step)
    }

    /// The rows the sheet shows: the tokens spelled out, because "%S" is not what somebody reads a
    /// confirmation for.
    func test_theRowSpellsOutTheTokens() {
        let step = MacroStep(tool: "move", arguments: ["sources": .text("%S"),
                                                       "destination": .text("%T/2026-08")])
        let text = MacroPlan.describe(tool: step.tool,
                                      arguments: step.arguments.mapValues(\.jsonValue)) ?? ""
        XCTAssertEqual(MacroRecorder.spelledOut(text), "Move the selection into “2026-08”")
    }

    /// End to end through the builder, which is where the option is actually applied.
    func test_theBuilderAppliesItOnlyWhenAsked() {
        let action = RecordedAction(at: Date(), tool: "move",
                                    argumentsJSON: #"{"destination":"/Users/me/Documents","sources":["/Users/me/Downloads/a.pdf"]}"#,
                                    succeeded: true, summary: "", source: .panel)
        let candidates = MacroRecorder.candidates(from: [action])
        let asRecorded = MacroRecorder.macro(id: "m", title: "M", from: candidates, keeping: ["1"])
        XCTAssertEqual(asRecorded.steps.first?.arguments["sources"],
                       .list(["/Users/me/Downloads/a.pdf"]))
        let following = MacroRecorder.macro(id: "m", title: "M", from: candidates, keeping: ["1"],
                                            following: context)
        XCTAssertEqual(following.steps.first?.arguments["sources"], .text("%S"))
        XCTAssertEqual(following.steps.first?.arguments["destination"], .text("%T"))
    }
}
