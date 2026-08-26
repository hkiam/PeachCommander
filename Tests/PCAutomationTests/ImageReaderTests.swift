// SPDX-License-Identifier: Apache-2.0
// ImageReaderTests.swift — a picture read as words, which is the only way it reaches the model.
//
// Apple Intelligence is text-only here, so image understanding is Vision's work and the language
// model's job starts after it. That split is what these check: given a picture with words on it,
// the words come back — and given a file that is not a picture at all, the caller is told so
// rather than handed an empty description that reads as "nothing in it".
//
// No language model, so these run in the ordinary suite. They do need macOS 15 for Vision's Swift
// API and are skipped below it.

import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import PCAutomation

final class ImageReaderTests: XCTestCase {

    /// A PNG with `text` drawn on it, big and black on white — a stand-in for a scan.
    private func imageWithText(_ text: String) throws -> String {
        let width = 900, height = 220
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw XCTSkip("no bitmap context") }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.textMatrix = .identity
        let font = CTFontCreateWithName("Helvetica" as CFString, 64, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)]))
        context.textPosition = CGPoint(x: 30, y: 80)
        CTLineDraw(line, context)
        guard let image = context.makeImage() else { throw XCTSkip("no image") }

        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ocr-\(UUID().uuidString).png")
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }
        guard let dest = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw XCTSkip("no image destination") }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw XCTSkip("could not write the png") }
        return path
    }

    func testTheWordsOnAPictureComeBack() async throws {
        guard #available(macOS 15, *) else { throw XCTSkip("Vision's Swift API needs macOS 15") }
        let path = try imageWithText("Rechnung 4711")
        let described = try await ImageReader.describe(path: path)
        // The words are the whole point: a scan is a document that happens to be pixels, and this
        // is what lets naming, commenting and classifying work on one.
        XCTAssertTrue(described.text.contains("4711"), "OCR read: \(described.text)")
        XCTAssertTrue(described.text.lowercased().contains("rechnung"), "OCR read: \(described.text)")
    }

    func testAFileThatIsNotThereSaysSoRatherThanBeingEmpty() async {
        do {
            _ = try await ImageReader.describe(path: "/nowhere/at/all.png")
            XCTFail("a missing file must not read as an empty picture")
        } catch {
            // "nothing in this picture" and "this could not be looked at" are different answers.
        }
    }

    func testWhatCountsAsAPicture() {
        XCTAssertTrue(DirectActionPlan.isImage("scan_0042.JPG"))
        XCTAssertTrue(DirectActionPlan.isImage("/a/b/photo.heic"))
        XCTAssertFalse(DirectActionPlan.isImage("notes.txt"))
        // A PDF carries its own text and `read_file` already gets it; sending it through OCR would
        // be slower and worse.
        XCTAssertFalse(DirectActionPlan.isImage("report.pdf"))
    }
}
