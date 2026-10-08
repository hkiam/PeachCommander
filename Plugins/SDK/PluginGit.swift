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
        /// The commit HEAD is on (`# branch.oid`), nil on an unborn branch — so nothing has to ask
        /// `rev-parse HEAD` beside the status.
        public var oid: String?

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
        var oid: String?

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
                case "branch.oid":
                    if parts[1] != "(initial)" { oid = parts[1] }
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
        var status = RepoStatus(branch: branch, detached: detached, upstream: upstream,
                                ahead: ahead, behind: behind, files: files)
        status.oid = oid
        return status
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
        public enum Kind: String, Sendable, Equatable { case head, branch, remote, tag, stash }
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
        /// When the commit was *committed* (`%ct`) — what history order follows. `date` is when it was
        /// authored, which a rebase or a cherry-pick keeps from months ago. nil from an older format.
        public var commitDate: Date?

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
    ///
    /// `all` is the panel's history: every branch, remote branch and tag, so forks and branches show as
    /// lanes. Named ref by ref rather than `--all`, which also walks `refs/stash` — whose parents are the
    /// stash's internal "index on …" and "untracked files on …" commits — and `refs/notes`, neither of
    /// which is history anybody committed. HEAD is added so a detached checkout is still shown.
    ///
    /// `--decorate=full` in every form: the short decoration cannot tell a local `feature/x` from the
    /// remote `origin/main` — both are a name with a slash.
    ///
    /// `dateOrder` is for a search: its results are not a graph, and several searches merged together
    /// need one order they all follow — commit time, which `--date-order` keeps (parents after children).
    ///
    /// `refs` replaces the refs `all` walks (Settings ▸ Git can leave remote branches or tags out).
    public static func logArguments(limit: Int, path: String? = nil, all: Bool = false,
                                    dateOrder: Bool = false, refs: [String]? = nil) -> [String] {
        // `--topo-order`, not git's default date order: with date order a parent can be listed *before*
        // its child (a branch committed earlier than the commit it forked from), and then the lane waiting
        // for that parent never closes — the graph shows a branch running past the commit that ended it.
        // Measured on a repository with one merge; this is also why every graph viewer asks for topo order.
        // `%D` last, after the subject: a subject may contain anything, including our separators in
        // principle, but appending a field keeps every existing index where it was — the rename defect in
        // `parseStatus` was exactly a shifted field, and it is not worth repeating here (F-425).
        var out = ["--no-optional-locks", "log", dateOrder ? "--date-order" : "--topo-order",
                   "--max-count=\(limit)",
                   "--format=%H\(unitSeparator)%h\(unitSeparator)%P\(unitSeparator)%an"
                   + "\(unitSeparator)%at\(unitSeparator)%s\(unitSeparator)%D\(unitSeparator)%ct"
                   + "\(recordSeparator)"]
        out.append("--decorate=full")
        if all { out += refs ?? ["--branches", "--remotes", "--tags", "HEAD"] }
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
            if fields.count >= 8, let seconds = Double(fields[7]) {
                commit.commitDate = Date(timeIntervalSince1970: seconds)
            }
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

    // MARK: - The panel's history: geometry, details, changes (phase 6)

    /// One stroke of the drawn graph, in lane units. `upper` strokes run from the row's top edge (lane
    /// `from`) to its middle (lane `to`); lower ones from the middle (`from`) to the bottom edge (`to`).
    /// `color` is the lane whose colour the stroke takes.
    public struct GraphLine: Sendable, Equatable {
        public let from: Int
        public let to: Int
        public let upper: Bool
        public let color: Int
        public init(from: Int, to: Int, upper: Bool, color: Int) {
            self.from = from; self.to = to; self.upper = upper; self.color = color
        }
    }

    /// What a renderer draws for each row: the node's lane and the strokes around it. Kept here, not in
    /// the view, so the geometry — which lane joins which — is tested rather than eyeballed.
    ///
    /// A lane that waits for another commit passes straight through. Lanes that wait for *this* commit
    /// bend into its node from above (that is the node's own lane plus the `closed` ones). Below the node,
    /// the first parent continues the node's lane and every further parent bends out to its lane.
    public static func graphLines(_ rows: [GraphRow]) -> [(node: Int, lines: [GraphLine])] {
        var out: [(node: Int, lines: [GraphLine])] = []
        for (index, row) in rows.enumerated() {
            var lines: [GraphLine] = []
            let after = index + 1 < rows.count ? rows[index + 1].lanes : []
            let incoming = Set([row.lane] + row.closed)
            for (lane, waiting) in row.lanes.enumerated() where waiting != nil {
                if incoming.contains(lane) {
                    // The first row's `lanes` is a placeholder for the commit itself, not a lane from above.
                    if index > 0 || lane != row.lane {
                        lines.append(GraphLine(from: lane, to: row.lane, upper: true, color: lane))
                    }
                } else {
                    lines.append(GraphLine(from: lane, to: lane, upper: true, color: lane))
                    lines.append(GraphLine(from: lane, to: lane, upper: false, color: lane))
                }
            }
            if row.lane < after.count, after[row.lane] != nil {
                lines.append(GraphLine(from: row.lane, to: row.lane, upper: false, color: row.lane))
            }
            for lane in row.merged {
                lines.append(GraphLine(from: row.lane, to: lane, upper: false, color: lane))
            }
            out.append((row.lane, lines))
        }
        return out
    }

    // MARK: - The tools git starts

    /// The `PATH` git runs with: the inherited one first, then — when missing — the directory of the git
    /// being run and the places Homebrew (Apple silicon, Intel) and MacPorts install to.
    ///
    /// git starts other programs by name: the `git-lfs` filter, `gpg` for a signed commit, credential
    /// helpers. An app opened from the Finder inherits launchd's `/usr/bin:/bin:/usr/sbin:/sbin`, none of
    /// which holds them, and git then fails in ways that look like the plugin's fault — measured: in a
    /// repository using LFS, even `git status` stopped with "git-lfs filter-process: git-lfs: command not
    /// found". Appended, not prepended, so a PATH the reader set up on purpose still wins.
    public static func toolSearchPath(current: String?, gitExecutable: String?) -> String {
        var entries = (current ?? "").split(separator: ":").map(String.init).filter { !$0.isEmpty }
        var extra: [String] = []
        if let gitExecutable { extra.append((gitExecutable as NSString).deletingLastPathComponent) }
        extra += ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        for directory in extra where !directory.isEmpty && !entries.contains(directory) { entries.append(directory) }
        return entries.joined(separator: ":")
    }

    // MARK: - Searching the history

    /// Whether a search text could be (the start of) a commit hash: four to forty hex digits. Four is
    /// git's own minimum for an abbreviated object name.
    public static func isHashLike(_ query: String) -> Bool {
        (4...40).contains(query.count) && query.allSatisfy(\.isHexDigit)
    }

    /// The `git log` calls one search runs over the message and the author, each a complete argument list
    /// for `parseLog`.
    ///
    /// Two calls because git *intersects* `--grep` and `--author` within one (measured: `--author=Demo
    /// --grep=helpers` lists only commits matching both), and a search box that only finds commits
    /// matching every field it says it searches is the wrong way round. Both are case-insensitive fixed
    /// strings — a reader typing `fix(git)` means those characters, not a regex — and `--grep` searches
    /// the whole message, body included; `--author` matches name and e-mail. In commit-time order, so the
    /// two lists can be merged without gaps (`mergeSearchResults`). Run them with `searchEnvironment`.
    public static func searchArguments(_ query: String, limit: Int, all: Bool, refs: [String]? = nil) -> [[String]] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        let base = logArguments(limit: limit, all: all, dateOrder: true, refs: refs)
        return [base + ["-i", "-F", "--grep=\(text)"], base + ["-i", "-F", "--author=\(text)"]]
    }

    /// git folds case by its locale, and an app started from Finder has none: under the C locale `über`
    /// does not find "Über" (measured). Only the search calls get this; their output is parsed, not shown.
    public static let searchEnvironment = ["LC_ALL": "UTF-8"]

    /// For a hash-like search, the call that resolves it to its commit — or nil. After `--end-of-options`,
    /// so nothing a reader types can become an option. The commit it finds still has to pass
    /// `reachabilityArguments`: a hash names any object in the repository, also one outside the history
    /// being searched.
    public static func hashSearchArguments(_ query: String) -> [String]? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isHashLike(text) else { return nil }
        return logArguments(limit: 1) + ["--no-walk", "--end-of-options", text]
    }

    /// Whether the commit a hash search found belongs to the history being searched. With `all`, some
    /// branch, remote branch or tag must contain it — the call lists one such ref, or nothing; on the
    /// current branch only, HEAD must — the call's exit status says it.
    public static func reachabilityArguments(_ hash: String, all: Bool) -> [String] {
        all ? ["for-each-ref", "--count=1", "--format=%(refname)", "--contains", hash,
               "refs/heads", "refs/remotes", "refs/tags"]
            : ["merge-base", "--is-ancestor", hash, "HEAD"]
    }

    /// The results of `searchArguments`' calls (each `limit` long at most) as one list, newest commit
    /// first, each commit once — plus `extra`, the hash search's commit, wherever its time puts it.
    ///
    /// A call that came back full stopped somewhere: past its last commit it may have more matches, which
    /// the other call cannot stand in for. So the merged list ends at the newest such stopping point, and
    /// `hasMore` says a longer search would go on — otherwise commits older than one call's cut-off and
    /// newer than the other's would be listed with the first call's matches missing among them.
    public static func mergeSearchResults(_ results: [[Commit]], extra: [Commit] = [],
                                          limit: Int) -> (commits: [Commit], hasMore: Bool) {
        func time(_ commit: Commit) -> Date { commit.commitDate ?? commit.date }
        let cutOffs = results.filter { $0.count >= limit }.compactMap { $0.last.map(time) }
        let cutOff = cutOffs.max()
        var seen = Set<String>()
        var out: [Commit] = []
        for commit in results.joined() + extra where seen.insert(commit.hash).inserted {
            if let cutOff, time(commit) < cutOff, !extra.contains(where: { $0.hash == commit.hash }) { continue }
            out.append(commit)
        }
        return (out.sorted { time($0) > time($1) }, cutOff != nil)
    }

    /// A file a commit touched, from `--name-status`. `oldPath` is set for a rename or copy.
    public struct ChangedFile: Sendable, Equatable {
        public let status: String
        public let path: String
        public let oldPath: String?
        public init(status: String, path: String, oldPath: String? = nil) {
            self.status = status; self.path = path; self.oldPath = oldPath
        }
    }

    /// `git show` arguments for the files a commit touched, against its first parent — for a merge that is
    /// the useful side, and a root commit lists its files as added. `-z` because without it git C-quotes
    /// every path outside ASCII (`"Gr\303\274\303\237e.txt"`), the same defect `parseStatus` had to
    /// leave behind (see the top of this file).
    public static func nameStatusArguments(_ hash: String) -> [String] {
        ["--no-optional-locks", "show", "--name-status", "-z", "--format=", "-m", "--first-parent", hash]
    }

    /// `nameStatusArguments` output: NUL-separated `M`, `path`, … and for a rename or copy `R100`, `old`,
    /// `new`. The status is the letter alone; the similarity score of a rename is noise in a list.
    public static func parseNameStatus(_ output: String) -> [ChangedFile] {
        var files: [ChangedFile] = []
        var fields = output.split(separator: "\0", omittingEmptySubsequences: false).map(String.init)[...]
        while let status = fields.popFirst() {
            // The first record of `show -m` can follow a newline; the letter is what matters.
            let code = status.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let letter = code.first else { continue }
            if letter == "R" || letter == "C" {
                guard let old = fields.popFirst(), let new = fields.popFirst() else { break }
                files.append(ChangedFile(status: String(letter), path: new, oldPath: old))
            } else {
                guard let path = fields.popFirst() else { break }
                files.append(ChangedFile(status: String(letter), path: path))
            }
        }
        return files
    }

    /// Everything the Commit tab shows about one commit.
    public struct CommitDetails: Sendable, Equatable {
        public let hash: String
        public let parents: [String]
        public let authorName: String
        public let authorEmail: String
        public let authorDate: Date
        public let committerName: String
        public let committerEmail: String
        public let commitDate: Date
        public let refs: [Ref]
        /// git's `%G?`: G good, B bad, U good but untrusted, N none, … — empty when git could not say.
        public let signature: String
        public let message: String
    }

    /// `git show -s` for `parseDetails`. The message (`%B`) comes last: it may contain anything.
    public static func detailsArguments(_ hash: String) -> [String] {
        let fields = ["%H", "%P", "%an", "%ae", "%at", "%cn", "%ce", "%ct", "%D", "%G?", "%B"]
        return ["--no-optional-locks", "show", "-s", "--decorate=full",
                "--format=" + fields.joined(separator: unitSeparator), hash]
    }

    public static func parseDetails(_ output: String) -> CommitDetails? {
        let fields = output.components(separatedBy: unitSeparator)
        guard fields.count >= 11, !fields[0].isEmpty else { return nil }
        func date(_ text: String) -> Date { Date(timeIntervalSince1970: Double(text) ?? 0) }
        return CommitDetails(
            hash: fields[0], parents: fields[1].split(separator: " ").map(String.init),
            authorName: fields[2], authorEmail: fields[3], authorDate: date(fields[4]),
            committerName: fields[5], committerEmail: fields[6], commitDate: date(fields[7]),
            refs: parseRefs(fields[8]), signature: fields[9],
            // A message that itself contained the separator is put back together rather than cut short.
            message: fields[10...].joined(separator: unitSeparator)
                .trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// A folder or a file in the Changes tree.
    public struct FileTreeNode: Sendable, Equatable {
        /// What the row shows: a file name, or a folder chain collapsed to `app/aktionen`.
        public var name: String
        /// Repository-relative path of the file or folder.
        public var path: String
        public var file: ChangedFile?
        public var children: [FileTreeNode]
        public var isFolder: Bool { file == nil }
    }

    /// The changed files as a tree: folders before files, each sorted the way Finder sorts, and a folder
    /// whose only child is another folder merged into it — `services/cockpit/app` is one row, not three
    /// rows that each hold nothing but the next.
    public static func fileTree(_ files: [ChangedFile]) -> [FileTreeNode] {
        final class Folder {
            var folders: [String: Folder] = [:]
            var files: [ChangedFile] = []
        }
        let top = Folder()
        for file in files {
            var folder = top
            for part in file.path.split(separator: "/").dropLast().map(String.init) {
                if let next = folder.folders[part] { folder = next } else {
                    let next = Folder(); folder.folders[part] = next; folder = next
                }
            }
            folder.files.append(file)
        }
        func order(_ a: String, _ b: String) -> Bool { a.localizedStandardCompare(b) == .orderedAscending }
        func nodes(_ folder: Folder, prefix: String) -> [FileTreeNode] {
            var out: [FileTreeNode] = []
            for name in folder.folders.keys.sorted(by: order) {
                var sub = folder.folders[name]!
                var label = name
                while sub.files.isEmpty, sub.folders.count == 1, let only = sub.folders.first {
                    label += "/" + only.key
                    sub = only.value
                }
                let path = prefix.isEmpty ? label : prefix + "/" + label
                out.append(FileTreeNode(name: label, path: path, file: nil, children: nodes(sub, prefix: path)))
            }
            for file in folder.files.sorted(by: { order($0.path, $1.path) }) {
                let name = (file.path as NSString).lastPathComponent
                out.append(FileTreeNode(name: name, path: file.path, file: file, children: []))
            }
            return out
        }
        return nodes(top, prefix: "")
    }

    /// One line of a unified diff, as the inline view draws it.
    public struct DiffLine: Sendable, Equatable {
        public enum Kind: String, Sendable, Equatable { case hunk, context, added, removed, meta, binary }
        public let kind: Kind
        public let text: String
        public let oldLine: Int?
        public let newLine: Int?
        public init(kind: Kind, text: String, oldLine: Int? = nil, newLine: Int? = nil) {
            self.kind = kind; self.text = text; self.oldLine = oldLine; self.newLine = newLine
        }
    }

    /// git's unified diff of one file, numbered. git computes the diff — this only reads it, so the panel
    /// does not carry a second diff algorithm. The header lines before the first hunk are dropped except
    /// the ones a reader needs (binary, rename, mode); past `limit` lines the rest is cut and `truncated`
    /// says so, because a generated file of a hundred thousand lines would otherwise stall the panel.
    public static func parseUnifiedDiff(_ text: String, limit: Int = 5000) -> (lines: [DiffLine], truncated: Bool) {
        var lines: [DiffLine] = []
        var old = 0, new = 0
        var inHunk = false
        var truncated = false
        // Checked when a line is about to be *shown*, not per raw line: the trailing empty element of the
        // split and the skipped headers would otherwise report a cut that removed nothing.
        func add(_ line: DiffLine) -> Bool {
            guard lines.count < limit else { truncated = true; return false }
            lines.append(line)
            return true
        }
        scan: for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.hasPrefix("@@") {
                inHunk = true
                // @@ -a,b +c,d @@ heading
                let numbers = line.split(separator: " ").dropFirst().prefix(2)
                for part in numbers {
                    let start = Int(part.dropFirst().split(separator: ",").first ?? "") ?? 0
                    if part.hasPrefix("-") { old = start } else if part.hasPrefix("+") { new = start }
                }
                guard add(DiffLine(kind: .hunk, text: line)) else { break scan }
                continue
            }
            if line.hasPrefix("diff --git") { inHunk = false; continue }
            if !inHunk {
                if line.hasPrefix("Binary files") || line.hasPrefix("GIT binary patch") {
                    guard add(DiffLine(kind: .binary, text: line)) else { break scan }
                } else if ["rename from", "rename to", "new file mode", "deleted file mode",
                           "old mode", "new mode", "copy from", "copy to"].contains(where: line.hasPrefix) {
                    guard add(DiffLine(kind: .meta, text: line)) else { break scan }
                }
                continue
            }
            if line.hasPrefix("+") {
                guard add(DiffLine(kind: .added, text: String(line.dropFirst()), newLine: new)) else { break scan }
                new += 1
            } else if line.hasPrefix("-") {
                guard add(DiffLine(kind: .removed, text: String(line.dropFirst()), oldLine: old)) else { break scan }
                old += 1
            } else if line.hasPrefix("\\") {
                // "\ No newline at end of file"
                guard add(DiffLine(kind: .meta, text: line)) else { break scan }
            } else if line.hasPrefix(" ") {
                let context = DiffLine(kind: .context, text: String(line.dropFirst()), oldLine: old, newLine: new)
                guard add(context) else { break scan }
                old += 1; new += 1
            }
        }
        return (lines, truncated)
    }

    // MARK: - Remotes and submodules (phase 7)

    public struct Remote: Sendable, Equatable {
        public let name: String
        public var fetchURL: String
        public var pushURL: String
    }

    public static let remotesArguments = ["--no-optional-locks", "remote", "-v"]

    /// `git remote -v`: `origin\tgit@host:x.git (fetch)` and the same with `(push)`. One entry per remote,
    /// in git's order; the push URL is shown only where it differs, so it is kept apart.
    public static func parseRemotes(_ output: String) -> [Remote] {
        var out: [Remote] = []
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            var rest = parts[1]
            let kind: String
            if rest.hasSuffix(" (fetch)") { kind = "fetch"; rest.removeLast(8) }
            else if rest.hasSuffix(" (push)") { kind = "push"; rest.removeLast(7) }
            else { continue }
            if let index = out.firstIndex(where: { $0.name == parts[0] }) {
                if kind == "fetch" { out[index].fetchURL = rest } else { out[index].pushURL = rest }
            } else {
                out.append(Remote(name: parts[0], fetchURL: kind == "fetch" ? rest : "", pushURL: kind == "push" ? rest : ""))
            }
        }
        return out
    }

    public static func addRemoteArguments(name: String, url: String) -> [String] { ["remote", "add", name, url] }
    public static func renameRemoteArguments(_ name: String, to newName: String) -> [String] { ["remote", "rename", name, newName] }
    public static func setRemoteURLArguments(_ name: String, url: String) -> [String] { ["remote", "set-url", name, url] }
    public static func removeRemoteArguments(_ name: String) -> [String] { ["remote", "remove", name] }

    public struct Submodule: Sendable, Equatable {
        public enum State: String, Sendable { case current, uninitialized, differs, conflict }
        public let path: String
        public let commit: String
        public let state: State
        /// `git describe` of the checked-out commit, when git gives one.
        public let describe: String?
    }

    public static let submodulesArguments = ["--no-optional-locks", "submodule", "status", "--recursive"]

    /// `git submodule status`: a state letter — space, `-` not initialized, `+` another commit checked
    /// out than the one recorded, `U` conflicted — then the commit, the path and `(describe)`.
    public static func parseSubmodules(_ output: String) -> [Submodule] {
        output.split(separator: "\n").compactMap { raw in
            let line = String(raw)
            guard let first = line.first else { return nil }
            let state: Submodule.State
            switch first {
            case "-": state = .uninitialized
            case "+": state = .differs
            case "U": state = .conflict
            default: state = .current
            }
            let fields = line.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
            guard fields.count == 2 else { return nil }
            var path = fields[1]
            var describe: String?
            if let open = path.range(of: " (", options: .backwards), path.hasSuffix(")") {
                describe = String(path[open.upperBound..<path.index(before: path.endIndex)])
                path = String(path[..<open.lowerBound])
            }
            return Submodule(path: path, commit: fields[0], state: state, describe: describe)
        }
    }

    public static let updateSubmodulesArguments = ["submodule", "update", "--init", "--recursive"]

    /// Add a submodule; `path` is where it goes in this repository. `--`, not `--end-of-options`, which
    /// `git submodule` does not take (it prints its usage and fails — measured).
    public static func addSubmoduleArguments(url: String, path: String) -> [String] {
        ["submodule", "add", "--", url, path]
    }

    /// Remove a submodule: its checkout, its entry in `.gitmodules` and the index. Two calls — `deinit`
    /// forgets it, `rm` removes it — run one after the other. Its repository under `.git/modules/<name>`
    /// stays; `submoduleGitDirArguments` finds it so the caller can delete it as well, or a submodule
    /// added again at that path would find it and refuse.

    public static func removeSubmoduleArguments(_ path: String) -> [[String]] {
        [["submodule", "deinit", "-f", "--", path], ["rm", "-f", "--", path]]
    }

    /// Asked inside the submodule before it is removed: its own git directory, absolute.
    public static let submoduleGitDirArguments = ["rev-parse", "--absolute-git-dir"]

    /// Asked in the superproject: the git directory its submodules' repositories live under.
    public static let commonGitDirArguments = ["rev-parse", "--path-format=absolute", "--git-common-dir"]

    /// Whether `gitDir` is one the removal may delete: strictly inside `<common>/modules/`. Anything
    /// else — an old-style submodule with its own `.git` folder, a path git printed oddly — is left.
    public static func isRemovableSubmoduleGitDir(_ gitDir: String, commonGitDir: String) -> Bool {
        let modules = (commonGitDir as NSString).standardizingPath + "/modules/"
        let dir = (gitDir as NSString).standardizingPath
        return dir.hasPrefix(modules) && dir.count > modules.count && !dir.contains("/../")
    }

    // MARK: - Worktrees and identity per repository (phase 8)

    public struct Worktree: Sendable, Equatable {
        public let path: String
        public let head: String
        /// The branch checked out there, without `refs/heads/`; nil when detached.
        public let branch: String?
        public let isMain: Bool
        public let isLocked: Bool
    }

    public static let worktreesArguments = ["--no-optional-locks", "worktree", "list", "--porcelain"]

    /// `git worktree list --porcelain`: blocks of `worktree <path>`, `HEAD <hash>`, `branch refs/heads/x`
    /// or `detached`, maybe `locked`, separated by an empty line. The first block is the main worktree.
    public static func parseWorktrees(_ output: String) -> [Worktree] {
        var out: [Worktree] = []
        for block in output.components(separatedBy: "\n\n") {
            var path: String?, head = "", branch: String?, locked = false
            for line in block.split(separator: "\n").map(String.init) {
                if line.hasPrefix("worktree ") { path = String(line.dropFirst(9)) }
                else if line.hasPrefix("HEAD ") { head = String(line.dropFirst(5)) }
                else if line.hasPrefix("branch ") {
                    let ref = String(line.dropFirst(7))
                    branch = ref.hasPrefix("refs/heads/") ? String(ref.dropFirst(11)) : ref
                }
                else if line == "locked" || line.hasPrefix("locked ") { locked = true }
            }
            guard let path else { continue }
            out.append(Worktree(path: path, head: head, branch: branch, isMain: out.isEmpty, isLocked: locked))
        }
        return out
    }

    /// A new worktree at `path` with `branch` checked out — created there from HEAD when `create`.
    public static func addWorktreeArguments(path: String, branch: String, create: Bool) -> [String] {
        create ? ["worktree", "add", "-b", branch, "--", path] : ["worktree", "add", "--", path, branch]
    }

    public static func removeWorktreeArguments(_ path: String) -> [String] { ["worktree", "remove", "--", path] }

    /// The name or e-mail this repository commits with, or — `value` empty — back to the global one.
    public static func localIdentityArguments(key: String, value: String) -> [String] {
        value.isEmpty ? ["config", "--local", "--unset", key] : ["config", "--local", key, value]
    }

    // MARK: - Push and pull that do not strand the reader (phase 8)

    /// The push for a branch: a plain `push` once it has an upstream; the first push sets one — to
    /// `origin` or the repository's only remote — when `setUpstream` (Settings ▸ Git). nil when there is
    /// no remote to push to at all.
    public static func pushArguments(upstream: String?, remotes: [String], setUpstream: Bool) -> [String]? {
        if upstream != nil || !setUpstream { return ["push"] }
        guard let remote = remotes.contains("origin") ? "origin" : remotes.first else { return nil }
        return ["push", "--set-upstream", remote, "HEAD"]
    }

    /// The push after a rewrite: `--force-with-lease` replaces the remote branch only if it is still
    /// where this repository last saw it — never a plain `--force`, which would throw away commits
    /// somebody else pushed in the meantime. The lease alone is not enough once the panel fetches in the
    /// background: the fetch moves `origin/x` to the colleague's commit and the lease then agrees with it.
    /// `--force-if-includes` also asks that the remote tip be something this branch has had — in its
    /// reflog — so a commit only a fetch has seen still makes the push refuse (git 2.30, measured).
    public static let forcePushArguments = ["push", "--force-with-lease", "--force-if-includes"]

    /// git's messages as the helpers above read them. They match git's English, and git speaks the
    /// system's language when it was built with gettext (Homebrew's is) — so the calls whose refusal is
    /// read run in English; what the reader is shown is git's text either way.
    public static let englishMessagesEnvironment = ["LC_ALL": "en_US.UTF-8", "LANGUAGE": "en"]

    /// Whether `git push` was refused because the remote branch has commits this one does not.
    public static func isRejectedAsBehind(_ output: String) -> Bool {
        output.contains("[rejected]") && (output.contains("non-fast-forward") || output.contains("fetch first"))
    }

    /// Whether `git pull --ff-only` refused because the branches diverged.
    public static func isDivergedPullRefusal(_ output: String) -> Bool {
        output.contains("Not possible to fast-forward") || output.contains("Diverging branches")
            || output.contains("divergent branches")
    }

    /// The pull that joins diverged branches the way the reader chose when asked.
    public static func pullArguments(_ mode: Settings.PullMode) -> [String] {
        var settings = Settings()
        settings.pullMode = mode
        return settings.pullArguments
    }

    // MARK: - Stash with options, LFS, search filters (phase 8)

    /// `git stash push` with what the reader chose: a message, untracked files too, the index kept, or
    /// only some files.
    public static func stashPushArguments(message: String, includeUntracked: Bool, keepIndex: Bool,
                                          paths: [String] = []) -> [String] {
        var out = ["stash", "push"]
        if includeUntracked { out.append("--include-untracked") }
        if keepIndex { out.append("--keep-index") }
        if !message.isEmpty { out += ["-m", message] }
        if !paths.isEmpty { out += ["--"] + paths }
        return out
    }

    public static func lfsLockArguments(_ path: String) -> [String] { ["lfs", "lock", "--", path] }
    public static func lfsUnlockArguments(_ path: String) -> [String] { ["lfs", "unlock", "--", path] }

    /// Track the file type of `path` with LFS: `*.psd` for `art/cover.psd`; nil for a file without an
    /// extension, where a pattern would have to be the file's own name and is better typed by hand.
    public static func lfsTrackArguments(forFileType path: String) -> [String]? {
        let ext = (path as NSString).pathExtension
        guard !ext.isEmpty else { return nil }
        return ["lfs", "track", "*.\(ext)"]
    }

    /// The history search's filters: `author:`, `path:`, `since:` and `until:` take the next word (or a
    /// quoted phrase); everything else is the free text, searched as before.
    public struct SearchQuery: Sendable, Equatable {
        public var text = ""
        public var authors: [String] = []
        public var paths: [String] = []
        public var since: String?
        public var until: String?
        public var hasFilters: Bool { !authors.isEmpty || !paths.isEmpty || since != nil || until != nil }

        public init() {}

        public static func parse(_ input: String) -> SearchQuery {
            var query = SearchQuery()
            var words: [String] = []
            var current = "", quoted = false
            for character in input {
                if character == "\"" { quoted.toggle(); continue }
                if character == " ", !quoted {
                    if !current.isEmpty { words.append(current); current = "" }
                } else {
                    current.append(character)
                }
            }
            if !current.isEmpty { words.append(current) }
            var text: [String] = []
            for word in words {
                let lower = word.lowercased()
                func value(_ prefix: String) -> String? {
                    lower.hasPrefix(prefix) && word.count > prefix.count ? String(word.dropFirst(prefix.count)) : nil
                }
                if let author = value("author:") { query.authors.append(author) }
                else if let path = value("path:") { query.paths.append(path) }
                else if let since = value("since:") { query.since = since }
                else if let until = value("until:") { query.until = until }
                else { text.append(word) }
            }
            query.text = text.joined(separator: " ")
            return query
        }

        /// The `git log` limits the filters stand for — all of them at once (a filter narrows), except
        /// that several `author:`s are any of them: git ORs `--author`, and a commit has one author.
        public var filterArguments: [String] {
            authors.map { "--author=\($0)" } + (since.map { ["--since=\($0)"] } ?? []) + (until.map { ["--until=\($0)"] } ?? [])
        }
    }

    /// The calls for a search with filters: the free text, if any, as the message and author searches
    /// (each narrowed by the filters), or one log narrowed by the filters alone.
    public static func searchArguments(_ query: SearchQuery, limit: Int, all: Bool, refs: [String]? = nil) -> [[String]] {
        let base = logArguments(limit: limit, all: all, dateOrder: true, refs: refs) + ["-i", "-F"] + query.filterArguments
        let pathspec = query.paths.isEmpty ? [] : ["--"] + query.paths
        if query.text.isEmpty { return query.hasFilters ? [base + pathspec] : [] }
        // git ORs `--author`s: the text as one more author would widen an `author:` filter, not
        // narrow it. With an author filter the text is searched in the messages only.
        let byAuthor = query.authors.isEmpty ? [base + ["--author=\(query.text)"] + pathspec] : []
        return [base + ["--grep=\(query.text)"] + pathspec] + byAuthor
    }

    // MARK: - Comparing and picking several (phase 8)

    /// The files that differ between `from` and `to` — or, with `to` nil, between `from` and the working
    /// tree. NUL-separated like `nameStatusArguments`, so `parseNameStatus` reads both.
    public static func compareNameStatusArguments(from: String, to: String?) -> [String] {
        ["--no-optional-locks", "diff", "--name-status", "-z", "-M", from] + (to.map { [$0] } ?? []) + ["--"]
    }

    /// The unified diff of `paths` between the same two.
    public static func compareDiffArguments(from: String, to: String?, paths: [String], options: [String] = []) -> [String] {
        ["--no-optional-locks", "diff", "--no-color", "-M"] + options + [from] + (to.map { [$0] } ?? []) + ["--"] + paths
    }

    /// Cherry-pick several commits, oldest first, so each applies on top of the one before. `commits`
    /// come in the history's order — newest first, topologically — and are simply reversed: a date
    /// cannot order them, since a rebase or `git am` gives a whole series the same second. nil when one
    /// of them is a merge: picking a merge in a series is ambiguous about its mainline, so such a
    /// selection is refused rather than guessed.
    public static func cherryPickSeriesArguments(_ commits: [Commit]) -> [String]? {
        guard !commits.isEmpty, !commits.contains(where: \.isMerge) else { return nil }
        return ["cherry-pick", "--no-edit"] + commits.reversed().map(\.hash)
    }

    /// The tree of an empty repository — what a root commit is compared against, having no parent.
    public static let emptyTree = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

    /// The base for "what these commits changed": the parent of the oldest of them, so its own changes
    /// are included — or the empty tree when it is a root commit. `oldest` is the last in history order.
    public static func comparisonBase(oldest: Commit) -> String {
        oldest.parents.isEmpty ? emptyTree : oldest.hash + "^"
    }

    // MARK: - Branches: rename, upstream, remote deletion (phase 8)

    public static func renameBranchArguments(_ name: String, to newName: String) -> [String] { ["branch", "-m", name, newName] }

    public static func setUpstreamArguments(branch: String, upstream: String) -> [String] {
        ["branch", "--set-upstream-to=\(upstream)", branch]
    }

    /// Delete a branch on its remote: `origin/feature/x` is `feature/x` on `origin` — the remote is the
    /// part before the first slash, the branch may have slashes of its own. nil for a name with no remote.
    public static func deleteRemoteBranchArguments(_ remoteBranch: String) -> [String]? {
        guard let slash = remoteBranch.firstIndex(of: "/") else { return nil }
        let remote = String(remoteBranch[..<slash]), branch = String(remoteBranch[remoteBranch.index(after: slash)...])
        guard !remote.isEmpty, !branch.isEmpty, branch != "HEAD" else { return nil }
        return ["push", remote, "--delete", branch]
    }

    // MARK: - Settings (phase 8)

    /// What the reader can decide about the plugin, kept in `git.ini` under the host's configuration root.
    /// Name and e-mail are not here: they are git's own (`git config`), and the settings page edits them
    /// there, so a commit made in a terminal carries the same ones.
    public struct Settings: Sendable, Equatable {
        public enum PullMode: String, Sendable, CaseIterable { case fastForward = "ff-only", merge, rebase }
        public enum DateStyle: String, Sendable, CaseIterable { case relative, absolute }

        /// The git to run; empty finds one (Homebrew, then the Command Line Tools — see `resolveExecutable`).
        public var gitProgram = ""
        public var pullMode = PullMode.fastForward
        /// The first push of a branch sets its upstream, so the second needs no arguments.
        public var pushSetsUpstream = true
        public var fetchPrunes = true
        /// Fetch in the background every so many minutes while the panel shows a repository; 0 is never.
        public var autoFetchMinutes = 0
        public var historyPageSize = 300
        public var showRemoteBranches = true
        public var showTags = true
        public var showStashes = true
        public var dateStyle = DateStyle.relative
        public var signCommits = false
        public var signOff = false
        /// The commit box shows the subject's length and turns it orange past this.
        public var subjectLength = 72
        /// Pre-commit and commit-msg hooks run; off adds `--no-verify`.
        public var runHooks = true
        public var diffIgnoreWhitespace = false
        public var diffContextLines = 3
        public var cloneRecursive = true
        /// git-flow's branch names and tag prefix (phase 9).
        public var flow = Flow()
        /// Hosts the pull-request tab cannot tell by name — a GitLab or GitHub Enterprise at a company
        /// address — and which they are (phase 9). github.com, gitlab.com and any host with "gitlab" in
        /// its name need no entry.
        public var hostKinds: [String: HostKind] = [:]

        public init() {}

        public static func parse(_ text: String) -> Settings {
            var settings = Settings()
            for line in text.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix(";"), !trimmed.hasPrefix("#"), !trimmed.hasPrefix("["),
                      let equals = trimmed.firstIndex(of: "=") else { continue }
                let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
                func number(_ range: ClosedRange<Int>, _ fallback: Int) -> Int {
                    Int(value).map { min(max($0, range.lowerBound), range.upperBound) } ?? fallback
                }
                switch key {
                case "GitProgram": settings.gitProgram = value
                case "PullMode": settings.pullMode = PullMode(rawValue: value) ?? settings.pullMode
                case "PushSetsUpstream": settings.pushSetsUpstream = value != "0"
                case "FetchPrunes": settings.fetchPrunes = value != "0"
                case "AutoFetchMinutes": settings.autoFetchMinutes = number(0...1440, settings.autoFetchMinutes)
                case "HistoryPageSize": settings.historyPageSize = number(50...5000, settings.historyPageSize)
                case "ShowRemoteBranches": settings.showRemoteBranches = value != "0"
                case "ShowTags": settings.showTags = value != "0"
                case "ShowStashes": settings.showStashes = value != "0"
                case "DateStyle": settings.dateStyle = DateStyle(rawValue: value) ?? settings.dateStyle
                case "SignCommits": settings.signCommits = value == "1"
                case "SignOff": settings.signOff = value == "1"
                case "SubjectLength": settings.subjectLength = number(20...200, settings.subjectLength)
                case "RunHooks": settings.runHooks = value != "0"
                case "DiffIgnoreWhitespace": settings.diffIgnoreWhitespace = value == "1"
                case "DiffContextLines": settings.diffContextLines = number(0...50, settings.diffContextLines)
                case "CloneRecursive": settings.cloneRecursive = value != "0"
                case "FlowMain": if !value.isEmpty { settings.flow.mainBranch = value }
                case "FlowDevelop": if !value.isEmpty { settings.flow.developBranch = value }
                case "FlowFeature": settings.flow.featurePrefix = value
                case "FlowRelease": settings.flow.releasePrefix = value
                case "FlowHotfix": settings.flow.hotfixPrefix = value
                case "FlowTagPrefix": settings.flow.tagPrefix = value
                case _ where key.hasPrefix("Host."):
                    let host = String(key.dropFirst("Host.".count)).lowercased()
                    if !host.isEmpty, let kind = HostKind(rawValue: value) { settings.hostKinds[host] = kind }
                default: break
                }
            }
            return settings
        }

        public func serialized() -> String {
            func flag(_ on: Bool) -> String { on ? "1" : "0" }
            return """
            ; Peach Commander — Git plugin. Written by Settings ▸ Git, safe to edit by hand.
            [Git]
            ; The git to run ("" = find one).
            GitProgram=\(gitProgram)
            ; ff-only, merge or rebase.
            PullMode=\(pullMode.rawValue)
            PushSetsUpstream=\(flag(pushSetsUpstream))
            FetchPrunes=\(flag(fetchPrunes))
            ; Minutes between background fetches; 0 = never.
            AutoFetchMinutes=\(autoFetchMinutes)
            HistoryPageSize=\(historyPageSize)
            ShowRemoteBranches=\(flag(showRemoteBranches))
            ShowTags=\(flag(showTags))
            ShowStashes=\(flag(showStashes))
            ; relative or absolute.
            DateStyle=\(dateStyle.rawValue)
            SignCommits=\(flag(signCommits))
            SignOff=\(flag(signOff))
            SubjectLength=\(subjectLength)
            RunHooks=\(flag(runHooks))
            DiffIgnoreWhitespace=\(flag(diffIgnoreWhitespace))
            DiffContextLines=\(diffContextLines)
            CloneRecursive=\(flag(cloneRecursive))
            ; git-flow: branch names and the prefix of a release's tag.
            FlowMain=\(flow.mainBranch)
            FlowDevelop=\(flow.developBranch)
            FlowFeature=\(flow.featurePrefix)
            FlowRelease=\(flow.releasePrefix)
            FlowHotfix=\(flow.hotfixPrefix)
            FlowTagPrefix=\(flow.tagPrefix)
            ; Hosts by kind (github or gitlab), for the pull requests window: Host.git.example.com=gitlab

            """ + hostKinds.keys.sorted().map { "Host.\($0)=\(hostKinds[$0]!.rawValue)\n" }.joined()
        }

        /// The refs the panel's history walks, by the settings: branches and HEAD always, remote branches
        /// and tags when shown.
        public var historyRefs: [String] {
            ["--branches"] + (showRemoteBranches ? ["--remotes"] : []) + (showTags ? ["--tags"] : []) + ["HEAD"]
        }

        /// `git pull` for the pull mode.
        public var pullArguments: [String] {
            switch pullMode {
            case .fastForward: return ["pull", "--ff-only"]
            case .merge: return ["pull", "--no-rebase", "--no-edit"]
            case .rebase: return ["pull", "--rebase"]
            }
        }

        public var fetchArguments: [String] { ["fetch", "--all"] + (fetchPrunes ? ["--prune"] : []) }

        /// The options a commit takes from the settings.
        public var commitOptions: [String] {
            (signCommits ? ["-S"] : []) + (signOff ? ["--signoff"] : []) + (runHooks ? [] : ["--no-verify"])
        }

        /// The options a diff of a commit takes from the settings.
        public var diffOptions: [String] { ["-U\(diffContextLines)"] + (diffIgnoreWhitespace ? ["-w"] : []) }
    }

    // MARK: - Creating and cloning, recent repositories (phase 7)

    /// The folder `git clone` would create for `url`: its last path component without `.git` — for
    /// `git@host:team/app.git`, `https://host/team/app/` and `/srv/app.git` alike, `app`. nil when the URL
    /// names nothing usable.
    public static func cloneDirectoryName(_ url: String) -> String? {
        var text = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        if text.hasSuffix(".git") { text.removeLast(4) }
        let name = text.split(whereSeparator: { $0 == "/" || $0 == ":" || $0 == "\\" }).last.map(String.init) ?? ""
        return name.isEmpty || name == "." || name == ".." ? nil : name
    }

    /// `git clone` into `directory`, reporting progress on stderr so the host's progress window has lines.
    public static func cloneArguments(url: String, into directory: String) -> [String] {
        ["clone", "--progress", "--end-of-options", url, directory]
    }

    /// The recent-repositories list after `root` was opened: it moves to the front, each root once, at
    /// most `limit`.
    public static func recentRepositories(_ list: [String], opening root: String, limit: Int = 10) -> [String] {
        Array(([root] + list.filter { $0 != root }).prefix(limit))
    }

    // MARK: - Reflog (phase 7)

    /// One move of HEAD, from `git reflog`: where it went, what moved it and when.
    public struct ReflogEntry: Sendable, Equatable {
        public let hash: String
        /// `HEAD@{3}` — the name git takes for it.
        public let selector: String
        /// git's own description of the move: "commit: …", "checkout: moving from a to b", "reset: …".
        public let action: String
        public let subject: String
        public let date: Date
    }

    public static func reflogArguments(limit: Int) -> [String] {
        ["--no-optional-locks", "reflog", "--max-count=\(limit)",
         "--format=%H\(unitSeparator)%gd\(unitSeparator)%gs\(unitSeparator)%s\(unitSeparator)%ct\(recordSeparator)"]
    }

    public static func parseReflog(_ output: String) -> [ReflogEntry] {
        output.components(separatedBy: recordSeparator).compactMap { record in
            let fields = record.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: unitSeparator)
            guard fields.count >= 5, !fields[0].isEmpty else { return nil }
            return ReflogEntry(hash: fields[0], selector: fields[1], action: fields[2], subject: fields[3],
                               date: Date(timeIntervalSince1970: Double(fields[4]) ?? 0))
        }
    }

    /// A reflog entry as a `Commit`, so the history's actions — check out, new branch here — take it.
    public static func commit(of entry: ReflogEntry) -> Commit {
        Commit(hash: entry.hash, shortHash: String(entry.hash.prefix(7)), parents: [], author: "",
               date: entry.date, subject: entry.subject)
    }

    // MARK: - Staging lines (phase 7)

    /// What a partial patch is for. Staging applies it to the index; unstaging and discarding apply it in
    /// reverse — to the index, or to the working tree.
    public enum LinePatchUse: Sendable { case stage, unstage, discard }

    /// A patch holding only the selected lines of a file's diff, for `git apply --recount`.
    ///
    /// `lines` is `parseUnifiedDiff` of `git diff -- path` (staging, discarding) or of `git diff --cached
    /// -- path` (unstaging); `selected` are indices into it. A change line that is not selected must not
    /// move, so it is rewritten the way it stands on the side the patch is applied to: applied forwards, an
    /// unselected `-` line is still there (it becomes context) and an unselected `+` line is not (it is
    /// dropped); applied in reverse it is the other way round. Hunk headers keep their start lines and
    /// `--recount` works out the counts. nil when nothing selected is a change.
    public static func linePatch(path: String, oldPath: String? = nil, lines: [DiffLine], selected: Set<Int>,
                                 use: LinePatchUse) -> String? {
        let reverse = use != .stage
        /// Whether line `index` ends up in the patch at all.
        func willKeep(_ index: Int) -> Bool {
            switch lines[index].kind {
            case .context: return true
            case .added: return selected.contains(index) || reverse
            case .removed: return selected.contains(index) || !reverse
            default: return false
            }
        }
        var hunks: [String] = []
        var index = 0
        while index < lines.count {
            guard lines[index].kind == .hunk else { index += 1; continue }
            var body: [String] = []
            var changes = 0
            var keptPrevious = false
            var cursor = index + 1
            while cursor < lines.count, lines[cursor].kind != .hunk {
                let line = lines[cursor]
                let isSelected = selected.contains(cursor)
                switch line.kind {
                case .context:
                    body.append(" " + line.text); keptPrevious = true
                case .added:
                    if isSelected { body.append("+" + line.text); changes += 1; keptPrevious = true }
                    else if reverse { body.append(" " + line.text); keptPrevious = true }
                    else { keptPrevious = false }
                case .removed:
                    if isSelected { body.append("-" + line.text); changes += 1; keptPrevious = true }
                    else if !reverse { body.append(" " + line.text); keptPrevious = true }
                    else { keptPrevious = false }
                case .meta where line.text.hasPrefix("\\"):
                    if keptPrevious { body.append(line.text) }   // "\ No newline at end of file"
                    // A line without a newline that stays as context cannot have anything after it: the
                    // patch would add lines past a file's unterminated end, which git rejects. Such a
                    // selection is refused rather than rewritten into something else.
                    if keptPrevious, body.count >= 2, body[body.count - 2].hasPrefix(" ") {
                        var next = cursor + 1
                        while next < lines.count, lines[next].kind != .hunk {
                            if willKeep(next) { return nil }
                            next += 1
                        }
                    }
                default:
                    break
                }
                cursor += 1
            }
            if changes > 0 { hunks.append(([lines[index].text] + body).joined(separator: "\n")) }
            index = cursor
        }
        guard !hunks.isEmpty else { return nil }
        let header = "--- a/\(oldPath ?? path)\n+++ b/\(path)\n"
        return header + hunks.joined(separator: "\n") + "\n"
    }

    /// `git apply` for a `linePatch` written to `patchFile`.
    public static func applyLinePatchArguments(_ use: LinePatchUse, patchFile: String) -> [String] {
        switch use {
        case .stage:   return ["apply", "--cached", "--recount", patchFile]
        case .unstage: return ["apply", "--cached", "--recount", "--reverse", patchFile]
        case .discard: return ["apply", "--recount", "--reverse", patchFile]
        }
    }

    /// The change lines of the hunk that holds `row` — "stage this hunk" is "stage these lines".
    public static func hunkLines(containing row: Int, in lines: [DiffLine]) -> Set<Int> {
        guard lines.indices.contains(row) else { return [] }
        var start = row
        while start > 0, lines[start].kind != .hunk { start -= 1 }
        guard lines[start].kind == .hunk else { return [] }
        var out = Set<Int>()
        var cursor = start + 1
        while cursor < lines.count, lines[cursor].kind != .hunk {
            if lines[cursor].kind == .added || lines[cursor].kind == .removed { out.insert(cursor) }
            cursor += 1
        }
        return out
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

    /// `stash list` as commits, for the panel's history (phase 7): hash, the commit it was made on, when,
    /// its name and its subject.
    public static let stashCommitsArguments = [
        "--no-optional-locks", "stash", "list",
        "--format=%H\(unitSeparator)%P\(unitSeparator)%at\(unitSeparator)%gd\(unitSeparator)%gs\(unitSeparator)%ct\(recordSeparator)",
    ]

    /// Each stash as a `Commit` whose one parent is the commit it was made on and whose only ref is its
    /// `stash@{n}` — so the Commit and Changes tabs show it like any commit, against what it was made on.
    /// The stash's other parents (its index, its untracked files) are internal and left out.
    public static func stashCommits(_ output: String) -> [Commit] {
        var out: [Commit] = []
        for record in output.components(separatedBy: recordSeparator) {
            let fields = record.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: unitSeparator)
            guard fields.count >= 5, !fields[0].isEmpty else { continue }
            let base = fields[1].split(separator: " ").first.map(String.init)
            var commit = Commit(hash: fields[0], shortHash: String(fields[0].prefix(7)), parents: base.map { [$0] } ?? [],
                                author: "", date: Date(timeIntervalSince1970: Double(fields[2]) ?? 0), subject: fields[4])
            commit.refs = [Ref(name: fields[3], kind: .stash)]
            if fields.count >= 6, let seconds = Double(fields[5]) { commit.commitDate = Date(timeIntervalSince1970: seconds) }
            out.append(commit)
        }
        return out
    }

    /// Whether this commit is a stash entry from `stashCommits`.
    public static func isStash(_ commit: Commit) -> Bool { commit.refs.contains { $0.kind == .stash } && commit.refs.count == 1 }

    /// The history with each stash placed directly above the commit it was made on, newest stash first
    /// there. A stash whose commit is not loaded is left out: it belongs further down than the list goes.
    public static func historyWithStashes(_ commits: [Commit], stashes: [Commit]) -> [Commit] {
        guard !stashes.isEmpty else { return commits }
        var byBase: [String: [Commit]] = [:]
        for stash in stashes { if let base = stash.parents.first { byBase[base, default: []].append(stash) } }
        var out: [Commit] = []
        for commit in commits {
            out += byBase[commit.hash] ?? []
            out.append(commit)
        }
        return out
    }

    public enum StashAction: String, Sendable { case apply, pop, drop }

    public static func stashArguments(_ action: StashAction, ref: String) -> [String] { ["stash", action.rawValue, ref] }

    /// The `stash@{n}` that names the stash with `hash` *now*, from a fresh `stashCommitsArguments` read.
    /// Positions move whenever a stash is pushed or dropped elsewhere, so acting on the name the history
    /// loaded with could drop a different stash — permanently. nil when it is gone.
    public static func currentStashRef(hash: String, in output: String) -> String? {
        stashCommits(output).first { $0.hash == hash }?.refs.first?.name
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

    /// git's `%D` decoration: `HEAD -> main, origin/main, tag: v1.0` — or, under `--decorate=full`,
    /// `HEAD -> refs/heads/main, refs/remotes/origin/main, tag: refs/tags/v1.0, refs/stash`, where the
    /// prefix and not a guess about slashes says what a name is.
    public static func parseRefs(_ decoration: String) -> [Ref] {
        var refs: [Ref] = []
        for piece in decoration.components(separatedBy: ", ") {
            let text = piece.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            if let full = fullRef(text) {
                refs.append(full)
            } else if text.hasPrefix("HEAD -> ") {
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

    /// One `--decorate=full` piece, or nil when it is in the short form.
    private static func fullRef(_ text: String) -> Ref? {
        var name = text
        var isHead = false
        if name.hasPrefix("HEAD -> ") { name = String(name.dropFirst(8)); isHead = true }
        if name.hasPrefix("tag: ") { name = String(name.dropFirst(5)) }
        for (prefix, kind) in [("refs/heads/", Ref.Kind.branch), ("refs/remotes/", .remote),
                               ("refs/tags/", .tag)] where name.hasPrefix(prefix) {
            return Ref(name: String(name.dropFirst(prefix.count)), kind: isHead ? .head : kind)
        }
        if name == "refs/stash" { return Ref(name: "stash", kind: .stash) }
        return nil
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
    /// `at` tags that commit instead of HEAD (the history's "New tag here…").
    public static func createTagArguments(name: String, message: String?, at commit: String? = nil) -> [String] {
        let target = commit.map { [$0] } ?? []
        guard let message, !message.isEmpty else { return ["tag", name] + target }
        return ["tag", "-a", name, "-m", message] + target
    }

    // MARK: - Recent messages and LFS (phase 7)

    /// The subjects of the reader's own last commits on any branch, for the commit box's list. `author`
    /// is their `user.email`; without one, the last commits of anybody.
    public static func recentMessagesArguments(author: String?) -> [String] {
        var out = ["--no-optional-locks", "log", "--branches", "--max-count=100", "--format=%s"]
        if let author, !author.isEmpty { out += ["-F", "--author=\(author)"] }
        return out
    }

    /// The recent subjects, each once, newest first, at most `limit` — a message used on five commits in a
    /// row is one entry, not five.
    public static func recentMessages(_ output: String, limit: Int = 20) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for line in output.split(separator: "\n") {
            let subject = line.trimmingCharacters(in: .whitespaces)
            guard !subject.isEmpty, seen.insert(subject).inserted else { continue }
            out.append(subject)
            if out.count == limit { break }
        }
        return out
    }

    /// `git check-attr` for which paths Git LFS stores: their `filter` attribute. The paths go to its
    /// standard input (`lfsCheckInput`), not on the command line — a commit touching thousands of deeply
    /// nested files would exceed the argument limit, and every badge would silently disappear.
    public static let lfsCheckArguments = ["check-attr", "--stdin", "-z", "filter"]

    /// The paths for `lfsCheckArguments`' standard input, NUL-separated.
    public static func lfsCheckInput(_ paths: [String]) -> Data {
        Data(paths.map { $0 + "\0" }.joined().utf8)
    }

    /// The paths whose filter is `lfs`, from `lfsCheckArguments`' NUL-separated `path, attribute, value`
    /// triples.
    public static func lfsPaths(_ output: String) -> Set<String> {
        let fields = output.split(separator: "\0", omittingEmptySubsequences: false).map(String.init)
        var out = Set<String>()
        var index = 0
        while index + 2 < fields.count {
            if fields[index + 1] == "filter", fields[index + 2] == "lfs" { out.insert(fields[index]) }
            index += 3
        }
        return out
    }

    // MARK: - Acting on a commit from the history (phase 7)

    /// HEAD on that commit, detached — the history's "Check out this commit". `switch --detach` rather
    /// than `checkout`: it says what it does, and it refuses to carry local changes into a conflict.
    public static func checkoutCommitArguments(_ hash: String) -> [String] { ["switch", "--detach", hash] }

    /// A new branch at that commit, checked out — what "New branch here…" means in every reference product.
    public static func branchAtArguments(name: String, commit: String) -> [String] { ["switch", "-c", name, commit] }

    /// Merge that commit into the current branch, with git's own message and no editor.
    public static func mergeArguments(_ ref: String) -> [String] { ["merge", "--no-edit", ref] }

    /// Replay the current branch on top of that commit.
    public static func rebaseOntoArguments(_ ref: String) -> [String] { ["rebase", ref] }

    public enum ResetMode: String, Sendable, CaseIterable { case soft, mixed, hard }

    /// Move the current branch to that commit. `soft` keeps the changes staged, `mixed` keeps them in the
    /// working tree, `hard` throws them away.
    public static func resetArguments(_ mode: ResetMode, to hash: String) -> [String] {
        ["reset", "--\(mode.rawValue)", hash]
    }

    /// The name to merge or rebase onto: the commit's branch, remote branch or tag when it has one — git
    /// then writes "Merge branch 'feature/x'" instead of a hash — otherwise its hash.
    public static func preferredRefName(_ commit: Commit) -> String {
        for kind in [Ref.Kind.branch, .head, .remote, .tag] {
            if let ref = commit.refs.first(where: { $0.kind == kind && !$0.name.hasSuffix("/HEAD") }) { return ref.name }
        }
        return commit.hash
    }

    /// Whether `hash` is an ancestor of HEAD — the exit status says it. An interactive rebase "from here"
    /// only makes sense below the current branch's tip; from anywhere else it would move the branch.
    public static func isAncestorOfHeadArguments(_ hash: String) -> [String] { ["merge-base", "--is-ancestor", hash, "HEAD"] }

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
    ///
    /// `hasBase`: the rebase starts at a commit the reader chose in the history ("interactive rebase from
    /// here") rather than at the upstream, so a missing upstream is no reason to refuse.
    public static func rebaseRefusal(repo: RepoStatus, aheadCount: Int, actions: [RebaseAction],
                                    rebaseRunning: Bool, hasBase: Bool = false) -> RebaseRefusal? {
        if rebaseRunning { return .rebaseAlreadyRunning }
        if let refusal = refusal(forCommitActionIn: repo) {
            return refusal == .conflictOpen ? .conflictOpen : .dirtyWorkingTree
        }
        if repo.upstream == nil, !hasBase { return .noUpstream }
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

    /// An operation git stopped in the middle of, waiting for the reader (phase 8).
    public enum Operation: String, Sendable, Equatable { case merge, cherryPick, revert, rebase, applyPatches }

    /// Which one is under way, by the files git leaves in its directory for it.
    public static func operationInProgress(gitDir: String, exists: (String) -> Bool) -> Operation? {
        func has(_ name: String) -> Bool { exists((gitDir as NSString).appendingPathComponent(name)) }
        // `git am` keeps its state in rebase-apply too; its own marker says it is am, not a rebase.
        if has("rebase-apply/applying") { return .applyPatches }
        if rebaseIsRunning(gitDir: gitDir, exists: exists) { return .rebase }
        if has("MERGE_HEAD") { return .merge }
        if has("CHERRY_PICK_HEAD") { return .cherryPick }
        if has("REVERT_HEAD") { return .revert }
        return nil
    }

    /// Finishing it. A merge is finished by committing with git's prepared message; the others by
    /// `--continue`, which wants an editor for that message — run them with `GIT_EDITOR=true`.
    public static func continueArguments(_ operation: Operation) -> [String] {
        switch operation {
        case .merge: return ["commit", "--no-edit"]
        case .cherryPick: return ["cherry-pick", "--continue"]
        case .revert: return ["revert", "--continue"]
        case .rebase: return ["rebase", "--continue"]
        case .applyPatches: return ["am", "--continue"]
        }
    }

    public static func abortArguments(_ operation: Operation) -> [String] {
        switch operation {
        case .merge: return ["merge", "--abort"]
        case .cherryPick: return ["cherry-pick", "--abort"]
        case .revert: return ["revert", "--abort"]
        case .rebase: return ["rebase", "--abort"]
        case .applyPatches: return ["am", "--abort"]
        }
    }

    // MARK: - Bisect (phase 8)

    /// Whether a bisect is under way: git keeps its log while it is.
    public static func isBisecting(gitDir: String, exists: (String) -> Bool) -> Bool {
        exists((gitDir as NSString).appendingPathComponent("BISECT_LOG"))
    }

    public enum BisectMark: String, Sendable { case good, bad, skip }

    /// Mark a commit (or, without one, the commit checked out) as good, bad or untestable. A bisect not
    /// yet started is started first — `bisect start` then the mark, two calls.
    public static func bisectArguments(_ mark: BisectMark, commit: String?, started: Bool) -> [[String]] {
        (started ? [] : [["bisect", "start"]]) + [["bisect", mark.rawValue] + (commit.map { [$0] } ?? [])]
    }

    public static let bisectResetArguments = ["bisect", "reset"]

    /// What `git bisect` said: how much is left, or which commit it found.
    public enum BisectProgress: Sendable, Equatable {
        case remaining(revisions: Int, steps: Int)
        case found(String)
        case waiting
    }

    public static func parseBisect(_ output: String) -> BisectProgress {
        for line in output.split(separator: "\n").map(String.init) {
            if line.hasSuffix(" is the first bad commit") {
                return .found(String(line.dropLast(" is the first bad commit".count)))
            }
            if line.hasPrefix("Bisecting: ") {
                let numbers = line.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
                return .remaining(revisions: numbers.first ?? 0, steps: numbers.count > 1 ? numbers[1] : 0)
            }
        }
        return .waiting
    }

    // MARK: - Patches (phase 8)

    /// One commit as a mail-style patch on standard output, numbered `number` when several are saved.
    public static func formatPatchArguments(_ hash: String) -> [String] {
        ["format-patch", "-1", "--stdout", hash]
    }

    /// A file name for a commit's patch: `0001-the-subject.patch`, as `git format-patch` names them.
    public static func patchFileName(number: Int, subject: String) -> String {
        let slug = subject.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
            .split(separator: "-").joined(separator: "-")
        return String(format: "%04d-%@.patch", number, String(slug.prefix(52)))
    }

    /// Apply mailbox patches as commits, falling back to a three-way merge where they do not apply cleanly.
    public static func applyPatchesArguments(_ files: [String]) -> [String] { ["am", "--3way", "--"] + files }

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

    // MARK: - Blame in the host's gutter (F-426)

    /// The wire format the host's `annotateLines` reads: one record per source line, `text\ttooltip`.
    ///
    /// Kept here, next to the parsing of `blame --porcelain`, and unit-tested — the buffer is the whole
    /// interface to the gutter, and a record count that disagrees with the file shifts every annotation
    /// against the line it describes, which is worse than showing nothing.
    ///
    /// `dateText` is passed in rather than formatted here: a date's rendering is the host's locale's
    /// business, and this file stays free of user-facing text.
    public static func gutterAnnotations(_ lines: [BlameLine],
                                        dateText: (Date) -> String,
                                        uncommittedLabel: String) -> String {
        guard let highest = lines.map(\.line).max() else { return "" }
        // Indexed by line number, because `blame` may skip lines (it does not, today) and because the
        // host's reader is "record N describes line N".
        var records = [String](repeating: "", count: highest)
        for line in lines {
            guard line.line >= 1, line.line <= highest else { continue }
            let text: String
            let tooltip: String
            if line.isUncommitted {
                text = uncommittedLabel
                tooltip = uncommittedLabel
            } else {
                text = "\(String(line.hash.prefix(8)))  \(line.author)"
                tooltip = "\(String(line.hash.prefix(8)))  \(line.author)  \(dateText(line.date))"
                    + (line.summary.isEmpty ? "" : "  ·  \(line.summary)")
            }
            // A tab separates the two fields and a newline separates records, so neither field may contain
            // either. A newline in a tooltip was the first version of this and the test caught it: it
            // splits one record into two and shifts every annotation after it against the line it
            // describes — which looks like blame that is simply wrong rather than like a format defect.
            records[line.line - 1] = Self.oneLine(text) + "\t" + Self.oneLine(tooltip)
        }
        return records.joined(separator: "\n") + "\n"
    }

    /// A field of the gutter's wire format: no tabs, no newlines.
    static func oneLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r\n", with: " · ")
            .replacingOccurrences(of: "\n", with: " · ")
            .replacingOccurrences(of: "\r", with: " · ")
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
    public static func revertArguments(_ hash: String, isMerge: Bool = false) -> [String] {
        ["revert", "--no-edit"] + (isMerge ? ["-m", "1"] : []) + [hash]
    }

    ///
    /// `isMerge`: a merge commit has two parents, and git refuses to pick or revert one without being told
    /// which side is the mainline — `-m 1`, the branch it was merged into, is what is meant every time.
    public static func cherryPickArguments(_ hash: String, isMerge: Bool = false) -> [String] {
        ["cherry-pick", "--no-edit"] + (isMerge ? ["-m", "1"] : []) + [hash]
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

    /// The SF Symbol for a status, for a host that can draw one in the column (F-428).
    ///
    /// Chosen for what they mean at 13 points rather than for looking like git: a conflict is the one a
    /// reader must not miss, so it gets the warning triangle every other part of macOS uses for that.
    public static func symbolName(for change: Change) -> String? {
        switch change {
        case .conflict:    return "exclamationmark.triangle.fill"
        case .added:       return "plus.circle.fill"
        case .deleted:     return "minus.circle.fill"
        case .modified:    return "pencil.circle.fill"
        case .renamed:     return "arrow.right.circle.fill"
        case .copied:      return "doc.on.doc.fill"
        case .typeChanged: return "arrow.triangle.2.circlepath.circle.fill"
        case .untracked:   return "questionmark.circle"
        case .ignored:     return "circle.dotted"
        case .unchanged:   return nil
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

// MARK: - Phase 9: the tree at any commit, git-flow, the merge editor

extension PluginGit {

    // MARK: The Files tab — the tree at a commit

    /// Every file in a commit's tree, NUL-separated so a name outside ASCII arrives as it is.
    public static func treeFilesArguments(_ commit: String) -> [String] {
        ["--no-optional-locks", "ls-tree", "-r", "-z", "--full-tree", "--name-only", commit]
    }

    /// `ls-tree`'s names as files without a status — the Files tab reuses the changes tree.
    public static func parseTreeFiles(_ output: String) -> [ChangedFile] {
        output.split(separator: "\0").map { ChangedFile(status: "", path: String($0)) }
    }

    /// A file's text at a commit, numbered like a diff's context so the same view shows it. Binary
    /// (a NUL in the first 8000 bytes, git's own test) gives no lines; past `limit` lines it is cut.
    public static func fileContentLines(_ data: Data, limit: Int = 5000)
        -> (lines: [DiffLine], truncated: Bool, binary: Bool) {
        if data.prefix(8000).contains(0) { return ([], false, true) }
        var text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
        if text.hasSuffix("\n") { text.removeLast() }
        if text.isEmpty { return ([], false, false) }
        let all = text.components(separatedBy: "\n")
        let lines = all.prefix(limit).enumerated().map { DiffLine(kind: .context, text: $1, newLine: $0 + 1) }
        return (lines, all.count > limit, false)
    }

    /// A file's content at a commit as a checkout would write it — through its smudge and line-ending
    /// filters, so an LFS file is the file and not its pointer. For saving a version somewhere else.
    public static func checkoutContentArguments(commit: String, path: String) -> [String] {
        ["--no-optional-locks", "cat-file", "--filters", "\(commit):\(path)"]
    }

    /// Put a file back in the working tree as it was at `commit` — the index is left alone, so the
    /// change shows as an ordinary modification to stage or discard.
    public static func restoreFileArguments(commit: String, path: String) -> [String] {
        ["restore", "--source=\(commit)", "--worktree", "--", path]
    }

    // MARK: git-flow

    /// The branch kinds of git-flow. A convention, not a feature of git: the names and the merges are
    /// all it is.
    public enum FlowKind: String, Sendable, CaseIterable { case feature, release, hotfix }

    public struct Flow: Sendable, Equatable {
        public var mainBranch = "main"
        public var developBranch = "develop"
        public var featurePrefix = "feature/"
        public var releasePrefix = "release/"
        public var hotfixPrefix = "hotfix/"
        /// Put before a release's or a hotfix's name in its tag: "v" makes 1.2 the tag v1.2.
        public var tagPrefix = ""
        public init() {}

        public func prefix(_ kind: FlowKind) -> String {
            switch kind {
            case .feature: return featurePrefix
            case .release: return releasePrefix
            case .hotfix: return hotfixPrefix
            }
        }

        /// Where a kind starts from: features and releases from develop, hotfixes from main.
        public func base(_ kind: FlowKind) -> String { kind == .hotfix ? mainBranch : developBranch }

        /// The kind and name of a flow branch, or nil for any other branch.
        public func kind(ofBranch branch: String) -> (kind: FlowKind, name: String)? {
            for kind in FlowKind.allCases {
                let prefix = prefix(kind)
                if !prefix.isEmpty, branch.hasPrefix(prefix), branch.count > prefix.count {
                    return (kind, String(branch.dropFirst(prefix.count)))
                }
            }
            return nil
        }

        public func tag(for name: String) -> String { tagPrefix + name }
    }

    /// Start a flow branch — after creating develop from main when the repository has no develop yet.
    /// `remoteDevelop`: develop as a remote branch (`origin/develop`) when there is no local one — a fresh
    /// clone of a git-flow repository — which the local develop then tracks instead of being made anew
    /// from main and going its own way.
    public static func flowStartArguments(_ kind: FlowKind, name: String, flow: Flow,
                                          hasDevelop: Bool, remoteDevelop: String? = nil) -> [[String]] {
        var calls: [[String]] = []
        if !hasDevelop, kind != .hotfix {
            if let remoteDevelop {
                calls.append(["branch", "--track", flow.developBranch, remoteDevelop])
            } else {
                calls.append(["branch", flow.developBranch, flow.mainBranch])
            }
        }
        calls.append(["switch", "-c", flow.prefix(kind) + name, flow.base(kind)])
        return calls
    }

    /// What finishing a flow branch has already done — so finishing again after a merge conflict picks
    /// up where it stopped instead of merging or tagging twice.
    public struct FlowFinishState: Sendable, Equatable {
        public var mergedIntoMain = false
        public var tagged = false
        public var mergedIntoDevelop = false
        public init(mergedIntoMain: Bool = false, tagged: Bool = false, mergedIntoDevelop: Bool = false) {
            self.mergedIntoMain = mergedIntoMain; self.tagged = tagged; self.mergedIntoDevelop = mergedIntoDevelop
        }
    }

    /// Finish a flow branch: a feature merges into develop; a release or a hotfix merges into main, is
    /// tagged there and merges into develop. Merges are `--no-ff`, so the branch stays visible in the
    /// graph. The branch is deleted last, with `-d`, which refuses if anything was left unmerged.
    public static func flowFinishArguments(_ kind: FlowKind, name: String, flow: Flow,
                                           state: FlowFinishState) -> [[String]] {
        let branch = flow.prefix(kind) + name
        func merge(into target: String) -> [[String]] {
            [["switch", target], ["merge", "--no-ff", "--no-edit", branch]]
        }
        var calls: [[String]] = []
        if kind != .feature {
            if !state.mergedIntoMain { calls += merge(into: flow.mainBranch) }
            if !state.tagged {
                let message = (kind == .release ? "Release " : "Hotfix ") + name
                calls.append(["tag", "-a", flow.tag(for: name), "-m", message, flow.mainBranch])
            }
        }
        if !state.mergedIntoDevelop { calls += merge(into: flow.developBranch) }
        calls.append(["branch", "-d", branch])
        return calls
    }

    /// Asked before finishing: is `branch` already in `target`?
    public static func isAncestorArguments(_ branch: String, of target: String) -> [String] {
        ["merge-base", "--is-ancestor", branch, target]
    }

    /// The remote branches named `name` (`origin/develop`, `upstream/develop`), one per line.
    public static func remoteBranchesArguments(named name: String) -> [String] {
        ["--no-optional-locks", "for-each-ref", "--format=%(refname:lstrip=2)", "refs/remotes/*/\(name)"]
    }

    /// The one to follow among them: origin's when there is one.
    public static func preferredRemoteBranch(_ lines: String) -> String? {
        let names = lines.split(separator: "\n").map(String.init)
        return names.first { $0.hasPrefix("origin/") } ?? names.first
    }

    /// The local branches by name, one per line.
    public static let localBranchNamesArguments = ["--no-optional-locks", "for-each-ref", "--format=%(refname:short)", "refs/heads"]

    public static func tagExistsArguments(_ tag: String) -> [String] {
        ["rev-parse", "-q", "--verify", "refs/tags/" + tag]
    }

    /// A name git accepts as part of a branch name — checked before the dialog closes, so a typo does
    /// not end in git's "is not a valid branch name".
    public static func isValidFlowName(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("-"), !name.hasPrefix("/"), !name.hasSuffix("/"),
              !name.hasSuffix("."), !name.hasSuffix(".lock"), !name.contains(".."), !name.contains("//"),
              !name.contains("@{") else { return false }
        let forbidden = CharacterSet(charactersIn: " ~^:?*[\\").union(.controlCharacters)
        return name.unicodeScalars.allSatisfy { !forbidden.contains($0) }
    }

    // MARK: The merge editor

    /// The three versions git keeps in the index for a conflicted file: base (stage 1), ours (2) and
    /// theirs (3). A side missing (added on one side only) is simply not there.
    public static func mergeStageSpec(_ stage: Int, path: String) -> String { ":\(stage):\(path)" }

    /// Merge the three again, in memory: with `diff3` the base stands between the markers. Exit status
    /// is the number of conflicts, so a non-zero one is the expected outcome, not a failure.
    public static func mergeFileArguments(ours: String, base: String, theirs: String,
                                          labels: (ours: String, base: String, theirs: String),
                                          diff3: Bool = true) -> [String] {
        ["merge-file", "-p"] + (diff3 ? ["--diff3"] : [])
            + ["-L", labels.ours, "-L", labels.base, "-L", labels.theirs, ours, base, theirs]
    }

    /// The text the merge editor starts from: git's diff3 re-merge — every hunk with its base — when the
    /// working file is still exactly what the merge left (compared with a re-merge in git's own style,
    /// labels aside). Not hunk by hunk: git's merge joins conflicts a line or two apart into one, the
    /// diff3 style keeps them apart, so the two cannot be matched up — measured. Once the reader has
    /// resolved or edited anything, nil, and the editor works on the file as it is, without a base:
    /// what they did stays.
    public static func adoptBase(working: String, merged: String, diff3: String) -> String? {
        guard let file = parseConflicts(working), let again = parseConflicts(merged),
              var withBase = parseConflicts(diff3), !file.hunks.isEmpty,
              file.segments == again.segments,
              zip(file.hunks, again.hunks).allSatisfy({ $0.ours == $1.ours && $0.theirs == $1.theirs }),
              file.hunks.count == again.hunks.count,
              withBase.hunks.allSatisfy({ $0.base != nil }) else { return nil }
        withBase.usesCRLF = file.usesCRLF
        withBase.endsWithNewline = file.endsWithNewline
        return render(withBase, choices: [])
    }

    /// What the reader can take for one hunk in the merge editor.
    public enum MergePick: String, Sendable, CaseIterable { case ours, theirs, oursThenTheirs, theirsThenOurs, base }

    public static func lines(of hunk: ConflictHunk, _ pick: MergePick) -> [String]? {
        switch pick {
        case .ours: return hunk.ours
        case .theirs: return hunk.theirs
        case .oursThenTheirs: return hunk.ours + hunk.theirs
        case .theirsThenOurs: return hunk.theirs + hunk.ours
        case .base: return hunk.base
        }
    }

    /// The text with one hunk replaced by `lines` and every other hunk left as markers.
    public static func resolving(_ file: ConflictFile, hunk index: Int, with lines: [String]) -> String {
        var copy = file
        guard copy.hunks.indices.contains(index) else { return render(file, choices: []) }
        // Rendered through `render` with the hunk turned into plain text, so CRLF and the final newline
        // are handled in the one place that already knows how.
        copy.segments = copy.segments.map { segment in
            if case .conflict(let i) = segment, i == index { return .text(lines) }
            return segment
        }
        return render(copy, choices: [])
    }

    /// For the side-by-side panes: which of a side's lines differ from the base (all of them when there
    /// is no base). By content, not by position — enough to make a changed line stand out.
    public static func changedLines(_ side: [String], base: [String]?) -> Set<Int> {
        guard let base else { return Set(side.indices) }
        var remaining: [String: Int] = [:]
        for line in base { remaining[line, default: 0] += 1 }
        var changed = Set<Int>()
        for (index, line) in side.enumerated() {
            if let count = remaining[line], count > 0 { remaining[line] = count - 1 } else { changed.insert(index) }
        }
        return changed
    }

    /// The 0-based line of the `index`-th `<<<<<<<` marker in `text`, for scrolling the result to it.
    public static func markerLine(of index: Int, in text: String, markerLength: Int = 7) -> Int? {
        let run = String(repeating: "<", count: markerLength)
        var seen = 0
        for (line, content) in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n").enumerated()
        where content == run || content.hasPrefix(run + " ") {
            if seen == index { return line }
            seen += 1
        }
        return nil
    }
}
