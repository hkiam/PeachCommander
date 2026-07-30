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
}
