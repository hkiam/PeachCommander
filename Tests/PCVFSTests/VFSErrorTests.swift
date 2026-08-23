// SPDX-License-Identifier: Apache-2.0
// VFSErrorTests.swift - Which refusal errno actually produced (F-449).
//
// The payload of `permissionDenied` used to be a Bool called `needsElevation`, and nothing pinned what
// it meant. It was set from `code == EPERM` and read by one caller that wanted the errno — so the name
// promised a remedy (administrator rights) that the value knew nothing about, and on macOS the EPERM
// case is usually the privacy gate, where elevation is precisely what cannot help. The mapping is what
// matters, so the mapping is what is tested.

import XCTest
@testable import PCVFS

final class VFSErrorTests: XCTestCase {

    func testEACCESIsTheModeBitsRefusing() {
        XCTAssertEqual(VFSError.fromErrno(EACCES), .permissionDenied(.modeBits))
    }

    func testEPERMIsTheOtherOne() {
        // Not "needs elevation": EPERM is everything the mode bits do not express, and the reason the
        // distinction is kept at all is `PrivateLocation`, which turns it into a Full Disk Access hint.
        XCTAssertEqual(VFSError.fromErrno(EPERM), .permissionDenied(.notPermitted))
    }

    func testTheOtherErrnosStillMapWhereTheyDid() {
        XCTAssertEqual(VFSError.fromErrno(ENOENT, path: "/x"), .notFound("/x"))
        XCTAssertEqual(VFSError.fromErrno(EEXIST, path: "/x"), .exists("/x"))
        XCTAssertEqual(VFSError.fromErrno(ENOSPC), .noSpace)
    }

    func testAnUnmappedErrnoCarriesItsCodeAndTheSystemMessage() {
        guard case .underlying(let code, let message) = VFSError.fromErrno(EIO) else {
            return XCTFail("EIO should fall through to .underlying")
        }
        XCTAssertEqual(code, EIO)
        XCTAssertFalse(message.isEmpty)
    }
}
