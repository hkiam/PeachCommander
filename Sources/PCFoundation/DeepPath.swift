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

public enum DeepPath {
    /// The longest path a syscall argument may be. PATH_MAX counts the terminator, so the last usable
    /// length is one less.
    public static let syscallLimit = Int(PATH_MAX) - 1

    /// Whether `path` has to be walked rather than passed to a syscall whole. Bytes, not characters:
    /// the kernel counts UTF-8, and a path of 400 emoji is over the limit while looking short.
    public static func isDeep(_ path: String) -> Bool { path.utf8.count > syscallLimit }

    /// A descriptor for the directory at `path`, or -1 with `errno` set.
    ///
    /// The caller owns the descriptor and must close it.
    public static func openDirectory(_ path: String) -> Int32 {
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
    public static func withParent<T>(of path: String, _ body: (Int32, String) throws -> T) rethrows -> T? {
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
    public static func createDirectory(_ path: String, mode: mode_t = 0o755) -> Bool {
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
    public static func removeRecursively(_ name: String, in directory: Int32) -> Bool {
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

// MARK: - Path-transparent primitives
//
// Each of these is the plain syscall for a path a syscall accepts, and the descriptor walk otherwise.
// The engines above them keep working in Strings, which is what makes this affordable: the alternative
// was threading descriptors through the copy, move and delete recursion, and those already carry
// overwrite decisions, progress and cancellation.
//
// The fast path is not an optimisation detail, it is what keeps the change reviewable — every ordinary
// copy on the machine still runs the exact instructions it ran before.

extension DeepPath {
    /// `open`, or `openat` relative to the parent's descriptor. -1 with `errno` set, like `open`.
    public static func open(_ path: String, _ flags: Int32, _ mode: mode_t = 0) -> Int32 {
        guard isDeep(path) else { return path.withCString { Darwin.open($0, flags, mode) } }
        return withParent(of: path) { fd, name in
            name.withCString { openat(fd, $0, flags, mode) }
        } ?? -1
    }

    /// `lstat`. Symlinks are not followed, matching the callers that use it to decide what a thing is.
    public static func lstat(_ path: String, _ info: inout stat) -> Int32 {
        guard isDeep(path) else { return Darwin.lstat(path, &info) }
        var out = stat()
        let rc = withParent(of: path) { fd, name in
            fstatat(fd, name, &out, AT_SYMLINK_NOFOLLOW)
        } ?? -1
        if rc == 0 { info = out }
        return rc
    }

    /// `stat`, i.e. following symlinks. Not named `stat`: that is a struct as well as a function in
    /// Darwin, and a static member of the same name shadows the type for every `stat()` in the enum.
    public static func statFollowingSymlinks(_ path: String, _ info: inout stat) -> Int32 {
        // `fstatat(AT_FDCWD, …, 0)` rather than `stat(…)`: the bare name resolves to the struct's
        // initialiser here, and this is the same call with no ambiguity to work around.
        guard isDeep(path) else { return fstatat(AT_FDCWD, path, &info, 0) }
        var out = stat()
        let rc = withParent(of: path) { fd, name in
            fstatat(fd, name, &out, 0)
        } ?? -1
        if rc == 0 { info = out }
        return rc
    }

    /// `mkdir` of the final component only; parents must exist. `createDirectory` is the recursive one.
    public static func mkdir(_ path: String, _ mode: mode_t) -> Int32 {
        guard isDeep(path) else { return path.withCString { Darwin.mkdir($0, mode) } }
        return withParent(of: path) { fd, name in mkdirat(fd, name, mode) } ?? -1
    }

    public static func unlink(_ path: String) -> Int32 {
        guard isDeep(path) else { return path.withCString { Darwin.unlink($0) } }
        return withParent(of: path) { fd, name in unlinkat(fd, name, 0) } ?? -1
    }

    /// Creates a symlink at `path` pointing at `target`. Only `path` is walked: the target is stored as
    /// the bytes given and is never resolved here, so its length is the file system's business.
    public static func symlink(_ target: String, at path: String) -> Int32 {
        guard isDeep(path) else {
            return target.withCString { t in path.withCString { p in Darwin.symlink(t, p) } }
        }
        return withParent(of: path) { fd, name in
            target.withCString { t in name.withCString { n in symlinkat(t, fd, n) } }
        } ?? -1
    }

    public static func readSymlink(_ path: String) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let n: Int
        if isDeep(path) {
            n = withParent(of: path) { fd, name in
                name.withCString { readlinkat(fd, $0, &buffer, buffer.count - 1) }
            } ?? -1
        } else {
            n = path.withCString { Darwin.readlink($0, &buffer, buffer.count - 1) }
        }
        guard n >= 0 else { return nil }
        buffer[n] = 0
        return String(cString: buffer)
    }

    /// `clonefile`, the same-volume instant copy. Either side may be deep, so both are walked when
    /// needed — `clonefileat` takes a descriptor per side exactly like `renameat`.
    public static func clone(_ source: String, to destination: String) -> Int32 {
        guard isDeep(source) || isDeep(destination) else {
            return source.withCString { s in destination.withCString { d in clonefile(s, d, 0) } }
        }
        let rc = withParent(of: source) { srcFd, srcName in
            withParent(of: destination) { dstFd, dstName in
                srcName.withCString { s in
                    dstName.withCString { d in clonefileat(srcFd, s, dstFd, d, 0) }
                }
            }
        }
        // A nil from either walk means the parent could not be opened; errno is already set.
        guard let inner = rc, let value = inner else { return -1 }
        return value
    }

    /// Copies metadata onto an existing target (`COPYFILE_METADATA`).
    ///
    /// There is no `copyfileat`, so the deep case goes through `fcopyfile` between two descriptors.
    /// The target is opened for writing where that is possible and read-only where it is not: a
    /// directory cannot be opened O_WRONLY at all, and directories are copied too.
    @discardableResult
    public static func copyMetadata(from source: String, to destination: String) -> Int32 {
        guard isDeep(source) || isDeep(destination) else {
            return source.withCString { s in
                destination.withCString { d in
                    copyfile(s, d, nil, copyfile_flags_t(COPYFILE_METADATA))
                }
            }
        }
        let from = open(source, O_RDONLY)
        guard from >= 0 else { return -1 }
        defer { close(from) }
        var to = open(destination, O_WRONLY)
        if to < 0 { to = open(destination, O_RDONLY) }
        guard to >= 0 else { return -1 }
        defer { close(to) }
        return fcopyfile(from, to, nil, copyfile_flags_t(COPYFILE_METADATA))
    }

    /// The names in `path`, without "." and "..". nil when it cannot be opened or read.
    public static func contentsOfDirectory(_ path: String) -> [String]? {
        guard isDeep(path) else {
            return try? FileManager.default.contentsOfDirectory(atPath: path)
        }
        let fd = openDirectory(path)
        guard fd >= 0 else { return nil }
        guard let handle = fdopendir(fd) else {
            let failure = errno
            close(fd)
            errno = failure
            return nil
        }
        defer { closedir(handle) }   // owns fd
        var names: [String] = []
        while let entry = readdir(handle) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { raw in
                String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
            }
            if name == "." || name == ".." { continue }
            names.append(name)
        }
        return names
    }

    /// Removes `path`, emptying it first when it is a directory.
    public static func removeItem(_ path: String) -> Bool {
        guard isDeep(path) else {
            return (try? FileManager.default.removeItem(atPath: path)) != nil
        }
        return withParent(of: path) { fd, name in
            removeRecursively(name, in: fd)
        } ?? false
    }

    /// `rename`. Either side may be deep — `renameat` takes a descriptor per side.
    public static func rename(_ source: String, to destination: String) -> Int32 {
        guard isDeep(source) || isDeep(destination) else {
            return source.withCString { s in destination.withCString { d in Darwin.rename(s, d) } }
        }
        let rc = withParent(of: source) { srcFd, srcName in
            withParent(of: destination) { dstFd, dstName in
                renameat(srcFd, srcName, dstFd, dstName)
            }
        }
        guard let inner = rc, let value = inner else { return -1 }
        return value
    }

    /// Removes an empty directory.
    public static func rmdir(_ path: String) -> Int32 {
        guard isDeep(path) else { return path.withCString { Darwin.rmdir($0) } }
        return withParent(of: path) { fd, name in unlinkat(fd, name, AT_REMOVEDIR) } ?? -1
    }

    /// Whether anything exists at `path`, symlinks not followed.
    public static func exists(_ path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) == 0
    }
}
