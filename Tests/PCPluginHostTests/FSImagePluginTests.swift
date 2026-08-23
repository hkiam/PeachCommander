// SPDX-License-Identifier: Apache-2.0
// FSImagePluginTests.swift — the FSImage plugin, built as shipped and driven through the host.
//
// Two things this deliberately does NOT do. It does not call the driver types
// directly — the plugin is built the way `Tools/build-fsimage-plugin.sh` builds it,
// dlopen'd, and driven through `PCXArchive` and `PCXArchiveFS`, which is the exact
// path the app takes when a user presses Enter on an image. A reader that parses
// correctly but reports entries the host's tree builder mangles would pass a direct
// test and fail in a panel. And it does not author its own images with its own
// encoder: the fixtures come from `/usr/bin/cpio` and the system compressors, so a
// misreading of the format cannot cancel out against a matching miswriting.
//
// The conformance cases here (root listing, nesting, symlinks, byte-exact
// extraction, refusal of a foreign file) are the battery every later driver has to
// pass too — they are written against `DriverCase` rather than against cpio, so
// adding SquashFS means adding a fixture, not adding tests.

import XCTest
import CryptoKit
import PCVFS
import CPCX
// For PcHostServices: the contributed Commands entry is driven through PcRunCommand with
// a fake host table, which is the only way to test what that entry actually produces.
import CContrib
@testable import PCPluginHost

/// Where the fake host was told to reveal the layout report. Global because a
/// `@convention(c)` function pointer cannot capture context — the same constraint, and
/// the same workaround, as `PCThemeTests`.
private nonisolated(unsafe) var revealedPath: String?
/// What the fake host was told to show in a dialog, if anything.
private nonisolated(unsafe) var presentedMessage: String?
/// What the fake host answers when the plugin asks for the cursor's path.
private nonisolated(unsafe) var fakeCursorPath = ""

private func fakeCursorPathCallback(_ host: UnsafeMutableRawPointer?,
                                    _ out: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let out, !fakeCursorPath.isEmpty else { return 0 }
    _ = strlcpy(out, fakeCursorPath, Int(maxlen))
    return 1
}

private func fakeOpenPath(_ host: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?) {
    revealedPath = path.map { String(cString: $0) }
}

private func fakePresentInfo(_ host: UnsafeMutableRawPointer?, _ title: UnsafePointer<CChar>?,
                             _ message: UnsafePointer<CChar>?) {
    presentedMessage = message.map { String(cString: $0) }
}

final class FSImagePluginTests: XCTestCase {
    private var dir: URL!
    private var lib: PluginLibrary!

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fsimage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try buildPlugin()
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    // MARK: - Building the plugin as shipped

    /// The source list mirrors `Tools/build-fsimage-plugin.sh`. It is duplicated
    /// rather than parsed out of the script on purpose: a driver added to one and
    /// not the other fails here loudly, which is cheaper to diagnose than a driver
    /// that quietly is not in the shipped binary.
    private static let pluginSources = [
        "Plugins/FSImage/fsimage.swift",
        "Plugins/FSImage/LayoutCommand.swift",
        "Plugins/SDK/PluginLoc.swift",
        "Plugins/FSImage/Support/ImageReader.swift",
        "Plugins/FSImage/Support/ImageEntry.swift",
        "Plugins/FSImage/Support/Decompressors.swift",
        "Plugins/FSImage/Support/LZO.swift",
        "Plugins/FSImage/Support/LZNT1.swift",
        "Plugins/FSImage/Support/DriverRegistry.swift",
        "Plugins/FSImage/Support/ImageCache.swift",
        "Plugins/FSImage/Support/PartitionTable.swift",
        "Plugins/FSImage/Support/BlobSignature.swift",
        "Plugins/FSImage/Support/ImageLayout.swift",
        "Plugins/FSImage/Support/LayoutReport.swift",
        "Plugins/FSImage/Drivers/NTFSRecord.swift",
        "Plugins/FSImage/Drivers/NTFSDriver.swift",
        "Plugins/FSImage/Drivers/ExFATDriver.swift",
        "Plugins/FSImage/Drivers/FATDriver.swift",
        "Plugins/FSImage/Drivers/CpioDriver.swift",
        "Plugins/FSImage/Drivers/PartitionedDriver.swift",
        "Plugins/FSImage/Drivers/CarvedDriver.swift",
        "Plugins/FSImage/Drivers/SquashFSMetadata.swift",
        "Plugins/FSImage/Drivers/SquashFSDriver.swift",
        "Plugins/FSImage/Drivers/ExtLayout.swift",
        "Plugins/FSImage/Drivers/ExtDriver.swift",
        "Plugins/FSImage/Drivers/CramFSDriver.swift",
        "Plugins/FSImage/Drivers/JFFS2Compression.swift",
        "Plugins/FSImage/Drivers/JFFS2Driver.swift",
        "Plugins/FSImage/Drivers/UBIVolume.swift",
        "Plugins/FSImage/Drivers/UBIFSDriver.swift",
        "Plugins/FSImage/Drivers/BtrfsChunkMap.swift",
        "Plugins/FSImage/Drivers/BtrfsDriver.swift",
    ]

    /// C sources vendored into the plugin. Compiled and linked here exactly as
    /// `Tools/build-fsimage-plugin.sh` does — without them the Swift half links
    /// against undefined ZSTD symbols and *every* test in this file fails at once,
    /// which is at least a loud way to find out the two builds have drifted.
    private static let vendoredCSources = ["Plugins/FSImage/Vendor/zstddeclib.c"]

    private func buildPlugin() throws {
        lib = try openPluginCopy()
    }

    /// A plugin image of this test's own — a separate copy on disk, so a separate `dlopen`.
    ///
    /// Called once per test from `setUpWithError`, and once per worker by the fuzz test: the
    /// plugin keeps state of its own (`ImageCache`), so driving one image from several threads
    /// would be sharing exactly what these tests must not share. A copy costs a file copy.
    private func openPluginCopy() throws -> PluginLibrary {
        // Compiled once per test run and copied per caller — see CachedPluginBuild. Only the
        // compiler stopped running 79 times for one dylib.
        let plugin = try CachedPluginBuild.freshBuild(key: "fsimage", into: dir) { cache in
            let swiftc = "/usr/bin/swiftc"
            try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: swiftc), "swiftc unavailable")

            var objects: [String] = []
            for source in Self.vendoredCSources {
                let object = cache.appendingPathComponent((source as NSString).lastPathComponent + ".o")
                let clang = Process()
                clang.executableURL = URL(fileURLWithPath: "/usr/bin/clang")
                clang.arguments = ["-O2", "-c", "-o", object.path,
                                   repoRoot.appendingPathComponent(source).path]
                let clangErrors = Pipe(); clang.standardError = clangErrors
                try clang.run(); clang.waitUntilExit()
                guard clang.terminationStatus == 0 else {
                    let message = String(data: clangErrors.fileHandleForReading.readDataToEndOfFile(),
                                         encoding: .utf8) ?? ""
                    // `throw`, not XCTFail: this runs inside setUpWithError, and a recorded-but-not-
                    // thrown failure leaves `lib` nil for a test body that force-unwraps it — a
                    // fatalError that takes the runner down along with every test after it.
                    throw PluginBuildFailure(description: "clang failed on \(source): \(message)")
                }
                objects.append(object.path)
            }

