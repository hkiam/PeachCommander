// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class MarkdownRendererTests: XCTestCase {
    private func body(_ md: String) -> String { MarkdownRenderer.bodyHTML(from: md) }

    func testHeadings() {
        XCTAssertEqual(body("# Title"), "<h1>Title</h1>")
        XCTAssertEqual(body("### Sub"), "<h3>Sub</h3>")
        // Trailing hashes stripped.
        XCTAssertEqual(body("## Heading ##"), "<h2>Heading</h2>")
    }

    func testParagraphAndInline() {
        XCTAssertEqual(body("hello world"), "<p>hello world</p>")
        XCTAssertEqual(body("**bold** and *italic*"),
                       "<p><strong>bold</strong> and <em>italic</em></p>")
        XCTAssertEqual(body("some `inline code` here"),
                       "<p>some <code>inline code</code> here</p>")
    }

    func testHTMLIsEscaped() {
        XCTAssertEqual(body("a < b & c > d"), "<p>a &lt; b &amp; c &gt; d</p>")
        // Code span content is escaped too.
        XCTAssertEqual(body("`<script>`"), "<p><code>&lt;script&gt;</code></p>")
    }

    func testLinksAndImages() {
        XCTAssertEqual(body("[text](https://example.com)"),
                       "<p><a href=\"https://example.com\">text</a></p>")
        XCTAssertEqual(body("![alt](img.png)"),
                       "<p><img alt=\"alt\" src=\"img.png\"></p>")
    }

    func testUnorderedList() {
        let html = body("- one\n- two\n- three")
        XCTAssertTrue(html.hasPrefix("<ul>"))
        XCTAssertTrue(html.contains("<li>one</li>"))
        XCTAssertTrue(html.contains("<li>three</li>"))
        XCTAssertTrue(html.hasSuffix("</ul>"))
    }

    func testOrderedList() {
        let html = body("1. first\n2. second")
        XCTAssertTrue(html.hasPrefix("<ol>"))
        XCTAssertTrue(html.contains("<li>first</li>"))
    }

    func testFencedCodeBlockPreservesContent() {
        let html = body("```\nlet x = a < b\n```")
        XCTAssertEqual(html, "<pre><code>let x = a &lt; b</code></pre>")
    }

    func testBlockquote() {
        XCTAssertEqual(body("> quoted"), "<blockquote><p>quoted</p></blockquote>")
    }

    func testThematicBreak() {
        XCTAssertEqual(body("---"), "<hr>")
        XCTAssertEqual(body("***"), "<hr>")
    }

    func testTable() {
        let html = body("| A | B |\n| --- | --- |\n| 1 | 2 |")
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th>A</th>"))
        XCTAssertTrue(html.contains("<td>1</td>"))
    }

    func testDocumentWrapperIsSelfContained() {
        let doc = MarkdownRenderer.htmlDocument(from: "# Hi", title: "t")
        XCTAssertTrue(doc.hasPrefix("<!DOCTYPE html>"))
        XCTAssertTrue(doc.contains("<style>"))          // embedded CSS, no network
        XCTAssertTrue(doc.contains("<h1>Hi</h1>"))
        XCTAssertFalse(doc.lowercased().contains("http://") || doc.lowercased().contains("https://"))
    }
}
