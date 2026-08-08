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

    // MARK: - The rendered document must not be able to phone home
    //
    // `![](http://…/x.png?who=…)` in a Markdown file is a read receipt: previewing the file tells that
    // server it was opened, and from which address. The viewer's comment said this could not happen
    // because JavaScript is disabled — measured with a local server as the witness, and the request
    // went out. An image element needs no JavaScript.
    //
    // This checks the policy is in the document; that it *works* is checked where it has to be, against
    // a real WebKit: the `viewer-beacon` VM scenario previews such a file and asks a server on the guest
    // whether anything arrived.

    func testTheDocumentCarriesAContentSecurityPolicy() {
        let html = MarkdownRenderer.htmlDocument(from: "# hi", title: "t")
        XCTAssertTrue(html.contains("http-equiv=\"Content-Security-Policy\""))
        XCTAssertTrue(html.contains(MarkdownRenderer.contentSecurityPolicy))
    }

    func testThePolicyForbidsEverythingButLocalImagesAndTheOwnStylesheet() {
        let policy = MarkdownRenderer.contentSecurityPolicy
        XCTAssertTrue(policy.contains("default-src 'none'"), "the default must be to allow nothing")
        // The case that must keep working: a document referring to a picture next to it.
        XCTAssertTrue(policy.contains("img-src file: data:"))
        // …and the case that must not: anything fetched over the network.
        XCTAssertFalse(policy.contains("http"), "a network scheme is allowed by the policy")
        XCTAssertFalse(policy.contains("*"), "a wildcard source defeats the policy")
    }

    func testTheHeadCarriesThePolicyBeforeAnythingCanLoad() {
        // A CSP in a <meta> only applies to what follows it, so it has to be in <head>, ahead of the
        // body — a policy after the first <img> would be a policy that arrives too late.
        let html = MarkdownRenderer.htmlDocument(from: "![x](http://example.test/a.png)", title: "t")
        let policyAt = try? XCTUnwrap(html.range(of: "Content-Security-Policy"))
        let imageAt = try? XCTUnwrap(html.range(of: "<img"))
        XCTAssertNotNil(policyAt); XCTAssertNotNil(imageAt)
        if let p = policyAt, let i = imageAt { XCTAssertTrue(p.lowerBound < i.lowerBound) }
    }
}
