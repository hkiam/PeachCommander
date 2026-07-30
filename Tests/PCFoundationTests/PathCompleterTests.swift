// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class PathCompleterTests: XCTestCase {
    private var tempDirectory: String = ""
    private var homeDirectory: String = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        let unique = "PathCompleterTests-\(UUID().uuidString)"
        tempDirectory = (NSTemporaryDirectory() as NSString).appendingPathComponent(unique)
        homeDirectory = (tempDirectory as NSString).appendingPathComponent("home")

        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: homeDirectory, withIntermediateDirectories: true)

        try fileManager.createDirectory(
            atPath: (tempDirectory as NSString).appendingPathComponent("apple"),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            atPath: (tempDirectory as NSString).appendingPathComponent("apricot"),
            withIntermediateDirectories: true
        )
        fileManager.createFile(
            atPath: (tempDirectory as NSString).appendingPathComponent("avocado.txt"),
            contents: nil
        )
        fileManager.createFile(
            atPath: (tempDirectory as NSString).appendingPathComponent("banana.txt"),
            contents: nil
        )
        fileManager.createFile(
            atPath: (tempDirectory as NSString).appendingPathComponent(".hidden"),
            contents: nil
        )
        fileManager.createFile(
            atPath: (homeDirectory as NSString).appendingPathComponent("welcome.txt"),
            contents: nil
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: tempDirectory)
        try super.tearDownWithError()
    }

    func testCompletionsMatchCaseInsensitivePrefix() {
        let results = PathCompleter.completions(for: "ap", in: tempDirectory, home: homeDirectory)
        XCTAssertEqual(results, ["apple/", "apricot/"])
    }

    func testCompletionsUppercasePrefixMatchesLowercaseNames() {
        let results = PathCompleter.completions(for: "AP", in: tempDirectory, home: homeDirectory)
        XCTAssertEqual(results, ["apple/", "apricot/"])
    }

    func testDirectoriesGetTrailingSlash() {
        let results = PathCompleter.completions(for: "apple", in: tempDirectory, home: homeDirectory)
        XCTAssertEqual(results, ["apple/"])
    }

    func testFilesDoNotGetTrailingSlash() {
        let results = PathCompleter.completions(for: "banana", in: tempDirectory, home: homeDirectory)
        XCTAssertEqual(results, ["banana.txt"])
    }

    func testHiddenFilesExcludedByDefault() {
        let results = PathCompleter.completions(for: "", in: tempDirectory, home: homeDirectory)
        XCTAssertFalse(results.contains(".hidden"))
        XCTAssertTrue(results.contains("apple/"))
    }

    func testHiddenFilesIncludedWhenLeafStartsWithDot() {
        let results = PathCompleter.completions(for: ".", in: tempDirectory, home: homeDirectory)
        XCTAssertEqual(results, [".hidden"])
    }

    func testAbsoluteTokenCompletion() {
        let token = (tempDirectory as NSString).appendingPathComponent("ap")
        let results = PathCompleter.completions(for: token, in: "/somewhere/else", home: homeDirectory)
        XCTAssertEqual(results, ["apple/", "apricot/"])
    }

    func testTildeTokenCompletion() {
        let results = PathCompleter.completions(for: "~/wel", in: tempDirectory, home: homeDirectory)
        XCTAssertEqual(results, ["welcome.txt"])
    }

    func testCompleteWithTwoCandidatesReturnsLongestCommonPrefix() {
        let completed = PathCompleter.complete("ap", in: tempDirectory, home: homeDirectory)
        XCTAssertEqual(completed, "ap")
    }

    func testCompleteWithTwoCandidatesSharingLongerPrefix() throws {
        try FileManager.default.removeItem(
            atPath: (tempDirectory as NSString).appendingPathComponent("apricot")
        )
        try FileManager.default.createDirectory(
            atPath: (tempDirectory as NSString).appendingPathComponent("applesauce"),
            withIntermediateDirectories: true
        )
        let completed = PathCompleter.complete("ap", in: tempDirectory, home: homeDirectory)
        XCTAssertEqual(completed, "apple")
    }

    func testCompleteWithSingleCandidateFullyCompletes() {
        let completed = PathCompleter.complete("ban", in: tempDirectory, home: homeDirectory)
        XCTAssertEqual(completed, "banana.txt")
    }

    func testCompleteWithNoCandidatesReturnsNil() {
        let completed = PathCompleter.complete("zzz_no_match", in: tempDirectory, home: homeDirectory)
        XCTAssertNil(completed)
    }

    func testCompletePreservesDirectoryPrefixOfToken() {
        let token = "apple/../ap"
        let completed = PathCompleter.complete(token, in: tempDirectory, home: homeDirectory)
        XCTAssertEqual(completed, "apple/../ap")
    }
}
