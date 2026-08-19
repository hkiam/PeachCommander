// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class PreviewRouteTests: XCTestCase {
    func testTheTwoFormatsAFileManagerIsAskedAboutMostAreRenderedInProcess() {
        XCTAssertEqual(PreviewRoute.route(forExtension: "pdf", isImage: false), .pdf)
        XCTAssertEqual(PreviewRoute.route(forExtension: "PDF", isImage: false), .pdf, "case is not meaning")
        XCTAssertEqual(PreviewRoute.route(forExtension: "docx", isImage: false), .rich)
        XCTAssertEqual(PreviewRoute.route(forExtension: "odt", isImage: false), .rich)
        XCTAssertEqual(PreviewRoute.route(forExtension: "rtf", isImage: false), .rich)
    }

    /// The long tail stays with QuickLook, which is where it earns its keep.
    func testEverythingElseGoesToQuickLook() {
        for ext in ["key", "numbers", "mp4", "zip", "swift", "", "psd"] {
            XCTAssertEqual(PreviewRoute.route(forExtension: ext, isImage: false), .quickLook, ext)
        }
    }

    /// An image is an image even when its extension is also in another list — the caller has already asked
    /// the system, and that answer wins.
    func testImageWins() {
        XCTAssertEqual(PreviewRoute.route(forExtension: "png", isImage: true), .image)
        XCTAssertEqual(PreviewRoute.route(forExtension: "pdf", isImage: true), .image)
    }

    /// The setting sends documents back to Quick Look, and leaves images alone — their route predates it.
    func testTheSettingTurnsTheInProcessRoutesOff() {
        XCTAssertEqual(PreviewRoute.route(forExtension: "pdf", isImage: false,
                                          rendersDocumentsInApp: false), .quickLook)
        XCTAssertEqual(PreviewRoute.route(forExtension: "docx", isImage: false,
                                          rendersDocumentsInApp: false), .quickLook)
        XCTAssertEqual(PreviewRoute.route(forExtension: "png", isImage: true,
                                          rendersDocumentsInApp: false), .image)
        XCTAssertEqual(PreviewRoute.route(forExtension: "pdf", isImage: false), .pdf,
                       "on is the default: the reader gets the renderer that can be measured")
    }
}
