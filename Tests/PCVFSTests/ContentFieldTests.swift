import XCTest
import AppKit
@testable import PCVFS

final class ContentFieldTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-cf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func writePNG(_ name: String, _ w: Int, _ h: Int) throws -> URL {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let url = dir.appendingPathComponent(name)
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    func testContentValueDisplay() {
        XCTAssertEqual(ContentValue.integer(42).display, "42")
        XCTAssertEqual(ContentValue.string("hi").display, "hi")
        XCTAssertEqual(ContentValue.none.display, "")
    }

    func testRegistryResolvesImageFields() async throws {
        let registry = ContentFieldRegistry()
        registry.register(ImageInfoContentProvider())
        let url = try writePNG("p.png", 128, 64)
        let w = await registry.value(qualifiedID: "fileinfo.width", forFileAt: url)
        let h = await registry.value(qualifiedID: "fileinfo.height", forFileAt: url)
        let dim = await registry.value(qualifiedID: "fileinfo.dimensions", forFileAt: url)
        XCTAssertEqual(w, .integer(128))
        XCTAssertEqual(h, .integer(64))
        XCTAssertEqual(dim, .string("128 × 64"))
    }

    func testUnknownProviderOrFieldIsNone() async throws {
        let registry = ContentFieldRegistry()
        registry.register(ImageInfoContentProvider())
        let url = try writePNG("p.png", 10, 10)
        let unknownProvider = await registry.value(qualifiedID: "nope.width", forFileAt: url)
        let unknownField = await registry.value(qualifiedID: "fileinfo.bogus", forFileAt: url)
        let malformed = await registry.value(qualifiedID: "nodot", forFileAt: url)
        XCTAssertEqual(unknownProvider, .none)
        XCTAssertEqual(unknownField, .none)
        XCTAssertEqual(malformed, .none)
    }

    func testNonImageIsNone() async throws {
        let registry = ContentFieldRegistry()
        registry.register(ImageInfoContentProvider())
        let txt = dir.appendingPathComponent("a.txt")
        try Data("text".utf8).write(to: txt)
        let v = await registry.value(qualifiedID: "fileinfo.width", forFileAt: txt)
        XCTAssertEqual(v, .none)
    }

    func testAllQualifiedFields() {
        let registry = ContentFieldRegistry()
        registry.register(ImageInfoContentProvider())
        let ids = registry.allQualifiedFields().map(\.qualifiedID)
        XCTAssertEqual(Set(ids), ["fileinfo.width", "fileinfo.height", "fileinfo.dimensions", "fileinfo.colormodel"])
    }
}
