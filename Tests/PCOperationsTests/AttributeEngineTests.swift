import XCTest
@testable import PCOperations
import PCFoundation
import PCVFS

final class AttributeEngineTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-attr-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    @discardableResult private func write(_ rel: String) throws -> URL {
        let url = dir.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
        return url
    }
    private func vpath(_ url: URL) -> VFSPath { VFSPath(filesystemId: "file", path: url.path) }
    private func mode(_ url: URL) throws -> UInt16 {
        UInt16((try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as! NSNumber).uint16Value & 0o7777)
    }

    func testChmodFile() async throws {
        let f = try write("a.txt")
        let r = await AttributeEngine.apply(posixMode: 0o600, modified: nil, to: [vpath(f)], on: fs)
        XCTAssertEqual(r.changed, 1)
        XCTAssertEqual(r.failed, 0)
        XCTAssertEqual(try mode(f), 0o600)
    }

    func testSetModificationDate() async throws {
        let f = try write("b.txt")
        let when = Date(timeIntervalSince1970: 1_000_000_000)   // 2001-09-09
        _ = await AttributeEngine.apply(posixMode: nil, modified: when, to: [vpath(f)], on: fs)
        let got = try FileManager.default.attributesOfItem(atPath: f.path)[.modificationDate] as! Date
        XCTAssertEqual(got.timeIntervalSince1970, when.timeIntervalSince1970, accuracy: 1)
    }

    func testSetBSDFlagLockedThenClear() async throws {
        let f = try write("locked.txt")
        let UF_IMMUTABLE: UInt32 = 0x0000_0002
        // Set the user-immutable flag.
        _ = await AttributeEngine.apply(posixMode: nil, modified: nil, bsdFlags: UF_IMMUTABLE,
                                        to: [vpath(f)], on: fs)
        var st = stat()
        XCTAssertEqual(lstat(f.path, &st), 0)
        XCTAssertNotEqual(st.st_flags & UF_IMMUTABLE, 0)
        // Clearing flags (0) must also succeed so the file stays deletable in teardown.
        _ = await AttributeEngine.apply(posixMode: nil, modified: nil, bsdFlags: 0, to: [vpath(f)], on: fs)
        XCTAssertEqual(lstat(f.path, &st), 0)
        XCTAssertEqual(st.st_flags & UF_IMMUTABLE, 0)
    }

    func testSetGroupToOwnPrimaryGroup() async throws {
        let f = try write("grp.txt")
        // chgrp to the current process's primary group is allowed without root.
        guard let gr = getgrgid(getgid()), let name = gr.pointee.gr_name else {
            throw XCTSkip("no primary group name")
        }
        let group = String(cString: name)
        let r = await AttributeEngine.apply(posixMode: nil, modified: nil, groupName: group,
                                            to: [vpath(f)], on: fs)
        XCTAssertEqual(r.failed, 0)
        let got = try FileManager.default.attributesOfItem(atPath: f.path)[.groupOwnerAccountName] as? String
        XCTAssertEqual(got, group)
    }

    func testRecursiveChmod() async throws {
        try write("tree/x.txt")
        try write("tree/sub/y.txt")
        let treeURL = dir.appendingPathComponent("tree")
        let r = await AttributeEngine.apply(posixMode: 0o700, modified: nil,
                                            to: [vpath(treeURL)], on: fs, recursive: true)
        XCTAssertGreaterThanOrEqual(r.changed, 4)   // tree + sub + x.txt + y.txt
        XCTAssertEqual(try mode(dir.appendingPathComponent("tree/x.txt")), 0o700)
        XCTAssertEqual(try mode(dir.appendingPathComponent("tree/sub/y.txt")), 0o700)
    }

    func testNonRecursiveLeavesChildrenUnchanged() async throws {
        try write("d/child.txt")
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o644)],
                                              ofItemAtPath: dir.appendingPathComponent("d/child.txt").path)
        _ = await AttributeEngine.apply(posixMode: 0o700, modified: nil,
                                        to: [vpath(dir.appendingPathComponent("d"))], on: fs, recursive: false)
        XCTAssertEqual(try mode(dir.appendingPathComponent("d/child.txt")), 0o644)   // untouched
    }
}
