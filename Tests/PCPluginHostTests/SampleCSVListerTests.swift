// SPDX-License-Identifier: Apache-2.0
// SampleCSVListerTests.swift - Drive the Swift SampleCSVLister PLX plugin
// (Plugins/SampleCSVLister/sample_csv_lister.swift) through the PLX adapter.
//
// This plugin returns a real NSView, so it verifies the on-macOS ListLoad contract
// the Lister UI relies on (a non-null NSView* handle), plus detect dispatch, search,
// and close — headlessly, without the GUI.

import XCTest
@testable import PCPluginHost

final class SampleCSVListerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("samplecsv-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func buildPlugin() throws -> PluginLibrary? {
        let swiftc = "/usr/bin/swiftc"
        guard FileManager.default.isExecutableFile(atPath: swiftc) else { return nil }
        let src = repoRoot.appendingPathComponent("Plugins/SampleCSVLister/sample_csv_lister.swift")
        let out = dir.appendingPathComponent("libsamplecsv.dylib")
        #if arch(arm64)
        let target = "arm64-apple-macos13.0"
        #else
        let target = "x86_64-apple-macos13.0"
        #endif
        let p = Process()
        p.executableURL = URL(fileURLWithPath: swiftc)
        p.arguments = ["-emit-library", "-module-name", "SampleCSVLister", "-target", target,
                       "-framework", "AppKit", "-o", out.path, src.path]
        let pipe = Pipe(); p.standardError = pipe
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let e = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("swiftc failed: \(e)"); return nil
        }
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PLXSymbols.required, optional: PLXSymbols.optional) else {
            XCTFail("open failed"); return nil
        }
        return lib
    }

    private func writeCSV() throws -> String {
        let csv = "name,age,city\nAlice,30,Berlin\nBob,25,Hamburg\nCarol,41,Munich\n"
        let url = dir.appendingPathComponent("people.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    @MainActor
    func testDetectAndLoadReturnsRealView() throws {
        guard let lib = try buildPlugin() else { throw XCTSkip("swiftc unavailable") }
        let lister = PLXLister(library: lib)
        XCTAssertEqual(lister.detectString(), "EXT=\"CSV\" | EXT=\"TSV\"")
        XCTAssertTrue(lister.handles(DetectContext(ext: "csv", size: 10, bytes: [])))
        XCTAssertTrue(lister.handles(DetectContext(ext: "TSV", size: 10, bytes: [])))
        XCTAssertFalse(lister.handles(DetectContext(ext: "png", size: 10, bytes: [])))

        let path = try writeCSV()
        let handle = try XCTUnwrap(lister.load(parent: nil, file: path), "ListLoad should return an NSView*")
        // The contract says the handle is an NSView*; confirm it really is one.
        let view = Unmanaged<NSObject>.fromOpaque(handle).takeUnretainedValue()
        XCTAssertTrue(view is NSView, "plugin must return a real NSView")
        lister.close(handle)
    }

    @MainActor
    func testSearchWithinPluginView() throws {
        guard let lib = try buildPlugin() else { throw XCTSkip("swiftc unavailable") }
        let lister = PLXLister(library: lib)
        let path = try writeCSV()
        let handle = try XCTUnwrap(lister.load(parent: nil, file: path))
        defer { lister.close(handle) }

        XCTAssertTrue(lister.searchText(in: handle, "Hamburg"))
        XCTAssertTrue(lister.searchText(in: handle, "carol"))                       // case-insensitive
        XCTAssertFalse(lister.searchText(in: handle, "carol", options: .matchCase)) // wrong case
        XCTAssertFalse(lister.searchText(in: handle, "Tokyo"))
    }

    @MainActor
    func testLoadRejectsMissingFile() throws {
        guard let lib = try buildPlugin() else { throw XCTSkip("swiftc unavailable") }
        let lister = PLXLister(library: lib)
        XCTAssertNil(lister.load(parent: nil, file: dir.appendingPathComponent("gone.csv").path))
    }

    @MainActor
    func testSemicolonDelimiterAutoDetected() throws {
        guard let lib = try buildPlugin() else { throw XCTSkip("swiftc unavailable") }
        let lister = PLXLister(library: lib)
        // A ';'-separated file: if the delimiter were hard-coded to ',', the whole
        // line would be one cell and a per-field search for "Hamburg" would still
        // match as substring — so search for a value that only isolates correctly
        // when split on ';' is not decisive. Instead verify a cell-exact match via
        // a value that contains a comma inside a field.
        let csv = "name;note;city\nAlice;a,b,c;Berlin\nBob;x;Hamburg\n"
        let url = dir.appendingPathComponent("semi.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        let handle = try XCTUnwrap(lister.load(parent: nil, file: url.path))
        defer { lister.close(handle) }
        // "a,b,c" is a single field only when splitting on ';'.
        XCTAssertTrue(lister.searchText(in: handle, "a,b,c"))
        XCTAssertTrue(lister.searchText(in: handle, "Hamburg"))
    }
}
