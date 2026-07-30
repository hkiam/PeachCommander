// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class SyntaxHighlighterTests: XCTestCase {
    private func swift() -> SyntaxLanguage { SyntaxHighlighter.language(forExtension: "swift")! }

    private func kinds(_ text: String, _ lang: SyntaxLanguage) -> [(TokenKind, String)] {
        let chars = Array(text)
        return SyntaxHighlighter.tokens(text, language: lang).map { ($0.kind, String(chars[$0.range])) }
    }

    func testLanguageResolution() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "swift")?.name, "Swift")
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "PY")?.name, "Python")
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "h")?.name, "C")
        XCTAssertNil(SyntaxHighlighter.language(forExtension: "bin"))
    }

    func testSwiftKeywordNumberComment() {
        let toks = kinds("let x = 42 // note", swift())
        XCTAssertEqual(toks[0].0, .keyword); XCTAssertEqual(toks[0].1, "let")
        XCTAssertTrue(toks.contains { $0 == (.number, "42") })
        XCTAssertTrue(toks.contains { $0 == (.comment, "// note") })
        // "x" is not a keyword → not emitted.
        XCTAssertFalse(toks.contains { $0.1 == "x" })
    }

    func testString() {
        let toks = kinds(#"let s = "hi""#, swift())
        XCTAssertTrue(toks.contains { $0 == (.string, "\"hi\"") })
    }

    func testStringWithEscapedQuote() {
        let toks = kinds(#""a\"b""#, swift())
        XCTAssertEqual(toks.count, 1)
        XCTAssertEqual(toks[0].0, .string)
        XCTAssertEqual(toks[0].1, #""a\"b""#)   // the whole literal, escape respected
    }

    func testBlockComment() {
        let toks = kinds("a /* c1\nc2 */ b", swift())
        XCTAssertTrue(toks.contains { $0 == (.comment, "/* c1\nc2 */") })
    }

    func testUnterminatedStringStopsAtNewline() {
        let toks = kinds("\"oops\nlet y = 1", swift())
        XCTAssertEqual(toks.first?.0, .string)
        XCTAssertEqual(toks.first.map { $0.1 }, "\"oops")   // does not swallow the next line
        XCTAssertTrue(toks.contains { $0 == (.keyword, "let") })
    }

    func testPythonHashComment() {
        let py = SyntaxHighlighter.language(forExtension: "py")!
        let toks = kinds("def f(): # hi", py)
        XCTAssertEqual(toks.first?.0, .keyword)
        XCTAssertEqual(toks.first?.1, "def")
        XCTAssertTrue(toks.contains { $0 == (.comment, "# hi") })
    }

    func testIdentifierWithDigitsIsNotANumber() {
        let toks = kinds("var abc123 = 0", swift())
        XCTAssertFalse(toks.contains { $0.1 == "abc123" })   // consumed as identifier, no token
        XCTAssertTrue(toks.contains { $0 == (.number, "0") })
    }

    // MARK: - XML

    private func xml() -> SyntaxLanguage { SyntaxHighlighter.language(forExtension: "xml")! }

    func testXMLLanguageResolution() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "svg")?.name, "XML")
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "plist")?.name, "XML")
    }

    func testXMLTagsAttributesComments() {
        let doc = "<!-- c --><book id=\"b1\"><title>Hi</title></book>"
        let toks = kinds(doc, xml())
        XCTAssertTrue(toks.contains { $0 == (.comment, "<!-- c -->") })
        XCTAssertTrue(toks.contains { $0 == (.keyword, "book") })
        XCTAssertTrue(toks.contains { $0 == (.keyword, "title") })
        XCTAssertTrue(toks.contains { $0 == (.string, "\"b1\"") })
        // Closing tags keep the name highlighted.
        XCTAssertEqual(toks.filter { $0 == (.keyword, "title") }.count, 2)
    }
}
