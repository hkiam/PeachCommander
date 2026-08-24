// SPDX-License-Identifier: Apache-2.0
// MarkdownPluginTests.swift — the parts of the plugin that are not the renderer.
//
// Three things are checked here, and the first is the one that matters most: which document may run
// scripts. Markdown and HTML now go through the same plugin, and the plugin must treat them
// differently — its own generated page may run the rendering engines, and a .html file somebody
// downloaded may not run anything. That is enforced by two configurations rather than a flag, and
// this is where the two are held apart.

import AppKit
import PCFoundation
import WebKit
import XCTest

final class MarkdownPluginTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("markdown-plugin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func write(_ name: String, _ contents: String) throws -> String {
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    // MARK: - Which document may run scripts

    @MainActor
    func testOurOwnPageMayRunScriptsAndAForeignOneMayNot() {
        // The engines are JavaScript, so the generated Markdown page has to allow it. A .html file is
        // somebody else's document: opening it to look at it must not run it. Two configurations, so
        // there is no single switch to set wrongly — and this asserts they really differ.
        let own = makeMarkdownWebView(policy: .ownDocument)
        let foreign = makeMarkdownWebView(policy: .foreignDocument)
        XCTAssertTrue(own.configuration.defaultWebpagePreferences.allowsContentJavaScript)
        XCTAssertFalse(foreign.configuration.defaultWebpagePreferences.allowsContentJavaScript)
    }

    @MainActor
    func testAnHTMLFileIsLoadedUnderTheForeignPolicy() throws {
        // The policy follows the *file*, not a setting: an .md gets the permissive one and an .html
        // the strict one, decided once at load and never re-asked.
        let md = try XCTUnwrap(MarkdownListerView.make(path: try write("a.md", "# Title"), surface: "viewer"))
        let html = try XCTUnwrap(MarkdownListerView.make(path: try write("a.html", "<h1>Title</h1>"),
                                                    surface: "viewer"))
        XCTAssertTrue(md.contentWebView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
        XCTAssertFalse(html.contentWebView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
    }

    @MainActor
    func testAFileThePluginDoesNotClaimIsDeclined() throws {
        // Returning nil from init is how a PLX plugin says "not mine", and the host then falls back to
        // its own viewer. A plugin that accepted everything would black-hole every file it claimed.
        XCTAssertNil(MarkdownListerView.make(path: try write("a.txt", "plain"), surface: "viewer"))
        XCTAssertNil(MarkdownListerView.make(path: dir.appendingPathComponent("gone.md").path,
                                        surface: "viewer"))
    }

    // MARK: - What the viewer asks for

    @MainActor
    func testTheOutlineCarriesLineDepthAndAnchor() throws {
        let view = try XCTUnwrap(MarkdownListerView.make(
            path: try write("out.md", "# Top\n\ntext\n\n## Nested\n\n# Second\n"), surface: "viewer"))
        let rows = view.outlineRows()
        XCTAssertEqual(rows.map(\.title), ["Top", "Nested", "Second"])
        XCTAssertEqual(rows.map(\.depth), [0, 1, 0])
        XCTAssertEqual(rows.map(\.line), [1, 5, 7])
        // The anchors must be the ids the render pass actually put in the page — the host hands them
        // straight back through ListGotoAnchor, so an invented one would scroll nowhere.
        XCTAssertEqual(rows.map(\.anchor), ["top", "nested", "second"])
    }

    @MainActor
    func testAnHTMLDocumentHasNoOutlineOfItsOwn() throws {
        // Which is what the application also offered: the sidebar was only ever filled for Markdown
        // in the rendered representation. The host falls back to outlining the text it is handed.
        let view = try XCTUnwrap(MarkdownListerView.make(path: try write("a.html", "<h1>Title</h1>"),
                                                    surface: "viewer"))
        XCTAssertEqual(view.outlineRows().count, 0)
        XCTAssertTrue(view.documentText.contains("<h1>Title</h1>"))
    }

    @MainActor
    func testDocumentTextIsTheMarkdownSource() throws {
        // The source rather than the rendered text: it is what a reader searches for, what the outline
        // is built from, and it is already in memory.
        let markdown = "# Überschrift\n\nEin Satz mit Umlauten: äöü.\n"
        let view = try XCTUnwrap(MarkdownListerView.make(path: try write("u.md", markdown), surface: "viewer"))
        XCTAssertEqual(view.documentText, markdown)
    }

    @MainActor
    func testAnchorsOutsideTheDocumentAreRefused() throws {
        let view = try XCTUnwrap(MarkdownListerView.make(path: try write("n.md", "# One\n"), surface: "viewer"))
        XCTAssertTrue(view.gotoAnchor("one"))
        XCTAssertFalse(view.gotoAnchor("nonsense"))
        XCTAssertFalse(view.gotoAnchor(""))
    }

    @MainActor
    func testTheSurfaceTheHostNamedIsKept() throws {
        // What ListLoadEx exists to deliver. Acted on later — a narrower chrome for the preview
        // column — but plumbed and checked now, so the plumbing is not the thing that breaks then.
        let view = try XCTUnwrap(MarkdownListerView.make(path: try write("s.md", "# S"), surface: "preview"))
        XCTAssertEqual(view.embeddedSurface, "preview")
    }

    // MARK: - Thumbnails

    @MainActor
    func testAThumbnailIsDrawnForMarkdownAndNotForHTML() throws {
        let md = try write("t.md", "# Title\n\nSome prose.\n\n```swift\nlet x = 1\n```\n")
        let png = try XCTUnwrap(MarkdownThumbnail.png(for: md, maxWidth: 128, maxHeight: 128))
        XCTAssertEqual(Array(png.prefix(8)), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let image = try XCTUnwrap(NSImage(data: png))
        XCTAssertEqual(image.size.width, 128, accuracy: 1)
        // HTML declines on purpose: there is no source worth showing as text, and QuickLook draws it.
        XCTAssertNil(MarkdownThumbnail.png(for: try write("t.html", "<h1>x</h1>"),
                                           maxWidth: 128, maxHeight: 128))
    }

    @MainActor
    func testAThumbnailIsNotDrawnIntoAnImpossibleSize() throws {
        let md = try write("small.md", "# Title\n")
        XCTAssertNil(MarkdownThumbnail.png(for: md, maxWidth: 8, maxHeight: 8))
    }
}
