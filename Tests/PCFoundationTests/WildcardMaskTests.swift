// SPDX-License-Identifier: Apache-2.0
// WildcardMaskTests.swift - What a file mask means (F-055/F-057/F-035).
//
// This one matcher backs select-by-wildcard, the quick filter, the search's name masks, the sync
// filter and the type-colour rules. It translated a mask into a regular expression by escaping the dot
// and leaving every other metacharacter alone — so a mask was, in effect, a regex, and file names are
// full of regex metacharacters.
//
// The consequence was not "finds nothing", which someone would notice. A mask of `Bericht (2026).pdf`
// failed to match the file of that name *and* matched `Bericht 2026.pdf` — it selected the wrong file,
// and the next operation acted on it.

import XCTest
@testable import PCFoundation

final class WildcardMaskTests: XCTestCase {

    private func assertMatch(_ mask: String, _ name: String, _ expected: Bool,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(WildcardMask(mask).matches(name), expected,
                       "mask [\(mask)] against [\(name)]", file: file, line: line)
    }

    // MARK: - The two characters that mean something

    func testStarAndQuestionMark() {
        assertMatch("*.txt", "notes.txt", true)
        assertMatch("*.txt", "notes.md", false)
        assertMatch("a?c.txt", "abc.txt", true)
        assertMatch("a?c.txt", "ac.txt", false)
        assertMatch("*", "anything at all", true)
    }

    func testSemicolonSeparatesAlternativesAndBarExcludes() {
        assertMatch("*.c;*.h", "main.h", true)
        assertMatch("*.c;*.h", "main.swift", false)
        assertMatch("*.txt|*.bak.txt", "notes.txt", true)
        assertMatch("*.txt|*.bak.txt", "notes.bak.txt", false)
    }

    // MARK: - Everything else is literal

    func testParenthesesAreLiteral() {
        // The case that made this visible: it matched the *other* file.
        assertMatch("Bericht (2026).pdf", "Bericht (2026).pdf", true)
        assertMatch("Bericht (2026).pdf", "Bericht 2026.pdf", false)
    }

    func testQuantifiersAreLiteral() {
        assertMatch("a+b.txt", "a+b.txt", true)
        assertMatch("a+b.txt", "aab.txt", false)
        assertMatch("a{2}.log", "a{2}.log", true)
        assertMatch("a{2}.log", "aa.log", false)
    }

    func testCharacterClassesAreLiteral() {
        assertMatch("[Entwurf].doc", "[Entwurf].doc", true)
        assertMatch("[Entwurf].doc", "E.doc", false)
    }

    func testAnchorsAndOtherMetacharactersAreLiteral() {
        assertMatch("Preis $5.txt", "Preis $5.txt", true)
        assertMatch("^start.txt", "^start.txt", true)
        assertMatch("^start.txt", "start.txt", false)
        assertMatch("back\\slash.txt", "back\\slash.txt", true)
        assertMatch("a|b.txt", "a|b.txt", false, )   // a bar still separates include from exclude
    }

    func testTheDotIsStillLiteral() {
        assertMatch("a.txt", "a.txt", true)
        assertMatch("a.txt", "axtxt", false)
    }

    // MARK: - The translation itself

    func testTheTranslationEscapesEverythingButTheWildcards() {
        XCTAssertEqual(WildcardMask.regexPattern(for: "*.txt"), "^.*\\.txt$")
        XCTAssertEqual(WildcardMask.regexPattern(for: "a?b"), "^a.b$")
        // The point of the fix: metacharacters come out escaped, not passed through.
        let pattern = WildcardMask.regexPattern(for: "(x)+[y]")
        XCTAssertFalse(pattern.contains("(x)+[y]"), "metacharacters must not survive verbatim: \(pattern)")
        XCTAssertNoThrow(try NSRegularExpression(pattern: pattern), "and the result must compile")
    }

    func testMatchingIsCaseInsensitive() {
        assertMatch("*.TXT", "notes.txt", true)
        assertMatch("readme*", "README.md", true)
    }
}
