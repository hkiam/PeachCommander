// SPDX-License-Identifier: Apache-2.0
// The user's OSA scripts on disk (F-477): the folder is the source of truth, scripts.json only carries
// what a script file cannot.

import XCTest
@testable import PCAutomation

final class ScriptStoreTests: XCTestCase {

    private func store() throws -> ScriptStore {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-scripts-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return ScriptStore(directory: dir)
    }

    private func write(_ s: ScriptStore, _ name: String, _ body: String = "return 1") throws {
        try body.write(to: s.directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    /// Dropping a file into the folder is enough to add a script — no registration step.
    func test_aFileInTheFolderIsAScript() throws {
        let s = try store()
        try write(s, "Tidy Downloads.applescript")
        let scripts = s.scripts()
        XCTAssertEqual(scripts.count, 1)
        XCTAssertEqual(scripts[0].id, "Tidy-Downloads")
        XCTAssertEqual(scripts[0].title, "Tidy Downloads")
        XCTAssertEqual(scripts[0].language, "AppleScript")
        XCTAssertEqual(scripts[0].mode, .subprocess, "the safe default")
        XCTAssertEqual(scripts[0].commandName, "plugin.script.run.Tidy-Downloads")
    }

    func test_theExtensionDecidesTheLanguage() throws {
        let s = try store()
        try write(s, "a.applescript")
        try write(s, "b.jxa")
        try write(s, "c.js")
        try write(s, "d.scpt")
        try write(s, "notes.txt")
        XCTAssertEqual(s.scripts().map { "\($0.fileName)=\($0.language)" },
                       ["a.applescript=AppleScript", "b.jxa=JavaScript",
                        "c.js=JavaScript", "d.scpt=AppleScript"],
                       "and a .txt is not a script")
    }

    func test_metadataSuppliesTitleModeAndTimeout() throws {
        let s = try store()
        try write(s, "x.applescript")
        try s.saveMetadata([ScriptDefinition(id: "x", fileName: "x.applescript", title: "Do the thing",
                                            language: "AppleScript", mode: .inProcess,
                                            timeoutSeconds: 5)])
        let script = try XCTUnwrap(s.script(id: "x"))
        XCTAssertEqual(script.title, "Do the thing")
        XCTAssertEqual(script.mode, .inProcess)
        XCTAssertEqual(script.timeoutSeconds, 5)
    }

    /// The file decides its own name and language. A metadata entry claiming otherwise would let a JSON
    /// file decide how a `.applescript` is run, which is the wrong way round.
    func test_theFileWinsOverMetadataAboutItselfa() throws {
        let s = try store()
        try write(s, "x.jxa")
        try s.saveMetadata([ScriptDefinition(id: "x", fileName: "somethingelse.applescript",
                                            title: "T", language: "AppleScript", mode: .inProcess)])
        let script = try XCTUnwrap(s.script(id: "x"))
        XCTAssertEqual(script.fileName, "x.jxa")
        XCTAssertEqual(script.language, "JavaScript")
        XCTAssertEqual(script.mode, .inProcess, "but what the file cannot say still comes from metadata")
    }

    /// Dragging a script out of the folder is how it is removed; a leftover metadata entry is not an
    /// error to report at the user.
    func test_metadataForAMissingFileIsIgnored() throws {
        let s = try store()
        try s.saveMetadata([ScriptDefinition(id: "gone", fileName: "gone.applescript", title: "Gone",
                                            language: "AppleScript", mode: .inProcess)])
        XCTAssertTrue(s.scripts().isEmpty)
    }

    /// Only entries that say something are written, so the folder does not have to be kept in sync.
    func test_defaultsAreNotWrittenOut() throws {
        let s = try store()
        try write(s, "plain.applescript")
        try s.saveMetadata(s.scripts())
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: s.directory.appendingPathComponent("scripts.json").path))
    }

    func test_malformedMetadataLeavesEveryScriptOnDefaults() throws {
        let s = try store()
        try write(s, "x.applescript")
        try Data("{ not json".utf8).write(to: s.directory.appendingPathComponent("scripts.json"))
        let script = try XCTUnwrap(s.script(id: "x"))
        XCTAssertEqual(script.mode, .subprocess)
        XCTAssertEqual(script.title, "x")
    }

    func test_seedingPutsOneWorkingExampleThereAndOnlyOnce() throws {
        let s = try store()
        try s.seedIfEmpty()
        XCTAssertEqual(s.scripts().map(\.fileName), ["Example.applescript"])
        try write(s, "mine.applescript")
        try s.seedIfEmpty()
        XCTAssertEqual(s.scripts().count, 2, "seeding again adds nothing")
    }

    /// The id becomes a command id suffix, which `acceptsSuffix` requires to hold no further dot.
    func test_anIdHoldsNothingThatWouldBreakACommandId() throws {
        let s = try store()
        try write(s, "my script v1.2.applescript")
        let script = try XCTUnwrap(s.scripts().first)
        XCTAssertFalse(script.id.contains("."), script.id)
        XCTAssertFalse(script.id.contains(" "), script.id)
        XCTAssertTrue(script.commandName.hasPrefix("plugin.script.run."))
        XCTAssertFalse(script.commandName.dropFirst("plugin.script.run.".count).contains("."))
    }
}
