import XCTest
@testable import PCFoundation

final class PosixPermissionsTests: XCTestCase {
    func testSymbolicForms() {
        XCTAssertEqual(PosixPermissions(mode: 0o755).symbolic, "rwxr-xr-x")
        XCTAssertEqual(PosixPermissions(mode: 0o644).symbolic, "rw-r--r--")
        XCTAssertEqual(PosixPermissions(mode: 0o777).symbolic, "rwxrwxrwx")
        XCTAssertEqual(PosixPermissions(mode: 0o000).symbolic, "---------")
    }

    func testOctalString() {
        XCTAssertEqual(PosixPermissions(mode: 0o755).octalString, "755")
        XCTAssertEqual(PosixPermissions(mode: 0o644).octalString, "644")
        XCTAssertEqual(PosixPermissions(mode: 0o007).octalString, "007")
        XCTAssertEqual(PosixPermissions(mode: 0o1777).octalString, "1777")   // sticky bit
    }

    func testFromOctal() {
        XCTAssertEqual(PosixPermissions.fromOctal("755"), PosixPermissions(mode: 0o755))
        XCTAssertEqual(PosixPermissions.fromOctal("0644"), PosixPermissions(mode: 0o644))
        XCTAssertEqual(PosixPermissions.fromOctal("1777"), PosixPermissions(mode: 0o1777))
        XCTAssertNil(PosixPermissions.fromOctal("789"))    // 8,9 not octal
        XCTAssertNil(PosixPermissions.fromOctal(""))
        XCTAssertNil(PosixPermissions.fromOctal("12345"))  // too long
    }

    func testHasAndSet() {
        var p = PosixPermissions(mode: 0o000)
        XCTAssertFalse(p.has(.owner, .read))
        p.set(.owner, .read, true)
        p.set(.owner, .write, true)
        p.set(.group, .execute, true)
        XCTAssertTrue(p.has(.owner, .read))
        XCTAssertTrue(p.has(.owner, .write))
        XCTAssertFalse(p.has(.owner, .execute))
        XCTAssertTrue(p.has(.group, .execute))
        XCTAssertEqual(p.mode, 0o610)
        p.set(.owner, .read, false)
        XCTAssertFalse(p.has(.owner, .read))
        XCTAssertEqual(p.mode, 0o210)
    }

    func testRoundTripOctal() {
        for mode: UInt16 in [0o755, 0o644, 0o700, 0o111, 0o1755] {
            XCTAssertEqual(PosixPermissions.fromOctal(PosixPermissions(mode: mode).octalString)?.mode, mode)
        }
    }
}
