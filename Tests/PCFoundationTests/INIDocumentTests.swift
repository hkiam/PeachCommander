// SPDX-License-Identifier: Apache-2.0
// INIDocumentTests.swift - Unit tests for INIDocument

import XCTest
@testable import PCFoundation

final class INIDocumentTests: XCTestCase {

    // MARK: - Round-trip

    func testRoundTripPreservesCommentsBlanksAndSections() {
        let text = """
        ; top-level comment
        [Configuration]
        ShowHiddenSystem=1
        ; a comment inside the section
        Layout=classic

        [Colors]
        InverseCursor=1
        """ + "\n"

        let doc = INIDocument(parsing: text)
        XCTAssertEqual(doc.serialized(), text)
    }

    func testTrailingNewlineIsNormalizedOnSerialization() {
        let textWithoutTrailingNewline = "[A]\nkey=value"
        let doc = INIDocument(parsing: textWithoutTrailingNewline)
        XCTAssertEqual(doc.serialized(), "[A]\nkey=value\n")
    }

    func testEmptyDocumentSerializesToEmptyString() {
        let doc = INIDocument()
        XCTAssertEqual(doc.serialized(), "")
    }

    // MARK: - set()

    func testSetExistingKeyPreservesCommentsAndOtherLines() {
        let text = """
        ; header comment
        [Layout]
        ButtonBar=1
        ; trailing comment

        [Colors]
        InverseCursor=0
        """ + "\n"

        var doc = INIDocument(parsing: text)
        doc.set("0", section: "Layout", key: "ButtonBar")

        let expected = """
        ; header comment
        [Layout]
        ButtonBar=0
        ; trailing comment

        [Colors]
        InverseCursor=0
        """ + "\n"

        XCTAssertEqual(doc.serialized(), expected)
    }

    func testSetNewKeyInExistingSectionInsertsAfterLastKeyOfSection() {
        let text = """
        [Layout]
        ButtonBar=1
        ShowToolbar=1

        [Colors]
        InverseCursor=0
        """ + "\n"

        var doc = INIDocument(parsing: text)
        doc.set("42", section: "Layout", key: "NewKey")

        let expected = """
        [Layout]
        ButtonBar=1
        ShowToolbar=1
        NewKey=42

        [Colors]
        InverseCursor=0
        """ + "\n"

        XCTAssertEqual(doc.serialized(), expected)
    }

    func testSetKeyInNewSectionAppendsAtEnd() {
        let text = "[Layout]\nButtonBar=1\n"
        var doc = INIDocument(parsing: text)
        doc.set("1", section: "Meta", key: "version")

        XCTAssertEqual(doc.serialized(), "[Layout]\nButtonBar=1\n\n[Meta]\nversion=1\n")
    }

    func testSetKeyInEmptySectionInsertsRightAfterHeader() {
        let text = "[Layout]\n\n[Colors]\nInverseCursor=0\n"
        var doc = INIDocument(parsing: text)
        doc.set("1", section: "Layout", key: "ButtonBar")

        XCTAssertEqual(doc.serialized(), "[Layout]\nButtonBar=1\n\n[Colors]\nInverseCursor=0\n")
    }

    // MARK: - remove()

    func testRemoveExistingKey() {
        let text = "[Layout]\nButtonBar=1\nShowToolbar=1\n"
        var doc = INIDocument(parsing: text)
        doc.remove(section: "Layout", key: "ButtonBar")

        XCTAssertEqual(doc.serialized(), "[Layout]\nShowToolbar=1\n")
    }

    func testRemoveNonexistentKeyIsNoOp() {
        let text = "[Layout]\nButtonBar=1\n"
        var doc = INIDocument(parsing: text)
        doc.remove(section: "Layout", key: "DoesNotExist")
        doc.remove(section: "NoSuchSection", key: "ButtonBar")

        XCTAssertEqual(doc.serialized(), text)
    }

    // MARK: - Lookup semantics

    func testCaseInsensitiveSectionAndKeyLookup() {
        let text = "[Layout]\nButtonBar=1\n"
        let doc = INIDocument(parsing: text)

        XCTAssertEqual(doc.value(section: "LAYOUT", key: "buttonbar"), "1")
        XCTAssertEqual(doc.value(section: "layout", key: "BUTTONBAR"), "1")
    }

    func testUnicodeValuesRoundTrip() {
        let text = "[Ansicht]\nÜberschrift=Größe\nEmoji=🍑📁\n"
        let doc = INIDocument(parsing: text)

        XCTAssertEqual(doc.value(section: "Ansicht", key: "Überschrift"), "Größe")
        XCTAssertEqual(doc.value(section: "Ansicht", key: "Emoji"), "🍑📁")
        XCTAssertEqual(doc.serialized(), text)
    }

