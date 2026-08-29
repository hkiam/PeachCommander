// SPDX-License-Identifier: Apache-2.0
// The explicit recording: what falls inside its two boundaries and what does not (F-478).

import XCTest
@testable import PCAutomation

final class MacroRecordingSessionTests: XCTestCase {

    private func panelAction(_ name: String, at: Date = Date()) -> RecordedAction {
        RecordedAction.panel(.makeDirectory("/tmp/\(name)"), summary: "New Folder", at: at)!
    }

    private func auditEntry(_ tool: String, at: Double) -> AuditEntry {
        var e = AuditEntry(at: at, tool: tool, capability: "write", arguments: "readable…",
                           outcome: "ok", detail: nil)
        e.argumentsJSON = #"{"path":"/tmp/x"}"#
        return e
    }

    /// The point of the whole type: nothing is kept until somebody says "record". The alternative — a
    /// buffer that always collects and is read from on stop — would make "stop" mean "the last N
    /// things", which is the other feature and the one whose boundaries were the complaint.
    func test_nothingIsRecordedBeforeItIsStarted() {
        var session = MacroRecordingSession()
        session.record(panelAction("a"))
        XCTAssertFalse(session.isRecording)
        XCTAssertEqual(session.count, 0)
    }

    func test_whatHappensBetweenStartAndStopIsWhatComesBack() {
        var session = MacroRecordingSession()
        session.start()
        session.record(panelAction("a"))
        session.record(panelAction("b"))
        XCTAssertEqual(session.count, 2)
        let out = session.stop()
        XCTAssertEqual(out.count, 2)
        XCTAssertFalse(session.isRecording)
        XCTAssertEqual(session.count, 0, "a stopped recording keeps nothing for the next one")
    }

    /// In the order they arrived. `MacroRecorder.macro` reverses a newest-first list to build the
    /// steps, so a recording that came back newest-first would produce a macro that runs backwards.
    func test_theOrderIsTheOrderTheyHappened() {
        var session = MacroRecordingSession()
        session.start()
        session.record(panelAction("first"))
        session.record(panelAction("second"))
        let out = session.stop()
        XCTAssertTrue(out[0].argumentsJSON?.contains("first") == true)
        XCTAssertTrue(out[1].argumentsJSON?.contains("second") == true)
    }

    /// Starting again is a new recording, not a continuation: the user pressed the button that says
    /// "record", and finding the previous attempt's steps in the list is the surprise this prevents.
    func test_startingAgainDiscardsTheOneBefore() {
        var session = MacroRecordingSession()
        session.start()
        session.record(panelAction("old"))
        session.start()
        XCTAssertEqual(session.count, 0)
    }

    func test_cancellingProducesNothing() {
        var session = MacroRecordingSession()
        session.start()
        session.record(panelAction("a"))
        session.cancel()
        XCTAssertFalse(session.isRecording)
        XCTAssertEqual(session.stop().count, 0)
    }

    /// The assistant's actions are merged out of the audit log on stop — but only the ones inside the
    /// window. The log is a running one; everything before the start belongs to whatever was being done
    /// before the user decided to record.
    func test_onlyTheAuditEntriesInsideTheWindowAreMerged() {
        var session = MacroRecordingSession()
        let start = Date(timeIntervalSince1970: 1_000)
        session.start(at: start)
        let out = session.stop(mergingAudit: [
            auditEntry("make_directory", at: 500),      // long before the start
            auditEntry("copy", at: 1_010),              // inside
        ])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].tool, "copy")
    }

    /// The audit log's timestamps are whole seconds, so an action logged in the same second as the
    /// start would round out of the window — and that action is exactly the one somebody armed the
    /// recorder for. A second of slack, deliberately.
    func test_anActionInTheSameSecondAsTheStartIsKept() {
        var session = MacroRecordingSession()
        session.start(at: Date(timeIntervalSince1970: 1_000.9))
        let out = session.stop(mergingAudit: [auditEntry("copy", at: 1_000)])
        XCTAssertEqual(out.count, 1)
    }

    /// A recording left armed over something enormous must not grow without limit. The oldest go
    /// first: a recording that has run away from its owner is one whose *end* they still mean.
    func test_theBufferIsCappedAndDropsTheOldest() {
        var session = MacroRecordingSession()
        session.start()
        for i in 0..<(MacroRecordingSession.cap + 5) { session.record(panelAction("n\(i)")) }
        XCTAssertEqual(session.count, MacroRecordingSession.cap)
        let out = session.stop()
        XCTAssertTrue(out.first?.argumentsJSON?.contains("/n5\"") == true
                      || out.first?.argumentsJSON?.contains("n5") == true,
                      "the first five should have been dropped, not the last five")
    }

    /// The indicator counts what a stop *would* yield, which includes the assistant's share — counting
    /// only the panel operations would leave the number short and the user unsure it is working.
    func test_theRunningCountCanIncludeTheAutomationShare() {
        var session = MacroRecordingSession()
        session.start(at: Date(timeIntervalSince1970: 1_000))
        session.record(panelAction("a"))
        let automation = session.automationActions(from: [auditEntry("copy", at: 1_010)])
        XCTAssertEqual(session.count + automation.count, 2)
    }
}

