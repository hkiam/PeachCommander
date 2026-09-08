// SPDX-License-Identifier: Apache-2.0
// SyncFilterTests.swift - Which files a synchronisation includes.
//
// Each of these names the case that goes wrong if the behaviour is implemented the obvious way
// instead: matching only the leaf, expanding `*` to `.*`, relying on a pruned descent, collapsing a
// relative date to an absolute one, or applying a size rule per side.

import XCTest
@testable import PCFoundation

final class SyncFilterTests: XCTestCase {

    private func excludes(_ patterns: String, _ path: String, isDirectory: Bool = false) -> Bool {
        SyncFilter(excludePatterns: patterns).exclusions()
            .excludes(relativePath: path, isDirectory: isDirectory)
    }

    // MARK: - What a pattern means

    /// A pattern with no separator is about a name, wherever that name turns up. Implemented as a
    /// test on the leaf alone — which is what the file mask does — this passes for `c.tmp` and fails
    /// here.
    func test_aPatternWithoutASeparatorMatchesAnyComponentAtAnyDepth() {
        XCTAssertTrue(excludes("*.tmp", "c.tmp"))
        XCTAssertTrue(excludes("*.tmp", "a/b/c.tmp"))
        XCTAssertTrue(excludes("node_modules", "node_modules/left-pad/index.js"))
        XCTAssertTrue(excludes("node_modules", "app/node_modules/left-pad/index.js"))
        XCTAssertFalse(excludes("node_modules", "app/src/index.js"))
    }

    /// `*` stops at a separator. With `.*` — which is what the file mask's translation produces —
    /// `src/*/generated` also matches `src/a/b/generated`, and `src/*` swallows the whole tree.
    func test_aStarDoesNotReachAcrossASeparator() {
        XCTAssertTrue(excludes("src/*/generated", "src/a/generated"))
        XCTAssertFalse(excludes("src/*/generated", "src/a/b/generated"),
                       "a path pattern reached across a separator")
        // Without an ancestor in the way, the star's limit is plainly visible.
        XCTAssertTrue(excludes("*/generated", "a/generated"))
        XCTAssertFalse(excludes("*/generated", "a/b/generated"),
                       "a path pattern reached across a separator")
        // `src/*` does cover `src/a/main.swift`, and not because the star crossed anything: the
        // folder `src/a` matches the pattern itself, and everything under an excluded folder is
        // excluded. Measured — the first version of this test asserted the opposite and was wrong
        // about which rule was doing the work.
        XCTAssertTrue(excludes("src/*", "src/main.swift"))
        XCTAssertTrue(excludes("src/*", "src/a/main.swift"))
    }

    /// A trailing separator says "folder", and a file of that name is left alone.
    func test_aTrailingSeparatorRestrictsThePatternToFolders() {
        XCTAssertTrue(excludes("build/", "build", isDirectory: true))
        XCTAssertFalse(excludes("build/", "build", isDirectory: false),
                       "a file was excluded by a folder-only pattern")
        // And it still covers what is inside the folder.
        XCTAssertTrue(excludes("build/", "build/app.o"))
    }

    /// An entry is excluded when any folder above it matches, which is why cutting off the descent is
    /// only ever a speed-up. This is also the case a zip cannot answer any other way: an archive
    /// legitimately holds `node_modules/x/y.js` with no entry for `node_modules/` to prune.
    func test_anEntryUnderAnExcludedFolderIsExcludedWithNoFolderEntryInvolved() {
        XCTAssertTrue(excludes("node_modules/", "node_modules/x/y.js"))
        XCTAssertTrue(excludes(".git/", "project/.git/objects/ab/cdef"))
    }

    /// `prunes` must never claim more than `excludes` does, or the walk would drop a subtree the
    /// decision layer wanted kept.
    func test_pruningNeverExcludesMoreThanTheRuleItself() {
        let ex = SyncFilter(excludePatterns: "build/;*.tmp;src/*/generated").exclusions()
        for path in ["build", "src/a/generated", "src/a/b/generated", "keep", "keep/me", "a.tmp"] {
            if ex.prunes(directory: path) {
                XCTAssertTrue(ex.excludes(relativePath: path, isDirectory: true),
                              "\(path) is pruned but not excluded")
            }
        }
    }