    func testValueContainingEqualsSignsSplitsOnFirstOnly() {
        let text = "[A]\nkey=a=b=c\n"
        let doc = INIDocument(parsing: text)

        XCTAssertEqual(doc.value(section: "A", key: "key"), "a=b=c")
    }

    func testKeysAndValuesAreTrimmedOfSurroundingSpaces() {
        let text = "[A]\n  spacedKey   =   spaced value  \n"
        let doc = INIDocument(parsing: text)

        XCTAssertEqual(doc.value(section: "A", key: "spacedKey"), "spaced value")
    }

    func testValueForMissingKeyReturnsNil() {
        let doc = INIDocument(parsing: "[A]\nkey=value\n")
        XCTAssertNil(doc.value(section: "A", key: "missing"))
        XCTAssertNil(doc.value(section: "MissingSection", key: "key"))
    }

    // MARK: - Enumeration

    func testSectionsReturnsNamesInFirstAppearanceOrder() {
        let text = "[B]\nkey=1\n[A]\nkey=2\n[B]\nother=3\n"
        let doc = INIDocument(parsing: text)

        XCTAssertEqual(doc.sections(), ["B", "A"])
    }

    func testKeysInSectionReturnsKeysInFirstAppearanceOrder() {
        let text = "[A]\nfirst=1\nsecond=2\nfirst=overwritten\n"
        let doc = INIDocument(parsing: text)

        XCTAssertEqual(doc.keys(inSection: "A"), ["first", "second"])
    }

    // MARK: - What a read-modify-write must not lose (F-375)
    //
    // These are the properties a sweep over 350 real .ini/.cfg/.properties files on this machine checked,
    // and that the sweep can no longer check once it is gone. The sweep found no defect — after the check
    // was taught to see one: its first version reported nothing when `serialized()` was made to drop every
    // comment, because comparing parse → serialize → parse cannot notice a loss that is stable.

    /// A file with every construct the parser distinguishes, and a few it does not.
    private let awkward = """
    ; a leading comment
    # another comment style

    [Section One]
    key=value
    spaced key = spaced value
    empty=
    [Section Two]
    ; a comment inside a section
    key=value with = signs and ; semicolons
    a line that is not a pair
    """

    func testEveryCommentSurvivesARoundTrip() {
        let out = INIDocument(parsing: awkward).serialized()
        for comment in ["; a leading comment", "# another comment style", "; a comment inside a section"] {
            XCTAssertTrue(out.contains(comment), "lost \(comment)\n\(out)")
        }
    }

    func testALineThatIsNotAPairIsKeptVerbatim() {
        // The parser keeps anything it does not recognise, so a settings file it half-understands does
        // not lose the half it does not.
        XCTAssertTrue(INIDocument(parsing: awkward).serialized().contains("a line that is not a pair"))
    }

    func testBlankLinesAndSectionOrderSurvive() {
        let out = INIDocument(parsing: awkward).serialized()
        let sections = out.split(separator: "\n").filter { $0.hasPrefix("[") }.map(String.init)
        XCTAssertEqual(sections, ["[Section One]", "[Section Two]"])
        XCTAssertTrue(out.contains("\n\n"), "the blank line between the comments and the first section is gone")
    }

    func testSerializingIsIdempotent() {
        let once = INIDocument(parsing: awkward).serialized()
        XCTAssertEqual(INIDocument(parsing: once).serialized(), once)
    }

    func testAValueContainingAnEqualsSignSurvives() {
        let doc = INIDocument(parsing: awkward)
        XCTAssertEqual(doc.value(section: "Section Two", key: "key"),
                       "value with = signs and ; semicolons")
    }

    func testSettingOneValueLeavesEveryOtherAlone() {
        let doc = INIDocument(parsing: awkward)
        var edited = doc
        edited.set("changed", section: "Section One", key: "key")
        XCTAssertEqual(edited.value(section: "Section One", key: "key"), "changed")
        XCTAssertEqual(edited.value(section: "Section One", key: "empty"), "")
        XCTAssertEqual(edited.value(section: "Section Two", key: "key"),
                       "value with = signs and ; semicolons")
        // …and the comments are still there afterwards, which is the point of a comment-preserving parser.
        XCTAssertTrue(edited.serialized().contains("; a comment inside a section"))
    }

    // MARK: - Line endings (F-375)

    func testACRLFFileStaysCRLF() {
        // The editor promises a line operation never changes the terminator on its own, and the Format
        // button runs this serializer on files the user owns. Joining with "\n" regardless rewrote every
        // line of a Windows-style INI — 34 of the 350 files in the sweep were CRLF.
        let out = INIDocument(parsing: "[S]\r\na=1\r\nb=2\r\n").serialized()
        XCTAssertTrue(out.contains("\r\n"), out.debugDescription)
        XCTAssertFalse(out.replacingOccurrences(of: "\r\n", with: "").contains("\n"),
                       "a stray LF means the file was rewritten with mixed endings: \(out.debugDescription)")
    }

