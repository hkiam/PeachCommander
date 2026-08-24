// SPDX-License-Identifier: Apache-2.0
// MarkdownFileTypeTests.swift — one answer to "is this Markdown", and the three it replaced.
//
// There were three sets and no two agreed: a `.mdx` file had an outline and could not be rendered, a
// `.mkdn` file was rendered and could not be reformatted. These pin the union and, more usefully, pin
// that the two consumers still inside this framework read *this* set rather than one of their own.

import XCTest
@testable import PCFoundation

final class MarkdownFileTypeTests: XCTestCase {

    func testEveryAliasIsMarkdown() {
        for ext in ["md", "markdown", "mdown", "mkd", "mkdn", "mdwn", "mdx"] {
            XCTAssertTrue(MarkdownFileType.matches(ext), ext)
        }
    }

    func testTheDotAndTheCaseDoNotMatter() {
        XCTAssertTrue(MarkdownFileType.matches(".MD"))
        XCTAssertTrue(MarkdownFileType.matches("Markdown"))
    }

    func testWhatIsNotMarkdown() {
        for ext in ["txt", "html", "m", "mdb", "", "md5"] {
            XCTAssertFalse(MarkdownFileType.matches(ext), ext)
        }
    }

    /// The point of the type: the outline and the Format button read the same set. Before this, `.mkdn`
    /// was outlined by neither and `.mdx` reformatted by neither, and nothing said that was meant.
    func testTheOutlineAndTheFormatterAgreeWithIt() {
        for ext in MarkdownFileType.sorted {
            XCTAssertTrue(DeclarationOutline.supports(ext: ext), "outline: \(ext)")
            XCTAssertEqual(DeclarationOutline.displayName(ext: ext), "Markdown", ext)
        }
        let markdownPrettier = DefaultExternalFormatters.all()
            .first { $0.tool == "prettier" && $0.supportedExtensions.contains("md") }
        XCTAssertEqual(markdownPrettier.map { Set($0.supportedExtensions) },
                       MarkdownFileType.extensions)
    }
}
