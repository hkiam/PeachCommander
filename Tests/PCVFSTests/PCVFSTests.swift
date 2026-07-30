// SPDX-License-Identifier: Apache-2.0
// PCVFSTests - Unit tests for PCVFS module

import XCTest
@testable import PCVFS

final class PCVFSTests: XCTestCase {
    func testVFSPath_equality() {
        let path1 = VFSPath(filesystemId: "local", path: "/home")
        let path2 = VFSPath(filesystemId: "local", path: "/home")
        let path3 = VFSPath(filesystemId: "local", path: "/var")

        XCTAssertEqual(path1, path2)
        XCTAssertNotEqual(path1, path3)
    }

    func testVFSPath_parent() {
        let path = VFSPath(filesystemId: "local", path: "/home/user/docs")
        XCTAssertEqual(path.parent()?.path, "/home/user")
    }

    func testVFSPath_lastComponent() {
        let path = VFSPath(filesystemId: "local", path: "/home/user/docs")
        XCTAssertEqual(path.lastComponent(), "docs")
    }

    func testVFSPath_joining() {
        let path = VFSPath(filesystemId: "local", path: "/home")
        let joined = path.joining("user")
        XCTAssertEqual(joined.path, "/home/user")
    }

    func testVFSEntry_init() {
        let entry = VFSEntry(
            name: "test.txt",
            ext: "txt",
            kind: .file,
            size: 1234,
            modified: Date()
        )
        XCTAssertEqual(entry.name, "test.txt")
        XCTAssertEqual(entry.ext, "txt")
        XCTAssertEqual(entry.kind, .file)
        XCTAssertEqual(entry.size, 1234)
    }

    func testVFSEntry_batch() {
        let batch = VFSEntryBatch(
            entries: [
                VFSEntry(name: "a.txt", ext: "txt", kind: .file, size: 100, modified: Date()),
                VFSEntry(name: "b.txt", ext: "txt", kind: .file, size: 200, modified: Date()),
            ],
            isLastBatch: true
        )
        XCTAssertEqual(batch.entries.count, 2)
        XCTAssertTrue(batch.isLastBatch)
    }

    func testVFSCapabilities_optionSet() {
        let caps: VFSCapabilities = [.read, .write]
        XCTAssertTrue(caps.contains(.read))
        XCTAssertTrue(caps.contains(.write))
        XCTAssertFalse(caps.contains(.rename))
    }

    func testWriteOptions_defaults() {
        let opts = WriteOptions()
        XCTAssertTrue(opts.create)
        XCTAssertTrue(opts.truncate)
        XCTAssertFalse(opts.append)
    }

    func testVFSAttributes_defaults() {
        let attrs = VFSAttributes()
        XCTAssertNil(attrs.posixMode)
        XCTAssertNil(attrs.modified)
    }
}
