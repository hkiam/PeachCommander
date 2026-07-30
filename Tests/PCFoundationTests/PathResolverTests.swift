// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class PathResolverTests: XCTestCase {
    func testAbsolutePathIgnoresBase() {
        XCTAssertEqual(PathResolver.resolve("/usr/local", base: "/var/tmp"), "/usr/local")
    }

    func testRelativePathJoinsBase() {
        XCTAssertEqual(PathResolver.resolve("sub/dir", base: "/var"), "/var/sub/dir")
    }

    func testDotDotIsResolvedLexically() {
        XCTAssertEqual(PathResolver.resolve("..", base: "/a/b"), "/a")
        XCTAssertEqual(PathResolver.resolve("../c", base: "/a/b"), "/a/c")
        XCTAssertEqual(PathResolver.resolve("./x", base: "/a"), "/a/x")
    }

    func testTildeExpands() {
        XCTAssertEqual(PathResolver.resolve("~", base: "/tmp"), NSHomeDirectory())
        XCTAssertEqual(PathResolver.resolve("~/Documents", base: "/tmp"),
                       NSHomeDirectory() + "/Documents")
    }

    func testWhitespaceTrimmed() {
        XCTAssertEqual(PathResolver.resolve("  /etc  ", base: "/"), "/etc")
    }

    func testEmptyIsNil() {
        XCTAssertNil(PathResolver.resolve("", base: "/tmp"))
        XCTAssertNil(PathResolver.resolve("   ", base: "/tmp"))
    }
}
