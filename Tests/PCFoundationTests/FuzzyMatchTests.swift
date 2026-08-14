// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

/// What the history palette's search must get right (F-402). The absolute numbers are not pinned — the
/// scoring is a heuristic and pinning it would make every tweak a test change — but the *orderings* are,
/// because those are what the user experiences.
final class FuzzyMatchTests: XCTestCase {

    func testASubsequenceMatchesAndSomethingElseDoesNot() {
        XCTAssertNotNil(FuzzyMatch.score("usr", in: "/Users/mel/src"))
        XCTAssertNil(FuzzyMatch.score("zzz", in: "/Users/mel/src"))
        XCTAssertNil(FuzzyMatch.score("srcx", in: "/Users/mel/src"))
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertNotNil(FuzzyMatch.score("USERS", in: "/users/mel"))
        XCTAssertNotNil(FuzzyMatch.score("mel", in: "/Users/MEL"))
    }

    func testAnEmptyPatternMatchesEverything() {
        XCTAssertEqual(FuzzyMatch.score("", in: "/anything"), 0)
        XCTAssertEqual(FuzzyMatch.score("   ", in: "/anything"), 0)
    }

    func testConsecutiveCharactersBeatScattered() {
        let together = FuzzyMatch.score("report", in: "/Users/mel/report.txt")
        let scattered = FuzzyMatch.score("report", in: "/rrr/eee/ppp/ooo/rrr/ttt")
        XCTAssertNotNil(together)
        XCTAssertNotNil(scattered)
        XCTAssertGreaterThan(together!, scattered!)
    }

    /// The initials case: "adr" must find the words' starts, not the first three letters lying around.
    func testWordStartsScoreHigher() {
        let initials = FuzzyMatch.score("adr", in: "/Application Support/dev-report")
        let middles = FuzzyMatch.score("adr", in: "/xxaxxdxxrxx")
        XCTAssertNotNil(initials)
        XCTAssertNotNil(middles)
        XCTAssertGreaterThan(initials!, middles!)
    }

    func testCamelCaseCountsAsWordStarts() {
        let camel = FuzzyMatch.score("gh", in: "getHistory")
        let plain = FuzzyMatch.score("gh", in: "gxxxxhxxxx")
        XCTAssertGreaterThan(camel!, plain!)
    }

    /// What the user remembers is usually the name, not the folders above it.
    func testTheLastPathComponentIsWorthMore() {
        let inName = FuzzyMatch.score("notes", in: "/Users/mel/notes")
        let inFolder = FuzzyMatch.score("notes", in: "/Users/notes/deeply/nested/thing")
        XCTAssertGreaterThan(inName!, inFolder!)
    }

    /// The defect the palette had on its first run in the real app: with a long, noisy prefix the greedy
    /// pass spent "re" on "p*r*ivat*e*" and never reached the file's own name, so searching "report" put
    /// report.txt behind two folders that merely contained those letters. The exact paths from that run.
    func testANameMatchBeatsLettersScatteredThroughALongPath() {
        let base = "/private/tmp/claude-501/-Users-mel-Sources-github-PeachCommander/76917b44/scratchpad"
        let file = FuzzyMatch.score("report", in: base + "/demo/projects/annual/report.txt")
        let folderA = FuzzyMatch.score("report", in: base + "/demo")
        let folderB = FuzzyMatch.score("report", in: base + "/demo/music")
        XCTAssertNotNil(file)
        XCTAssertGreaterThan(file!, folderA ?? Int.min)
        XCTAssertGreaterThan(file!, folderB ?? Int.min)
    }

    func testAShorterCandidateWinsWhenBothContainTheMatch() {
        let short = FuzzyMatch.score("src", in: "/src")
        let long = FuzzyMatch.score("src", in: "/src/" + String(repeating: "x/", count: 60))
        XCTAssertGreaterThan(short!, long!)
    }

    func testEveryWordOfTheQueryMustMatchAndOrderDoesNotMatter() {
        let path = "/Users/mel/Projects/annual-report.txt"
        XCTAssertNotNil(FuzzyMatch.score("proj rep", in: path))
        XCTAssertNotNil(FuzzyMatch.score("rep proj", in: path))
        XCTAssertNil(FuzzyMatch.score("proj missing", in: path))
        XCTAssertTrue(FuzzyMatch.matches("annual txt", in: path))
    }

    func testACommandLineIsSearchableToo() {
        XCTAssertNotNil(FuzzyMatch.score("gst", in: "git status"))
        XCTAssertNotNil(FuzzyMatch.score("grep x", in: "grep -rn \"x\" ."))
    }
}
