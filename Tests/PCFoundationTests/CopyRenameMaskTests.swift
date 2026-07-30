// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class CopyRenameMaskTests: XCTestCase {
    func testIsMask() {
        XCTAssertTrue(CopyRenameMask.isMask("*.bak"))
        XCTAssertTrue(CopyRenameMask.isMask("??.dat"))
        XCTAssertFalse(CopyRenameMask.isMask("plain.txt"))
        XCTAssertFalse(CopyRenameMask.isMask("folder"))
    }

    func testStarKeepsNameReplacesExt() {
        XCTAssertEqual(CopyRenameMask.apply("*.bak", to: "readme.txt"), "readme.bak")
    }

    func testIdentityStarDotStar() {
        XCTAssertEqual(CopyRenameMask.apply("*.*", to: "readme.txt"), "readme.txt")
        XCTAssertEqual(CopyRenameMask.apply("*.*", to: "noext"), "noext")
    }

    func testPrefixAndSuffix() {
        XCTAssertEqual(CopyRenameMask.apply("backup_*.*", to: "readme.txt"), "backup_readme.txt")
        XCTAssertEqual(CopyRenameMask.apply("*_old.*", to: "readme.txt"), "readme_old.txt")
    }

    func testNoDotInMaskKeepsSourceExtension() {
        XCTAssertEqual(CopyRenameMask.apply("new_*", to: "readme.txt"), "new_readme.txt")
        XCTAssertEqual(CopyRenameMask.apply("fixed", to: "readme.txt"), "fixed.txt")
    }

    func testTrailingDotStripsExtension() {
        XCTAssertEqual(CopyRenameMask.apply("*.", to: "readme.txt"), "readme")
    }

    func testQuestionMarkCopiesSingleChars() {
        XCTAssertEqual(CopyRenameMask.apply("??.dat", to: "readme.txt"), "re.dat")
        // More '?' than source chars: extras are dropped, not padded.
        XCTAssertEqual(CopyRenameMask.apply("?????????.x", to: "ab.y"), "ab.x")
    }

    func testFullLiteralNameForSingleFileRename() {
        XCTAssertEqual(CopyRenameMask.apply("renamed.log", to: "readme.txt"), "renamed.log")
    }

    func testDotfileHasNoExtension() {
        // ".gitignore" is all base; "*.cfg" replaces the (empty) extension.
        XCTAssertEqual(CopyRenameMask.apply("*.cfg", to: ".gitignore"), ".gitignore.cfg")
    }

    func testMultipleDotsSplitAtLast() {
        XCTAssertEqual(CopyRenameMask.apply("*.gz", to: "archive.tar.gz"), "archive.tar.gz")
        XCTAssertEqual(CopyRenameMask.apply("*.*", to: "archive.tar.gz"), "archive.tar.gz")
    }
}
