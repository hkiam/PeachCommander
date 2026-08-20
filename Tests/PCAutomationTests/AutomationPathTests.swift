// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

// Where a path a tool was handed actually points. These rules decide where a write lands, so the
// cases below are the ones the on-device model was measured producing — and one it did not, which
// would have written to the root of the disk.
final class AutomationPathTests: XCTestCase {

    private let active = "/Users/maik1/Berichte"

    /// A world where only these paths exist.
    private func world(_ paths: String...) -> (String) -> Bool {
        let set = Set(paths)
        return { set.contains($0) }
    }

    // MARK: Reading

    func test_pathThatExists_isUsedAsGiven() {
        let exists = world("/tmp/a.txt")
        XCTAssertEqual(AutomationPath.resolveExisting("/tmp/a.txt", activeFolder: active, exists: exists),
                       "/tmp/a.txt")
    }

    // The measured case: a search hands the model an absolute path and it drops the slash.
    func test_droppedLeadingSlash_isRecovered() {
        let exists = world("/var/folders/x/januar.txt")
        XCTAssertEqual(AutomationPath.resolveExisting("var/folders/x/januar.txt",
                                                      activeFolder: active, exists: exists),
                       "/var/folders/x/januar.txt")
    }

    func test_bareName_isTakenFromTheActiveFolder() {
        let exists = world("/Users/maik1/Berichte/q3.txt")
        XCTAssertEqual(AutomationPath.resolveExisting("q3.txt", activeFolder: active, exists: exists),
                       "/Users/maik1/Berichte/q3.txt")
    }

    // Nothing is invented: an unresolvable path fails as the path that was asked for.
    func test_unresolvablePath_comesBackUnchanged() {
        XCTAssertEqual(AutomationPath.resolveExisting("nope.txt", activeFolder: active, exists: world()),
                       "nope.txt")
    }

    func test_whatWasAskedFor_winsOverTheActiveFolder() {
        let exists = world("q3.txt", "/Users/maik1/Berichte/q3.txt")
        XCTAssertEqual(AutomationPath.resolveExisting("q3.txt", activeFolder: active, exists: exists),
                       "q3.txt", "an existing relative path is not second-guessed")
    }

    func test_emptyPath_staysEmpty() {
        // "/" exists in every world; an empty path must not resolve to it.
        XCTAssertEqual(AutomationPath.resolveExisting("", activeFolder: active, exists: world("/")), "")
    }

    // MARK: Writing

    // The bug this file exists for: the parent of "notiz.txt" is "", and "/" + "" is "/", so a new
    // file would have been written to the root of the disk instead of the folder in front of the user.
    func test_bareName_isCreatedInTheActiveFolder_notAtTheRoot() {
        let resolved = AutomationPath.resolveForWriting("notiz.txt", activeFolder: active,
                                                        exists: world("/", active))
        XCTAssertEqual(resolved, "/Users/maik1/Berichte/notiz.txt")
        XCTAssertNotEqual(resolved, "/notiz.txt")
    }

    func test_newFileInAnExistingFolder_isLeftAlone() {
        XCTAssertEqual(AutomationPath.resolveForWriting("/tmp/neu.txt", activeFolder: active,
                                                        exists: world("/tmp")),
                       "/tmp/neu.txt")
    }

    func test_newFile_underAParentWithADroppedSlash() {
        XCTAssertEqual(AutomationPath.resolveForWriting("var/folders/x/neu.txt", activeFolder: active,
                                                        exists: world("/var/folders/x")),
                       "/var/folders/x/neu.txt")
    }

    func test_newFile_whoseParentDoesNotExist_isLeftAlone() {
        XCTAssertEqual(AutomationPath.resolveForWriting("/tmp/kein/ordner/neu.txt",
                                                        activeFolder: active, exists: world()),
                       "/tmp/kein/ordner/neu.txt", "the failure must stay honest")
    }

    func test_bareName_withoutAnActiveFolder_isLeftAlone() {
        XCTAssertEqual(AutomationPath.resolveForWriting("notiz.txt", activeFolder: "", exists: world("/")),
                       "notiz.txt")
    }

    func test_emptyPath_isNotTurnedIntoTheActiveFolder() {
        XCTAssertEqual(AutomationPath.resolveForWriting("", activeFolder: active, exists: world("/")), "")
    }
}

#if canImport(FoundationModels)
// Naming the language beats describing the rule: the on-device model answered in English about a
// German file 4 times out of 4 when the fold prompts said "the same language as the text", and 4
// out of 4 in German once they said "Write in German."
@available(macOS 26, *)
final class SummaryLanguageTests: XCTestCase {

    func test_germanText_isRecognisedAsGerman() {
        let name = NativeToolContext.languageName(
            of: "Die Region Nord meldet gleichbleibende Umsätze und leicht steigende Kosten im September.")
        XCTAssertEqual(name, "German")
    }

    func test_englishText_isRecognisedAsEnglish() {
        XCTAssertEqual(NativeToolContext.languageName(
            of: "The northern region reports steady sales and slightly rising costs in September."),
                       "English")
    }

    func test_theClauseNamesTheLanguage() {
        XCTAssertEqual(NativeToolContext.languageClause("German"), " Write in German.")
    }

    // Unknown language: no clause at all rather than an instruction naming nothing.
    func test_noLanguage_addsNoInstruction() {
        XCTAssertEqual(NativeToolContext.languageClause(String?.none), "")
    }

    func test_gibberish_doesNotProduceAConfidentClause() {
        let name = NativeToolContext.languageName(of: "zzz qqq xxx 123 ...")
        // Whatever it guesses, the clause must be a complete sentence or empty — never " Write in ."
        let clause = NativeToolContext.languageClause(name)
        XCTAssertTrue(clause.isEmpty || clause.hasSuffix("."), clause)
        XCTAssertFalse(clause.contains("in ."), clause)
    }
}
#endif
