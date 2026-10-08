// SPDX-License-Identifier: Apache-2.0
// PluginGitTests.swift - Reading git's machine-readable status (F-415, Git plugin phase 0).
//
// The defect that started this: the plugin parsed `git status --porcelain` (v1), which quotes any path
// outside ASCII — measured in a scratch repository as `A  "Gr\303\266\303\237e mit Leerzeichen.txt"` —
// and used that text as a path, so the Git Status column stayed empty for every file with an umlaut in
// its name. v1 also cannot say whether a change is staged, which the commit command needs.
//
// The fixture strings below are real output shapes with NULs written as \0. `testAgainstRealGit` runs
// the actual binary over a repository built for the case, so the fixtures cannot drift into fiction.

import XCTest

final class PluginGitTests: XCTestCase {

    // MARK: - Header

    func testBranchAheadBehindAndUpstream() {
        let out = "# branch.oid abc123\0# branch.head feature/x\0# branch.upstream origin/feature/x\0"
            + "# branch.ab +2 -3\0"
        let status = PluginGit.parseStatus(out)
        XCTAssertEqual(status.branch, "feature/x")
        XCTAssertEqual(status.upstream, "origin/feature/x")
        XCTAssertEqual(status.ahead, 2)
        XCTAssertEqual(status.behind, 3)
        XCTAssertFalse(status.detached)
    }

    func testDetachedHead() {
        let status = PluginGit.parseStatus("# branch.oid abc\0# branch.head (detached)\0")
        XCTAssertTrue(status.detached)
        XCTAssertEqual(status.branch, "")
    }

    // MARK: - Files

    /// The case the column was blank for. In v2 the path is raw, umlaut and space included.
    func testNonASCIIAndSpacesInPaths() {
        let out = "1 A. N... 000000 100644 100644 000 abc Größe mit Leerzeichen.txt\0"
        let status = PluginGit.parseStatus(out)
        XCTAssertEqual(status.files.keys.sorted(), ["Größe mit Leerzeichen.txt"])
        XCTAssertEqual(status.files["Größe mit Leerzeichen.txt"]?.staged, .added)
        XCTAssertEqual(status.files["Größe mit Leerzeichen.txt"]?.worktree, .unchanged)
    }

    func testStagedAndUnstagedAreSeparate() {
        // "MM": staged modification plus a further unstaged one.
        let out = "1 MM N... 100644 100644 100644 aaa bbb src/app.swift\0"
        let file = PluginGit.parseStatus(out).files["src/app.swift"]
        XCTAssertEqual(file?.staged, .modified)
        XCTAssertEqual(file?.worktree, .modified)
        XCTAssertTrue(file?.isStaged == true)
        XCTAssertEqual(file?.summary, .modified)
    }

    /// A rename record carries two paths separated by a further NUL. Consuming only one shifts every
    /// path after it by one record — the shape of defect that reads as "some files show the wrong status".
    func testRenameCarriesTwoPathsWithoutShiftingTheRest() {
        let out = "2 R. N... 100644 100644 100644 aaa bbb R100 new/name.txt\0old/name.txt\0"
            + "1 .M N... 100644 100644 100644 ccc ddd after.txt\0"
        let status = PluginGit.parseStatus(out)
        XCTAssertEqual(status.files.keys.sorted(), ["after.txt", "new/name.txt"])
        XCTAssertEqual(status.files["new/name.txt"]?.originalPath, "old/name.txt")
        XCTAssertEqual(status.files["new/name.txt"]?.staged, .renamed)
        XCTAssertEqual(status.files["after.txt"]?.worktree, .modified,
                       "the record after a rename must not be swallowed")
    }

    func testUnmergedIsAConflict() {
        let out = "u UU N... 100644 100644 100644 100644 aaa bbb ccc conflicted.txt\0"
        let file = PluginGit.parseStatus(out).files["conflicted.txt"]
        XCTAssertEqual(file?.summary, .conflict)
    }

    func testUntrackedAndIgnored() {
        let status = PluginGit.parseStatus("? new.txt\0! build/output.o\0")
        XCTAssertEqual(status.files["new.txt"]?.worktree, .untracked)
        XCTAssertEqual(status.files["build/output.o"]?.worktree, .ignored)
    }

    func testEmptyOutputIsACleanRepository() {
        let status = PluginGit.parseStatus("# branch.head main\0")
        XCTAssertEqual(status.branch, "main")
        XCTAssertTrue(status.files.isEmpty)
    }

    func testGarbageIsIgnoredRatherThanCrashing() {
        let status = PluginGit.parseStatus("1 too short\0nonsense\0? ok.txt\0")
        XCTAssertEqual(status.files.keys.sorted(), ["ok.txt"])
    }

    /// Conflicts first, then staged, then modified, then untracked — the order the panel shows.
    func testOrderedPutsConflictsFirstAndUntrackedLast() {
        let out = "? z-untracked.txt\0"
            + "1 .M N... 100644 100644 100644 a b m-modified.txt\0"
            + "1 M. N... 100644 100644 100644 a b s-staged.txt\0"
            + "u UU N... 100644 100644 100644 100644 a b c c-conflict.txt\0"
        XCTAssertEqual(PluginGit.parseStatus(out).ordered.map(\.path),
                       ["c-conflict.txt", "s-staged.txt", "m-modified.txt", "z-untracked.txt"])
    }

    // MARK: - Which git

    func testTheSettingWins() {
        let git = PluginGit.resolveExecutable(setting: "/opt/mygit/bin/git",
                                             isExecutable: { _ in true }, exists: { _ in true })
        XCTAssertEqual(git, "/opt/mygit/bin/git")
    }

    func testHomebrewBeatsTheShim() {
        let git = PluginGit.resolveExecutable(setting: nil,
                                             isExecutable: { $0 == "/opt/homebrew/bin/git" || $0 == "/usr/bin/git" },
                                             exists: { _ in true })
        XCTAssertEqual(git, "/opt/homebrew/bin/git")
    }

    /// The point of the whole policy: with no toolchain behind it, `/usr/bin/git` is a shim that opens
    /// the Command Line Tools installer. A column value must never do that.
    func testTheShimIsSkippedWhenTheToolchainIsAbsent() {
        let git = PluginGit.resolveExecutable(setting: nil,
                                             isExecutable: { $0 == "/usr/bin/git" },
                                             exists: { _ in false })
        XCTAssertNil(git)
    }

    func testTheShimIsUsedWhenTheToolchainIsPresent() {
        let git = PluginGit.resolveExecutable(
            setting: nil,
            isExecutable: { $0 == "/usr/bin/git" },
            exists: { $0 == "/Library/Developer/CommandLineTools/usr/bin/git" })
        XCTAssertEqual(git, "/usr/bin/git")
    }

    // MARK: - Paths

    /// Two defects in a row here, and the second is why this asks git instead of comparing strings: git
    /// answers `--show-toplevel` as `/private/tmp/r` while the host hands over `/tmp/r`, and
    /// `NSString.resolvingSymlinksInPath` maps `/private/tmp` *back* to `/tmp` — so "resolve, then compare
    /// prefixes" failed in both directions. Measured twice in the running app: the status column empty
    /// while the branch column, which needs no relative path, worked.
    func testParseLocate() {
        let top = PluginGit.parseLocate("/private/tmp/r\n\n")
        XCTAssertEqual(top?.root, "/private/tmp/r")
        XCTAssertEqual(top?.prefix, "")
        let sub = PluginGit.parseLocate("/private/tmp/r\nsrc/deep/\n")
        XCTAssertEqual(sub?.prefix, "src/deep/")
        XCTAssertNil(PluginGit.parseLocate(""), "not a repository")
    }

    func testRelativePathFromPrefixAndName() {
        XCTAssertEqual(PluginGit.relativePath(prefix: "", name: "app.swift"), "app.swift")
        XCTAssertEqual(PluginGit.relativePath(prefix: "src/", name: "app.swift"), "src/app.swift")
        XCTAssertEqual(PluginGit.relativePath(prefix: "src", name: "app.swift"), "src/app.swift",
                       "a prefix without its trailing slash must still work")
        XCTAssertEqual(PluginGit.relativePath(prefix: "/src/", name: "a"), "src/a")
    }

    func testRelativePathOfADirectory() {
        XCTAssertEqual(PluginGit.relativePath(directoryPrefix: "src/deep/"), "src/deep")
        XCTAssertEqual(PluginGit.relativePath(directoryPrefix: ""), "", "the repository root itself")
    }

    // MARK: - Cache freshness

    func testAChangedIndexInvalidatesImmediately() {
        let now = Date()
        XCTAssertFalse(PluginGit.cacheIsFresh(cachedIndexMTime: Date(timeIntervalSince1970: 1),
                                              currentIndexMTime: Date(timeIntervalSince1970: 2),
                                              cachedAt: now, now: now))
    }

    func testAnUnchangedIndexStaysFreshUntilTheTTL() {
        let stamp = Date(timeIntervalSince1970: 1000)
        let mtime = Date(timeIntervalSince1970: 1)
        XCTAssertTrue(PluginGit.cacheIsFresh(cachedIndexMTime: mtime, currentIndexMTime: mtime,
                                             cachedAt: stamp, now: stamp.addingTimeInterval(2)))
        XCTAssertFalse(PluginGit.cacheIsFresh(cachedIndexMTime: mtime, currentIndexMTime: mtime,
                                              cachedAt: stamp, now: stamp.addingTimeInterval(4)))
    }

    // MARK: - The panel's model (phase 1)

    /// A file can be staged *and* changed again, and then belongs in both lists: staging it once more and
    /// committing what is already staged are different actions on the same file.
    func testAFileStagedAndChangedAgainIsInBothSections() {
        let file = PluginGit.FileStatus(path: "a.txt", staged: .modified, worktree: .modified)
        XCTAssertEqual(PluginGit.sections(for: file), [.staged, .changed])
    }

    func testSectionsForTheSimpleCases() {
        XCTAssertEqual(PluginGit.sections(for: .init(path: "a", staged: .modified, worktree: .unchanged)),
                       [.staged])
        XCTAssertEqual(PluginGit.sections(for: .init(path: "a", staged: .unchanged, worktree: .modified)),
                       [.changed])
        XCTAssertEqual(PluginGit.sections(for: .init(path: "a", staged: .unchanged, worktree: .untracked)),
                       [.untracked])
        XCTAssertEqual(PluginGit.sections(for: .init(path: "a", staged: .conflict, worktree: .conflict)),
                       [.conflicts], "a conflict is not also a staged change")
        XCTAssertEqual(PluginGit.sections(for: .init(path: "a", staged: .unchanged, worktree: .ignored)),
                       [], "ignored files are not the panel's business")
    }

    func testGroupedOrderAndContents() {
        let status = PluginGit.parseStatus(
            "? u.txt\0"
            + "1 .M N... 100644 100644 100644 a b c.txt\0"
            + "1 M. N... 100644 100644 100644 a b s.txt\0"
            + "u UU N... 100644 100644 100644 100644 a b c k.txt\0")
        let grouped = PluginGit.grouped(status)
        XCTAssertEqual(grouped.map(\.section), [.conflicts, .staged, .changed, .untracked])
        XCTAssertEqual(grouped.map { $0.files.map(\.path) }, [["k.txt"], ["s.txt"], ["c.txt"], ["u.txt"]])
    }

    /// What "diff" means depends on which list the file was picked from — index against HEAD for a staged
    /// file, working tree against the index for a changed one, and nothing for an untracked one.
    func testDiffBaseAndSpec() {
        let file = PluginGit.FileStatus(path: "src/a.swift", staged: .modified, worktree: .modified)
        XCTAssertEqual(PluginGit.diffBase(for: file, section: .staged), .head)
        XCTAssertEqual(PluginGit.diffBase(for: file, section: .changed), .index)
        XCTAssertEqual(PluginGit.diffBase(for: file, section: .untracked), PluginGit.DiffBase.none)
        XCTAssertEqual(PluginGit.showSpec(base: .head, path: "src/a.swift"), "HEAD:src/a.swift")
        XCTAssertEqual(PluginGit.showSpec(base: .index, path: "src/a.swift"), ":src/a.swift")
        XCTAssertNil(PluginGit.showSpec(base: PluginGit.DiffBase.none, path: "src/a.swift"))
        XCTAssertEqual(PluginGit.diffTitle(base: .head, path: "src/a.swift"), "HEAD:src/a.swift")
    }

    /// The temp file keeps its extension, or the compare window highlights a Swift file as plain text.
    func testBlobFileNameKeepsTheExtension() {
        XCTAssertEqual(PluginGit.blobFileName(path: "src/app.swift", base: .head, token: "1A"),
                       "app@HEAD-1A.swift")
        XCTAssertEqual(PluginGit.blobFileName(path: "Makefile", base: .index, token: "2B"),
                       "Makefile@index-2B")
    }

    // MARK: - History and the lane graph (phase 2)

    private func logRecord(_ hash: String, _ short: String, _ parents: String,
                           _ author: String, _ time: String, _ subject: String) -> String {
        [hash, short, parents, author, time, subject].joined(separator: "\u{1F}") + "\u{1E}"
    }

    func testParseLog() {
        let out = logRecord("a1", "a1s", "b2 c3", "Ada", "1700000000", "Merge branch 'x'")
            + logRecord("b2", "b2s", "d4", "Grace", "1699999000", "Fix: a subject with | and \t in it")
        let commits = PluginGit.parseLog(out)
        XCTAssertEqual(commits.count, 2)
        XCTAssertEqual(commits[0].parents, ["b2", "c3"])
        XCTAssertTrue(commits[0].isMerge)
        XCTAssertEqual(commits[1].author, "Grace")
        XCTAssertEqual(commits[1].subject, "Fix: a subject with | and \t in it",
                       "the separators are ASCII US/RS precisely so a subject may contain anything")
        XCTAssertEqual(commits[1].date, Date(timeIntervalSince1970: 1699999000))
        XCTAssertFalse(commits[1].isMerge)
    }

    func testLogArgumentsAskForTopologicalOrder() {
        // Date order can list a parent before its child, and then a lane never closes (see `graph`).
        XCTAssertTrue(PluginGit.logArguments(limit: 10).contains("--topo-order"))
    }

    func testLogArgumentsFollowAFileOnlyWhenGivenOne() {
        XCTAssertFalse(PluginGit.logArguments(limit: 50).contains("--follow"))
        let forFile = PluginGit.logArguments(limit: 50, path: "src/app.swift")
        XCTAssertTrue(forFile.contains("--follow"))
        XCTAssertEqual(forFile.last, "src/app.swift")
    }

    /// A straight line of commits stays in one lane.
    func testGraphOfALinearHistory() {
        let commits = PluginGit.parseLog(
            logRecord("a", "a", "b", "A", "3", "third")
            + logRecord("b", "b", "c", "A", "2", "second")
            + logRecord("c", "c", "", "A", "1", "first"))
        let rows = PluginGit.graph(commits)
        XCTAssertEqual(rows.map(\.lane), [0, 0, 0])
        XCTAssertEqual(rows.map { PluginGit.graphText($0, width: 1) }, ["●", "●", "●"])
    }

    /// A merge puts its second parent in a new lane, and the commits of that branch then occupy it.
    func testGraphOfAMerge() {
        let commits = PluginGit.parseLog(
            logRecord("m", "m", "a b", "A", "5", "merge")
            + logRecord("a", "a", "base", "A", "4", "on main")
            + logRecord("b", "b", "base", "A", "3", "on branch")
            + logRecord("base", "base", "", "A", "1", "base"))
        let rows = PluginGit.graph(commits)
        XCTAssertEqual(rows[0].lane, 0)
        XCTAssertEqual(rows[0].merged, [1], "the second parent takes a free lane")
        XCTAssertEqual(rows[1].lane, 0, "the first parent continues the merge's lane")
        XCTAssertEqual(rows[2].lane, 1, "the branch commit sits in the lane its parent was put in")
        XCTAssertEqual(rows[3].lane, 0, "the base is waited for by lane 0 first")
        XCTAssertTrue(PluginGit.graphText(rows[0], width: 2).contains("●"))
    }

    /// Two lanes waiting for the same commit converge there: the second one must **end**, or the graph
    /// claims a branch continues past the commit that absorbed it (`git log --graph` draws `|/`).
    func testConvergingLanesEnd() {
        let commits = PluginGit.parseLog(
            logRecord("m", "m", "a b", "A", "5", "merge")
            + logRecord("a", "a", "base", "A", "4", "on main")
            + logRecord("b", "b", "base", "A", "3", "on branch")
            + logRecord("base", "base", "", "A", "1", "base"))
        let rows = PluginGit.graph(commits)
        XCTAssertEqual(rows[3].lane, 0)
        XCTAssertEqual(rows[3].closed, [1], "lane 1 was waiting for base too and ends there")
        XCTAssertTrue(PluginGit.graphText(rows[3], width: 2).contains("┘"))
    }

    // MARK: - The panel's history (phase 6)

    func testAllHistoryNamesTheRefsItWalks() {
        let args = PluginGit.logArguments(limit: 10, all: true)
        for ref in ["--branches", "--remotes", "--tags", "HEAD"] { XCTAssertTrue(args.contains(ref), ref) }
        XCTAssertFalse(args.contains("--all"),
                       "--all walks refs/stash, whose internal index and untracked commits are not history")
        XCTAssertFalse(PluginGit.logArguments(limit: 10).contains("--branches"))
    }

    func testEveryLogAsksForFullDecoration() {
        // The short form cannot tell a local feature/x from origin/main — with or without `all`.
        XCTAssertTrue(PluginGit.logArguments(limit: 10).contains("--decorate=full"))
        XCTAssertTrue(PluginGit.logArguments(limit: 10, all: true).contains("--decorate=full"))
        XCTAssertTrue(PluginGit.logArguments(limit: 10, path: "a.swift").contains("--decorate=full"))
    }

    func testFullDecorationSaysWhatEachRefIs() {
        let refs = PluginGit.parseRefs(
            "HEAD -> refs/heads/main, refs/remotes/origin/main, refs/heads/feature/x, tag: refs/tags/v1.0, refs/stash")
        XCTAssertEqual(refs, [
            .init(name: "main", kind: .head), .init(name: "origin/main", kind: .remote),
            .init(name: "feature/x", kind: .branch), .init(name: "v1.0", kind: .tag),
            .init(name: "stash", kind: .stash),
        ])
        // The short form still parses as before.
        XCTAssertEqual(PluginGit.parseRefs("HEAD -> main, tag: v1"),
                       [.init(name: "main", kind: .head), .init(name: "v1", kind: .tag)])
    }

    /// A linear history: one lane, joined above and below every node except at the two ends.
    func testGraphLinesOfALinearHistory() {
        let commits = PluginGit.parseLog(
            logRecord("a", "a", "b", "A", "3", "third")
            + logRecord("b", "b", "c", "A", "2", "second")
            + logRecord("c", "c", "", "A", "1", "first"))
        let drawn = PluginGit.graphLines(PluginGit.graph(commits))
        XCTAssertEqual(drawn.map(\.node), [0, 0, 0])
        XCTAssertEqual(drawn[0].lines, [.init(from: 0, to: 0, upper: false, color: 0)],
                       "the newest commit has nothing above it")
        XCTAssertEqual(drawn[1].lines, [.init(from: 0, to: 0, upper: true, color: 0),
                                        .init(from: 0, to: 0, upper: false, color: 0)])
        XCTAssertEqual(drawn[2].lines, [.init(from: 0, to: 0, upper: true, color: 0)],
                       "the root has no parent, so nothing below it")
    }

    /// A merge bends out to its second parent's lane, the branch runs in that lane, and the lane bends
    /// back into the base where the two converge.
    func testGraphLinesOfAMerge() {
        let commits = PluginGit.parseLog(
            logRecord("m", "m", "a b", "A", "5", "merge")
            + logRecord("a", "a", "base", "A", "4", "on main")
            + logRecord("b", "b", "base", "A", "3", "on branch")
            + logRecord("base", "base", "", "A", "1", "base"))
        let drawn = PluginGit.graphLines(PluginGit.graph(commits))
        XCTAssertTrue(drawn[0].lines.contains(.init(from: 0, to: 1, upper: false, color: 1)),
                      "the merge reaches out to lane 1 below its node")
        XCTAssertTrue(drawn[1].lines.contains(.init(from: 1, to: 1, upper: true, color: 1))
                      && drawn[1].lines.contains(.init(from: 1, to: 1, upper: false, color: 1)),
                      "lane 1 passes the main-line commit straight through")
        XCTAssertEqual(drawn[2].node, 1)
        XCTAssertTrue(drawn[3].lines.contains(.init(from: 1, to: 0, upper: true, color: 1)),
                      "the branch lane bends into the base it converges on")
        XCTAssertFalse(drawn[3].lines.contains { !$0.upper }, "nothing continues below the root")
    }

    func testNameStatusIsAskedForUnquoted() {
        XCTAssertTrue(PluginGit.nameStatusArguments("abc").contains("-z"),
                      "without -z git C-quotes every path outside ASCII")
        XCTAssertEqual(PluginGit.nameStatusArguments("abc").last, "abc")
    }

    /// An app opened from the Finder gets launchd's PATH; git must still find git-lfs, gpg and the rest.
    func testToolSearchPathReachesTheTools() {
        let finder = PluginGit.toolSearchPath(current: "/usr/bin:/bin:/usr/sbin:/sbin", gitExecutable: "/usr/bin/git")
        XCTAssertEqual(finder, "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:/opt/local/bin")
        // The reader's own PATH comes first and is not reordered; nothing is listed twice.
        let own = PluginGit.toolSearchPath(current: "/Users/x/bin:/usr/local/bin:/usr/bin", gitExecutable: "/opt/homebrew/bin/git")
        XCTAssertTrue(own.hasPrefix("/Users/x/bin:/usr/local/bin:/usr/bin:/opt/homebrew/bin"))
        XCTAssertEqual(own.split(separator: ":").count, Set(own.split(separator: ":")).count)
        // A git outside the usual places brings its own directory, where its git-lfs lives.
        XCTAssertTrue(PluginGit.toolSearchPath(current: nil, gitExecutable: "/Applications/X.app/bin/git")
            .hasPrefix("/Applications/X.app/bin:"))
    }

