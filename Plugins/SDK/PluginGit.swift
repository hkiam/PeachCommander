// SPDX-License-Identifier: Apache-2.0
// PluginGit.swift - Reading git's machine-readable status, for the Git plugin.
//
// Split out of git.swift so the parsing and the executable-resolution *policy* can be unit-tested
// without a plugin bundle: pure functions over text, no Process, no filesystem (the one function that
// needs the filesystem takes the check as a closure). Compiled into the plugin bundle
// (Tools/build-git-plugin.sh) and into PCFoundationTests, the arrangement PluginCSV and
// PluginDecompiler already use.
//
// Two things were wrong with the first pass and both are fixed here rather than patched there:
//
//   * it parsed `git status --porcelain` (v1), which **quotes** any path outside ASCII —
//     `A  "Gr\303\266\303\237e.txt"` — and used the quoted text as a path, so the column stayed empty
//     for every file with an umlaut in its name. Measured in a scratch repository.
//   * v1 also collapses the index and the worktree into two letters without saying which is which in a
//     way a reader can use, so "staged" and "changed" could not be told apart — which the commit
//     command needs (it committed with `-a`, ignoring the index it had just been asked to add to).
//
// `--porcelain=v2 -z` answers both: NUL-separated records, raw bytes, and the staged/worktree split
// per file, plus the branch and the ahead/behind counts in the same call.

import Foundation

public enum PluginGit {

    /// What happened to a file, on one side (index or worktree).
    public enum Change: String, Sendable, Equatable {
        case unchanged, modified, added, deleted, renamed, copied, typeChanged, untracked, ignored, conflict
    }

    /// One file's status. `staged` is the index side, `worktree` the working-tree side; a file may be
    /// both (staged edit plus a further unstaged edit), which is why they are separate.
    public struct FileStatus: Sendable, Equatable {
        /// Repository-relative path, raw (no quoting, no escaping).
        public let path: String
        /// Where a rename or copy came from.
        public let originalPath: String?
        public let staged: Change
        public let worktree: Change

        public init(path: String, originalPath: String? = nil, staged: Change, worktree: Change) {
            self.path = path
            self.originalPath = originalPath
            self.staged = staged
            self.worktree = worktree
        }

        /// The one change worth putting in a column, worst-first: a conflict outranks a staged edit,
        /// which outranks an unstaged one.
        public var summary: Change {
            if staged == .conflict || worktree == .conflict { return .conflict }
            if worktree != .unchanged && worktree != .ignored { return worktree }
            if staged != .unchanged { return staged }
            return worktree
        }

        public var isStaged: Bool { staged != .unchanged && staged != .untracked && staged != .ignored }
    }

    /// A repository's state as one `status --porcelain=v2 --branch -z` call reports it.
    public struct RepoStatus: Sendable, Equatable {
        /// Branch name, or "" when detached or on an unborn branch.
        public let branch: String
        public let detached: Bool
        /// Tracking branch, when there is one.
        public let upstream: String?
        public let ahead: Int
        public let behind: Int
        /// Repository-relative path → status.
        public let files: [String: FileStatus]

        public init(branch: String, detached: Bool = false, upstream: String? = nil,
                    ahead: Int = 0, behind: Int = 0, files: [String: FileStatus] = [:]) {
            self.branch = branch; self.detached = detached; self.upstream = upstream
            self.ahead = ahead; self.behind = behind; self.files = files
        }

        /// Files in a stable order: conflicts first, then staged, then the rest, each alphabetically.
        public var ordered: [FileStatus] {
            files.values.sorted { a, b in
                func rank(_ f: FileStatus) -> Int {
                    if f.summary == .conflict { return 0 }
                    if f.isStaged { return 1 }
                    if f.summary == .untracked { return 3 }
                    return 2
                }
                return rank(a) == rank(b) ? a.path < b.path : rank(a) < rank(b)
            }
        }
    }

    // MARK: - Arguments