/// A recording has to survive the app stopping: it is armed by hand, it runs while the user works, and
/// losing it to a quit or a crash would be exactly the silent loss the feature exists to prevent.
extension MacroRecordingSessionTests {

    func test_aRunningRecordingSurvivesARoundTripThroughDisk() throws {
        var session = MacroRecordingSession()
        session.start(at: Date(timeIntervalSince1970: 1_000))
        session.record(panelAction("a"))
        session.record(panelAction("b"))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(MacroRecordingSession.self,
                                          from: try encoder.encode(XCTUnwrap(session.resumable)))
        XCTAssertTrue(restored.isRecording)
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored.startedAt, session.startedAt,
                       "the window has to come back too, or the assistant's share is merged wrongly")
    }

    /// An armed recording that has caught nothing is still worth keeping — the arming was the decision,
    /// and coming back to no indicator would read as the app having forgotten.
    func test_anEmptyButArmedRecordingIsStillWorthKeeping() {
        var session = MacroRecordingSession()
        session.start()
        XCTAssertNotNil(session.resumable)
    }

    func test_nothingIsKeptWhenNoRecordingIsRunning() {
        XCTAssertNil(MacroRecordingSession().resumable)
        var stopped = MacroRecordingSession()
        stopped.start()
        _ = stopped.stop()
        XCTAssertNil(stopped.resumable)
    }
}

/// Shift+F4 makes an empty file and never overwrites one. `write_file` does both, so recording it as a
/// write would hand back a macro that empties an existing file the second time it runs.
final class MacroRecordedNewFileTests: XCTestCase {

    func test_aNewFileIsRecordedAsCreateFileAndNotAsAWrite() throws {
        let action = try XCTUnwrap(RecordedAction.panel(.createFile("/tmp/notes.txt"),
                                                        summary: "New File", at: Date()))
        XCTAssertEqual(action.tool, "create_file")
        let candidates = MacroRecorder.candidates(from: [action])
        XCTAssertEqual(candidates.first?.step,
                       MacroStep(tool: "create_file", arguments: ["path": .text("/tmp/notes.txt")]))
    }

    func test_createFileIsInTheCatalogueSoAMacroUsingItValidates() {
        let macro = Macro(id: "m", title: "m",
                          steps: [MacroStep(tool: "create_file",
                                            arguments: ["path": .text("/tmp/x.txt")])])
        XCTAssertEqual(MacroPlan.problems(of: macro, tools: AutomationCatalog.tools), [])
    }

    /// It reads as a creation, not as a write — the row a user approves has to say which of the two it
    /// is, because only one of them can destroy something.
    func test_theRowSaysCreateRatherThanWrite() {
        let phrase = MacroPlan.phrase(tool: "create_file",
                                      argumentsJSON: #"{"path":"/tmp/notes.txt"}"#)
        XCTAssertEqual(phrase?.key, .createFile)
        // The leaf, like every other row: `MacroPlan.phrase` names files by their last component, so a
        // list of steps reads as actions rather than as a column of paths.
        XCTAssertEqual(phrase?.english, "Create the file “notes.txt”")
    }
}
