// SPDX-License-Identifier: Apache-2.0
// The pure half of the macro engine (F-478): the plan a macro amounts to, the placeholder
// resolution its arguments go through, and the store that keeps it on disk.

import XCTest
@testable import PCAutomation

final class MacroPlanTests: XCTestCase {

    private func macro(_ tools: [String]) -> Macro {
        Macro(id: "m", title: "M", steps: tools.map { MacroStep(tool: $0) })
    }

    func test_capability_isTheMostDemandingStep() {
        XCTAssertEqual(MacroPlan.capability(of: macro(["list_directory", "stat_path"])), .read)
        XCTAssertEqual(MacroPlan.capability(of: macro(["list_directory", "move"])), .write)
        // Order must not matter: the delete is the answer whether it is first or last.
        XCTAssertEqual(MacroPlan.capability(of: macro(["move_to_trash", "list_directory"])), .delete)
        XCTAssertEqual(MacroPlan.capability(of: macro(["list_directory", "move_to_trash"])), .delete)
        XCTAssertEqual(MacroPlan.capability(of: macro(["move", "run_shell"])), .shell)
    }

    /// The point of the fail-closed default: a macro written against a newer build must not run as a
    /// read here just because the tool it names is missing.
    func test_capability_ofAnUnknownTool_isAWrite() {
        XCTAssertEqual(MacroPlan.capability(of: macro(["list_directory", "reticulate_splines"])), .write)
    }

    func test_capability_ofAnEmptyMacro_isARead() {
        XCTAssertEqual(MacroPlan.capability(of: macro([])), .read)
    }

    func test_rows_areOneStepEachAndOneBased() {
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/out")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%S")], note: "Move the selection"),
        ])
        let rows = MacroPlan.rows(of: m)
        XCTAssertEqual(rows.map(\.id), ["1", "2"])
        XCTAssertEqual(rows[0].text, "make_directory path=%T/out")
        // A note replaces the derived description; it is the whole reason a note exists.
        XCTAssertEqual(rows[1].text, "Move the selection")
    }

    func test_resolvedRows_readAsActions() {
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/%{date:yyyy-MM}")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%S"),
                                                "destination": .text("%T/%{date:yyyy-MM}")]),
        ])
        let context = MacroContext(activeDirectory: "/a", inactiveDirectory: "/b",
                                   cursorPath: "/a/f.txt", selection: ["/a/one.pdf", "/a/two.pdf"],
                                   startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let rows = MacroPlan.rows(of: m, resolvedWith: context)
        XCTAssertEqual(rows.map(\.text), ["Create the folder “2023-11”",
                                          "Move one.pdf, two.pdf into “2023-11”"])
    }

    /// A `%{1}` cannot be resolved before step 1 has run, and the row says what it is waiting for
    /// instead of showing a guess.
    /// The one part that is still to come must not drag the whole row back to the raw template.
    func test_onlyTheUnresolvableArgumentStandsIn() {
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "merge_files", arguments: ["destination": .text("%T/all.csv")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%{1}"),
                                                "destination": .text("%T/%{date:yyyy-MM}")]),
        ])
        let context = MacroContext(activeDirectory: "/a", inactiveDirectory: "/b",
                                   selection: ["/a/x"],
                                   startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let rows = MacroPlan.rows(of: m, resolvedWith: context)
        XCTAssertEqual(rows[0].text, "Merge 0 file(s) into “all.csv”")
        XCTAssertTrue(rows[1].text.contains("2023-11"), "the date resolved: \(rows[1].text)")
        XCTAssertTrue(rows[1].text.contains("result of step 1"), rows[1].text)
        XCTAssertFalse(rows[1].text.contains("%"), "no raw template survives: \(rows[1].text)")
    }

    func test_aRowThatCannotBeResolvedYetSaysWhatItIsWaitingFor() {
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "merge_files", arguments: ["destination": .text("%T/all.csv")]),
            MacroStep(tool: "open_path", arguments: ["path": .text("%{1}")]),
        ])
        let context = MacroContext(activeDirectory: "/a", inactiveDirectory: "/b",
                                   startedAt: Date(timeIntervalSince1970: 0))
        let rows = MacroPlan.rows(of: m, resolvedWith: context)
        XCTAssertTrue(rows[1].text.contains("the result of step 1"), rows[1].text)
    }

    /// A step with nothing selected is described, not hidden: the reader has to be able to see why the
    /// macro is about to refuse.
    func test_aRowWithNothingSelectedSaysSo() {
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "move", arguments: ["sources": .text("%S"), "destination": .text("%T")])])
        let context = MacroContext(activeDirectory: "/a", inactiveDirectory: "/b",
                                   selection: [], startedAt: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(MacroPlan.rows(of: m, resolvedWith: context)[0].text
            .contains("nothing is selected"),
            "with no step to fill it, an empty selection IS the thing to say")
    }

    /// A plan reading "nothing is selected" above a macro that selects its own files is worse than no
    /// note at all: it announces a failure that is not going to happen.
    func test_aRowDoesNotClaimAProblemAnEarlierStepWillFix() {
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "set_selection", arguments: ["mask": .text("*.pdf")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%S"), "destination": .text("%T")]),
        ])
        let context = MacroContext(activeDirectory: "/a", inactiveDirectory: "/b",
                                   selection: [], startedAt: Date(timeIntervalSince1970: 0))
        let rows = MacroPlan.rows(of: m, resolvedWith: context)
        XCTAssertEqual(rows[0].text, "Select *.pdf", "and the row reads as an action")
        // Argument by argument: the destination resolved, so only the sources stand in — the row is a
        // sentence, not the raw template it used to fall back to.
        XCTAssertEqual(rows[1].text, "Move what an earlier step selects into “b”")
    }

    /// A note replaces the description whether or not anything resolved — it is the author's own words.
    func test_aNoteWinsOverTheResolvedDescription() {
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "move", arguments: ["sources": .text("%S")], note: "Tidy them away")])
        let context = MacroContext(activeDirectory: "/a", selection: ["/a/x"],
                                   startedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(MacroPlan.rows(of: m, resolvedWith: context)[0].text, "Tidy them away")
    }

    func test_commandName_isTheIdPrefixed() {
        XCTAssertEqual(Macro(id: "file-by-date", title: "x").commandName, "mc_file-by-date")
    }
}