    /// The measured failure, end to end: an LFS repository under launchd's PATH. Without the tool path
    /// `git status` stops with "git-lfs: command not found"; with it, it reports the file.
    func testAnLFSRepositoryWorksUnderTheFindersPath() throws {
        let lfs = ["/opt/homebrew/bin/git-lfs", "/usr/local/bin/git-lfs"].first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
        guard lfs != nil else { throw XCTSkip("git-lfs is not installed here") }
        let repo = try TempRepo()
        let finder = "/usr/bin:/bin:/usr/sbin:/sbin"
        let full = ["PATH": PluginGit.toolSearchPath(current: finder, gitExecutable: "/usr/bin/git")]
        try repo.git(["init", "-q"], environment: full)
        try repo.git(["lfs", "install", "--local"], environment: full)
        try repo.git(["lfs", "track", "*.bin"], environment: full)
        try Data(repeating: 7, count: 100).write(to: repo.dir.appendingPathComponent("a.bin"))
        try repo.git(["add", "-A"], environment: full)
        try repo.git(["commit", "-q", "-m", "lfs"], environment: full)
        try Data(repeating: 8, count: 100).write(to: repo.dir.appendingPathComponent("a.bin"))

        let bare = try repo.git(PluginGit.statusArguments, environment: ["PATH": finder])
        XCTAssertTrue(bare.out.contains("git-lfs") && !bare.ok, "the defect this guards against: \(bare.out)")
        let fixed = try repo.git(PluginGit.statusArguments, environment: full, combined: false)
        XCTAssertTrue(fixed.ok)
        XCTAssertEqual(PluginGit.parseStatus(fixed.out).files.keys.sorted(), ["a.bin"])
    }

