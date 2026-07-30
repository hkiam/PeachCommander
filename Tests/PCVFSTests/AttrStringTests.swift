// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCVFS

final class AttrStringTests: XCTestCase {
    func testRwxAndType() {
        XCTAssertEqual(VFSEntry.attrString(kind: .file, mode: 0o644, bsdFlags: 0), "-rw-r--r--")
        XCTAssertEqual(VFSEntry.attrString(kind: .directory, mode: 0o755, bsdFlags: 0), "drwxr-xr-x")
        XCTAssertEqual(VFSEntry.attrString(kind: .symlinkFile, mode: 0o777, bsdFlags: 0), "lrwxrwxrwx")
        // symlinkDir is directory-like → 'd' (matches the previous behavior).
        XCTAssertEqual(VFSEntry.attrString(kind: .symlinkDir, mode: 0o755, bsdFlags: 0), "drwxr-xr-x")
    }

    func testBSDFlagsSuffix() {
        let UF_IMMUTABLE: UInt32 = 0x0000_0002
        let SF_IMMUTABLE: UInt32 = 0x0002_0000
        let UF_HIDDEN: UInt32    = 0x0000_8000
        let UF_APPEND: UInt32    = 0x0000_0004
        XCTAssertEqual(VFSEntry.attrString(kind: .file, mode: 0o644, bsdFlags: UF_IMMUTABLE), "-rw-r--r-- u")
        XCTAssertEqual(VFSEntry.attrString(kind: .file, mode: 0o644, bsdFlags: SF_IMMUTABLE), "-rw-r--r-- s")
        XCTAssertEqual(VFSEntry.attrString(kind: .file, mode: 0o644, bsdFlags: UF_HIDDEN), "-rw-r--r-- h")
        XCTAssertEqual(VFSEntry.attrString(kind: .file, mode: 0o644, bsdFlags: UF_IMMUTABLE | UF_HIDDEN | UF_APPEND),
                       "-rw-r--r-- uha")
    }
}
