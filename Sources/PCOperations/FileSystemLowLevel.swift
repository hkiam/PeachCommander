// SPDX-License-Identifier: Apache-2.0
// FileSystemLowLevel.swift - lstat-based helpers shared by the engines
//
// Uses lstat semantics throughout so symbolic links are treated as links, never
// silently followed (a safety requirement for recursive copy/delete).

import Foundation

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

    static func readSymlink(_ path: String) -> String? {
        var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
        let n = path.withCString { readlink($0, &buf, buf.count - 1) }
        guard n >= 0 else { return nil }
        buf[n] = 0
        return String(cString: buf)
    }

    private static func lstatPath(_ path: String, _ st: inout stat) -> Int32 {
        path.withCString { lstat($0, &st) }
    }
}
