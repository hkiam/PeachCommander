// SPDX-License-Identifier: Apache-2.0
// HiddenFileTests.swift - Both ways a file is hidden on macOS (F-028).
//
// The row promises "dotfiles + hidden flag" and only the dot was ever checked. `chflags hidden` sets
// UF_HIDDEN — it is how the system hides /usr and /bin, and how a user hides a file without renaming
// it — and such a file stayed visible with "show hidden files" switched off.
//
// The flag is set here with the system's own `chflags`, so the fixture is what macOS considers hidden
// rather than what this code thinks it writes.

import XCTest
@testable import PCVFS

final class HiddenFileTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-hidden-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        // The flag has to come off first or the directory removal can trip over it.
        _ = try? chflags(dir.appendingPathComponent("flagged.txt").path, hidden: false)
        try? FileManager.default.removeItem(at: dir)
    }

    @discardableResult
    private func chflags(_ path: String, hidden: Bool) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        process.arguments = [hidden ? "hidden" : "nohidden", path]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func entry(_ name: String) async throws -> VFSEntry {
        try await fs.stat(VFSPath(filesystemId: "file", path: dir.appendingPathComponent(name).path))
    }

    func testADotFileIsHidden() async throws {
        try Data("x".utf8).write(to: dir.appendingPathComponent(".dotfile"))
        let e = try await entry(".dotfile")
        XCTAssertTrue(e.isHidden)
    }

    func testAFlaggedFileIsHiddenToo() async throws {
        let url = dir.appendingPathComponent("flagged.txt")
        try Data("x".utf8).write(to: url)
        try XCTSkipUnless(try chflags(url.path, hidden: true), "chflags is not available here")

        let e = try await entry("flagged.txt")
        XCTAssertTrue(e.isHidden, "a file macOS itself calls hidden must be hidden here as well")
        // …and the attribute column still shows it, which is where the flag was already being read.
        XCTAssertNotEqual(e.bsdFlags & UInt32(UF_HIDDEN), 0)
    }

    func testAnOrdinaryFileIsNotHidden() async throws {
        try Data("x".utf8).write(to: dir.appendingPathComponent("plain.txt"))
        let e = try await entry("plain.txt")
        XCTAssertFalse(e.isHidden, "and nothing else became hidden along the way")
    }

    func testUnhidingBringsItBack() async throws {
        let url = dir.appendingPathComponent("flagged.txt")
        try Data("x".utf8).write(to: url)
        try XCTSkipUnless(try chflags(url.path, hidden: true), "chflags is not available here")
        _ = try chflags(url.path, hidden: false)
        let e = try await entry("flagged.txt")
        XCTAssertFalse(e.isHidden)
    }
}