    func testBisectFindsTheFirstBadCommitAgainstRealGit() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        var hashes: [String] = []
        for index in 1...8 {
            try (index >= 6 ? "broken" : "fine").write(to: repo.dir.appendingPathComponent("state"), atomically: true, encoding: .utf8)
            try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", "c\(index)"])
            hashes.append(try repo.git(["rev-parse", "HEAD"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let gitDir = repo.dir.appendingPathComponent(".git").path
        func bisecting() -> Bool { PluginGit.isBisecting(gitDir: gitDir) { FileManager.default.fileExists(atPath: $0) } }
        XCTAssertFalse(bisecting())
        var progress = PluginGit.BisectProgress.waiting
        for call in PluginGit.bisectArguments(.bad, commit: hashes[7], started: false) { progress = PluginGit.parseBisect(try repo.git(call).out) }
        XCTAssertTrue(bisecting())
        for call in PluginGit.bisectArguments(.good, commit: hashes[0], started: true) { progress = PluginGit.parseBisect(try repo.git(call).out) }
        var rounds = 0
        while case .remaining = progress, rounds < 10 {
            let state = try String(contentsOf: repo.dir.appendingPathComponent("state"), encoding: .utf8)
            let mark: PluginGit.BisectMark = state == "broken" ? .bad : .good
            progress = PluginGit.parseBisect(try repo.git(PluginGit.bisectArguments(mark, commit: nil, started: true)[0]).out)
            rounds += 1
        }
        XCTAssertEqual(progress, .found(hashes[5]), "c6 is where it broke")
        XCTAssertTrue(try repo.git(PluginGit.bisectResetArguments).ok)
        XCTAssertFalse(bisecting())
    }

    func testPatchesOutAndInAgainstRealGit() throws {
        XCTAssertEqual(PluginGit.patchFileName(number: 1, subject: "Fix(git): the panel's buttons!"), "0001-fix-git-the-panel-s-buttons.patch")
        let source = try TempRepo(), target = try TempRepo()
        for repo in [source, target] { try repo.git(["init", "-q", "-b", "main"]) }
        try "a\n".write(to: source.dir.appendingPathComponent("f"), atomically: true, encoding: .utf8)
        try source.git(["add", "-A"]); try source.git(["commit", "-q", "-m", "base"])
        try "a\n".write(to: target.dir.appendingPathComponent("f"), atomically: true, encoding: .utf8)
        try target.git(["add", "-A"]); try target.git(["commit", "-q", "-m", "base"])
        try "a\nb\n".write(to: source.dir.appendingPathComponent("f"), atomically: true, encoding: .utf8)
        try source.git(["commit", "-q", "-am", "Add b"])
        let patch = try source.git(PluginGit.formatPatchArguments("HEAD"), combined: false).out
        let file = target.dir.appendingPathComponent(PluginGit.patchFileName(number: 1, subject: "Add b"))
        try patch.write(to: file, atomically: true, encoding: .utf8)
        XCTAssertTrue(try target.git(PluginGit.applyPatchesArguments([file.path])).ok)
        XCTAssertEqual(try target.git(["log", "-1", "--format=%s"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines), "Add b")
        // A patch that does not apply leaves `am` under way, seen as such, and aborted.
        try target.git(["reset", "-q", "--hard", "HEAD~1"])
        try "z\n".write(to: target.dir.appendingPathComponent("f"), atomically: true, encoding: .utf8)
        try target.git(["commit", "-q", "-am", "conflicting"])
        XCTAssertFalse(try target.git(PluginGit.applyPatchesArguments([file.path])).ok)
        let gitDir = target.dir.appendingPathComponent(".git").path
        XCTAssertEqual(PluginGit.operationInProgress(gitDir: gitDir) { FileManager.default.fileExists(atPath: $0) }, .applyPatches)
        XCTAssertTrue(try target.git(PluginGit.abortArguments(.applyPatches)).ok)
        XCTAssertNil(PluginGit.operationInProgress(gitDir: gitDir) { FileManager.default.fileExists(atPath: $0) })
    }

    func testParseWorktrees() {
        let out = "worktree /r/main\nHEAD aaa\nbranch refs/heads/main\n\nworktree /r/fix\nHEAD bbb\nbranch refs/heads/fix/x\nlocked\n\nworktree /r/det\nHEAD ccc\ndetached\n"
        let trees = PluginGit.parseWorktrees(out)
        XCTAssertEqual(trees.map(\.path), ["/r/main", "/r/fix", "/r/det"])
        XCTAssertEqual(trees.map(\.branch), ["main", "fix/x", nil])
        XCTAssertEqual(trees.map(\.isMain), [true, false, false])
        XCTAssertEqual(trees.map(\.isLocked), [false, true, false])
    }

    func testWorktreesSubmodulesAndLocalIdentityAgainstRealGit() throws {
        let repo = try TempRepo(), lib = try TempRepo(), place = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"]); try repo.git(["commit", "-q", "--allow-empty", "-m", "x"])
        try lib.git(["init", "-q", "-b", "main"]); try lib.git(["commit", "-q", "--allow-empty", "-m", "lib"])
        let path = place.dir.appendingPathComponent("wt").path
        XCTAssertTrue(try repo.git(PluginGit.addWorktreeArguments(path: path, branch: "fix", create: true)).ok)
        let trees = PluginGit.parseWorktrees(try repo.git(PluginGit.worktreesArguments, combined: false).out)
        XCTAssertEqual(trees.count, 2)
        XCTAssertEqual(trees.last?.branch, "fix")
        XCTAssertTrue(try repo.git(PluginGit.removeWorktreeArguments(path)).ok)
        XCTAssertEqual(PluginGit.parseWorktrees(try repo.git(PluginGit.worktreesArguments, combined: false).out).count, 1)

        let allow = ["GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "protocol.file.allow", "GIT_CONFIG_VALUE_0": "always"]
        XCTAssertTrue(try repo.git(PluginGit.addSubmoduleArguments(url: lib.dir.path, path: "libs/lib"), environment: allow).ok)
        try repo.git(["commit", "-q", "-m", "add lib"])
        let gitDir = try repo.git(["-C", "libs/lib"] + PluginGit.submoduleGitDirArguments, combined: false).out
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let common = try repo.git(PluginGit.commonGitDirArguments, combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(PluginGit.isRemovableSubmoduleGitDir(gitDir, commonGitDir: common), gitDir)
        XCTAssertFalse(PluginGit.isRemovableSubmoduleGitDir(common, commonGitDir: common), "never the superproject's own")
        XCTAssertFalse(PluginGit.isRemovableSubmoduleGitDir(common + "/modules/../hooks", commonGitDir: common))
        for call in PluginGit.removeSubmoduleArguments("libs/lib") { XCTAssertTrue(try repo.git(call).ok) }
        XCTAssertTrue(PluginGit.parseSubmodules(try repo.git(PluginGit.submodulesArguments, combined: false).out).isEmpty)

        XCTAssertTrue(try repo.git(PluginGit.localIdentityArguments(key: "user.email", value: "me@example.com")).ok)
        XCTAssertEqual(try repo.git(["config", "--local", "user.email"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines), "me@example.com")
        XCTAssertTrue(try repo.git(PluginGit.localIdentityArguments(key: "user.email", value: "")).ok)
        XCTAssertFalse(try repo.git(["config", "--local", "user.email"]).ok, "back to the global one")
    }

    func testSearchFilters() {
        let query = PluginGit.SearchQuery.parse("fix author:ada path:src/ \"since:2 weeks ago\" until:2026-10-01 panel")
        XCTAssertEqual(query.text, "fix panel")
        XCTAssertEqual(query.authors, ["ada"])
        XCTAssertEqual(query.paths, ["src/"])
        XCTAssertEqual(query.since, "2 weeks ago")
        XCTAssertEqual(query.until, "2026-10-01")
        let calls = PluginGit.searchArguments(query, limit: 10, all: true)
        XCTAssertEqual(calls.count, 1, "with author: the text is searched in messages only — git ORs --author")
        XCTAssertTrue(calls[0].contains("--grep=fix panel") && calls[0].contains("--author=ada") && calls[0].suffix(2) == ["--", "src/"])
        XCTAssertEqual(PluginGit.searchArguments(PluginGit.SearchQuery.parse("fix path:src/"), limit: 10, all: true).count, 2,
                       "without one, the text is a message or an author")
        let filtersOnly = PluginGit.searchArguments(PluginGit.SearchQuery.parse("path:README.md"), limit: 10, all: true)
        XCTAssertEqual(filtersOnly.count, 1, "no text: one log, narrowed by the filters")
        XCTAssertEqual(PluginGit.searchArguments(PluginGit.SearchQuery.parse("  "), limit: 10, all: true), [])
    }

    func testStashPushAndLFSArguments() {
        XCTAssertEqual(PluginGit.stashPushArguments(message: "wip", includeUntracked: true, keepIndex: true, paths: ["a"]),
                       ["stash", "push", "--include-untracked", "--keep-index", "-m", "wip", "--", "a"])
        XCTAssertEqual(PluginGit.stashPushArguments(message: "", includeUntracked: false, keepIndex: false), ["stash", "push"])
        XCTAssertEqual(PluginGit.lfsTrackArguments(forFileType: "art/cover.psd"), ["lfs", "track", "*.psd"])
        XCTAssertNil(PluginGit.lfsTrackArguments(forFileType: "Makefile"))
    }

    func testStashingSelectedFilesAgainstRealGit() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        for name in ["a", "b"] { try "1".write(to: repo.dir.appendingPathComponent(name), atomically: true, encoding: .utf8) }
        try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", "base"])
        for name in ["a", "b"] { try "2".write(to: repo.dir.appendingPathComponent(name), atomically: true, encoding: .utf8) }
        try "u".write(to: repo.dir.appendingPathComponent("new"), atomically: true, encoding: .utf8)
        XCTAssertTrue(try repo.git(PluginGit.stashPushArguments(message: "only a", includeUntracked: false, keepIndex: false,
                                                                paths: ["a"])).ok)
        let status = PluginGit.parseStatus(try repo.git(PluginGit.statusArguments, combined: false).out)
        XCTAssertNil(status.files["a"], "a went into the stash")
        XCTAssertNotNil(status.files["b"], "b did not")
        XCTAssertTrue(try repo.git(PluginGit.stashPushArguments(message: "", includeUntracked: true, keepIndex: false)).ok)
        XCTAssertTrue(PluginGit.parseStatus(try repo.git(PluginGit.statusArguments, combined: false).out).files.isEmpty,
                      "untracked files went too")
    }

    func testComparingTwoCommitsOrOneWithTheWorkingTree() throws {
        XCTAssertEqual(PluginGit.compareNameStatusArguments(from: "a", to: "b").suffix(3), ["a", "b", "--"])
        XCTAssertEqual(PluginGit.compareNameStatusArguments(from: "a", to: nil).suffix(2), ["a", "--"])
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        let file = repo.dir.appendingPathComponent("f.txt")
        try "1\n".write(to: file, atomically: true, encoding: .utf8)
        try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", "one"])
        let one = try repo.git(["rev-parse", "HEAD"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines)
        try "2\n".write(to: file, atomically: true, encoding: .utf8)
        try "n\n".write(to: repo.dir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
        try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", "two"])
        try "3\n".write(to: file, atomically: true, encoding: .utf8)
        let between = PluginGit.parseNameStatus(try repo.git(PluginGit.compareNameStatusArguments(from: one, to: "HEAD"), combined: false).out)
        XCTAssertEqual(between.map(\.path).sorted(), ["f.txt", "new.txt"])
        let toWorkingTree = PluginGit.parseUnifiedDiff(
            try repo.git(PluginGit.compareDiffArguments(from: one, to: nil, paths: ["f.txt"]), combined: false).out).lines
        XCTAssertEqual(toWorkingTree.filter { $0.kind == .added }.map(\.text), ["3"], "against the file on disk")
    }

    /// Oldest first by the history's order, not by date: a rebase gives a whole series one second, and
    /// a date sort then kept them newest first — a child picked before its parent.
    func testCherryPickingSeveralInTheOrderTheyWereMade() {
        var a = PluginGit.parseLog(logRecord("a", "a", "b", "A", "1", "a"))[0]; a.commitDate = Date(timeIntervalSince1970: 100)
        var b = PluginGit.parseLog(logRecord("b", "b", "p", "A", "1", "b"))[0]; b.commitDate = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(PluginGit.cherryPickSeriesArguments([a, b]), ["cherry-pick", "--no-edit", "b", "a"],
                       "history order is newest first, whatever the dates")
        let merge = PluginGit.parseLog(logRecord("m", "m", "p q", "A", "1", "m"))[0]
        XCTAssertNil(PluginGit.cherryPickSeriesArguments([a, merge]))
        XCTAssertEqual(PluginGit.comparisonBase(oldest: b), "b^", "the oldest's own changes are in the comparison")
        let root = PluginGit.parseLog(logRecord("r", "r", "", "A", "1", "r"))[0]
        XCTAssertEqual(PluginGit.comparisonBase(oldest: root), PluginGit.emptyTree)
    }

    /// A series made in one second, picked onto another branch: the order has to be the history's.
    func testCherryPickingASeriesMadeInOneSecondAgainstRealGit() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        try repo.git(["commit", "-q", "--allow-empty", "-m", "base"])
        try repo.git(["switch", "-q", "-c", "topic"])
        let file = repo.dir.appendingPathComponent("f.txt")
        let date = ["GIT_COMMITTER_DATE": "2026-01-01T00:00:00", "GIT_AUTHOR_DATE": "2026-01-01T00:00:00"]
        for text in ["1\n", "1\n2\n", "1\n2\n3\n"] {
            try text.write(to: file, atomically: true, encoding: .utf8)
            try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", text], environment: date)
        }
        let log = PluginGit.parseLog(try repo.git(PluginGit.logArguments(limit: 3, path: nil), combined: false).out)
        XCTAssertEqual(log.count, 3)
        try repo.git(["switch", "-q", "main"])
        let pick = try repo.git(try XCTUnwrap(PluginGit.cherryPickSeriesArguments(log)))
        XCTAssertTrue(pick.ok, pick.out)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "1\n2\n3\n")
    }

    func testBranchHousekeeping() {
        XCTAssertEqual(PluginGit.renameBranchArguments("a", to: "b"), ["branch", "-m", "a", "b"])
        XCTAssertEqual(PluginGit.setUpstreamArguments(branch: "main", upstream: "origin/main"),
                       ["branch", "--set-upstream-to=origin/main", "main"])
        XCTAssertEqual(PluginGit.deleteRemoteBranchArguments("origin/feature/x"), ["push", "origin", "--delete", "feature/x"])
        XCTAssertNil(PluginGit.deleteRemoteBranchArguments("origin/HEAD"))
        XCTAssertNil(PluginGit.deleteRemoteBranchArguments("main"))
    }

    func testDeletingARemoteBranchAgainstRealGit() throws {
        let remote = try TempRepo(), local = try TempRepo()
        try remote.git(["init", "-q", "--bare", "-b", "main"])
        try local.git(["init", "-q", "-b", "main"])
        try local.git(["remote", "add", "origin", remote.dir.path])
        try local.git(["commit", "-q", "--allow-empty", "-m", "x"])
        try local.git(["push", "-q", "origin", "main", "main:feature/x"])
        try local.git(["fetch", "-q"])
        XCTAssertTrue(try local.git(XCTUnwrap(PluginGit.deleteRemoteBranchArguments("origin/feature/x"))).ok)
        XCTAssertFalse(try remote.git(["branch", "--list", "feature/x"], combined: false).out.contains("feature/x"))
        XCTAssertTrue(try local.git(PluginGit.renameBranchArguments("main", to: "trunk")).ok)
        XCTAssertTrue(try local.git(PluginGit.setUpstreamArguments(branch: "trunk", upstream: "origin/main")).ok)
    }

    func testAMergeIsRevertedAndPickedAgainstItsMainline() {
        XCTAssertEqual(PluginGit.revertArguments("m", isMerge: true), ["revert", "--no-edit", "-m", "1", "m"])
        XCTAssertEqual(PluginGit.cherryPickArguments("m", isMerge: true), ["cherry-pick", "--no-edit", "-m", "1", "m"])
    }

    /// A merge that conflicts is seen as under way, can be aborted, and once resolved is finished.
    func testAStoppedMergeAgainstRealGit() throws {
        let repo = try TempRepo()
        func write(_ text: String) throws { try text.write(to: repo.dir.appendingPathComponent("f"), atomically: true, encoding: .utf8) }
        func operation() -> PluginGit.Operation? {
            PluginGit.operationInProgress(gitDir: repo.dir.appendingPathComponent(".git").path) {
                FileManager.default.fileExists(atPath: $0)
            }
        }
        try repo.git(["init", "-q", "-b", "main"])
        try write("base\n"); try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", "base"])
        try repo.git(["switch", "-q", "-c", "side"])
        try write("side\n"); try repo.git(["commit", "-q", "-am", "side"])
        try repo.git(["switch", "-q", "main"])
        try write("main\n"); try repo.git(["commit", "-q", "-am", "main"])
        XCTAssertNil(operation())
        XCTAssertFalse(try repo.git(PluginGit.mergeArguments("side")).ok, "it conflicts")
        XCTAssertEqual(operation(), .merge)
        XCTAssertTrue(try repo.git(PluginGit.abortArguments(.merge)).ok)
        XCTAssertNil(operation())
        XCTAssertFalse(try repo.git(PluginGit.mergeArguments("side")).ok)
        try write("both\n"); try repo.git(["add", "f"])
        XCTAssertTrue(try repo.git(PluginGit.continueArguments(.merge)).ok)
        XCTAssertNil(operation())
        XCTAssertEqual(try repo.git(["log", "-1", "--format=%P"], combined: false).out.split(separator: " ").count, 2,
                       "finished as a merge commit")
        // And that merge reverted against its mainline.
        let merge = try repo.git(["rev-parse", "HEAD"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(try repo.git(PluginGit.revertArguments(merge, isMerge: true)).ok)
        XCTAssertEqual(try String(contentsOf: repo.dir.appendingPathComponent("f"), encoding: .utf8), "main\n")
    }

    func testTheFirstPushSetsAnUpstream() {
        XCTAssertEqual(PluginGit.pushArguments(upstream: "origin/main", remotes: ["origin"], setUpstream: true), ["push"])
        XCTAssertEqual(PluginGit.pushArguments(upstream: nil, remotes: ["fork", "origin"], setUpstream: true),
                       ["push", "--set-upstream", "origin", "HEAD"], "origin when there is one")
        XCTAssertEqual(PluginGit.pushArguments(upstream: nil, remotes: ["fork"], setUpstream: true),
                       ["push", "--set-upstream", "fork", "HEAD"], "else the only remote")
        XCTAssertNil(PluginGit.pushArguments(upstream: nil, remotes: [], setUpstream: true))
        XCTAssertEqual(PluginGit.pushArguments(upstream: nil, remotes: ["origin"], setUpstream: false), ["push"])
        XCTAssertFalse(PluginGit.forcePushArguments.contains("--force"), "never a plain --force")
    }

    /// Two clones of one remote diverge: the push of the second is refused as behind, a pull with
    /// --ff-only refuses as diverged, a rebasing pull joins them, and a force-with-lease push after an
    /// amend goes through — the whole sequence that sent a reader to the terminal.
    func testPushAndPullOnDivergedBranchesAgainstRealGit() throws {
        let remote = try TempRepo()
        try remote.git(["init", "-q", "--bare", "-b", "main"])
        let one = try TempRepo(), two = try TempRepo()
        func commit(_ repo: TempRepo, _ file: String) throws {
            try file.write(to: repo.dir.appendingPathComponent(file), atomically: true, encoding: .utf8)
            try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", file])
        }
        try one.git(["init", "-q", "-b", "main"])
        try one.git(["remote", "add", "origin", remote.dir.path])
        try commit(one, "base")
        // The first push of a branch without an upstream.
        let first = try XCTUnwrap(PluginGit.pushArguments(upstream: nil, remotes: ["origin"], setUpstream: true))
        XCTAssertTrue(try one.git(first).ok)
        XCTAssertTrue(try one.git(["rev-parse", "--abbrev-ref", "@{upstream}"], combined: false).out.contains("origin/main"))

        try two.git(["clone", "-q", remote.dir.path, "."])
        try commit(one, "from-one"); try one.git(["push", "-q"])
        try commit(two, "from-two")
        let push = try two.git(["push"])
        XCTAssertFalse(push.ok)
        XCTAssertTrue(PluginGit.isRejectedAsBehind(push.out), push.out)
        let pull = try two.git(PluginGit.Settings().pullArguments)
        XCTAssertFalse(pull.ok)
        XCTAssertTrue(PluginGit.isDivergedPullRefusal(pull.out), pull.out)
        XCTAssertTrue(try two.git(PluginGit.pullArguments(.rebase)).ok, "a rebasing pull joins them")
        XCTAssertTrue(try two.git(["push", "-q"]).ok)

        // An amend of a pushed commit, then the lease.
        try two.git(["commit", "-q", "--amend", "-m", "from-two, reworded"])
        XCTAssertFalse(try two.git(["push"]).ok)
        XCTAssertTrue(try two.git(PluginGit.forcePushArguments).ok)

        // A background fetch brings a colleague's push into origin/main; a lease alone would now agree
        // with it and drop the colleague's commit. --force-if-includes refuses: this branch never had it.
        try one.git(["pull", "-q", "--rebase"])
        try commit(one, "colleague"); try one.git(["push", "-q"])
        try two.git(["fetch", "-q"])
        try two.git(["commit", "-q", "--amend", "-m", "from-two, again"])
        let unsafe = try two.git(PluginGit.forcePushArguments)
        XCTAssertFalse(unsafe.ok, "a commit only a fetch has seen stops the force push")
        XCTAssertTrue(PluginGit.isRejectedAsBehind(unsafe.out) || unsafe.out.contains("rejected"), unsafe.out)
    }

    func testSettingsRoundTripAndClamp() {
        var settings = PluginGit.Settings()
        settings.pullMode = .rebase
        settings.autoFetchMinutes = 15
        settings.showTags = false
        settings.signOff = true
        settings.dateStyle = .absolute
        settings.gitProgram = "/opt/homebrew/bin/git"
        XCTAssertEqual(PluginGit.Settings.parse(settings.serialized()), settings)
        // A hand-edited file with nonsense keeps sensible values.
        let odd = PluginGit.Settings.parse("[Git]\nHistoryPageSize=3\nPullMode=sideways\nSubjectLength=x\n")
        XCTAssertEqual(odd.historyPageSize, 50, "clamped to the smallest page that is still a page")
        XCTAssertEqual(odd.pullMode, .fastForward)
        XCTAssertEqual(odd.subjectLength, 72)
        XCTAssertEqual(PluginGit.Settings.parse(""), PluginGit.Settings(), "no file is the defaults")
    }

    func testSettingsShapeTheCommands() {
        var settings = PluginGit.Settings()
        XCTAssertEqual(settings.historyRefs, ["--branches", "--remotes", "--tags", "HEAD"])
        XCTAssertEqual(settings.pullArguments, ["pull", "--ff-only"])
        XCTAssertEqual(settings.fetchArguments, ["fetch", "--all", "--prune"])
        XCTAssertEqual(settings.commitOptions, [])
        XCTAssertEqual(settings.diffOptions, ["-U3"])
        settings.showRemoteBranches = false; settings.showTags = false
        settings.pullMode = .rebase; settings.fetchPrunes = false
        settings.signCommits = true; settings.signOff = true; settings.runHooks = false
        settings.diffIgnoreWhitespace = true; settings.diffContextLines = 8
        XCTAssertEqual(settings.historyRefs, ["--branches", "HEAD"])
        XCTAssertEqual(settings.pullArguments, ["pull", "--rebase"])
        XCTAssertEqual(settings.fetchArguments, ["fetch", "--all"])
        XCTAssertEqual(settings.commitOptions, ["-S", "--signoff", "--no-verify"])
        XCTAssertEqual(settings.diffOptions, ["-U8", "-w"])
        XCTAssertEqual(Array(PluginGit.logArguments(limit: 5, all: true, refs: settings.historyRefs).suffix(2)), ["--branches", "HEAD"])
    }

    func testCloneDirectoryNames() {
        XCTAssertEqual(PluginGit.cloneDirectoryName("git@github.com:team/app.git"), "app")
        XCTAssertEqual(PluginGit.cloneDirectoryName("https://host/team/app/"), "app")
        XCTAssertEqual(PluginGit.cloneDirectoryName("/srv/repos/app.git"), "app")
        XCTAssertEqual(PluginGit.cloneDirectoryName("ssh://host:22/x/Grüße"), "Grüße")
        XCTAssertNil(PluginGit.cloneDirectoryName("  "))
        XCTAssertEqual(Array(PluginGit.cloneArguments(url: "-x", into: "/d").suffix(3)), ["--end-of-options", "-x", "/d"],
                       "a URL can never be an option")
    }

    func testRecentRepositoriesMoveToTheFrontOnce() {
        XCTAssertEqual(PluginGit.recentRepositories(["/a", "/b", "/c"], opening: "/b"), ["/b", "/a", "/c"])
        XCTAssertEqual(PluginGit.recentRepositories((1...10).map { "/\($0)" }, opening: "/new").count, 10)
        XCTAssertEqual(PluginGit.recentRepositories((1...10).map { "/\($0)" }, opening: "/new").last, "/9")
    }

    func testCloneAgainstRealGit() throws {
        let source = try TempRepo()
        try source.git(["init", "-q", "-b", "main"])
        try source.git(["commit", "-q", "--allow-empty", "-m", "first"])
        let target = try TempRepo()
        let name = try XCTUnwrap(PluginGit.cloneDirectoryName(source.dir.path))
        let into = target.dir.appendingPathComponent(name).path
        XCTAssertTrue(try target.git(PluginGit.cloneArguments(url: source.dir.path, into: into)).ok)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (into as NSString).appendingPathComponent(".git")))
    }

    func testParseRemotesKeepsFetchAndPushApart() {
        let out = "origin\tgit@github.com:a/b.git (fetch)\norigin\tgit@github.com:a/b.git (push)\n"
            + "fork\thttps://x/y.git (fetch)\nfork\tssh://push/y.git (push)\n"
        XCTAssertEqual(PluginGit.parseRemotes(out), [
            .init(name: "origin", fetchURL: "git@github.com:a/b.git", pushURL: "git@github.com:a/b.git"),
            .init(name: "fork", fetchURL: "https://x/y.git", pushURL: "ssh://push/y.git"),
        ])
        XCTAssertEqual(PluginGit.renameRemoteArguments("fork", to: "upstream"), ["remote", "rename", "fork", "upstream"])
    }

    func testParseSubmodules() {
        let out = " 1111 libs/core (v1.2)\n-2222 vendor/x\n+3333 tools/y (heads/main)\nU4444 z\n"
        let subs = PluginGit.parseSubmodules(out)
        XCTAssertEqual(subs.map(\.path), ["libs/core", "vendor/x", "tools/y", "z"])
        XCTAssertEqual(subs.map(\.state), [.current, .uninitialized, .differs, .conflict])
        XCTAssertEqual(subs[0].describe, "v1.2")
        XCTAssertNil(subs[1].describe)
    }

    func testRemotesAndSubmodulesAgainstRealGit() throws {
        let lib = try TempRepo()
        try lib.git(["init", "-q", "-b", "main"])
        try lib.git(["commit", "-q", "--allow-empty", "-m", "lib"])
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        XCTAssertTrue(try repo.git(PluginGit.addRemoteArguments(name: "origin", url: "https://example.com/a.git")).ok)
        XCTAssertTrue(try repo.git(PluginGit.setRemoteURLArguments("origin", url: "https://example.com/b.git")).ok)
        XCTAssertTrue(try repo.git(PluginGit.renameRemoteArguments("origin", to: "upstream")).ok)
        XCTAssertEqual(PluginGit.parseRemotes(try repo.git(PluginGit.remotesArguments, combined: false).out),
                       [.init(name: "upstream", fetchURL: "https://example.com/b.git", pushURL: "https://example.com/b.git")])
        XCTAssertTrue(try repo.git(PluginGit.removeRemoteArguments("upstream")).ok)
        XCTAssertEqual(PluginGit.parseRemotes(try repo.git(PluginGit.remotesArguments, combined: false).out), [])

        // A local submodule (protocol.file.allow: git refuses file:// submodules by default since 2.38).
        let allow = ["GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "protocol.file.allow", "GIT_CONFIG_VALUE_0": "always"]
        XCTAssertTrue(try repo.git(["submodule", "add", "-q", lib.dir.path, "libs/lib"], environment: allow).ok)
        try repo.git(["commit", "-q", "-m", "add lib"])
        let subs = PluginGit.parseSubmodules(try repo.git(PluginGit.submodulesArguments, combined: false).out)
        XCTAssertEqual(subs.map(\.path), ["libs/lib"])
        XCTAssertEqual(subs.first?.state, .current)
    }

    /// A commit lost to a hard reset is still in the reflog, and a branch on it brings it back.
    func testTheReflogFindsALostCommitAgainstRealGit() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        try repo.git(["commit", "-q", "--allow-empty", "-m", "base"])
        try repo.git(["commit", "-q", "--allow-empty", "-m", "precious"])
        try repo.git(PluginGit.resetArguments(.hard, to: "HEAD~1"))
        XCTAssertFalse(try repo.git(["log", "--format=%s"], combined: false).out.contains("precious"))
        let entries = PluginGit.parseReflog(try repo.git(PluginGit.reflogArguments(limit: 50), combined: false).out)
        XCTAssertEqual(entries.first?.selector, "HEAD@{0}")
        XCTAssertTrue(entries.first?.action.hasPrefix("reset:") ?? false, entries.first?.action ?? "")
        let lost = try XCTUnwrap(entries.first { $0.subject == "precious" })
        XCTAssertTrue(lost.action.hasPrefix("commit"))
        let commit = PluginGit.commit(of: lost)
        XCTAssertTrue(try repo.git(PluginGit.branchAtArguments(name: "rescued", commit: commit.hash)).ok)
        XCTAssertEqual(try repo.git(["log", "-1", "--format=%s"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines), "precious")
    }

    func testALinePatchKeepsUnselectedChangesWhereTheyStand() {
        let diff = """
        @@ -1,3 +1,3 @@
         keep
        -old one
        -old two
        +new one
        +new two
         tail
        """
        let lines = PluginGit.parseUnifiedDiff(diff).lines
        // Select "-old one" (2) and "+new one" (4).
        let stage = PluginGit.linePatch(path: "f.txt", lines: lines, selected: [2, 4], use: .stage)
        XCTAssertEqual(stage, "--- a/f.txt\n+++ b/f.txt\n@@ -1,3 +1,3 @@\n keep\n-old one\n old two\n+new one\n tail\n",
                       "forwards: the unselected - stays as context, the unselected + is left out")
        let unstage = PluginGit.linePatch(path: "f.txt", lines: lines, selected: [2, 4], use: .unstage)
        XCTAssertEqual(unstage, "--- a/f.txt\n+++ b/f.txt\n@@ -1,3 +1,3 @@\n keep\n-old one\n+new one\n new two\n tail\n",
                       "in reverse it is the other way round")
        XCTAssertNil(PluginGit.linePatch(path: "f.txt", lines: lines, selected: [1, 6], use: .stage), "context only")
        // The old file ended without a newline; adding a line after it while its end stays context is
        // something git cannot apply, so it is refused.
        let unterminated = PluginGit.parseUnifiedDiff("@@ -1 +1,2 @@\n-foo\n\\ No newline at end of file\n+foo\n+bar\n").lines
        XCTAssertNil(PluginGit.linePatch(path: "f", lines: unterminated, selected: [4], use: .stage))
        XCTAssertNotNil(PluginGit.linePatch(path: "f", lines: unterminated, selected: [1, 3, 4], use: .stage),
                        "the whole change is fine")
        XCTAssertEqual(PluginGit.hunkLines(containing: 5, in: lines), [2, 3, 4, 5])
    }

    /// Against real git: stage two of four changed lines, unstage one of them, discard another.
    func testStagingLinesAgainstRealGit() throws {
        let repo = try TempRepo()
        let file = repo.dir.appendingPathComponent("f.txt")
        func write(_ text: String) throws { try text.write(to: file, atomically: true, encoding: .utf8) }
        func diff(_ cached: Bool) throws -> [PluginGit.DiffLine] {
            PluginGit.parseUnifiedDiff(try repo.git(["diff"] + (cached ? ["--cached"] : []) + ["--", "f.txt"], combined: false).out).lines
        }
        func apply(_ patch: String?, _ use: PluginGit.LinePatchUse) throws {
            let patchFile = repo.dir.appendingPathComponent("p.patch")
            try XCTUnwrap(patch).write(to: patchFile, atomically: true, encoding: .utf8)
            let result = try repo.git(PluginGit.applyLinePatchArguments(use, patchFile: patchFile.path))
            XCTAssertTrue(result.ok, result.out)
            try FileManager.default.removeItem(at: patchFile)
        }

        try repo.git(["init", "-q"])
        try write("a\nb\nc\nd\ne\n")
        try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", "base"])
        try write("a\nB\nc\nD\ne\nf\n")         // b→B, d→D, +f

        let unstaged = try diff(false)
        let pick = Set(unstaged.indices.filter { ["b", "B"].contains(unstaged[$0].text) && unstaged[$0].kind != .context })
        try apply(PluginGit.linePatch(path: "f.txt", lines: unstaged, selected: pick, use: .stage), .stage)
        XCTAssertEqual(try repo.git(["show", ":f.txt"], combined: false).out, "a\nB\nc\nd\ne\n", "only b→B is staged")

        let staged = try diff(true)
        let back = Set(staged.indices.filter { staged[$0].text == "B" })
        try apply(PluginGit.linePatch(path: "f.txt", lines: staged, selected: back, use: .unstage), .unstage)
        XCTAssertEqual(try repo.git(["show", ":f.txt"], combined: false).out, "a\nc\nd\ne\n",
                       "each line on its own: unstaging +B takes B out, the staged deletion of b stays")
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "a\nB\nc\nD\ne\nf\n", "the working tree is untouched")

        let now = try diff(false)
        let f = Set(now.indices.filter { now[$0].text == "f" && now[$0].kind == .added })
        try apply(PluginGit.linePatch(path: "f.txt", lines: now, selected: f, use: .discard), .discard)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "a\nB\nc\nD\ne\n", "discarding +f removes it alone")
    }

    func testStashesSitAboveTheCommitTheyWereMadeOn() {
        let us = "\u{1F}", rs = "\u{1E}"
        let out = ["s1", "base2 idx1", "300", "stash@{0}", "On main: wip", "301"].joined(separator: us) + rs
            + ["s2", "base1 idx2 untracked2", "100", "stash@{1}", "WIP on main: abc subject", "101"].joined(separator: us) + rs
        let stashes = PluginGit.stashCommits(out)
        XCTAssertEqual(stashes.map(\.parents), [["base2"], ["base1"]], "only the commit it was made on")
        XCTAssertEqual(stashes[0].refs, [.init(name: "stash@{0}", kind: .stash)])
        XCTAssertTrue(PluginGit.isStash(stashes[0]))
        let commits = PluginGit.parseLog(logRecord("base2", "b2", "base1", "A", "200", "two")
            + logRecord("base1", "b1", "", "A", "50", "one"))
        XCTAssertFalse(PluginGit.isStash(commits[0]))
        XCTAssertEqual(PluginGit.historyWithStashes(commits, stashes: stashes).map(\.hash), ["s1", "base2", "s2", "base1"])
        let orphan = PluginGit.stashCommits(["s3", "elsewhere", "1", "stash@{2}", "x"].joined(separator: us) + rs)
        XCTAssertEqual(PluginGit.historyWithStashes(commits, stashes: orphan).count, 2, "its commit is not loaded")
        XCTAssertEqual(PluginGit.stashArguments(.pop, ref: "stash@{1}"), ["stash", "pop", "stash@{1}"])
        // Pushed elsewhere since: s2 is stash@{2} now, and its old name points at another stash.
        let later = ["s9", "base2", "400", "stash@{0}", "On main: newer", "401"].joined(separator: us) + rs
            + ["s1", "base2", "300", "stash@{1}", "On main: wip", "301"].joined(separator: us) + rs
            + ["s2", "base1", "100", "stash@{2}", "WIP on main: abc subject", "101"].joined(separator: us) + rs
        XCTAssertEqual(PluginGit.currentStashRef(hash: "s2", in: later), "stash@{2}")
        XCTAssertNil(PluginGit.currentStashRef(hash: "gone", in: later))
    }

    func testStashCommitsAgainstRealGit() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        try "a\n".write(to: repo.dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", "base"])
        let base = try repo.git(["rev-parse", "HEAD"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines)
        try "b\n".write(to: repo.dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "u\n".write(to: repo.dir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
        try repo.git(["stash", "push", "-u", "-q", "-m", "half done"])
        let stashes = PluginGit.stashCommits(try repo.git(PluginGit.stashCommitsArguments, combined: false).out)
        XCTAssertEqual(stashes.count, 1)
        XCTAssertEqual(stashes[0].parents, [base], "the untracked-files parent is not the base")
        XCTAssertEqual(stashes[0].subject, "On main: half done")
        XCTAssertEqual(stashes[0].refs.first?.name, "stash@{0}")
        let files = PluginGit.parseNameStatus(try repo.git(PluginGit.nameStatusArguments(stashes[0].hash), combined: false).out)
        XCTAssertEqual(files.map(\.path), ["a.txt"], "its Changes are the tracked change, against the base")
    }

    func testRecentMessagesAreTheReadersOwnEachOnce() {
        XCTAssertTrue(PluginGit.recentMessagesArguments(author: "me@x").contains("--author=me@x"))
        XCTAssertFalse(PluginGit.recentMessagesArguments(author: nil).contains { $0.hasPrefix("--author") })
        XCTAssertEqual(PluginGit.recentMessages("fix: a\nwip\nwip\n\nfix: b\nwip\n"), ["fix: a", "wip", "fix: b"])
        XCTAssertEqual(PluginGit.recentMessages((1...30).map { "m\($0)" }.joined(separator: "\n"), limit: 20).count, 20)
    }

    func testLFSPathsFromCheckAttr() {
        XCTAssertEqual(PluginGit.lfsCheckArguments, ["check-attr", "--stdin", "-z", "filter"])
        XCTAssertEqual(PluginGit.lfsCheckInput(["a.bin", "b c"]), Data("a.bin\0b c\0".utf8))
        let out = "a.bin\0filter\0lfs\0Grüße.txt\0filter\0unspecified\0b c.psd\0filter\0lfs\0"
        XCTAssertEqual(PluginGit.lfsPaths(out), ["a.bin", "b c.psd"])
    }

    func testLFSPathsAgainstRealGit() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q"])
        try "*.bin filter=lfs diff=lfs merge=lfs -text\n".write(to: repo.dir.appendingPathComponent(".gitattributes"),
                                                                  atomically: true, encoding: .utf8)
        let out = try repo.git(PluginGit.lfsCheckArguments, combined: false,
                               input: PluginGit.lfsCheckInput(["data/a.bin", "Grüße.txt"])).out
        XCTAssertEqual(PluginGit.lfsPaths(out), ["data/a.bin"])
    }

    func testActionsOnACommitFromTheHistory() {
        XCTAssertEqual(PluginGit.checkoutCommitArguments("abc"), ["switch", "--detach", "abc"])
        XCTAssertEqual(PluginGit.branchAtArguments(name: "fix", commit: "abc"), ["switch", "-c", "fix", "abc"])
        XCTAssertEqual(PluginGit.mergeArguments("feature/x"), ["merge", "--no-edit", "feature/x"])
        XCTAssertEqual(PluginGit.rebaseOntoArguments("abc"), ["rebase", "abc"])
        XCTAssertEqual(PluginGit.resetArguments(.hard, to: "abc"), ["reset", "--hard", "abc"])
        XCTAssertEqual(PluginGit.resetArguments(.soft, to: "abc"), ["reset", "--soft", "abc"])
        XCTAssertEqual(PluginGit.isAncestorOfHeadArguments("abc"), ["merge-base", "--is-ancestor", "abc", "HEAD"])
    }

    /// The history menu's actions against real git: each argument list does what its menu item says.
    func testHistoryActionsAgainstRealGit() throws {
        let repo = try TempRepo()
        func head() throws -> String { try repo.git(["rev-parse", "HEAD"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines) }
        func branch() throws -> String { try repo.git(["branch", "--show-current"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines) }
        func commit(_ file: String, _ text: String) throws {
            try text.write(to: repo.dir.appendingPathComponent(file), atomically: true, encoding: .utf8)
            try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", "\(file) \(text)"])
        }
        try repo.git(["init", "-q", "-b", "main"])
        try commit("a.txt", "1")
        let first = try head()
        try commit("a.txt", "2")
        let second = try head()

        // New branch here: a branch at the older commit, checked out.
        XCTAssertTrue(try repo.git(PluginGit.branchAtArguments(name: "side", commit: first)).ok)
        XCTAssertEqual(try branch(), "side"); XCTAssertEqual(try head(), first)
        try commit("b.txt", "side")
        // New tag here, on a commit that is not HEAD.
        XCTAssertTrue(try repo.git(PluginGit.createTagArguments(name: "v0", message: "first", at: first)).ok)
        XCTAssertEqual(try repo.git(["rev-parse", "v0^{commit}"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines), first)
        // Rebase the current branch onto main's tip: side's commit now sits on top of `second`.
        XCTAssertTrue(try repo.git(PluginGit.rebaseOntoArguments("main")).ok)
        XCTAssertEqual(try repo.git(["rev-parse", "HEAD~1"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines), second)
        // Merge into the current branch: main merges side, without an editor.
        try repo.git(["switch", "-q", "main"])
        XCTAssertTrue(try repo.git(PluginGit.mergeArguments("side"), environment: ["GIT_EDITOR": "false"]).ok)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repo.dir.appendingPathComponent("b.txt").path))
        // Reset: soft keeps the change staged, hard discards it.
        XCTAssertTrue(try repo.git(PluginGit.resetArguments(.soft, to: second)).ok)
        XCTAssertTrue(PluginGit.parseStatus(try repo.git(PluginGit.statusArguments, combined: false).out).files["b.txt"]?.isStaged ?? false)
        XCTAssertTrue(try repo.git(PluginGit.resetArguments(.hard, to: second)).ok)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repo.dir.appendingPathComponent("b.txt").path))
        // Check out this commit: HEAD detached on it, no branch.
        XCTAssertTrue(try repo.git(PluginGit.checkoutCommitArguments(first)).ok)
        XCTAssertEqual(try head(), first); XCTAssertEqual(try branch(), "")
        // From here an interactive rebase is allowed only below HEAD.
        XCTAssertFalse(try repo.git(PluginGit.isAncestorOfHeadArguments(second)).ok, "second is not below the detached HEAD")
        try repo.git(["switch", "-q", "main"])
        XCTAssertTrue(try repo.git(PluginGit.isAncestorOfHeadArguments(first)).ok)
    }

    func testMergeAndRebaseNameTheBranchWhenThereIsOne() {
        var commit = PluginGit.parseLog(logRecord("abc123", "abc", "", "A", "1", "s"))[0]
        XCTAssertEqual(PluginGit.preferredRefName(commit), "abc123", "a bare commit by its hash")
        commit.refs = [.init(name: "v1.0", kind: .tag), .init(name: "origin/HEAD", kind: .remote),
                       .init(name: "origin/main", kind: .remote), .init(name: "feature/x", kind: .branch)]
        XCTAssertEqual(PluginGit.preferredRefName(commit), "feature/x", "a local branch first")
        commit.refs.removeLast()
        XCTAssertEqual(PluginGit.preferredRefName(commit), "origin/main", "then a remote branch, never origin/HEAD")
    }

    func testAnInteractiveRebaseFromAChosenCommitNeedsNoUpstream() {
        let repo = PluginGit.parseStatus("# branch.oid abc\0# branch.head main\0")
        XCTAssertEqual(PluginGit.rebaseRefusal(repo: repo, aheadCount: 2, actions: [.pick, .pick], rebaseRunning: false),
                       .noUpstream)
        XCTAssertNil(PluginGit.rebaseRefusal(repo: repo, aheadCount: 2, actions: [.pick, .pick], rebaseRunning: false,
                                             hasBase: true))
    }

    func testHashLikeNeedsFourToFortyHexDigits() {
        XCTAssertTrue(PluginGit.isHashLike("7a6e"))
        XCTAssertTrue(PluginGit.isHashLike("7A6E3E0"))
        XCTAssertFalse(PluginGit.isHashLike("7a6"), "git's minimum abbreviation is four")
        XCTAssertFalse(PluginGit.isHashLike("helpers"))
        XCTAssertFalse(PluginGit.isHashLike(String(repeating: "a", count: 41)))
    }

    /// Message and author are separate calls, because one call with both intersects them.
    func testSearchRunsOneCallPerField() {
        let calls = PluginGit.searchArguments("helpers", limit: 50, all: true)
        XCTAssertEqual(calls.count, 2)
        XCTAssertTrue(calls[0].contains("--grep=helpers") && !calls[0].contains { $0.hasPrefix("--author") })
        XCTAssertTrue(calls[1].contains("--author=helpers") && !calls[1].contains { $0.hasPrefix("--grep") })
        for call in calls {
            XCTAssertTrue(call.contains("-i") && call.contains("-F"), "case-insensitive fixed strings")
            XCTAssertTrue(call.contains("--branches"), "the same refs the history walks")
            XCTAssertTrue(call.contains("--date-order") && !call.contains("--topo-order"),
                          "one order every call follows, so they merge without gaps")
        }
        XCTAssertEqual(PluginGit.searchArguments("   ", limit: 50, all: true), [])
        XCTAssertEqual(PluginGit.searchEnvironment["LC_ALL"], "UTF-8")
    }

    func testAHashLikeSearchAsksForThatCommitWithoutLettingItBeAnOption() {
        let call = PluginGit.hashSearchArguments(" 7a6e3e0 ")
        XCTAssertEqual(call.map { Array($0.suffix(2)) }, ["--end-of-options", "7a6e3e0"])
        XCTAssertTrue(call?.contains("--no-walk") ?? false)
        XCTAssertNil(PluginGit.hashSearchArguments("helpers"))
    }

    func testReachabilityFollowsTheScope() {
        XCTAssertEqual(PluginGit.reachabilityArguments("abc", all: false), ["merge-base", "--is-ancestor", "abc", "HEAD"])
        let all = PluginGit.reachabilityArguments("abc", all: true)
        XCTAssertEqual(all.first, "for-each-ref")
        XCTAssertTrue(all.contains("--contains") && all.contains("refs/remotes") && all.contains("refs/tags"))
    }

    private func commit(_ hash: String, committed: TimeInterval) -> PluginGit.Commit {
        var commit = PluginGit.parseLog(logRecord(hash, hash, "", "A", "1", hash))[0]
        commit.commitDate = Date(timeIntervalSince1970: committed)
        return commit
    }

    func testSearchResultsAreMergedOnceNewestCommitFirst() {
        // Ordered by commit time, not author time: a rebased commit keeps an old author date.
        let merged = PluginGit.mergeSearchResults(
            [[commit("a", committed: 300), commit("b", committed: 100)], [commit("a", committed: 300), commit("c", committed: 200)]],
            limit: 10)
        XCTAssertEqual(merged.commits.map(\.hash), ["a", "c", "b"])
        XCTAssertFalse(merged.hasMore)
    }

    /// A full list stopped somewhere; past its last commit the other list must not fill in alone.
    func testAFullListCutsTheMergeWhereItStopped() {
        let grep = [commit("g1", committed: 900), commit("g2", committed: 800)]          // full: limit 2
        let author = [commit("a1", committed: 850), commit("a2", committed: 100)]        // full too
        let merged = PluginGit.mergeSearchResults([grep, author], limit: 2)
        XCTAssertEqual(merged.commits.map(\.hash), ["g1", "a1", "g2"],
                       "a2 is older than where grep stopped: grep's matches between are not known")
        XCTAssertTrue(merged.hasMore)
        let withHash = PluginGit.mergeSearchResults([grep, author], extra: [commit("h", committed: 50)], limit: 2)
        XCTAssertEqual(withHash.commits.last?.hash, "h", "the hash search's commit is shown wherever it is")
    }

    /// Against real git: message, body, author name and e-mail and a hash prefix all find their commit,
    /// case-insensitively also outside ASCII, and a hash outside the current branch is not on it.
    func testSearchAgainstRealGit() throws {
        let repo = try TempRepo()
        // Stdout only, in the search's environment — the locale-less case it has to survive.
        func git(_ arguments: [String], _ author: String) throws -> (out: String, ok: Bool) {
            try repo.git(arguments, environment: PluginGit.searchEnvironment, author: author, combined: false)
        }
        do {
            func search(_ query: String, all: Bool = true) throws -> [String] {
                let results = try PluginGit.searchArguments(query, limit: 50, all: all)
                    .map { PluginGit.parseLog(try git($0, "Ada").out) }
                var extra: [PluginGit.Commit] = []
                if let call = PluginGit.hashSearchArguments(query) {
                    extra = try PluginGit.parseLog(git(call, "Ada").out).filter { found in
                        let check = try git(PluginGit.reachabilityArguments(found.hash, all: all), "Ada")
                        return all ? !check.out.isEmpty : check.ok
                    }
                }
                return PluginGit.mergeSearchResults(results, extra: extra, limit: 50).commits.map(\.subject)
            }
            _ = try git(["init", "-q"], "Ada")
            _ = try git(["symbolic-ref", "HEAD", "refs/heads/main"], "Ada")
            _ = try git(["commit", "-q", "--allow-empty", "-m", "Fix(git): Über die Grüße", "-m", "Body mentions Straße"], "Ada")
            _ = try git(["commit", "-q", "--allow-empty", "-m", "Unrelated"], "Grace")
            _ = try git(["checkout", "-q", "-b", "side"], "Ada")
            _ = try git(["commit", "-q", "--allow-empty", "-m", "Only on side"], "Ada")
            let side = try git(["rev-parse", "HEAD"], "Ada").out.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try git(["checkout", "-q", "main"], "Ada")
            let first = try git(["rev-parse", "HEAD~1"], "Ada").out.trimmingCharacters(in: .whitespacesAndNewlines)

            XCTAssertEqual(try search("fix(GIT)"), ["Fix(git): Über die Grüße"], "case-insensitive, not a regex")
            XCTAssertEqual(try search("über"), ["Fix(git): Über die Grüße"], "case folded outside ASCII too")
            XCTAssertEqual(try search("straße"), ["Fix(git): Über die Grüße"], "the body is searched too")
            XCTAssertEqual(try search("grace"), ["Unrelated"], "the author's name")
            XCTAssertEqual(try search("ada@example"), ["Only on side", "Fix(git): Über die Grüße"],
                           "the author's e-mail, across every branch")
            XCTAssertEqual(try search(String(first.prefix(7))), ["Fix(git): Über die Grüße"], "a hash prefix")
            XCTAssertEqual(try search(String(side.prefix(7)), all: false), [],
                           "a commit only on another branch is not on the current one")
            XCTAssertEqual(try search(String(side.prefix(7)), all: true), ["Only on side"])
            XCTAssertEqual(try search("nothing like this"), [])
        }
    }

    func testParseNameStatusKeepsRenamesOldPath() {
        let files = PluginGit.parseNameStatus("M\0README.md\0R100\0old/name.txt\0new/name.txt\0A\0docs/Grüße.md\0")
        XCTAssertEqual(files, [
            .init(status: "M", path: "README.md"),
            .init(status: "R", path: "new/name.txt", oldPath: "old/name.txt"),
            .init(status: "A", path: "docs/Grüße.md"),
        ])
    }

    func testParseDetails() {
        let us = "\u{1F}"
        let out = ["abc", "p1 p2", "Ada", "ada@x", "1700000000", "Bob", "bob@x", "1700000100",
                   "HEAD -> refs/heads/main", "G", "Subject\n\nBody line\n"].joined(separator: us)
        let details = PluginGit.parseDetails(out)
        XCTAssertEqual(details?.parents, ["p1", "p2"])
        XCTAssertEqual(details?.committerEmail, "bob@x")
        XCTAssertEqual(details?.commitDate, Date(timeIntervalSince1970: 1700000100))
        XCTAssertEqual(details?.refs, [.init(name: "main", kind: .head)])
        XCTAssertEqual(details?.signature, "G")
        XCTAssertEqual(details?.message, "Subject\n\nBody line")
        XCTAssertNil(PluginGit.parseDetails(""))
    }

    func testFileTreeCollapsesSingleChildFoldersAndPutsFoldersFirst() {
        let files = ["services/cockpit/app/aktionen/datenbank.py", "services/cockpit/app/auth.py",
                     "services/cockpit/tests/conftest.py", "README.md"]
            .map { PluginGit.ChangedFile(status: "M", path: $0) }
        let tree = PluginGit.fileTree(files)
        XCTAssertEqual(tree.map(\.name), ["services/cockpit", "README.md"])
        let cockpit = tree[0]
        XCTAssertEqual(cockpit.path, "services/cockpit")
        XCTAssertEqual(cockpit.children.map(\.name), ["app", "tests"])
        XCTAssertEqual(cockpit.children[0].children.map(\.name), ["aktionen", "auth.py"],
                       "a folder before the files beside it")
        XCTAssertEqual(cockpit.children[0].children[0].children.first?.file?.path,
                       "services/cockpit/app/aktionen/datenbank.py")
    }

    func testParseUnifiedDiffNumbersBothSides() {
        let diff = """
        diff --git a/f.py b/f.py
        index 1..2 100644
        --- a/f.py
        +++ b/f.py
        @@ -31,3 +31,3 @@ import threading
         keep
        -import pymssql
        +from x import y
         tail
        \\ No newline at end of file
        """
        let (lines, truncated) = PluginGit.parseUnifiedDiff(diff)
        XCTAssertFalse(truncated)
        XCTAssertEqual(lines.map(\.kind), [.hunk, .context, .removed, .added, .context, .meta],
                       "the header lines before the hunk are not shown")
        XCTAssertEqual(lines[1].oldLine, 31); XCTAssertEqual(lines[1].newLine, 31)
        XCTAssertEqual(lines[2].oldLine, 32); XCTAssertNil(lines[2].newLine)
        XCTAssertEqual(lines[3].newLine, 32); XCTAssertEqual(lines[3].text, "from x import y")
        XCTAssertEqual(lines[4].oldLine, 33); XCTAssertEqual(lines[4].newLine, 33)
    }

    func testParseUnifiedDiffReportsBinaryAndCutsLongDiffs() {
        let binary = PluginGit.parseUnifiedDiff("diff --git a/x b/x\nBinary files a/x and b/x differ\n")
        XCTAssertEqual(binary.lines.map(\.kind), [.binary])
        let long = "@@ -1,0 +1,10 @@\n" + (1...10).map { "+line \($0)" }.joined(separator: "\n")
        let cut = PluginGit.parseUnifiedDiff(long, limit: 4)
        XCTAssertTrue(cut.truncated)
        XCTAssertEqual(cut.lines.count, 4)
        // Exactly at the limit, with git's trailing newline: nothing was cut, so nothing is reported.
        let exact = PluginGit.parseUnifiedDiff("@@ -1,0 +1,3 @@\n+a\n+b\n+c\n", limit: 4)
        XCTAssertFalse(exact.truncated)
        XCTAssertEqual(exact.lines.count, 4)
    }

    /// The real thing: a commit that touches a file with an umlaut in its name, read through git.
    func testNameStatusOfANonASCIIPathAgainstRealGit() throws {
        let repo = try TempRepo()
        let dir = repo.dir
        @discardableResult
        func git(_ arguments: [String]) throws -> String { try repo.git(arguments, combined: false).out }
        try git(["init", "-q"])
        try "hi".write(to: dir.appendingPathComponent("Grüße.txt"), atomically: true, encoding: .utf8)
        try git(["add", "-A"])
        try git(["commit", "-q", "-m", "add"])
        let files = PluginGit.parseNameStatus(try git(PluginGit.nameStatusArguments("HEAD")))
        XCTAssertEqual(files.map(\.path), ["Grüße.txt"],
                       "the path as it is on disk, not git's quoted \"Gr\\303\\274\\303\\237e.txt\"")
    }

    func testGraphTextIsWideEnoughForTheLaneItDraws() {
        let row = PluginGit.GraphRow(lane: 3, lanes: ["a", "b", nil, "d"], merged: [])
        let text = PluginGit.graphText(row)
        XCTAssertEqual(text.count, 4)
        XCTAssertEqual(Array(text)[3], "●")
        XCTAssertEqual(Array(text)[2], " ", "a free lane draws nothing")
        XCTAssertEqual(Array(text)[0], "│")
    }

    // MARK: - Blame (phase 2)

    /// The porcelain format states a commit's details only the first time that commit appears; a parser
    /// that reads each block on its own loses the author from the second line of every commit onwards.
    func testParseBlameRemembersCommitDetails() {
        let out = """
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 1 1 2
        author Ada Lovelace
        author-time 1700000000
        summary first commit
        filename a.txt
        \tline one
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 2 2
        \tline two
        bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 3 3 1
        author Grace Hopper
        author-time 1700001000
        summary second commit
        filename a.txt
        \tline three
        """
        let lines = PluginGit.parseBlame(out)
        XCTAssertEqual(lines.map(\.line), [1, 2, 3])
        XCTAssertEqual(lines.map(\.author), ["Ada Lovelace", "Ada Lovelace", "Grace Hopper"])
        XCTAssertEqual(lines[1].summary, "first commit", "the referred-back commit keeps its details")
        XCTAssertEqual(lines.map(\.text), ["line one", "line two", "line three"])
        XCTAssertEqual(lines[2].date, Date(timeIntervalSince1970: 1700001000))
    }

    /// An uncommitted line is all zeros, and must not be shown as some very old commit.
    func testUncommittedBlameLine() {
        let out = """
        0000000000000000000000000000000000000000 4 4 1
        author Not Committed Yet
        author-time 1700002000
        summary uncommitted
        filename a.txt
        \tnew line
        """
        let line = PluginGit.parseBlame(out).first
        XCTAssertEqual(line?.isUncommitted, true)
        XCTAssertEqual(line?.line, 4)
    }

    // MARK: - Branches, stashes, conflicts (phase 3)

    private func us(_ parts: [String]) -> String { parts.joined(separator: "\u{1F}") }

    /// `for-each-ref` with an explicit format rather than `git branch -vv`, whose output is written for
    /// people: a `*` for the current branch, space-aligned columns, and the tracking state in brackets
    /// inside the subject.
    func testParseBranches() {
        let out = [
            us(["main", "*", "origin/main", "[ahead 2, behind 1]", "latest work", "refs/heads/main"]),
            us(["feature/x", " ", "", "", "a branch with no upstream", "refs/heads/feature/x"]),
            us(["origin/main", " ", "", "", "latest work", "refs/remotes/origin/main"]),
        ].joined(separator: "\n")
        let branches = PluginGit.parseBranches(out)
        XCTAssertEqual(branches.map(\.name), ["main", "feature/x", "origin/main"])
        XCTAssertTrue(branches[0].isCurrent)
        XCTAssertEqual(branches[0].upstream, "origin/main")
        XCTAssertEqual(branches[0].ahead, 2)
        XCTAssertEqual(branches[0].behind, 1)
        XCTAssertFalse(branches[0].isRemote)
        XCTAssertNil(branches[1].upstream)
        XCTAssertEqual(branches[1].ahead, 0)
        XCTAssertTrue(branches[2].isRemote)
    }

    func testParseBranchesHandlesAGoneUpstream() {
        let out = us(["old", " ", "origin/old", "[gone]", "subject", "refs/heads/old"])
        let branch = PluginGit.parseBranches(out).first
        XCTAssertEqual(branch?.upstream, "origin/old")
        XCTAssertEqual(branch?.ahead, 0)
        XCTAssertEqual(branch?.behind, 0)
    }

    /// A stash's own description says which branch it was made on, and that is the one worth showing: a
    /// stash from another branch is the one that needs care when popping.
    func testParseStashes() {
        let out = [us(["stash@{0}", "WIP on main: 1a2b3c4 the last commit"]),
                   us(["stash@{1}", "On feature/x: a message I typed"])].joined(separator: "\n")
        let stashes = PluginGit.parseStashes(out)
        XCTAssertEqual(stashes.map(\.ref), ["stash@{0}", "stash@{1}"])
        XCTAssertEqual(stashes[0].branch, "main")
        XCTAssertEqual(stashes[0].subject, "1a2b3c4 the last commit")
        XCTAssertEqual(stashes[1].branch, "feature/x")
        XCTAssertEqual(stashes[1].subject, "a message I typed")
    }

    /// Switching branches with a conflict or a staged change in the way is refused with a reason, because
    /// a half-finished checkout is worse than a refusal and git's own message is written for a terminal.
    func testSwitchRefusals() {
        let clean = PluginGit.parseStatus("# branch.head main\0")
        XCTAssertEqual(PluginGit.canSwitch(clean), PluginGit.SwitchRefusal.none)

        let staged = PluginGit.parseStatus("1 M. N... 100644 100644 100644 a b s.txt\0")
        XCTAssertEqual(PluginGit.canSwitch(staged), .staged(1))

        let conflicted = PluginGit.parseStatus(
            "u UU N... 100644 100644 100644 100644 a b c k.txt\0"
            + "1 M. N... 100644 100644 100644 a b s.txt\0")
        XCTAssertEqual(PluginGit.canSwitch(conflicted), .conflicts(1),
                       "a conflict outranks a staged change: it is the thing to deal with first")
    }

    /// Stage 2 is "ours", stage 3 is "theirs"; the common ancestor is stage 1 and is not shown, because
    /// the host's compare window takes two files.
    func testConflictSpecs() {
        let specs = PluginGit.conflictSpecs(path: "src/app.swift")
        XCTAssertEqual(specs.ours, ":2:src/app.swift")
        XCTAssertEqual(specs.theirs, ":3:src/app.swift")
    }

    // MARK: - Ignoring, worktrees, glyphs (phase 4)

    /// A leading slash matters: without it `build` matches a directory of that name at any depth, which is
    /// not what "ignore this folder" means. An extension glob is deliberately not anchored.
    func testIgnorePatterns() {
        XCTAssertEqual(PluginGit.ignorePattern(kind: .name, relativePath: "src/secret.txt"),
                       "/src/secret.txt")
        XCTAssertEqual(PluginGit.ignorePattern(kind: .extensionGlob, relativePath: "src/app.o"), "*.o")
        XCTAssertEqual(PluginGit.ignorePattern(kind: .directory, relativePath: "build"), "/build/")
        XCTAssertNil(PluginGit.ignorePattern(kind: .extensionGlob, relativePath: "Makefile"),
                     "a file without an extension has no extension glob")
    }

    func testAppendingIgnoreSkipsAnExactDuplicateOnly() {
        XCTAssertEqual(PluginGit.appendingIgnore("*.o", to: "build/\n"), "build/\n*.o\n")
        XCTAssertEqual(PluginGit.appendingIgnore("*.o", to: "build/"), "build/\n*.o\n",
                       "a file without a trailing newline still gets one")
        XCTAssertNil(PluginGit.appendingIgnore("*.o", to: "build/\n*.o\n"))
        XCTAssertNil(PluginGit.appendingIgnore("*.o", to: "build/\n  *.o  \n"),
                     "surrounding whitespace does not make it a different line")
        // Whether an existing pattern *implies* the new one is git's judgement, not this code's.
        XCTAssertEqual(PluginGit.appendingIgnore("/src/build/", to: "**/build\n"),
                       "**/build\n/src/build/\n")
    }

    /// In a linked worktree `.git` is a file, so `<root>/.git/index` does not exist and the cache had
    /// nothing to compare — the column then followed a commit only when the TTL expired.
    func testParseLocateWithGitDir() {
        let worktree = PluginGit.parseLocateWithGitDir(
            "/Users/x/wt\nsub/\n/Users/x/main/.git/worktrees/wt\n")
        XCTAssertEqual(worktree?.root, "/Users/x/wt")
        XCTAssertEqual(worktree?.prefix, "sub/")
        XCTAssertEqual(worktree?.gitDir, "/Users/x/main/.git/worktrees/wt")
    }

    func testParseLocateWithGitDirFallsBackForAnOlderGit() {
        let plain = PluginGit.parseLocateWithGitDir("/Users/x/repo\n\n")
        XCTAssertEqual(plain?.gitDir, "/Users/x/repo/.git",
                       "no --absolute-git-dir output: assume the normal layout")
        XCTAssertNil(PluginGit.parseLocateWithGitDir(""))
    }

    func testGlyphsAreDistinctPerChange() {
        let glyphs = PluginGit.Change.allCases.map(PluginGit.glyph(for:))
        XCTAssertEqual(Set(glyphs).count, glyphs.count, "each state needs its own glyph to be scannable")
        XCTAssertEqual(PluginGit.glyph(for: .conflict), "⚠")
        XCTAssertEqual(PluginGit.glyph(for: .unchanged), "")
    }

    /// git's own refusal talks about overwritten local changes as if the commit were at fault; the status
    /// the column already has says what is really in the way.
    func testCommitActionRefusal() {
        let clean = PluginGit.parseStatus("# branch.head main\0")
        XCTAssertNil(PluginGit.refusal(forCommitActionIn: clean))

        let untracked = PluginGit.parseStatus("# branch.head main\0? notes.txt\0")
        XCTAssertNil(PluginGit.refusal(forCommitActionIn: untracked),
                     "untracked files are none of the sequencer's business")

        let dirty = PluginGit.parseStatus("# branch.head main\0" + "1 .M N... 100644 100644 100644 ccc ddd a.txt\0")
        XCTAssertEqual(PluginGit.refusal(forCommitActionIn: dirty), .dirtyWorkingTree)

        let conflicted = PluginGit.parseStatus("# branch.head main\0" + "u UU N... 100644 100644 100644 100644 aaa bbb ccc a.txt\0")
        XCTAssertEqual(PluginGit.refusal(forCommitActionIn: conflicted), .conflictOpen,
                       "an open conflict outranks the generic dirty-tree reason")
    }

    func testRevertAndCherryPickNeverOpenAnEditor() {
        XCTAssertEqual(PluginGit.revertArguments("abc"), ["revert", "--no-edit", "abc"])
        XCTAssertEqual(PluginGit.cherryPickArguments("abc"), ["cherry-pick", "--no-edit", "abc"])
    }

    /// Every state a reader can see needs its own symbol, or the column trades one ambiguity for another.
    func testSymbolNamesAreDistinctPerChange() {
        let named = PluginGit.Change.allCases.compactMap(PluginGit.symbolName(for:))
        XCTAssertEqual(Set(named).count, named.count)
        XCTAssertNil(PluginGit.symbolName(for: .unchanged), "an unchanged file draws nothing")
        XCTAssertEqual(PluginGit.symbolName(for: .conflict), "exclamationmark.triangle.fill",
                       "the one a reader must not miss gets the system's warning symbol")
    }

    // MARK: - Blame in the gutter (F-426)

    /// Record N describes line N: an off-by-one here shifts every annotation against the line it is about,
    /// which is worse than showing nothing at all.
    func testGutterAnnotationsAreIndexedByLine() {
        let lines = [
            PluginGit.BlameLine(line: 1, hash: "aaaaaaaaaaaa", author: "Ada",
                                date: Date(timeIntervalSince1970: 0), summary: "adds the parser", text: "let x = 1"),
            PluginGit.BlameLine(line: 3, hash: "bbbbbbbbbbbb", author: "Linus",
                                date: Date(timeIntervalSince1970: 0), summary: "fixes it", text: "let z = 3"),
        ]
        let buffer = PluginGit.gutterAnnotations(lines, dateText: { _ in "1970-01-01" },
                                                uncommittedLabel: "(uncommitted)")
        let records = buffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(records.count, 4, "three lines plus the terminator")
        XCTAssertTrue(records[0].hasPrefix("aaaaaaaa  Ada"))
        XCTAssertEqual(records[1], "", "line 2 has no blame line, so it stays blank")
        XCTAssertTrue(records[2].hasPrefix("bbbbbbbb  Linus"))
        XCTAssertTrue(records[0].contains("\tadds the parser") || records[0].contains("adds the parser"),
                      "the subject belongs in the tooltip")
    }

    func testGutterAnnotationsMarkUncommittedAndNeverEmitATabInAField() {
        let lines = [
            PluginGit.BlameLine(line: 1, hash: "000000000000", author: "Not Committed Yet",
                                date: Date(timeIntervalSince1970: 0), summary: "with\ta tab", text: "x"),
            PluginGit.BlameLine(line: 2, hash: "cccccccccccc", author: "A\tB",
                                date: Date(timeIntervalSince1970: 0), summary: "sub\tject", text: "y"),
        ]
        let buffer = PluginGit.gutterAnnotations(lines, dateText: { _ in "x" },
                                                uncommittedLabel: "(uncommitted)")
        let records = buffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        XCTAssertTrue(records[0].hasPrefix("(uncommitted)\t"))
        // Exactly one tab per record: the host cuts at the first one, so a second would put half the
        // tooltip into the column the gutter draws.
        for record in records where !record.isEmpty {
            XCTAssertEqual(record.filter { $0 == "\t" }.count, 1, record)
            XCTAssertFalse(record.contains("\n"), "a newline in a record shifts every annotation after it")
        }
        XCTAssertEqual(PluginGit.gutterAnnotations([], dateText: { _ in "" }, uncommittedLabel: ""), "")
    }

    // MARK: - Refs in the history, and tags (F-425)

    func testParseRefsFromGitDecoration() {
        let refs = PluginGit.parseRefs("HEAD -> main, origin/main, tag: v1.0, feature")
        XCTAssertEqual(refs.map(\.name), ["main", "origin/main", "v1.0", "feature"])
        XCTAssertEqual(refs.map(\.kind), [.head, .remote, .tag, .branch])
        XCTAssertEqual(PluginGit.parseRefs(""), [])
        XCTAssertEqual(PluginGit.parseRefs("HEAD"), [PluginGit.Ref(name: "HEAD", kind: .head)],
                       "a detached HEAD decorates as just HEAD")
    }

    /// The decoration is appended as a seventh field, so every existing index stays where it was — a
    /// shifted field is the defect `parseStatus` had with renames, and it is not worth repeating.
    func testLogParsesRefsAndStillWorksWithoutThem() {
        let us = "\u{1F}", rs = "\u{1E}"
        let withRefs = "aaa\(us)aaa1\(us)bbb\(us)T\(us)0\(us)subject\(us)HEAD -> main, tag: v2\(rs)"
        let commit = PluginGit.parseLog(withRefs).first
        XCTAssertEqual(commit?.subject, "subject")
        XCTAssertEqual(commit?.refs.map(\.name), ["main", "v2"])

        let withoutRefs = "aaa\(us)aaa1\(us)bbb\(us)T\(us)0\(us)subject\(rs)"
        let older = PluginGit.parseLog(withoutRefs).first
        XCTAssertEqual(older?.subject, "subject", "six fields must still parse")
        XCTAssertEqual(older?.refs, [], "and simply carry no refs")
    }

    func testParseTags() {
        let us = "\u{1F}"
        let out = "v2.0\(us)tag\(us)the second release\(us)1700000000\n"
            + "v1.9\(us)commit\(us)\(us)1690000000\n"
        let tags = PluginGit.parseTags(out)
        XCTAssertEqual(tags.map(\.name), ["v2.0", "v1.9"])
        XCTAssertTrue(tags[0].isAnnotated)
        XCTAssertEqual(tags[0].subject, "the second release")
        XCTAssertFalse(tags[1].isAnnotated, "objecttype commit means a lightweight tag")
        XCTAssertEqual(tags[1].date, Date(timeIntervalSince1970: 1690000000))
        XCTAssertEqual(PluginGit.parseTags("nonsense\n"), [], "a line with too few fields is skipped")
    }

    /// Annotated when there is a message, lightweight when there is not — that *is* the difference.
    func testTagArguments() {
        XCTAssertEqual(PluginGit.createTagArguments(name: "v1", message: nil), ["tag", "v1"])
        XCTAssertEqual(PluginGit.createTagArguments(name: "v1", message: nil, at: "abc"), ["tag", "v1", "abc"])
        XCTAssertEqual(PluginGit.createTagArguments(name: "v1", message: "m", at: "abc"), ["tag", "-a", "v1", "-m", "m", "abc"])
        XCTAssertEqual(PluginGit.createTagArguments(name: "v1", message: ""), ["tag", "v1"])
        XCTAssertEqual(PluginGit.createTagArguments(name: "v1", message: "ship it"),
                       ["tag", "-a", "v1", "-m", "ship it"])
        XCTAssertEqual(PluginGit.deleteTagArguments("v1"), ["tag", "-d", "v1"])
        // `git push` does not carry tags, which is the standard surprise about them.
        XCTAssertEqual(PluginGit.pushTagArguments(remote: "origin", name: "v1"),
                       ["push", "origin", "refs/tags/v1"])
        XCTAssertEqual(PluginGit.checkoutTagArguments("v1"), ["checkout", "v1"])
    }

    // MARK: - Rebase (phase 5d)

    private static func commit(_ hash: String, _ subject: String) -> PluginGit.Commit {
        PluginGit.Commit(hash: hash, shortHash: String(hash.prefix(8)), parents: [], author: "T",
                         date: Date(timeIntervalSince1970: 0), subject: subject)
    }

    /// Oldest first, which is the opposite of `log` order and the direction git applies them in. Getting it
    /// backwards produces a rebase that succeeds and reorders the branch wrongly.
    func testRebaseTodoIsWrittenInApplyOrder() {
        let commits = [Self.commit("aaa", "first"), Self.commit("bbb", "second"),
                       Self.commit("ccc", "third")]
        let todo = PluginGit.rebaseTodo(commits: commits, actions: [.pick, .squash, .drop])
        XCTAssertEqual(todo, "pick aaa first\nsquash bbb second\ndrop ccc third\n")
        // A short actions list means the rest is picked, not dropped.
        XCTAssertEqual(PluginGit.rebaseTodo(commits: commits, actions: [.reword]),
                       "reword aaa first\npick bbb second\npick ccc third\n")
    }

    func testSequenceEditorHandsGitOurTodoFile() {
        XCTAssertEqual(PluginGit.sequenceEditorValue(todoPath: "/tmp/a b/todo"),
                       "cp '/tmp/a b/todo'", "a repository may live under a path with spaces")
        XCTAssertEqual(PluginGit.sequenceEditorValue(todoPath: "/tmp/it's/todo"),
                       "cp '/tmp/it'\\''s/todo'", "and a quote must not end the quoting")
        XCTAssertEqual(PluginGit.editorValue(messagePath: nil), "true",
                       "no message: accept what git pre-filled, which is what a squash needs")
        XCTAssertEqual(PluginGit.editorValue(messagePath: "/tmp/msg"), "cp '/tmp/msg'")
    }

    func testRebaseRefusals() {
        let clean = PluginGit.parseStatus("# branch.head main\0# branch.upstream origin/main\0")
        let dirty = PluginGit.parseStatus("# branch.head main\0# branch.upstream origin/main\0"
            + "1 .M N... 100644 100644 100644 ccc ddd a.txt\0")
        let noUpstream = PluginGit.parseStatus("# branch.head main\0")

        XCTAssertNil(PluginGit.rebaseRefusal(repo: clean, aheadCount: 2, actions: [.pick, .squash],
                                             rebaseRunning: false))
        XCTAssertEqual(PluginGit.rebaseRefusal(repo: clean, aheadCount: 2, actions: [.pick],
                                               rebaseRunning: true), .rebaseAlreadyRunning)
        XCTAssertEqual(PluginGit.rebaseRefusal(repo: dirty, aheadCount: 2, actions: [.pick],
                                               rebaseRunning: false), .dirtyWorkingTree)
        XCTAssertEqual(PluginGit.rebaseRefusal(repo: noUpstream, aheadCount: 2, actions: [.pick],
                                               rebaseRunning: false), .noUpstream)
        XCTAssertEqual(PluginGit.rebaseRefusal(repo: clean, aheadCount: 0, actions: [],
                                               rebaseRunning: false), .nothingAhead)
        // The oldest line has nothing left to squash into.
        XCTAssertEqual(PluginGit.rebaseRefusal(repo: clean, aheadCount: 2, actions: [.squash, .pick],
                                               rebaseRunning: false), .squashWithoutParent)
        // Two rewords would be handed the same message file, so both commits would get the same message.
        XCTAssertEqual(PluginGit.rebaseRefusal(repo: clean, aheadCount: 3,
                                               actions: [.reword, .reword, .pick],
                                               rebaseRunning: false), .severalRewords(2))
    }

    func testRebaseIsRunningLooksWhereGitLooks() {
        let merge = "/repo/.git/rebase-merge"
        XCTAssertTrue(PluginGit.rebaseIsRunning(gitDir: "/repo/.git") { $0 == merge })
        XCTAssertTrue(PluginGit.rebaseIsRunning(gitDir: "/repo/.git") { $0.hasSuffix("rebase-apply") },
                      "the --apply machinery counts too")
        XCTAssertFalse(PluginGit.rebaseIsRunning(gitDir: "/repo/.git") { _ in false })
        // A linked worktree keeps its state in its own git dir, not in <root>/.git (F-419).
        XCTAssertTrue(PluginGit.rebaseIsRunning(gitDir: "/main/.git/worktrees/wt") {
            $0 == "/main/.git/worktrees/wt/rebase-merge"
        })
    }

    // MARK: - Remotes, credentials, web links (phase 5b/5c)

    /// Which credentials apply is decided by the transport, and telling somebody to add an SSH key when
    /// their remote is HTTPS is worse than saying nothing.
    func testRemoteTransport() {
        XCTAssertEqual(PluginGit.transport(of: "https://github.com/o/r.git"), .https)
        XCTAssertEqual(PluginGit.transport(of: "git@github.com:o/r.git"), .ssh,
                       "the scp-like form is SSH without saying so")
        XCTAssertEqual(PluginGit.transport(of: "ssh://git@example.com:2222/o/r.git"), .ssh)
        XCTAssertEqual(PluginGit.transport(of: "git://example.com/o/r.git"), .git)
        XCTAssertEqual(PluginGit.transport(of: "/Users/x/repo"), .local)
        XCTAssertEqual(PluginGit.transport(of: ""), .unknown)
    }

    func testRemoteHostAndPathAcrossEveryFormGitAccepts() {
        let cases: [(String, String, String)] = [
            ("https://github.com/owner/repo.git", "github.com", "owner/repo"),
            ("https://user@github.com/owner/repo", "github.com", "owner/repo"),
            ("git@github.com:owner/repo.git", "github.com", "owner/repo"),
            ("ssh://git@gitlab.com/group/sub/repo.git", "gitlab.com", "group/sub/repo"),
            ("ssh://git@example.com:2222/owner/repo.git", "example.com", "owner/repo"),
            ("git://example.com/owner/repo.git", "example.com", "owner/repo"),
        ]
        for (url, host, path) in cases {
            let parsed = PluginGit.remoteHostAndPath(url)
            XCTAssertEqual(parsed?.host, host, url)
            XCTAssertEqual(parsed?.path, path, url)
        }
        XCTAssertNil(PluginGit.remoteHostAndPath("nonsense"))
        XCTAssertNil(PluginGit.remoteHostAndPath(""))
    }

    func testCredentialFindings() {
        func report(_ url: String, helper: String? = nil, keys: Int? = nil) -> PluginGit.CredentialReport {
            PluginGit.CredentialReport(remoteName: "origin", remoteURL: url, helper: helper,
                                       agentKeys: keys)
        }
        XCTAssertEqual(PluginGit.findings(report("")), [.noRemote])
        XCTAssertEqual(PluginGit.findings(report("https://github.com/o/r.git")), [.httpsWithoutHelper])
        XCTAssertEqual(PluginGit.findings(report("https://github.com/o/r.git", helper: "osxkeychain")),
                       [.httpsWithHelper])
        XCTAssertEqual(PluginGit.findings(report("git@github.com:o/r.git", keys: 2)), [.sshAgentReady])
        XCTAssertEqual(PluginGit.findings(report("git@github.com:o/r.git", keys: 0)), [.sshAgentEmpty])
        XCTAssertEqual(PluginGit.findings(report("git@github.com:o/r.git", keys: nil)),
                       [.sshAgentUnreachable], "no agent to ask is different advice from an empty agent")
        XCTAssertEqual(PluginGit.findings(report("/Users/x/repo")), [.localRemote])

        // The one action offered — and only where it applies.
        XCTAssertTrue(PluginGit.offersKeychainHelper([.httpsWithoutHelper]))
        XCTAssertFalse(PluginGit.offersKeychainHelper([.sshAgentEmpty]))
        XCTAssertEqual(PluginGit.keychainHelperArguments,
                       ["config", "--global", "credential.helper", "osxkeychain"])
    }

    /// `ssh-add -l` distinguishes "no keys" (1) from "no agent" (2), which is the difference between
    /// "add a key" and "start an agent" — hence Int? rather than Bool.
    func testParseAgentKeys() {
        XCTAssertEqual(PluginGit.parseAgentKeys(output: "256 SHA256:aa a@b (ED25519)\n", exitCode: 0), 1)
        XCTAssertEqual(PluginGit.parseAgentKeys(output: "a\nb\n\n", exitCode: 0), 2)
        XCTAssertEqual(PluginGit.parseAgentKeys(output: "The agent has no identities.\n", exitCode: 1), 0)
        XCTAssertNil(PluginGit.parseAgentKeys(
            output: "Could not open a connection to your authentication agent.\n", exitCode: 2))
    }

    func testWebURLsPerService() {
        let file = PluginGit.WebTarget.file(path: "src/app swift/main.swift", ref: "main")
        XCTAssertEqual(PluginGit.webURL(remote: "git@github.com:o/r.git", target: file),
                       "https://github.com/o/r/blob/main/src/app%20swift/main.swift")
        XCTAssertEqual(PluginGit.webURL(remote: "https://gitlab.com/g/r.git", target: file),
                       "https://gitlab.com/g/r/-/blob/main/src/app%20swift/main.swift")
        XCTAssertEqual(PluginGit.webURL(remote: "git@bitbucket.org:o/r.git", target: file),
                       "https://bitbucket.org/o/r/src/main/src/app%20swift/main.swift")
        XCTAssertEqual(PluginGit.webURL(remote: "git@github.com:o/r.git", target: .commit("abc123")),
                       "https://github.com/o/r/commit/abc123")
        XCTAssertEqual(PluginGit.webURL(remote: "https://gitlab.example.org/g/r.git",
                                        target: .commit("abc123")),
                       "https://gitlab.example.org/g/r/-/commit/abc123",
                       "a host named gitlab.* is one we do know the shape of")
        XCTAssertEqual(PluginGit.webURL(remote: "git@github.com:o/r.git", target: .branch("feature/x")),
                       "https://github.com/o/r/tree/feature/x")
    }

    /// A self-hosted GitHub Enterprise cannot be told from any other host by its name, so a deep link
    /// would be a guess that 404s and looks like a defect in the file manager.
    func testUnknownHostGetsTheRootOnly() {
        XCTAssertEqual(PluginGit.webURL(remote: "git@git.company.example:o/r.git", target: .repository),
                       "https://git.company.example/o/r")
        XCTAssertNil(PluginGit.webURL(remote: "git@git.company.example:o/r.git",
                                      target: .commit("abc123")))
        XCTAssertNil(PluginGit.webURL(remote: "nonsense", target: .repository))
    }

    func testWebRefPrefersWhatOtherPeopleCanSee() {
        XCTAssertEqual(PluginGit.webRef(PluginGit.RepoStatus(branch: "local-name",
                                                            upstream: "origin/main")), "main")
        XCTAssertEqual(PluginGit.webRef(PluginGit.RepoStatus(branch: "feature")), "feature")
        XCTAssertEqual(PluginGit.webRef(PluginGit.RepoStatus(branch: "", detached: true)), "HEAD",
                       "every one of the four services resolves HEAD to their default branch")
    }

    // MARK: - Conflict markers (phase 5a)

    private static let twoWay = """
        keep this
        <<<<<<< HEAD
        ours line
        =======
        theirs line
        >>>>>>> feature
        and this

        """

    func testParseTwoWayConflict() throws {
        let file = try XCTUnwrap(PluginGit.parseConflicts(Self.twoWay))
        XCTAssertEqual(file.hunks.count, 1)
        XCTAssertEqual(file.hunks[0].ours, ["ours line"])
        XCTAssertEqual(file.hunks[0].theirs, ["theirs line"])
        XCTAssertEqual(file.hunks[0].oursLabel, "HEAD")
        XCTAssertEqual(file.hunks[0].theirsLabel, "feature")
        XCTAssertNil(file.hunks[0].base)
        XCTAssertEqual(file.hunks[0].startLine, 2, "the list has to be able to say where it is")
    }

    func testParseDiff3StyleKeepsTheAncestor() throws {
        let text = """
            <<<<<<< HEAD
            ours
            ||||||| base commit
            original
            =======
            theirs
            >>>>>>> other

            """
        let file = try XCTUnwrap(PluginGit.parseConflicts(text))
        XCTAssertEqual(file.hunks[0].base, ["original"])
        XCTAssertEqual(file.hunks[0].baseLabel, "base commit")
    }

    func testRenderPerChoice() throws {
        let file = try XCTUnwrap(PluginGit.parseConflicts(Self.twoWay))
        XCTAssertEqual(PluginGit.render(file, choices: [.ours]),
                       "keep this\nours line\nand this\n")
        XCTAssertEqual(PluginGit.render(file, choices: [.theirs]),
                       "keep this\ntheirs line\nand this\n")
        XCTAssertEqual(PluginGit.render(file, choices: [.both]),
                       "keep this\nours line\ntheirs line\nand this\n",
                       "both means ours first, which is the order the file had them in")
    }

    /// Writing a half-finished resolution must lose nothing: an untouched hunk goes back marker for
    /// marker, so the file is exactly as conflicted as it was.
    func testUnresolvedRoundTripsByteForByte() throws {
        for text in [Self.twoWay,
                     "<<<<<<< HEAD\nours\n||||||| base\nold\n=======\ntheirs\n>>>>>>> them\n",
                     "<<<<<<<\nours\n=======\ntheirs\n>>>>>>>\n"] {
            let file = try XCTUnwrap(PluginGit.parseConflicts(text))
            XCTAssertEqual(PluginGit.render(file, choices: []), text)
        }
    }

    /// `"\r\n"` is a single Character in Swift, so a parser splitting on `"\n"` sees a Windows file as
    /// one line — the trap the menu-file parsers hit (F-257). Here it would write the file back with the
    /// wrong endings on every line.
    func testCRLFSurvives() throws {
        let text = Self.twoWay.replacingOccurrences(of: "\n", with: "\r\n")
        let file = try XCTUnwrap(PluginGit.parseConflicts(text))
        XCTAssertTrue(file.usesCRLF)
        XCTAssertEqual(file.hunks[0].ours, ["ours line"], "no stray carriage return in the content")
        XCTAssertEqual(PluginGit.render(file, choices: []), text)
        XCTAssertEqual(PluginGit.render(file, choices: [.ours]),
                       "keep this\r\nours line\r\nand this\r\n")
    }

    func testFileWithoutTrailingNewlineStaysThatWay() throws {
        let file = try XCTUnwrap(PluginGit.parseConflicts(
            "<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> them"))
        XCTAssertFalse(file.endsWithNewline)
        XCTAssertEqual(PluginGit.render(file, choices: [.ours]), "ours")
    }

    /// This text is about to be written over the reader's file. A marker set we cannot read must stop the
    /// window, not produce a best guess.
    func testMalformedMarkersAreRefused() {
        let cases = [
            "<<<<<<< HEAD\nours\n>>>>>>> them\n":                     "no separator",
            "<<<<<<< a\nx\n<<<<<<< b\ny\n=======\nz\n>>>>>>> c\n": "nested conflict",
            "=======\nstray\n":                                      "separator outside a conflict",
            ">>>>>>> them\n":                                         "closes nothing",
            "<<<<<<< HEAD\nours\n=======\ntheirs\n":                 "truncated: no closing marker",
            "||||||| base\nx\n":                                     "an ancestor outside a conflict",
        ]
        for (text, why) in cases {
            XCTAssertNil(PluginGit.parseConflicts(text), "must refuse — \(why)")
        }
    }

    func testACleanFileHasNoHunksAndSurvivesUnchanged() throws {
        let text = "nothing here\nnot even a marker\n=========== not a separator either\n"
        let file = try XCTUnwrap(PluginGit.parseConflicts(text))
        XCTAssertTrue(file.hunks.isEmpty, "a longer run of equals signs is a document, not a marker")
        XCTAssertEqual(PluginGit.render(file, choices: []), text)
    }

    // MARK: - Against the real binary

    /// The fixtures above are shapes; this proves the shape is real. Builds a repository with the cases
    /// that broke the old parser — a non-ASCII name, a space, a rename, a staged and an unstaged edit,
    /// an untracked file — runs the actual status call and asserts what comes back.
    func testAgainstRealGit() throws {
        let repo = try TempRepo()
        let dir = repo.dir
        func run(_ arguments: [String]) throws { try repo.git(arguments) }
        func status() throws -> String { try repo.git(PluginGit.statusArguments, combined: false).out }

        try run(["init", "-q", "-b", "main", "."])
        try "one\n".write(to: dir.appendingPathComponent("Größe mit Leerzeichen.txt"), atomically: true,
                          encoding: .utf8)
        try "two\n".write(to: dir.appendingPathComponent("to-rename.txt"), atomically: true, encoding: .utf8)
        try "three\n".write(to: dir.appendingPathComponent("edited.txt"), atomically: true, encoding: .utf8)
        try run(["add", "-A"]); try run(["commit", "-q", "-m", "start"])
        try run(["mv", "to-rename.txt", "renamed.txt"])
        try "three, changed\n".write(to: dir.appendingPathComponent("edited.txt"), atomically: true,
                                    encoding: .utf8)
        try "new\n".write(to: dir.appendingPathComponent("untracked.txt"), atomically: true, encoding: .utf8)

        let parsed = PluginGit.parseStatus(try status())
        XCTAssertEqual(parsed.branch, "main")
        XCTAssertEqual(parsed.files["renamed.txt"]?.staged, .renamed)
        XCTAssertEqual(parsed.files["renamed.txt"]?.originalPath, "to-rename.txt")
        XCTAssertEqual(parsed.files["edited.txt"]?.worktree, .modified)
        XCTAssertEqual(parsed.files["untracked.txt"]?.worktree, .untracked)
        // And the file whose name broke the old parser is simply absent from the changes: it is committed
        // and unmodified. Its *presence* would mean the parser is inventing entries.
        XCTAssertNil(parsed.files["Größe mit Leerzeichen.txt"])

        // Now dirty it, and it must appear under its real name rather than a quoted one.
        try "one, changed\n".write(to: dir.appendingPathComponent("Größe mit Leerzeichen.txt"),
                                  atomically: true, encoding: .utf8)
        let dirty = PluginGit.parseStatus(try status())
        XCTAssertEqual(dirty.files["Größe mit Leerzeichen.txt"]?.worktree, .modified,
                       "the umlaut path must arrive raw — this is the reported defect")
        XCTAssertFalse(dirty.files.keys.contains { $0.contains("\\303") }, "no quoted path may survive")
    }

    /// Revert and cherry-pick against the real binary, in a repository built for it.
    ///
    /// The claim worth proving is not that git can revert — it is that *these* argument lists do it
    /// without an editor and without a terminal, which is the only way a plugin inside a GUI process can
    /// run them. `GIT_EDITOR=false` makes that check real: an editor that gets launched fails, so a
    /// missing `--no-edit` turns into a failed test rather than a window nobody can close (F-419).
    func testRevertAndCherryPickAgainstRealGit() throws {
        let repo = try TempRepo()
        let dir = repo.dir
        // Any editor launch is a failure, not a hang.
        @discardableResult
        func git(_ arguments: [String]) throws -> (out: String, ok: Bool) {
            try repo.git(arguments, environment: ["GIT_EDITOR": "false"])
        }
        func read(_ name: String) -> String? {
            try? String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
        }
        func status() throws -> PluginGit.RepoStatus {
            PluginGit.parseStatus(try git(PluginGit.statusArguments).out)
        }

        try git(["init", "-q", "-b", "main", "."])
        try "one\n".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try git(["add", "-A"]); try git(["commit", "-q", "-m", "start"])
        try "one\ntwo\n".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try git(["commit", "-qam", "adds two"])
        let toRevert = try git(["rev-parse", "HEAD"]).out.trimmingCharacters(in: .whitespacesAndNewlines)

        // A side branch with a commit to pick, and back to main.
        try git(["checkout", "-q", "-b", "side"])
        try "picked\n".write(to: dir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        try git(["add", "-A"]); try git(["commit", "-q", "-m", "adds b"])
        let toPick = try git(["rev-parse", "HEAD"]).out.trimmingCharacters(in: .whitespacesAndNewlines)
        try git(["checkout", "-q", "main"])

        XCTAssertNil(PluginGit.refusal(forCommitActionIn: try status()), "the tree is clean here")

        let reverted = try git(PluginGit.revertArguments(toRevert))
        XCTAssertTrue(reverted.ok, "revert failed: \(reverted.out)")
        XCTAssertEqual(read("a.txt"), "one\n", "the revert must undo the second commit's change")

        let picked = try git(PluginGit.cherryPickArguments(toPick))
        XCTAssertTrue(picked.ok, "cherry-pick failed: \(picked.out)")
        XCTAssertEqual(read("b.txt"), "picked\n", "the picked commit's file must be here")
        XCTAssertNil(try status().files["b.txt"], "and it must be committed, not left in the index")

        // Finally the refusal the buttons rely on: a modified tracked file, and git would refuse anyway.
        try "dirty\n".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        XCTAssertEqual(PluginGit.refusal(forCommitActionIn: try status()), .dirtyWorkingTree)
        XCTAssertFalse(try git(PluginGit.revertArguments(toRevert)).ok,
                       "git itself refuses too — the check only says so in better words")
    }

    /// A conflict git actually produced, resolved the way the window resolves it: parse the working file,
    /// render one side, write it, stage it — and then ask git whether the conflict is gone (F-420).
    ///
    /// The fixtures above are hand-written marker sets; this proves the markers git writes are the ones
    /// the parser reads, including the labels, and that the resolved text satisfies git rather than only
    /// looking right.
    func testResolvingARealConflict() throws {
        let repo = try TempRepo()
        let dir = repo.dir
        // Any editor launch is a failure, not a hang.
        @discardableResult
        func git(_ arguments: [String]) throws -> (out: String, ok: Bool) {
            try repo.git(arguments, environment: ["GIT_EDITOR": "false"])
        }
        let file = dir.appendingPathComponent("shared.txt")

        try git(["init", "-q", "-b", "main", "."])
        try "top\nmiddle\nbottom\n".write(to: file, atomically: true, encoding: .utf8)
        try git(["add", "-A"]); try git(["commit", "-q", "-m", "start"])
        try git(["checkout", "-q", "-b", "side"])
        try "top\ntheir middle\nbottom\n".write(to: file, atomically: true, encoding: .utf8)
        try git(["commit", "-qam", "theirs"])
        try git(["checkout", "-q", "main"])
        try "top\nour middle\nbottom\n".write(to: file, atomically: true, encoding: .utf8)
        try git(["commit", "-qam", "ours"])
        XCTAssertFalse(try git(["merge", "side"]).ok, "this merge is supposed to conflict")

        let conflicted = try String(contentsOf: file, encoding: .utf8)
        let parsed = try XCTUnwrap(PluginGit.parseConflicts(conflicted),
                                   "git's own markers must parse")
        XCTAssertEqual(parsed.hunks.count, 1)
        XCTAssertEqual(parsed.hunks[0].ours, ["our middle"])
        XCTAssertEqual(parsed.hunks[0].theirs, ["their middle"])
        XCTAssertEqual(parsed.hunks[0].oursLabel, "HEAD", "git labels our side HEAD")
        XCTAssertEqual(parsed.hunks[0].theirsLabel, "side")

        // Unresolved must round-trip through git's own text, not just through our fixtures.
        XCTAssertEqual(PluginGit.render(parsed, choices: []), conflicted)

        // Now resolve it the way the window does, and let git judge the result.
        try PluginGit.render(parsed, choices: [.both]).write(to: file, atomically: true, encoding: .utf8)
        try git(["add", "--", "shared.txt"])
        let after = PluginGit.parseStatus(try git(PluginGit.statusArguments).out)
        XCTAssertNil(after.files["shared.txt"].map(\.summary).flatMap { $0 == .conflict ? true : nil },
                     "git must no longer see a conflict")
        XCTAssertEqual(after.files["shared.txt"]?.isStaged, true)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8),
                       "top\nour middle\ntheir middle\nbottom\n",
                       "both sides, ours first, and no markers left behind")
        XCTAssertTrue(try git(["commit", "-q", "-m", "merged"]).ok,
                      "and the merge can be committed")
    }

    /// The rebase trick against the real binary: git runs `$GIT_SEQUENCE_EDITOR <todo>`, so `cp <ours>`
    /// hands it a todo list we wrote — no editor process, no terminal (F-423).
    ///
    /// Two commits squashed into one and a third dropped, then git is asked what the branch looks like.
    /// Without `GIT_EDITOR=true` the squash would try to open an editor for the combined message and the
    /// rebase would stop half-way, which is exactly the failure this proves cannot happen.
    func testInteractiveRebaseAgainstRealGit() throws {
        let repo = try TempRepo()
        let dir = repo.dir
        @discardableResult
        func git(_ arguments: [String], environment extra: [String: String] = [:])
            throws -> (out: String, ok: Bool) {
            try repo.git(arguments, environment: extra)
        }

        try git(["init", "-q", "-b", "main", "."])
        try "base\n".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try git(["add", "-A"]); try git(["commit", "-q", "-m", "base"])
        try git(["branch", "upstream-stand-in"])
        // A real upstream, because the refusal check asks for one — a local branch is allowed to be one,
        // which keeps this test off the network.
        try git(["branch", "--set-upstream-to=upstream-stand-in", "main"])
        for (file, message) in [("b.txt", "adds b"), ("c.txt", "adds c"), ("d.txt", "adds d")] {
            try "x\n".write(to: dir.appendingPathComponent(file), atomically: true, encoding: .utf8)
            try git(["add", "-A"]); try git(["commit", "-q", "-m", message])
        }

        // The commits ahead, oldest first — which is the order the todo file wants.
        let ahead = PluginGit.parseLog(try git(PluginGit.logArguments(limit: 20, path: nil)
            + ["upstream-stand-in..HEAD"]).out).reversed().map { $0 }
        XCTAssertEqual(ahead.map(\.subject), ["adds b", "adds c", "adds d"])
        XCTAssertNil(PluginGit.rebaseRefusal(
            repo: PluginGit.parseStatus(try git(PluginGit.statusArguments).out),
            aheadCount: ahead.count, actions: [.pick, .squash, .drop], rebaseRunning: false),
            "a clean tree with three commits ahead: nothing in the way except the missing upstream")

        let todo = dir.appendingPathComponent("pc-todo")
        try PluginGit.rebaseTodo(commits: ahead, actions: [.pick, .squash, .drop])
            .write(to: todo, atomically: true, encoding: .utf8)
        let result = try git(PluginGit.rebaseArguments(upstream: "upstream-stand-in"), environment: [
            "GIT_SEQUENCE_EDITOR": PluginGit.sequenceEditorValue(todoPath: todo.path),
            "GIT_EDITOR": PluginGit.editorValue(messagePath: nil),
        ])
        XCTAssertTrue(result.ok, "rebase failed: \(result.out)")

        let after = PluginGit.parseLog(try git(PluginGit.logArguments(limit: 20, path: nil)
            + ["upstream-stand-in..HEAD"]).out)
        XCTAssertEqual(after.count, 1, "two commits squashed into one, the third dropped")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("b.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("c.txt").path),
                      "the squashed commit's change must still be there")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("d.txt").path),
                       "and the dropped one's must not")

        // And nothing is left half-finished.
        let gitDir = dir.appendingPathComponent(".git").path
        XCTAssertFalse(PluginGit.rebaseIsRunning(gitDir: gitDir) {
            FileManager.default.fileExists(atPath: $0)
        })
    }
}

/// A temporary repository for the tests that run real git, removed again when the test is done.
///
/// git is isolated from this machine: no global or system configuration, no terminal prompt, a fixed
/// committer — and no locale, the way an app started from Finder runs it, which is the case the plugin
/// has to work in (the search's case folding failed exactly there).
// MARK: - Phase 9: the tree at any commit, git-flow, the merge editor, pull requests and CI

extension PluginGitTests {

    func testTheTreeAtACommitAndRestoringAFileAgainstRealGit() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        let file = repo.dir.appendingPathComponent("Grüße.txt")
        try FileManager.default.createDirectory(at: repo.dir.appendingPathComponent("src"), withIntermediateDirectories: true)
        try "one\ntwo\n".write(to: file, atomically: true, encoding: .utf8)
        try "x".write(to: repo.dir.appendingPathComponent("src/a.swift"), atomically: true, encoding: .utf8)
        try Data([0x89, 0x50, 0x00, 0x01]).write(to: repo.dir.appendingPathComponent("logo.png"))
        try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", "first"])
        let first = try repo.git(["rev-parse", "HEAD"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines)
        try "changed\n".write(to: file, atomically: true, encoding: .utf8)
        try repo.git(["commit", "-q", "-am", "second"])

        let files = PluginGit.parseTreeFiles(try repo.git(PluginGit.treeFilesArguments(first), combined: false).out)
        XCTAssertEqual(files.map(\.path).sorted(), ["Grüße.txt", "logo.png", "src/a.swift"], "names unquoted")
        XCTAssertEqual(files.first?.status, "")

        let text = PluginGit.fileContentLines(Data("one\ntwo\n".utf8))
        XCTAssertEqual(text.lines.map(\.text), ["one", "two"])
        XCTAssertEqual(text.lines.map(\.newLine), [1, 2])
        XCTAssertFalse(text.binary)
        XCTAssertTrue(PluginGit.fileContentLines(Data([0x89, 0x50, 0x00, 0x01])).binary)
        let long = PluginGit.fileContentLines(Data((1...20).map(String.init).joined(separator: "\n").utf8), limit: 5)
        XCTAssertEqual(long.lines.count, 5)
        XCTAssertTrue(long.truncated)

        XCTAssertTrue(try repo.git(PluginGit.restoreFileArguments(commit: first, path: "Grüße.txt")).ok)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "one\ntwo\n")
        let status = try repo.git(["status", "--porcelain"], combined: false).out
        XCTAssertTrue(status.hasPrefix(" M"), "back in the working tree only, not staged: \(status)")
    }

    func testFlowNames() {
        var flow = PluginGit.Flow()
        flow.tagPrefix = "v"
        XCTAssertEqual(flow.kind(ofBranch: "feature/login")?.kind, .feature)
        XCTAssertEqual(flow.kind(ofBranch: "release/1.2")?.name, "1.2")
        XCTAssertNil(flow.kind(ofBranch: "feature/"))
        XCTAssertNil(flow.kind(ofBranch: "main"))
        XCTAssertEqual(flow.tag(for: "1.2"), "v1.2")
        XCTAssertEqual(flow.base(.hotfix), "main")
        XCTAssertEqual(flow.base(.release), "develop")
        XCTAssertTrue(PluginGit.isValidFlowName("login-form"))
        XCTAssertTrue(PluginGit.isValidFlowName("1.2.0"))
        for bad in ["", "a b", "a..b", "-x", "x/", "x.lock", "a:b", "a~1", "a^", "a?", "a*", "a[", "a@{1}"] {
            XCTAssertFalse(PluginGit.isValidFlowName(bad), bad)
        }
        XCTAssertEqual(PluginGit.flowStartArguments(.feature, name: "x", flow: flow, hasDevelop: false),
                       [["branch", "develop", "main"], ["switch", "-c", "feature/x", "develop"]])
        XCTAssertEqual(PluginGit.flowStartArguments(.hotfix, name: "1.0.1", flow: flow, hasDevelop: false),
                       [["switch", "-c", "hotfix/1.0.1", "main"]], "a hotfix needs no develop")
        // Finishing again after a conflict skips what is already done.
        let resumed = PluginGit.flowFinishArguments(.release, name: "1.2", flow: flow,
                                                    state: .init(mergedIntoMain: true, tagged: true))
        XCTAssertEqual(resumed, [["switch", "develop"], ["merge", "--no-ff", "--no-edit", "release/1.2"],
                                 ["branch", "-d", "release/1.2"]])
    }

    /// A feature and a release through the whole cycle, in a real repository: develop is created, the
    /// release lands in main and develop with its tag, and the branches are gone afterwards.
    func testFlowCycleAgainstRealGit() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        try repo.git(["commit", "-q", "--allow-empty", "-m", "base"])
        let flow = PluginGit.Flow()
        func run(_ calls: [[String]]) throws {
            for call in calls { let result = try repo.git(call); XCTAssertTrue(result.ok, "\(call): \(result.out)") }
        }
        func commit(_ name: String) throws {
            try name.write(to: repo.dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
            try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", name])
        }
        func state(_ kind: PluginGit.FlowKind, _ name: String) throws -> PluginGit.FlowFinishState {
            let branch = flow.prefix(kind) + name
            return .init(mergedIntoMain: try repo.git(PluginGit.isAncestorArguments(branch, of: flow.mainBranch)).ok,
                         tagged: try repo.git(PluginGit.tagExistsArguments(flow.tag(for: name))).ok,
                         mergedIntoDevelop: try repo.git(PluginGit.isAncestorArguments(branch, of: flow.developBranch)).ok)
        }
        try run(PluginGit.flowStartArguments(.feature, name: "login", flow: flow, hasDevelop: false))
        try commit("login.txt")
        try run(PluginGit.flowFinishArguments(.feature, name: "login", flow: flow, state: try state(.feature, "login")))
        XCTAssertFalse(try repo.git(["rev-parse", "-q", "--verify", "refs/heads/feature/login"]).ok, "deleted")
        XCTAssertTrue(try repo.git(["cat-file", "-e", "develop:login.txt"]).ok)

        try run(PluginGit.flowStartArguments(.release, name: "1.0", flow: flow, hasDevelop: true))
        try commit("version.txt")
        let before = try state(.release, "1.0")
        XCTAssertEqual(before, .init())
        try run(PluginGit.flowFinishArguments(.release, name: "1.0", flow: flow, state: before))
        XCTAssertTrue(try repo.git(["cat-file", "-e", "main:version.txt"]).ok)
        XCTAssertTrue(try repo.git(["cat-file", "-e", "main:login.txt"]).ok)
        XCTAssertTrue(try repo.git(["cat-file", "-e", "develop:version.txt"]).ok)
        XCTAssertTrue(try repo.git(PluginGit.tagExistsArguments("1.0")).ok)
        XCTAssertEqual(try repo.git(["rev-parse", "--abbrev-ref", "HEAD"], combined: false).out
            .trimmingCharacters(in: .whitespacesAndNewlines), "develop")
    }

    /// A real conflict: the three stages re-merged with the base, adopted into the working file, one
    /// hunk taken from each side, and the result free of markers.
    func testMergeEditorAgainstRealGit() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        let file = repo.dir.appendingPathComponent("f.txt")
        try "a\nbase1\nm\nbase2\nz\n".write(to: file, atomically: true, encoding: .utf8)
        try repo.git(["add", "-A"]); try repo.git(["commit", "-q", "-m", "base"])
        try repo.git(["switch", "-q", "-c", "other"])
        try "a\ntheirs1\nm\ntheirs2\nz\n".write(to: file, atomically: true, encoding: .utf8)
        try repo.git(["commit", "-q", "-am", "theirs"])
        try repo.git(["switch", "-q", "main"])
        try "a\nours1\nm\nours2\nz\n".write(to: file, atomically: true, encoding: .utf8)
        try repo.git(["commit", "-q", "-am", "ours"])
        XCTAssertFalse(try repo.git(["merge", "other"]).ok)

        let working = try String(contentsOf: file, encoding: .utf8)
        XCTAssertNil(PluginGit.parseConflicts(working)?.hunks.first?.base, "git's default style has no base")
        var paths: [String] = []
        for stage in 1...3 {
            let out = try repo.git(["show", PluginGit.mergeStageSpec(stage, path: "f.txt")], combined: false).out
            let url = repo.dir.appendingPathComponent(".stage\(stage)")
            try out.write(to: url, atomically: true, encoding: .utf8)
            paths.append(url.path)
        }
        let labels = ("HEAD", "base", "other")
        let diff3 = try repo.git(PluginGit.mergeFileArguments(ours: paths[1], base: paths[0], theirs: paths[2],
                                                              labels: labels), combined: false).out
        let merged = try repo.git(PluginGit.mergeFileArguments(ours: paths[1], base: paths[0], theirs: paths[2],
                                                               labels: labels, diff3: false), combined: false).out
        XCTAssertEqual(PluginGit.parseConflicts(working)?.hunks.count, 1, "git joined the two conflicts")
        let adopted = try XCTUnwrap(PluginGit.adoptBase(working: working, merged: merged, diff3: diff3))
        let parsed = try XCTUnwrap(PluginGit.parseConflicts(adopted))
        XCTAssertEqual(parsed.hunks.count, 2)
        XCTAssertEqual(parsed.hunks[0].base, ["base1"])
        XCTAssertEqual(parsed.hunks[1].ours, ["ours2"])

        let first = PluginGit.resolving(parsed, hunk: 0, with: try XCTUnwrap(PluginGit.lines(of: parsed.hunks[0], .theirs)))
        let rest = try XCTUnwrap(PluginGit.parseConflicts(first))
        XCTAssertEqual(rest.hunks.count, 1, "the other hunk stays as markers")
        XCTAssertEqual(PluginGit.markerLine(of: 0, in: first), 3)
        let done = PluginGit.resolving(rest, hunk: 0, with: try XCTUnwrap(PluginGit.lines(of: rest.hunks[0], .oursThenTheirs)))
        XCTAssertEqual(done, "a\ntheirs1\nm\nours2\ntheirs2\nz\n")

        // An edit inside the markers: no base is adopted rather than the wrong one.
        XCTAssertNil(PluginGit.adoptBase(working: working.replacingOccurrences(of: "ours1", with: "edited"),
                                         merged: merged, diff3: diff3))
        XCTAssertEqual(PluginGit.changedLines(["x", "keep"], base: ["keep"]), [0])
        XCTAssertEqual(PluginGit.changedLines(["x"], base: nil), [0])
        XCTAssertNil(PluginGit.lines(of: PluginGit.ConflictHunk(ours: [], base: nil, theirs: [], oursLabel: "", theirsLabel: "",
                                                                 baseLabel: nil, startLine: 1), .base))
    }

    func testSettingsKeepFlowAndHostKinds() {
        var settings = PluginGit.Settings()
        settings.flow.developBranch = "dev"
        settings.flow.tagPrefix = "v"
        settings.hostKinds = ["git.example.com": .gitlab, "ghe.corp": .github]
        let text = settings.serialized()
        XCTAssertEqual(PluginGit.Settings.parse(text), settings)
        XCTAssertTrue(text.contains("Host.ghe.corp=github\n"))
        XCTAssertEqual(PluginGit.Settings.parse("FlowDevelop=\n").flow.developBranch, "develop", "an empty name keeps the default")
    }

    // MARK: Hosting

    func testHostingProjectFromRemotes() throws {
        let gh = try XCTUnwrap(PluginGit.hostingProject(remoteName: "origin", url: "git@github.com:hkiam/PeachCommander.git"))
        XCTAssertEqual(gh.kind, .github)
        XCTAssertEqual(gh.path, "hkiam/PeachCommander")
        XCTAssertEqual(gh.apiBase, "https://api.github.com")
        XCTAssertEqual(gh.webBase, "https://github.com/hkiam/PeachCommander")
        let gl = try XCTUnwrap(PluginGit.hostingProject(remoteName: "up", url: "https://gitlab.com/group/sub/project.git"))
        XCTAssertEqual(gl.kind, .gitlab)
        XCTAssertEqual(gl.path, "group/sub/project")
        XCTAssertEqual(gl.apiBase, "https://gitlab.com/api/v4")
        XCTAssertEqual(PluginGit.hostingProject(remoteName: "o", url: "ssh://git@gitlab.corp.de:2222/a/b.git")?.apiBase,
                       "https://gitlab.corp.de/api/v4")
        XCTAssertNil(PluginGit.hostingProject(remoteName: "o", url: "git@git.corp.de:a/b.git"), "unknown without a setting")
        let ghe = try XCTUnwrap(PluginGit.hostingProject(remoteName: "o", url: "git@git.corp.de:a/b.git", kinds: ["git.corp.de": .github]))
        XCTAssertEqual(ghe.apiBase, "https://git.corp.de/api/v3")
        XCTAssertNil(PluginGit.hostingProject(remoteName: "o", url: "/Users/me/repo.git"))

        let remotes = [PluginGit.Remote(name: "fork", fetchURL: "git@github.com:me/x.git", pushURL: ""),
                       PluginGit.Remote(name: "origin", fetchURL: "git@github.com:them/x.git", pushURL: "")]
        XCTAssertEqual(PluginGit.hostingProject(remotes: remotes)?.path, "them/x", "origin first")
        XCTAssertEqual(PluginGit.tokenStore(host: "GitHub.com"), "git-token:github.com")
        XCTAssertEqual(PluginGit.parseHostKinds("Git.Corp.de=GitLab, ghe.corp = github; bad, x=bitbucket, a b=github"),
                       ["git.corp.de": .gitlab, "ghe.corp": .github])
        XCTAssertEqual(PluginGit.hostKindsText(["b": .github, "a": .gitlab]), "a=gitlab, b=github")
    }

    func testHostingRequests() throws {
        let gh = try XCTUnwrap(PluginGit.hostingProject(remoteName: "origin", url: "git@github.com:o/r.git"))
        let gl = try XCTUnwrap(PluginGit.hostingProject(remoteName: "origin", url: "git@gitlab.com:g/s/p.git"))
        XCTAssertEqual(PluginGit.pullRequestsRequest(gh).url, "https://api.github.com/repos/o/r/pulls?state=open&per_page=50")
        XCTAssertEqual(PluginGit.pullRequestsRequest(gl).url,
                       "https://gitlab.com/api/v4/projects/g%2Fs%2Fp/merge_requests?state=opened&per_page=50")
        XCTAssertEqual(PluginGit.ciRequests(gh, sha: "abc").map(\.url),
                       ["https://api.github.com/repos/o/r/commits/abc/check-runs?per_page=100",
                        "https://api.github.com/repos/o/r/commits/abc/status"])
        XCTAssertEqual(PluginGit.ciRequests(gl, sha: "abc").map(\.url),
                       ["https://gitlab.com/api/v4/projects/g%2Fs%2Fp/pipelines?sha=abc&per_page=1"])
        let create = PluginGit.createPullRequestRequest(gl, title: "T", body: "B", head: "f", base: "main", draft: true)
        XCTAssertEqual(create.method, "POST")
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(create.body)) as? [String: Any])
        XCTAssertEqual(payload["title"] as? String, "Draft: T")
        XCTAssertEqual(payload["source_branch"] as? String, "f")
        XCTAssertEqual(PluginGit.apiHeaders(.gitlab, token: "t")["PRIVATE-TOKEN"], "t")
        XCTAssertEqual(PluginGit.apiHeaders(.github, token: "t")["Authorization"], "Bearer t")
        XCTAssertEqual(PluginGit.fetchPullRequestArguments(gh, number: 7).arguments, ["fetch", "origin", "+pull/7/head:pr/7"])
        XCTAssertEqual(PluginGit.fetchPullRequestArguments(gl, number: 7).branch, "mr/7")
    }

