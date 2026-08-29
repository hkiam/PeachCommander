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

    /// A macro's rows are a sequence, and the dialog has to know which of them hold the others up.
    /// Striking out the folder-making step and running the move anyway is the half-run this prevents.
    func test_aStepThatTakesAValueFromAnotherDependsOnIt() {
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "set_selection", arguments: ["mask": .text("*.csv")]),
            MacroStep(tool: "merge_files", arguments: ["sources": .text("%S"),
                                                       "destination": .text("%P/all.csv")]),
            MacroStep(tool: "open_path", arguments: ["path": .text("%{2.destination}")]),
        ])
        let rows = MacroPlan.rows(of: m)
        XCTAssertEqual(rows[0].dependsOn, [])
        XCTAssertEqual(rows[1].dependsOn, ["1"], "%S after a set_selection depends on it")
        XCTAssertEqual(rows[2].dependsOn, ["2"], "%{2.destination} depends on step 2")
    }

    /// A macro written to work on the user's own selection has no such dependency, and reporting one
    /// would grey out a row for no reason.
    func test_aSelectionTokenWithNoSetSelectionBeforeItDependsOnNothing() {
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/out")]),
            MacroStep(tool: "copy", arguments: ["sources": .text("%S"),
                                                "destination": .text("%T/out")]),
        ])
        XCTAssertEqual(MacroPlan.rows(of: m).map(\.dependsOn), [[], []])
    }

    /// Forward and self references are not dependencies — they cannot be satisfied at all, and the
    /// runner reports them for what they are.
    func test_aForwardReferenceIsNotADependency() {
        let m = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "open_path", arguments: ["path": .text("%{2}")]),
            MacroStep(tool: "make_directory", arguments: ["path": .text("%P/x")]),
        ])
        XCTAssertEqual(MacroPlan.rows(of: m).map(\.dependsOn), [[], []])
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

    /// The other half of the same rule, and the one that was broken: a value substituted *into* the
    /// template must not then be read as a template.
    ///
    /// Braces used to be expanded first and the outcome handed to `ParamExpander`, so a step result
    /// containing a `%` was interpreted. Measured: step 1 producing `/tmp/50%Netto.pdf` and a template
    /// of `%{1}.bak` came out as `/tmp/50report final.pdfetto.pdf.bak` — with `%N` substituted out of
    /// the data. Both families now go through one pass of the one expander.
    func test_aPercentInAStepResultIsNotExpandedAgain() throws {
        let payload = Data(#""/tmp/50%Netto.pdf""#.utf8)
        let out = try resolve(["path": .text("%{1}.bak")], results: ["1": payload])
        XCTAssertEqual(out["path"], .text("/tmp/50%Netto.pdf.bak"))
    }

    /// The same for a date: a format that produced a `%` would otherwise be re-read too. `%%` is the
    /// expander's own escape, and it must survive as one character rather than become a token.
    func test_aLiteralPercentSurvivesAsOne() throws {
        XCTAssertEqual(try resolve(["p": .text("100%% done")])["p"], .text("100% done"))
    }

    /// `%{2}` was written for a tool returning a bare path, and no tool in the catalogue returns one:
    /// every payload that is not nil is an object. The field selector is what makes the documented
    /// chaining work at all.
    func test_aStepResultFieldCanBeNamed() throws {
        let payload = try JSONSerialization.data(
            withJSONObject: ["destination": "/a/merged.csv", "files_merged": 3])
        XCTAssertEqual(try resolve(["p": .text("%{1.destination}")], results: ["1": payload]),
                       ["p": .text("/a/merged.csv")])
        // In the middle of a longer template too.
        XCTAssertEqual(try resolve(["p": .text("open %{1.destination} now")], results: ["1": payload]),
                       ["p": .text("open /a/merged.csv now")])
    }

    /// A list-valued field becomes a list, so `sources: "%{1.paths}"` is a usable step.
    func test_aListValuedStepResultFieldBecomesAList() throws {
        let payload = try JSONSerialization.data(withJSONObject: ["paths": ["/a/one", "/a/two"]])
        XCTAssertEqual(try resolve(["s": .text("%{1.paths}")], results: ["1": payload]),
                       ["s": .list(["/a/one", "/a/two"])])
    }

    /// A field that is not there, or is not a path, is refused rather than guessed at — passing the
    /// wrong path to a `move` is the failure this prevents.
    func test_aFieldThatIsNotAPathIsRefused() throws {
        let payload = try JSONSerialization.data(
            withJSONObject: ["destination": "/a/merged.csv", "files_merged": 3])
        XCTAssertThrowsError(try resolve(["p": .text("%{1.rows}")], results: ["1": payload])) {
            XCTAssertEqual($0 as? MacroPlaceholderError,
                           .unknownStepField(step: "1", field: "rows"))
        }
        XCTAssertThrowsError(try resolve(["p": .text("%{1.files_merged}")], results: ["1": payload])) {
            XCTAssertEqual($0 as? MacroPlaceholderError,
                           .unknownStepField(step: "1", field: "files_merged"))
        }
    }

    /// A trailing dot names no field, and answering with the whole payload would be a silent guess.
    func test_aTokenThatIsNotAStepReferenceIsLeftVerbatim() throws {
        XCTAssertEqual(try resolve(["p": .text("%{1.}")], results: [:])["p"], .text("%{1.}"))
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
        return MacroStore(directory: dir)
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
        let text = try String(contentsOf: s.file(for: "m"), encoding: .utf8)
        XCTAssertTrue(text.contains("\"sources\" : \"%S\""), text)
        XCTAssertTrue(text.contains("\"max\" : 3"), text)
    }

    /// The hard rule for a file a person edits: never trap, never throw, always say what was wrong.
    func test_malformedFile_yieldsNoMacrosAndAProblem() throws {
        let s = try store()
        try write("{ this is not json", named: "m.json", in: s)
        let (macros, problems) = s.load()
        XCTAssertTrue(macros.isEmpty)
        XCTAssertEqual(problems.count, 1)
        XCTAssertTrue(problems[0].contains("m.json"))
    }

    func test_missingFolder_isNotAProblem() throws {
        let (macros, problems) = try store().load()
        XCTAssertTrue(macros.isEmpty)
        XCTAssertTrue(problems.isEmpty)
    }

    /// Unlike SkillStore, the *first* entry wins: both are the user's, both would claim `mc_<id>`, and
    /// silently picking the later one means a button that runs the macro the user was not looking at.
    func test_duplicateIds_keepTheFirstAndReportTheSecond() throws {
        let s = try store()
        // Two files claiming one id: only reachable by hand, and the one place `save` cannot prevent it.
        let step = #"{"tool":"list_directory","arguments":{"path":"/a"}}"#
        try write("{\"id\":\"m\",\"order\":0,\"title\":\"First\",\"steps\":[\(step)]}",
                  named: "m.json", in: s)
        try write("{\"id\":\"m\",\"order\":1,\"title\":\"Second\",\"steps\":[\(step)]}",
                  named: "copy-of-m.json", in: s)
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
        try write("{\"id\":\"!!!\",\"title\":\"Bad\",\"steps\":[\(step)]}", named: "bad.json", in: s)
        try write("{\"id\":\"ok\",\"title\":\"Good\",\"steps\":[\(step)]}", named: "ok.json", in: s)
        let (macros, problems) = s.load()
        XCTAssertEqual(macros.map(\.id), ["ok"])
        XCTAssertEqual(problems.count, 1)
    }

    /// A macro with no steps would register as a command that does nothing — visible in the Command
    /// Browser and bindable to a key. The seeded file's explanatory entry is one of these, which is what
    /// keeps it out of the command table without needing a special-cased id.
    func test_aMacroWithNoStepsIsNotLoaded() throws {
        let s = try store()
        try write(#"{"id":"_readme","title":"How this works","steps":[]}"#,
                  named: "_readme.json", in: s)
        try write(#"{"id":"real","title":"Real","steps":[{"tool":"list_directory","arguments":{"path":"/a"}}]}"#,
                  named: "real.json", in: s)
        XCTAssertEqual(s.macros().map(\.id), ["real"])
    }

    /// Writing a file into the store's folder, for the cases only a hand-edited folder can produce.
    private func write(_ text: String, named name: String, in store: MacroStore) throws {
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try text.write(to: store.directory.appendingPathComponent(name),
                       atomically: true, encoding: .utf8)
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


/// The one value a macro does not know until it runs (F-478).
final class MacroQuestionTests: XCTestCase {

    func test_aBareQuestionHasNoDefault() throws {
        let q = try XCTUnwrap(MacroQuestion("ask:Folder name"))
        XCTAssertEqual(q.prompt, "Folder name")
        XCTAssertEqual(q.defaultValue, "")
        XCTAssertFalse(q.hasDefault)
    }

    func test_aDefaultFollowsTheFirstEquals() throws {
        let q = try XCTUnwrap(MacroQuestion("ask:Rename to=a=b"))
        XCTAssertEqual(q.prompt, "Rename to")
        XCTAssertEqual(q.defaultValue, "a=b", "only the first = splits; the rest is the value")
        XCTAssertTrue(q.hasDefault)
    }

    func test_anEmptyDefaultIsStillADefault() throws {
        let q = try XCTUnwrap(MacroQuestion("ask:Comment="))
        XCTAssertEqual(q.defaultValue, "")
        XCTAssertTrue(q.hasDefault, "the difference decides what happens with nobody to ask")
    }

    func test_whatIsNotAQuestion() {
        XCTAssertNil(MacroQuestion("date:yyyy-MM"))
        XCTAssertNil(MacroQuestion("1.destination"))
        XCTAssertNil(MacroQuestion("ask:"), "a question with no words is not one")
        XCTAssertNil(MacroQuestion("ask:   =x"), "nor is one that is only whitespace")
    }

    /// Once per question, not once per occurrence: a macro naming the same folder twice is asking one
    /// thing, and two fields would ask the user to keep two answers in agreement by hand.
    func test_theSameQuestionIsAskedOnce() {
        let macro = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/%{ask:Folder=Archive}")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%S"),
                                                "destination": .text("%T/%{ask:Folder=Other}")]),
        ])
        let questions = MacroPlaceholders.questions(in: macro)
        XCTAssertEqual(questions.map(\.prompt), ["Folder"])
        XCTAssertEqual(questions.first?.defaultValue, "Archive", "the first one met wins")
    }

    /// A dictionary's iteration order is not stable across runs, and a dialog whose fields move between
    /// two openings of the same macro is one nobody can fill in from memory.
    func test_theOrderIsStable() {
        let macro = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "rename", arguments: ["path": .text("%P/%{ask:Which file}"),
                                                  "new_name": .text("%{ask:New name}")]),
        ])
        let once = MacroPlaceholders.questions(in: macro).map(\.prompt)
        for _ in 0..<20 {
            XCTAssertEqual(MacroPlaceholders.questions(in: macro).map(\.prompt), once)
        }
        // Sorted by argument name: new_name before path.
        XCTAssertEqual(once, ["New name", "Which file"])
    }

    func test_anAnswerIsSubstitutedAndADefaultStandsInForOne() throws {
        let template: [String: MacroArgument] = ["path": .text("%T/%{ask:Folder=Archive}")]
        let answered = MacroContext(activeDirectory: "/a", inactiveDirectory: "/b",
                                    startedAt: Date(), answers: ["Folder": "Rechnungen"])
        XCTAssertEqual(try MacroPlaceholders.resolve(template, context: answered, results: [:])["path"],
                       .text("/b/Rechnungen"))
        let unanswered = MacroContext(activeDirectory: "/a", inactiveDirectory: "/b", startedAt: Date())
        XCTAssertEqual(try MacroPlaceholders.resolve(template, context: unanswered, results: [:])["path"],
                       .text("/b/Archive"))
    }

    /// An answer that is present and empty is an answer. Clearing a field is how `set_comment` removes
    /// a comment, and second-guessing it would take the choice away.
    func test_anEmptyAnswerBeatsTheDefault() throws {
        let out = try MacroPlaceholders.resolve(["comment": .text("%{ask:Comment=old}")],
                                                context: MacroContext(activeDirectory: "/a",
                                                                      startedAt: Date(),
                                                                      answers: ["Comment": ""]),
                                                results: [:])
        XCTAssertEqual(out["comment"], .text(""))
    }

    /// A question with no default and no answer is a wiring mistake, not a value to guess at.
    func test_anUnansweredQuestionWithoutADefaultThrows() {
        XCTAssertThrowsError(try MacroPlaceholders.resolve(["p": .text("%{ask:Folder}")],
                                                           context: MacroContext(activeDirectory: "/a",
                                                                                 startedAt: Date()),
                                                           results: [:])) {
            XCTAssertEqual($0 as? MacroPlaceholderError, .unanswered("Folder"))
        }
    }

    /// An answer is data, and data is never read as a template — the same rule that keeps a `%` in a
    /// file name from becoming a token.
    func test_aPercentInAnAnswerIsNotExpanded() throws {
        let out = try MacroPlaceholders.resolve(["p": .text("%T/%{ask:Folder}")],
                                                context: MacroContext(activeDirectory: "/a",
                                                                      inactiveDirectory: "/b",
                                                                      cursorPath: "/a/cursor.txt",
                                                                      startedAt: Date(),
                                                                      answers: ["Folder": "50%Netto"]),
                                                results: [:])
        XCTAssertEqual(out["p"], .text("/b/50%Netto"))
    }
}


