import XCTest
@testable import PCFoundation

final class DescriptionFileTests: XCTestCase {
    func testParseSimple() {
        let d = DescriptionFile(parsing: "readme.txt The project readme\nnotes.md Some notes\n")
        XCTAssertEqual(d.comment(for: "readme.txt"), "The project readme")
        XCTAssertEqual(d.comment(for: "notes.md"), "Some notes")
        XCTAssertNil(d.comment(for: "missing"))
    }

    func testParseQuotedNameWithSpaces() {
        let d = DescriptionFile(parsing: "\"my file.txt\" comment for spaced name\n")
        XCTAssertEqual(d.comment(for: "my file.txt"), "comment for spaced name")
    }

    func testSerializeQuotesSpacedNames() {
        var d = DescriptionFile()
        d.setComment("hello", for: "a.txt")
        d.setComment("spaced comment", for: "my doc.pdf")
        // Sorted by name: "a.txt" then "my doc.pdf".
        XCTAssertEqual(d.serialized(), "a.txt hello\n\"my doc.pdf\" spaced comment\n")
    }

    func testSetEmptyRemoves() {
        var d = DescriptionFile(parsing: "a.txt keep\nb.txt drop\n")
        d.setComment("", for: "b.txt")
        d.setComment(nil, for: "a.txt")
        XCTAssertTrue(d.isEmpty)
        XCTAssertEqual(d.serialized(), "")
    }

    func testRoundTrip() {
        var d = DescriptionFile()
        d.setComment("first", for: "one.txt")
        d.setComment("has spaces here", for: "two files.bin")
        d.setComment("üñîçödé comment 🍑", for: "z.dat")
        let round = DescriptionFile(parsing: d.serialized())
        XCTAssertEqual(round, d)
    }

    func testEmptyCommentsIgnoredOnParse() {
        let d = DescriptionFile(parsing: "lonely.txt   \n\n  \n")
        XCTAssertTrue(d.isEmpty)
    }
}
