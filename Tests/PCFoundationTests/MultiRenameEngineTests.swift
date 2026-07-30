// MultiRenameEngineTests - Unit tests for MultiRenameEngine

import XCTest
@testable import PCFoundation

final class MultiRenameEngineTests: XCTestCase {

    // MARK: - Test helpers

    /// A fixed Gregorian/UTC date so date-token assertions are deterministic
    /// regardless of the host machine's calendar/time zone: 2024-03-05
    /// 07:08:09 UTC.
    private func fixedDate(year: Int = 2024, month: Int = 3, day: Int = 5,
                            hour: Int = 7, minute: Int = 8, second: Int = 9) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return calendar.date(from: comps)!
    }

    /// Runs `compute` for a single input and returns its new name.
    private func rename(_ name: String, spec: RenameSpec, parent: String = "", grandparent: String = "") -> String {
        let input = RenameInput(name: name, modified: fixedDate(), parentName: parent, grandparentName: grandparent)
        return MultiRenameEngine.compute([input], spec: spec)[0].newName
    }

    // MARK: - Name / extension splitting

    func testSplit_basicNameAndExtension() {
        let spec = RenameSpec()
        XCTAssertEqual(rename("Photo.JPG", spec: spec), "Photo.JPG")
    }

    func testSplit_noExtension() {
        let spec = RenameSpec()
        XCTAssertEqual(rename("README", spec: spec), "README")
    }

    func testSplit_leadingDotOnlyHasEmptyExtension() {
        let spec = RenameSpec()
        XCTAssertEqual(rename(".bashrc", spec: spec), ".bashrc")
    }

    func testSplit_leadingDotSingleWordHasEmptyExtension() {
        let spec = RenameSpec()
        XCTAssertEqual(rename(".txt", spec: spec), ".txt")
    }

    func testSplit_multipleDotsUsesLastDot() {
        let spec = RenameSpec()
        XCTAssertEqual(rename(".tar.gz", spec: spec), ".tar.gz")
    }

    func testSplit_trailingDotExtensionIsEmptyAndDropped() {
        // "photo." has an empty extension after the final dot; since the
        // default extMask "[E]" then expands to "", the combined name drops
        // the separator dot entirely.
        let spec = RenameSpec()
        XCTAssertEqual(rename("photo.", spec: spec), "photo")
    }

    func testLiteralExtMaskAddsExtensionEvenWithoutOne() {
        // extMask is literal text (no [E] token), so it still contributes a
        // non-empty extension even though "README" itself has none.
        let spec = RenameSpec(nameMask: "[N]", extMask: "bak")
        XCTAssertEqual(rename("README", spec: spec), "README.bak")
    }

    // MARK: - [N...] ranges

    func testRangeN_whole() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "")
        XCTAssertEqual(rename("abcdefgh.txt", spec: spec), "abcdefgh")
    }

    func testRangeN_dashInclusive() {
        let spec = RenameSpec(nameMask: "[N2-5]", extMask: "")
        XCTAssertEqual(rename("abcdefgh.txt", spec: spec), "bcde")
    }

    func testRangeN_dashOpenEnded() {
        let spec = RenameSpec(nameMask: "[N2-]", extMask: "")
        XCTAssertEqual(rename("abcdefgh.txt", spec: spec), "bcdefgh")
    }

    func testRangeN_countForm() {
        let spec = RenameSpec(nameMask: "[N2,3]", extMask: "")
        XCTAssertEqual(rename("abcdefgh.txt", spec: spec), "bcd")
    }

    func testRangeN_negativeStartCountForm() {
        // 5 chars starting from the 8th-from-last of an 8-char name is the
        // whole string.
        let spec = RenameSpec(nameMask: "[N-8,5]", extMask: "")
        XCTAssertEqual(rename("abcdefgh.txt", spec: spec), "abcde")
    }

    func testRangeN_dashEndClampsToLength() {
        let spec = RenameSpec(nameMask: "[N2-100]", extMask: "")
        XCTAssertEqual(rename("abcdefgh.txt", spec: spec), "bcdefgh")
    }

    func testRangeN_negativeStartClampsUpward() {
        // "9th-from-last" doesn't exist in an 8-char string, so the start
        // clamps up to position 1 while the end keeps its resolved value.
        let spec = RenameSpec(nameMask: "[N-9,5]", extMask: "")
        XCTAssertEqual(rename("abcdefgh.txt", spec: spec), "abcd")
    }

    func testRangeN_extremeNegativeStartCollapsesToFirstChar() {
        let spec = RenameSpec(nameMask: "[N-100,5]", extMask: "")
        XCTAssertEqual(rename("abcdefgh.txt", spec: spec), "a")
    }

    func testRangeN_bareSinglePosition() {
        let spec = RenameSpec(nameMask: "[N3]", extMask: "")
        XCTAssertEqual(rename("abcdefgh.txt", spec: spec), "c")
    }

    func testRangeN_bareSinglePositionClampsToLength() {
        let spec = RenameSpec(nameMask: "[N100]", extMask: "")
        XCTAssertEqual(rename("ab.txt", spec: spec), "b")
    }

    func testRangeN_unicodeGraphemeClusterSinglePosition() {
        // The flag emoji is two Unicode scalars but one grapheme cluster;
        // ranges must count it as a single "character".
        let name = "\u{1F1E9}\u{1F1EA}caf\u{00E9}.txt"
        let spec = RenameSpec(nameMask: "[N1]", extMask: "")
        XCTAssertEqual(rename(name, spec: spec), "\u{1F1E9}\u{1F1EA}")
    }

    func testRangeN_unicodeGraphemeClusterRange() {
        let name = "\u{1F1E9}\u{1F1EA}caf\u{00E9}.txt"
        let spec = RenameSpec(nameMask: "[N2-5]", extMask: "")
        XCTAssertEqual(rename(name, spec: spec), "caf\u{00E9}")
    }

    // MARK: - [E...] ranges

    func testRangeE_dashInclusive() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "[E2-4]")
        XCTAssertEqual(rename("document.report", spec: spec), "document.epo")
    }

    func testRangeE_negativeStartCountForm() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "[E-2,2]")
        XCTAssertEqual(rename("document.report", spec: spec), "document.rt")
    }

    // MARK: - [P] / [G]

    func testParentToken_whole() {
        let spec = RenameSpec(nameMask: "[P]_[N]", extMask: "[E]")
        XCTAssertEqual(rename("song.mp3", spec: spec, parent: "Music"), "Music_song.mp3")
    }

    func testGrandparentToken_ranged() {
        let spec = RenameSpec(nameMask: "[G1-3]_[N]", extMask: "[E]")
        XCTAssertEqual(rename("song.mp3", spec: spec, grandparent: "Users"), "Use_song.mp3")
    }

    // MARK: - [C] counter

    func testCounter_bareUsesBlockDefaults() {
        let spec = RenameSpec(nameMask: "[N]_[C]", extMask: "")
        let inputs = ["a.txt", "b.txt", "c.txt"].map { RenameInput(name: $0, modified: fixedDate()) }
        let results = MultiRenameEngine.compute(inputs, spec: spec)
        XCTAssertEqual(results.map(\.newName), ["a_1", "b_2", "c_3"])
    }

    func testCounter_stepAndDigitsFromBlock() {
        let spec = RenameSpec(nameMask: "[C]", extMask: "", counterStart: 10, counterStep: 5, counterDigits: 3)
        let inputs = ["a.txt", "b.txt", "c.txt"].map { RenameInput(name: $0, modified: fixedDate()) }
        let results = MultiRenameEngine.compute(inputs, spec: spec)
        XCTAssertEqual(results.map(\.newName), ["010", "015", "020"])
    }

    func testCounter_fullInlineOverride() {
        let spec = RenameSpec(nameMask: "[C10+5:3]", extMask: "")
        let inputs = ["a.txt", "b.txt", "c.txt"].map { RenameInput(name: $0, modified: fixedDate()) }
        let results = MultiRenameEngine.compute(inputs, spec: spec)
        XCTAssertEqual(results.map(\.newName), ["010", "015", "020"])
    }

    func testCounter_partialInlineStartOnly() {
        let spec = RenameSpec(nameMask: "[C10]", extMask: "", counterStep: 2, counterDigits: 2)
        let inputs = ["a.txt", "b.txt", "c.txt"].map { RenameInput(name: $0, modified: fixedDate()) }
        let results = MultiRenameEngine.compute(inputs, spec: spec)
        XCTAssertEqual(results.map(\.newName), ["10", "12", "14"])
    }

    func testCounter_partialInlineDigitsOnly() {
        let spec = RenameSpec(nameMask: "[C:3]", extMask: "", counterStart: 5)
        let inputs = ["a.txt", "b.txt", "c.txt"].map { RenameInput(name: $0, modified: fixedDate()) }
        let results = MultiRenameEngine.compute(inputs, spec: spec)
        XCTAssertEqual(results.map(\.newName), ["005", "006", "007"])
    }

    func testCounter_negativeValuePreservesSignInPadding() {
        let spec = RenameSpec(nameMask: "[C]", extMask: "", counterStart: -5, counterDigits: 3)
        XCTAssertEqual(rename("a.txt", spec: spec), "-005")
    }

    // MARK: - Date tokens (fixed date: 2024-03-05 07:08:09 UTC)

    func testDateToken_yearMonthDay() {
        let spec = RenameSpec(nameMask: "[Y]-[M]-[D]", extMask: "")
        XCTAssertEqual(rename("a.txt", spec: spec), "2024-03-05")
    }

    func testDateToken_hourMinuteSecond() {
        let spec = RenameSpec(nameMask: "[h]-[m]-[s]", extMask: "")
        XCTAssertEqual(rename("a.txt", spec: spec), "07-08-09")
    }

    func testDateToken_compactDate() {
        let spec = RenameSpec(nameMask: "[d]", extMask: "")
        XCTAssertEqual(rename("a.txt", spec: spec), "20240305")
    }

    // MARK: - Case-region modifiers ([U], [L], [F], [n])

    func testCaseRegion_upper() {
        let spec = RenameSpec(nameMask: "[U][N]", extMask: "")
        XCTAssertEqual(rename("photo.txt", spec: spec), "PHOTO")
    }

    func testCaseRegion_lower() {
        let spec = RenameSpec(nameMask: "[L][N]", extMask: "")
        XCTAssertEqual(rename("PHOTO.txt", spec: spec), "photo")
    }

    func testCaseRegion_firstWordAcrossBoundaries() {
        let spec = RenameSpec(nameMask: "[F][N]", extMask: "")
        XCTAssertEqual(rename("hello world_test.txt", spec: spec), "Hello World_Test")
    }

    func testCaseRegion_resetToNormal() {
        let spec = RenameSpec(nameMask: "[U][N2-3][n][N4-5]", extMask: "")
        XCTAssertEqual(rename("abcdef.txt", spec: spec), "BCde")
    }

    // MARK: - Literal brackets

    func testLiteralBrackets_escapeWithoutTokenEvaluation() {
        let spec = RenameSpec(nameMask: "[[N]] literal", extMask: "")
        XCTAssertEqual(rename("abc.txt", spec: spec), "[N] literal")
    }

    func testLiteralBrackets_escapeThenRealToken() {
        let spec = RenameSpec(nameMask: "[[N]][N]", extMask: "")
        XCTAssertEqual(rename("abc.txt", spec: spec), "[N]abc")
    }

    // MARK: - Unknown / malformed tokens

    func testUnknownTokenExpandsToEmptyWithoutCrashing() {
        let spec = RenameSpec(nameMask: "[Q]abc", extMask: "")
        XCTAssertEqual(rename("photo.txt", spec: spec), "abc")
    }

    func testUnterminatedBracketIsTreatedAsLiteral() {
        let spec = RenameSpec(nameMask: "abc[", extMask: "")
        XCTAssertEqual(rename("photo.txt", spec: spec), "abc[")
    }

    func testEmptyTokenExpandsToEmpty() {
        let spec = RenameSpec(nameMask: "x[]y", extMask: "")
        XCTAssertEqual(rename("photo.txt", spec: spec), "xy")
    }

    // MARK: - Search / replace

    func testSearchReplace_literalAllOccurrences() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "", search: "cat", replace: "dog")
        XCTAssertEqual(rename("cat_cat.txt", spec: spec), "dog_dog")
    }

    func testSearchReplace_multiplePipeSeparatedPairs() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "", search: "a|b", replace: "1|2")
        XCTAssertEqual(rename("aabb.txt", spec: spec), "1122")
    }

    func testSearchReplace_caseInsensitiveByDefault() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "", search: "ABC", replace: "X")
        XCTAssertEqual(rename("abcABC.txt", spec: spec), "XX")
    }

    func testSearchReplace_caseSensitiveOnlyMatchesExactCase() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "", search: "ABC", replace: "X", caseSensitive: true)
        XCTAssertEqual(rename("abcABC.txt", spec: spec), "abcX")
    }

    func testSearchReplace_regexGroupSubstitution() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "", search: "(\\d+)", replace: "<$1>", useRegex: true)
        XCTAssertEqual(rename("a123b456c.txt", spec: spec), "a<123>b<456>c")
    }

    func testSearchReplace_repeatReplaceConvergesFully() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "", search: "aa", replace: "a", repeatReplace: true)
        XCTAssertEqual(rename("aaaaa.txt", spec: spec), "a")
    }

    func testSearchReplace_emptySearchIsNoOp() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "")
        XCTAssertEqual(rename("cat.txt", spec: spec), "cat")
    }

    func testSearchReplace_emptyIndividualTermIsSkipped() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "", search: "|x", replace: "Y|Z")
        XCTAssertEqual(rename("xxx.txt", spec: spec), "ZZZ")
    }

    func testSearchReplace_missingReplaceTermDefaultsToEmpty() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "", search: "a|b", replace: "1")
        XCTAssertEqual(rename("ab.txt", spec: spec), "1")
    }

    // MARK: - Case modes

    func testCaseMode_unchanged() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "[E]", caseMode: .unchanged)
        XCTAssertEqual(rename("PhoTO.TxT", spec: spec), "PhoTO.TxT")
    }

    func testCaseMode_lower() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "[E]", caseMode: .lower)
        XCTAssertEqual(rename("PhoTO.TXT", spec: spec), "photo.txt")
    }

    func testCaseMode_upper() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "[E]", caseMode: .upper)
        XCTAssertEqual(rename("photo.txt", spec: spec), "PHOTO.TXT")
    }

    func testCaseMode_firstUpper() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "[E]", caseMode: .firstUpper)
        XCTAssertEqual(rename("hELLO world.TXT", spec: spec), "Hello world.txt")
    }

    func testCaseMode_everyWord() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "[E]", caseMode: .everyWord)
        XCTAssertEqual(rename("my_photo file.TXT", spec: spec), "My_Photo File.Txt")
    }

    // MARK: - Pipeline ordering (mask -> search/replace -> case)

    func testPipelineOrder_maskThenSearchReplaceThenCase() {
        let spec = RenameSpec(nameMask: "[N]_[C]", extMask: "[E]", search: "_", replace: "-", caseMode: .upper)
        XCTAssertEqual(rename("photo.jpg", spec: spec), "PHOTO-1.JPG")
    }

    // MARK: - compute(): validity and collisions

    func testCompute_preservesInputOrder() {
        let spec = RenameSpec()
        let inputs = ["b.txt", "a.txt", "c.txt"].map { RenameInput(name: $0, modified: fixedDate()) }
        let results = MultiRenameEngine.compute(inputs, spec: spec)
        XCTAssertEqual(results.map(\.oldName), ["b.txt", "a.txt", "c.txt"])
    }

    func testCompute_twoWayCollisionCaseInsensitive() {
        let spec = RenameSpec()
        let inputs = ["a.txt", "A.TXT", "b.txt"].map { RenameInput(name: $0, modified: fixedDate()) }
        let results = MultiRenameEngine.compute(inputs, spec: spec)
        XCTAssertTrue(results[0].collides)
        XCTAssertTrue(results[1].collides)
        XCTAssertFalse(results[2].collides)
    }

    func testCompute_threeWayCollision() {
        let spec = RenameSpec()
        let inputs = ["x.txt", "X.txt", "X.TXT"].map { RenameInput(name: $0, modified: fixedDate()) }
        let results = MultiRenameEngine.compute(inputs, spec: spec)
        XCTAssertTrue(results.allSatisfy { $0.collides })
    }

    func testCompute_noCollisionWhenNamesDiffer() {
        let spec = RenameSpec()
        let inputs = ["a.txt", "b.txt", "c.txt"].map { RenameInput(name: $0, modified: fixedDate()) }
        let results = MultiRenameEngine.compute(inputs, spec: spec)
        XCTAssertTrue(results.allSatisfy { !$0.collides })
    }

    func testCompute_invalidWhenNewNameIsEmpty() {
        let spec = RenameSpec(nameMask: "", extMask: "")
        let result = MultiRenameEngine.compute([RenameInput(name: "photo.jpg", modified: fixedDate())], spec: spec)[0]
        XCTAssertEqual(result.newName, "")
        XCTAssertFalse(result.isValid)
    }

    func testCompute_invalidWhenNewNameContainsSlash() {
        let spec = RenameSpec(nameMask: "a/b", extMask: "")
        let result = MultiRenameEngine.compute([RenameInput(name: "photo.jpg", modified: fixedDate())], spec: spec)[0]
        XCTAssertEqual(result.newName, "a/b")
        XCTAssertFalse(result.isValid)
    }

    func testCompute_invalidWhenNewNameContainsNUL() {
        let spec = RenameSpec(nameMask: "[N]", extMask: "", search: "x", replace: "\0")
        let result = MultiRenameEngine.compute([RenameInput(name: "x.txt", modified: fixedDate())], spec: spec)[0]
        XCTAssertTrue(result.newName.contains("\0"))
        XCTAssertFalse(result.isValid)
    }

    func testCompute_validForOrdinaryName() {
        let spec = RenameSpec()
        let result = MultiRenameEngine.compute([RenameInput(name: "photo.jpg", modified: fixedDate())], spec: spec)[0]
        XCTAssertTrue(result.isValid)
        XCTAssertFalse(result.collides)
        XCTAssertEqual(result.newName, "photo.jpg")
    }
}
