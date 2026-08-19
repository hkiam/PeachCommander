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
    public enum Change: String, Sendable, Equatable, CaseIterable {
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

    // MARK: - The panel's model (phase 1)

    /// The three groups the panel shows, in the order a reader works through them.
    public enum Section: String, Sendable, CaseIterable {
        case conflicts, staged, changed, untracked
    }

    /// Which section a file belongs in. A file can be in *two* states at once — staged edit plus a
    /// further unstaged edit — and it is then listed in both, because staging it again and committing
    /// what is staged are different actions on the same file.
    public static func sections(for file: FileStatus) -> [Section] {
        if file.summary == .conflict { return [.conflicts] }
        var out: [Section] = []
        if file.isStaged { out.append(.staged) }
        switch file.worktree {
        case .untracked: out.append(.untracked)
        case .ignored:   break
        case .unchanged: break
        default:         out.append(.changed)
        }
        return out
    }

    /// The panel's grouping: section → files, each alphabetically, ignored files left out.
    public static func grouped(_ status: RepoStatus) -> [(section: Section, files: [FileStatus])] {
        var out: [(Section, [FileStatus])] = []
        for section in Section.allCases {
            let files = status.files.values
                .filter { sections(for: $0).contains(section) }
                .sorted { $0.path < $1.path }
            if !files.isEmpty { out.append((section, files)) }
        }
        return out
    }

    /// What the panel's diff means for a file, and therefore which two things to compare.
    ///
    /// Staged: the index against HEAD. Unstaged: the working file against the index. Untracked: there is
    /// nothing to compare it with, and offering an empty left side would be a worse answer than refusing.
    public enum DiffBase: String, Sendable, Equatable { case head, index, none }

    public static func diffBase(for file: FileStatus, section: Section) -> DiffBase {
        switch section {
        case .untracked: return .none
        case .staged:    return .head
        case .changed:   return .index
        case .conflicts: return .index
        }
    }

    /// `git show` argument for one side of that comparison — `HEAD:path` or `:path` (the index).
    public static func showSpec(base: DiffBase, path: String) -> String? {
        switch base {
        case .head:  return "HEAD:" + path
        case .index: return ":" + path
        case .none:  return nil
        }
    }

    /// The column title for the left (git) side of the compare window, so the reader knows what they are
    /// looking at rather than the temp file's name.
    public static func diffTitle(base: DiffBase, path: String) -> String {
        switch base {
        case .head:  return "HEAD:" + path
        case .index: return "index:" + path
        case .none:  return path
        }
    }

    /// A temp file name for a blob: recognisable, collision-free, and it keeps the extension so the
    /// compare window highlights it as the language it is.
    public static func blobFileName(path: String, base: DiffBase, token: String) -> String {
        let name = (path as NSString).lastPathComponent
        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let tag = base == .head ? "HEAD" : "index"
        let leaf = "\(stem)@\(tag)-\(token)"
        return ext.isEmpty ? leaf : leaf + "." + ext
    }

    // MARK: - History (phase 2)

    /// One commit, as `parseLog` reads it.
    /// One name pointing at a commit: a local branch, a remote-tracking branch or a tag. `head` is the
    /// branch HEAD is on, which git prints as "HEAD -> main" and a reader wants to see marked (F-425).
    public struct Ref: Sendable, Equatable {
        public enum Kind: String, Sendable, Equatable { case head, branch, remote, tag }
        public let name: String
        public let kind: Kind
        public init(name: String, kind: Kind) { self.name = name; self.kind = kind }
    }

    public struct Commit: Sendable, Equatable {
        public let hash: String
        public let shortHash: String
        public let parents: [String]
        public let author: String
        public let date: Date
        public let subject: String
        /// Branch, remote-branch and tag names pointing at this commit, in git's own order (F-425).
        ///
        /// A history without these does not answer the question it is usually opened for — *where* is
        /// `main`, what did the release tag point at — and every reference product shows them.
        public var refs: [Ref] = []

        public init(hash: String, shortHash: String, parents: [String], author: String,
                    date: Date, subject: String) {
            self.hash = hash; self.shortHash = shortHash; self.parents = parents
            self.author = author; self.date = date; self.subject = subject
        }

        public var isMerge: Bool { parents.count > 1 }
    }

    /// Field and record separators: ASCII US (0x1F) and RS (0x1E). Chosen because a commit subject may
    /// contain anything a human types — tabs, quotes, newlines, pipes — and every one of those has been
    /// used as a separator by somebody's log parser that then broke on a real repository.
    static let unitSeparator = "\u{1F}"
    static let recordSeparator = "\u{1E}"

    /// `git log` arguments for `parseLog`. `path` limits the history to one file (its file history).
    public static func logArguments(limit: Int, path: String? = nil) -> [String] {
        // `--topo-order`, not git's default date order: with date order a parent can be listed *before*
        // its child (a branch committed earlier than the commit it forked from), and then the lane waiting
        // for that parent never closes — the graph shows a branch running past the commit that ended it.
        // Measured on a repository with one merge; this is also why every graph viewer asks for topo order.
        // `%D` last, after the subject: a subject may contain anything, including our separators in
        // principle, but appending a field keeps every existing index where it was — the rename defect in
        // `parseStatus` was exactly a shifted field, and it is not worth repeating here (F-425).
        var out = ["--no-optional-locks", "log", "--topo-order", "--max-count=\(limit)",
                   "--format=%H\(unitSeparator)%h\(unitSeparator)%P\(unitSeparator)%an"
                   + "\(unitSeparator)%at\(unitSeparator)%s\(unitSeparator)%D\(recordSeparator)"]
        if let path, !path.isEmpty { out += ["--follow", "--", path] }
        return out
    }

    public static func parseLog(_ output: String) -> [Commit] {
        var commits: [Commit] = []
        for record in output.components(separatedBy: recordSeparator) {
            let fields = record.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: unitSeparator)
            guard fields.count >= 6, !fields[0].isEmpty else { continue }
            let parents = fields[2].split(separator: " ").map(String.init)
            let seconds = Double(fields[4]) ?? 0
            var commit = Commit(hash: fields[0], shortHash: fields[1], parents: parents,
                                author: fields[3], date: Date(timeIntervalSince1970: seconds),
                                subject: fields[5])
            // An older format (or a caller with its own) simply has no seventh field, and then there are
            // no refs — not a parse error.
            if fields.count >= 7 { commit.refs = parseRefs(fields[6]) }
            commits.append(commit)
        }
        return commits
    }

    // MARK: - The lane graph

    /// Where a commit sits in the graph, and which lanes are alive around it.
    ///
    /// `lanes` is what each lane is *waiting for* when the row is drawn — a commit hash, or nil for a free
    /// lane — and `lane` is the one this commit occupies. `merged` names the lanes this commit's extra
    /// parents were placed into, which is what a renderer draws as branches joining.
    public struct GraphRow: Sendable, Equatable {
        public let lane: Int
        public let lanes: [String?]
        public let merged: [Int]
        /// Lanes that were also waiting for this commit and therefore end here — two branches converging.
        /// `git log --graph` draws this as `|/`; without it the graph claims a lane continues past a
        /// commit that in fact absorbed it.
        public let closed: [Int]

        public init(lane: Int, lanes: [String?], merged: [Int], closed: [Int] = []) {
            self.lane = lane; self.lanes = lanes; self.merged = merged; self.closed = closed
        }
    }

    /// Assign lanes to a linear list of commits (newest first), the way every commit graph does it: a
    /// commit takes the lane that was waiting for it, then hands that lane to its first parent; further
    /// parents take free lanes. No dependency for this — it is a hundred lines and a vendored graph
    /// library would bring a licence question with it (see the plan's §4).
    public static func graph(_ commits: [Commit]) -> [GraphRow] {
        var lanes: [String?] = []
        var rows: [GraphRow] = []
        for commit in commits {
            let before = lanes
            var lane = lanes.firstIndex(where: { $0 == commit.hash }) ?? -1
            if lane < 0 {
                lane = lanes.firstIndex(where: { $0 == nil }) ?? lanes.count
                if lane == lanes.count { lanes.append(nil) }
            }
            // The lane continues with the first parent; a commit with no parents ends it.
            lanes[lane] = commit.parents.first
            // Any *other* lane waiting for this same commit converges here and ends.
            var closed: [Int] = []
            for (index, waiting) in lanes.enumerated() where index != lane && waiting == commit.hash {
                lanes[index] = nil
                closed.append(index)
            }
            var merged: [Int] = []
            for parent in commit.parents.dropFirst() {
                if let existing = lanes.firstIndex(where: { $0 == parent }) {
                    merged.append(existing)          // that parent is already on its way down
                    continue
                }
                let free = lanes.firstIndex(where: { $0 == nil }) ?? lanes.count
                if free == lanes.count { lanes.append(parent) } else { lanes[free] = parent }
                merged.append(free)
            }
            // A lane whose expectation is now nil and that nobody else waits for is free again.
            rows.append(GraphRow(lane: lane, lanes: before.isEmpty ? [commit.hash] : before,
                                 merged: merged, closed: closed))
        }
        return rows
    }

    /// The graph as monospace text, which is what a table column can show without a custom renderer:
    /// `│ ● │` for a commit on the middle lane, `●─┐` where a merge brings in a second parent.
    public static func graphText(_ row: GraphRow, width: Int? = nil) -> String {
        let count = max(width ?? row.lanes.count, row.lane + 1,
                        (row.merged.max() ?? 0) + 1)
        var cells = [String](repeating: " ", count: count)
        for (index, lane) in row.lanes.enumerated() where index < count {
            cells[index] = lane == nil ? " " : "│"
        }
        cells[row.lane] = "●"
        for lane in row.merged where lane < count {
            cells[lane] = cells[lane] == " " ? "┐" : "┤"
        }
        for lane in row.closed where lane < count {
            cells[lane] = "┘"      // this branch ends in the commit on this row
        }
        return cells.joined()
    }

    // MARK: - Blame (phase 2)

    /// One line of `git blame --porcelain`.
    public struct BlameLine: Sendable, Equatable {
        public let line: Int
        public let hash: String
        public let author: String
        public let date: Date
        public let summary: String
        public let text: String

        public init(line: Int, hash: String, author: String, date: Date, summary: String, text: String) {
            self.line = line; self.hash = hash; self.author = author
            self.date = date; self.summary = summary; self.text = text
        }

        /// A commit that is not committed: `git blame` writes all-zero for a line that is not in any
        /// commit yet, which is a different thing from an old commit and must not be shown as one.
        public var isUncommitted: Bool { hash.allSatisfy { $0 == "0" } }
    }

    public static let blameArguments = ["--no-optional-locks", "blame", "--porcelain", "--"]

    /// Parse `git blame --porcelain`.
    ///
    /// The format repeats a commit's details only the *first* time that commit appears, and refers back to
    /// it afterwards by hash alone — so a parser that reads each block independently loses the author on
    /// every line after the first of each commit. The details are therefore remembered per hash.
    public static func parseBlame(_ output: String) -> [BlameLine] {
        var details: [String: (author: String, date: Date, summary: String)] = [:]
        var lines: [BlameLine] = []
        var hash = ""
        var lineNumber = 0
        var author = "", summary = ""
        var date = Date(timeIntervalSince1970: 0)

        for raw in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.hasPrefix("\t") {
                let known = details[hash]
                lines.append(BlameLine(line: lineNumber, hash: hash,
                                       author: known?.author ?? author,
                                       date: known?.date ?? date,
                                       summary: known?.summary ?? summary,
                                       text: String(line.dropFirst())))
                continue
            }
            let parts = line.split(separator: " ", maxSplits: 3).map(String.init)
            guard let first = parts.first else { continue }
            if first.count == 40, first.allSatisfy({ $0.isHexDigit }), parts.count >= 3 {
                hash = first
                lineNumber = Int(parts[2]) ?? 0
                if let known = details[hash] {
                    author = known.author; date = known.date; summary = known.summary
                } else {
                    author = ""; summary = ""; date = Date(timeIntervalSince1970: 0)
                }
                continue
            }
            switch first {
            case "author":
                author = parts.count > 1 ? line.dropFirst("author ".count).trimmingCharacters(in: .whitespaces) : ""
            case "author-time":
                date = Date(timeIntervalSince1970: Double(parts.count > 1 ? parts[1] : "0") ?? 0)
            case "summary":
                summary = String(line.dropFirst("summary ".count))
            case "filename":
                details[hash] = (author, date, summary)
            default:
                break
            }
        }
        return lines
    }

    // MARK: - Branches, stashes, remotes (phase 3)

    /// A branch as `for-each-ref` reports it.
    public struct Branch: Sendable, Equatable {
        public let name: String
        public let isCurrent: Bool
        public let isRemote: Bool
        public let upstream: String?
        public let ahead: Int
        public let behind: Int
        public let subject: String

        public init(name: String, isCurrent: Bool, isRemote: Bool, upstream: String?,
                    ahead: Int, behind: Int, subject: String) {
            self.name = name; self.isCurrent = isCurrent; self.isRemote = isRemote
            self.upstream = upstream; self.ahead = ahead; self.behind = behind; self.subject = subject
        }
    }

    /// `for-each-ref` with an explicit format, rather than parsing `git branch -vv`, whose output is
    /// meant for people: it marks the current branch with a `*`, aligns columns with spaces and puts the
    /// tracking information in brackets inside the subject line.
    public static let branchArguments = [
        "--no-optional-locks", "for-each-ref", "--sort=-committerdate",
        "--format=%(refname:short)\u{1F}%(HEAD)\u{1F}%(upstream:short)\u{1F}%(upstream:track)"
        + "\u{1F}%(contents:subject)\u{1F}%(refname)",
        "refs/heads", "refs/remotes",
    ]

    public static func parseBranches(_ output: String) -> [Branch] {
        var branches: [Branch] = []
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = String(line).components(separatedBy: unitSeparator)
            guard fields.count >= 6, !fields[0].isEmpty else { continue }
            let track = fields[3]      // "[ahead 2, behind 1]", "[gone]" or empty
            var ahead = 0, behind = 0
            if let range = track.range(of: "ahead ") {
                ahead = Int(track[range.upperBound...].prefix(while: \.isNumber)) ?? 0
            }
            if let range = track.range(of: "behind ") {
                behind = Int(track[range.upperBound...].prefix(while: \.isNumber)) ?? 0
            }
            branches.append(Branch(name: fields[0], isCurrent: fields[1] == "*",
                                   isRemote: fields[5].hasPrefix("refs/remotes/"),
                                   upstream: fields[2].isEmpty ? nil : fields[2],
                                   ahead: ahead, behind: behind, subject: fields[4]))
        }
        return branches
    }

    /// One stash entry.
    public struct Stash: Sendable, Equatable {
        /// `stash@{0}` — the name every stash command takes.
        public let ref: String
        public let branch: String
        public let subject: String
        public init(ref: String, branch: String, subject: String) {
            self.ref = ref; self.branch = branch; self.subject = subject
        }
    }

    public static let stashListArguments = [
        "--no-optional-locks", "stash", "list",
        "--format=%gd\u{1F}%gs",
    ]

    /// Parse `stash list`. `%gs` reads "WIP on main: abc1234 subject" or "On main: message"; the branch is
    /// worth pulling out because a stash made on another branch is the one you have to be careful with.
    public static func parseStashes(_ output: String) -> [Stash] {
        var stashes: [Stash] = []
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = String(line).components(separatedBy: unitSeparator)
            guard fields.count >= 2, !fields[0].isEmpty else { continue }
            var branch = ""
            var subject = fields[1]
            for prefix in ["WIP on ", "On "] where subject.hasPrefix(prefix) {
                let rest = subject.dropFirst(prefix.count)
                if let colon = rest.firstIndex(of: ":") {
                    branch = String(rest[rest.startIndex..<colon])
                    subject = String(rest[rest.index(after: colon)...])
                        .trimmingCharacters(in: .whitespaces)
                }
                break
            }
            stashes.append(Stash(ref: fields[0], branch: branch, subject: subject))
        }
        return stashes
    }

    /// Whether switching branches is safe right now, and if not, why — in a form the caller can turn into
    /// a sentence. A half-finished checkout is worse than a refusal, and git's own error text is written
    /// for a terminal.
    public enum SwitchRefusal: Sendable, Equatable {
        case conflicts(Int)
        case staged(Int)
        case none
    }

    public static func canSwitch(_ status: RepoStatus) -> SwitchRefusal {
        let conflicts = status.files.values.filter { $0.summary == .conflict }.count
        if conflicts > 0 { return .conflicts(conflicts) }
        let staged = status.files.values.filter(\.isStaged).count
        if staged > 0 { return .staged(staged) }
        return .none
    }

    /// The two sides of a conflicted file, as `git show` specs: stage 2 is "ours", stage 3 is "theirs".
    /// (Stage 1 is the common ancestor; the host's compare window takes two files, so the base is not
    /// shown — recorded in the plan rather than pretended away.)
    public static func conflictSpecs(path: String) -> (ours: String, theirs: String) {
        (":2:" + path, ":3:" + path)
    }

    // MARK: - Ignoring (phase 4)

    /// What to add to `.gitignore` for an item — the three choices the reference products offer.
    public enum IgnoreKind: String, Sendable, CaseIterable { case name, extensionGlob, directory }

    /// The pattern to write, anchored the way git reads it.
    ///
    /// A leading `/` matters: without it `build` matches a directory of that name at *any* depth, which is
    /// almost never what somebody clicking "ignore this folder" means. An extension glob is deliberately
    /// *not* anchored, because `*.o` everywhere is exactly what it means.
    public static func ignorePattern(kind: IgnoreKind, relativePath: String) -> String? {
        let name = (relativePath as NSString).lastPathComponent
        guard !name.isEmpty else { return nil }
        switch kind {
        case .name:
            return "/" + relativePath
        case .extensionGlob:
            let ext = (name as NSString).pathExtension
            return ext.isEmpty ? nil : "*." + ext
        case .directory:
            return "/" + relativePath + "/"
        }
    }

    /// Append `pattern` to an existing `.gitignore`'s text, or return nil when it is already covered.
    ///
    /// Only an exact line match counts as "already there". Deciding whether an existing pattern *implies*
    /// the new one is git's job, not a plugin's — `**/build` covers `/src/build` and this code has no
    /// business claiming to know that — and a duplicate line is harmless, while a wrongly-skipped one
    /// leaves the reader wondering why their click did nothing.
    public static func appendingIgnore(_ pattern: String, to text: String) -> String? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard !lines.contains(pattern) else { return nil }
        var out = text
        if !out.isEmpty && !out.hasSuffix("\n") { out += "\n" }
        out += pattern + "\n"
        return out
    }

    // MARK: - Worktrees (phase 4)

    /// `rev-parse` answering all three questions a listing needs: the working tree's root, the directory's
    /// prefix inside it, and where the *real* git directory is.
    ///
    /// The third one is what makes linked worktrees work. In a worktree created with `git worktree add`,
    /// `.git` is a *file* pointing elsewhere, so `<root>/.git/index` does not exist — the cache's
    /// index-mtime check then found nothing to compare and fell back to the TTL alone, which is the
    /// difference between a column that follows a commit immediately and one that follows it eventually.
    public static let locateArgumentsWithGitDir =
        ["rev-parse", "--show-toplevel", "--show-prefix", "--absolute-git-dir"]

    /// Root, prefix and git-dir from `locateArgumentsWithGitDir`.
    public static func parseLocateWithGitDir(_ output: String) -> (root: String, prefix: String,
                                                                  gitDir: String)? {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let root = lines.first, !root.isEmpty else { return nil }
        let prefix = lines.count > 1 ? lines[1] : ""
        // An older git without --absolute-git-dir prints nothing for it; the caller then falls back to
        // <root>/.git, which is right for a normal clone and merely imprecise for a worktree.
        let gitDir = lines.count > 2 && !lines[2].isEmpty ? lines[2] : (root as NSString)
            .appendingPathComponent(".git")
        return (root, prefix, gitDir)
    }

    /// git's `%D` decoration: `HEAD -> main, origin/main, tag: v1.0`.
    public static func parseRefs(_ decoration: String) -> [Ref] {
        var refs: [Ref] = []
        for piece in decoration.components(separatedBy: ", ") {
            let text = piece.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            if text.hasPrefix("HEAD -> ") {
                refs.append(Ref(name: String(text.dropFirst(8)), kind: .head))
            } else if text.hasPrefix("tag: ") {
                refs.append(Ref(name: String(text.dropFirst(5)), kind: .tag))
            } else if text == "HEAD" {
                refs.append(Ref(name: "HEAD", kind: .head))     // detached
            } else {
                refs.append(Ref(name: text, kind: text.contains("/") ? .remote : .branch))
            }
        }
        return refs
    }

    // MARK: - Tags (F-425)

    /// A tag, as the list shows it. `isAnnotated` matters: a lightweight tag has no message and no tagger,
    /// so a window that pretends otherwise shows empty columns for half the rows.
    public struct Tag: Sendable, Equatable {
        public let name: String
        public let isAnnotated: Bool
        public let subject: String
        public let date: Date?
        public init(name: String, isAnnotated: Bool, subject: String, date: Date?) {
            self.name = name; self.isAnnotated = isAnnotated; self.subject = subject; self.date = date
        }
    }

    /// Tags newest first, with the same explicit format the branch list uses.
    ///
    /// `creatordate` rather than `taggerdate`: a lightweight tag has no tagger, so sorting by taggerdate
    /// puts every lightweight tag in one undated clump at the end.
    public static let tagArguments = [
        "--no-optional-locks", "for-each-ref", "--sort=-creatordate",
        "--format=%(refname:short)\u{1F}%(objecttype)\u{1F}%(contents:subject)\u{1F}%(creatordate:unix)",
        "refs/tags",
    ]

    public static func parseTags(_ output: String) -> [Tag] {
        var tags: [Tag] = []
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.components(separatedBy: unitSeparator)
            guard fields.count >= 4, !fields[0].isEmpty else { continue }
            let seconds = Double(fields[3].trimmingCharacters(in: .whitespaces))
            tags.append(Tag(name: fields[0],
                            isAnnotated: fields[1] == "tag",
                            subject: fields[2],
                            date: seconds.map { Date(timeIntervalSince1970: $0) }))
        }
        return tags
    }

    /// Annotated when there is a message, lightweight when there is not — which is the actual difference
    /// between the two, so the choice is made by whether the reader typed something rather than by a
    /// checkbox they would have to understand first.
    public static func createTagArguments(name: String, message: String?) -> [String] {
        guard let message, !message.isEmpty else { return ["tag", name] }
        return ["tag", "-a", name, "-m", message]
    }

    public static func deleteTagArguments(_ name: String) -> [String] { ["tag", "-d", name] }

    /// Publishing a tag is explicit: `git push` does not carry tags, which is the single most common
    /// surprise about them ("I tagged it and nobody else can see it").
    public static func pushTagArguments(remote: String, name: String) -> [String] {
        ["push", remote, "refs/tags/" + name]
    }

    public static func checkoutTagArguments(_ name: String) -> [String] { ["checkout", name] }

    // MARK: - Rebase, bounded to the commits ahead of the upstream (phase 5d)

    /// What to do with one commit in a rebase. Deliberately the five that "clean up what I have not pushed
    /// yet" needs — not git's full vocabulary (no `exec`, no `break`, no `label`/`merge`).
    public enum RebaseAction: String, Sendable, CaseIterable {
        case pick, reword, squash, fixup, drop
    }

    /// Why a rebase must not be started.
    public enum RebaseRefusal: Sendable, Equatable {
        case dirtyWorkingTree, conflictOpen, noUpstream, nothingAhead
        case squashWithoutParent          // the oldest line cannot be squashed into anything
        case severalRewords(Int)          // one message can be supplied, not several (see `editorValue`)
        case rebaseAlreadyRunning
    }

    /// Check a plan before running it. The order matters: what has to be dealt with first comes first.
    public static func rebaseRefusal(repo: RepoStatus, aheadCount: Int, actions: [RebaseAction],
                                    rebaseRunning: Bool) -> RebaseRefusal? {
        if rebaseRunning { return .rebaseAlreadyRunning }
        if let refusal = refusal(forCommitActionIn: repo) {
            return refusal == .conflictOpen ? .conflictOpen : .dirtyWorkingTree
        }
        if repo.upstream == nil { return .noUpstream }
        if aheadCount == 0 { return .nothingAhead }
        // The list is oldest-first, as git's todo file is: a squash on the first line has no parent left.
        if let first = actions.first, first == .squash || first == .fixup { return .squashWithoutParent }
        let rewords = actions.filter { $0 == .reword }.count
        if rewords > 1 { return .severalRewords(rewords) }
        return nil
    }

    /// The todo file git's sequence editor would have been opened on.
    ///
    /// Oldest first, which is the opposite of `log` order and the direction git applies them in — getting
    /// this backwards produces a rebase that succeeds and reorders the branch wrongly, which is the worst
    /// kind of wrong here. `drop` is written as a `drop` line rather than omitted: git then confirms it
    /// dropped that commit, and a todo missing a commit git expected is an error rather than an intention.
    public static func rebaseTodo(commits: [Commit], actions: [RebaseAction]) -> String {
        var lines: [String] = []
        for (index, commit) in commits.enumerated() {
            let action = actions.indices.contains(index) ? actions[index] : .pick
            lines.append("\(action.rawValue) \(commit.hash) \(commit.subject)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// `GIT_SEQUENCE_EDITOR`: the todo file is handed over by copying ours onto the one git offers.
    ///
    /// git runs this through a shell with the todo path appended, so `cp <ours>` becomes
    /// `cp <ours> <git's>`. That is the whole trick that makes an interactive rebase possible from a GUI
    /// with no terminal to open an editor on. Single-quoted, since a repository can live under a path with
    /// spaces in it, and any single quote inside is escaped the shell's way.
    public static func sequenceEditorValue(todoPath: String) -> String {
        "cp " + shellQuoted(todoPath)
    }

    /// `GIT_EDITOR`: supply a commit message from a file, or accept whatever git pre-filled.
    ///
    /// `true` is not a no-op editor by accident — it is the editor that changes nothing and exits happily,
    /// which for a `squash` means keeping the concatenated message git prepared. With a message file it
    /// becomes `cp`, and that is why only *one* reword is allowed per run: every invocation would be handed
    /// the same file, so two rewords would silently give both commits the same message.
    public static func editorValue(messagePath: String?) -> String {
        guard let messagePath else { return "true" }
        return "cp " + shellQuoted(messagePath)
    }

    static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func rebaseArguments(upstream: String) -> [String] { ["rebase", "-i", upstream] }
    public static let rebaseContinueArguments = ["rebase", "--continue"]
    public static let rebaseSkipArguments = ["rebase", "--skip"]
    public static let rebaseAbortArguments = ["rebase", "--abort"]

    /// Is a rebase half-finished in this repository?
    ///
    /// From the git directory rather than from a command: `rebase-merge` (the interactive machinery) and
    /// `rebase-apply` (the older/`--apply` one) are what git itself looks for, and asking costs a `stat`
    /// rather than a process per listing. `gitDir` must be the *real* one — in a worktree that is not
    /// `<root>/.git`, which is what F-419 taught this file.
    public static func rebaseIsRunning(gitDir: String, exists: (String) -> Bool) -> Bool {
        exists((gitDir as NSString).appendingPathComponent("rebase-merge"))
            || exists((gitDir as NSString).appendingPathComponent("rebase-apply"))
    }

    // MARK: - Remotes: transport, credentials, web links (phase 5b/5c)

    public enum RemoteTransport: String, Sendable, Equatable { case ssh, https, git, local, unknown }

    /// How a remote is reached, which is what decides *where its credentials come from*: an SSH remote
    /// asks the agent, an HTTPS remote asks a credential helper, and telling a user to add an SSH key when
    /// their remote is HTTPS is worse than saying nothing.
    public static func transport(of url: String) -> RemoteTransport {
        let text = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .unknown }
        if text.hasPrefix("https://") || text.hasPrefix("http://") { return .https }
        if text.hasPrefix("ssh://") { return .ssh }
        if text.hasPrefix("git://") { return .git }
        if text.hasPrefix("/") || text.hasPrefix("file://") || text.hasPrefix(".") { return .local }
        // scp-like: user@host:path — an SSH remote without saying so.
        if let at = text.firstIndex(of: "@"), text[at...].contains(":") { return .ssh }
        return .unknown
    }

    /// Host and repository path from any of the forms git accepts, with credentials and `.git` stripped.
    public static func remoteHostAndPath(_ url: String) -> (host: String, path: String)? {
        var text = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        for prefix in ["https://", "http://", "ssh://", "git://"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        if text.hasPrefix("git@") || text.contains("@") , let at = text.firstIndex(of: "@"),
           !text.hasPrefix("/") {
            text = String(text[text.index(after: at)...])   // drop user[:password]@
        }
        // scp-like "host:owner/repo" becomes "host/owner/repo"; a port ("host:22/x") is dropped.
        if let colon = text.firstIndex(of: ":") {
            let after = text[text.index(after: colon)...]
            let digits = after.prefix(while: \.isNumber)
            if !digits.isEmpty, after.dropFirst(digits.count).hasPrefix("/") {
                text = String(text[text.startIndex..<colon]) + String(after.dropFirst(digits.count))
            } else {
                text = String(text[text.startIndex..<colon]) + "/" + String(after)
            }
        }
        let parts = text.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2 else { return nil }
        var path = parts.dropFirst().joined(separator: "/")
        if path.hasSuffix(".git") { path.removeLast(4) }
        guard !path.isEmpty else { return nil }
        return (parts[0], path)
    }

    /// What the plugin knows about how this repository authenticates.
    public struct CredentialReport: Sendable {
        public var remoteName: String
        public var remoteURL: String
        public var helper: String?          // credential.helper, if configured
        /// Keys the SSH agent holds; nil when the agent could not be asked at all.
        public var agentKeys: Int?
        public init(remoteName: String, remoteURL: String, helper: String?, agentKeys: Int?) {
            self.remoteName = remoteName; self.remoteURL = remoteURL
            self.helper = helper; self.agentKeys = agentKeys
        }
    }

    /// The findings a report leads to, in the order they should be read.
    ///
    /// `offerKeychain` is the *only* action this plugin takes about credentials: it sets git's own
    /// `credential.helper` to `osxkeychain`, which ships with git and keeps the secret in the macOS
    /// Keychain under git's management. The plugin never sees a passphrase — and a store of its own would
    /// be a stale copy of git's, because git looks credentials up by URL and decides their lifetime.
    public enum CredentialFinding: String, Sendable, Equatable {
        case noRemote, httpsWithoutHelper, httpsWithHelper, sshAgentReady, sshAgentEmpty
        case sshAgentUnreachable, gitProtocolAnonymous, localRemote, unknownTransport
    }

    public static func findings(_ report: CredentialReport) -> [CredentialFinding] {
        guard !report.remoteURL.isEmpty else { return [.noRemote] }
        switch transport(of: report.remoteURL) {
        case .https:
            return [(report.helper?.isEmpty == false) ? .httpsWithHelper : .httpsWithoutHelper]
        case .ssh:
            switch report.agentKeys {
            case .some(let count) where count > 0: return [.sshAgentReady]
            case .some:                            return [.sshAgentEmpty]
            case nil:                              return [.sshAgentUnreachable]
            }
        case .git:     return [.gitProtocolAnonymous]
        case .local:   return [.localRemote]
        case .unknown: return [.unknownTransport]
        }
    }

    public static func offersKeychainHelper(_ findings: [CredentialFinding]) -> Bool {
        findings.contains(.httpsWithoutHelper)
    }

    /// Configure git's own helper. `--global`, because credentials are a property of the person, not of
    /// one checkout, and that is where git's documentation puts it.
    public static let keychainHelperArguments =
        ["config", "--global", "credential.helper", "osxkeychain"]

    /// How many identities the agent holds, from `ssh-add -l`. nil when there is no agent to ask.
    ///
    /// `ssh-add` says "The agent has no identities." on exit code 1 and "Could not open a connection to
    /// your authentication agent." on 2 — the difference between "add a key" and "start an agent", which
    /// is exactly the advice a reader needs and the reason this is not a boolean.
    public static func parseAgentKeys(output: String, exitCode: Int32) -> Int? {
        if exitCode == 0 {
            let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return lines.count
        }
        if output.lowercased().contains("no identities") { return 0 }
        return nil
    }

    // MARK: - Web links (phase 5c)

    /// What to open on the hosting service.
    public enum WebTarget: Sendable, Equatable {
        case repository
        case file(path: String, ref: String)
        case commit(String)
        case branch(String)
    }

    /// The URL for a target on the service the remote points at, or nil when there is nothing sensible.
    ///
    /// Deep links are only built for hosts whose URL shape is *known* — github.com, gitlab.com,
    /// bitbucket.org, dev.azure.com. A self-hosted GitHub Enterprise or GitLab cannot be told from any
    /// other host by its name, so an unknown host gets the repository root and the window says why:
    /// guessing `/blob/main/…` at a service that spells it differently produces a 404 that looks like a
    /// bug in the file manager.
    public static func webURL(remote: String, target: WebTarget) -> String? {
        guard let (host, path) = remoteHostAndPath(remote) else { return nil }
        let root = "https://\(host)/\(path)"
        func encoded(_ path: String) -> String {
            path.split(separator: "/").map {
                $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
            }.joined(separator: "/")
        }
        let lower = host.lowercased()
        if lower == "dev.azure.com" || lower.hasSuffix(".visualstudio.com") {
            // Azure keeps the path in a query parameter rather than in the URL's path.
            switch target {
            case .repository:              return root
            case .file(let file, let ref):
                let p = "/" + encoded(file)
                return "\(root)?path=\(p.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? p)&version=GB\(ref)"
            case .commit(let hash):        return "\(root)/commit/\(hash)"
            case .branch(let name):        return "\(root)?version=GB\(name)"
            }
        }
        let isGitLab = lower == "gitlab.com" || lower.hasPrefix("gitlab.")
        let isBitbucket = lower == "bitbucket.org"
        let isGitHub = lower == "github.com" || lower == "www.github.com"
        guard isGitHub || isGitLab || isBitbucket else {
            // Known-unknown: the root is always right, a deep link would be a guess.
            return target == .repository ? root : nil
        }
        let infix = isGitLab ? "/-" : ""
        switch target {
        case .repository:
            return root
        case .file(let file, let ref):
            return isBitbucket ? "\(root)/src/\(ref)/\(encoded(file))"
                               : "\(root)\(infix)/blob/\(ref)/\(encoded(file))"
        case .commit(let hash):
            return isBitbucket ? "\(root)/commits/\(hash)" : "\(root)\(infix)/commit/\(hash)"
        case .branch(let name):
            return isBitbucket ? "\(root)/branch/\(name)" : "\(root)\(infix)/tree/\(name)"
        }
    }

    /// Which ref a file link should point at: the tracking branch's name when there is one, else the local
    /// branch, else `HEAD` — a link to a branch that exists only on this Mac is a 404 to everyone else,
    /// and every one of the four services resolves `HEAD` to their default branch.
    public static func webRef(_ repo: RepoStatus) -> String {
        if let upstream = repo.upstream, let slash = upstream.firstIndex(of: "/") {
            let name = String(upstream[upstream.index(after: slash)...])
            if !name.isEmpty { return name }
        }
        if repo.detached || repo.branch.isEmpty { return "HEAD" }
        return repo.branch
    }

    // MARK: - Conflict markers (phase 5a)

    /// One conflicted region of a file, as git left it.
    public struct ConflictHunk: Sendable, Equatable {
        public var ours: [String]
        /// The common ancestor's lines — present only in diff3 style (`merge.conflictStyle`).
        public var base: [String]?
        public var theirs: [String]
        public var oursLabel: String
        public var theirsLabel: String
        public var baseLabel: String?
        /// 1-based line number of the `<<<<<<<` marker, so the list can say where it is.
        public var startLine: Int
    }

    /// What the reader decided for a hunk. `unresolved` writes the markers back unchanged.
    public enum ConflictChoice: String, Sendable, CaseIterable { case unresolved, ours, theirs, both }

    /// A conflicted file split into the parts that are plain text and the parts that are a conflict.
    public struct ConflictFile: Sendable {
        public enum Segment: Sendable, Equatable { case text([String]); case conflict(Int) }
        public var segments: [Segment]
        public var hunks: [ConflictHunk]
        /// The line ending to write back, and whether the file ended with one.
        public var usesCRLF: Bool
        public var endsWithNewline: Bool
    }

    /// Split a conflicted file into text and hunks, or nil when the markers do not make sense.
    ///
    /// Returning nil rather than a best guess is the whole point: this text is about to be written back
    /// over the reader's file, and a marker set we misread is how a resolver eats a working tree. A
    /// `<<<<<<<` with no `=======`, a nested `<<<<<<<`, a `>>>>>>>` that closes nothing — all nil, and
    /// the window says so instead of offering buttons.
    ///
    /// CRLF is normalized first and restored on the way out. `"\r\n"` is a *single* Character in Swift,
    /// so splitting on `"\n"` never sees it and a Windows file would arrive as one enormous line — the
    /// same trap the menu-file parsers hit (F-257).
    public static func parseConflicts(_ text: String, markerLength: Int = 7) -> ConflictFile? {
        let usesCRLF = text.contains("\r\n")
        let normalized = usesCRLF ? text.replacingOccurrences(of: "\r\n", with: "\n") : text
        let endsWithNewline = normalized.hasSuffix("\n")
        var lines = normalized.components(separatedBy: "\n")
        if endsWithNewline { lines.removeLast() }   // the trailing "" after the final newline

        let ours = String(repeating: "<", count: markerLength)
        let base = String(repeating: "|", count: markerLength)
        let separator = String(repeating: "=", count: markerLength)
        let theirs = String(repeating: ">", count: markerLength)
        /// A marker line is the run followed by end-of-line or a space and a label — not a line of a
        /// document that happens to start with seven equals signs under a heading.
        func marker(_ line: String, _ run: String) -> String?? {
            guard line.hasPrefix(run) else { return nil }
            let rest = String(line.dropFirst(run.count))
            if rest.isEmpty { return .some(nil) }
            guard rest.hasPrefix(" ") else { return nil }
            return .some(String(rest.dropFirst()))
        }

        enum State { case text, ours, base, theirs }
        var state = State.text
        var segments: [ConflictFile.Segment] = []
        var hunks: [ConflictHunk] = []
        var plain: [String] = []
        var current: ConflictHunk?

        for (index, line) in lines.enumerated() {
            if let label = marker(line, ours) {
                guard state == .text else { return nil }         // nested conflict: refuse
                if !plain.isEmpty { segments.append(.text(plain)); plain = [] }
                current = ConflictHunk(ours: [], base: nil, theirs: [], oursLabel: label ?? "",
                                      theirsLabel: "", baseLabel: nil, startLine: index + 1)
                state = .ours
            } else if let label = marker(line, base) {
                guard state == .ours, var hunk = current else { return nil }
                hunk.base = []
                hunk.baseLabel = label ?? ""
                current = hunk
                state = .base
            } else if marker(line, separator) != nil {
                guard state == .ours || state == .base else { return nil }
                state = .theirs
            } else if let label = marker(line, theirs) {
                guard state == .theirs, var hunk = current else { return nil }
                hunk.theirsLabel = label ?? ""
                segments.append(.conflict(hunks.count))
                hunks.append(hunk)
                current = nil
                state = .text
            } else {
                switch state {
                case .text:   plain.append(line)
                case .ours:   current?.ours.append(line)
                case .base:   current?.base?.append(line)
                case .theirs: current?.theirs.append(line)
                }
            }
        }
        guard state == .text, current == nil else { return nil }  // truncated markers: refuse
        if !plain.isEmpty { segments.append(.text(plain)) }
        return ConflictFile(segments: segments, hunks: hunks, usesCRLF: usesCRLF,
                            endsWithNewline: endsWithNewline)
    }

    /// The file's text with each hunk resolved as chosen. Fewer choices than hunks counts as unresolved.
    ///
    /// An unresolved hunk is written back marker for marker, so writing a half-finished resolution loses
    /// nothing and the file stays exactly as conflicted as it was.
    public static func render(_ file: ConflictFile, choices: [ConflictChoice],
                              markerLength: Int = 7) -> String {
        var out: [String] = []
        for segment in file.segments {
            switch segment {
            case .text(let lines):
                out += lines
            case .conflict(let index):
                let hunk = file.hunks[index]
                switch choices.indices.contains(index) ? choices[index] : .unresolved {
                case .ours:   out += hunk.ours
                case .theirs: out += hunk.theirs
                case .both:   out += hunk.ours + hunk.theirs
                case .unresolved:
                    func line(_ run: Character, _ label: String?) -> String {
                        let marker = String(repeating: run, count: markerLength)
                        guard let label, !label.isEmpty else { return marker }
                        return marker + " " + label
                    }
                    out.append(line("<", hunk.oursLabel))
                    out += hunk.ours
                    if let base = hunk.base {
                        out.append(line("|", hunk.baseLabel))
                        out += base
                    }
                    out.append(line("=", nil))
                    out += hunk.theirs
                    out.append(line(">", hunk.theirsLabel))
                }
            }
        }
        var text = out.joined(separator: "\n")
        if file.endsWithNewline, !text.isEmpty || !out.isEmpty { text += "\n" }
        return file.usesCRLF ? text.replacingOccurrences(of: "\n", with: "\r\n") : text
    }

    // MARK: - Commit-level actions (phase 4)

    /// Why a revert or cherry-pick must not be started.
    ///
    /// git's sequencer requires a clean working tree and index for both, and refuses with a message about
    /// overwritten local changes that reads as if the *commit* were the problem. Checking the status the
    /// column already has lets the plugin say what is actually in the way.
    public enum CommitActionRefusal: String, Sendable { case conflictOpen, dirtyWorkingTree }

    public static func refusal(forCommitActionIn repo: RepoStatus) -> CommitActionRefusal? {
        if repo.files.values.contains(where: { $0.summary == .conflict }) { return .conflictOpen }
        // Untracked files are none of the sequencer's business; tracked changes are.
        if repo.files.values.contains(where: { $0.summary != .untracked && $0.summary != .ignored }) {
            return .dirtyWorkingTree
        }
        return nil
    }

    /// `revert`/`cherry-pick` with no editor: this process has no terminal to open one on.
    public static func revertArguments(_ hash: String) -> [String] {
        ["revert", "--no-edit", hash]
    }

    public static func cherryPickArguments(_ hash: String) -> [String] {
        ["cherry-pick", "--no-edit", hash]
    }

    // MARK: - Column glyphs (phase 4)

    /// A leading glyph for the status column, so a listing can be scanned rather than read.
    ///
    /// Not an icon: the PDX content ABI returns strings, and a real icon field is host work (see the
    /// plan's §6). A glyph in front of the word is what a plugin can do today, and it is what makes
    /// "which of these forty files is in conflict" a glance instead of a search.
    public static func glyph(for change: Change) -> String {
        switch change {
        case .conflict:    return "⚠"
        case .added:       return "✚"
        case .deleted:     return "✖"
        case .modified:    return "●"
        case .renamed:     return "→"
        case .copied:      return "⧉"
        case .typeChanged: return "◐"
        case .untracked:   return "?"
        case .ignored:     return "·"
        case .unchanged:   return ""
        }
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
