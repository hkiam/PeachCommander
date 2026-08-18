// SPDX-License-Identifier: Apache-2.0
// GitRepo.swift — running git, and remembering what it said.
//
// Extracted from git.swift when the panel arrived (F-416): the columns, the commands and the panel all
// need the same three things — which git, where is the repository, what is its status — and three copies
// of that would be three caches disagreeing with each other. The *decisions* (parsing, resolution
// policy, cache freshness) live in Plugins/SDK/PluginGit.swift and are unit-tested; this is the part that
// touches Process and the filesystem.

import Foundation

enum PluginGitRepo {

    // MARK: - Which git

    private static let gitLock = NSLock()
    private static var resolvedGit: String??   // nil = not looked for yet; .some(nil) = looked, not found

    /// The git to use, resolved once. `PCGitExecutable` in the environment overrides everything, which is
    /// what the automation harness sets.
    static func executable() -> String? {
        gitLock.lock()
        if let cached = resolvedGit { gitLock.unlock(); return cached }
        gitLock.unlock()
        let manager = FileManager.default
        let found = PluginGit.resolveExecutable(
            setting: ProcessInfo.processInfo.environment["PCGitExecutable"],
            isExecutable: { manager.isExecutableFile(atPath: $0) },
            exists: { manager.fileExists(atPath: $0) })
        gitLock.lock(); resolvedGit = .some(found); gitLock.unlock()
        if found == nil {
            NSLog("[git plugin] no usable git found — the columns stay empty and the commands report it")
        }
        return found
    }

    // MARK: - Running