final class MacroPlaceholderTests: XCTestCase {

    private let context = MacroContext(
        activeDirectory: "/Users/me/Downloads",
        inactiveDirectory: "/Users/me/Documents",
        cursorPath: "/Users/me/Downloads/report final.pdf",
        selection: ["/Users/me/Downloads/a b.pdf", "/Users/me/Downloads/c.pdf"],
        startedAt: Date(timeIntervalSince1970: 1_700_000_000))   // 2023-11-14 UTC

    private func resolve(_ args: [String: MacroArgument],
                         results: [String: Data?] = [:]) throws -> [String: ResolvedArgument] {
        try MacroPlaceholders.resolve(args, context: context, results: results)
    }

    /// The one deliberate difference from the button bar. A bare `%S` is the selection as a JSON array
    /// of absolute paths, because that is what `copy`, `move` and `move_to_trash` take.
    func test_bareSelectionToken_becomesAListOfAbsolutePaths() throws {
        let out = try resolve(["sources": .text("%S")])
        XCTAssertEqual(out["sources"], .list(context.selection))
    }

    /// A macro run with nothing selected created the destination folder, reported both steps `ok`, and
    /// moved nothing. An empty expansion is a step that has lost its subject, not a smaller step.
    func test_bareSelectionToken_withNothingSelected_throws() throws {
        var empty = context
        empty.selection = []
        XCTAssertThrowsError(try MacroPlaceholders.resolve(["sources": .text("%S")],
                                                          context: empty, results: [:])) {
            XCTAssertEqual($0 as? MacroPlaceholderError, .expandedToNothing("%S"))
        }
    }

    /// But a list written out as `[]` is a real instruction — `set_tags` with an empty list is how tags
    /// are removed — so only *expanded* emptiness is refused.
    func test_anExplicitlyEmptyListIsLeftAlone() throws {
        let out = try resolve(["tags": .list([])])
        XCTAssertEqual(out["tags"], .list([]))
    }

    func test_aStepResultThatIsAnEmptyListThrows() throws {
        let empty = try JSONSerialization.data(withJSONObject: [String]())
        XCTAssertThrowsError(try resolve(["sources": .text("%{1}")], results: ["1": empty])) {
            XCTAssertEqual($0 as? MacroPlaceholderError, .expandedToNothing("%{1}"))
        }
    }

    func test_selectionTokenSurroundedByText_staysAString() throws {
        let out = try resolve(["message": .text("moving %S now")])
        // The button bar's reading: leaf names, space-separated. Unquoted — a macro argument is a
        // value, not a shell word, and quotes here would end up inside a file name.
        XCTAssertEqual(out["message"], .text("moving a b.pdf c.pdf now"))
    }

    func test_pathTokens_areRawPathsWithoutQuoting() throws {
        let out = try resolve(["a": .text("%P"), "b": .text("%T/sub"), "c": .text("%N")])
        XCTAssertEqual(out["a"], .text("/Users/me/Downloads"))
        XCTAssertEqual(out["b"], .text("/Users/me/Documents/sub"))
        // A name with a space must survive as one value; quoting it was the bug this asserts against.
        XCTAssertEqual(out["c"], .text("report final.pdf"))
    }

