// SampleListerTests.swift - End-to-end run through the real SampleLister C plugin
// (Plugins/SampleLister/sample_lister.c) via the PLX adapter.

import XCTest
@testable import PCPluginHost

final class SampleListerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("samplelister-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func buildSampleLister() throws -> PluginLibrary? {
        let clang = "/usr/bin/clang"
        guard FileManager.default.isExecutableFile(atPath: clang) else { return nil }
        let src = repoRoot.appendingPathComponent("Plugins/SampleLister/sample_lister.c")
        let sdk = repoRoot.appendingPathComponent("Plugins/SDK")
        let out = dir.appendingPathComponent("libsamplelister.dylib")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: clang)
        p.arguments = ["-dynamiclib", "-std=c11", "-I", sdk.path, "-o", out.path, src.path]
        let pipe = Pipe(); p.standardError = pipe
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let e = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("clang failed: \(e)"); return nil
        }
        // Also resolve the test-only live-count helper alongside the PLX symbols.
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PLXSymbols.required,
            optional: PLXSymbols.optional + ["SampleGetLiveCount"]) else {
            XCTFail("open failed"); return nil
        }
        return lib
    }

    private func liveCount(_ lib: PluginLibrary) -> Int {
        guard let ptr = lib.symbol("SampleGetLiveCount") else { return -1 }
        typealias Fn = @convention(c) () -> Int32
        return Int(unsafeBitCast(ptr, to: Fn.self)())
    }

    private func writeFile(_ name: String, _ contents: String) throws -> String {
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    func testDetectStringDispatch() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        XCTAssertEqual(lister.detectString(), "EXT=\"TXT\" | EXT=\"LOG\"")

        let txt = DetectContext(ext: "txt", size: 10, bytes: [])
        let log = DetectContext(ext: "LOG", size: 10, bytes: [])   // case-insensitive
        let png = DetectContext(ext: "png", size: 10, bytes: [])
        XCTAssertTrue(lister.handles(txt))
        XCTAssertTrue(lister.handles(log))
        XCTAssertFalse(lister.handles(png))
    }

    func testLoadSearchAndClose() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        let path = try writeFile("notes.txt", "The quick brown Fox jumps.")

        XCTAssertEqual(liveCount(lib), 0)
        let handle = try XCTUnwrap(lister.load(parent: nil, file: path), "should load a .txt file")
        XCTAssertEqual(liveCount(lib), 1)

        XCTAssertTrue(lister.searchText(in: handle, "brown"))
        XCTAssertTrue(lister.searchText(in: handle, "FOX"))                              // case-insensitive default
        XCTAssertFalse(lister.searchText(in: handle, "fox", options: .matchCase))        // wrong case
        XCTAssertTrue(lister.searchText(in: handle, "Fox", options: .matchCase))
        XCTAssertFalse(lister.searchText(in: handle, "missing"))

        lister.close(handle)
        XCTAssertEqual(liveCount(lib), 0, "close must free the view (balanced lifecycle)")
    }

    func testLoadRejectsMissingFile() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        XCTAssertNil(lister.load(parent: nil, file: dir.appendingPathComponent("nope.txt").path))
        XCTAssertEqual(liveCount(lib), 0)
    }

    func testViewerCyclingWithLoadNext() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        XCTAssertTrue(lister.canLoadNext)
        let first = try writeFile("a.txt", "alpha content")
        let second = try writeFile("b.log", "beta beacon")

        let handle = try XCTUnwrap(lister.load(parent: nil, file: first))
        XCTAssertTrue(lister.searchText(in: handle, "alpha"))
        XCTAssertTrue(lister.loadNext(parent: nil, listWin: handle, file: second))
        XCTAssertFalse(lister.searchText(in: handle, "alpha"), "old content should be gone")
        XCTAssertTrue(lister.searchText(in: handle, "beacon"))
        XCTAssertEqual(liveCount(lib), 1, "cycling reuses the same view, no leak")
        lister.close(handle)
        XCTAssertEqual(liveCount(lib), 0)
    }

    func testSendCommandAndPrint() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        let path = try writeFile("c.txt", "hello")
        let handle = try XCTUnwrap(lister.load(parent: nil, file: path))
        defer { lister.close(handle) }

        XCTAssertTrue(lister.send(.copy, to: handle))
        XCTAssertTrue(lister.send(.selectAll, to: handle))
        XCTAssertTrue(lister.send(.newParams([.wrapText, .darkMode]), to: handle))
        XCTAssertTrue(lister.canPrint)
        XCTAssertTrue(lister.printFile(path, in: handle))
    }

    func testPreviewBitmapReturnsPNG() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        XCTAssertTrue(lister.canPreview)
        let path = try writeFile("d.txt", "hello preview")
        let data = try XCTUnwrap(lister.previewBitmap(file: path, maxWidth: 128, maxHeight: 128))
        XCTAssertEqual(Array(data), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])   // PNG signature
        // Missing file -> no preview.
        XCTAssertNil(lister.previewBitmap(file: dir.appendingPathComponent("gone.txt").path,
                                          maxWidth: 128, maxHeight: 128))
    }
}