    func testHostingAnswers() throws {
        let githubPulls = """
        [{"number": 12, "title": "Add login", "user": {"login": "ada"}, "draft": true,
          "head": {"ref": "feature/login", "sha": "abc"}, "base": {"ref": "main"},
          "html_url": "https://github.com/o/r/pull/12", "updated_at": "2026-10-01T12:00:00Z", "body": "Text"}]
        """
        let pull = try XCTUnwrap(PluginGit.parsePullRequests(Data(githubPulls.utf8), kind: .github)?.first)
        XCTAssertEqual(pull.number, 12); XCTAssertEqual(pull.author, "ada"); XCTAssertTrue(pull.isDraft)
        XCTAssertEqual(pull.sourceBranch, "feature/login"); XCTAssertEqual(pull.headSHA, "abc"); XCTAssertNotNil(pull.updated)
        let gitlabMRs = """
        [{"iid": 3, "title": "Draft: Fix", "author": {"username": "bob"}, "source_branch": "fix", "target_branch": "main",
          "web_url": "https://gitlab.com/g/p/-/merge_requests/3", "draft": true, "sha": "def",
          "updated_at": "2026-10-01T12:00:00.123Z", "description": "D"}]
        """
        let mr = try XCTUnwrap(PluginGit.parsePullRequests(Data(gitlabMRs.utf8), kind: .gitlab)?.first)
        XCTAssertEqual(mr.number, 3); XCTAssertEqual(mr.body, "D"); XCTAssertNotNil(mr.updated, "fractional seconds")
        XCTAssertNil(PluginGit.parsePullRequests(Data("{\"message\":\"Bad credentials\"}".utf8), kind: .github))

        let issues = """
        [{"number": 1, "title": "Bug", "user": {"login": "a"}, "labels": [{"name": "bug"}], "html_url": "u"},
         {"number": 2, "title": "PR", "user": {"login": "a"}, "pull_request": {}, "html_url": "u"}]
        """
        XCTAssertEqual(PluginGit.parseIssues(Data(issues.utf8), kind: .github)?.map(\.number), [1], "pull requests are not issues")
        XCTAssertEqual(PluginGit.parseIssues(Data(issues.utf8), kind: .github)?.first?.labels, ["bug"])

        let runs = """
        {"check_runs": [{"name": "build", "status": "completed", "conclusion": "success", "html_url": "b"},
                        {"name": "test", "status": "in_progress", "conclusion": null}]}
        """
        let statuses = #"{"statuses": [{"context": "ci/legacy", "state": "success", "target_url": "l"}]}"#
        let ci = PluginGit.parseGitHubCI(checkRuns: Data(runs.utf8), status: Data(statuses.utf8))
        XCTAssertEqual(ci.state, .pending)
        XCTAssertEqual(ci.checks.map(\.name), ["build", "test", "ci/legacy"])
        let failed = PluginGit.parseGitHubCI(checkRuns: Data(#"{"check_runs":[{"name":"x","status":"completed","conclusion":"failure"}]}"#.utf8),
                                            status: nil)
        XCTAssertEqual(failed.state, .failure)
        XCTAssertEqual(PluginGit.parseGitHubCI(checkRuns: nil, status: nil), .none)
        XCTAssertEqual(PluginGit.parseGitLabCI(Data(#"[{"id": 9, "status": "running", "web_url": "w"}]"#.utf8)).state, .pending)
        XCTAssertEqual(PluginGit.parseGitLabCI(Data("[]".utf8)), .none)

        XCTAssertEqual(PluginGit.apiErrorMessage(Data(#"{"message":"Validation Failed","errors":[{"message":"A pull request already exists"}]}"#.utf8), status: 422),
                       "Validation Failed: A pull request already exists")
        XCTAssertEqual(PluginGit.apiErrorMessage(Data("<html>".utf8), status: 502), "HTTP 502")
        XCTAssertEqual(PluginGit.rateLimitRemaining(["X-RateLimit-Remaining": "42"]), 42)
        XCTAssertEqual(PluginGit.rateLimitRemaining(["RateLimit-Remaining": "7"]), 7)
        XCTAssertEqual(PluginGit.parseCreated(Data(#"{"iid": 5, "web_url": "w"}"#.utf8), kind: .gitlab)?.number, 5)
        XCTAssertEqual(PluginGit.parseDefaultBranch(Data(#"{"default_branch": "trunk"}"#.utf8)), "trunk")

        let one = PluginGit.pullRequestDraft(subjects: ["Add login"], firstMessage: "Add login\n\nWith a form.\n")
        XCTAssertEqual(one.title, "Add login"); XCTAssertEqual(one.body, "With a form.")
        let several = PluginGit.pullRequestDraft(subjects: ["third", "second", "first"], firstMessage: nil)
        XCTAssertEqual(several.title, "first"); XCTAssertEqual(several.body, "- first\n- second\n- third")
    }

    /// The client sends the service's headers and refuses to send the token anywhere but the API host.
    func testHostingClientSendsTheTokenOnlyToItsHost() throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HostingStub.self]
        let session = URLSession(configuration: configuration)
        let project = try XCTUnwrap(PluginGit.hostingProject(remoteName: "origin", url: "git@github.com:o/r.git"))
        let client = PluginGitHostingClient(project: project, token: "secret", session: session)

        let answered = expectation(description: "answered")
        client.send(PluginGit.pullRequestsRequest(project)) { response, error in
            XCTAssertNil(error)
            XCTAssertEqual(response?.status, 200)
            XCTAssertEqual(response?.headers["X-RateLimit-Remaining"], "99")
            answered.fulfill()
        }
        wait(for: [answered], timeout: 5)
        XCTAssertEqual(HostingStub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(HostingStub.lastRequest?.url?.host, "api.github.com")

        let refused = expectation(description: "refused")
        HostingStub.lastRequest = nil
        client.send(PluginGit.APIRequest(method: "GET", url: "https://evil.example.com/x", body: nil)) { response, error in
            XCTAssertNil(response)
            XCTAssertNotNil(error)
            refused.fulfill()
        }
        wait(for: [refused], timeout: 5)
        XCTAssertNil(HostingStub.lastRequest, "never sent")
    }
}

extension PluginGitTests {
    /// The review's findings on phase 9, each pinned.
    func testPhase9ReviewFindings() throws {
        // The commit HEAD is on comes with the status; an unborn branch has none.
        let status = PluginGit.parseStatus("# branch.oid 1a2b3c\0# branch.head main\0")
        XCTAssertEqual(status.oid, "1a2b3c")
        XCTAssertNil(PluginGit.parseStatus("# branch.oid (initial)\0# branch.head main\0").oid)

        // An HTTPS port is the API's port too; an SSH port is not.
        let onPort = try XCTUnwrap(PluginGit.hostingProject(remoteName: "o", url: "https://gitlab.corp:8443/g/app.git",
                                                            kinds: ["gitlab.corp": .gitlab]))
        XCTAssertEqual(onPort.apiBase, "https://gitlab.corp:8443/api/v4")
        XCTAssertEqual(PluginGit.hostingProject(remoteName: "o", url: "ssh://git@gitlab.corp:2222/g/app.git",
                                                kinds: ["gitlab.corp": .gitlab])?.apiBase, "https://gitlab.corp/api/v4")

        // A branch that tracks main has not been pushed as itself; one with commits ahead has to push them.
        XCTAssertEqual(PluginGit.pushBeforePullRequest(branch: "fix-x", upstream: "origin/main", ahead: 0, remote: "origin"),
                       ["push", "--set-upstream", "origin", "HEAD"])
        XCTAssertEqual(PluginGit.pushBeforePullRequest(branch: "fix-x", upstream: "origin/fix-x", ahead: 3, remote: "origin"),
                       ["push", "origin", "HEAD"])
        XCTAssertNil(PluginGit.pushBeforePullRequest(branch: "fix-x", upstream: "origin/fix-x", ahead: 0, remote: "origin"))
        XCTAssertEqual(PluginGit.pushBeforePullRequest(branch: "fix-x", upstream: nil, ahead: 0, remote: "origin"),
                       ["push", "--set-upstream", "origin", "HEAD"])

        // A checked-out pull request is updated through FETCH_HEAD.
        let gh = try XCTUnwrap(PluginGit.hostingProject(remoteName: "origin", url: "git@github.com:o/r.git"))
        XCTAssertEqual(PluginGit.updatePullRequestArguments(gh, number: 7),
                       [["fetch", "origin", "pull/7/head"], ["merge", "--ff-only", "FETCH_HEAD"]])

        // develop only on the remote: followed, not made anew from main.
        XCTAssertEqual(PluginGit.flowStartArguments(.feature, name: "x", flow: PluginGit.Flow(), hasDevelop: false,
                                                    remoteDevelop: "origin/develop"),
                       [["branch", "--track", "develop", "origin/develop"], ["switch", "-c", "feature/x", "develop"]])
        XCTAssertEqual(PluginGit.preferredRemoteBranch("fork/develop\norigin/develop\n"), "origin/develop")
        XCTAssertNil(PluginGit.preferredRemoteBranch(""))
    }

    func testFlowFollowsARemoteDevelopAndSavedVersionsGoThroughFiltersAgainstRealGit() throws {
        let remote = try TempRepo(), repo = try TempRepo()
        try remote.git(["init", "-q", "-b", "main"])
        try remote.git(["commit", "-q", "--allow-empty", "-m", "base"])
        try remote.git(["switch", "-q", "-c", "develop"])
        try "d".write(to: remote.dir.appendingPathComponent("dev.txt"), atomically: true, encoding: .utf8)
        try remote.git(["add", "-A"]); try remote.git(["commit", "-q", "-m", "dev"])
        try remote.git(["switch", "-q", "main"])
        try repo.git(["clone", "-q", remote.dir.path, "."])
        let found = PluginGit.preferredRemoteBranch(try repo.git(PluginGit.remoteBranchesArguments(named: "develop"), combined: false).out)
        XCTAssertEqual(found, "origin/develop")
        for call in PluginGit.flowStartArguments(.feature, name: "x", flow: PluginGit.Flow(), hasDevelop: false, remoteDevelop: found) {
            XCTAssertTrue(try repo.git(call).ok, "\(call)")
        }
        XCTAssertTrue(try repo.git(["cat-file", "-e", "HEAD:dev.txt"]).ok, "the feature starts from the remote's develop")
        XCTAssertEqual(try repo.git(["rev-parse", "--abbrev-ref", "develop@{upstream}"], combined: false).out
            .trimmingCharacters(in: .whitespacesAndNewlines), "origin/develop")

        // cat-file --filters applies the checkout's line endings, as a restore would.
        try repo.git(["config", "core.autocrlf", "true"])
        let saved = try repo.git(PluginGit.checkoutContentArguments(commit: "HEAD", path: "dev.txt"), combined: false)
        XCTAssertTrue(saved.ok)
        XCTAssertEqual(saved.out, "d")
    }

    /// Host and port both decide where the token may go.
    func testHostingClientRefusesAnotherPort() throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HostingStub.self]
        let project = try XCTUnwrap(PluginGit.hostingProject(remoteName: "o", url: "https://gitlab.corp:8443/g/app.git",
                                                             kinds: ["gitlab.corp": .gitlab]))
        let client = PluginGitHostingClient(project: project, token: "t", session: URLSession(configuration: configuration))
        HostingStub.lastRequest = nil
        let refused = expectation(description: "refused")
        client.send(PluginGit.APIRequest(method: "GET", url: "https://gitlab.corp/api/v4/projects", body: nil)) { response, error in
            XCTAssertNil(response); XCTAssertNotNil(error); refused.fulfill()
        }
        wait(for: [refused], timeout: 5)
        XCTAssertNil(HostingStub.lastRequest)
        let sent = expectation(description: "sent")
        client.send(PluginGit.pullRequestsRequest(project)) { response, _ in
            XCTAssertEqual(response?.status, 200); sent.fulfill()
        }
        wait(for: [sent], timeout: 5)
        XCTAssertEqual(HostingStub.lastRequest?.url?.port, 8443)
    }
}

/// Answers every request with an empty list and remembers it.
private final class HostingStub: URLProtocol {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["X-RateLimit-Remaining": "99", "Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("[]".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

// MARK: - Commit messages changed after the fact (phase 10)

extension PluginGitTests {

    private func commitFile(_ repo: TempRepo, _ name: String, _ text: String, message: String,
                            date: String) throws {
        try text.write(to: repo.dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        try repo.git(["add", name])
        try repo.git(["commit", "-q", "-m", message],
                     environment: ["GIT_AUTHOR_DATE": date, "GIT_COMMITTER_DATE": date], author: "Ann")
    }

    private func head(_ repo: TempRepo, _ ref: String = "HEAD") throws -> String {
        try repo.git(["rev-parse", ref], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testACommitObjectIsReadAndWrittenBackByteForByte() {
        let raw = "tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904\nparent aaaa\nparent bbbb\n"
            + "author Jörg <j@x> 1700000000 +0200\ncommitter C <c@x> 1700000001 -0500\n"
            + "gpgsig -----BEGIN PGP SIGNATURE-----\n \n abc\n -----END PGP SIGNATURE-----\n"
            + "\nSubject\n\nBody\n"
        let data = Data(raw.utf8)
        let commit = PluginGit.parseCommitObject(data)!
        XCTAssertEqual(commit.serialized(), data)
        XCTAssertEqual(commit.parents, ["aaaa", "bbbb"])
        XCTAssertTrue(commit.isSigned)
        XCTAssertEqual(commit.messageText, "Subject\n\nBody\n")

        let rewritten = PluginGit.rewrittenCommit(commit, parents: ["cccc", "bbbb"], message: Data("New\n".utf8))
        let text = String(data: rewritten.serialized(), encoding: .utf8)!
        XCTAssertEqual(text, "tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904\nparent cccc\nparent bbbb\n"
            + "author Jörg <j@x> 1700000000 +0200\ncommitter C <c@x> 1700000001 -0500\n\nNew\n")
        XCTAssertFalse(rewritten.isSigned)

        let env = PluginGit.identityEnvironment(commit)!
        XCTAssertEqual(env["GIT_AUTHOR_NAME"], "Jörg")
        XCTAssertEqual(env["GIT_AUTHOR_DATE"], "@1700000000 +0200")
        XCTAssertEqual(env["GIT_COMMITTER_DATE"], "@1700000001 -0500")
    }

    func testARootCommitGetsNoParentAndAnotherEncodingIsNotEditable() {
        let root = PluginGit.parseCommitObject(Data("tree t\nauthor A <a> 1 +0000\ncommitter A <a> 1 +0000\n\nm\n".utf8))!
        XCTAssertEqual(PluginGit.rewrittenCommit(root, parents: [], message: nil), root)
        let latin = PluginGit.parseCommitObject(Data("tree t\nauthor A <a> 1 +0000\ncommitter A <a> 1 +0000\nencoding ISO-8859-1\n\nm\n".utf8))!
        XCTAssertFalse(latin.isUTF8)
        XCTAssertNil(latin.messageText)
        XCTAssertFalse(PluginGit.canSignAnew(latin))
    }

    func testTheHashComputedHereIsGitsAndTheBatchIsRead() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q"])
        try commitFile(repo, "a", "1", message: "first", date: "1700000000 +0100")
        let hash = try head(repo)
        let batch = PluginGit.parseCatFileBatch(try repo.gitData(["cat-file", "--batch"], combined: false,
                                                                 input: Data("\(hash)\nnope\n".utf8)).out)
        XCTAssertEqual(batch.count, 1)
        let object = try XCTUnwrap(batch[hash])
        XCTAssertEqual(object.type, "commit")
        XCTAssertEqual(PluginGit.objectHash(type: "commit", content: object.content), hash)
    }

    func testFindAndReplaceInMessages() {
        var replacement = PluginGit.MessageReplacement(find: "Token $1", replacement: "$1")
        XCTAssertEqual(replacement.apply(to: "a token $1 b"), "a $1 b", "literal both ways, case ignored")
        replacement.caseSensitive = true
        XCTAssertEqual(replacement.matches(in: "a token $1 b"), [])
        let regex = PluginGit.MessageReplacement(find: #"key=(\w+)"#, replacement: "key=<$1>", regex: true)
        XCTAssertEqual(regex.apply(to: "key=abc and KEY=d"), "key=<abc> and key=<d>")
        let word = PluginGit.MessageReplacement(find: "pass", replacement: "x", wholeWord: true)
        XCTAssertEqual(word.apply(to: "pass password pass."), "x password x.")
        XCTAssertNil(PluginGit.MessageReplacement(find: "(", replacement: "", regex: true).expression)
        XCTAssertNil(PluginGit.MessageReplacement(find: "", replacement: "").expression)
    }

    func testSecretsAreFoundAndRedacted() {
        let token = "ghp_" + String(repeating: "a1B2", count: 9)
        let message = """
            Deploy with \(token)
            password: hunter22secret
            remote https://bob:s3cr3tpw@example.com/x.git
            -----BEGIN OPENSSH PRIVATE KEY-----
            b3BlbnNzaC1rZXk
            -----END OPENSSH PRIVATE KEY-----
            password = ***REDACTED***
            """
        let findings = PluginGit.secretFindings(in: message)
        XCTAssertEqual(findings.map(\.kind), ["GitHub token", "Private key", "Password in a URL", "Password or key"])
        XCTAssertEqual(findings[0].value, token)
        XCTAssertEqual(findings[2].value, "s3cr3tpw")
        XCTAssertEqual(findings[3].value, "hunter22secret")
        let redacted = PluginGit.redaction(of: findings.map(\.value)).apply(to: message)
        XCTAssertTrue(PluginGit.secretFindings(in: redacted).isEmpty, redacted)
        XCTAssertTrue(redacted.contains("Deploy with ***REDACTED***"))
        XCTAssertTrue(redacted.contains("https://bob:***REDACTED***@example.com"))
        XCTAssertEqual(PluginGit.maskedSecret("hunter22secret"), "hunt…et (14)")
        XCTAssertEqual(PluginGit.maskedSecret("abc"), "••••")
    }

    func testATypedMessageIsStoredTheWayGitStoresOne() {
        XCTAssertEqual(PluginGit.normalizedMessage("\n Subject  \r\n\nBody\t\n\n\n"), " Subject\n\nBody\n")
        XCTAssertEqual(PluginGit.normalizedMessage(" \n\n"), "")
    }

    func testBackupStampsSortAndParse() {
        let stamp = PluginGit.backupStamp(Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(stamp, "messages-20231114-221320")
        XCTAssertEqual(PluginGit.backupDate(stamp), Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(PluginGit.backupStamps("refs/pc-backup/messages-1/old/heads/a\nrefs/pc-backup/messages-2/new/heads/a\n"),
                       ["messages-2", "messages-1"])
    }

    /// The whole thing against git: a history with a merge, a branch and both kinds of tag; two messages
    /// changed in one run. Trees, authors, committers and dates stay; the working tree is not touched; the
    /// refs move; undo puts them back; and the clean-up leaves the old commit nowhere.
    func testMessagesAreRewrittenAcrossAMergeAndUndoneAndCleanedUp() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        try commitFile(repo, "a", "1", message: "A", date: "1700000000 +0100")
        try commitFile(repo, "b", "2", message: "B with ghp_secret", date: "1700000100 +0100")
        let b = try head(repo)
        try repo.git(["tag", "-a", "v1", "-m", "release one"])
        try repo.git(["checkout", "-q", "-b", "side"])
        try commitFile(repo, "s", "3", message: "S", date: "1700000200 -0700")
        try repo.git(["checkout", "-q", "main"])
        try commitFile(repo, "c", "4", message: "C", date: "1700000300 +0100")
        try repo.git(["merge", "-q", "--no-ff", "side", "-m", "Merge side"],
                     environment: ["GIT_AUTHOR_DATE": "1700000400 +0100", "GIT_COMMITTER_DATE": "1700000400 +0100"])
        try commitFile(repo, "d", "5", message: "D\n\nwith body", date: "1700000500 +0100")
        let d = try head(repo)
        try repo.git(["tag", "light"])
        try "dirty".write(to: repo.dir.appendingPathComponent("a"), atomically: true, encoding: .utf8)
        try repo.git(["stash", "-q"])
        try "dirty again".write(to: repo.dir.appendingPathComponent("a"), atomically: true, encoding: .utf8)

        let identity = ["log", "--format=%T %an %ae %ad %cn %ce %cd", "--date=raw", "main"]
        let before = try repo.git(identity, combined: false).out
        let oldMain = try head(repo, "main"), oldSide = try head(repo, "side")

        let refs = PluginGit.parseContainingRefs(
            try repo.git(PluginGit.containingRefsArguments([b, d]), combined: false).out, currentBranch: "refs/heads/main")
        XCTAssertEqual(Set(refs.map(\.name)), ["refs/heads/main", "refs/heads/side", "refs/tags/v1", "refs/tags/light", "refs/stash"])

        let result = PluginGit.rewriteMessages([b: "B\n", d: "D\n\nwith a better body\n"],
                                               refs: ["refs/heads/main", "refs/heads/side", "refs/tags/v1", "refs/tags/light"],
                                               sign: false, stamp: "messages-1", git: repo.call)
        if case .failure(let error) = result { XCTFail("\(error)") }
        let report = try result.get()
        XCTAssertEqual(report.mapping.count, 5, "B, C, S, the merge and D")
        XCTAssertEqual(Set(report.moved.map(\.ref)), ["refs/heads/main", "refs/heads/side", "refs/tags/v1", "refs/tags/light"])

        XCTAssertEqual(try repo.git(identity, combined: false).out, before, "trees, people and dates are what they were")
        XCTAssertEqual(try repo.git(["rev-list", "--parents", "-1", "main~1"], combined: false).out.split(separator: " ").count, 3,
                       "the merge is still a merge")
        XCTAssertEqual(try repo.git(["log", "--format=%s", "main"], combined: false).out, "D\nMerge side\nC\nS\nB\nA\n")
        XCTAssertEqual(try repo.git(["log", "-1", "--format=%B", "main"], combined: false).out, "D\n\nwith a better body\n\n")
        XCTAssertEqual(try repo.git(["rev-parse", "v1^{commit}"], combined: false).out, try repo.git(["rev-parse", "main~3"], combined: false).out)
        XCTAssertEqual(try repo.git(["cat-file", "-p", "v1"], combined: false).out.components(separatedBy: "\n").last(where: { !$0.isEmpty }), "release one")
        XCTAssertEqual(try head(repo, "light"), try head(repo, "main"))
        XCTAssertEqual(try repo.git(["status", "--porcelain"], combined: false).out, " M a\n", "the working tree is as it was")
        XCTAssertTrue(try repo.git(["fsck", "--strict", "--no-dangling"]).ok)
        XCTAssertEqual(PluginGit.backupStamps(try repo.git(["for-each-ref", "--format=%(refname)"], combined: false).out), ["messages-1"])

        // Undo, then redo, then remove the old commits for good.
        XCTAssertEqual(PluginGit.undoRewrite(stamp: "messages-1", git: repo.call),
                       .undone(["refs/heads/main", "refs/heads/side", "refs/tags/light", "refs/tags/v1"]))
        XCTAssertEqual(try head(repo, "main"), oldMain)
        XCTAssertEqual(try head(repo, "side"), oldSide)
        XCTAssertEqual(PluginGit.undoRewrite(stamp: "messages-1", git: repo.call), .noBackup)

        let again = try PluginGit.rewriteMessages([b: "B\n"], refs: ["refs/heads/main", "refs/heads/side", "refs/tags/v1"],
                                                  sign: false, stamp: "messages-2", git: repo.call).get()
        let cleaning = PluginGit.cleanUpRewrite(stamp: again.stamp, old: [b], git: repo.call)
        if case .failure(let error) = cleaning { XCTFail("\(error)") }
        let clean = try cleaning.get()
        // The stash was made on D, which still holds the old B — so it stays, and says why.
        XCTAssertEqual(clean.removed, [])
        XCTAssertTrue(clean.remaining[b]?.contains("refs/tags/light") == true, "\(clean.remaining)")
        XCTAssertEqual(try repo.git(["stash", "list"], combined: false).out.components(separatedBy: "\n").filter { !$0.isEmpty }.count, 1,
                       "the stash list survives the clean-up")
        try repo.git(["tag", "-d", "light"])
        try repo.git(["stash", "drop", "-q"])
        let gone = try PluginGit.cleanUpRewrite(stamp: nil, old: [b], git: repo.call).get()
        XCTAssertEqual(gone.removed, [b])
        XCTAssertFalse(try repo.git(["cat-file", "-e", b]).ok)
    }

    /// Edited commits one behind the other: the second's parent is a descendant of the first, so bounding
    /// the walk by parents would hide the first — the walk widens instead.
    func testTwoEditsOnOneLineAndUndoRefusedAfterNewWork() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        try commitFile(repo, "a", "1", message: "one", date: "1700000000 +0000")
        let one = try head(repo)
        try commitFile(repo, "a", "2", message: "two", date: "1700000001 +0000")
        try commitFile(repo, "a", "3", message: "three", date: "1700000002 +0000")
        let three = try head(repo)
        let report = try PluginGit.rewriteMessages([one: "ONE\n", three: "THREE\n"], refs: ["refs/heads/main"],
                                                   sign: false, stamp: "messages-3", git: repo.call).get()
        XCTAssertEqual(report.mapping.count, 3)
        XCTAssertEqual(try repo.git(["log", "--format=%s"], combined: false).out, "THREE\ntwo\nONE\n")
        try commitFile(repo, "a", "4", message: "four", date: "1700000003 +0000")
        XCTAssertEqual(PluginGit.undoRewrite(stamp: "messages-3", git: repo.call), .moved(["refs/heads/main"]))
        XCTAssertEqual(PluginGit.rewriteMessages([one: "x\n"], refs: ["refs/heads/nope"], sign: false, stamp: "m",
                                                 git: repo.call), .failure(.notReachable))
    }

    func testTheMessagesListingAndWhatWasPushed() throws {
        let remote = try TempRepo(), repo = try TempRepo()
        try remote.git(["init", "-q", "--bare", "-b", "main"])
        try repo.git(["init", "-q", "-b", "main"])
        try commitFile(repo, "a", "1", message: "pushed\n\nbody\u{1F}odd", date: "1700000000 +0000")
        let pushed = try head(repo)
        try repo.git(["remote", "add", "origin", remote.dir.path])
        try repo.git(["push", "-q", "-u", "origin", "main"])
        try commitFile(repo, "a", "2", message: "local", date: "1700000001 +0000")

        let all = PluginGit.parseMessages(try repo.git(PluginGit.messagesArguments(.currentBranch), combined: false).out)
        XCTAssertEqual(all.map(\.subject), ["local", "pushed"])
        XCTAssertEqual(all[1].message, "pushed\n\nbody\u{1F}odd\n")
        XCTAssertEqual(all[1].author, "Ann")
        XCTAssertEqual(PluginGit.parseMessages(try repo.git(PluginGit.messagesArguments(.notPushed), combined: false).out).map(\.subject), ["local"])
        XCTAssertEqual(PluginGit.parseMessages(try repo.git(PluginGit.messagesArguments(.commits([pushed])), combined: false).out).map(\.hash), [pushed])

        let refs = PluginGit.parseContainingRefs(try repo.git(PluginGit.containingRefsArguments([pushed]), combined: false).out,
                                                 currentBranch: "refs/heads/main")
        let main = try XCTUnwrap(PluginGit.pushedBranches(refs).first)
        XCTAssertTrue(main.isCurrent)
        XCTAssertEqual(PluginGit.forcePushArguments(for: main),
                       ["push", "--force-with-lease", "--force-if-includes", "origin", "refs/heads/main:refs/heads/main"])

        _ = try PluginGit.rewriteMessages([pushed: "PUSHED\n"], refs: ["refs/heads/main"], sign: false, stamp: "messages-4", git: repo.call).get()
        let push = try repo.git(PluginGit.forcePushArguments(for: main)!)
        XCTAssertTrue(push.ok, push.out)
        XCTAssertEqual(try remote.git(["log", "--format=%s", "main"], combined: false).out, "local\nPUSHED\n")
    }
}

extension PluginGitTests {

    /// Review of phase 10: a commit that cannot be signed again (it carries an encoding header) between
    /// signable ones. It is written unsigned at once, so its child's `commit-tree -p` finds it; the others
    /// are signed, and each signed one is, signature aside, exactly the commit meant.
    func testSigningAgainSurvivesACommitThatCannotBeSigned() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        let key = repo.dir.appendingPathComponent("key").path
        let made = Process()
        made.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        made.arguments = ["-q", "-t", "ed25519", "-N", "", "-f", key]
        try made.run(); made.waitUntilExit()
        guard made.terminationStatus == 0 else { throw XCTSkip("ssh-keygen could not make a key") }
        try repo.git(["config", "gpg.format", "ssh"])
        try repo.git(["config", "user.signingkey", key])
        try commitFile(repo, "a", "1", message: "one", date: "1700000000 +0000")
        let one = try head(repo)
        try repo.git(["-c", "i18n.commitEncoding=ISO-8859-1", "commit", "-q", "--allow-empty", "-m", "latin"],
                     environment: ["GIT_AUTHOR_DATE": "1700000001 +0000", "GIT_COMMITTER_DATE": "1700000001 +0000"])
        try commitFile(repo, "a", "3", message: "three", date: "1700000002 +0000")

        let report = try PluginGit.rewriteMessages([one: "ONE\n"], refs: ["refs/heads/main"], sign: true,
                                                   stamp: "messages-s", git: repo.call).get()
        XCTAssertEqual(report.mapping.count, 3)
        XCTAssertEqual(report.notSigned, 1, "the commit with an encoding header")
        let signedHeads = try repo.git(["log", "--format=%H"], combined: false).out.split(separator: "\n").map { hash in
            try repo.git(["cat-file", "commit", String(hash)], combined: false).out.contains("\ngpgsig ")
        }
        XCTAssertEqual(signedHeads, [true, false, true])
        XCTAssertEqual(try repo.git(["log", "--format=%s %an %ad", "--date=raw"], combined: false).out,
                       "three Ann 1700000002 +0000\nlatin T 1700000001 +0000\nONE Ann 1700000000 +0000\n")
        XCTAssertTrue(try repo.git(["fsck", "--strict", "--no-dangling"]).ok)
    }

    func testAMessageThatIsNotUTF8IsNotRewrittenAndAMessageGetsItsBlankLine() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        try commitFile(repo, "a", "1", message: "one", date: "1700000000 +0000")
        let tree = try repo.git(["rev-parse", "HEAD^{tree}"], combined: false).out.trimmingCharacters(in: .whitespacesAndNewlines)
        var raw = Data("tree \(tree)\nauthor A <a@x> 1700000001 +0000\ncommitter A <a@x> 1700000001 +0000\n\nM".utf8)
        raw.append(contentsOf: [0xFC, 0x6C, 0x6C, 0x0A])          // "Müll" in Latin-1, no encoding header
        let bad = try repo.gitData(["hash-object", "-t", "commit", "-w", "--stdin", "--literally"], combined: false, input: raw)
        let hash = String(decoding: bad.out, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        try repo.git(["update-ref", "refs/heads/odd", hash])
        XCTAssertEqual(PluginGit.rewriteMessages([hash: "x\n"], refs: ["refs/heads/odd"], sign: false, stamp: "m", git: repo.call),
                       .failure(.notUTF8([hash])))

        let headless = PluginGit.CommitObject(headers: ["tree t"], message: Data(), hasSeparator: false)
        XCTAssertEqual(String(data: PluginGit.rewrittenCommit(headless, parents: [], message: Data("m\n".utf8)).serialized(), encoding: .utf8),
                       "tree t\n\nm\n")
    }

    /// Without any reflog (`core.logAllRefUpdates=false`) the clean-up still runs — naming HEAD to
    /// `reflog expire` would fail — and the backup is kept until the reflogs are done.
    func testTheCleanUpRunsWithoutReflogs() throws {
        let repo = try TempRepo()
        try repo.git(["init", "-q", "-b", "main"])
        try repo.git(["config", "core.logAllRefUpdates", "false"])
        try commitFile(repo, "a", "1", message: "one ghp_x", date: "1700000000 +0000")
        let one = try head(repo)
        try commitFile(repo, "a", "2", message: "two", date: "1700000001 +0000")
        try? FileManager.default.removeItem(at: repo.dir.appendingPathComponent(".git/logs"))
        XCTAssertFalse(try repo.git(["reflog", "exists", "HEAD"]).ok)
        let report = try PluginGit.rewriteMessages([one: "one\n"], refs: ["refs/heads/main"], sign: false,
                                                   stamp: "messages-n", git: repo.call).get()
        let clean = try PluginGit.cleanUpRewrite(stamp: report.stamp, old: [one], git: repo.call).get()
        XCTAssertEqual(clean.removed, [one])
        XCTAssertEqual(PluginGit.backupStamps(try repo.git(["for-each-ref", "--format=%(refname)"], combined: false).out), [])
    }
}

private final class TempRepo {
    let dir: URL
    private let executable: String

    init() throws {
        let found = PluginGit.resolveExecutable(
            setting: nil,
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) },
            exists: { FileManager.default.fileExists(atPath: $0) })
        executable = try XCTUnwrap(found, "no git on this machine")
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pcgit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: dir) }

    /// `combined` puts git's stderr into the output, which is what the tests asserting git's own messages
    /// want; the parsers' tests read stdout alone.
    @discardableResult
    func git(_ arguments: [String], environment extra: [String: String] = [:], author: String = "T",
             combined: Bool = true, input: Data? = nil) throws -> (out: String, ok: Bool) {
        let result = try gitData(arguments, environment: extra, author: author, combined: combined, input: input)
        return (String(decoding: result.out, as: UTF8.self), result.ok)
    }

    /// The same, with git's output as bytes — `cat-file --batch` hands back objects, not text.
    func gitData(_ arguments: [String], environment extra: [String: String] = [:], author: String = "T",
                 combined: Bool = true, input: Data? = nil) throws -> (out: Data, ok: Bool) {
        let process = Process()
        if let input {
            let stdin = Pipe()
            process.standardInput = stdin
            try stdin.fileHandleForWriting.write(contentsOf: input)
            try stdin.fileHandleForWriting.close()
        }
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-C", dir.path] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        // Without `combined`, git's complaint still comes back when it fails — after its output.
        let errors = Pipe()
        process.standardError = combined ? pipe : errors
        var environment = ProcessInfo.processInfo.environment
        for key in ["LANG", "LC_ALL", "LC_CTYPE", "LC_MESSAGES"] { environment[key] = nil }
        environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
        environment["GIT_CONFIG_NOSYSTEM"] = "1"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_AUTHOR_NAME"] = author
        environment["GIT_AUTHOR_EMAIL"] = author == "T" ? "t@example.com" : "\(author.lowercased())@example.com"
        environment["GIT_COMMITTER_NAME"] = "T"; environment["GIT_COMMITTER_EMAIL"] = "t@example.com"
        environment.merge(extra) { _, new in new }
        process.environment = environment
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let complaint = combined ? Data() : errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let ok = process.terminationStatus == 0
        return (ok ? data : data + complaint, ok)
    }

    /// The rewrite's way to git, without stderr: git's warnings must not end up in an object name.
    var call: PluginGit.GitCall {
        { arguments, input, environment in
            (try? self.gitData(arguments, environment: environment, combined: false, input: input)) ?? (Data(), false)
        }
    }
}
