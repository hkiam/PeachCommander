// SPDX-License-Identifier: Apache-2.0
// FoldGroupsTests.swift - Bounding the prompt that folds section summaries together (F-451).
//
// The fold used to be one generation over every section summary, under a comment asserting that "the
// section summaries are short, so they fit in one window together". The model decides how long a "two or
// three sentence" summary is, so that was an assumption — and a ten-section file produced a fold prompt
// the model reported as 4100 tokens against a limit of 4096. The same file and the same code passed three
// runs and failed the fourth, which is the worst shape a limit can have.
//
// The grouping is what bounds it, and it is the part that can be tested without a model: the rounds are
// arithmetic, and the generation between them is not.

import XCTest
@testable import PCAutomation

@available(macOS 26, *)
final class FoldGroupsTests: XCTestCase {

    private func text(_ bytes: Int) -> String { String(repeating: "a", count: bytes) }

    func testEverythingFittingIsOneGroup() {
        // The common case must not become several rounds for nothing: one fold, one prompt.
        let groups = NativeToolContext.foldGroups([text(100), text(100), text(100)], budget: 1000)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].count, 3)
    }

    func testTooMuchIsSplitIntoGroupsThatFit() {
        let groups = NativeToolContext.foldGroups(Array(repeating: text(400), count: 6), budget: 1000)
        // 400+400 fits, 1200 would not, so pairs.
        XCTAssertEqual(groups.count, 3)
        XCTAssertTrue(groups.allSatisfy { $0.reduce(0) { $0 + $1.utf8.count } <= 1000 }, "\(groups)")
    }

    func testGroupsKeepNeighboursTogetherAndInOrder() {
        // The sections are consecutive parts of one file: folding section 1 with section 9 would read
        // as though the middle were missing.
        let partials = (1...6).map { "S\($0)" + text(400) }
        let groups = NativeToolContext.foldGroups(partials, budget: 1000)
        XCTAssertEqual(groups.flatMap { $0 }, partials, "order or membership changed")
        for group in groups {
            let numbers = group.compactMap { Int($0.prefix(2).dropFirst()) }
            XCTAssertEqual(numbers, Array(numbers.min()!...numbers.max()!), "not adjacent: \(numbers)")
        }
    }

    func testAPartialOverBudgetOnItsOwnBecomesItsOwnGroup() {
        // Refusing it would mean dropping a section, and a summary of the wrong file is worse than one
        // long prompt.
        let groups = NativeToolContext.foldGroups([text(50), text(5000), text(50)], budget: 1000)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[1][0].utf8.count, 5000)
    }

    func testNothingIsEverDropped() {
        // The property that matters most: whatever the budget, every section reaches the fold.
        let partials = (1...25).map { "section \($0) " + text(300) }
        for budget in [1, 100, 500, 2048, 100_000] {
            let flat = NativeToolContext.foldGroups(partials, budget: budget).flatMap { $0 }
            XCTAssertEqual(flat, partials, "budget \(budget) lost or reordered a section")
        }
    }

    func testAnEmptyListGroupsToNothing() {
        XCTAssertTrue(NativeToolContext.foldGroups([], budget: 1000).isEmpty)
    }

    func testTheRoundsTerminate() {
        // A round has to reduce the count, or `fold` would loop. With a budget that admits at least two
        // ordinary partials the group count is strictly smaller; with one that admits none it is equal,
        // which is the case `fold` stops on rather than spinning.
        let partials = Array(repeating: text(300), count: 8)
        XCTAssertLessThan(NativeToolContext.foldGroups(partials, budget: 1000).count, partials.count)
        XCTAssertEqual(NativeToolContext.foldGroups(partials, budget: 10).count, partials.count)
    }

    func testTheFoldBudgetLeavesRoomForTheInstructionsAndTheConversion() {
        // Not a magic number: it has to be under the read budget, because the fold prompt carries its
        // instructions as well as the partials, and the window counts tokens while this counts bytes.
        XCTAssertLessThan(NativeToolContext.foldBudget, NativeToolContext.readBudget)
    }

    func testTheFoldPromptNamesTheLanguageAndNumbersTheSections() {
        let prompt = NativeToolContext.foldPrompt(["one", "two"], language: "German")
        XCTAssertTrue(prompt.contains("Write in German."), prompt)
        XCTAssertTrue(prompt.contains("Section 1: one"), prompt)
        XCTAssertTrue(prompt.contains("Section 2: two"), prompt)
        // The reader must not be told about the machinery.
        XCTAssertTrue(prompt.contains("Do not mention sections"), prompt)
    }
}
