// SPDX-License-Identifier: Apache-2.0
// SFTPSupportTests.swift - Proves libssh2 links + loads at runtime (F-214).

import XCTest
@testable import PCNet

final class SFTPSupportTests: XCTestCase {
    func test_libssh2Version_isAvailable() {
        let v = SFTPSupport.libssh2Version()
        XCTAssertFalse(v.isEmpty, "libssh2 not linked/loaded")
        // e.g. "1.11.1" — just sanity that it looks like a version.
        XCTAssertTrue(v.first?.isNumber ?? false, "unexpected version string: \(v)")
    }
}
