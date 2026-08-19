// SPDX-License-Identifier: Apache-2.0
// SampleContentPluginTests.swift - End-to-end run through the real SampleContentPlugin
// C plugin (Plugins/SampleContentPlugin/sample_content.c) via the PDX adapter.

import XCTest
import PCVFS
@testable import PCPluginHost

final class SampleContentPluginTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("samplecontent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func buildSampleContentPlugin() throws -> PluginLibrary? {
        let clang = "/usr/bin/clang"
        guard FileManager.default.isExecutableFile(atPath: clang) else { return nil }
        let src = repoRoot.appendingPathComponent("Plugins/SampleContentPlugin/sample_content.c")
        let sdk = repoRoot.appendingPathComponent("Plugins/SDK")
        let out = dir.appendingPathComponent("libsamplecontent.dylib")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: clang)
        p.arguments = ["-dynamiclib", "-std=c11", "-I", sdk.path, "-o", out.path, src.path]
        let pipe = Pipe(); p.standardError = pipe
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let e = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("clang failed: \(e)"); return nil
        }
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PDXSymbols.required, optional: PDXSymbols.optional) else {
            XCTFail("open failed"); return nil
        }
        return lib
    }

    func testEnumerateSupportedFields() throws {
        guard let lib = try buildSampleContentPlugin() else { throw XCTSkip("clang unavailable") }
        let plugin = PDXPlugin(library: lib)
        let fields = try plugin.supportedFields()
        XCTAssertEqual(fields.map(\.name), ["Size", "Name Length", "Extension", "Tag"])
        XCTAssertEqual(fields[0].kind, .numeric64)
        XCTAssertEqual(fields[0].units, ["bytes"])
        XCTAssertEqual(fields[1].kind, .numeric32)
        XCTAssertEqual(fields[2].kind, .string)
    }

    func testGetTypedValues() throws {
        guard let lib = try buildSampleContentPlugin() else { throw XCTSkip("clang unavailable") }
        let plugin = PDXPlugin(library: lib)
        let file = dir.appendingPathComponent("photo.jpeg")
        try Data("hello world".utf8).write(to: file)   // 11 bytes

        XCTAssertEqual(try plugin.value(fileName: file.path, fieldIndex: 0), .integer(11))          // Size
        XCTAssertEqual(try plugin.value(fileName: file.path, fieldIndex: 1), .integer(10))          // "photo.jpeg".count
        XCTAssertEqual(try plugin.value(fileName: file.path, fieldIndex: 2), .string("jpeg"))       // Extension
        XCTAssertEqual(try plugin.value(fileName: file.path, fieldIndex: 9), .none)                 // out of range
    }

    func testMissingFileReportsNone() throws {
        guard let lib = try buildSampleContentPlugin() else { throw XCTSkip("clang unavailable") }
        let plugin = PDXPlugin(library: lib)
        let absent = dir.appendingPathComponent("does-not-exist.bin")
        XCTAssertEqual(try plugin.value(fileName: absent.path, fieldIndex: 0), .none)   // PC_FT_FILEERROR → .none
    }

    func testBridgeThroughContentFieldRegistry() async throws {
        guard let lib = try buildSampleContentPlugin() else { throw XCTSkip("clang unavailable") }
        let plugin = PDXPlugin(library: lib)
        let provider = try PDXContentProvider(providerName: "sample", plugin: plugin)
        XCTAssertEqual(provider.fields.map(\.id), ["size", "name_length", "extension", "tag"])

        let file = dir.appendingPathComponent("archive.tar.gz")
        try Data(repeating: 0x41, count: 256).write(to: file)

        let registry = ContentFieldRegistry()
        registry.register(provider)
        let size = await registry.value(qualifiedID: "sample.size", forFileAt: file)
        let ext = await registry.value(qualifiedID: "sample.extension", forFileAt: file)
        XCTAssertEqual(size, .integer(256))
        XCTAssertEqual(ext, .string("gz"))

        // Search predicate over the plugin's numeric field, exactly like a built-in provider.
        let matches = await registry.filter([file],
            matching: ContentFieldPredicate(qualifiedID: "sample.size", op: .greater, value: "100"))
        XCTAssertEqual(matches, [file])
    }

    // MARK: - F-234: ContentSetValue + ContentCompareFiles

    func testSetValue_roundTripsThroughGetValue() throws {
        guard let lib = try buildSampleContentPlugin() else { throw XCTSkip("clang unavailable") }
        let plugin = PDXPlugin(library: lib)
        let file = dir.appendingPathComponent("tagged.txt")
        try Data("hi".utf8).write(to: file)

        // Field 3 = "Tag" (writable, xattr-backed). Empty before setting.
        XCTAssertEqual(try plugin.value(fileName: file.path, fieldIndex: 3), .string(""))
        let rc = plugin.setValue(fileName: file.path, fieldIndex: 3, value: .string("important"))
        XCTAssertEqual(rc, 8, "PC_FT_STRING")
        XCTAssertEqual(try plugin.value(fileName: file.path, fieldIndex: 3), .string("important"))

        // The read-only Size field reports "not writable" (PC_FT_NOMOREFIELDS == 0).
        XCTAssertEqual(plugin.setValue(fileName: file.path, fieldIndex: 0, value: .integer(5)), 0)
    }

    func testCompareFiles_bySize() throws {
        guard let lib = try buildSampleContentPlugin() else { throw XCTSkip("clang unavailable") }
        let plugin = PDXPlugin(library: lib)
        let small = dir.appendingPathComponent("small"); try Data(count: 10).write(to: small)
        let big = dir.appendingPathComponent("big"); try Data(count: 99).write(to: big)
        let same = dir.appendingPathComponent("same"); try Data(count: 10).write(to: same)

        // Results: -1 PC_CMP_LESS, 1 PC_CMP_GREATER, 0 PC_CMP_EQUAL.
        XCTAssertEqual(plugin.compareFiles(fieldIndex: 0, file1: small.path, file2: big.path), -1)
        XCTAssertEqual(plugin.compareFiles(fieldIndex: 0, file1: big.path, file2: small.path), 1)
        XCTAssertEqual(plugin.compareFiles(fieldIndex: 0, file1: small.path, file2: same.path), 0)
        // A non-comparable field → nil (PC_CMP_NOTSUPPORTED).
        XCTAssertNil(plugin.compareFiles(fieldIndex: 2, file1: small.path, file2: big.path))
    }

    /// A localized header, without moving the id (F-428). The sample plugin titles field 0 only, so this
    /// covers both paths: the plugin's title where it offers one, the field *name* where it does not.
    func testLocalizedFieldTitleDoesNotChangeTheFieldID() throws {
        guard let lib = try buildSampleContentPlugin() else { throw XCTSkip("clang unavailable") }
        let plugin = PDXPlugin(library: lib)
        let fields = try plugin.supportedFields()

        XCTAssertEqual(fields[0].name, "Size", "the name is the stable part")
        XCTAssertEqual(fields[0].title, "Größe", "and the title is what the header shows")
        XCTAssertNil(fields[1].title, "a field the plugin does not title keeps the name")

        // What the host actually publishes: the id derived from the name either way, the header localized
        // only where there is a title. An id that moved with the language would orphan saved column sets.
        let provider = try PDXContentProvider(providerName: "sample", plugin: plugin)
        let published = provider.fields
        XCTAssertEqual(published[0].id, PDXContentProvider.fieldID("Size"))
        XCTAssertEqual(published[0].title, "Größe")
        XCTAssertEqual(published[1].id, PDXContentProvider.fieldID("Name Length"))
        XCTAssertEqual(published[1].title, "Name Length")
    }
}