/// A plan row as a *shape* rather than as a sentence (F-478), so the host can say it in the user's
/// language while the model, the MCP client and the audit log keep the English one.
final class PlanPhraseTests: XCTestCase {

    private func phrase(_ tool: String, _ json: String) -> PlanPhrase? {
        MacroPlan.phrase(tool: tool, argumentsJSON: json)
    }

    /// The English side must still read exactly as it did — it is what `PlanItem.text` carries, and
    /// two other readers depend on that text not changing under them.
    func test_theEnglishRenderingIsUnchanged() {
        XCTAssertEqual(phrase("make_directory", #"{"path":"/a/2026-08"}"#)?.english,
                       "Create the folder “2026-08”")
        XCTAssertEqual(phrase("move", #"{"destination":"/b/out","sources":["/a/one.pdf","/a/two.pdf"]}"#)?.english,
                       "Move one.pdf, two.pdf into “out”")
        XCTAssertEqual(phrase("move_to_trash", #"{"paths":["/a/w","/a/x","/a/y","/a/z"]}"#)?.english,
                       "Move w, x, y +1 more to the Trash")
        XCTAssertEqual(phrase("rename", #"{"path":"/a/old.txt","new_name":"new.txt"}"#)?.english,
                       "Rename “old.txt” to “new.txt”")
        XCTAssertEqual(phrase("set_comment", #"{"path":"/a/f.txt","comment":"kept"}"#)?.english,
                       "Comment “f.txt”: kept")
        XCTAssertEqual(phrase("run_shell", #"{"command":"ls -l"}"#)?.english,
                       "Run “ls -l” in a terminal")
    }

    /// The values a translator has to place are separated out, not baked into a sentence. This is the
    /// property that makes the host's renderer possible at all.
    func test_aPhraseCarriesItsValuesApartFromItsWords() throws {
        let p = try XCTUnwrap(phrase("move", #"{"destination":"/b/out","sources":["/a/one.pdf"]}"#))
        XCTAssertEqual(p.key, .moveInto)
        XCTAssertEqual(p.values, [.literal("one.pdf"), .literal("out")])
        XCTAssertNil(p.count)
    }

    /// A count is a number, not a rendered word, so a language that inflects can.
    func test_aCountedPhraseCarriesTheNumber() throws {
        let p = try XCTUnwrap(phrase("rename_batch", #"{"old_names":["a","b","c"],"new_names":["d","e","f"]}"#))
        XCTAssertEqual(p.key, .renameBatch)
        XCTAssertEqual(p.count, 3)
    }

    /// "+2 more" is words too, so the overflow is a phrase inside the phrase rather than text.
    func test_theOverflowIsItsOwnPhrase() throws {
        let p = try XCTUnwrap(phrase("move_to_trash", #"{"paths":["/a/w","/a/x","/a/y","/a/z"]}"#))
        guard case .phrase(let more)? = p.values.first else {
            return XCTFail("the item list should nest a phrase")
        }
        XCTAssertEqual(more.key, .andMore)
        XCTAssertEqual(more.count, 1)
    }

    /// A stand-in is a phrase too, nested where the value would be, so the whole sentence can be
    /// translated as one — "Move *the result of step 2* into “out”" is not two strings.
    func test_aStandInIsANestedPhrase() throws {
        let macro = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "merge_files", arguments: ["sources": .text("%S"),
                                                       "destination": .text("%P/all.csv")]),
            MacroStep(tool: "move", arguments: ["sources": .text("%{1.destination}"),
                                                "destination": .text("%P/done")]),
        ])
        let context = MacroContext(activeDirectory: "/a", selection: ["/a/x.csv"], startedAt: Date())
        let rows = MacroPlan.rows(of: macro, resolvedWith: context)
        let second = try XCTUnwrap(rows.last?.phrase)
        XCTAssertEqual(second.key, .moveInto)
        guard case .phrase(let standIn)? = second.values.first else {
            return XCTFail("the unresolved source should nest a phrase, got \(second.values)")
        }
        XCTAssertEqual(standIn.key, .resultOfStep)
        XCTAssertEqual(rows.last?.text, "Move the result of step 1 into “done”")
    }

    /// The marker a stand-in travels in is an implementation detail and must never be seen. If one
    /// reaches a row, the dialog shows a control character.
    func test_noRenderedRowEverContainsTheMarker() {
        let macro = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "move", arguments: ["sources": .text("%S"), "destination": .text("%T/x")]),
            MacroStep(tool: "open_path", arguments: ["path": .text("%{9}")]),
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/%{ask:Where}")]),
        ])
        // Nothing selected, no step 9, nobody asked: every stand-in at once.
        let context = MacroContext(activeDirectory: "/a", inactiveDirectory: "/b", startedAt: Date())
        for row in MacroPlan.rows(of: macro, resolvedWith: context) {
            XCTAssertFalse(row.text.contains("\u{1}"), row.text)
            XCTAssertFalse(row.text.contains("\u{1F}"), row.text)
            XCTAssertFalse(row.text.isEmpty)
        }
    }

    /// A step's own `note` is the user's wording and carries no phrase — nothing may translate it.
    func test_aNoteCarriesNoPhrase() {
        let macro = Macro(id: "m", title: "M", steps: [
            MacroStep(tool: "move", arguments: ["sources": .text("%S")], note: "Meine eigene Zeile"),
        ])
        let rows = MacroPlan.rows(of: macro, resolvedWith: MacroContext(activeDirectory: "/a",
                                                                        selection: ["/a/x"],
                                                                        startedAt: Date()))
        XCTAssertNil(rows[0].phrase)
        XCTAssertEqual(rows[0].text, "Meine eigene Zeile")
    }

    /// Every key must render to something. The host's switch is kept exhaustive by the compiler; this
    /// is the same guarantee for the English side, which has no such check.
    func test_everyKeyRendersToSomething() {
        for key in PlanPhrase.Key.allCases {
            let rendered = PlanPhrase(key, literals: ["one", "two"], count: 2).english
            XCTAssertFalse(rendered.isEmpty, "\(key) renders to nothing")
            XCTAssertFalse(rendered.contains("\u{1}"), "\(key)")
        }
    }
}

/// One unreadable file costs that macro, not the collection.
///
/// It used to cost everything: the macros lived in one `macros.json` decoded in one go, so a single
/// typo left the user with no macros at all — and with every button, key and menu entry that ran one
/// silently doing nothing. One file per macro makes that structural: a file that will not parse cannot
/// take its neighbours with it.
final class MacroStoreDirectoryTests: XCTestCase {

    private func emptyStore(legacy: String? = nil) throws -> MacroStore {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-macros-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let legacyFile = root.appendingPathComponent("macros.json")
        if let legacy { try legacy.write(to: legacyFile, atomically: true, encoding: .utf8) }
        return MacroStore(directory: root.appendingPathComponent("macros", isDirectory: true),
                          legacyFile: legacyFile)
    }

    private func macro(_ id: String, _ path: String = "%P/A") -> Macro {
        Macro(id: id, title: id.capitalized,
              steps: [MacroStep(tool: "make_directory", arguments: ["path": .text(path)])])
    }

    private func write(_ text: String, named name: String, in store: MacroStore) throws {
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try text.write(to: store.directory.appendingPathComponent(name),
                       atomically: true, encoding: .utf8)
    }

    func test_oneUnreadableFileDoesNotCostTheOthers() throws {
        let store = try emptyStore()
        try store.save([macro("first"), macro("second")])
        try write("{ this is not json at all", named: "broken.json", in: store)
        let loaded = store.load()
        XCTAssertEqual(loaded.macros.map(\.id), ["first", "second"])
        XCTAssertEqual(loaded.problems.count, 1)
        XCTAssertTrue(loaded.problems[0].contains("broken.json"),
                      "the report has to name the file, or there is nothing to go and fix")
    }

    /// A directory has no order of its own, and the order is not decoration — it is what the Command
    /// Browser and the button-bar picker list them in.
    func test_theSavedOrderIsTheOrderThatComesBack() throws {
        let store = try emptyStore()
        try store.save([macro("zulu"), macro("alpha"), macro("mike")])
        XCTAssertEqual(store.macros().map(\.id), ["zulu", "alpha", "mike"],
                       "alphabetical by file name would be “alpha, mike, zulu”")
    }

    /// A file dropped in by hand has no order, and a new thing belongs at the end.
    func test_aFileWithNoOrderLandsAtTheEnd() throws {
        let store = try emptyStore()
        try store.save([macro("zulu"), macro("alpha")])
        try write(#"""
            { "id": "handmade", "title": "By hand",
              "steps": [ { "tool": "make_directory", "arguments": { "path": "%P/H" } } ] }
            """#, named: "handmade.json", in: store)
        XCTAssertEqual(store.macros().map(\.id), ["zulu", "alpha", "handmade"])
    }

    /// Saving is the whole collection, so a delete has to actually delete.
    func test_savingRemovesTheFilesOfMacrosThatAreGone() throws {
        let store = try emptyStore()
        try store.save([macro("keep"), macro("drop")])
        try store.save([macro("keep")])
        XCTAssertEqual(store.macros().map(\.id), ["keep"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.file(for: "drop").path))
    }

    /// …but only files that are macros. `_readme.json` has no steps and is there to be read; so is any
    /// note a user keeps beside their macros. A reorder must not take those away.
    func test_savingLeavesFilesThatAreNotMacrosAlone() throws {
        let store = try emptyStore()
        try store.save([macro("keep")])
        try write(#"{ "id": "_readme", "title": "How this works", "steps": [] }"#,
                  named: "_readme.json", in: store)
        try store.save([macro("keep")])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: store.directory.appendingPathComponent("_readme.json").path))
    }

    /// JSON has no comments, so the examples — and a user's own notes — live in a key the decoder
    /// ignores. Encoding straight from `Macro` would drop them on the first reorder.
    func test_aCommentInAMacroFileSurvivesBeingSavedAgain() throws {
        let store = try emptyStore()
        try write(#"""
            { "id": "noted", "title": "Noted", "_comment": "why this exists",
              "steps": [ { "tool": "make_directory", "arguments": { "path": "%P/N" } } ] }
            """#, named: "noted.json", in: store)
        try store.save(store.macros())
        let text = try String(contentsOf: store.file(for: "noted"), encoding: .utf8)
        XCTAssertTrue(text.contains("why this exists"), text)
    }

    // MARK: - Exchange

    /// What Export writes is one macro on its own, with no position in anybody's list.
    func test_anExportedMacroIsOneObjectAndCarriesNoOrder() throws {
        let data = try MacroStore.encoded(macro("solo"))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["id"] as? String, "solo")
        XCTAssertNil(object["order"])
    }

    func test_importReadsBothASingleMacroAndAWholeOldFile() throws {
        let one = try MacroStore.encoded(macro("solo"))
        XCTAssertEqual(MacroStore.decodeForImport(one).map(\.id), ["solo"])
        let many = Data(#"""
            [ { "id": "a", "title": "A",
                "steps": [ { "tool": "make_directory", "arguments": { "path": "%P/A" } } ] },
              { "id": "b", "title": "B",
                "steps": [ { "tool": "make_directory", "arguments": { "path": "%P/B" } } ] } ]
            """#.utf8)
        XCTAssertEqual(MacroStore.decodeForImport(many).map(\.id), ["a", "b"])
    }

    /// An import is somebody else's macro arriving. Silently replacing the one you wrote under the
    /// same obvious name is the one outcome that cannot be undone from here.
    func test_importNeverReplacesAMacroYouAlreadyHave() throws {
        let store = try emptyStore()
        try store.save([macro("backup", "%P/MINE")])
        let added = try store.importing([macro("backup", "%P/THEIRS")])
        XCTAssertEqual(added.map(\.id), ["backup-2"])
        XCTAssertEqual(store.macro(id: "backup")?.steps.first?.arguments["path"], .text("%P/MINE"))
        XCTAssertEqual(store.macro(id: "backup-2")?.steps.first?.arguments["path"], .text("%P/THEIRS"))
    }

    // MARK: - The move from one file to a directory

    func test_anOldMacrosFileIsMovedAcrossOnceAndPutOutOfTheWay() throws {
        let store = try emptyStore(legacy: #"""
            [ { "id": "first",  "title": "First",
                "steps": [ { "tool": "make_directory", "arguments": { "path": "%P/A" } } ] },
              { "id": "second", "title": "Second",
                "steps": [ { "tool": "make_directory", "arguments": { "path": "%P/B" } } ] } ]
            """#)
        XCTAssertTrue(store.migrateIfNeeded())
        XCTAssertEqual(store.macros().map(\.id), ["first", "second"], "order is kept")
        let root = store.directory.deletingLastPathComponent()
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("macros.json").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("macros.json.migrated").path),
            "the old file is renamed, not deleted — it is the user's data")
    }

    /// Once. A user who already has a directory has answered this question, and a `macros.json` beside
    /// it is theirs to do with as they like.
    func test_nothingIsMovedWhenThereIsAlreadyADirectory() throws {
        let store = try emptyStore(legacy: #"""
            [ { "id": "old", "title": "Old",
                "steps": [ { "tool": "make_directory", "arguments": { "path": "%P/O" } } ] } ]
            """#)
        try store.save([macro("mine")])
        XCTAssertFalse(store.migrateIfNeeded())
        XCTAssertEqual(store.macros().map(\.id), ["mine"])
    }

    func test_nothingIsMovedWhenThereIsNoOldFile() throws {
        XCTAssertFalse(try emptyStore().migrateIfNeeded())
    }

    /// A note somebody wrote next to their own macro comes across with it. JSON has no comments, so it
    /// lives in a key the decoder ignores — and a tidier layout is a poor trade for deleting it.
    func test_aCommentInTheOldFileSurvivesTheMove() throws {
        let store = try emptyStore(legacy: #"""
            [ { "id": "kept", "title": "Kept", "_comment": "this is why I wrote it",
                "steps": [ { "tool": "make_directory", "arguments": { "path": "%P/K" } } ] } ]
            """#)
        XCTAssertTrue(store.migrateIfNeeded())
        let text = try String(contentsOf: store.file(for: "kept"), encoding: .utf8)
        XCTAssertTrue(text.contains("this is why I wrote it"), text)
    }
}
