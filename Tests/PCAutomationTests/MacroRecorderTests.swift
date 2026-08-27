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

    /// The paths stay absolute. A recorder that turned `/Users/me/Downloads` back into `%P` would be
    /// guessing that the folder was incidental, and a macro that quietly means "wherever I happen to
    /// be" is worse than one whose paths are visible and editable.
    func test_pathsAreNotGeneralisedBackIntoPlaceholders() {
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
        XCTAssertEqual(c[0].unavailable, "its arguments were too large to record in full")
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
        XCTAssertEqual(c[0].unavailable, "this action did not succeed")
    }

    func test_aRecordedMacroRunIsNotOfferedBecauseNestingIsRefused() {
        let c = MacroRecorder.candidates(from: [entry("run_macro", #"{"macro_id":"x"}"#)])
        XCTAssertFalse(c[0].isReplayable)
        XCTAssertEqual(c[0].unavailable, "a macro cannot run another macro")
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
        XCTAssertEqual(c[0].unavailable, "its arguments could not be read back")
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
