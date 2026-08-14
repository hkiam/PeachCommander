// SPDX-License-Identifier: Apache-2.0
// FileSystemLowLevel.swift - lstat-based helpers shared by the engines
//
// Uses lstat semantics throughout so symbolic links are treated as links, never
// silently followed (a safety requirement for recursive copy/delete).

import Foundation
import PCFoundation

enum FSKind: Equatable {
    case file
    case directory
    case symlink
}

enum FSLowLevel {
    /// Kind of the item at `path` (does not follow symlinks). nil if it does not exist.
    static func kind(of path: String) -> FSKind? {
        var st = stat()
        guard lstatPath(path, &st) == 0 else { return nil }
        let fmt = st.st_mode & S_IFMT
        if fmt == S_IFLNK { return .symlink }
        if fmt == S_IFDIR { return .directory }
        return .file
    }

    static func exists(_ path: String) -> Bool {
        var st = stat()
        return lstatPath(path, &st) == 0
    }

    static func size(of path: String) -> Int64 {
        var st = stat()
        guard lstatPath(path, &st) == 0 else { return 0 }
        return Int64(st.st_size)
    }

    static func facts(of path: String) -> FileFacts? {
        var st = stat()
        guard lstatPath(path, &st) == 0 else { return nil }
        let fmt = st.st_mode & S_IFMT
        let isDir = fmt == S_IFDIR
        let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec)
                         + TimeInterval(st.st_mtimespec.tv_nsec) / 1_000_000_000)
        return FileFacts(path: path,
                         name: (path as NSString).lastPathComponent,
                         size: Int64(st.st_size),
                         modified: mtime,
                         isDirectory: isDir)
    }

    /// Same-device check for two paths (for rename vs copy+delete, clone eligibility).
    static func sameDevice(_ a: String, _ b: String) -> Bool {
        var sa = stat(), sb = stat()
        let ra = lstatPath(a, &sa)
        // b may not exist yet; stat its parent directory instead.
        let bParent = (b as NSString).deletingLastPathComponent
        let rb = lstatPath(bParent.isEmpty ? "/" : bParent, &sb)
        guard ra == 0, rb == 0 else { return false }
        return sa.st_dev == sb.st_dev
    }

    /// Whether two paths name the same file on disk — asked of the filesystem, not of the strings.
    ///
    /// String comparison is not enough and being nearly right here costs the file: macOS is normally
    /// case-insensitive, `/a//b` and `/a/b` are the same place, `.` and `..` resolve, and a hard link
    /// is genuinely the same bytes under a second name. The device and inode pair is what the
    /// filesystem itself considers identity, so that is what is compared.
    ///
    /// `lstat`, not `stat`: a symlink pointing at the source is a *different* file that happens to
    /// lead there, and copying onto it should replace the link, not be refused.
    ///
    /// False when either path does not exist — the ordinary case of copying somewhere new.
    static func isSameFile(_ a: String, _ b: String) -> Bool {
        var sa = stat(), sb = stat()
        guard lstatPath(a, &sa) == 0, lstatPath(b, &sb) == 0 else { return false }
        return sa.st_dev == sb.st_dev && sa.st_ino == sb.st_ino
    }

    static func readSymlink(_ path: String) -> String? {
        DeepPath.readSymlink(path)
    }

    /// Routed through `DeepPath` so a path past PATH_MAX answers instead of reporting "does not
    /// exist" — which is what an lstat failure reads as to every caller above (F-383).
    private static func lstatPath(_ path: String, _ st: inout stat) -> Int32 {
        DeepPath.lstat(path, &st)
    }
}
