// SPDX-License-Identifier: Apache-2.0
// MarkdownThumbnail.swift — the window-less preview bitmap, for the gallery view.
//
// `ListGetPreviewBitmap` is synchronous and gets no view, which rules out the obvious approach: a
// `WKWebView` needs a window to lay out in and `takeSnapshot` is asynchronous, so there is nothing to
// wait for and nowhere to wait.
//
// The other obvious approach is worse. `NSAttributedString(html:baseURL:documentAttributes:)` would
// render the generated HTML synchronously and is already used elsewhere in the application for .docx
// and .rtf — but AppKit's HTML reader resolves the document's resources, and a Markdown file may name
// `![](http://…/x.png?who=…)`. That is the exact read receipt this whole plugin is built to refuse
// (F-116), and a thumbnail is drawn for every file in a folder without anybody asking for it. So it
// is not used, on purpose, and this is the note that says why.
//
// What is drawn instead is the *source*: the first lines, with headings given weight and code given a
// monospaced face. Not the rendered page and not pretending to be — but legible, which is the whole
// job of a 128-point tile, and it reaches no network by construction because it never leaves text.

import AppKit
import PCFoundation
// EncodingDetector — the same one the lister view uses, so a thumbnail and the page agree about
// what a Windows-written file says.
import PCVFS

enum MarkdownThumbnail {

    /// How much of the file is read. A thumbnail only ever shows the first few lines, and a gallery
    /// asks for one per file in the folder.
    private static let readCap = 64 * 1024

    /// A PNG thumbnail of `path`, at most `maxWidth` × `maxHeight` points, or nil.
    ///
    /// Markdown only. A foreign `.html` file has no source worth showing as text and QuickLook
    /// already draws it, so declining is the honest answer and the host falls back.
    @MainActor
    static func png(for path: String, maxWidth: Int, maxHeight: Int) -> Data? {
        guard MarkdownListerView.Kind.forExtension((path as NSString).pathExtension) == .markdown,
              maxWidth > 16, maxHeight > 16,
              let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let bytes = [UInt8](handle.readData(ofLength: readCap))
        let encoding = EncodingDetector.detect(Array(bytes.prefix(4096)))
        let text = String(bytes: bytes, encoding: encoding) ?? String(decoding: bytes, as: UTF8.self)
        let attributed = styled(text, width: CGFloat(maxWidth))
        guard attributed.length > 0 else { return nil }

        let size = NSSize(width: CGFloat(maxWidth), height: CGFloat(maxHeight))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: maxWidth, pixelsHigh: maxHeight,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        // A page, not a transparent tile: the gallery draws these over its own background, and text
        // on nothing is unreadable on half the themes.
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        let inset = NSRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12)
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        attributed.draw(with: inset, options: options)
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    /// The first lines of a Markdown document as an attributed string: headings weighted, fenced code
    /// monospaced, fence markers and leading `#` dropped so the tile reads as prose.
    ///
    /// Deliberately line-based rather than parsed. A thumbnail is a first impression; running the real
    /// parser over a file for a tile that is 128 points tall would cost the whole document to show ten
    /// lines of it.
    private static func styled(_ text: String, width: CGFloat) -> NSAttributedString {
        let out = NSMutableAttributedString()
        var inFence = false
        var lines = 0
        for raw in text.components(separatedBy: "\n") {
            if lines >= 14 { break }
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") || line.hasPrefix("~~~") { inFence.toggle(); continue }
            if line.isEmpty { continue }
            lines += 1
            let attributes: [NSAttributedString.Key: Any]
            if inFence {
                attributes = [.font: NSFont.monospacedSystemFont(ofSize: 6, weight: .regular),
                              .foregroundColor: NSColor.black.withAlphaComponent(0.65)]
                out.append(NSAttributedString(string: line + "\n", attributes: attributes))
                continue
            }
            var hashes = 0
            while hashes < line.count, Array(line)[hashes] == "#" { hashes += 1 }
            if hashes > 0, hashes <= 6 {
                let title = String(line.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
                let size = max(7, 13 - CGFloat(hashes) * 1.5)
                out.append(NSAttributedString(string: title + "\n", attributes: [
                    .font: NSFont.boldSystemFont(ofSize: size), .foregroundColor: NSColor.black]))
            } else {
                out.append(NSAttributedString(string: line + "\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 6),
                    .foregroundColor: NSColor.black.withAlphaComponent(0.8)]))
            }
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        out.addAttribute(.paragraphStyle, value: paragraph,
                         range: NSRange(location: 0, length: out.length))
        return out
    }
}