    /// The status call this parser expects. `--no-optional-locks` keeps a listing from writing to the
    /// repository at all: without it a plain `status` may refresh the index, which is a write to
    /// somebody else's working copy triggered by scrolling past it in a file manager.
    public static let statusArguments = [
        "--no-optional-locks", "status", "--porcelain=v2", "--branch", "-z",
        "--untracked-files=normal", "--ignore-submodules=none",
    ]

    // MARK: - Parsing

    /// Parse `git status --porcelain=v2 --branch -z` output.
    ///
    /// Records are NUL-separated. A rename/copy record ("2 ") carries *two* paths separated by a further
    /// NUL, so the record after it belongs to it — getting that wrong shifts every following path by one,
    /// which is the sort of defect that looks like "the column is wrong for some files".
    public static func parseStatus(_ output: String) -> RepoStatus {
        var branch = ""
        var detached = false
        var upstream: String?
        var ahead = 0, behind = 0
        var files: [String: FileStatus] = [:]

        let records = output.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)
        var index = 0
        while index < records.count {
            let record = records[index]
            index += 1
            guard let kind = record.first else { continue }
            switch kind {
            case "#":
                let parts = record.dropFirst(2).split(separator: " ", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { continue }
                switch parts[0] {
                case "branch.head":
                    if parts[1] == "(detached)" { detached = true } else { branch = parts[1] }
                case "branch.upstream":
                    upstream = parts[1]
                case "branch.ab":
                    for token in parts[1].split(separator: " ") {
                        if token.hasPrefix("+") { ahead = Int(token.dropFirst()) ?? 0 }
                        if token.hasPrefix("-") { behind = Int(token.dropFirst()) ?? 0 }
                    }
                default:
                    break
                }
            case "1", "2":
                // "1 XY sub mH mI mW hH hI path"  /  "2 XY sub mH mI mW hH hI Xscore path" + NUL + orig
                let fields = record.split(separator: " ", maxSplits: kind == "1" ? 8 : 9,
                                          omittingEmptySubsequences: false).map(String.init)
                guard fields.count >= (kind == "1" ? 9 : 10) else { continue }
                let xy = fields[1]
                let path = fields[kind == "1" ? 8 : 9]
                var original: String?
                if kind == "2", index < records.count {
                    original = records[index]
                    index += 1
                }
                let status = FileStatus(path: path, originalPath: original,
                                        staged: change(xy.first, isIndex: true),
                                        worktree: change(xy.dropFirst().first, isIndex: false))
                files[path] = status
            case "u":
                let fields = record.split(separator: " ", maxSplits: 10,
                                          omittingEmptySubsequences: false).map(String.init)
                guard fields.count >= 11 else { continue }
                files[fields[10]] = FileStatus(path: fields[10], staged: .conflict, worktree: .conflict)
            case "?", "!":
                let path = String(record.dropFirst(2))
                guard !path.isEmpty else { continue }
                let kindChange: Change = kind == "?" ? .untracked : .ignored
                files[path] = FileStatus(path: path, staged: .unchanged, worktree: kindChange)
            default:
                break
            }
        }
        return RepoStatus(branch: branch, detached: detached, upstream: upstream,
                          ahead: ahead, behind: behind, files: files)
    }

    /// One letter of a porcelain v2 XY pair.
    static func change(_ letter: Character?, isIndex: Bool) -> Change {
        switch letter {
        case ".": return .unchanged
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "T": return .typeChanged
        case "U": return .conflict
        default:  return .unchanged
        }
    }

    // MARK: - Which git

