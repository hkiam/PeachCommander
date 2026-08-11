// SPDX-License-Identifier: Apache-2.0
// DeepPath.swift - Reaching files whose absolute path is longer than a syscall accepts (F-383).
//
// macOS caps a path *argument* at PATH_MAX, which is 1024 including the terminator. That is a limit on
// the argument, not on the file system: a tree can grow past it and routinely does, because each step
// that creates it only ever passes one short relative path. Measured on APFS — building a tree with
// absolute `mkdir` stops at 977 bytes with ENAMETOOLONG, while the same tree built by chdir-ing into
// each new folder reached 2560 bytes without complaint. Everything in it is real, listable by `ls` from
// inside, and invisible to any call that names it from the root: `stat` on the 2560-byte absolute path
// fails ENAMETOOLONG, `fstatat` on the same file relative to a directory descriptor returns its size.
//
// That is the whole fix. Walk the path one component at a time, so the kernel never sees more than one
// name per call, and do the real work with the `*at()` variant against the descriptor that walk ends on.
//
// Two design points worth stating:
//
//   * **Short paths keep the plain calls.** `isDeep` is a byte count, and everything under the limit
//     goes down exactly the code path it went down before — no extra opens, no behaviour to re-verify.
//     The walk costs one syscall per component, which is the wrong trade for the 99.99% case.
//   * **A walk is not the same as resolving the path.** `..` and symlinks are handed to `openat` and
//     mean what the kernel says they mean, rather than being normalised here first. Normalising in
//     user space is how a path that points outside the tree it appears to be in gets followed anyway.

import Foundation

enum DeepPath {
    /// The longest path a syscall argument may be. PATH_MAX counts the terminator, so the last usable
    /// length is one less.
    static let syscallLimit = Int(PATH_MAX) - 1

    /// Whether `path` has to be walked rather than passed to a syscall whole. Bytes, not characters:
    /// the kernel counts UTF-8, and a path of 400 emoji is over the limit while looking short.
    static func isDeep(_ path: String) -> Bool { path.utf8.count > syscallLimit }

    /// A descriptor for the directory at `path`, or -1 with `errno` set.
    ///
    /// The caller owns the descriptor and must close it.
    static func openDirectory(_ path: String) -> Int32 {
        var fd: Int32
        var components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if path.hasPrefix("/") {
            fd = open("/", O_RDONLY | O_DIRECTORY)
        } else {
            fd = openat(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY)
        }
        guard fd >= 0 else { return -1 }

        while !components.isEmpty {
            let component = components.removeFirst()
            let next = openat(fd, component, O_RDONLY | O_DIRECTORY)
            let failure = errno
            close(fd)
            guard next >= 0 else {
                errno = failure
                return -1
            }
            fd = next
        }
        return fd
    }

    /// Runs `body` with a descriptor for `path`'s parent directory and the final component's name,
    /// closing the descriptor afterwards. Returns nil — with `errno` set — when the parent cannot be
    /// opened, which is the only failure this can have of its own.
    ///
    /// The pair is what every `*at()` call wants, and it is also what makes `renameat` possible at
    /// depth: two of these, one per side.
    static func withParent<T>(of path: String, _ body: (Int32, String) throws -> T) rethrows -> T? {
        let parent = (path as NSString).deletingLastPathComponent
        let name = (path as NSString).lastPathComponent
        guard !name.isEmpty else { errno = EINVAL; return nil }
        let fd = openDirectory(parent.isEmpty ? "/" : parent)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        return try body(fd, name)
    }

    /// Creates `path` and any missing parent directories, walking as it goes so no single call sees
    /// the whole path. Mirrors `createDirectory(withIntermediateDirectories: true)`: an existing
    /// directory is success, an existing *file* in the way is not.
    static func createDirectory(_ path: String, mode: mode_t = 0o755) -> Bool {
        var fd = path.hasPrefix("/") ? open("/", O_RDONLY | O_DIRECTORY)
                                     : openat(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        for component in path.split(separator: "/", omittingEmptySubsequences: true).map(String.init) {
            if mkdirat(fd, component, mode) != 0 && errno != EEXIST { return false }
            let next = openat(fd, component, O_RDONLY | O_DIRECTORY)
            guard next >= 0 else { return false }   // an existing non-directory lands here as ENOTDIR
            close(fd)
            fd = next
        }
        return true
    }

    /// Removes `name` under `directory`, emptying it first when it is a directory. `errno` is left
    /// from the call that failed.
    ///
    /// Recursion carries the descriptor rather than a path, which is the point: a tree deep enough to
    /// need this cannot be deleted by naming its leaves.
    static func removeRecursively(_ name: String, in directory: Int32) -> Bool {
        var info = stat()
        guard fstatat(directory, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { return false }
        guard (info.st_mode & S_IFMT) == S_IFDIR else {
            return unlinkat(directory, name, 0) == 0
        }

        let child = openat(directory, name, O_RDONLY | O_DIRECTORY)
        guard child >= 0 else { return false }
        // fdopendir takes ownership of `child`: closedir releases it, and closing it here as well
        // would be a double close onto whatever descriptor number got reused in between.
        guard let stream = fdopendir(child) else {
            let failure = errno
            close(child)
            errno = failure
            return false
        }
        var ok = true
        while let entry = readdir(stream) {
            let child = withUnsafeBytes(of: entry.pointee.d_name) { raw in
                String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
            }
            if child == "." || child == ".." { continue }
            if !removeRecursively(child, in: dirfd(stream)) { ok = false; break }
        }
        let failure = errno
        closedir(stream)
        guard ok else { errno = failure; return false }
        return unlinkat(directory, name, AT_REMOVEDIR) == 0
    }
}
