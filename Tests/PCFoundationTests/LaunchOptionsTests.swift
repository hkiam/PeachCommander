// SPDX-License-Identifier: Apache-2.0
// LaunchOptionsTests.swift - Command-line launch parameter parsing.

import XCTest
@testable import PCFoundation

final class LaunchOptionsTests: XCTestCase {
    private func parse(_ tail: [String]) -> LaunchOptions {
        LaunchOptions.parse(["/path/to/PeachCommander"] + tail)
    }

    func test_explicitFlags() {
        let o = parse(["-LeftPath", "/a", "-RightPath", "/b", "-ActivePanel", "R", "-Tab"])
        XCTAssertEqual(o.leftPath, "/a")
        XCTAssertEqual(o.rightPath, "/b")
        XCTAssertEqual(o.activePanel, .right)
        XCTAssertTrue(o.openInNewTab)
        XCTAssertEqual(o.effectiveLeft, "/a")
        XCTAssertEqual(o.effectiveRight, "/b")
    }

    func test_viewFileAndSearch() {
        let o = parse(["-View", "/tmp/a.log", "-ViewSearch", "ERROR"])
        XCTAssertEqual(o.viewFile, "/tmp/a.log")
        XCTAssertEqual(o.viewSearch, "ERROR")
        // -View must not leak into the positional directory list.
        XCTAssertTrue(o.positionals.isEmpty)
    }

    func test_activePanel_synonyms_caseInsensitive() {
        XCTAssertEqual(parse(["-activepanel", "left"]).activePanel, .left)
        XCTAssertEqual(parse(["-ActivePanel", "r"]).activePanel, .right)
        XCTAssertNil(parse(["-ActivePanel", "middle"]).activePanel)
    }

    func test_positionals_fillLeftThenRight() {
        let o = parse(["/dir1", "/dir2"])
        XCTAssertEqual(o.effectiveLeft, "/dir1")
        XCTAssertEqual(o.effectiveRight, "/dir2")
    }

    func test_leftFlag_plusPositional_fillsRight() {
        let o = parse(["-LeftPath", "/x", "/y"])
        XCTAssertEqual(o.effectiveLeft, "/x")
        XCTAssertEqual(o.effectiveRight, "/y")   // positional becomes right when left is a flag
    }

    func test_configRootValue_isNotAPositional() {
        let o = parse(["-ConfigRoot", "/cfg", "/data"])
        XCTAssertEqual(o.positionals, ["/data"])
        XCTAssertEqual(o.effectiveLeft, "/data")
    }

    func test_macOSInjectedFlags_areSwallowed() {
        let o = parse(["-NSDocumentRevisionsDebugMode", "YES", "-LeftPath", "/a"])
        XCTAssertEqual(o.leftPath, "/a")
        XCTAssertTrue(o.positionals.isEmpty)     // "YES" swallowed as the unknown flag's value
    }

    func test_valueFlag_withoutValue_isSafe() {
        let o = parse(["-LeftPath"])             // no following value
        XCTAssertNil(o.leftPath)
        XCTAssertTrue(o.positionals.isEmpty)
    }
}

extension LaunchOptionsTests {

    func test_startupProbe_takesItsValue() {
        // -StartupProbe drives the pre-first-paint check (F-360); the path must not be mistaken for a
        // directory to open, which is what an unlisted value flag does.
        let opts = LaunchOptions.parse(["pc", "-StartupProbe", "/tmp/probe.txt", "/Users/x"])
        XCTAssertEqual(opts.startupProbe, "/tmp/probe.txt")
        XCTAssertEqual(opts.positionals, ["/Users/x"])
        XCTAssertEqual(opts.effectiveLeft, "/Users/x")
    }

    func test_startupProbe_isAbsentByDefault() {
        XCTAssertNil(LaunchOptions.parse(["pc"]).startupProbe)
    }
}
