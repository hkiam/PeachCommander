// SPDX-License-Identifier: Apache-2.0
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

    // MARK: - Total Commander's multi-line extension (F-374)
    //
    // The format: a line break inside a comment is stored as a literal backslash-n, and the two bytes
    // 0x04 0xC2 are appended to the line. 0x04 introduces a 4DOS extension; 0xC2 is the code Total
    // Commander was given for "this comment uses \\n for line breaks". Without the marker, `\\n` is two
    // characters somebody typed.

    private let marker = "\u{04}\u{C2}"

    func testAMultiLineCommentIsReadAsLineBreaks() {
        let doc = DescriptionFile(parsing: "report.txt first line\\nsecond line\(marker)\n")
        XCTAssertEqual(doc.comment(for: "report.txt"), "first line\nsecond line")
    }

    func testWithoutTheMarkerBackslashNStaysLiteral() {
        // Somebody else's comment must not sprout line breaks: this is a Windows path, not two lines.
        let doc = DescriptionFile(parsing: "setup.exe unpacks into C:\\new\\files\n")
        XCTAssertEqual(doc.comment(for: "setup.exe"), "unpacks into C:\\new\\files")
    }

    func testAMultiLineCommentRoundTripsThroughTheMarker() {
        var doc = DescriptionFile()
        doc.setComment("first line\nsecond line", for: "a.txt")
        let text = doc.serialized()
        XCTAssertTrue(text.contains("first line\\nsecond line"), text.debugDescription)
        XCTAssertTrue(text.contains(marker), "the marker is what makes the escape readable: \(text.debugDescription)")
        XCTAssertEqual(DescriptionFile(parsing: text).comment(for: "a.txt"), "first line\nsecond line")
    }

    func testASingleLineCommentGetsNoMarker() {
        var doc = DescriptionFile()
        doc.setComment("just one line", for: "a.txt")
        XCTAssertFalse(doc.serialized().contains(marker))
    }

    func testAQuotedNameWithAMultiLineComment() {
        let doc = DescriptionFile(parsing: "\"two words.txt\" a\\nb\(marker)\n")
        XCTAssertEqual(doc.comment(for: "two words.txt"), "a\nb")
    }

    func testTheMarkerIsNotLeftInACommentlessLine() {
        // A line that is only a name plus the marker: nothing to comment, and the marker is not a name.
        let doc = DescriptionFile(parsing: "lonely.txt\(marker)\n")
        XCTAssertNil(doc.comment(for: "lonely.txt"))
        XCTAssertNil(doc.comment(for: "lonely.txt" + marker))
    }

    // MARK: - Encodings (F-374)

    func testUTF8WithoutABOM() {
        let data = Data("a.txt hello\n".utf8)
        let decoded = DescriptionFile.decode(data)
        XCTAssertEqual(decoded.encoding, .utf8)
        XCTAssertEqual(DescriptionFile(parsing: decoded.text).comment(for: "a.txt"), "hello")
    }

    func testUTF8WithABOM() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("a.txt hällo\n".utf8))
        let decoded = DescriptionFile.decode(data)
        XCTAssertEqual(decoded.encoding, .utf8BOM)
        XCTAssertEqual(DescriptionFile(parsing: decoded.text).comment(for: "a.txt"), "hällo")
    }

    func testUTF16LittleEndian() {
        // What Total Commander writes when a comment needs characters the codepage cannot hold. Read as
        // UTF-8 this is replacement characters, and writing it back destroyed every comment in the
        // directory — including the ones nobody had touched.
        var data = Data([0xFF, 0xFE])
        data.append("a.txt Grüße aus Zürich\n".data(using: .utf16LittleEndian)!)
        let decoded = DescriptionFile.decode(data)
        XCTAssertEqual(decoded.encoding, .utf16LE)
        XCTAssertEqual(DescriptionFile(parsing: decoded.text).comment(for: "a.txt"), "Grüße aus Zürich")
    }

    func testUTF16BigEndian() {
        var data = Data([0xFE, 0xFF])
        data.append("a.txt Grüße\n".data(using: .utf16BigEndian)!)
        let decoded = DescriptionFile.decode(data)
        XCTAssertEqual(decoded.encoding, .utf16BE)
        XCTAssertEqual(DescriptionFile(parsing: decoded.text).comment(for: "a.txt"), "Grüße")
    }

    func testEveryEncodingRoundTripsItsOwnBytes() {
        for encoding in [DescriptionFile.Encoding.utf8, .utf8BOM, .utf16LE, .utf16BE] {
            let text = "a.txt Grüße\n\"b c.txt\" 日本語\n"
            let data = DescriptionFile.encode(text, as: encoding)
            let back = DescriptionFile.decode(data)
            XCTAssertEqual(back.encoding, encoding, "BOM not recognised for \(encoding)")
            XCTAssertEqual(back.text, text, "text changed for \(encoding)")
        }
    }

    func testTheBOMIsNotPartOfTheFirstName() {
        // The classic BOM bug: the first entry becomes "\u{FEFF}a.txt" and is never found again.
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("a.txt hello\n".utf8))
        let doc = DescriptionFile(parsing: DescriptionFile.decode(data).text)
        XCTAssertEqual(doc.comments.keys.sorted(), ["a.txt"])
    }

    // MARK: - The line endings this format actually arrives with (F-023 / F-374)

    func testACRLFDescriptionFileKeepsEveryComment() {
        // `descript.ion` comes from 4DOS and is read and written by Total Commander, so a file written on
        // Windows — CRLF — is the ordinary case, not the exotic one. The parser compared each Character
        // against "\n" and "\r"; a CRLF is one Character equal to neither, so the file did not split at
        // all: one comment survived, holding the rest of the file as its text, and the others vanished.
        let doc = DescriptionFile(parsing: "a.txt a comment\r\nb.txt another\r\nc.txt third\r\n")
        XCTAssertEqual(doc.comments.count, 3)
        XCTAssertEqual(doc.comment(for: "a.txt"), "a comment")
        XCTAssertEqual(doc.comment(for: "b.txt"), "another")
        XCTAssertEqual(doc.comment(for: "c.txt"), "third")
    }

    func testALoneCarriageReturnFileStillParses() {
        let doc = DescriptionFile(parsing: "a.txt one\rb.txt two\r")
        XCTAssertEqual(doc.comment(for: "a.txt"), "one")
        XCTAssertEqual(doc.comment(for: "b.txt"), "two")
    }

    func testMixedLineEndingsLoseNothing() {
        let doc = DescriptionFile(parsing: "a.txt one\r\nb.txt two\nc.txt three\r\n")
        XCTAssertEqual(doc.comments.count, 3)
    }
}