    /// Where to look for git, in order. The setting wins; a real git found on `PATH` beats the shim.
    ///
    /// `/usr/bin/git` on macOS is **not** git: it is a Command Line Tools shim, and on a machine without
    /// them, running it opens the installer dialog. A file manager must not do that because somebody
    /// scrolled through a folder, so the shim is used only when the tools are actually present — which is
    /// what `clueThatToolsExist` checks (`/Library/Developer/CommandLineTools/usr/bin/git`, or Xcode's own
    /// copy). Order and policy are here so they can be tested; the filesystem checks are the caller's.
    public static func executableCandidates(setting: String?) -> [String] {
        var out: [String] = []
        if let setting, !setting.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append(setting.trimmingCharacters(in: .whitespaces))
        }
        out += ["/opt/homebrew/bin/git", "/usr/local/bin/git",
                "/Library/Developer/CommandLineTools/usr/bin/git",
                "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
                "/usr/bin/git"]
        return out
    }

    /// Paths whose presence means `/usr/bin/git` will not open the installer.
    public static let toolchainClues = ["/Library/Developer/CommandLineTools/usr/bin/git",
                                        "/Applications/Xcode.app/Contents/Developer/usr/bin/git"]

    /// Resolve git from the candidates. `isExecutable` and `exists` are injected so this is testable.
    public static func resolveExecutable(setting: String?,
                                        isExecutable: (String) -> Bool,
                                        exists: (String) -> Bool = { _ in false }) -> String? {
        for candidate in executableCandidates(setting: setting) {
            guard isExecutable(candidate) else { continue }
            if candidate == "/usr/bin/git", !toolchainClues.contains(where: exists) {
                continue   // the shim without the tools behind it: skip rather than trigger the installer
            }
            return candidate
        }
        return nil
    }

    // MARK: - Paths

    /// The `rev-parse` that answers both questions about a directory at once: which repository it belongs
    /// to, and where inside that repository it sits.
    public static let locateArguments = ["rev-parse", "--show-toplevel", "--show-prefix"]

    /// Parse `rev-parse --show-toplevel --show-prefix` output into the root and the directory's
    /// repository-relative prefix (`""` at the top, `"src/"` one level down).
    public static func parseLocate(_ output: String) -> (root: String, prefix: String)? {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let root = lines.first, !root.isEmpty else { return nil }
        let prefix = lines.count > 1 ? lines[1] : ""
        return (root, prefix)
    }

    /// A file's repository-relative path, from git's own prefix plus the file's name.
    ///
    /// Deliberately *not* computed by comparing the host's path with git's root. That was the first
    /// attempt and it is wrong on macOS in both directions: `rev-parse --show-toplevel` answers
    /// `/private/tmp/r` while the host hands over `/tmp/r`, and `NSString.resolvingSymlinksInPath` — the
    /// obvious repair — maps `/private/tmp` *back* to `/tmp`, so neither string can be relied on to
    /// prefix the other. Measured: with the "resolve then compare" version the status column stayed empty
    /// for a repository under `/tmp` while the branch column, which needs no relative path, worked. Asking
    /// git costs nothing extra, since the same call already had to find the root.
    public static func relativePath(prefix: String, name: String) -> String {
        var directory = prefix
        while directory.hasPrefix("/") { directory.removeFirst() }
        if directory.isEmpty { return name }
        if !directory.hasSuffix("/") { directory += "/" }
        return directory + name
    }

    /// A directory's own repository-relative path (its prefix without the trailing slash).
    public static func relativePath(directoryPrefix: String) -> String {
        var path = directoryPrefix
        while path.hasSuffix("/") { path.removeLast() }
        while path.hasPrefix("/") { path.removeFirst() }
        return path
    }

    // MARK: - Cache freshness

    /// Whether a cached status may still be used.
    ///
    /// Two questions, because two different things change a repository: the **index** (staging, commits,
    /// checkouts — `.git/index`'s mtime moves) and the **working tree** (an editor saving a file, which
    /// touches nothing git owns). The first is exact; for the second there is nothing to watch that is
    /// cheaper than `status` itself, so the entry also expires after `ttl`. The host reloads a listing on
    /// a filesystem event anyway, so the practical effect is that the column follows an edit at the next
    /// refresh rather than instantly — and a repository nobody is touching costs one `stat`.
    public static func cacheIsFresh(cachedIndexMTime: Date?, currentIndexMTime: Date?,
                                    cachedAt: Date, now: Date, ttl: TimeInterval = 3) -> Bool {
        if cachedIndexMTime != currentIndexMTime { return false }
        return now.timeIntervalSince(cachedAt) < ttl
    }
}