    func test_dateToken_usesTheMacrosStartTimeAndTheGivenFormat() throws {
        let out = try resolve(["path": .text("%T/%{date:yyyy-MM}")])
        XCTAssertEqual(out["path"], .text("/Users/me/Documents/2023-11"))
        XCTAssertEqual(try resolve(["p": .text("%{date:}")])["p"], .text("2023-11-14"))
    }

    /// `%M` means "the name under the cursor in the other panel" in every button bar in existence, so
    /// a date macro cannot spell month as `%M`. This is the assertion that keeps the two apart.
    func test_theMonthIsNotSpelledAsAPercentLetter() throws {
        let out = try resolve(["p": .text("%M")])
        XCTAssertEqual(out["p"], .text(""), "targetName is empty in this context — not a month")
    }

    func test_unknownBraceToken_isLeftVerbatim() throws {
        XCTAssertEqual(try resolve(["p": .text("%T/%{nope}/x")])["p"],
                       .text("/Users/me/Documents/%{nope}/x"))
    }

    func test_unterminatedBraceToken_isLeftVerbatimRatherThanThrowing() throws {
        XCTAssertEqual(try resolve(["p": .text("%{date:yyyy")])["p"], .text("%{date:yyyy"))
    }

    func test_stepReference_takesAStringOrAListPayload() throws {
        let text = try JSONSerialization.data(withJSONObject: "/tmp/merged.csv" as Any,
                                              options: [.fragmentsAllowed])
        let list = try JSONSerialization.data(withJSONObject: ["/tmp/a", "/tmp/b"])
        let out = try resolve(["one": .text("%{1}"), "two": .text("%{2}")],
                              results: ["1": text, "2": list])
        XCTAssertEqual(out["one"], .text("/tmp/merged.csv"))
        XCTAssertEqual(out["two"], .list(["/tmp/a", "/tmp/b"]))
    }

    /// No result schema is invented for tools that do not have one: an object payload is refused, not
    /// rummaged through for a plausible-looking key.
    func test_stepReference_toAnUnusablePayload_throws() throws {
        let object = try JSONSerialization.data(withJSONObject: ["destination": "/tmp/x"])
        XCTAssertThrowsError(try resolve(["p": .text("%{1}")], results: ["1": object])) {
            XCTAssertEqual($0 as? MacroPlaceholderError, .unknownStepReference("1"))
        }
        XCTAssertThrowsError(try resolve(["p": .text("%{9}")], results: [:])) {
            XCTAssertEqual($0 as? MacroPlaceholderError, .unknownStepReference("9"))
        }
    }

    func test_explicitList_flattensABareListTokenAmongItsElements() throws {
        let out = try resolve(["sources": .list(["%S", "%T/keep.txt"])])
        XCTAssertEqual(out["sources"], .list(context.selection + ["/Users/me/Documents/keep.txt"]))
    }

    func test_numbersAndFlags_passThroughAndEncodeAsJSON() throws {
        let out = try resolve(["n": .number(4096), "f": .flag(true)])
        XCTAssertEqual(out["n"], .number(4096))
        let data = try XCTUnwrap(MacroPlaceholders.json(out))
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        // An integral number must not serialise as 4096.0 — a tool taking max_bytes gets an Int.
        XCTAssertEqual(dict["n"] as? Int, 4096)
        XCTAssertEqual(dict["f"] as? Bool, true)
    }

    func test_noArguments_isNoJSONAtAll() throws {
        XCTAssertNil(try MacroPlaceholders.json([:]))
    }

    /// A selection whose file name contains a `%` must not be able to change how the template is read.
    func test_aPercentInTheDataCannotTurnAStringIntoAList() throws {
        var odd = context
        odd.selection = ["/tmp/100%S.pdf"]
        let out = try MacroPlaceholders.resolve(["p": .text("in %S")], context: odd, results: [:])
        XCTAssertEqual(out["p"], .text("in 100%S.pdf"))
    }
}

final class MacroStoreTests: XCTestCase {

    private func store() throws -> MacroStore {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-macros-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return MacroStore(url: dir.appendingPathComponent("macros.json"))
    }

