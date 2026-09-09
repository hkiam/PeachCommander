// SPDX-License-Identifier: Apache-2.0
// TrashedItem.swift - What a trashing actually did, per item.
//
// `FileManager.trashItem(at:resultingItemURL:)` and `NSWorkspace.recycle(_:completionHandler:)` both
// report where each item ended up, and every call site in this project passed `nil` or dropped the
// mapping. That made one sentence the app repeats — a deleted file is in the Trash and can be put
// back from the Finder — true and unusable: nobody can pick this operation's items out of several
// hundred in there.
//
// It is not a convenience either. The Trash renames on collision, so a second `notes.txt` lands as
// `notes.txt 11-17-15-028.txt`; anything derived from the Trash plus the file's own name points at
// *the earlier file*. Measured. So the reported path is the only reliable answer, and it has to
// travel with the operation's result rather than be reconstructed later.

import Foundation

/// One item a trashing moved, and where it went.
public struct TrashedItem: Sendable, Equatable {
    /// Where it was.
    public let originalPath: String
    /// Where it is now — nil when the system did not say, which is the only honest value for a
    /// caller that cannot then offer to put it back.
    public let trashedPath: String?

    public init(originalPath: String, trashedPath: String?) {
        self.originalPath = originalPath
        self.trashedPath = trashedPath
    }

    /// Whether this item could be put back at all: it has to have gone somewhere known.
    public var isRestorable: Bool { trashedPath != nil }
}
