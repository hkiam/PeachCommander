// SPDX-License-Identifier: Apache-2.0
import XCTest
import AppKit
@testable import PCVFS

final class ContentFieldPredicateTests: XCTestCase {
    // MARK: - Pure evaluation

    private func pred(_ id: String, _ op: ContentOperator, _ v: String) -> ContentFieldPredicate {
        ContentFieldPredicate(qualifiedID: id, op: op, value: v)
    }

    // MARK: - End-to-end with the builtin provider (F-157 Find-dialog wiring)

    func testRegistryFilterBySizeViaBuiltinProvider() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-cfp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let small = dir.appendingPathComponent("small.txt")
        let big = dir.appendingPathComponent("big.txt")
        try Data(repeating: 0x41, count: 10).write(to: small)
        try Data(repeating: 0x42, count: 5000).write(to: big)

        let registry = ContentFieldRegistry()
        registry.register(BuiltinContentProvider())
        // "builtin.size > 1000" must keep only the big file.
        let matches = await registry.filter([small, big],
                                             matching: pred("builtin.size", .greater, "1000"))
        XCTAssertEqual(matches, [big])
        // "builtin.extension = txt" keeps both.
        let both = await registry.filter([small, big], matching: pred("builtin.extension", .equals, "txt"))
        XCTAssertEqual(Set(both), Set([small, big]))
    }

    // MARK: - Parser (F-157)

    func testParse_splitsFieldOpValue_longestOperatorFirst() {
        XCTAssertEqual(ContentFieldPredicate.parse("fileinfo.width > 1000"),
                       pred("fileinfo.width", .greater, "1000"))
        XCTAssertEqual(ContentFieldPredicate.parse("media.duration >= 10min"),
                       pred("media.duration", .greaterEqual, "10min"))
        XCTAssertEqual(ContentFieldPredicate.parse("tag != draft"), pred("tag", .notEquals, "draft"))
        XCTAssertEqual(ContentFieldPredicate.parse("name ~ report"), pred("name", .contains, "report"))
        XCTAssertEqual(ContentFieldPredicate.parse("a<=5"), pred("a", .lessEqual, "5"))
    }

    func testParse_rejectsMalformed() {
        XCTAssertNil(ContentFieldPredicate.parse("no operator here"))
        XCTAssertNil(ContentFieldPredicate.parse("> 5"))          // empty field
        XCTAssertNil(ContentFieldPredicate.parse("width >"))       // empty value
    }

    func testParseQuantity_units() {
        XCTAssertEqual(ContentFieldPredicate.parseQuantity("600"), 600)
        XCTAssertEqual(ContentFieldPredicate.parseQuantity("10min"), 600)
        XCTAssertEqual(ContentFieldPredicate.parseQuantity("2h"), 7200)
        XCTAssertEqual(ContentFieldPredicate.parseQuantity("5MB"), 5 * 1024 * 1024)
        XCTAssertEqual(ContentFieldPredicate.parseQuantity("3kb"), 3072)
        XCTAssertNil(ContentFieldPredicate.parseQuantity("abc"))
    }

    func testEvaluate_withUnit() {
        // A duration field of 900 seconds satisfies ">= 10min" (600s).
        XCTAssertTrue(pred("d", .greaterEqual, "10min").evaluate(.integer(900)))
        XCTAssertFalse(pred("d", .greater, "20min").evaluate(.integer(900)))
    }

    func testNumericComparisons() {
        XCTAssertTrue(pred("f.width", .greater, "1000").evaluate(.integer(1920)))
        XCTAssertFalse(pred("f.width", .greater, "1000").evaluate(.integer(640)))
        XCTAssertTrue(pred("f.width", .lessEqual, "640").evaluate(.integer(640)))
        XCTAssertTrue(pred("f.width", .equals, "640").evaluate(.integer(640)))
        XCTAssertTrue(pred("f.width", .notEquals, "1").evaluate(.integer(640)))
    }

    func testNumericOpOnNonNumericIsFalse() {
        XCTAssertFalse(pred("f.model", .greater, "10").evaluate(.string("RGB")))
        XCTAssertFalse(pred("f.width", .greater, "10").evaluate(.none))
    }

    func testStringEqualsAndContains() {
        XCTAssertTrue(pred("f.model", .equals, "rgb").evaluate(.string("RGB")))   // case-insensitive
        XCTAssertTrue(pred("f.dim", .contains, "800").evaluate(.string("800 × 600")))
        XCTAssertFalse(pred("f.dim", .contains, "999").evaluate(.string("800 × 600")))
    }

    func testNoneNeverMatches() {
        XCTAssertFalse(pred("f.x", .equals, "").evaluate(.none))
        XCTAssertFalse(pred("f.x", .contains, "anything").evaluate(.none))
    }

    // MARK: - Registry filter over fixture images

    private func makeDir() throws -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("pc-cfp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private func writePNG(_ dir: URL, _ name: String, _ w: Int, _ h: Int) throws -> URL {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let url = dir.appendingPathComponent(name)
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    func testFilterImagesByWidth() async throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let big = try writePNG(dir, "big.png", 1920, 1080)
        let small = try writePNG(dir, "small.png", 320, 240)
        let txt = dir.appendingPathComponent("note.txt")
        try Data("x".utf8).write(to: txt)

        let registry = ContentFieldRegistry()
        registry.register(ImageInfoContentProvider())
        let matches = await registry.filter([big, small, txt],
                                            matching: ContentFieldPredicate(qualifiedID: "fileinfo.width", op: .greater, value: "1000"))
        XCTAssertEqual(matches, [big])   // small excluded, non-image excluded
    }
}
