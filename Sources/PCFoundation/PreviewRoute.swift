// SPDX-License-Identifier: Apache-2.0
// PreviewRoute.swift — which renderer a preview uses for a file (F-429).
//
// The preview panel used to hand everything except images to `QLPreviewView`, and QuickLook renders
// out-of-process: it either shows the document or it does not, and nothing inside the application can tell
// which — no pixel of it is in our layer tree, so `cacheDisplay` sees a blank rectangle either way. That is
// tolerable for the long tail of formats and wrong for the two a file manager is asked about most, PDF and
// word-processor documents, because when a reader says "it does not render any more" there is no way to
// agree or disagree with them.
//
// So the common ones are rendered in-process — PDFKit for PDF, AppKit's own document reader for
// docx/odt/rtf — which also gives them the zoom the image route already had, and makes both *checkable*
// from the harness. QuickLook keeps everything else, where it earns its keep.
//
// The decision itself lives here, away from any view, because it is a fact about a file name and the only
// part of this worth a test.

import Foundation

public enum PreviewRoute: String, Sendable, Equatable {
    /// Our own image view, with zoom (F-389).
    case image
    /// PDFKit, with zoom and page navigation.
    case pdf
    /// AppKit reads the document into an attributed string: .docx, .odt, .rtf, .rtfd, .doc.
    case rich
    /// Everything else — QuickLook, which handles the long tail.
    case quickLook

    /// Extensions AppKit's document reader handles well enough to show as formatted text.
    ///
    /// `.doc` is in the list and is the weakest of them: AppKit reads the old binary Word format only
    /// sometimes, so the route falls back to QuickLook when the read fails. That fallback is the reason this
    /// list may be generous.
    public static let richExtensions: Set<String> = ["docx", "odt", "rtf", "rtfd", "doc", "wordml"]

    public static let pdfExtensions: Set<String> = ["pdf"]

    /// The route for a path, given whether the system considers it an image and whether the reader wants
    /// documents rendered in the application at all.
    ///
    /// `isImage` is passed in rather than computed: it needs UniformTypeIdentifiers, which belongs to the
    /// caller's layer, and keeping it out makes this a pure function of its arguments.
    ///
    /// `rendersDocumentsInApp` is the `Viewer.RenderDocumentsInApp` setting. Off, PDFs and documents go back
    /// to Quick Look — which is what somebody wants who trusts the system's preview more than ours, or who
    /// has a Quick Look extension for a format AppKit reads worse. Images are unaffected either way: their
    /// own route predates this and is not what the switch is about.
    public static func route(forExtension ext: String, isImage: Bool,
                            rendersDocumentsInApp: Bool = true) -> PreviewRoute {
        let lower = ext.lowercased()
        if isImage { return .image }
        guard rendersDocumentsInApp else { return .quickLook }
        if pdfExtensions.contains(lower) { return .pdf }
        if richExtensions.contains(lower) { return .rich }
        return .quickLook
    }
}