    func testAnLFFileStaysLF() {
        let out = INIDocument(parsing: "[S]\na=1\n").serialized()
        XCTAssertFalse(out.contains("\r"), out.debugDescription)
    }

    func testTheDominantTerminatorWins() {
        // A CRLF file with one stray LF is a CRLF file; rewriting all of it because of the stray one is
        // the behaviour being avoided.
        let out = INIDocument(parsing: "[S]\r\na=1\r\nb=2\nc=3\r\n").serialized()
        XCTAssertEqual(out.components(separatedBy: "\r\n").count - 1, 4, out.debugDescription)
    }

    func testAnEditedCRLFFileIsStillCRLF() {
        var doc = INIDocument(parsing: "[S]\r\na=1\r\n")
        doc.set("2", section: "S", key: "b")
        XCTAssertTrue(doc.serialized().contains("b=2\r\n"), doc.serialized().debugDescription)
    }

    func testACRLFFileIsParsedAtAll() {
        // The defect this whole sweep found: in Swift "\r\n" is a single Character, so
        // `split(separator: "\n")` does not split a CRLF file — the parser saw one giant line, read
        // `[S]\r\na` as a key, and every section header was lost. A Windows-written INI, which is to say
        // every `wincmd.ion` and most `.ini` files in the world, was never parsed correctly.
        let doc = INIDocument(parsing: "[Section]\r\nkey=value\r\nother=2\r\n")
        XCTAssertEqual(doc.sections(), ["Section"])
        XCTAssertEqual(doc.value(section: "Section", key: "key"), "value")
        XCTAssertEqual(doc.value(section: "Section", key: "other"), "2")
    }

    func testACRFileIsParsedToo() {
        // Classic Mac endings, for completeness: also one Character, also never split.
        let doc = INIDocument(parsing: "[S]\rkey=value\r")
        XCTAssertEqual(doc.value(section: "S", key: "key"), "value")
    }

    func testCommentsSurviveInACRLFFile() {
        let out = INIDocument(parsing: "; note\r\n[S]\r\na=1\r\n").serialized()
        XCTAssertTrue(out.contains("; note"), out.debugDescription)
        XCTAssertTrue(out.contains("[S]"), out.debugDescription)
    }

    // MARK: - The file belongs to the user (F-275)
    //
    // These files are documented as ones people edit by hand. The serializer rebuilt every line as
    // `key=value`, so the first time the app wrote anything it reformatted the whole file — lines nobody
    // had touched included. A configuration file that reformats itself is one you stop hand-editing.

    private var handWritten: String {
        """
        ; Peach Commander configuration
        ; edited by hand — please keep the comments

        [Colors]
        Appearance = dark
        BackColor=#101010

        [Operation]
        # a hash comment, also legal
        VerifyAfterCopy = 1

        [Empty]

        [Paths]
        Extra = a=b=c
        """
    }

    func testReadingAndWritingWithoutChangingAnythingLeavesTheFileAlone() {
        let doc = INIDocument(parsing: handWritten)
        // The serializer ends the last line, which the fixture does not; that is the only difference.
        XCTAssertEqual(doc.serialized(), handWritten + "\n")
    }

    func testSettingOneValueChangesOneLineAndKeepsItsSpacing() {
        var doc = INIDocument(parsing: handWritten)
        doc.set("light", section: "Colors", key: "Appearance")
        let lines = doc.serialized().split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let before = handWritten.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines[4], "Appearance = light", "the author's spacing around = must survive")
        for index in before.indices where index != 4 {
            XCTAssertEqual(lines[index], before[index], "line \(index + 1) changed and should not have")
        }
    }

    func testASemicolonInAValueIsPartOfTheValue() {
        // Deliberate, and worth pinning so nobody "fixes" it into inline-comment support: Windows'
        // profile API has no inline comments either, and a path list separated by semicolons — which is
        // what these files hold — would be truncated at the first one.
        let doc = INIDocument(parsing: "[S]\nPaths = /one;/two;/three\n")
        XCTAssertEqual(doc.value(section: "S", key: "Paths"), "/one;/two;/three")
    }

    func testAddingAKeyDoesNotDisturbTheLinesAlreadyThere() {
        var doc = INIDocument(parsing: handWritten)
        doc.set("dvorak", section: "Operation", key: "Keyboard")
        let text = doc.serialized()
        XCTAssertTrue(text.contains("Keyboard=dvorak"))
        XCTAssertTrue(text.contains("; edited by hand — please keep the comments"))
        XCTAssertTrue(text.contains("VerifyAfterCopy = 1"), "an untouched line kept its spacing")
        XCTAssertTrue(text.contains("[Empty]"), "an empty section is still someone's placeholder")
    }
}