    /// A bar separates patterns here. The file mask gives a single bar the meaning "exclude what
    /// follows", so this text will arrive pasted from that field; treated as a literal it would
    /// exclude nothing at all and say nothing about it.
    func test_bothSeparatorsSplitThePatternList() {
        XCTAssertTrue(excludes("*.bak|*.tmp", "a.bak"))
        XCTAssertTrue(excludes("*.bak|*.tmp", "a.tmp"))
        XCTAssertTrue(excludes("*.bak;*.tmp", "a.tmp"))
        XCTAssertFalse(excludes("*.bak|*.tmp", "a.txt"))
        // Blanks and stray separators are not patterns.
        XCTAssertFalse(excludes(" ; | ; ", "a.txt"))
        XCTAssertTrue(excludes(" *.tmp ; ", "a.tmp"), "a pattern with spaces around it was ignored")
    }

    func test_matchingIgnoresCase() {
        XCTAssertTrue(excludes("build/", "Build", isDirectory: true))
        XCTAssertTrue(excludes("*.TMP", "a.tmp"))
    }

    /// The escaping is the reason this shares the mask's translation instead of having its own: a
    /// name full of regex metacharacters must be matched as itself.
    func test_everythingButTheWildcardsIsLiteral() {
        XCTAssertTrue(excludes("Bericht (2026).pdf", "Bericht (2026).pdf"))
        XCTAssertFalse(excludes("Bericht (2026).pdf", "Bericht 2026.pdf"))
        XCTAssertTrue(excludes("a+b.txt", "a+b.txt"))
        XCTAssertFalse(excludes("a.txt", "axtxt"), "the dot matched any character")
    }

    func test_anEmptyPatternListExcludesNothing() {
        XCTAssertTrue(SyncFilter().exclusions().isEmpty)
        XCTAssertFalse(excludes("", "anything/at/all.txt"))
    }

    // MARK: - Size and date, which act on the pair

    /// The case the whole two-place design exists for. Applied per side, "nothing over 2 GB" drops
    /// the left half of this pair, the pair then reads as "only on the right", and the small file is
    /// copied over the large one — an exclusion that causes a write.
    func test_aPairIsKeptOnlyIfEveryPresentSidePasses() {
        let f = SyncFilter(maxSize: 2_000_000_000)
        XCTAssertFalse(f.keepsPair(leftSize: 3_000_000_000, leftModified: Date(),
                                   rightSize: 1_024, rightModified: Date(),
                                   isDirectory: false, now: Date()),
                       "a pair one side of which is excluded stayed in the comparison")
        XCTAssertTrue(f.keepsPair(leftSize: 1_024, leftModified: Date(),
                                  rightSize: 2_048, rightModified: Date(),
                                  isDirectory: false, now: Date()))
    }

    func test_aOneSidedEntryIsJudgedOnTheSideThatExists() {
        let f = SyncFilter(minSize: 1_000)
        XCTAssertTrue(f.keepsPair(leftSize: 5_000, leftModified: Date(), rightSize: nil,
                                  rightModified: nil, isDirectory: false, now: Date()))
        XCTAssertFalse(f.keepsPair(leftSize: 10, leftModified: Date(), rightSize: nil,
                                   rightModified: nil, isDirectory: false, now: Date()))
    }

    /// A folder's own size and date say nothing about its contents, and excluding a folder by date
    /// would take everything under it along.
    func test_aFolderIsNeverFilteredBySizeOrDate() {
        let f = SyncFilter(maxSize: 1, modifiedWithinDays: 1)
        XCTAssertTrue(f.keepsPair(leftSize: 4_096, leftModified: Date(timeIntervalSince1970: 0),
                                  rightSize: nil, rightModified: nil,
                                  isDirectory: true, now: Date()))
    }

    func test_sizeBoundsAreInclusive() {
        let f = SyncFilter(minSize: 100, maxSize: 200)
        XCTAssertTrue(f.keeps(size: 100, modified: nil, now: Date()))
        XCTAssertTrue(f.keeps(size: 200, modified: nil, now: Date()))
        XCTAssertFalse(f.keeps(size: 99, modified: nil, now: Date()))
        XCTAssertFalse(f.keeps(size: 201, modified: nil, now: Date()))
    }

    // MARK: - The relative date stays relative

