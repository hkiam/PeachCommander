// SPDX-License-Identifier: Apache-2.0
// PermissionDeniedTests.swift - "you may not write there", in both vocabularies Foundation uses.
//
// The editor offers an elevated save only when the failure really is about permission, so this has to
// be right in both directions: a refused write must be recognised, and an unrelated failure must not
// trigger an authorization prompt the user never asked for.

import XCTest
@testable import PCFoundation

final class PermissionDeniedTests: XCTestCase {
    func testCocoaWritePermissionIsRecognised() {
        XCTAssertTrue(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError).isPermissionDenied)
        XCTAssertTrue(NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError).isPermissionDenied)
    }

    func testPosixPermissionErrorsAreRecognised() {
        // Foundation reports the same refusal in POSIX terms depending on how deep it happened, which
        // is why both vocabularies are handled rather than whichever one was seen first.
        for code in [EACCES, EPERM, EROFS] {
            XCTAssertTrue(NSError(domain: NSPOSIXErrorDomain, code: Int(code)).isPermissionDenied,
                          "errno \(code)")
        }
    }

    func testUnrelatedFailuresDoNotAskForAuthorization() {
        XCTAssertFalse(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError).isPermissionDenied)
        XCTAssertFalse(NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError).isPermissionDenied)
        XCTAssertFalse(NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT)).isPermissionDenied)
        XCTAssertFalse(NSError(domain: NSURLErrorDomain, code: -1009).isPermissionDenied)
    }
}
