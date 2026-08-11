// SPDX-License-Identifier: Apache-2.0
// FileStamp.swift - "Is this the same file it was?" for a file the panel is reading through (F-384).
//
// Watching a *directory* answers "did the listing change". Watching a file the panel depends on — the
// .zip whose interior is on screen — is a different question, and mtime alone answers it badly: the
// usual way a program rewrites an archive is to write a temporary file and rename it over the old one,
// which produces a new inode, and a rename preserves the source file's mtime. Two rewrites within the
// same coarse mtime, or a restore from a backup, then look identical.
//
// So the stamp is size, mtime and inode together. Any of the three moving means the bytes the panel
// parsed are not the bytes on disk any more.

import Foundation
import PCFoundation

/// Enough of a file's identity to tell a rewrite from an untouched file.
public struct FileStamp: Equatable, Sendable {
    public let size: Int64
    public let modified: TimeInterval
    public let inode: UInt64

    public init(size: Int64, modified: TimeInterval, inode: UInt64) {
        self.size = size
        self.modified = modified
        self.inode = inode
    }

    /// The stamp of the file at `path`, or nil when there is nothing there — which is itself a change
    /// worth distinguishing from "unchanged", and the caller must, because reloading a file that is
    /// gone is not the same as leaving the panel as it stands.
    public static func of(_ path: String) -> FileStamp? {
        var info = stat()
        guard DeepPath.lstat(path, &info) == 0 else { return nil }
        return FileStamp(
            size: Int64(info.st_size),
            modified: TimeInterval(info.st_mtimespec.tv_sec)
                + TimeInterval(info.st_mtimespec.tv_nsec) / 1_000_000_000,
            inode: UInt64(info.st_ino)
        )
    }
}
