// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class MarkdownRendererTests: XCTestCase {
    private func body(_ md: String) -> String { MarkdownRenderer.bodyHTML(from: md) }

    func testHeadings() {
        // Every heading carries an id, so the viewer's outline can scroll the rendered page to it.
        XCTAssertEqual(body("# Title"), "<h1 id=\"title\">Title</h1>")
        XCTAssertEqual(body("### Sub"), "<h3 id=\"sub\">Sub</h3>")
        // Trailing hashes stripped.
        XCTAssertEqual(body("## Heading ##"), "<h2 id=\"heading\">Heading</h2>")
    }

    // MARK: - Heading anchors (F-410)

    /// The anchors are keyed by the heading's source line, which is what the outline knows a heading by.
    func testAnchorsAreKeyedBySourceLine() {
        let rendered = MarkdownRenderer.render("""
        # Titel

        ## Erster Abschnitt

        text

        ### Unterpunkt A
        """)
        XCTAssertEqual(rendered.anchors[1], "titel")
        XCTAssertEqual(rendered.anchors[3], "erster-abschnitt")
        XCTAssertEqual(rendered.anchors[7], "unterpunkt-a")
        XCTAssertEqual(rendered.anchors.count, 3)
    }

    /// A `#` inside a fenced code block is code, and must not become an anchor — the reason the anchors
    /// come out of the render pass instead of a second scan over the source.
    func testHashInsideACodeFenceIsNotAHeading() {
        let rendered = MarkdownRenderer.render("""
        # Real

        ```
        # not a heading
        ```
        """)
        XCTAssertEqual(rendered.anchors, [1: "real"])
        XCTAssertFalse(rendered.html.contains("id=\"not-a-heading\""))
    }

    /// A document may repeat a heading; the ids must still be unique or navigation goes to the first one.
    func testRepeatedHeadingsGetDistinctAnchors() {
        let rendered = MarkdownRenderer.render("""
        ## Notes

        ## Notes

        ## Notes
        """)
        XCTAssertEqual([rendered.anchors[1], rendered.anchors[3], rendered.anchors[5]],
                       ["notes", "notes-2", "notes-3"])
    }

    /// Unicode letters are kept (the id is only ever looked up by this app), punctuation collapses to a
    /// single dash, and a heading with nothing usable in it still gets an id.
    func testAnchorSlugRules() {
        XCTAssertEqual(MarkdownRenderer.render("# Größe & Datum!").anchors[1], "größe-datum")
        XCTAssertEqual(MarkdownRenderer.render("# A -- B").anchors[1], "a-b")
        XCTAssertEqual(MarkdownRenderer.render("# 42").anchors[1], "42")
        XCTAssertEqual(MarkdownRenderer.render("# ***").anchors[1], "section")
    }

    // MARK: - Underlined (setext) headings

    /// `Title` over `===` / `---` is a heading, not a paragraph followed by a rule. The outline has always
    /// read this form (the repo's own README uses it), so the rendered page had entries with no anchor.
    func testUnderlinedHeadings() {
        let rendered = MarkdownRenderer.render("""
        Titel
        =====

        Abschnitt
        ---------
        """)
        XCTAssertEqual(rendered.anchors, [1: "titel", 4: "abschnitt"])
        XCTAssertTrue(rendered.html.contains("<h1 id=\"titel\">Titel</h1>"))
        XCTAssertTrue(rendered.html.contains("<h2 id=\"abschnitt\">Abschnitt</h2>"))
        XCTAssertFalse(rendered.html.contains("<hr>"))
    }

    /// A rule on its own is still a rule, and a table's delimiter row is still a table.
    func testDashesThatAreNotHeadings() {
        XCTAssertEqual(body("---"), "<hr>")
        XCTAssertTrue(body("A | B\n--- | ---\n1 | 2").hasPrefix("<table>"))
        // A dash run inside a code fence stays code.
        XCTAssertTrue(body("```\nTitle\n---\n```").contains("<pre><code>"))
    }

    /// The anchors survive the document wrapper, which is what the viewer actually loads.
    func testDocumentCarriesTheSameAnchors() {
        let rendered = MarkdownRenderer.document(from: "# Hi\n\n## There", title: "t")
        XCTAssertEqual(rendered.anchors, [1: "hi", 3: "there"])
        XCTAssertTrue(rendered.html.contains("<h2 id=\"there\">There</h2>"))
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
        XCTAssertTrue(doc.contains("<h1 id=\"hi\">Hi</h1>"))
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
