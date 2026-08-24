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
    // MARK: - A plugin's own view

    // The fourth renderer, and the only one that is not a fixed set of extensions: whichever formats
    // the installed lister plugins claim. Markdown and HTML arrive this way now that the application
    // renders neither itself.

    func testAClaimedFileGoesToThePlugin() {
        XCTAssertEqual(PreviewRoute.route(forExtension: "md", isImage: false, hasPlugin: true), .plugin)
        XCTAssertEqual(PreviewRoute.route(forExtension: "html", isImage: false, hasPlugin: true), .plugin)
        // Nothing claims it → QuickLook, exactly as before.
        XCTAssertEqual(PreviewRoute.route(forExtension: "md", isImage: false, hasPlugin: false), .quickLook)
    }

    func testTheInProcessReadersStillComeFirst() {
        // A plugin claiming .pdf does not take the PDF route away: PDFKit renders it in-process with
        // zoom, which is why that route exists at all.
        XCTAssertEqual(PreviewRoute.route(forExtension: "pdf", isImage: false, hasPlugin: true), .pdf)
        XCTAssertEqual(PreviewRoute.route(forExtension: "docx", isImage: false, hasPlugin: true), .rich)
        // And an image is an image whoever claims it.
        XCTAssertEqual(PreviewRoute.route(forExtension: "png", isImage: true, hasPlugin: true), .image)
    }

    func testTurningOffInAppDocumentsDoesNotTakePluginsWithIt() {
        // `Viewer.RenderDocumentsInApp` is about who renders PDFs and word-processor documents —
        // somebody who prefers the system's PDF reader has not asked to lose Markdown as well.
        XCTAssertEqual(PreviewRoute.route(forExtension: "md", isImage: false, hasPlugin: true,
                                          rendersDocumentsInApp: false), .plugin)
        XCTAssertEqual(PreviewRoute.route(forExtension: "pdf", isImage: false, hasPlugin: true,
                                          rendersDocumentsInApp: false), .quickLook)
    }
}