    /// Run git, capturing stdout (and stderr when `combined`, because git says useful things there).
    ///
    /// `GIT_TERMINAL_PROMPT=0` is the important one: a `push` that wants a password must fail and say so
    /// rather than wait forever on a terminal this process does not have.
    static func run(_ arguments: [String], combined: Bool = false) -> (out: String, ok: Bool) {
        guard let executable = executable() else { return (L("Git was not found on this Mac."), false) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = combined ? pipe : FileHandle.nullDevice
        do { try process.run() } catch { return (L("Git could not be started."), false) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (String(decoding: data, as: UTF8.self), process.terminationStatus == 0)
    }

    /// Run git and hand back raw bytes — for `show`, whose output is a file's content and may not be text.
    static func runData(_ arguments: [String]) -> Data? {
        guard let executable = executable() else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }

    // MARK: - Repository lookup and cache

    private struct CacheEntry {
        let status: PluginGit.RepoStatus
        let indexMTime: Date?
        let cachedAt: Date
    }

    private static let cacheLock = NSLock()
    /// directory -> (repo root, the directory's repo-relative prefix); nil = not a repository
    private static var locationByDirectory: [String: (root: String, prefix: String)?] = [:]
    private static var statusByRoot: [String: CacheEntry] = [:]
    /// repo root -> the *real* git directory, learned while locating (F-419).
    private static var gitDirByRoot: [String: String] = [:]

    /// The index's mtime, which is what tells the cache the repository moved.
    ///
    /// Via the git directory git itself reported, not `<root>/.git`: in a linked worktree `.git` is a
    /// *file*, so `<root>/.git/index` does not exist and this returned nil for every call — the cache then
    /// had nothing to compare and fell back to the age check alone, which is the difference between a
    /// column that follows a commit at once and one that follows it within the TTL (F-419).
    private static func indexMTime(root: String) -> Date? {
        cacheLock.lock()
        let gitDir = gitDirByRoot[root]
        cacheLock.unlock()
        let base = gitDir ?? (root as NSString).appendingPathComponent(".git")
        let path = (base as NSString).appendingPathComponent("index")
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return attributes?[.modificationDate] as? Date
    }

    /// The repository a directory belongs to and where inside it that directory sits, cached. One
    /// `rev-parse` per directory, not per file — and it answers both questions in the same call.
    static func locate(_ directory: String) -> (root: String, prefix: String)? {
        cacheLock.lock()
        if let cached = locationByDirectory[directory] { cacheLock.unlock(); return cached }
        cacheLock.unlock()
        let result = run(["-C", directory] + PluginGit.locateArgumentsWithGitDir)
        let found = result.ok ? PluginGit.parseLocateWithGitDir(result.out) : nil
        let location = found.map { (root: $0.root, prefix: $0.prefix) }
        cacheLock.lock()
        if locationByDirectory.count > 4096 { locationByDirectory.removeAll() }
        locationByDirectory[directory] = location
        if let found {
            if gitDirByRoot.count > 64 { gitDirByRoot.removeAll() }
            gitDirByRoot[found.root] = found.gitDir
        }
        cacheLock.unlock()
        return location
    }

    /// The repository's status, cached per root and refreshed when the index moved or the entry aged out.
    static func status(root: String) -> PluginGit.RepoStatus? {
        let mtime = indexMTime(root: root)
        cacheLock.lock()
        if let entry = statusByRoot[root],
           PluginGit.cacheIsFresh(cachedIndexMTime: entry.indexMTime, currentIndexMTime: mtime,
                                  cachedAt: entry.cachedAt, now: Date()) {
            cacheLock.unlock()
            return entry.status
        }
        cacheLock.unlock()
        let result = run(["-C", root] + PluginGit.statusArguments)
        guard result.ok else { return nil }
        let parsed = PluginGit.parseStatus(result.out)
        cacheLock.lock()
        if statusByRoot.count > 64 { statusByRoot.removeAll() }   // many repositories open: keep it bounded
        statusByRoot[root] = CacheEntry(status: parsed, indexMTime: mtime, cachedAt: Date())
        cacheLock.unlock()
        return parsed
    }

    static func invalidate() {
        cacheLock.lock()
        statusByRoot.removeAll(); locationByDirectory.removeAll(); gitDirByRoot.removeAll()
        cacheLock.unlock()
    }

    /// Repository root plus the item's repository-relative path, from git's own prefix.
    ///
    /// No comparing of paths: git answers with `/private/tmp/r` where the host says `/tmp/r`, and
    /// `resolvingSymlinksInPath` maps `/private/tmp` back to `/tmp`, so neither prefixes the other (see
    /// `PluginGit.relativePath`).
    static func item(_ path: String) -> (root: String, relative: String)? {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        let isDir = exists && isDirectory.boolValue
        let directory = isDir ? path : (path as NSString).deletingLastPathComponent
        guard let location = locate(directory) else { return nil }
        let relative = isDir
            ? PluginGit.relativePath(directoryPrefix: location.prefix)
            : PluginGit.relativePath(prefix: location.prefix, name: (path as NSString).lastPathComponent)
        return (location.root, relative)
    }

    // MARK: - Blobs

    /// An empty temp file, for the older side of a file this commit *added*: comparing against nothing is
    /// what the reference products show, and it is more honest than refusing to diff at all (F-417).
    static func writeEmptyBlob(path: String) -> String? {
        let token = String(UUID().uuidString.prefix(6))
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-git-blobs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(
            PluginGit.blobFileName(path: path, base: .index, token: "empty-" + token))
        do { try Data().write(to: url) } catch { return nil }
        return url.path
    }

    /// Write `git show <spec>` to a temp file and return its path, for the compare window (F-416).
    ///
    /// A file rather than a string because the host's compare window reads paths — and a *named* file,
    /// keeping the extension, so the window highlights it as the language it is and the reader sees which
    /// version they are looking at.
    static func writeBlob(root: String, spec: String, path: String, base: PluginGit.DiffBase) -> String? {
        guard let data = runData(["-C", root, "--no-optional-locks", "show", spec]) else { return nil }
        let token = String(UUID().uuidString.prefix(6))
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-git-blobs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(
            PluginGit.blobFileName(path: path, base: base, token: token))
        do { try data.write(to: url) } catch { return nil }
        return url.path
    }
}
