// SPDX-License-Identifier: Apache-2.0
// ArchiveWriteSupport.swift - What can actually be added to this archive? (F-139)
//
// Copying into an archive worked for zip and for nothing else. The panel decides it is "in an archive"
// by asking whether the filesystem is an ArchiveFS — which also opens tar, 7z, rar, iso and the rest —
// so F5 into a .tar reached the zip rewriter, which asked ZipReader to read it, got nothing, and threw
// `unreadableArchive`. The archive was perfectly readable; it just was not a zip, and the message said
// the opposite of what was true.
//
// What each format can do was measured rather than taken from a manual page:
//
//   * uncompressed tar: `tar -rf` appends. Deleting needs `--delete`, which macOS's bsdtar answers with
//     "Option --delete is not supported" — GNU tar has it, the tar every Mac ships does not.
//   * tar.gz and friends: `tar -rf` says "Cannot append to compressed archive". There is no way in
//     without rewriting the whole stream, which is a different feature and not this one.
//   * 7z: `7z a` adds and `7z d` deletes, both in place — when the binary is installed at all, which on
//     a stock Mac it is not.
//   * zip: no cheap in-place edit, so ArchiveEditor rewrites it. That already worked.
//
// The point of naming the reason is the message: "this archive cannot be modified" is not something a
// user can act on, while "compressed tar archives cannot be added to" and "7z is not installed" are.

import Foundation

public enum ArchiveWriteSupport {

    /// Why an archive cannot be added to.
    public enum Reason: Sendable, Equatable {
        /// A compressed tar stream — appending would mean rewriting the whole thing.
        case compressedStream
        /// The external tool this format needs is not installed.
        case toolMissing(String)
        /// Not a format this app knows how to write into (rar, iso, cpio, …).
        case formatNotWritable(String)
    }

    /// How to add to an archive, or why not.
    public enum Capability: Sendable, Equatable {
        /// Read every entry and re-emit the archive (zip).
        case rewrite
        /// Append with `tar -rf` (uncompressed tar only).
        case appendTar(tool: String)
        /// `7z a`.
        case sevenZip(tool: String)
        case unsupported(Reason)
    }

    /// What can be done to the archive at `path`.
    ///
    /// Decided by the file name, like the pack dialog and the archive reader already do. `.tar.gz` and
    /// `.tgz` have to be recognised before `.gz`, and before the bare `.tar` check, or a two-part
    /// suffix is read as its last part alone.
    public static func capability(forArchiveAt path: String,
                                  toolPath: (String) -> String? = { PackEngine.toolPath($0) }) -> Capability {
        let name = (path as NSString).lastPathComponent.lowercased()

        if name.hasSuffix(".zip") { return .rewrite }

        for suffix in [".tar.gz", ".tgz", ".tar.bz2", ".tbz", ".tbz2", ".tar.xz", ".txz", ".tar.zst"]
        where name.hasSuffix(suffix) {
            return .unsupported(.compressedStream)
        }

        if name.hasSuffix(".tar") {
            guard let tar = toolPath("tar") else { return .unsupported(.toolMissing("tar")) }
            return .appendTar(tool: tar)
        }

        if name.hasSuffix(".7z") {
            guard let sevenZip = toolPath("7z") ?? toolPath("7za") else {
                return .unsupported(.toolMissing("7z"))
            }
            return .sevenZip(tool: sevenZip)
        }

        let ext = (name as NSString).pathExtension
        return .unsupported(.formatNotWritable(ext.isEmpty ? name : ext))
    }

    /// Can anything be added to this archive at all?
    public static func canAdd(toArchiveAt path: String,
                              toolPath: (String) -> String? = { PackEngine.toolPath($0) }) -> Bool {
        if case .unsupported = capability(forArchiveAt: path, toolPath: toolPath) { return false }
        return true
    }
}
