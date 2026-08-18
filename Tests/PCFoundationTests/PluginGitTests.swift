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
        let git = PluginGit.resolveExecutable(setting: nil,
                                              isExecutable: { FileManager.default.isExecutableFile(atPath: $0) },
                                              exists: { FileManager.default.fileExists(atPath: $0) })
        let executable = try XCTUnwrap(git, "no git on this machine")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pcgit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        func run(_ arguments: [String]) throws {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["-C", dir.path] + arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            var environment = ProcessInfo.processInfo.environment
            environment["GIT_CONFIG_GLOBAL"] = "/dev/null"     // the machine's config must not decide
            environment["GIT_CONFIG_NOSYSTEM"] = "1"
            environment["GIT_AUTHOR_NAME"] = "T"; environment["GIT_AUTHOR_EMAIL"] = "t@example.com"
            environment["GIT_COMMITTER_NAME"] = "T"; environment["GIT_COMMITTER_EMAIL"] = "t@example.com"
            process.environment = environment
            try process.run(); process.waitUntilExit()
        }
        func status() throws -> String {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["-C", dir.path] + PluginGit.statusArguments
            let pipe = Pipe(); process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(decoding: data, as: UTF8.self)
        }

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
        let found = PluginGit.resolveExecutable(
            setting: nil,
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) },
            exists: { FileManager.default.fileExists(atPath: $0) })
        let executable = try XCTUnwrap(found, "no git on this machine")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pcgit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        @discardableResult
        func git(_ arguments: [String]) throws -> (out: String, ok: Bool) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["-C", dir.path] + arguments
            let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
            var environment = ProcessInfo.processInfo.environment
            environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
            environment["GIT_CONFIG_NOSYSTEM"] = "1"
            environment["GIT_TERMINAL_PROMPT"] = "0"
            environment["GIT_EDITOR"] = "false"     // any editor launch is a failure, not a hang
            environment["GIT_AUTHOR_NAME"] = "T"; environment["GIT_AUTHOR_EMAIL"] = "t@example.com"
            environment["GIT_COMMITTER_NAME"] = "T"; environment["GIT_COMMITTER_EMAIL"] = "t@example.com"
            process.environment = environment
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (String(decoding: data, as: UTF8.self), process.terminationStatus == 0)
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
        let found = PluginGit.resolveExecutable(
            setting: nil,
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) },
            exists: { FileManager.default.fileExists(atPath: $0) })
        let executable = try XCTUnwrap(found, "no git on this machine")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pcgit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        @discardableResult
        func git(_ arguments: [String]) throws -> (out: String, ok: Bool) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["-C", dir.path] + arguments
            let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
            var environment = ProcessInfo.processInfo.environment
            environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
            environment["GIT_CONFIG_NOSYSTEM"] = "1"
            environment["GIT_TERMINAL_PROMPT"] = "0"
            environment["GIT_EDITOR"] = "false"
            environment["GIT_AUTHOR_NAME"] = "T"; environment["GIT_AUTHOR_EMAIL"] = "t@example.com"
            environment["GIT_COMMITTER_NAME"] = "T"; environment["GIT_COMMITTER_EMAIL"] = "t@example.com"
            process.environment = environment
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (String(decoding: data, as: UTF8.self), process.terminationStatus == 0)
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
}
