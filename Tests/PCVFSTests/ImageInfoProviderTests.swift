import XCTest
import AppKit
@testable import PCVFS

final class ImageInfoProviderTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-img-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    /// Write a solid-color PNG of the given pixel size.
    private func writePNG(_ name: String, width: Int, height: Int) throws -> URL {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let data = rep.representation(using: .png, properties: [:])!
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    func testReadsPixelDimensions() throws {
        let url = try writePNG("pic.png", width: 40, height: 30)
        let info = ImageInfoProvider.info(at: url)
        XCTAssertEqual(info?.pixelWidth, 40)
        XCTAssertEqual(info?.pixelHeight, 30)
        XCTAssertEqual(info?.dimensionsText, "40 × 30")
        XCTAssertEqual(info?.colorModel, "RGB")
    }

    func testNonImageReturnsNil() throws {
        let url = dir.appendingPathComponent("notimage.txt")
        try Data("just text, not an image".utf8).write(to: url)
        XCTAssertNil(ImageInfoProvider.info(at: url))
    }

    func testMissingFileReturnsNil() {
        XCTAssertNil(ImageInfoProvider.info(at: dir.appendingPathComponent("ghost.png")))
    }
}
