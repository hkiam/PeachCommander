import XCTest
@testable import PCFoundation

final class RenameValidatorTests: XCTestCase {
    func testValidNames() {
        XCTAssertEqual(RenameValidator.validate("report.pdf"), .valid)
        XCTAssertEqual(RenameValidator.validate("a file with spaces.txt"), .valid)
        XCTAssertEqual(RenameValidator.validate(".hidden"), .valid)
        XCTAssertTrue(RenameValidator.isValid("Ünïcödé.dat"))
    }

    func testEmpty() {
        XCTAssertEqual(RenameValidator.validate(""), .empty)
        XCTAssertEqual(RenameValidator.validate("   "), .empty)
    }

    func testReserved() {
        XCTAssertEqual(RenameValidator.validate("."), .reserved)
        XCTAssertEqual(RenameValidator.validate(".."), .reserved)
        XCTAssertEqual(RenameValidator.validate("  ..  "), .reserved)
    }

    func testSeparator() {
        XCTAssertEqual(RenameValidator.validate("a/b"), .containsSeparator)
        XCTAssertEqual(RenameValidator.validate("/etc"), .containsSeparator)
    }
}
