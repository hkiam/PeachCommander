// SPDX-License-Identifier: Apache-2.0
import XCTest
import AppKit
@testable import PCAutomation

// The chat renders the model's Markdown. Before this the answers went on screen verbatim,
// so the "Make a table" action — which uses guided generation precisely so the table is
// always well-formed — arrived as rows of pipe characters. These tests pin the parsing:
// what becomes a table, what becomes code, what stays text, and that no markup leaks
// through as literal characters.
final class ChatMarkdownTests: XCTestCase {

    private var style: ChatMarkdownStyle { ChatMarkdownStyle(theme: .systemFallback) }

    // MARK: Tables

    func test_table_isLaidOutAsATable_notAsPipes() {
        let md = """
        Hier die Auswertung:

        | Datei | Größe |
        | --- | --- |
        | bericht.txt | 12 KB |
        | notizen.txt | 3 KB |
        """
        let out = ChatMarkdown.render(md, style: style)
        XCTAssertFalse(out.string.contains("|"), "no pipe characters may survive: \(out.string)")
        XCTAssertFalse(out.string.contains("---"))
        XCTAssertTrue(out.string.contains("bericht.txt"))
        XCTAssertTrue(out.string.contains("12 KB"))

        // Every cell carries a table block, which is what makes TextKit lay out columns.
        var blocks = 0
        out.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: out.length)) { value, _, _ in
            if let p = value as? NSParagraphStyle, !p.textBlocks.isEmpty { blocks += 1 }
        }
        XCTAssertGreaterThanOrEqual(blocks, 6, "3 rows × 2 columns of table cells expected")
    }

    func test_tableHeader_isBold() {
        let out = ChatMarkdown.render("| A | B |\n| --- | --- |\n| 1 | 2 |", style: style)
        let headerRange = (out.string as NSString).range(of: "A")
        let font = out.attribute(.font, at: headerRange.location, effectiveRange: nil) as? NSFont
        XCTAssertEqual(font, NSFont.boldSystemFont(ofSize: 13))
    }

    // A separator row is what distinguishes a table from a line that merely has pipes in it.
    func test_pipesWithoutSeparator_stayText() {
        let out = ChatMarkdown.render("Nutze a | b als Trenner", style: style)
        XCTAssertTrue(out.string.contains("a | b"))
    }

    func test_separatorRecognition() {
        XCTAssertTrue(ChatMarkdown.isTableSeparator("| --- | :--: |"))
        XCTAssertTrue(ChatMarkdown.isTableSeparator("|---|---|"))
        XCTAssertFalse(ChatMarkdown.isTableSeparator("| a | b |"))
        XCTAssertFalse(ChatMarkdown.isTableSeparator("no pipes at all"))
    }

    func test_raggedTable_doesNotDropCells() {
        let out = ChatMarkdown.render("| A | B | C |\n|---|---|---|\n| 1 | 2 |", style: style)
        for cell in ["A", "B", "C", "1", "2"] {
            XCTAssertTrue(out.string.contains(cell), "missing \(cell)")
        }
    }

    // MARK: Code

    func test_fencedCode_isMonospacedAndVerbatim() {
        let out = ChatMarkdown.render("So geht das:\n```\nls -la *.txt\n```\n", style: style)
        XCTAssertFalse(out.string.contains("```"))
        XCTAssertTrue(out.string.contains("ls -la *.txt"))
        let range = (out.string as NSString).range(of: "ls -la")
        let font = out.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.monoSpace) ?? false)
    }

    func test_inlineCode_isMonospaced() {
        let out = ChatMarkdown.render("Rufe `read_file` auf.", style: style)
        XCTAssertFalse(out.string.contains("`"))
        let range = (out.string as NSString).range(of: "read_file")
        let font = out.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.monoSpace) ?? false)
    }

    func test_unterminatedFence_doesNotSwallowTheAnswer() {
        let out = ChatMarkdown.render("Ergebnis:\n```\nnoch offen", style: style)
        XCTAssertTrue(out.string.contains("Ergebnis:"))
        XCTAssertTrue(out.string.contains("noch offen"))
    }

    // MARK: Inline emphasis

    func test_boldAndItalic_loseTheirMarkers() {
        let out = ChatMarkdown.render("Das ist **wichtig** und *auch das*.", style: style)
        XCTAssertFalse(out.string.contains("*"))
        XCTAssertTrue(out.string.contains("wichtig"))
        let bold = (out.string as NSString).range(of: "wichtig")
        XCTAssertEqual(out.attribute(.font, at: bold.location, effectiveRange: nil) as? NSFont,
                       NSFont.boldSystemFont(ofSize: 13))
    }

    func test_unmatchedAsterisk_isKept() {
        let out = ChatMarkdown.render("Die Maske *.txt passt.", style: style)
        XCTAssertTrue(out.string.contains("*.txt"), "an unpaired marker is text: \(out.string)")
    }

    // MARK: Lists and headings

    func test_bulletList_becomesBullets() {
        let out = ChatMarkdown.render("- eins\n- zwei\n", style: style)
        XCTAssertTrue(out.string.contains("•"))
        XCTAssertFalse(out.string.contains("- eins"))
        XCTAssertTrue(out.string.contains("eins"))
    }

    func test_numberedList_keepsItsNumbers() {
        let out = ChatMarkdown.render("1. erst dies\n2. dann das\n", style: style)
        XCTAssertTrue(out.string.contains("1."))
        XCTAssertTrue(out.string.contains("2."))
    }

    func test_heading_isLargerThanBody() {
        let out = ChatMarkdown.render("## Ergebnis\n\nText danach.", style: style)
        XCTAssertFalse(out.string.contains("#"))
        let range = (out.string as NSString).range(of: "Ergebnis")
        let font = out.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        XCTAssertGreaterThan(font?.pointSize ?? 0, 13)
    }

    // MARK: Paths

    func test_paths_becomeClickableLinks() {
        let out = ChatMarkdown.render("Siehe /Users/maik1/Berichte/q3.txt für die Zahlen.", style: style)
        var links: [URL] = []
        out.enumerateAttribute(.link, in: NSRange(location: 0, length: out.length)) { value, _, _ in
            if let url = value as? URL { links.append(url) }
        }
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.scheme, "pcfile")
        XCTAssertEqual(links.first?.path, "/Users/maik1/Berichte/q3.txt")
    }

    func test_pathInsideATableCell_isStillALink() {
        let out = ChatMarkdown.render("| Datei |\n|---|\n| /tmp/a/b.txt |", style: style)
        var found = false
        out.enumerateAttribute(.link, in: NSRange(location: 0, length: out.length)) { value, _, _ in
            if (value as? URL)?.path == "/tmp/a/b.txt" { found = true }
        }
        XCTAssertTrue(found, "a path in a cell must stay navigable")
    }

    // MARK: Robustness

    func test_plainText_isUnchangedApartFromTrimming() {
        let out = ChatMarkdown.render("Einfach nur ein Satz.", style: style)
        XCTAssertEqual(out.string, "Einfach nur ein Satz.")
    }

    func test_emptyInput_producesEmptyOutput() {
        XCTAssertEqual(ChatMarkdown.render("", style: style).string, "")
        XCTAssertEqual(ChatMarkdown.render("\n\n\n", style: style).string, "")
    }

    // MARK: Images
    //
    // `![](…)` used to arrive as its own source text, bracket for bracket. It is now the picture —
    // read from disk, never fetched, and scaled so a screenshot cannot push the chat sideways.

    /// A real PNG on disk, `width` × `width/2`, so scaling is observable. Encoded straight from
    /// a bitmap rep rather than drawn into an NSImage: a test needs no window server for this.
    private func writePNG(width: Int, _ name: String) throws -> URL {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: width / 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ChatMarkdownTests-\(name).png")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func test_localImage_becomesAnAttachment() throws {
        let url = try writePNG(width: 40, "local")
        let out = ChatMarkdown.render("Hier:\n\n![Ein Diagramm](\(url.path))", style: style)
        let attachment = try XCTUnwrap((0..<out.length).compactMap {
            out.attribute(.attachment, at: $0, effectiveRange: nil) as? NSTextAttachment
        }.first, "no attachment in: \(out.string.debugDescription)")
        XCTAssertNotNil(attachment.image)
        XCTAssertFalse(out.string.contains("!["), "the source markup must not also be shown")
        XCTAssertFalse(out.string.contains(url.path))
    }

    func test_theAltTextSurvivesAsATooltip() throws {
        let url = try writePNG(width: 40, "alt")
        let out = ChatMarkdown.render("![Ein Diagramm](\(url.path))", style: style)
        let tips = (0..<out.length).compactMap { out.attribute(.toolTip, at: $0, effectiveRange: nil) as? String }
        XCTAssertEqual(tips.first, "Ein Diagramm")
    }

    func test_aWideImageIsScaledToTheAvailableWidth() throws {
        let url = try writePNG(width: 800, "wide")
        let narrow = ChatMarkdownStyle(theme: .systemFallback, maxImageWidth: 200)
        let attachment = try XCTUnwrap(ChatMarkdown.imageAttachment(path: url.path, style: narrow))
        XCTAssertEqual(attachment.bounds.width, 200, accuracy: 1)
        XCTAssertEqual(attachment.bounds.height, 100, accuracy: 1, "the aspect ratio must hold")
    }

    func test_aSmallImageIsNotBlownUp() throws {
        let url = try writePNG(width: 40, "small")
        let attachment = try XCTUnwrap(ChatMarkdown.imageAttachment(path: url.path, style: style))
        XCTAssertEqual(attachment.bounds.width, 40, accuracy: 1)
    }

    func test_aRemoteImageIsNotFetchedAndStaysVisibleAsText() {
        // The point of the whole exercise: an image URL in an answer is a read receipt, and this
        // renderer never asks for one. The reader still sees what was meant.
        for markup in ["![x](http://example.test/a.png)",
                       "![x](https://example.test/a.png)",
                       "![x](data:image/png;base64,AAAA)"] {
            let out = ChatMarkdown.render(markup, style: style)
            XCTAssertTrue(out.string.contains("!["), "\(markup) should have stayed text: \(out.string)")
            XCTAssertNil(ChatMarkdown.localImageURL(String(markup.dropFirst(5).dropLast())))
        }
    }

    func test_anUnreadableImageFallsBackToItsMarkdown() {
        let out = ChatMarkdown.render("![weg](/tmp/does-not-exist-\(UUID().uuidString).png)", style: style)
        XCTAssertTrue(out.string.contains("![weg]("), out.string)
    }

    func test_aRelativePathIsNotGuessedAt() {
        // Nothing in the chat view knows a current directory, so there is nothing to resolve
        // against — better literal text than an image loaded from the wrong place.
        XCTAssertNil(ChatMarkdown.localImageURL("pictures/a.png"))
        XCTAssertNil(ChatMarkdown.localImageURL(""))
        XCTAssertEqual(ChatMarkdown.localImageURL("/tmp/a.png")?.path, "/tmp/a.png")
    }

    func test_imageMarkupIsReadWithItsTitleLeftOut() throws {
        let m = try XCTUnwrap(ChatMarkdown.imageMarkup("![a](/tmp/x.png \"Titel\") danach"[...]))
        XCTAssertEqual(m.alt, "a")
        XCTAssertEqual(m.path, "/tmp/x.png")
        XCTAssertEqual(m.length, "![a](/tmp/x.png \"Titel\")".count)
        XCTAssertNil(ChatMarkdown.imageMarkup("![a] (/tmp/x.png)"[...]))
        XCTAssertNil(ChatMarkdown.imageMarkup("![a"[...]))
    }

    func test_everyCharacterIsStyled() {
        let out = ChatMarkdown.render("**A** und `b` und *c*", style: style)
        var unstyled = 0
        for i in 0..<out.length where out.attribute(.font, at: i, effectiveRange: nil) == nil { unstyled += 1 }
        XCTAssertEqual(unstyled, 0, "unstyled characters render in the wrong theme colour")
    }
}
