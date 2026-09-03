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

    /// A network address is refused, not mangled.
    ///
    /// It used to come back as a local path: the UNC form went down the relative branch and
    /// returned `<base>/\\srv\ablage`, and `//srv/ablage` was worse — `standardizingPath`
    /// collapses the double slash, so the result was `/srv/ablage`, which looks like a real path
    /// and is not the one that was typed. nil is what lets the caller route it to a mount.
    func testNetworkAddressesAreRefused() {
        XCTAssertNil(PathResolver.resolve(#"\\srv-ablage.pdv.lan\ablage\PDV_Gemeinsam"#, base: "/tmp"))
        XCTAssertNil(PathResolver.resolve("//srv-ablage.pdv.lan/ablage", base: "/tmp"))
        XCTAssertNil(PathResolver.resolve("smb://srv/ablage", base: "/tmp"))
        XCTAssertNil(PathResolver.resolve("afp://srv/vol", base: "/tmp"))
    }

    /// But `server/share` stays a relative path: it is spelled exactly like one, and the folder is
    /// what the user meant far more often than the share.
    func testBareServerShareStaysRelative() {
        XCTAssertEqual(PathResolver.resolve("server/share", base: "/var"), "/var/server/share")
    }
}
