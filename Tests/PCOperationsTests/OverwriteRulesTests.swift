// SPDX-License-Identifier: Apache-2.0
// OverwriteRulesTests.swift - Conditional overwrite + auto-rename rules (F-086).

import XCTest
@testable import PCOperations

final class OverwriteRulesTests: XCTestCase {
    private func facts(size: Int64, modified: Date?) -> FileFacts {
        FileFacts(path: "/x", name: "x", size: size, modified: modified, isDirectory: false)
    }
    private let t0 = Date(timeIntervalSince1970: 1000)
    private let t1 = Date(timeIntervalSince1970: 2000)

    func test_overwriteIfSourceNewer() {
        // Source newer → overwrite; older/equal → skip.
        XCTAssertEqual(OverwriteRules.overwriteIfSourceNewer(source: facts(size: 1, modified: t1),
                                                             target: facts(size: 1, modified: t0)), .overwrite)
        XCTAssertEqual(OverwriteRules.overwriteIfSourceNewer(source: facts(size: 1, modified: t0),
                                                             target: facts(size: 1, modified: t1)), .skip)
        XCTAssertEqual(OverwriteRules.overwriteIfSourceNewer(source: facts(size: 1, modified: t0),
                                                             target: facts(size: 1, modified: t0)), .skip)
        // Missing source date never overwrites; missing target date does.
        XCTAssertEqual(OverwriteRules.overwriteIfSourceNewer(source: facts(size: 1, modified: nil),
                                                             target: facts(size: 1, modified: t0)), .skip)
        XCTAssertEqual(OverwriteRules.overwriteIfSourceNewer(source: facts(size: 1, modified: t0),
                                                             target: facts(size: 1, modified: nil)), .overwrite)
    }

    func test_overwriteIfSourceLarger() {
        XCTAssertEqual(OverwriteRules.overwriteIfSourceLarger(source: facts(size: 10, modified: nil),
                                                              target: facts(size: 5, modified: nil)), .overwrite)
        XCTAssertEqual(OverwriteRules.overwriteIfSourceLarger(source: facts(size: 5, modified: nil),
                                                              target: facts(size: 10, modified: nil)), .skip)
        XCTAssertEqual(OverwriteRules.overwriteIfSourceLarger(source: facts(size: 5, modified: nil),
                                                              target: facts(size: 5, modified: nil)), .skip)
    }

    func test_autoRenameName() {
        XCTAssertEqual(OverwriteRules.autoRenameName("report.txt"), "report (2).txt")
        XCTAssertEqual(OverwriteRules.autoRenameName("report (2).txt"), "report (3).txt")
        XCTAssertEqual(OverwriteRules.autoRenameName("noext"), "noext (2)")
        XCTAssertEqual(OverwriteRules.autoRenameName("archive.tar.gz"), "archive.tar (2).gz")
    }
}
