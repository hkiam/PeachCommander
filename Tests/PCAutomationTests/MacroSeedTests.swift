// SPDX-License-Identifier: Apache-2.0
// The macros the app ships with (F-478).
//
// A shipped example is documentation that runs, which is exactly why it has to be held to the
// catalogue rather than to a proofread: a macro naming a tool that has since been renamed appears in
// the Command Browser, goes on a button, and fails the first time somebody trusts it. Everything
// here is checked against the same `AutomationCatalog` the runner uses.

import XCTest
@testable import PCAutomation

final class MacroSeedTests: XCTestCase {

    private func seed() throws -> [Macro] {
        let macros = MacroSeed.macros()
        try XCTSkipIf(macros.isEmpty, "the seed did not decode at all — see the JSON test below")
        return macros
    }

    /// The file as written must be readable by the decoder that will read it on disk. A trailing
    /// comma or a stray brace makes every example vanish and leaves the user with an empty editor.
    func test_theSeedIsValidJSONAndDecodes() throws {
        let data = Data(MacroSeed.json.utf8)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
        XCTAssertNoThrow(try JSONDecoder().decode([Macro].self, from: data))
    }

    /// The examples are the point; the count is the promise that they are still there.
    func test_thereAreAtLeastFiveRunnableExamples() throws {
        let runnable = try seed().filter { !$0.steps.isEmpty }
        XCTAssertGreaterThanOrEqual(runnable.count, 5, "shipped examples: \(runnable.map(\.id))")
    }

    /// Every step names a real tool and passes its required arguments — the same check the Core now
    /// applies before it proposes a macro, so a shipped example cannot be one the Core would refuse.
    func test_everyExampleWouldPassThePreflight() throws {
        for macro in try seed() {
            XCTAssertEqual(MacroPlan.problems(of: macro), [], "macro “\(macro.id)”")
        }
    }

    /// Ids survive `MacroStore`: an id that sanitises to something else would register under a command
    /// name the file does not mention, and an empty one would be dropped without a word.
    func test_idsAreAlreadyInTheFormACommandNameNeeds() throws {
        for macro in MacroSeed.macros() {
            XCTAssertEqual(MacroStore.sanitize(macro.id), macro.id, "id “\(macro.id)”")
        }
        let ids = MacroSeed.macros().map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "two examples share an id: \(ids)")
    }

    /// The explanatory entry has no steps, so `MacroStore` drops it — otherwise it would register as a
    /// command that does nothing and appear on the button-bar picker beside the real ones.
    func test_theReadmeEntryIsNotAMacro() throws {
        let store = try temporaryStore()
        for file in MacroSeed.files() {
            try file.data.write(to: store.directory.appendingPathComponent(file.name))
        }
        let loaded = store.load()
        XCTAssertEqual(loaded.problems, [])
        XCTAssertFalse(loaded.macros.contains { $0.id == "_readme" })
        XCTAssertEqual(loaded.macros.count, MacroSeed.macros().filter { !$0.steps.isEmpty }.count)
    }

    /// Every example is described by a sentence rather than by its tool name and raw arguments. This
    /// is what the confirmation dialog shows, and "move_to_trash paths=%S" is not a row somebody can
    /// agree to.
    func test_everyStepReadsAsASentenceInTheConfirmation() throws {
        let context = MacroContext(activeDirectory: "/a", inactiveDirectory: "/b",
                                   cursorPath: "/a/report.pdf",
                                   selection: ["/a/one.pdf", "/a/two.pdf"],
                                   startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        for macro in try seed() where !macro.steps.isEmpty {
            for row in MacroPlan.rows(of: macro, resolvedWith: context) {
                // The unresolved form is the tool name followed by `key=value` pairs; a resolved row
                // never looks like that.
                XCTAssertFalse(row.text.contains("="), "macro “\(macro.id)” row \(row.id): \(row.text)")
                XCTAssertFalse(row.text.contains("%"), "macro “\(macro.id)” row \(row.id): \(row.text)")
            }
        }
    }

    /// The one example that deletes must be gated as a delete, and the ones that only file things
    /// away as writes. If this ever came out `.read` the examples would run with nothing shown.
    func test_theExamplesAreGatedAsWhatTheyDo() throws {
        let byID = Dictionary(uniqueKeysWithValues: try seed().map { ($0.id, $0) })
        XCTAssertEqual(byID["clean-temp"].map { MacroPlan.capability(of: $0) }, .delete)
        XCTAssertEqual(byID["stage-by-month"].map { MacroPlan.capability(of: $0) }, .write)
        XCTAssertEqual(byID["mark-reviewed"].map { MacroPlan.capability(of: $0) }, .write)
    }

    /// The chaining example is the only one that can be wrong in a way the catalogue cannot see: it
    /// names a *field* of another tool's result. This pins the field to what `merge_files` returns.
    func test_theChainingExampleNamesAFieldMergeFilesActuallyReturns() throws {
        let merged = try XCTUnwrap(MacroSeed.macros().first { $0.id == "merge-csv" })
        let last = try XCTUnwrap(merged.steps.last)
        XCTAssertEqual(last.tool, "open_path")
        guard case .text(let template)? = last.arguments["path"] else {
            return XCTFail("the last step should take a template path")
        }
        // The shape `DefaultAutomationCore` returns for merge_files.
        let payload = try JSONSerialization.data(
            withJSONObject: ["destination": "/a/merged-2023-11-14.csv", "files_merged": 3, "rows": 12])
        let resolved = try MacroPlaceholders.resolve(
            ["path": .text(template)],
            context: MacroContext(activeDirectory: "/a", startedAt: Date()),
            results: ["2": payload])
        XCTAssertEqual(resolved["path"], .text("/a/merged-2023-11-14.csv"))
    }

    /// The asking example has to ask exactly one question, however many steps mention it — that is the
    /// property the "same question, one field" rule buys, and the example is what demonstrates it.
    func test_theAskingExampleAsksOneQuestionForItsTwoSteps() throws {
        let macro = try XCTUnwrap(MacroSeed.macros().first { $0.id == "file-into-named-folder" })
        let questions = MacroPlaceholders.questions(in: macro)
        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(questions.first?.prompt, "Folder name")
        XCTAssertEqual(questions.first?.defaultValue, "Archive")
        XCTAssertEqual(macro.steps.count, 2, "both steps use the answer")
    }

    private func temporaryStore() throws -> MacroStore {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-macro-seed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return MacroStore(directory: dir)
    }
}
