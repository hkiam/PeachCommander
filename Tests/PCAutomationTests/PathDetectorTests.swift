// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

final class PathDetectorTests: XCTestCase {
    func test_findsAbsolutePath_trimsTrailingPunctuation() {
        let matches = PathDetector.detect(in: "I read /Users/me/a.txt.")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.path, "/Users/me/a.txt")
    }

    func test_findsMultiplePaths() {
        let matches = PathDetector.detect(in: "moved /a/one.txt to /b/two.txt")
        XCTAssertEqual(matches.map(\.path), ["/a/one.txt", "/b/two.txt"])
    }

    func test_ignoresNonBoundarySlash() {
        // "and/or" — the slash is mid-token, not a path
        XCTAssertTrue(PathDetector.detect(in: "yes and/or no").isEmpty)
    }

    func test_ignoresLoneSlash() {
        XCTAssertTrue(PathDetector.detect(in: "the root is / here").isEmpty)
    }

    func test_rangeMapsToPath() throws {
        let text = "see /x/y now"
        let m = try XCTUnwrap(PathDetector.detect(in: text).first)
        let ns = text as NSString
        XCTAssertEqual(ns.substring(with: m.range), "/x/y")
    }
}
