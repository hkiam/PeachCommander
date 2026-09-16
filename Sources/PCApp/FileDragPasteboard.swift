// SPDX-License-Identifier: Apache-2.0
// FileDragPasteboard.swift - Reading file paths out of a drag, in one place.
//
// The same four lines had been written three times — on the button bar, on its droppable buttons and
// on the panel list — and the workspace chip strip would have been the fourth (F-499). None of the
// copies was wrong, which is exactly why they were worth collecting: a drag-and-drop reader that is
// right in three places and subtly different in the fourth is a defect nobody goes looking for.

import AppKit

enum FileDragPasteboard {

    /// The file paths a drag is carrying, or an empty array when it carries something else.
    ///
    /// `urlReadingFileURLsOnly` is what keeps a dragged web link out: without it a URL from a browser
    /// arrives as a perfectly good `NSURL` and every drop target here would try to treat it as a file.
    static func paths(from sender: NSDraggingInfo) -> [String] {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return [] }
        return urls.map(\.path)
    }
}
