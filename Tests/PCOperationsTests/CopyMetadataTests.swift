// SPDX-License-Identifier: Apache-2.0
// CopyMetadataTests.swift - What survives a copy, checked against the system's own tools (F-087/F-088).
//
// The inventory says a copy preserves "dates, permissions, xattrs, resource forks, symlinks, ACLs" and
// nothing verified any of it. Each one fails silently: the copy appears, the bytes are right, and the
// thing that is gone — an executable bit, a Finder tag, an ACL that kept a file private — is not
// something anyone notices until it matters.
//
// The witnesses are `stat`, `xattr` and `ls -le`, run as subprocesses. Deliberately not Foundation's
// `attributesOfItem`: that is the same layer the engine writes through, so it would mostly be checking
// that a value round-trips through one API rather than that it reached the file system.

import XCTest
@testable import PCOperations
import PCFoundation

final class CopyMetadataTests: XCTestCase {
    private var root: URL!, src: URL!, dst: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pc-meta-\(UUID().uuidString)")
        src = root.appendingPathComponent("src")
        dst = root.appendingPathComponent("dst")
        for dir in [src!, dst!] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    /// Run a system tool and return its trimmed stdout ("" when it fails, so a missing tool reads as
    /// "nothing there" rather than crashing the test).
    @discardableResult
    private func shell(_ launchPath: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func copyEverything(preserve: Bool = true, clone: Bool = true) async throws {
        var options = CopyOptions()
        options.preserveMetadata = preserve
        options.useCloneWhenPossible = clone
        let names = try FileManager.default.contentsOfDirectory(atPath: src.path).sorted()
        let engine = CopyEngine(options: options, control: OperationControl(),
                                resolver: SkipResolver(), progress: { _ in })
        _ = try await engine.run(items: names.map { src.appendingPathComponent($0).path },
                                 toDirectory: dst.path)
    }

    // MARK: - Permissions and times

    func testTheExecutableBitSurvives() async throws {
        let file = src.appendingPathComponent("script.sh")
        try "#!/bin/sh\necho hi\n".write(to: file, atomically: true, encoding: .utf8)
        shell("/bin/chmod", ["755", file.path])

        try await copyEverything()
        // %Lp is the permission bits in octal — asked of the file system, not of Foundation.
        let mode = shell("/usr/bin/stat", ["-f", "%Lp", dst.appendingPathComponent("script.sh").path])
        XCTAssertEqual(mode, "755", "a copied script that is no longer executable is a broken script")
    }

    func testARestrictiveModeIsNotWidened() async throws {
        // The target is created 0644 and the mode fixed up afterwards; a 0600 file must not be left
        // world-readable at the end of that.
        let file = src.appendingPathComponent("secret.txt")
        try "private".write(to: file, atomically: true, encoding: .utf8)
        shell("/bin/chmod", ["600", file.path])

        try await copyEverything()
        XCTAssertEqual(shell("/usr/bin/stat", ["-f", "%Lp", dst.appendingPathComponent("secret.txt").path]),
                       "600")
    }

    func testTheModificationTimeSurvives() async throws {
        let file = src.appendingPathComponent("old.txt")
        try "old".write(to: file, atomically: true, encoding: .utf8)
        shell("/usr/bin/touch", ["-t", "199901011200.00", file.path])

        try await copyEverything()
        let srcTime = shell("/usr/bin/stat", ["-f", "%m", file.path])
        let dstTime = shell("/usr/bin/stat", ["-f", "%m", dst.appendingPathComponent("old.txt").path])
        XCTAssertEqual(dstTime, srcTime, "a copy that renames every file to \"now\" destroys sort order")
        XCTAssertFalse(srcTime.isEmpty)
    }

    // MARK: - Extended attributes (Finder tags, resource forks, quarantine)

    func testAnExtendedAttributeSurvives() async throws {
        let file = src.appendingPathComponent("tagged.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)
        shell("/usr/bin/xattr", ["-w", "com.example.marker", "kept", file.path])

        try await copyEverything()
        let value = shell("/usr/bin/xattr", ["-p", "com.example.marker",
                                             dst.appendingPathComponent("tagged.txt").path])
        XCTAssertEqual(value, "kept", "Finder tags and comments live in xattrs; losing them is silent")
    }

    func testAResourceForkSurvives() async throws {
        // A resource fork is an extended attribute on modern macOS, but it is the one the inventory
        // names, and it is written through a different path (the ..namedfork alias).
        let file = src.appendingPathComponent("forked.txt")
        try "data".write(to: file, atomically: true, encoding: .utf8)
        try "RESOURCE".write(to: URL(fileURLWithPath: file.path + "/..namedfork/rsrc"),
                            atomically: false, encoding: .utf8)

        try await copyEverything()
        let copied = dst.appendingPathComponent("forked.txt").path + "/..namedfork/rsrc"
        XCTAssertEqual(try? String(contentsOfFile: copied, encoding: .utf8), "RESOURCE")
    }

    func testAnACLSurvives() async throws {
        let file = src.appendingPathComponent("acl.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)
        shell("/bin/chmod", ["+a", "everyone deny delete", file.path])
        // If the platform refused the ACL there is nothing to check; do not pass on an empty comparison.
        try XCTSkipIf(!shell("/bin/ls", ["-le", file.path]).contains("deny delete"),
                      "the ACL could not be set on this volume")

        try await copyEverything()
        let listing = shell("/bin/ls", ["-le", dst.appendingPathComponent("acl.txt").path])
        XCTAssertTrue(listing.contains("deny delete"), "ACL lost; listing was:\n\(listing)")
    }

    // MARK: - Symlinks

    func testASymlinkIsCopiedAsALinkAndNotAsItsTarget() async throws {
        let target = src.appendingPathComponent("target.txt")
        try "pointed at".write(to: target, atomically: true, encoding: .utf8)
        let link = src.appendingPathComponent("link.txt")
        shell("/bin/ln", ["-s", "target.txt", link.path])

        try await copyEverything()
        let copied = dst.appendingPathComponent("link.txt")
        // %Y is the link target; a file that is not a link answers with nothing.
        XCTAssertEqual(shell("/usr/bin/stat", ["-f", "%Y", copied.path]), "target.txt",
                       "following the link instead of copying it silently duplicates data and breaks "
                       + "the relationship the user set up")
    }

    func testASymlinkPointingOutsideTheCopyKeepsItsTarget() async throws {
        // A relative link to somewhere else must be copied verbatim, not resolved and not repaired.
        let link = src.appendingPathComponent("outside.txt")
        shell("/bin/ln", ["-s", "../elsewhere/file.txt", link.path])

        try await copyEverything()
        XCTAssertEqual(shell("/usr/bin/stat", ["-f", "%Y", dst.appendingPathComponent("outside.txt").path]),
                       "../elsewhere/file.txt")
    }

    // MARK: - The clone fast path (F-088)

    func testTheClonePathPreservesTheSameThingsAsTheStreamingPath() async throws {
        // Both paths exist and the user never chooses between them — the volume does. If they disagree
        // about metadata, whether a permission survives depends on which disk the folders are on.
        let file = src.appendingPathComponent("both.sh")
        try "#!/bin/sh\n".write(to: file, atomically: true, encoding: .utf8)
        shell("/bin/chmod", ["700", file.path])
        shell("/usr/bin/xattr", ["-w", "com.example.marker", "kept", file.path])
        shell("/usr/bin/touch", ["-t", "199901011200.00", file.path])

        try await copyEverything(clone: true)
        let cloned = dst.appendingPathComponent("both.sh")
        let cloneMode = shell("/usr/bin/stat", ["-f", "%Lp", cloned.path])
        let cloneXattr = shell("/usr/bin/xattr", ["-p", "com.example.marker", cloned.path])
        let cloneTime = shell("/usr/bin/stat", ["-f", "%m", cloned.path])
        // Anchored to the source, not only to each other: comparing the two runs alone would pass
        // happily if both had lost everything, which is exactly what happened when I checked this test
        // by turning metadata copying off.
        XCTAssertEqual(cloneMode, "700")
        XCTAssertEqual(cloneXattr, "kept")
        XCTAssertEqual(cloneTime, shell("/usr/bin/stat", ["-f", "%m", file.path]))
        try FileManager.default.removeItem(at: cloned)

        try await copyEverything(clone: false)
        XCTAssertEqual(shell("/usr/bin/stat", ["-f", "%Lp", cloned.path]), cloneMode)
        XCTAssertEqual(shell("/usr/bin/xattr", ["-p", "com.example.marker", cloned.path]), cloneXattr)
        XCTAssertEqual(shell("/usr/bin/stat", ["-f", "%m", cloned.path]), cloneTime)
    }

    func testACloneHasTheSameBytes() async throws {
        // clonefile shares storage rather than copying it; if the sharing were ever wrong the file would
        // read back differently, and nothing else in the suite would notice.
        let file = src.appendingPathComponent("data.bin")
        try Data((0..<200_000).map { UInt8($0 & 0xFF) }).write(to: file)

        try await copyEverything(clone: true)
        XCTAssertEqual(try Data(contentsOf: dst.appendingPathComponent("data.bin")),
                       try Data(contentsOf: file))
    }
}

/// Never asked in these tests — every target is new — but the engine requires one.
private struct SkipResolver: OperationResolver {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .skip }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}