            let out = cache.appendingPathComponent("libfsimage.dylib")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: swiftc)
            process.arguments = [
                "-emit-library", "-module-name", "FSImage",
                "-import-objc-header", repoRoot.appendingPathComponent("Plugins/FSImage/FSImageBridging.h").path,
                "-Xcc", "-I\(repoRoot.appendingPathComponent("Plugins/SDK").path)",
                "-o", out.path,
            ] + Self.pluginSources.map { repoRoot.appendingPathComponent($0).path } + objects
            let pipe = Pipe(); process.standardError = pipe
            try process.run(); process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let message = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                throw PluginBuildFailure(description: "swiftc failed: \(message)")
            }
            return out
        }
        // Both ABIs: the plugin is a packer that also contributes a Commands entry, and
        // the host resolves those through two separate opens. Combining them here is
        // what lets one dlopen'd copy be driven from both sides in one test file.
        guard case .success(let lib) = PluginLibrary.open(
            path: plugin.path, required: PCXSymbols.required,
            optional: PCXSymbols.optional + ContribSymbols.optional) else {
            throw PluginBuildFailure(description: "dlopen/symbol resolution failed for \(plugin.path)")
        }
        return lib
    }

    // MARK: - Fixtures

    /// The tree every fixture encodes. Kept as data so each driver's fixture can be
    /// checked against one expectation rather than against a hand-written list per
    /// format — the point of a conformance battery.
    private struct ExpectedTree {
        static let files: [String: String] = [
            "etc/motd": "hello from initramfs\n",
            "etc/conf.d/app.conf": "key = value\n",
            "bin/empty": "",
        ]
        static let directories = ["bin", "etc", "etc/conf.d"]
        static let symlink = (path: "bin/motd-link", target: "../etc/motd")
    }

    /// Author the sample tree on disk. Every format's fixture is built from *this*
    /// directory, so the conformance battery is comparing like with like — three
    /// copies of the tree-building code would drift, and the battery would quietly
    /// stop testing the same thing in each format.
    private func buildSampleTree(at root: URL) throws {
        let manager = FileManager.default
        for directory in ExpectedTree.directories {
            try manager.createDirectory(at: root.appendingPathComponent(directory),
                                        withIntermediateDirectories: true)
        }
        for (path, contents) in ExpectedTree.files {
            try Data(contents.utf8).write(to: root.appendingPathComponent(path))
        }
        try manager.createSymbolicLink(atPath: root.appendingPathComponent(ExpectedTree.symlink.path).path,
                                       withDestinationPath: ExpectedTree.symlink.target)
        // Larger than one block so block lists and extent trees are actually walked,
        // and incompressible so the stored bytes cannot accidentally be the plain ones.
        try Data(Self.bigFileContents).write(to: root.appendingPathComponent("bin/big.dat"))
    }

    /// Deterministic pseudo-random bytes: the same on every run and on every machine,
    /// so a mismatch is the reader's fault and never the fixture's.
    private static let bigFileContents: [UInt8] =
        (0..<300_000).map { UInt8(truncatingIfNeeded: $0 &* 2_654_435_761 >> 13) }

    /// Author the tree on disk, then have `/usr/bin/cpio` turn it into a newc
    /// archive — a third-party encoder, which is the whole value of this fixture.
    private func makeCpioImage(compressor: (name: String, argument: String)? = nil) throws -> String {
        let cpio = "/usr/bin/cpio"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: cpio), "cpio unavailable")
        let root = dir.appendingPathComponent("root-\(UUID().uuidString)")
        try buildSampleTree(at: root)

        var image = dir.appendingPathComponent("initramfs-\(UUID().uuidString).cpio").path
        // `find . | cpio -o -H newc` from inside the tree, exactly how an initramfs
        // is built, so the names carry the "./" prefix real images have.
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "cd \(root.path) && find . | \(cpio) -o -H newc > \(image)"]
        shell.standardError = FileHandle.nullDevice
        try shell.run(); shell.waitUntilExit()
        try XCTSkipUnless(shell.terminationStatus == 0, "cpio failed")

        if let compressor {
            guard let tool = Self.which(compressor.name) else {
                throw XCTSkip("\(compressor.name) unavailable")
            }
            let compressed = image + "." + compressor.argument
            let run = Process()
            run.executableURL = URL(fileURLWithPath: "/bin/sh")
            run.arguments = ["-c", "\(tool) -c \(image) > \(compressed)"]
            run.standardError = FileHandle.nullDevice
            try run.run(); run.waitUntilExit()
            try XCTSkipUnless(run.terminationStatus == 0, "\(compressor.name) failed")
            image = compressed
        }
        return image
    }

    /// The same tree as `makeCpioImage`, built by `mksquashfs` — a third-party
    /// encoder, which is what makes a byte-exact comparison meaningful.
    ///
    /// Skips rather than fails when mksquashfs is absent: it is a Homebrew formula
    /// (`brew install squashfs`), not something a checkout can assume. CI installs it.
    private func makeSquashFSImage(compressor: String = "gzip", extraArguments: [String] = []) throws -> String {
        let mksquashfs = try requireTool("mksquashfs", hint: "brew install squashfs")
        let root = dir.appendingPathComponent("sqroot-\(UUID().uuidString)")
        try buildSampleTree(at: root)

        let image = dir.appendingPathComponent("root-\(UUID().uuidString).sqfs").path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mksquashfs)
        process.arguments = [root.path, image, "-comp", compressor,
                             "-noappend", "-no-progress", "-quiet"] + extraArguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: image) else {
            throw XCTSkip("mksquashfs cannot build a -comp \(compressor) image here")
        }
        return image
    }

    private static func which(_ name: String) -> String? {
        for directory in ["/usr/bin", "/bin", "/opt/homebrew/bin", "/usr/local/bin"]
                          + extraToolDirectories {
            let path = "\(directory)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    /// The same tree again, this time as a real ext2/ext3/ext4 filesystem.
    ///
    /// `mke2fs -d` populates the image from a directory as it creates it — no mount,
    /// no root privileges — which is what makes ext fixtures reproducible on macOS
    /// and on a CI runner at all.
    private func makeExtImage(type: String = "ext4", blockSize: Int = 4096,
                              sizeMB: Int = 32, from source: URL? = nil,
                              features: String? = nil, inodeSize: Int? = nil) throws -> String {
        let mke2fs = try requireTool("mke2fs", hint: "brew install e2fsprogs")
        let root: URL
        if let source {
            root = source
        } else {
            let built = dir.appendingPathComponent("extroot-\(UUID().uuidString)")
            try buildSampleTree(at: built)
            root = built
        }
        let image = dir.appendingPathComponent("fs-\(UUID().uuidString).img").path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mke2fs)
        var arguments = ["-q", "-t", type, "-d", root.path, "-b", String(blockSize)]
        if let features { arguments += ["-O", features] }
        if let inodeSize { arguments += ["-I", String(inodeSize)] }
        process.arguments = arguments + [image, "\(sizeMB)M"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw XCTSkip("mke2fs cannot build a \(type) image here")
        }
        return image
    }

    /// e2fsprogs is keg-only on Homebrew, so its tools are not on the default PATH.
    private static let extraToolDirectories = ["/opt/homebrew/opt/e2fsprogs/sbin",
                                               "/usr/local/opt/e2fsprogs/sbin"]

    // MARK: - Golden fixtures
    //
    // cramfs, JFFS2 and Btrfs have no image builder on macOS — no Homebrew formula,
    // and populating one otherwise needs a Linux kernel. Those images are built once
    // by `Tools/make-fsimage-fixtures.sh` in a container and committed, gzipped, with
    // a manifest recording the exact command and the sha256 of each uncompressed
    // image. Committed rather than generated per run for a plain reason: a test that
    // needs Docker is a test that does not run.

    private var fixturesDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/fsimage")
    }

    /// `<name>  <sha256>  <tool>  <command>` rows from the manifest, comments dropped.
    private func manifestRows() throws -> [(name: String, sha256: String)] {
        let text = try String(contentsOf: fixturesDirectory.appendingPathComponent("manifest.txt"),
                              encoding: .utf8)
        return text.split(separator: "\n").compactMap { line in
            guard !line.hasPrefix("#"), !line.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 2 else { return nil }
            return (String(fields[0]), String(fields[1]))
        }
    }

    /// Unpack a committed fixture and hand back its path.
    ///
    /// The checksum is verified on every use rather than in a test of its own. These
    /// files are opaque binaries nobody reviews in a diff, so "is this still the image
    /// the manifest describes" has to be asked where it matters — a fixture that was
    /// replaced or half-written should fail the format's own tests, naming itself,
    /// instead of surfacing as a confusing parse error.
    private func goldenFixture(_ name: String) throws -> String {
        let archive = fixturesDirectory.appendingPathComponent("\(name).gz")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: archive.path),
                          "\(name).gz is missing — run Tools/make-fsimage-fixtures.sh")
        let image = dir.appendingPathComponent("\(name)-\(UUID().uuidString)")

        let gunzip = Process()
        gunzip.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        gunzip.arguments = ["-c", archive.path]
        let output = Pipe()
        gunzip.standardOutput = output
        gunzip.standardError = FileHandle.nullDevice
        try gunzip.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        gunzip.waitUntilExit()
        guard gunzip.terminationStatus == 0, !data.isEmpty else {
            XCTFail("could not decompress \(name).gz")
            throw XCTSkip("fixture unreadable")
        }
        try data.write(to: image)

        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard let expected = try manifestRows().first(where: { $0.name == name })?.sha256 else {
            XCTFail("\(name) is not listed in manifest.txt")
            throw XCTSkip("fixture unlisted")
        }
        XCTAssertEqual(digest, expected,
                       "\(name) does not match its manifest entry — the fixture changed without "
                       + "Tools/make-fsimage-fixtures.sh being re-run, or it is damaged")
        return image.path
    }

    /// Locate a fixture-building tool, skipping locally but *failing* on CI.
    ///
    /// A developer without `brew install squashfs` should not get a red suite for a
    /// tool they never asked for. CI is the opposite case: it installs the tool on
    /// purpose, and if the install ever breaks, a silent skip would retire an entire
    /// format's coverage while the run still reports success. That is the failure a
    /// skip exists to prevent, so here it has to be the loud one.
    private func requireTool(_ name: String, hint: String) throws -> String {
        if let path = Self.which(name) { return path }
        let onCI = ProcessInfo.processInfo.environment["CI"] != nil
            || ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
        if onCI {
            // A plain error, not XCTFail-then-XCTSkip: a skipped test can carry its
            // recorded failure quietly, and quiet is the one thing this must not be.
            struct MissingTool: Error, CustomStringConvertible {
                let description: String
            }
            throw MissingTool(description:
                "\(name) is missing on CI — \(hint). Without it the tests that build fixtures "
                + "with it stop running, and the suite still reports success.")
        }
        throw XCTSkip("\(name) unavailable (\(hint))")
    }

    private func collect(_ fs: PCXArchiveFS, _ path: String) async throws -> [VFSEntry] {
        var out: [VFSEntry] = []
        for try await batch in fs.list(fs.path(path)) { out.append(contentsOf: batch.entries) }
        return out
    }

    private func read(_ fs: PCXArchiveFS, _ path: String) async throws -> Data {
        var data = Data()
        for try await element in try await fs.openRead(fs.path(path)) {
            if let chunk = element as? Data { data.append(chunk) }
        }
        return data
    }

    // MARK: - The shared conformance battery
    //
    // Written against an image path, not against a format. A new driver earns all of
    // it by producing a fixture with the same tree — it cannot start life with less
    // coverage than the drivers already here, which is the whole point of the plugin
    // growing one format at a time.

    /// Every promise the plugin makes about an image, checked through the host adapter.
    /// - Parameter alsoInRoot: root entries this image is expected to carry beyond the
    ///   sample tree. The battery's claim is "the sample tree came through intact",
    ///   not "nothing else exists" — a fixture may legitimately hold more, and saying
    ///   so at the call site is clearer than loosening the check for everyone.
    private func assertConformance(image: String, label: String, alsoInRoot: Set<String> = [],
                                   file: StaticString = #filePath, line: UInt = #line) async throws {
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:\(label)") else {
            return XCTFail("\(label): the host could not mount the image", file: file, line: line)
        }

        // A filesystem may also add entries of its own that no source tree asked for —
        // ext always creates `lost+found`. Those are part of the image and must be
        // *listed*, so they are excluded here rather than asserted absent.
        let ignored = alsoInRoot.union(["lost+found"])
        let root = try await collect(fs, "/").filter { !ignored.contains($0.name) }
        XCTAssertEqual(Set(root.map(\.name)), ["bin", "etc"],
                       "\(label): root listing", file: file, line: line)

        let etc = try await collect(fs, "/etc")
        XCTAssertEqual(Set(etc.map(\.name)), ["motd", "conf.d"],
                       "\(label): /etc listing", file: file, line: line)
        XCTAssertEqual(etc.first { $0.name == "conf.d" }?.kind, .directory,
                       "\(label): nested directory kind", file: file, line: line)

        let nested = try await collect(fs, "/etc/conf.d")
        XCTAssertEqual(nested.map(\.name), ["app.conf"],
                       "\(label): a directory two levels down must not be flattened",
                       file: file, line: line)

        for (path, expected) in ExpectedTree.files {
            let data = try await read(fs, "/" + path)
            XCTAssertEqual(data, Data(expected.utf8),
                           "\(label): contents differ for \(path)", file: file, line: line)
        }

        let bin = try await collect(fs, "/bin")
        XCTAssertTrue(bin.contains { $0.name == "motd-link" },
                      "\(label): the symlink must appear in its directory", file: file, line: line)
        let target = try await read(fs, "/" + ExpectedTree.symlink.path)
        XCTAssertEqual(String(decoding: target, as: UTF8.self), ExpectedTree.symlink.target,
                       "\(label): symlink target", file: file, line: line)

        let empty = bin.first { $0.name == "empty" }
        XCTAssertEqual(empty?.size, 0, "\(label): a zero-length file is still an entry",
                       file: file, line: line)
    }

    // MARK: - SquashFS

    func testSquashFSGzipPassesTheConformanceBattery() async throws {
        try await assertConformance(image: try makeSquashFSImage(compressor: "gzip"), label: "sqfs-gzip")
    }

    func testSquashFSXzPassesTheConformanceBattery() async throws {
        try await assertConformance(image: try makeSquashFSImage(compressor: "xz"), label: "sqfs-xz")
    }

    func testSquashFSLz4PassesTheConformanceBattery() async throws {
        // Squashfs stores bare LZ4 blocks, which is COMPRESSION_LZ4_RAW rather than
        // Apple's own "bv41"-framed COMPRESSION_LZ4 — this is the case that tells the
        // two apart, because the wrong one decodes nothing at all.
        try await assertConformance(image: try makeSquashFSImage(compressor: "lz4"), label: "sqfs-lz4")
    }

    /// `-noI -noD -noF` stores metadata, data and fragments uncompressed. Each block
    /// then carries the "stored" flag instead of compressed bytes, which is a
    /// separate branch in both the metadata reader and the extractor.
    func testSquashFSWithUncompressedBlocks() async throws {
        let image = try makeSquashFSImage(extraArguments: ["-noI", "-noD", "-noF", "-noX"])
        try await assertConformance(image: image, label: "sqfs-stored")
    }

    /// Without fragments every file occupies whole blocks, so the tail-in-a-shared-
    /// fragment path is skipped and the block-list path carries everything.
    func testSquashFSWithoutFragments() async throws {
        try await assertConformance(image: try makeSquashFSImage(extraArguments: ["-no-fragments"]),
                                    label: "sqfs-nofrag")
    }

    /// A 4 KB block size turns the 300 KB file into a long block list, which is where
    /// an off-by-one in the block count shows up.
    func testSquashFSWithSmallBlocks() async throws {
        try await assertConformance(image: try makeSquashFSImage(extraArguments: ["-b", "4096"]),
                                    label: "sqfs-4k")
    }

    func testSquashFSMultiBlockFileExtractsByteForByte() async throws {
        let image = try makeSquashFSImage()
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:sqfs-big") else {
            return XCTFail("the host could not mount the image")
        }
        let expected = Data(Self.bigFileContents)
        let actual = try await read(fs, "/bin/big.dat")
        XCTAssertEqual(actual.count, expected.count, "a multi-block file must come back whole")
        XCTAssertEqual(actual, expected)
    }

    /// Zstandard, through the vendored single-file decoder.
    ///
    /// This one image exercises both halves of that decoder. A squashfs built with
    /// `-comp zstd` compresses its *metadata* blocks too, and those are decoded
    /// against a ceiling (8 KB, the format's maximum) while data blocks are decoded
    /// against a size the filesystem states exactly. Getting either wrong fails here.
    func testSquashFSZstdPassesTheConformanceBattery() async throws {
        try await assertConformance(image: try makeSquashFSImage(compressor: "zstd"), label: "sqfs-zstd")
    }

    /// LZO, through the decoder written from the format description in `LZO.swift`.
    ///
    /// The one compressor every format here can meet and none of them could read.
    /// Checked against a real `mksquashfs -comp lzo` image rather than against
    /// round-tripped output, because there is nothing here that can *produce* an LZO
    /// stream to round-trip against — which is the point.
    func testSquashFSLzoPassesTheConformanceBattery() async throws {
        try await assertConformance(image: try makeSquashFSImage(compressor: "lzo"), label: "sqfs-lzo")
    }

    /// A 300 KB file is 74 LZO blocks, so this walks the decoder far past the first
    /// instruction — which is where a mis-decoded `state` or a match copied as a range
    /// instead of byte by byte first shows up.
    func testLzoMultiBlockFileExtractsByteForByte() async throws {
        let image = try makeSquashFSImage(compressor: "lzo")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:lzo-big") else {
            return XCTFail("the host could not mount the LZO image")
        }
        let data = try await read(fs, "/bin/big.dat")
        XCTAssertEqual(data, Data(Self.bigFileContents))
    }

    /// Btrfs does not store a bare LZO stream: it wraps segments in its own framing —
    /// a total length, then per-segment lengths, with headers never straddling a page.
    /// Handing the whole extent to the LZO decoder fails on the first byte, because
    /// what looks like an opcode is the low byte of a length.
    func testBtrfsLzoUnwrapsItsSegmentFramingBeforeDecoding() async throws {
        let image = try goldenFixture("btrfs-lzo.img")
        try await assertConformance(image: image, label: "btrfs-lzo")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:btrfs-lzo") else {
            return XCTFail("the host could not mount the LZO btrfs image")
        }
        let data = try await read(fs, "/bin/pattern.dat")
        XCTAssertEqual(data.count, 300_000)
        XCTAssertEqual(data, Data(Self.patternFileContents))
    }

    func testATruncatedSquashFSFailsRatherThanListingWhatSurvived() throws {
        let image = try makeSquashFSImage()
        let full = try Data(contentsOf: URL(fileURLWithPath: image))
        let truncated = dir.appendingPathComponent("truncated.sqfs")
        try full.prefix(full.count / 3).write(to: truncated)
        XCTAssertThrowsError(try PCXArchive(library: lib).list(archivePath: truncated.path))
    }

    // MARK: - cramfs

    func testCramFSLittleEndianPassesTheConformanceBattery() async throws {
        try await assertConformance(image: try goldenFixture("cramfs-le.img"), label: "cramfs-le")
    }

    /// `mkfs.cramfs -N big` is what MIPS and PowerPC devices ship, and firmware full
    /// of them is exactly what this plugin is for.
    ///
    /// The interesting part is not the byte order of the words. An inode is three
    /// 32-bit words carrying seven C bitfields at widths of 16/16/24/8/6/26, and a
    /// big-endian target packs those from the most significant bit down rather than
    /// up. Byte-swapping alone gives a superblock that parses and sizes in the
    /// gigabytes — it does not fail, it just reads nonsense. So this is checked
    /// against a real image rather than reasoned about.
    func testCramFSBigEndianPassesTheConformanceBattery() async throws {
        try await assertConformance(image: try goldenFixture("cramfs-be.img"), label: "cramfs-be")
    }

    /// The 300 KB file spans 74 of cramfs's fixed 4 KB blocks, so this walks the
    /// block-pointer array and the zlib path for every one of them — in both byte
    /// orders, which is where a mirrored bitfield would show up as truncated data.
    func testCramFSMultiBlockFileExtractsByteForByteInBothByteOrders() async throws {
        for name in ["cramfs-le.img", "cramfs-be.img"] {
            let image = try goldenFixture(name)
            guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:\(name)") else {
                return XCTFail("\(name): the host could not mount the image")
            }
            let data = try await read(fs, "/bin/pattern.dat")
            XCTAssertEqual(data.count, 300_000, "\(name): length")
            XCTAssertEqual(data, Data(Self.patternFileContents), "\(name): contents")
        }
    }

    /// The generator's `bin/pattern.dat`, recomputed here. Committed fixtures are
    /// opaque binaries, so what they are supposed to contain has to be stated in code
    /// that a reviewer can check, not left implicit in the bytes.
    private static let patternFileContents: [UInt8] =
        (0..<300_000).map { UInt8((($0 * 7) + 3) % 251) }

    func testEveryCommittedFixtureIsListedInTheManifest() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: fixturesDirectory.path)
            .filter { $0.hasSuffix(".img.gz") }
            .map { String($0.dropLast(3)) }
        try XCTSkipIf(files.isEmpty, "no committed fixtures yet")
        let listed = Set(try manifestRows().map(\.name))
        for file in files {
            XCTAssertTrue(listed.contains(file),
                          "\(file) is committed but not in manifest.txt — nothing records what "
                          + "built it or what it should contain")
        }
    }

    // MARK: - JFFS2

    func testJFFS2LittleEndianPassesTheConformanceBattery() async throws {
        try await assertConformance(image: try goldenFixture("jffs2-le.img"), label: "jffs2-le")
    }

    func testJFFS2BigEndianPassesTheConformanceBattery() async throws {
        try await assertConformance(image: try goldenFixture("jffs2-be.img"), label: "jffs2-be")
    }

    /// An image whose nodes use JFFS2's own `rtime` codec throughout.
    ///
    /// mkfs.jffs2 picks rtime only when it beats zlib on a given node, which on this
    /// tree is never — so the fixture is built with zlib and lzo disabled to force it.
    /// Without that, the rtime decoder would ship having never decoded anything.
    func testJFFS2RtimeCompressedImageReadsIdentically() async throws {
        let image = try goldenFixture("jffs2-rtime.img")
        try await assertConformance(image: image, label: "jffs2-rtime")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:rtime") else {
            return XCTFail("the host could not mount the rtime image")
        }
        let data = try await read(fs, "/bin/pattern.dat")
        XCTAssertEqual(data, Data(Self.patternFileContents),
                       "300 KB through rtime must come back byte for byte")
    }

    /// JFFS2 nodes compressed with LZO — the codec `mkfs.jffs2` prefers above all others
    /// when it is available.
    ///
    /// This fixture exists because the path it covers was **dead**. LZO was wired into the
    /// shared decompressor when it was written, but JFFS2 keeps its own codec switch and
    /// that one still refused LZO by name. Nothing failed, because Ubuntu's mkfs.jffs2 is
    /// built without LZO and no image ever reached it. Alpine's is built with it, and the
    /// first run against this image turned a silent gap into an error.
    func testJFFS2LzoCompressedImageReadsIdentically() async throws {
        let image = try goldenFixture("jffs2-lzo.img")
        try await assertConformance(image: image, label: "jffs2-lzo")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:jffs2-lzo") else {
            return XCTFail("the host could not mount the LZO image")
        }
        let data = try await read(fs, "/bin/pattern.dat")
        XCTAssertEqual(data, Data(Self.patternFileContents),
                       "300 KB through JFFS2's LZO nodes must come back byte for byte")
    }

    /// A raw NAND dump has out-of-band ECC bytes interleaved with the data, so some
    /// node payloads are cut apart by bytes that are not filesystem content.
    ///
    /// The detection is a plain data-integrity check, not a layout heuristic — the
    /// first attempt counted how often the scan resynchronised, and that turned out
    /// identical for a clean image and an interleaved one, because the scan hunts for
    /// magic and finds every node either way. What actually differs is that the
    /// affected nodes fail their own data CRC. Refusing matters more than naming the
    /// cause: using a payload that fails its checksum puts wrong bytes into a file
    /// the user then reads as the firmware's contents.
    func testANandDumpWithInterleavedSpareAreaIsRefused() throws {
        let source = try Data(contentsOf: URL(fileURLWithPath: try goldenFixture("jffs2-le.img")))
        // 2048-byte pages each followed by 64 bytes of spare area, as a NAND dump has.
        var interleaved = Data()
        var offset = 0
        while offset < source.count {
            let end = min(offset + 2048, source.count)
            interleaved.append(source[offset..<end])
            interleaved.append(Data(repeating: 0xA5, count: 64))
            offset = end
        }
        let dump = dir.appendingPathComponent("nand-dump.img")
        try interleaved.write(to: dump)

        XCTAssertThrowsError(try PCXArchive(library: lib).list(archivePath: dump.path),
                             "payloads that fail their own CRC must not be served as file contents")
    }

    // MARK: - Btrfs

    /// The plain image, built by `mkfs.btrfs -r` without ever being mounted: one flat
    /// filesystem tree, no compression, no subvolumes.
    func testBtrfsPassesTheConformanceBattery() async throws {
        try await assertConformance(image: try goldenFixture("btrfs.img"), label: "btrfs")
    }

    /// The image that was actually mounted and written to, which is the only way to
    /// get the parts `mkfs.btrfs -r` cannot produce: zlib-compressed extents, a
    /// subvolume, a snapshot of it, and enough files that the filesystem tree is more
    /// than one level deep. A driver that only ever sees the flat image has tested
    /// almost none of what btrfs is.
    func testBtrfsWithCompressionSubvolumesAndAMultiLevelTree() async throws {
        let image = try goldenFixture("btrfs-rich.img")
        try await assertConformance(image: image, label: "btrfs-rich",
                                    alsoInRoot: ["many", "subvolume-256", "subvolume-257"])
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:btrfs-rich") else {
            return XCTFail("the host could not mount the image")
        }

        // 500 files in one directory only fit in a tree deeper than a single node, so
        // reaching the last of them means internal nodes were walked, not just a leaf.
        let many = try await collect(fs, "/many")
        XCTAssertEqual(many.count, 500, "every file of a multi-level tree must be listed")
        let last = try await read(fs, "/many/f0499.txt")
        XCTAssertEqual(String(decoding: last, as: UTF8.self), "file 499\n")

        // The subvolume and its snapshot are separate trees. Listing only the default
        // one would hide where the older copies of a file actually live.
        let root = try await collect(fs, "/")
        let subvolumes = root.filter { $0.name.hasPrefix("subvolume-") }
        XCTAssertEqual(subvolumes.count, 2, "the subvolume and its snapshot should both be listed")
        for subvolume in subvolumes {
            let note = try await read(fs, "/\(subvolume.name)/note.txt")
            XCTAssertEqual(String(decoding: note, as: UTF8.self), "inside a subvolume\n")
        }
    }

    /// 300 KB written to a filesystem mounted with `compress-force=zlib`.
    ///
    /// The case that caught a real defect. Btrfs compresses in extents of at most
    /// 128 KB, so this file is three of them, and `ram_bytes` — the uncompressed span
    /// — is rounded up to the sector size. The final extent claims 40960 and its
    /// stream yields 37856. Demanding an exact match rejected that tail while the two
    /// full extents ahead of it decoded cleanly, so anything up to 128 KB worked and
    /// only larger files broke.
    func testBtrfsCompressedFileLargerThanOneExtentExtractsByteForByte() async throws {
        let image = try goldenFixture("btrfs-rich.img")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:btrfs-zlib") else {
            return XCTFail("the host could not mount the image")
        }
        let data = try await read(fs, "/bin/pattern.dat")
        XCTAssertEqual(data.count, 300_000, "a compressed file spanning three extents must come back whole")
        XCTAssertEqual(data, Data(Self.patternFileContents))
    }

    func testATruncatedBtrfsImageFailsRatherThanListingWhatSurvived() throws {
        let image = try goldenFixture("btrfs.img")
        let full = try Data(contentsOf: URL(fileURLWithPath: image))
        let truncated = dir.appendingPathComponent("truncated.btrfs")
        // Keep the superblock (64 KB in) but cut away the trees it points at.
        try full.prefix(200_000).write(to: truncated)
        XCTAssertThrowsError(try PCXArchive(library: lib).list(archivePath: truncated.path))
    }

    // MARK: - FAT12 / FAT16 / FAT32

    /// The FAT fixtures hold a tree of their own — mtools writes it in, so the layout
    /// differs slightly from `ExpectedTree` — and all three widths hold the same one.
    private static let fatTree: [String: String] = [
        "etc/motd": "hello from initramfs\n",
        "etc/a-rather-long-file-name.conf": "hello from initramfs\n",
        "etc/conf.d/app.conf": "key = value\n",
        "bin/empty": "",
    ]

    private func assertFATImage(_ name: String, label: String) async throws {
        let image = try goldenFixture(name)
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:\(label)") else {
            return XCTFail("\(label): the host could not mount the image")
        }
        let root = try await collect(fs, "/")
        XCTAssertEqual(Set(root.map(\.name)), ["bin", "etc"], "\(label): root")
        for (path, contents) in Self.fatTree {
            let data = try await read(fs, "/" + path)
            XCTAssertEqual(data, Data(contents.utf8), "\(label): contents of \(path)")
        }
        let big = try await read(fs, "/bin/pattern.dat")
        XCTAssertEqual(big, Data(Self.patternFileContents), "\(label): a file spanning many clusters")
    }

    /// exFAT, despite the name, is not a wider FAT: different directory format, UTF-16
    /// names with no 8.3 alias, and — the part that decides whether large files read at
    /// all — a `NoFatChain` flag meaning the file is contiguous and the allocation table
    /// holds nothing for it. Following the table anyway lands on whatever that cluster's
    /// entry last described, and that flag is the normal case for anything written in
    /// one go.
    ///
    /// The fixture carries no symlink: exFAT has none, and copying one in fails with
    /// "Function not implemented".
    func testExFATReadsIncludingContiguousFilesAndLongNames() async throws {
        let image = try goldenFixture("exfat.img")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:exfat") else {
            return XCTFail("the host could not mount the exFAT image")
        }
        let root = try await collect(fs, "/")
        XCTAssertEqual(Set(root.map(\.name)), ["bin", "etc"])
        for (path, contents) in Self.fatTree {
            let data = try await read(fs, "/" + path)
            XCTAssertEqual(data, Data(contents.utf8), "exfat: contents of \(path)")
        }
        let etc = try await collect(fs, "/etc")
        XCTAssertTrue(etc.contains { $0.name == "a-rather-long-file-name.conf" },
                      "exFAT names are UTF-16 with no 8.3 alias to fall back on")
        let big = try await read(fs, "/bin/pattern.dat")
        XCTAssertEqual(big, Data(Self.patternFileContents),
                       "a 300 KB file, which mkfs writes contiguously — the NoFatChain path")
    }

    /// FAT12 packs two allocation-table entries into three bytes, so an entry is the low
    /// or the high twelve bits of a 16-bit read depending on whether its index is even.
    /// Small media only — which includes plenty of embedded boot partitions.
    func testFAT12ReadsIncludingItsPackedAllocationTable() async throws {
        try await assertFATImage("fat12.img", label: "fat12")
    }

    func testFAT16Reads() async throws {
        try await assertFATImage("fat16.img", label: "fat16")
    }

    /// FAT32 is the one where the root directory is an ordinary cluster chain rather
    /// than a fixed region before the data area.
    func testFAT32ReadsIncludingItsClusterChainedRoot() async throws {
        try await assertFATImage("fat32.img", label: "fat32")
    }

    /// A name that is not 8.3 is stored as a chain of preceding entries holding UTF-16
    /// fragments in reverse order, tied to the real entry by a checksum of its short
    /// name. Without them the listing shows `A-RATH~1.CON` — plausible, wrong, and
    /// exactly what defeats somebody searching a firmware dump for a filename.
    func testFATLongFileNamesAreReassembled() async throws {
        for name in ["fat12.img", "fat16.img", "fat32.img"] {
            let image = try goldenFixture(name)
            guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:lfn-\(name)") else {
                return XCTFail("\(name): the host could not mount the image")
            }
            let etc = try await collect(fs, "/etc")
            XCTAssertTrue(etc.contains { $0.name == "a-rather-long-file-name.conf" },
                          "\(name): the long name, not its 8.3 alias")
            XCTAssertFalse(etc.contains { $0.name.contains("~") },
                           "\(name): no 8.3 alias should be listed in its place")
        }
    }

    // MARK: - NTFS

    /// The flat image, written by `ntfscp` without ever mounting the filesystem.
    ///
    /// Two things here fail *silently* if misread, which is why each is checked against a
    /// real image rather than reasoned about. Every MFT record has the last two bytes of
    /// each of its sectors replaced by a signature, with the real values in an array at
    /// the front — a reader that does not undo those fixups gets a record that parses and
    /// is wrong two bytes per 512. And data runs encode each cluster offset as a *signed
    /// delta* from the previous one, so treating it as unsigned works for the first run
    /// of most files and puts everything after it elsewhere.
    func testNTFSReadsResidentAndNonResidentFiles() async throws {
        let image = try goldenFixture("ntfs.img")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:ntfs") else {
            return XCTFail("the host could not mount the NTFS image")
        }
        let root = try await collect(fs, "/")
        XCTAssertEqual(Set(root.map(\.name)),
                       ["motd", "app.conf", "empty", "pattern.dat", "a-rather-long-file-name.conf"],
                       "NTFS metadata files must not appear in the listing")

        // A small file lives inside its own MFT record; a large one is a run list.
        let resident = try await read(fs, "/app.conf")
        XCTAssertEqual(String(decoding: resident, as: UTF8.self), "key = value\n")
        let nonResident = try await read(fs, "/pattern.dat")
        XCTAssertEqual(nonResident, Data(Self.patternFileContents))
    }

    /// The mounted image: directories, deep nesting, and files ntfs-3g compressed.
    ///
    /// NTFS compresses in fixed units of clusters rather than whole attributes, and how
    /// many clusters a unit actually occupies is what says whether it is compressed:
    /// none is a hole, a full unit is stored verbatim, fewer is an LZNT1 run.
    /// Decompressing everything — or nothing — yields a file that is mostly right and
    /// wrong in patches.
    func testNTFSReadsDirectoriesAndLZNT1CompressedFiles() async throws {
        let image = try goldenFixture("ntfs-rich.img")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:ntfs-rich") else {
            return XCTFail("the host could not mount the NTFS image")
        }
        let root = try await collect(fs, "/")
        XCTAssertEqual(Set(root.map(\.name)), ["bin", "etc", "deep", "comp"])

        let leaf = try await read(fs, "/deep/a/b/c/leaf.txt")
        XCTAssertEqual(String(decoding: leaf, as: UTF8.self), "nested\n")

        // Written into a FILE_ATTRIBUTE_COMPRESSED directory, so these went through LZNT1.
        let compressed = try await read(fs, "/comp/pattern.dat")
        XCTAssertEqual(compressed.count, 300_000, "a compressed file must come back whole")
        XCTAssertEqual(compressed, Data(Self.patternFileContents))
        let short = try await read(fs, "/comp/motd")
        XCTAssertEqual(String(decoding: short, as: UTF8.self), "hello from initramfs\n")

        // And the uncompressed copy of the same bytes, so a decoder that quietly did
        // nothing could not pass by accident.
        let plain = try await read(fs, "/bin/pattern.dat")
        XCTAssertEqual(plain, Data(Self.patternFileContents))
    }

    // MARK: - Partitioned disk images

    /// The case every filesystem driver here would otherwise miss: the filesystem is a
    /// slice of the file, not the file. Without a partition table the plugin finds
    /// nothing at offset 0 and declines an image it could read one partition in.
    ///
    /// Both fixtures hold two partitions the plugin already reads — a SquashFS and an
    /// ext4 — so what is under test is the table and the windowing, not another format.
    func testMBRDiskImageListsEachPartitionAsADirectory() async throws {
        let image = try goldenFixture("disk-mbr.img")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:mbr") else {
            return XCTFail("the host could not mount the partitioned image")
        }
        let root = try await collect(fs, "/")
        let partitions = root.filter { $0.kind == .directory }
        XCTAssertEqual(partitions.count, 2, "one directory per partition")

        // Each partition's own tree hangs under it, with the sample tree intact.
        guard let first = partitions.map(\.name).sorted().first else { return XCTFail("no partitions") }
        let inside = try await collect(fs, "/\(first)")
        XCTAssertEqual(Set(inside.map(\.name)), ["bin", "etc"])
        let motd = try await read(fs, "/\(first)/etc/motd")
        XCTAssertEqual(motd, Data(ExpectedTree.files["etc/motd"]!.utf8))
    }

    /// GPT records a *name* per partition, so the listing shows `1-rootfs` and `2-esp`
    /// rather than a type — which is the difference between a usable listing and two
    /// directories called "partition".
    ///
    /// GPT also always writes a protective MBR in sector 0 claiming the whole disk, so
    /// reading MBR first would report one giant partition where two good ones exist.
    func testGPTDiskImageUsesPartitionNamesAndIgnoresTheProtectiveMBR() async throws {
        let image = try goldenFixture("disk-gpt.img")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:gpt") else {
            return XCTFail("the host could not mount the GPT image")
        }
        let root = try await collect(fs, "/")
        XCTAssertEqual(Set(root.filter { $0.kind == .directory }.map(\.name)), ["1-rootfs", "2-esp"],
                       "GPT partition names, and exactly two — not the protective MBR's one")
        let motd = try await read(fs, "/1-rootfs/etc/motd")
        XCTAssertEqual(motd, Data(ExpectedTree.files["etc/motd"]!.utf8))
    }

    /// A partition's driver must not be able to read outside its own partition. The
    /// window is what enforces it, and it is the only thing that does — every driver
    /// happily follows an offset wherever it points.
    func testAPartitionsDriverCannotReadPastItsOwnPartition() async throws {
        let image = try goldenFixture("disk-mbr.img")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:window") else {
            return XCTFail("the host could not mount the partitioned image")
        }
        // The second partition is ext4 and creates lost+found; the first is SquashFS and
        // never does. Seeing it under the wrong one would mean a driver read across.
        let first = try await collect(fs, "/1-Linux")
        XCTAssertFalse(first.contains { $0.name == "lost+found" },
                       "the SquashFS partition must not show the ext4 partition's contents")
    }

    // MARK: - UBIFS

    /// The bare filesystem, as `mkfs.ubifs` writes it.
    ///
    /// Reading a cleanly written UBIFS is easier than JFFS2, not harder: there is a real
    /// B-tree on disk, so nothing has to be replayed. What is hard is that almost every
    /// offset is unguessable — `node_type` sits at 20 of the common header, not 16, and
    /// a branch is `lnum, offs, len, key` with the key *last*. Neither mistake fails
    /// loudly; both were settled against this image.
    func testUBIFSPassesTheConformanceBattery() async throws {
        try await assertConformance(image: try goldenFixture("rootfs.ubifs"), label: "ubifs")
    }

    /// The same filesystem inside the UBI container firmware actually ships.
    ///
    /// UBI hands out *logical* erase blocks and moves them between physical ones, so the
    /// blocks are in whatever order the writer used — LEB 0 is rarely the first physical
    /// block. Mapping them back has to produce byte-for-byte what the bare image is,
    /// which is exactly what this asserts by running the same battery over both.
    func testUBIContainerReadsIdenticallyToTheBareImage() async throws {
        try await assertConformance(image: try goldenFixture("rootfs.ubi"), label: "ubi")

        let bare = try PCXArchive(library: lib).list(archivePath: try goldenFixture("rootfs.ubifs"))
        let wrapped = try PCXArchive(library: lib).list(archivePath: try goldenFixture("rootfs.ubi"))
        XCTAssertEqual(Set(bare.map(\.path)), Set(wrapped.map(\.path)),
                       "the container and the bare image are the same filesystem")
    }

    /// `mkfs.ubifs` compresses with LZO by default — 74 of 76 data nodes in this image.
    /// Before `LZO.swift` existed, this driver could have listed the tree and failed on
    /// nearly every file in it, which is why UBIFS waited for that decoder.
    func testUBIFSMultiBlockLzoFileExtractsByteForByte() async throws {
        let image = try goldenFixture("rootfs.ubifs")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:ubifs-lzo") else {
            return XCTFail("the host could not mount the UBIFS image")
        }
        let data = try await read(fs, "/bin/pattern.dat")
        XCTAssertEqual(data.count, 300_000)
        XCTAssertEqual(data, Data(Self.patternFileContents))
    }

    // MARK: - ext2 / ext3 / ext4

    func testExt4PassesTheConformanceBattery() async throws {
        try await assertConformance(image: try makeExtImage(type: "ext4"), label: "ext4")
    }

    /// ext2 has no extents at all: every file goes through the direct/indirect block
    /// pointers, which is a completely separate code path from ext4's extent trees.
    func testExt2PassesTheConformanceBattery() async throws {
        try await assertConformance(image: try makeExtImage(type: "ext2"), label: "ext2")
    }

    func testExt3PassesTheConformanceBattery() async throws {
        try await assertConformance(image: try makeExtImage(type: "ext3"), label: "ext3")
    }

    /// 1 KB blocks move `s_first_data_block` to 1, shifting the group descriptor
    /// table by a block, and push the 300 KB file past the singly-indirect level into
    /// the doubly-indirect one.
    func testExt2WithOneKilobyteBlocks() async throws {
        try await assertConformance(image: try makeExtImage(type: "ext2", blockSize: 1024, sizeMB: 64),
                                    label: "ext2-1k")
    }

    func testExtMultiBlockFileExtractsByteForByte() async throws {
        let image = try makeExtImage(type: "ext4")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:ext-big") else {
            return XCTFail("the host could not mount the image")
        }
        let actual = try await read(fs, "/bin/big.dat")
        XCTAssertEqual(actual, Data(Self.bigFileContents))
    }

    /// A sparse file: a 300 KB hole, then four bytes.
    ///
    /// This is the case that caught two real defects, one per block-mapping scheme,
    /// and both had the same shape — a run list treated as a dense sequence when it
    /// is addressed by *logical block*. On ext4 the file has a single extent for
    /// logical block 73, and writing the runs back to back put "TAIL" at offset 0.
    /// On ext2 the singly-indirect level is entirely a hole and was skipped instead
    /// of consuming its 256 blocks, so everything after it shifted forward. Both
    /// produced a file of exactly the right length, full of plausible zeros, with the
    /// content in the wrong place — nothing about the result looked wrong.
    func testSparseFilesPlaceTheirContentAtTheRightOffset() async throws {
        for (type, blockSize) in [("ext4", 4096), ("ext2", 1024)] {
            let source = dir.appendingPathComponent("sparse-\(type)-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
            let sparse = source.appendingPathComponent("sparse.dat")
            FileManager.default.createFile(atPath: sparse.path, contents: nil)
            let writer = try FileHandle(forWritingTo: sparse)
            try writer.seek(toOffset: 300_000)
            try writer.write(contentsOf: Data("TAIL".utf8))
            try writer.close()

            let image = try makeExtImage(type: type, blockSize: blockSize, sizeMB: 64, from: source)
            guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:sparse-\(type)") else {
                return XCTFail("\(type): the host could not mount the image")
            }
            let data = try await read(fs, "/sparse.dat")
            XCTAssertEqual(data.count, 300_004, "\(type): sparse file length")
            XCTAssertEqual(data.suffix(4), Data("TAIL".utf8),
                           "\(type): the tail must land at the end, not at the start")
            XCTAssertTrue(data.prefix(300_000).allSatisfy { $0 == 0 },
                          "\(type): the hole must read as zeros")
        }
    }

    /// A dirty journal means the committed truth is in the journal and the block
    /// groups hold the older version. This driver does not replay journals, so the
    /// only honest options are to refuse the image or to say so where the user will
    /// see it. It says so — silently showing stale data to somebody auditing firmware
    /// is the outcome worth going out of the way to avoid.
    func testAnUncleanFilesystemIsAnnouncedInTheListing() async throws {
        let image = try makeExtImage(type: "ext4")
        // Set the RECOVER incompat bit (0x0004) in the superblock at 1024 + 96.
        let handle = try FileHandle(forUpdating: URL(fileURLWithPath: image))
        try handle.seek(toOffset: 1024 + 96)
        guard let current = try handle.read(upToCount: 4), current.count == 4 else {
            return XCTFail("could not read the incompat feature word")
        }
        var value = current.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
        value |= 0x0004
        try handle.seek(toOffset: 1024 + 96)
        try handle.write(contentsOf: withUnsafeBytes(of: value.littleEndian) { Data($0) })
        try handle.close()

        let entries = try PCXArchive(library: lib).list(archivePath: image)
        XCTAssertTrue(entries.contains { $0.path.contains("UNCLEAN") && $0.path.contains("e2fsck") },
                      "an unclean filesystem must be visible in the listing, not only in a log")
    }

    /// `-O inline_data` puts small files' contents where their block pointers would go —
    /// and *directories* too, which is the part that decides whether the image can be
    /// read at all. An inline directory has no blocks, so a driver without this walks
    /// into nothing and reports an empty or broken tree rather than a file it cannot open.
    ///
    /// An inline directory also has no `.` or `..` records: the first four bytes are the
    /// parent inode number standing in for both.
    func testExt4WithInlineDataReadsSmallFilesAndInlineDirectories() async throws {
        let image = try makeExtImage(type: "ext4", blockSize: 1024, sizeMB: 64,
                                     features: "inline_data", inodeSize: 256)
        try await assertConformance(image: image, label: "ext4-inline")

        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:inline") else {
            return XCTFail("the host could not mount the inline_data image")
        }
        // The sample tree's small files land inline while big.dat keeps its extents, so
        // this image exercises both paths in one walk.
        let motd = try await read(fs, "/etc/motd")
        XCTAssertEqual(motd, Data(ExpectedTree.files["etc/motd"]!.utf8), "an inline file's contents")
        let big = try await read(fs, "/bin/big.dat")
        XCTAssertEqual(big, Data(Self.bigFileContents), "a non-inline file in the same image")
    }

    func testATruncatedExtImageFailsRatherThanListingWhatSurvived() throws {
        let image = try makeExtImage(type: "ext4")
        let full = try Data(contentsOf: URL(fileURLWithPath: image))
        let truncated = dir.appendingPathComponent("truncated.img")
        try full.prefix(full.count / 8).write(to: truncated)
        XCTAssertThrowsError(try PCXArchive(library: lib).list(archivePath: truncated.path),
                             "an image smaller than the filesystem it describes must fail")
    }

    // MARK: - initramfs conformance battery

    func testListsTheWholeTreeThroughTheHostAdapter() async throws {
        let image = try makeCpioImage()
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:test") else {
            return XCTFail("the host could not mount the image")
        }

        let root = try await collect(fs, "/")
        XCTAssertEqual(Set(root.map(\.name)), ["bin", "etc"],
                       "root should hold exactly the two top-level directories")

        let etc = try await collect(fs, "/etc")
        XCTAssertEqual(Set(etc.map(\.name)), ["motd", "conf.d"])
        XCTAssertEqual(etc.first { $0.name == "conf.d" }?.kind, .directory)

        let nested = try await collect(fs, "/etc/conf.d")
        XCTAssertEqual(nested.map(\.name), ["app.conf"],
                       "a directory two levels down must be reachable, not flattened")
    }

    func testFileContentsSurviveExtractionByteForByte() async throws {
        let image = try makeCpioImage()
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:bytes") else {
            return XCTFail("the host could not mount the image")
        }
        for (path, expected) in ExpectedTree.files {
            let data = try await read(fs, "/" + path)
            XCTAssertEqual(data, Data(expected.utf8), "contents differ for \(path)")
        }
    }

    func testSymlinkIsListedAndCarriesItsTarget() async throws {
        let image = try makeCpioImage()
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:link") else {
            return XCTFail("the host could not mount the image")
        }
        let bin = try await collect(fs, "/bin")
        XCTAssertTrue(bin.contains { $0.name == "motd-link" }, "the symlink must appear in its directory")
        // The host has no symlink concept inside an archive, so the entry extracts as
        // a file holding the link target — that is what the plugin promises, and it is
        // what stops an image from planting a real link into the user's filesystem.
        let data = try await read(fs, "/" + ExpectedTree.symlink.path)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), ExpectedTree.symlink.target)
    }

    func testAnEmptyFileListsAsEmptyRatherThanMissing() async throws {
        let image = try makeCpioImage()
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:empty") else {
            return XCTFail("the host could not mount the image")
        }
        let bin = try await collect(fs, "/bin")
        let empty = bin.first { $0.name == "empty" }
        XCTAssertNotNil(empty, "a zero-length file is still an entry")
        XCTAssertEqual(empty?.size, 0)
        let contents = try await read(fs, "/bin/empty")
        XCTAssertEqual(contents, Data())
    }

    // MARK: - Compressed initramfs (the decompressor layer, end to end)

    func testGzippedInitramfsReadsIdenticallyToThePlainOne() async throws {
        let image = try makeCpioImage(compressor: (name: "gzip", argument: "gz"))
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:gz") else {
            return XCTFail("the host could not mount the gzipped image")
        }
        let root = try await collect(fs, "/")
        XCTAssertEqual(Set(root.map(\.name)), ["bin", "etc"])
        let motd = try await read(fs, "/etc/motd")
        XCTAssertEqual(motd, Data(ExpectedTree.files["etc/motd"]!.utf8))
    }

    func testXzInitramfsReadsIdenticallyToThePlainOne() async throws {
        let image = try makeCpioImage(compressor: (name: "xz", argument: "xz"))
        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:xz") else {
            return XCTFail("the host could not mount the xz image")
        }
        let root = try await collect(fs, "/")
        XCTAssertEqual(Set(root.map(\.name)), ["bin", "etc"])
        let motd = try await read(fs, "/etc/motd")
        XCTAssertEqual(motd, Data(ExpectedTree.files["etc/motd"]!.utf8))
    }

    // MARK: - Hardening: hostile and damaged images
    //
    // Firmware images come from update servers, forum posts and chip readers. The
    // parsers here are the first thing to touch bytes nobody vouched for, so what
    // matters is not that a damaged image reads *correctly* — it cannot — but that no
    // image can make the plugin crash, hang, or hand the host a path that escapes the
    // archive. Those three are asserted; being able to read a broken image is not.

    /// Deterministic mutations of a fixture: truncations, bit flips, and length fields
    /// smashed to extreme values.
    ///
    /// Seeded arithmetic rather than random, so a failure names a case that can be
    /// reproduced exactly. Length fields get particular attention because they are how
    /// an image tells the parser how much to allocate and how far to walk — every
    /// unchecked one is an out-of-bounds read or an allocation the size of the field.
    /// The same bytes, moved off offset 0 so that only a scan can find them.
    ///
    /// This is the half of the corpus that was missing, and its absence let two crashes
    /// through. A mutated fixture still probes as its own format at byte 0, so its own
    /// driver opens it directly and the *carve* path never runs — which means
    /// `byteLength` never runs either, because nothing else calls it. Both the ext and
    /// the NTFS overflow lived there, in code the corpus was structurally unable to
    /// reach no matter how many mutations it made.
    ///
    /// The prefix is 467 bytes of values below 128, which is deliberate on both counts:
    /// an odd length so the filesystem starts aligned to nothing, and a range that
    /// cannot contain 0xAA, 0xEF or any other byte of a signature the scan looks for, so
    /// a hit inside the padding is impossible and a hit is always the real fixture.
    private static func buried(_ image: Data) -> Data {
        var out = Data((0..<467).map { UInt8(($0 &* 37 &+ 11) % 128) })
        out.append(image)
        return out
    }

    /// Every header field in turn, set to the value that overflows a size calculation.
    ///
    /// The random-position mutations above are the wrong instrument for this and burying
    /// them did not fix it: the corpus reaches the carve path now, but a scatter of
    /// twenty-eight offsets across a hundred-kilobyte image lands on a superblock field
    /// essentially never. Reverting the NTFS overflow fix and re-running proved it —
    /// the corpus stayed green.
    ///
    /// So this sweeps instead of sampling, and only where header fields actually live:
    /// the boot sector, the ext superblock at 1024, the Btrfs superblock at 65536. That
    /// is a few dozen aligned offsets rather than the whole image, which is what keeps a
    /// sweep affordable. `0x7FFFFFFFFFFFFFFF` is the value chosen because it is the one
    /// that survives every "is this positive and plausible" check and then overflows the
    /// multiplication behind it.
    ///
    /// Buried, because `byteLength` — the function this is aimed at — runs only on the
    /// carve path.
    private static func headerFieldSweep(of image: Data) -> [(label: String, data: Data)] {
        let regions: [(name: String, range: Range<Int>)] = [
            ("boot", 0..<128),              // FAT, exFAT and NTFS boot sectors
            ("ext-sb", 1024..<1400),        // the ext superblock
            ("btrfs-sb", 65536..<65700),    // the Btrfs superblock
        ]
        var out: [(String, Data)] = []
        for (name, range) in regions {
            for offset in stride(from: range.lowerBound, to: range.upperBound, by: 8)
            where offset + 8 <= image.count {
                var copy = image
                for byte in 0..<8 {
                    copy[copy.startIndex + offset + byte] = byte == 7 ? 0x7F : 0xFF
                }
                // Truncated to the header region plus slack. The sweep is aimed at
                // `byteLength`, which runs on the header the moment a magic matches, so
                // the rest of the image contributes nothing but scanning time — and a
                // 32 MB fixture swept sixty times is the difference between this batch
                // finishing and blowing its deadline, which is how the first attempt
                // failed.
                out.append(("sweep-\(name)-\(offset)", buried(copy.prefix(128 << 10))))
            }
        }
        return out
    }

    private static func mutations(of image: Data, count: Int) -> [(label: String, data: Data)] {
        guard image.count > 512 else { return [] }
        var out: [(String, Data)] = []
        for index in 0..<count {
            var copy = image
            let position = (index &* 2_654_435_761) % (image.count - 8)
            switch index % 4 {
            case 0:
                out.append(("truncated-at-\(position)", image.prefix(position)))
                continue
            case 1:
                copy[copy.startIndex + position] ^= 0xFF
                out.append(("byte-flip-at-\(position)", copy))
            case 2:
                // A 32-bit length field set to its maximum.
                let aligned = position - (position % 4)
                for byte in 0..<4 { copy[copy.startIndex + aligned + byte] = 0xFF }
                out.append(("u32-max-at-\(aligned)", copy))
            default:
                // A 64-bit field set to the largest positive signed value, which is
                // where a naive `Int64` size calculation overflows.
                let aligned = position - (position % 8)
                for byte in 0..<8 { copy[copy.startIndex + aligned + byte] = byte == 7 ? 0x7F : 0xFF }
                out.append(("i64-max-at-\(aligned)", copy))
            }
        }
        return out
    }

    /// Paths the plugin may hand the host. Anything else is a defect regardless of how
    /// damaged the image was.
    private func assertPathIsSafe(_ path: String, case label: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(path.hasPrefix("/"),
                       "\(label): absolute path \"\(path)\" escapes the archive root", file: file, line: line)
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        XCTAssertFalse(components.contains(".."),
                       "\(label): \"\(path)\" walks out of the archive", file: file, line: line)
        XCTAssertFalse(components.contains(""),
                       "\(label): \"\(path)\" has an empty component", file: file, line: line)
        XCTAssertFalse(path.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7F },
                       "\(label): \"\(path)\" carries control characters", file: file, line: line)
        XCTAssertLessThan(path.utf8.count, 1024,
                          "\(label): path longer than the ABI buffer", file: file, line: line)
    }

    /// The corpus gate: no mutation of any fixture may crash, hang, or produce an
    /// unsafe path.
    ///
    /// Each case runs under its own `PluginGuard` with its own id. The guard turns a
    /// fatal signal into a reported failure instead of taking the whole test bundle
    /// down with it — and because the id is per-case, one crash does not quarantine
    /// the plugin and silently turn every later case into a no-op.
    func testNoMutatedImageCrashesHangsOrEscapesTheRoot() throws {
        var sources: [(String, Data)] = []
        for name in ["cramfs-le.img", "cramfs-be.img", "jffs2-le.img", "jffs2-rtime.img",
                     "btrfs.img", "btrfs-lzo.img", "jffs2-lzo.img", "rootfs.ubifs", "rootfs.ubi", "disk-mbr.img", "fat16.img", "exfat.img", "ntfs.img"] {
            if let path = try? goldenFixture(name),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                sources.append((name, data))
            }
        }
        if let squash = try? makeSquashFSImage(), let data = try? Data(contentsOf: URL(fileURLWithPath: squash)) {
            sources.append(("squashfs", data))
        }
        if let ext = try? makeExtImage(), let data = try? Data(contentsOf: URL(fileURLWithPath: ext)) {
            sources.append(("ext4", data))
        }
        try XCTSkipIf(sources.isEmpty, "no fixtures available to mutate")

        var cases: [(label: String, path: String, buried: Bool)] = []
        for (name, data) in sources {
            for (label, mutated) in Self.mutations(of: data, count: 28) {
                let url = dir.appendingPathComponent("fuzz-\(name)-\(label)")
                try mutated.write(to: url)
                cases.append(("\(name)/\(label)", url.path, false))

                // The same bytes again, buried, so the scan is the only way in.
                let deep = dir.appendingPathComponent("fuzz-\(name)-\(label)-buried")
                try Self.buried(mutated).write(to: deep)
                cases.append(("\(name)/\(label)/buried", deep.path, true))
            }
            for (label, swept) in Self.headerFieldSweep(of: data) {
                let url = dir.appendingPathComponent("fuzz-\(name)-\(label)")
                try swept.write(to: url)
                cases.append(("\(name)/\(label)", url.path, true))
            }
        }

        // The whole batch runs on a background queue against one deadline. A parser
        // that hangs would otherwise block this test forever with no indication of
        // which input did it, so the index of the last case started is published as it
        // goes and reported if the deadline passes.
        let progress = NSLock()
        var crashed: [String] = []
        var unsafePaths: [(String, String)] = []
        /// Cases that got past the magic check into real parsing. Counted because a
        /// corpus every case of which is rejected at the first four bytes exercises
        /// nothing at all, and would pass forever while proving nothing.
        var reachedParser = 0
        /// Of those, the ones that got there through the scan rather than through a
        /// driver claiming byte 0. Counted separately because that is the path the
        /// corpus could not reach at all until now, and a combined number would let it
        /// stop reaching it again without anybody noticing.
        var reachedParserBuried = 0

        // Striped over a few workers, each holding a plugin image of its own. The cases were always
        // independent — a fresh guard and a unique id per case — but they all drove one dlopen'd
        // library, whose own ImageCache is shared mutable state, so the batch had to be serial and
        // took 110 s of a 154 s class. A copy per worker removes the sharing rather than hoping the
        // plugin is thread-safe. Round-robin, not contiguous chunks, so every worker gets a mix of
        // fixture families and one slow format cannot land entirely on one of them.
        let workerCount = min(max(2, ProcessInfo.processInfo.activeProcessorCount / 3), 6)
        var libs: [PluginLibrary] = []
        for _ in 0..<workerCount { libs.append(try openPluginCopy()) }
        var currents = [String](repeating: "(none)", count: workerCount)
        let group = DispatchGroup()

        for worker in 0..<workerCount {
            DispatchQueue.global().async(group: group) { [lib = libs[worker]] in
            for (label, path, buried) in cases.enumerated()
                .filter({ $0.offset % workerCount == worker }).map({ $0.element }) {
                progress.lock(); currents[worker] = label; progress.unlock()
                // A fresh guard and a unique id per case: shared state here would let
                // the first crash quarantine the plugin and make every later case pass
                // by never running.
                let archive = PCXArchive(library: lib, pluginID: "fuzz-\(label)", guard: PluginGuard())
                do {
                    let entries = try archive.list(archivePath: path)
                    progress.lock()
                    reachedParser += 1
                    if buried { reachedParserBuried += 1 }
                    progress.unlock()
                    for entry in entries {
                        if entry.path.hasPrefix("/") || entry.path.split(separator: "/",
                                                                        omittingEmptySubsequences: false)
                            .contains("..") {
                            progress.lock(); unsafePaths.append((label, entry.path)); progress.unlock()
                        }
                    }
                } catch PCXArchive.PCXError.crashed {
                    progress.lock(); crashed.append(label); progress.unlock()
                } catch PCXArchive.PCXError.openFailed(let code) where code == Int(PC_E_UNKNOWN_FMT) {
                    // Turned away at the magic check — the mutation broke the header
                    // before any parser saw it. Correct, but it tests nothing.
                } catch {
                    // Reached a parser and was rejected there, which is the outcome a
                    // damaged image should get.
                    progress.lock()
                    reachedParser += 1
                    if buried { reachedParserBuried += 1 }
                    progress.unlock()
                }
            }
            }
        }

        // Raised from 120s when the header sweep roughly quadrupled the case count. It
        // bounds the whole batch, not one case, so it is a hang detector with slack —
        // not a performance budget. Left where it was rather than lowered with the
        // workers: a budget that tracks the machine turns a hang detector into a flake.
        let deadline = DispatchTime.now() + .seconds(300)
        if group.wait(timeout: deadline) == .timedOut {
            progress.lock(); let stuck = currents; progress.unlock()
            return XCTFail("a mutated image did not finish parsing in time — workers were on "
                           + stuck.joined(separator: ", "))
        }

        XCTAssertEqual(crashed, [], "these mutated images crashed the plugin")
        for (label, path) in unsafePaths {
            assertPathIsSafe(path, case: label)
        }
        XCTAssertEqual(unsafePaths.count, 0, "mutated images produced paths that escape the archive root")

        // Without this the whole test is theatre: if every mutation were turned away
        // at the magic check, nothing past `probe` would ever run and the gate would
        // stay green through any defect in any parser.
        XCTAssertGreaterThan(reachedParser, cases.count / 2,
                             "only \(reachedParser) of \(cases.count) mutations got past the magic "
                             + "check — the corpus is not reaching the parsers")
        XCTAssertGreaterThan(reachedParserBuried, 0,
                             "no buried mutation was found by scanning — the corpus is back to "
                             + "testing only what a driver claims at byte 0, which is how two "
                             + "overflow crashes got through")
    }

    /// Even an intact image must never produce a path the host would resolve outside
    /// the archive. `PCXArchiveFS` splits paths on "/" and filters nothing, so this is
    /// the plugin's responsibility and nobody else's.
    func testEveryFixtureProducesOnlySafePaths() throws {
        var images: [(String, String)] = []
        for name in ["cramfs-le.img", "jffs2-le.img", "btrfs.img", "btrfs-rich.img"] {
            if let path = try? goldenFixture(name) { images.append((name, path)) }
        }
        if let path = try? makeSquashFSImage() { images.append(("squashfs", path)) }
        if let path = try? makeExtImage() { images.append(("ext4", path)) }
        if let path = try? makeCpioImage() { images.append(("cpio", path)) }
        try XCTSkipIf(images.isEmpty, "no fixtures available")

        for (name, path) in images {
            for entry in try PCXArchive(library: lib).list(archivePath: path) {
                assertPathIsSafe(entry.path, case: name)
            }
        }
    }

    // MARK: - Refusals
    //
    // The plugin claims broad extensions (.img, .bin), so being handed something
    // that is not an image is the normal case, not the exceptional one. It has to
    // decline in a way the host can fall back from.

    func testAForeignFileIsDeclinedRatherThanMisread() throws {
        let notAnImage = dir.appendingPathComponent("firmware.bin")
        try Data(repeating: 0x42, count: 8192).write(to: notAnImage)
        XCTAssertNil(PCXArchiveFS(archivePath: notAnImage.path, library: lib, fsID: "fsimage:foreign"),
                     "a file no driver recognises must not mount")
        XCTAssertEqual(PCXArchive(library: lib).canHandle(fileName: notAnImage.path), false)
    }

    func testAnEmptyFileIsDeclined() throws {
        let empty = dir.appendingPathComponent("empty.img")
        try Data().write(to: empty)
        XCTAssertNil(PCXArchiveFS(archivePath: empty.path, library: lib, fsID: "fsimage:zero"))
    }

    func testATruncatedImageFailsInsteadOfReportingAPartialTree() throws {
        let image = try makeCpioImage()
        let full = try Data(contentsOf: URL(fileURLWithPath: image))
        // Cut mid-way through the payload: the first headers parse, then a header
        // promises bytes that are not there.
        let truncated = dir.appendingPathComponent("truncated.cpio")
        try full.prefix(full.count / 2).write(to: truncated)
        XCTAssertThrowsError(try PCXArchive(library: lib).list(archivePath: truncated.path),
                             "a truncated image must fail, not list what happened to survive")
    }

    /// Truncated so that a header's magic is present but the 110-byte header is not.
    ///
    /// This exact shape hung the parser: "no magic here" and "magic here, header cut
    /// off" both came back as "not a header", so the scan looked for the next header
    /// at the offset it had just rejected and never moved. The image that provokes it
    /// is the one an interrupted download produces, so it is not a contrived input.
    func testAHeaderCutOffMidwayFailsRatherThanSpinning() throws {
        let image = try makeCpioImage()
        let full = try Data(contentsOf: URL(fileURLWithPath: image))
        let magic = Data("070701".utf8)
        guard let lastHeader = full.range(of: magic, options: .backwards) else {
            return XCTFail("fixture has no newc header to cut")
        }
        let cut = dir.appendingPathComponent("cut-header.cpio")
        try full.prefix(lastHeader.lowerBound + magic.count).write(to: cut)

        let expectation = expectation(description: "parse returns instead of spinning")
        DispatchQueue.global().async {
            _ = try? PCXArchive(library: self.lib).list(archivePath: cut.path)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
        XCTAssertThrowsError(try PCXArchive(library: lib).list(archivePath: cut.path))
    }

    /// Cut exactly at an entry boundary: every record that is present parses cleanly,
    /// and the only thing missing is the TRAILER!!! that says the archive ended.
    ///
    /// The tempting behaviour is to list what was found. It is also the worst one
    /// available: someone auditing firmware would see a complete-looking tree and
    /// conclude a file is not in the image when it is only unread. So a missing
    /// trailer is a failure, not a short listing.
    func testAnArchiveWithNoTrailerIsRefusedRatherThanListedShort() throws {
        let image = try makeCpioImage()
        let full = try Data(contentsOf: URL(fileURLWithPath: image))
        guard let lastHeader = full.range(of: Data("070701".utf8), options: .backwards) else {
            return XCTFail("fixture has no newc header to cut")
        }
        let cut = dir.appendingPathComponent("no-trailer.cpio")
        try full.prefix(lastHeader.lowerBound).write(to: cut)
        XCTAssertThrowsError(try PCXArchive(library: lib).list(archivePath: cut.path),
                             "an archive with no trailer must not list a partial tree as if it were whole")
    }

    /// Boot images staple several cpio archives together — CPU microcode first, then
    /// the real initramfs. Stopping at the first trailer would show the user the
    /// microcode blob and hide the filesystem they opened the file for.
    func testConcatenatedArchivesAreAllListed() async throws {
        let first = try makeCpioImage()
        let second = try makeCpioImage()
        let combined = dir.appendingPathComponent("combined.cpio")
        var bytes = try Data(contentsOf: URL(fileURLWithPath: first))
        bytes.append(try Data(contentsOf: URL(fileURLWithPath: second)))
        try bytes.write(to: combined)

        let entries = try PCXArchive(library: lib).list(archivePath: combined.path)
        let names = Set(entries.map(\.path))
        XCTAssertTrue(names.contains("etc/motd"), "entries from the trailing archive must be listed too")
        // Per archive: the sample files, the directories, the symlink and big.dat.
        let perArchive = ExpectedTree.files.count + ExpectedTree.directories.count + 2
        XCTAssertEqual(entries.count, 2 * perArchive, "both archives' entries should be present")
    }

    /// The plugin must both *offer* content detection and answer correctly, because the
    /// host consults `CanYouHandleThisFile` only for plugins advertising
    /// PC_CAP_BY_CONTENT — reading a header off every unmatched file is a cost a plugin
    /// has to ask for rather than have applied on its behalf.
    func testContentDetectionIsAdvertisedAndAnswersForExtensionlessImages() throws {
        let archive = PCXArchive(library: lib)
        XCTAssertTrue(archive.detectsByContent,
                      "without PC_CAP_BY_CONTENT the host never asks, and an image named "
                      + "`firmware` or `dump` can never be recognised")

        // No extension at all — the case an association list cannot reach by design.
        let image = try makeSquashFSImage()
        let extensionless = dir.appendingPathComponent("dump")
        try FileManager.default.copyItem(atPath: image, toPath: extensionless.path)
        XCTAssertEqual(archive.canHandle(fileName: extensionless.path), true)
        XCTAssertNotNil(PCXArchiveFS(archivePath: extensionless.path, library: lib, fsID: "fsimage:noext"),
                        "what canHandle claims must be what actually opens")

        // And the other direction, which is what keeps the probe from turning Enter on an
        // ordinary file into something else: a non-image must be declined.
        let text = dir.appendingPathComponent("notes.txt")
        try Data("just text\n".utf8).write(to: text)
        XCTAssertEqual(archive.canHandle(fileName: text.path), false)
    }

    func testContentDetectionAgreesWithWhatWillActuallyOpen() throws {
        let image = try makeCpioImage()
        XCTAssertEqual(PCXArchive(library: lib).canHandle(fileName: image), true)
    }

    // MARK: - The parse cache
    //
    // The host reopens the archive for every single file it reads
    // (`PCXArchive.extract`), so without a cache in the plugin a tree copy is
    // quadratic in parse work. This asserts the behaviour that makes it linear.

    func testRepeatedExtractionDoesNotReparseTheImageEachTime() throws {
        let image = try makeCpioImage()
        let archive = PCXArchive(library: lib)
        let destination = dir.appendingPathComponent("out.txt").path

        let first = Date()
        try archive.extract(archivePath: image, entryPath: "etc/motd", to: destination)
        let cold = Date().timeIntervalSince(first)

        let second = Date()
        for _ in 0..<50 {
            try archive.extract(archivePath: image, entryPath: "etc/motd", to: destination)
        }
        let warmAverage = Date().timeIntervalSince(second) / 50

        // A generous bound: the claim is "reopening is not a full reparse", not a
        // specific speed. Timing on a shared CI machine is noisy, so this fails only
        // on the behaviour actually being wrong.
        XCTAssertLessThan(warmAverage, max(cold, 0.001) * 5,
                          "reopening the image should not cost a fresh parse each time")
    }

    // MARK: - Carving: an image with no table and no filesystem at the front
    //
    // Everything above is handed a starting offset by something that knows one. These
    // cases are the ones where nothing does: a firmware file straight off a router,
    // which is a vendor header, a bootloader, a kernel and a rootfs concatenated at
    // offsets recorded nowhere. The plugin has to find them by looking.
    //
    // The risk this whole area carries is false positives — a four-byte pattern occurs
    // in compressed data constantly — so two of these tests are about *not* finding
    // things, and they matter more than the ones about finding them.

    /// A router firmware image, assembled the way a vendor's build does.
    ///
    /// Built at run time rather than committed because the only part that has to be
    /// authentic is the SquashFS, and `mksquashfs` writes that — the headers around it
    /// are a few dozen bytes of documented layout. Committing it would add 200 KB to
    /// the repository to store bytes this function states more clearly.
    ///
    /// Returns where each part landed, so the tests assert against the real offsets
    /// rather than against numbers copied into an expectation.
    private struct RouterFirmware {
        let path: String
        let kernelOffset: Int64
        let kernelPayload: Data
        let squashfsOffset: Int64
    }

    /// `kernelName` is raw bytes rather than a string so a test can put something in the
    /// uImage name field that is not text — which a header found at a chance offset
    /// always has, and a real image with a broken build script sometimes does.
    private func makeRouterFirmware(kernelName: [UInt8] = Array("Linux-6.1.0-test".utf8))
        throws -> RouterFirmware {
        let rootfs = try Data(contentsOf: URL(fileURLWithPath: try makeSquashFSImage()))
        var image = Data()

        // A vendor container header that declares its own length — 64 bytes, so the
        // header is one region and the bootloader behind it is another.
        image.append(contentsOf: Array("HDR0".utf8))
        image.append(contentsOf: withUnsafeBytes(of: UInt32(64).littleEndian, Array.init))
        image.append(Data(repeating: 0, count: 56))

        // The bootloader: bytes that cannot accidentally carry any signature the scan
        // looks for. Cycling 0…127 contains no 0xAA, so not even FAT's two-byte boot
        // signature can appear here — which is what makes a hit in this test meaningful.
        image.append(Data((0..<(192 * 1024)).map { UInt8($0 % 128) }))

        // A U-Boot legacy image. Every field is big-endian by definition of the format,
        // whatever the target's own byte order is.
        let kernelOffset = Int64(image.count)
        let payload = Data((0..<(128 * 1024)).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })
        var header = Data()
        header.append(contentsOf: [0x27, 0x05, 0x19, 0x56])                     // magic
        header.append(Data(repeating: 0, count: 8))                             // hcrc, time
        header.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).bigEndian, Array.init))
        header.append(Data(repeating: 0, count: 12))                            // load, ep, dcrc
        header.append(contentsOf: [0x05, 0x02, 0x02, 0x01])                     // os, arch, KERNEL, gzip
        var name = Array(kernelName.prefix(32))
        name.append(contentsOf: [UInt8](repeating: 0, count: 32 - name.count))
        header.append(contentsOf: name)
        XCTAssertEqual(header.count, 64, "a uImage header is 64 bytes by definition")
        image.append(header)
        image.append(payload)

        // Three bytes of slack, so the rootfs starts at an offset that is not aligned to
        // anything. A scan that quietly assumed sector alignment would miss it, and real
        // firmware does put filesystems at arbitrary offsets.
        image.append(Data(repeating: 0xFF, count: 3))
        let squashfsOffset = Int64(image.count)
        image.append(rootfs)

        let path = dir.appendingPathComponent("firmware-\(UUID().uuidString).bin").path
        try image.write(to: URL(fileURLWithPath: path))
        return RouterFirmware(path: path, kernelOffset: kernelOffset, kernelPayload: payload,
                              squashfsOffset: squashfsOffset)
    }

    /// The case the whole feature exists for: no partition table, no filesystem at byte
    /// zero, and a rootfs two megabytes in that used to make the plugin decline the file.
    func testFirmwareWithNoPartitionTableIsCarvedIntoItsParts() async throws {
        let firmware = try makeRouterFirmware()
        guard let fs = PCXArchiveFS(archivePath: firmware.path, library: lib,
                                    fsID: "fsimage:carve") else {
            return XCTFail("a firmware image with an embedded rootfs must mount")
        }
        let root = try await collect(fs, "/")
        let names = root.map(\.name)

        XCTAssertTrue(names.contains("0x00000000-firmware.trx"),
                      "the vendor header should be named, not left as unknown data: \(names)")
        XCTAssertTrue(names.contains(String(format: "0x%08llx-kernel.uimage", firmware.kernelOffset)),
                      "the kernel should be found at its real offset: \(names)")

        let rootfsName = String(format: "0x%08llx-squashfs", firmware.squashfsOffset)
        guard let rootfs = root.first(where: { $0.name == rootfsName }) else {
            return XCTFail("the rootfs was not carved out: \(names)")
        }
        XCTAssertEqual(rootfs.kind, .directory, "a carved filesystem is a directory to walk into")

        // And it is genuinely browsable, not merely named.
        let inside = try await collect(fs, "/\(rootfsName)")
        XCTAssertEqual(Set(inside.map(\.name)), ["bin", "etc"])
        let motd = try await read(fs, "/\(rootfsName)/etc/motd")
        XCTAssertEqual(motd, Data(ExpectedTree.files["etc/motd"]!.utf8))
    }

    /// The bootloader and the kernel cannot be browsed, so being able to copy them out
    /// is the entire value of listing them. Byte-exact, because a region reported with
    /// the right length and the wrong contents is the failure mode this plugin keeps
    /// producing when an offset is off by a header.
    func testACarvedKernelBlobExtractsByteForByte() async throws {
        let firmware = try makeRouterFirmware()
        guard let fs = PCXArchiveFS(archivePath: firmware.path, library: lib,
                                    fsID: "fsimage:blob") else {
            return XCTFail("the firmware image must mount")
        }
        let name = String(format: "0x%08llx-kernel.uimage", firmware.kernelOffset)
        let extracted = try await read(fs, "/\(name)")
        XCTAssertEqual(extracted.count, 64 + firmware.kernelPayload.count,
                       "the uImage header declares its payload size, so the extent is exact")
        XCTAssertEqual(extracted.suffix(firmware.kernelPayload.count), firmware.kernelPayload,
                       "the payload must come back exactly as it went in")
    }

    /// A file that is not an image must still be declined, even though the carving
    /// driver's probe accepts everything.
    ///
    /// This is the guard that keeps the plugin from claiming every `.bin` on the system:
    /// the decision moved out of `probe` and into the initialiser, which refuses when the
    /// scan found no filesystem. If that refusal ever stops working, the symptom is not a
    /// crash — it is every unrecognised file in every panel opening as a folder holding
    /// one meaningless entry.
    func testAFileWithNoFilesystemInItIsStillDeclined() throws {
        var noise = Data((0..<200_000).map { UInt8(truncatingIfNeeded: $0 &* 2_654_435_761 >> 11) })
        // Plant the SquashFS magic in the middle of it. The pattern search will find it;
        // opening a filesystem there is what has to fail.
        noise.replaceSubrange(100_000..<100_004, with: Array("hsqs".utf8))
        let path = dir.appendingPathComponent("noise.bin")
        try noise.write(to: path)

        XCTAssertNil(PCXArchiveFS(archivePath: path.path, library: lib, fsID: "fsimage:noise"),
                     "a pattern match is not a filesystem — opening it is what decides")
        XCTAssertEqual(PCXArchive(library: lib).canHandle(fileName: path.path), false)
    }

    /// The same claim from the other side: a real image with a planted magic must report
    /// the one filesystem it has, not two.
    func testAPlantedMagicDoesNotBecomeASecondFilesystem() async throws {
        let firmware = try makeRouterFirmware()
        var bytes = try Data(contentsOf: URL(fileURLWithPath: firmware.path))
        // Inside the bootloader region, where nothing real lives.
        bytes.replaceSubrange(70_000..<70_004, with: Array("hsqs".utf8))
        let path = dir.appendingPathComponent("planted.bin")
        try bytes.write(to: path)

        guard let fs = PCXArchiveFS(archivePath: path.path, library: lib,
                                    fsID: "fsimage:planted") else {
            return XCTFail("the image still contains a real rootfs and must mount")
        }
        let directories = try await collect(fs, "/").filter { $0.kind == .directory }
        XCTAssertEqual(directories.count, 1,
                       "exactly one filesystem: \(directories.map(\.name))")
    }

    /// The bootloader on an embedded device lives outside every partition. Listing only
    /// the partitions says an image plainly containing one does not, which is the wrong
    /// answer about the hardware.
    func testUnallocatedSpaceInAPartitionedImageIsListed() async throws {
        let image = try goldenFixture("disk-mbr.img")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib,
                                    fsID: "fsimage:gaps") else {
            return XCTFail("the host could not mount the partitioned image")
        }
        let root = try await collect(fs, "/")
        let gaps = root.filter { $0.kind != .directory }
        XCTAssertFalse(gaps.isEmpty, "the megabyte ahead of partition 1 must be reachable")
        XCTAssertTrue(gaps.contains { $0.name == "0x00000000-unknown.bin" },
                      "the run before the first partition, named by its offset: \(root.map(\.name))")

        // And it is the real bytes, not a placeholder: the first sector is the MBR, so
        // the run has to start with the partition table's own boot signature.
        guard let first = gaps.first(where: { $0.name == "0x00000000-unknown.bin" }) else { return }
        let data = try await read(fs, "/\(first.name)")
        XCTAssertEqual(data.count, 1 << 20, "one megabyte before the first partition")
        XCTAssertEqual([data[510], data[511]], [0x55, 0xAA], "the MBR signature is in there")
    }

    /// A gap smaller than the threshold is not listed. Every partitioned image has a few
    /// — the table's own sector, alignment slack — and reporting them would bury the one
    /// gap that means something under two that never do.
    func testStructuralSlackIsNotReportedAsAnUnallocatedRegion() async throws {
        let image = try goldenFixture("disk-gpt.img")
        guard let fs = PCXArchiveFS(archivePath: image, library: lib,
                                    fsID: "fsimage:slack") else {
            return XCTFail("the host could not mount the GPT image")
        }
        let blobs = try await collect(fs, "/").filter { $0.kind != .directory }
        XCTAssertFalse(blobs.contains { $0.size < 64 << 10 },
                       "nothing under the threshold should appear: \(blobs.map { "\($0.name)=\($0.size)" })")
    }

    // MARK: - Carving: hostile arithmetic
    //
    // The scan asks a driver for its `byteLength` straight after a magic match, before
    // anything has validated the superblock. Every field it reads at that moment is
    // whatever the file says, and `*` on Int64 traps rather than wrapping — so a number
    // in a header is a way to crash the process, not merely to get a wrong answer.
    // Both of these took the plugin down with SIGTRAP before `scaledLength` existed.

    /// An ext superblock claiming `Int64.max` blocks of 1 KB.
    func testACraftedBlockCountCannotCrashTheScan() throws {
        var image = Data((0..<65536).map { UInt8($0 % 251) })
        let superblock = 2048 + 1024        // a filesystem at 2048, so only carving finds it
        func put32(_ value: UInt32, at offset: Int) {
            withUnsafeBytes(of: value.littleEndian) { image.replaceSubrange(offset..<(offset + 4), with: $0) }
        }
        put32(0xFFFF_FFFF, at: superblock + 4)      // s_blocks_count_lo
        put32(0, at: superblock + 24)               // 1 KB blocks
        put32(0x0000_EF53, at: superblock + 56)     // magic (low half of the word)
        put32(1, at: superblock + 76)               // s_rev_level
        put32(0x0080, at: superblock + 96)          // INCOMPAT_64BIT
        put32(0x7FFF_FFFF, at: superblock + 336)    // s_blocks_count_hi

        let path = dir.appendingPathComponent("ext-overflow.img")
        try image.write(to: path)
        XCTAssertNil(PCXArchiveFS(archivePath: path.path, library: lib, fsID: "fsimage:extmax"),
                     "an impossible block count is refused, not multiplied")
    }

    /// An NTFS boot sector claiming `Int64.max` sectors of 512 bytes.
    func testACraftedSectorCountCannotCrashTheScan() throws {
        var image = Data((0..<65536).map { UInt8($0 % 251) })
        let boot = 4096
        image.replaceSubrange((boot + 3)..<(boot + 11), with: Array("NTFS    ".utf8))
        withUnsafeBytes(of: UInt16(512).littleEndian) {
            image.replaceSubrange((boot + 11)..<(boot + 13), with: $0)
        }
        image[boot + 13] = 8
        withUnsafeBytes(of: UInt64(0x7FFF_FFFF_FFFF_FFFE).littleEndian) {
            image.replaceSubrange((boot + 40)..<(boot + 48), with: $0)
        }

        let path = dir.appendingPathComponent("ntfs-overflow.img")
        try image.write(to: path)
        XCTAssertNil(PCXArchiveFS(archivePath: path.path, library: lib, fsID: "fsimage:ntfsmax"),
                     "an impossible sector count is refused, not multiplied")
    }

    /// A run of unallocated space larger than the ceiling is listed, not searched.
    ///
    /// The bound exists because a whole-drive dump is mostly one such run: searching it
    /// froze the panel for as long as the disk was large, where before this feature the
    /// image opened at once. Asserted by behaviour rather than by a stopwatch — a header
    /// planted deep inside the run must *not* be split out — because a timing assertion
    /// on a shared machine fails for reasons that have nothing to do with the rule.
    func testAnOversizedUnallocatedRunIsListedButNotSearched() async throws {
        let path = dir.appendingPathComponent("bigdisk.img")
        FileManager.default.createFile(atPath: path.path, contents: nil)
        let handle = try FileHandle(forWritingTo: path)
        defer { try? handle.close() }

        var mbr = Data(repeating: 0, count: 512)
        withUnsafeBytes(of: UInt32(2048).littleEndian) { mbr.replaceSubrange(454..<458, with: $0) }
        withUnsafeBytes(of: UInt32(2048).littleEndian) { mbr.replaceSubrange(458..<462, with: $0) }
        mbr[450] = 0x83
        mbr[510] = 0x55; mbr[511] = 0xAA
        try handle.write(contentsOf: mbr)
        // Sparse: 700 MB of hole, past the 512 MB ceiling, costing no disk.
        try handle.truncate(atOffset: 700 << 20)
        // A U-Boot header 600 MB in — inside the oversized run, and findable only if the
        // run were searched.
        try handle.seek(toOffset: 600 << 20)
        try handle.write(contentsOf: Data([0x27, 0x05, 0x19, 0x56] + [UInt8](repeating: 0, count: 60)))
        try handle.close()

        guard let fs = PCXArchiveFS(archivePath: path.path, library: lib,
                                    fsID: "fsimage:bigdisk") else {
            return XCTFail("a partitioned image must still mount")
        }
        let names = try await collect(fs, "/").map(\.name)
        XCTAssertFalse(names.contains { $0.hasSuffix("uimage") },
                       "the oversized run must not be searched for headers: \(names)")
        XCTAssertTrue(names.contains { $0.hasSuffix("unknown.bin") },
                      "but it must still be listed and extractable: \(names)")
    }

    // MARK: - The layout report

    /// The contributed Commands entry, driven the way the host drives it.
    ///
    /// Worth testing through `PcRunCommand` rather than by calling the report builder
    /// directly: what can break here is not the table formatting but the wiring around it
    /// — which host service the path comes from, where the file is written, whether the
    /// panel is told about it. None of that is reachable from a unit test of the
    /// formatter, and all of it is what the user experiences as "the menu item did
    /// nothing".
    func testTheLayoutReportNamesEveryRegionAndIsRevealed() throws {
        let firmware = try makeRouterFirmware()
        revealedPath = nil
        presentedMessage = nil
        fakeCursorPath = firmware.path

        try runLayoutCommand()

        XCTAssertNil(presentedMessage, "a readable image should produce a report, not a dialog")
        guard let reportPath = revealedPath else {
            return XCTFail("the command must reveal the report it wrote")
        }
        XCTAssertEqual((reportPath as NSString).lastPathComponent,
                       (firmware.path as NSString).lastPathComponent + ".layout.txt",
                       "the report belongs beside the image it describes")
        let report = try String(contentsOfFile: reportPath, encoding: .utf8)

        XCTAssertTrue(report.contains("squashfs"), "the rootfs must be in the report:\n\(report)")
        XCTAssertTrue(report.contains("kernel.uimage"), "and the kernel:\n\(report)")
        XCTAssertTrue(report.contains("Linux-6.1.0-test"),
                      "the uImage name is the one human-written string in the image:\n\(report)")
        XCTAssertTrue(report.contains(String(format: "0x%08llx", firmware.squashfsOffset)),
                      "offsets must be exact, in the same form the panel uses:\n\(report)")
        XCTAssertTrue(report.contains("1 filesystem can be opened"),
                      "the summary line should count what was found:\n\(report)")
    }

    /// The report is the one place where bytes out of an image become part of a document
    /// somebody keeps and pastes elsewhere, so a name field that is not text must not
    /// reach it.
    ///
    /// Found by reading a report rather than by reasoning about the code: a header at a
    /// chance offset has 32 random bytes in its name field, and they came out as a row of
    /// replacement characters in the middle of an otherwise clean table.
    func testAnUnreadableNameFieldDoesNotReachTheReport() throws {
        let firmware = try makeRouterFirmware(kernelName: [0xFF, 0x4E, 0x00, 0x9A, 0xC3, 0x28, 0x01])
        revealedPath = nil
        presentedMessage = nil
        fakeCursorPath = firmware.path

        try runLayoutCommand()

        guard let reportPath = revealedPath else { return XCTFail("no report was written") }
        let report = try String(contentsOfFile: reportPath, encoding: .utf8)
        XCTAssertTrue(report.contains("U-Boot"), "the blob is still identified:\n\(report)")
        XCTAssertFalse(report.contains("\u{FFFD}"),
                       "no replacement characters from a lossy decode:\n\(report)")
        XCTAssertTrue(report.unicodeScalars.allSatisfy { $0.value >= 0x20 || $0 == "\n" },
                      "no control characters anywhere in the report")
    }

    /// With no cursor, the command says so instead of writing an empty report somewhere.
    func testTheLayoutReportExplainsItselfWhenThereIsNoImage() throws {
        revealedPath = nil
        presentedMessage = nil
        fakeCursorPath = ""

        try runLayoutCommand()

        XCTAssertNil(revealedPath, "nothing should be written when there is nothing to scan")
        XCTAssertNotNil(presentedMessage, "the user has to be told why nothing happened")
    }

    // MARK: - Does the listed size match what the file actually holds? (F-413)
    //
    // Asked because a reader reported files listed as 0 bytes that clearly had content. A listing is a
    // promise about the file, and the panel acts on it: the status bar sums it, a copy shows progress
    // against it, "select files larger than" filters on it, and a 0 for a file with content makes every
    // one of those wrong. The conformance battery compares *contents* and asserts that the deliberately
    // empty file is 0 — it never asked whether a non-empty file's size is the truth.
    //
    // So: walk every image in the fixture set, read every file, and hold the listed size against the
    // bytes. One test over all drivers rather than one per driver, because the question is the same for
    // all of them and a driver added later must answer it too.

    /// Every regular file's listed size must equal the number of bytes reading it produces.
    func testListedSizesMatchTheBytesInEveryImage() async throws {
        for name in try Self.everyGoldenImage(self) {
            let image = try goldenFixture(name)
            guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:size-\(name)") else {
                XCTFail("\(name): the host could not mount the image"); continue
            }
            var checked = 0
            var mismatches: [String] = []
            try await walk(fs, "/") { path, entry in
                guard entry.kind == .file else { return }
                let data = try await self.read(fs, path)
                checked += 1
                if Int64(data.count) != entry.size {
                    mismatches.append("\(path): listed \(entry.size), read \(data.count)")
                }
            }
            XCTAssertGreaterThan(checked, 0, "\(name): no files were checked at all")
            XCTAssertEqual(mismatches, [], "\(name): listed size differs from the content")
        }
    }

    /// An initramfs is full of hardlinks — busybox is one binary under thirty names — and `newc` stores
    /// the bytes with the *last* link, writing filesize 0 in the headers of the earlier ones (F-413).
    ///
    /// Reading such a link already worked, because the data is resolved through the inode. Its **size** was
    /// not: the entry kept the 0 from its own header, so the file listed as empty and opened with its full
    /// contents. That is what the panel's status bar sums, what a copy shows progress against and what
    /// "select files larger than" filters on. Both directions are built here, because the fix has two
    /// branches: the twin that comes *after* the link (resolved at the end of the parse) and the one that
    /// came *before* it (resolved on the spot).
    func testHardlinkedFilesInACpioImageAreListedWithTheirRealSize() async throws {
        let cpio = "/usr/bin/cpio"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: cpio), "cpio unavailable")
        let root = dir.appendingPathComponent("linkroot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let payload = "busybox pretends to be many programs\n"
        let real = root.appendingPathComponent("bin-busybox")
        try payload.write(to: real, atomically: true, encoding: .utf8)
        // Two more names for the same inode. `find` walks them in name order, so `aa-first` is listed
        // before the data-carrying entry and `zz-last` after it.
        for name in ["aa-first", "zz-last"] {
            try FileManager.default.linkItem(at: real, to: root.appendingPathComponent(name))
        }

        let image = dir.appendingPathComponent("links-\(UUID().uuidString).cpio").path
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "cd \(root.path) && find . | \(cpio) -o -H newc > \(image)"]
        shell.standardError = FileHandle.nullDevice
        try shell.run(); shell.waitUntilExit()
        try XCTSkipUnless(shell.terminationStatus == 0, "cpio failed")

        guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:links") else {
            return XCTFail("the host could not mount the image")
        }
        let expected = Int64(payload.utf8.count)
        let entries = try await collect(fs, "/").filter { $0.kind == .file }
        XCTAssertEqual(entries.count, 3, "all three names are files")
        for entry in entries {
            XCTAssertEqual(entry.size, expected, "\(entry.name): listed size")
            let data = try await read(fs, "/" + entry.name)
            XCTAssertEqual(String(decoding: data, as: UTF8.self), payload, "\(entry.name): contents")
        }
    }

    /// The same question for the images that are *built* here rather than committed — ext above all, the
    /// filesystem the report named, plus the SquashFS variants and a cpio archive. Skipped where the
    /// builder is not installed, which is why it cannot replace the golden sweep above.
    func testListedSizesMatchTheBytesInBuiltImages() async throws {
        var images: [(String, String)] = []
        // Small files with `inline_data` have no blocks at all — their content sits where the block
        // pointers would be. If a size were going to be reported as 0 for a file that has content, this is
        // the shape it would happen in.
        for (label, make) in [
            ("ext4", { try self.makeExtImage(type: "ext4") }),
            ("ext3-1k", { try self.makeExtImage(type: "ext3", blockSize: 1024) }),
            ("ext2", { try self.makeExtImage(type: "ext2") }),
            ("ext4-inline", { try self.makeExtImage(type: "ext4", features: "inline_data", inodeSize: 256) }),
            ("squashfs-gzip", { try self.makeSquashFSImage(compressor: "gzip") }),
            ("squashfs-zstd", { try self.makeSquashFSImage(compressor: "zstd") }),
            ("cpio", { try self.makeCpioImage() }),
        ] as [(String, () throws -> String)] {
            do { images.append((label, try make())) }
            catch { continue }   // builder missing here; the golden sweep still ran
        }
        try XCTSkipIf(images.isEmpty, "no image builder available on this machine")

        for (label, image) in images {
            guard let fs = PCXArchiveFS(archivePath: image, library: lib, fsID: "fsimage:size-\(label)") else {
                XCTFail("\(label): the host could not mount the image"); continue
            }
            var checked = 0
            var mismatches: [String] = []
            try await walk(fs, "/") { path, entry in
                guard entry.kind == .file else { return }
                let data = try await self.read(fs, path)
                checked += 1
                if Int64(data.count) != entry.size {
                    mismatches.append("\(path): listed \(entry.size), read \(data.count)")
                }
            }
            XCTAssertGreaterThan(checked, 0, "\(label): no files were checked at all")
            XCTAssertEqual(mismatches, [], "\(label): listed size differs from the content")
        }
    }

    /// The images the manifest describes, as the fixture names the tests use.
    private static func everyGoldenImage(_ test: FSImagePluginTests) throws -> [String] {
        try test.manifestRows().map(\.name)
    }

    /// Depth-first walk over an image, calling `visit` for every entry.
    ///
    /// Bounded: a fixture is small, but a walk that follows a driver's own loop — a directory that lists
    /// itself — would never end, and that is exactly the sort of defect these images exist to catch.
    private func walk(_ fs: PCXArchiveFS, _ path: String, depth: Int = 0,
                     visit: (String, VFSEntry) async throws -> Void) async throws {
        guard depth < 16 else { return }
        for entry in try await collect(fs, path) {
            let child = path == "/" ? "/" + entry.name : path + "/" + entry.name
            try await visit(child, entry)
            if entry.kind == .directory {
                try await walk(fs, child, depth: depth + 1, visit: visit)
            }
        }
    }

    /// Invoke the contributed command with a fake host table.
    private func runLayoutCommand() throws {
        typealias RunCommand = @convention(c) (UnsafePointer<CChar>?,
                                              UnsafePointer<PcHostServices>?) -> Void
        guard let symbol = lib.symbol("PcRunCommand") else {
            return XCTFail("the plugin does not export PcRunCommand")
        }
        var services = PcHostServices()
        services.localCursorPath = fakeCursorPathCallback
        services.cursorPath = fakeCursorPathCallback
        services.openPath = fakeOpenPath
        services.presentInfo = fakePresentInfo

        withUnsafePointer(to: &services) { table in
            "plugin.fsimage.layout".withCString { id in
                unsafeBitCast(symbol, to: RunCommand.self)(id, table)
            }
        }
    }
}