    /// The same saved filter, two different runs, two different answers. Collapsing "within the last
    /// N days" to an absolute date when the sheet closes — which is what the search window does with
    /// its own field — passes any test with a fixed `now` and fails this one.
    func test_withinLastNDaysIsResolvedAgainstTheRunAndNotTheSaving() {
        let f = SyncFilter(modifiedWithinDays: 30)
        let file = Date(timeIntervalSince1970: 1_000_000_000)             // 2001-09-09
        let soonAfter = file.addingTimeInterval(10 * 86_400)
        let longAfter = file.addingTimeInterval(400 * 86_400)
        XCTAssertTrue(f.keeps(size: 1, modified: file, now: soonAfter))
        XCTAssertFalse(f.keeps(size: 1, modified: file, now: longAfter),
                       "the relative window was frozen instead of resolved against the run")
    }

    /// Both bounds apply when both are set, which for two lower bounds is the later of the two — the
    /// same reading `SpotlightQuery.build` gives the same pair.
    func test_aRelativeAndAnAbsoluteLowerBoundBothApply() {
        let epoch = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 100 * 86_400)
        let f = SyncFilter(modifiedWithinDays: 10, modifiedAfter: epoch)
        XCTAssertEqual(f.effectiveAfter(now: now), now.addingTimeInterval(-10 * 86_400),
                       "the later of the two lower bounds did not win")
        // And the other way round, where the absolute one is the stricter.
        let strict = SyncFilter(modifiedWithinDays: 10,
                                modifiedAfter: now.addingTimeInterval(-2 * 86_400))
        XCTAssertEqual(strict.effectiveAfter(now: now), now.addingTimeInterval(-2 * 86_400))
    }

    func test_aWithinDaysOfZeroIsNoBoundAtAll() {
        XCTAssertNil(SyncFilter(modifiedWithinDays: 0).effectiveAfter(now: Date()))
        XCTAssertEqual(SyncFilter(modifiedWithinDays: 0).activeCriteriaCount, 0)
    }

    // MARK: - What the window shows

    func test_anEmptyFilterIsInert() {
        XCTAssertFalse(SyncFilter().isActive)
        XCTAssertEqual(SyncFilter().activeCriteriaCount, 0)
        XCTAssertFalse(SyncFilter().hasPairCriteria)
    }

    func test_theCriteriaCountIsWhatTheButtonCanShow() {
        XCTAssertEqual(SyncFilter(excludePatterns: "*.tmp").activeCriteriaCount, 1)
        XCTAssertEqual(SyncFilter(excludePatterns: "*.tmp;*.bak").activeCriteriaCount, 1,
                       "two patterns are one criterion")
        XCTAssertEqual(SyncFilter(excludePatterns: "*.tmp", maxSize: 5,
                                  modifiedWithinDays: 30).activeCriteriaCount, 3)
        // Whitespace is not a criterion.
        XCTAssertEqual(SyncFilter(excludePatterns: "  ", pluginPredicate: " ").activeCriteriaCount, 0)
    }

    // MARK: - It has to survive being saved

    /// Same trap as `SyncPreset`: this rides in a preset on disk, and the synthesized decoder would
    /// throw on a key that a filter written before the next criterion does not have.
    func test_aFilterFromAnOlderVersionStillDecodes() throws {
        let json = Data(#"{"excludePatterns":"*.tmp","maxSize":2048}"#.utf8)
        let f = try JSONDecoder().decode(SyncFilter.self, from: json)
        XCTAssertEqual(f.excludePatterns, "*.tmp")
        XCTAssertEqual(f.maxSize, 2048)
        XCTAssertNil(f.minSize)
        XCTAssertNil(f.modifiedWithinDays)
    }

    func test_aFilterWithAnUnknownFutureFieldStillDecodes() throws {
        let json = Data(#"{"excludePatterns":"*.tmp","aCriterionFromTheFuture":{"depth":2}}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(SyncFilter.self, from: json).excludePatterns, "*.tmp")
    }

    func test_aFilterRoundTripsThroughJSONIncludingItsDates() throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let original = SyncFilter(excludePatterns: "node_modules/;*.tmp", minSize: 1, maxSize: 2,
                                  modifiedWithinDays: 7,
                                  modifiedAfter: Date(timeIntervalSince1970: 1_000_000),
                                  modifiedBefore: Date(timeIntervalSince1970: 2_000_000),
                                  pluginPredicate: "fileinfo.width > 800")
        let back = try decoder.decode(SyncFilter.self, from: encoder.encode(original))
        XCTAssertEqual(back, original)
    }
}
