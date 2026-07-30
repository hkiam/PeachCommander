// AliasStoreTests.swift - Command-line alias parsing + expansion (F-256).

import XCTest
@testable import PCFoundation

final class AliasStoreTests: XCTestCase {
    private let sample = """
    ; comment
    # another comment
    [Aliases]
    gs = git status
    dl=cd ~/Downloads
    empty =
    """

    func test_parse_ignoresCommentsSectionsAndEmptyValues() {
        let s = AliasStore(parsing: sample)
        XCTAssertEqual(s.expansion(for: "gs"), "git status")
        XCTAssertEqual(s.expansion(for: "dl"), "cd ~/Downloads")
        XCTAssertNil(s.expansion(for: "empty"))     // empty value dropped
        XCTAssertNil(s.expansion(for: "comment"))
        XCTAssertFalse(s.isEmpty)
    }

    func test_expand_replacesLeadingTokenAndAppendsArgs() {
        let s = AliasStore(parsing: sample)
        XCTAssertEqual(s.expand("gs -s -v"), "git status -s -v")
        XCTAssertEqual(s.expand("gs"), "git status")
        XCTAssertEqual(s.expand("  gs  "), "git status")   // trimmed
    }

    func test_expand_passesThroughUnknownAndNonLeadingMatches() {
        let s = AliasStore(parsing: sample)
        XCTAssertEqual(s.expand("ls -la"), "ls -la")       // no alias
        XCTAssertEqual(s.expand("echo gs"), "echo gs")     // alias not in leading position
        XCTAssertEqual(s.expand(""), "")
    }

    func test_expand_canProduceInternalCommand() {
        let s = AliasStore(parsing: "sync = cm_SyncDirs")
        XCTAssertEqual(s.expand("sync"), "cm_SyncDirs")
    }
}