    func test_roundTrip() throws {
        let s = try store()
        let m = Macro(id: "file-by-date", title: "File by date", icon: "calendar", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/%{date:yyyy-MM}")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%S"),
                                                "destination": .text("%T/%{date:yyyy-MM}")]),
        ])
        try s.save([m])
        XCTAssertEqual(s.macros(), [m])
        XCTAssertEqual(s.macro(id: "file-by-date"), m)
        XCTAssertNil(s.macro(id: "nope"))
    }

    /// The file reads like the tool calls it becomes — that is the point of the transparent encoding.
    func test_theFileOnDiskIsPlainJSON() throws {
        let s = try store()
        try s.save([Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "move", arguments: ["sources": .text("%S"), "max": .number(3)])])])
        let text = try String(contentsOf: s.url, encoding: .utf8)
        XCTAssertTrue(text.contains("\"sources\" : \"%S\""), text)
        XCTAssertTrue(text.contains("\"max\" : 3"), text)
    }

    /// The hard rule for a file a person edits: never trap, never throw, always say what was wrong.
    func test_malformedFile_yieldsNoMacrosAndAProblem() throws {
        let s = try store()
        try Data("{ this is not json".utf8).write(to: s.url)
        let (macros, problems) = s.load()
        XCTAssertTrue(macros.isEmpty)
        XCTAssertEqual(problems.count, 1)
        XCTAssertTrue(problems[0].contains("macros.json"))
    }

    func test_missingFile_isNotAProblem() throws {
        let (macros, problems) = try store().load()
        XCTAssertTrue(macros.isEmpty)
        XCTAssertTrue(problems.isEmpty)
    }

    /// Unlike SkillStore, the *first* entry wins: both are the user's, both would claim `mc_<id>`, and
    /// silently picking the later one means a button that runs the macro the user was not looking at.
    func test_duplicateIds_keepTheFirstAndReportTheSecond() throws {
        let s = try store()
        let step = #"{"tool":"list_directory","arguments":{"path":"/a"}}"#
        try Data("""
        [{"id":"m","title":"First","steps":[\(step)]},{"id":"m","title":"Second","steps":[\(step)]}]
        """.utf8).write(to: s.url)
        let (macros, problems) = s.load()
        XCTAssertEqual(macros.map(\.title), ["First"])
        XCTAssertEqual(problems.count, 1)
        XCTAssertTrue(problems[0].contains("share the id"))
    }

    func test_anIdIsReducedToWhatACommandNameMayHold() {
        XCTAssertEqual(MacroStore.sanitize("file by date"), "file-by-date")
        XCTAssertEqual(MacroStore.sanitize("a=b"), "a-b")
        XCTAssertEqual(MacroStore.sanitize("Ordner räumen"), "Ordner-r-umen")
        XCTAssertEqual(MacroStore.sanitize("--x--"), "x")
        XCTAssertEqual(MacroStore.sanitize("!!!"), "")
    }

    func test_anUnusableIdIsSkippedRatherThanTurnedIntoAnEmptyCommandName() throws {
        let s = try store()
        let step = #"{"tool":"list_directory","arguments":{"path":"/a"}}"#
        try Data("""
        [{"id":"!!!","title":"Bad","steps":[\(step)]},{"id":"ok","title":"Good","steps":[\(step)]}]
        """.utf8).write(to: s.url)
        let (macros, problems) = s.load()
        XCTAssertEqual(macros.map(\.id), ["ok"])
        XCTAssertEqual(problems.count, 1)
    }

    /// A macro with no steps would register as a command that does nothing — visible in the Command
    /// Browser and bindable to a key. The seeded file's explanatory entry is one of these, which is what
    /// keeps it out of the command table without needing a special-cased id.
    func test_aMacroWithNoStepsIsNotLoaded() throws {
        let s = try store()
        try Data("""
        [{"id":"_readme","title":"How this works","steps":[]},
         {"id":"real","title":"Real","steps":[{"tool":"list_directory","arguments":{"path":"/a"}}]}]
        """.utf8).write(to: s.url)
        XCTAssertEqual(s.macros().map(\.id), ["real"])
    }

    func test_proposedID_isUniqueAgainstWhatExists() {
        XCTAssertEqual(MacroStore.proposedID(for: "Tidy Downloads", existing: []), "tidy-downloads")
        XCTAssertEqual(MacroStore.proposedID(for: "Tidy Downloads", existing: ["tidy-downloads"]),
                       "tidy-downloads-2")
        XCTAssertEqual(MacroStore.proposedID(for: "Tidy Downloads",
                                             existing: ["tidy-downloads", "tidy-downloads-2"]),
                       "tidy-downloads-3")
        XCTAssertEqual(MacroStore.proposedID(for: "!!!", existing: []), "macro")
    }

    func test_upsertAndRemove() throws {
        let s = try store()
        let steps = [MacroStep(tool: "list_directory", arguments: ["path": .text("%P")])]
        try s.upsert(Macro(id: "a", title: "A", steps: steps))
        try s.upsert(Macro(id: "b", title: "B", steps: steps))
        try s.upsert(Macro(id: "a", title: "A2", steps: steps))
        XCTAssertEqual(s.macros().map(\.title), ["A2", "B"], "order is kept, the entry is replaced")
        try s.remove(id: "a")
        XCTAssertEqual(s.macros().map(\.id), ["b"])
    }
}
