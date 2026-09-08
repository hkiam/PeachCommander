// SPDX-License-Identifier: Apache-2.0
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

    // MARK: - A recursive change has to reach what it says it reaches

    /// Applied to the folder first, a mode without its execute bit made the listing that comes next
    /// impossible — so the descent found nothing, everything below was left alone, and the counts
    /// said "1 changed, 0 failed". Measured before this was turned round. Children first now.
    func test_aRecursiveModeWithoutExecuteStillReachesTheChildren() async throws {
        try write("top/sub/file.txt")
        let top = VFSPath(filesystemId: "file", path: dir.appendingPathComponent("top").path)

        let result = await AttributeEngine.apply(posixMode: 0o400, modified: nil, to: [top],
                                                 on: fs, recursive: true)
        // Unlocked one level at a time, and the order is not incidental: without the execute bit on
        // `top` nothing can stat `top/sub`, and without it on `top/sub` nothing can stat the file. So
        // each level is read *before* the next is opened up — the test would otherwise fail for the
        // same reason the engine used to.
        XCTAssertEqual(mode("top"), 0o400)
        try restore("top")
        XCTAssertEqual(mode("top/sub"), 0o400, "the subfolder was never reached")
        try restore("top/sub")
        XCTAssertEqual(mode("top/sub/file.txt"), 0o400, "the file below was never reached")

        XCTAssertEqual(result.changed, 3, "three items were asked for: \(result)")
        XCTAssertEqual(result.failed, 0)
    }

    /// And a mode that keeps the bit still works, so the reordering did not trade one case for another.
    func test_aRecursiveModeThatKeepsExecuteReachesEverything() async throws {
        try write("keep/sub/file.txt")
        let top = VFSPath(filesystemId: "file", path: dir.appendingPathComponent("keep").path)
        let result = await AttributeEngine.apply(posixMode: 0o700, modified: nil, to: [top],
                                                 on: fs, recursive: true)
        XCTAssertEqual(result.changed, 3)
        XCTAssertEqual(mode("keep/sub/file.txt"), 0o700)
        XCTAssertEqual(result.failed, 0)
    }

    /// A walk that cannot be finished is counted, not swallowed: the comment that used to sit in that
    /// `catch` said the counts reported a partial application while nothing ever added to them.
    func test_aFolderThatCannotBeListedIsReportedAsAFailure() async throws {
        try write("locked/inner.txt")
        let locked = dir.appendingPathComponent("locked")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        let result = await AttributeEngine.apply(posixMode: nil, modified: Date(timeIntervalSince1970: 0),
                                                 to: [VFSPath(filesystemId: "file", path: locked.path)],
                                                 on: fs, recursive: true)
        XCTAssertGreaterThan(result.failed, 0, "the unreadable folder was reported as a clean run: \(result)")
    }

    private func restore(_ rel: String) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                             ofItemAtPath: dir.appendingPathComponent(rel).path)
    }

    private func mode(_ rel: String) -> Int {
        let a = try? FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(rel).path)
        return (a?[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    /// A name out of a *listing* is not the user's: for a server or a plugin mount it is whatever the
    /// far side chose to send. `LocalFS` never produces one with a separator in it, so this needs a
    /// filesystem that does — otherwise the guard is a line nobody has ever executed.
    func test_aNameFromAListingCannotPutTheChangeOutsideTheTree() async throws {
        let inside = try write("tree/honest.txt")
        let outside = try write("outside.txt")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: inside.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: outside.path)

        let hostile = HostileNameFS(root: dir.appendingPathComponent("tree").path,
                                    names: ["honest.txt", "../outside.txt"])
        let result = await AttributeEngine.apply(
            posixMode: 0o600, modified: nil,
            to: [VFSPath(filesystemId: "hostile", path: dir.appendingPathComponent("tree").path)],
            on: hostile, recursive: true)

        // The folder itself was given 0o600 too, so its execute bit is gone and nothing can look
        // inside — the same trap the engine used to fall into, and here it is only the test's.
        try restore("tree")
        XCTAssertEqual(mode("tree/honest.txt"), 0o600, "the honest entry was not changed")
        XCTAssertEqual(mode("outside.txt"), 0o644, "a listing name reached outside the tree")
        XCTAssertGreaterThan(result.failed, 0, "the refused name was not reported: \(result)")
    }
}

/// A filesystem whose listing offers a name with a separator in it — what a crafted server response
/// or a misbehaving plugin looks like from the engine's side. Everything else is delegated to the
/// real local filesystem, so the change it *is* allowed to make really happens on disk.
private final class HostileNameFS: VirtualFileSystem, @unchecked Sendable {
    let scheme = "hostile"
    var capabilities: VFSCapabilities { [.read, .write] }
    private let root: String
    private let names: [String]
    private let local = LocalFS()

    init(root: String, names: [String]) { self.root = root; self.names = names }

    private func localPath(_ p: VFSPath) -> VFSPath { VFSPath(filesystemId: "file", path: p.path) }

    func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            if dir.path == root {
                continuation.yield(VFSEntryBatch(entries: names.map {
                    VFSEntry(name: $0, ext: "", kind: .file, size: 1,
                             modified: Date(timeIntervalSince1970: 0), created: nil,
                             posixMode: 0o644, bsdFlags: 0, isHidden: false)
                }))
            }
            continuation.finish()
        }
    }

    func stat(_ path: VFSPath) async throws -> VFSEntry { try await local.stat(localPath(path)) }
    func openRead(_ path: VFSPath) async throws -> VFSReadStream { try await local.openRead(localPath(path)) }
    func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        try await local.openWrite(localPath(path), options: options)
    }
    func mkdir(_ path: VFSPath) async throws { try await local.mkdir(localPath(path)) }
    func delete(_ path: VFSPath) async throws { try await local.delete(localPath(path)) }
    func rename(_ from: VFSPath, to: VFSPath) async throws {
        try await local.rename(localPath(from), to: localPath(to))
    }
    func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {
        try await local.setAttributes(localPath(path), attributes: attributes)
    }
    func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { nil }
    func localFileIfAvailable(_ path: VFSPath) async throws -> URL? { nil }
}
