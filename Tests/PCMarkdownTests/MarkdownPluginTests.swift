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

    // MARK: - Which engines a document needs
    //
    // The rule under test: a Markdown file with no diagram and no formula gets no JavaScript at all.
    // Everything else here is in service of not breaking that one.

    func testAPlainDocumentNeedsNothing() {
        XCTAssertEqual(MarkdownEngines.needs(of: "# Title\n\nJust prose.\n"), .init())
    }

    func testAMermaidFenceAsksForDiagrams() {
        let needs = MarkdownEngines.needs(of: "# T\n\n```mermaid\ngraph TD\n A --> B\n```\n")
        XCTAssertTrue(needs.diagrams)
        XCTAssertFalse(needs.maths, "a diagram is not a formula")
    }

    func testDollarsInsideCodeAskForNothing() {
        // The case that would otherwise load 300 KB of KaTeX to render nothing: a shell snippet.
        // Fenced *and* indented under a fence — the scan has to know it is inside one.
        let needs = MarkdownEngines.needs(of: """
        # Shell

        ```sh
        echo "$HOME kostet $5 und $6"
        ```
        """)
        XCTAssertEqual(needs, .init())
    }

    func testMathsIsDetectedGenerously() {
        XCTAssertTrue(MarkdownEngines.needs(of: "$$\na^2\n$$").maths)
        XCTAssertTrue(MarkdownEngines.needs(of: "inline $a^2$ here").maths)
        // Deliberately a false positive: two dollars on a prose line load KaTeX, and KaTeX's own
        // auto-render then decides — in the page, where it can see the tags — that this is not maths.
        // The cost is an injection; the alternative is a scanner that mangles a sentence.
        XCTAssertTrue(MarkdownEngines.needs(of: "kostet $5 und $6").maths)
        XCTAssertFalse(MarkdownEngines.needs(of: "kostet $5").maths)
    }

    @MainActor
    func testNoEngineIsInstalledForADocumentThatNeedsNone() {
        let web = makeMarkdownWebView(policy: .ownDocument)
        XCTAssertEqual(MarkdownEngines.install(.init(), into: web, configRoot: dir.path), [])
        XCTAssertEqual(web.configuration.userContentController.userScripts.count, 0)
    }

    @MainActor
    func testAPlainDocumentLoadsNoScriptsThroughTheView() throws {
        // The same rule one level up, where it actually matters.
        let view = try XCTUnwrap(MarkdownListerView.make(
            path: try write("plain.md", "# Title\n\nProse only.\n"), surface: "viewer",
            configRoot: dir.path))
        XCTAssertEqual(view.loadedEngines, [])
        XCTAssertEqual(view.contentWebView.configuration.userContentController.userScripts.count, 0)
    }

    // MARK: - Where the engines come from

    @MainActor
    func testAReadersOwnCopyBeatsTheBundledOne() throws {
        // The decompiler plugin's rule for engines, and for the same reason: a file somebody went to
        // the trouble of placing there is an explicit instruction. Also the only path this test bundle
        // can exercise — it has no engines of its own in its resources, which is itself the assertion
        // that `locate` does not invent one.
        XCTAssertNil(MarkdownAssets.locate("mermaid.min.js", configRoot: dir.path))

        let assets = URL(fileURLWithPath: MarkdownAssets.overrideDirectory(configRoot: dir.path))
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try "window.mermaid = {};".write(to: assets.appendingPathComponent("mermaid.min.js"),
                                        atomically: true, encoding: .utf8)

        let found = try XCTUnwrap(MarkdownAssets.locate("mermaid.min.js", configRoot: dir.path))
        XCTAssertEqual(found.source, .folder(assets.path))
        let script = try XCTUnwrap(MarkdownAssets.mermaidScript(configRoot: dir.path))
        XCTAssertEqual(script.js, "window.mermaid = {};")

        // And it reaches the page: two scripts, the engine and the bootstrap that drives it.
        let web = makeMarkdownWebView(policy: .ownDocument)
        let loaded = MarkdownEngines.install(.init(diagrams: true, maths: false),
                                            into: web, configRoot: dir.path)
        XCTAssertEqual(loaded, ["mermaid (\(assets.path))"])
        XCTAssertEqual(web.configuration.userContentController.userScripts.count, 2)
    }

    @MainActor
    func testAMissingEngineCostsTheFeatureAndNotTheDocument() throws {
        // No engine anywhere → nothing installed, and the document still renders. A plugin that
        // refused to show a file because a diagram could not be drawn would be the worse failure.
        let web = makeMarkdownWebView(policy: .ownDocument)
        XCTAssertEqual(MarkdownEngines.install(.init(diagrams: true, maths: true),
                                               into: web, configRoot: dir.path), [])
        let view = try XCTUnwrap(MarkdownListerView.make(
            path: try write("d.md", "# T\n\n```mermaid\ngraph TD\n```\n"), surface: "viewer",
            configRoot: dir.path))
        XCTAssertEqual(view.loadedEngines, [])
        XCTAssertTrue(view.documentText.contains("mermaid"))
    }

    // MARK: - What the reader chose

    func testOptionsRoundTripThroughTheirOwnFile() {
        // In markdown.ini rather than the host's peachcmd.ini: the plugin is removable, and a setting
        // in the host's file would outlive the plugin that meant something by it.
        var options = MarkdownOptions()
        options.claimFiles = false
        options.maths = false
        options.maxSizeMB = 3
        options.write(configRoot: dir.path)
        let read = MarkdownOptions.read(configRoot: dir.path)
        XCTAssertFalse(read.claimFiles)
        XCTAssertTrue(read.diagrams)
        XCTAssertFalse(read.maths)
        XCTAssertEqual(read.maxSizeMB, 3)
    }

    func testDefaultsApplyWhenThereIsNoFileAndNoConfigRoot() {
        // A host that publishes no context at all still gets working defaults, which is what the
        // no-services `ListLoad` path relies on.
        for root in [dir.path, ""] {
            let options = MarkdownOptions.read(configRoot: root)
            XCTAssertTrue(options.claimFiles)
            XCTAssertTrue(options.diagrams)
            XCTAssertTrue(options.maths)
            XCTAssertEqual(options.maxSizeMB, 8)
        }
    }

    @MainActor
    func testAFileOverTheSizeLimitIsDeclined() throws {
        // Declining is the ABI's way of saying "use your own viewer" — better than making somebody
        // wait while a 40 MB generated report becomes a DOM.
        var options = MarkdownOptions()
        options.maxSizeMB = 1
        options.write(configRoot: dir.path)
        let big = try write("big.md", String(repeating: "# Kopf\n\nText.\n", count: 90_000))
        XCTAssertGreaterThan(MarkdownListerView.fileSize(of: big), 1024 * 1024)
        XCTAssertNil(MarkdownListerView.make(path: big, surface: "viewer", configRoot: dir.path))
        // …and the same file is fine with the default limit.
        XCTAssertNotNil(MarkdownListerView.make(path: big, surface: "viewer", configRoot: ""))
    }

    @MainActor
    func testTurningTheEnginesOffKeepsThemOut() throws {
        // The switches have to reach the load path, not only the settings file.
        var options = MarkdownOptions()
        options.diagrams = false
        options.maths = false
        options.write(configRoot: dir.path)
        // An override engine exists, so "nothing loaded" cannot be mistaken for "nothing to load".
        let assets = URL(fileURLWithPath: MarkdownAssets.overrideDirectory(configRoot: dir.path))
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try "window.mermaid = {};".write(to: assets.appendingPathComponent("mermaid.min.js"),
                                        atomically: true, encoding: .utf8)
        let view = try XCTUnwrap(MarkdownListerView.make(
            path: try write("off.md", "# T\n\n```mermaid\ngraph TD\n```\n\n$$a$$\n"),
            surface: "viewer", configRoot: dir.path))
        XCTAssertEqual(view.loadedEngines, [])
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
