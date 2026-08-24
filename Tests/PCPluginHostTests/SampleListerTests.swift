// SPDX-License-Identifier: Apache-2.0
// SampleListerTests.swift - End-to-end run through the real SampleLister C plugin
// (Plugins/SampleLister/sample_lister.c) via the PLX adapter.

import CContrib
import XCTest
@testable import PCPluginHost

// The additive PLX entry points (ListLoadEx, ListGetOutline, ListGotoAnchor, ListGetText) are
// exercised here against the real C sample rather than a mock, and *before* any shipping plugin
// depends on them — an ABI designed against one caller tends to fit only that caller.

/// What the fake host answers for a context key. Global because a `@convention(c)` function
/// cannot capture; the same pattern PluginThemeTests uses.
private nonisolated(unsafe) var fakeListerContext: [String: String] = [:]

private func fakeListerGetContext(_ host: UnsafeMutableRawPointer?, _ key: UnsafePointer<CChar>?,
                                  _ out: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let key, let out, let v = fakeListerContext[String(cString: key)] else { return 0 }
    _ = strlcpy(out, v, Int(maxlen))
    return 1
}

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
        // Compiled once per test run, copied per test — see CachedPluginBuild.
        let out: URL
        do {
            out = try CachedPluginBuild.freshBuild(key: "samplelister", into: dir) { cache in
                let src = repoRoot.appendingPathComponent("Plugins/SampleLister/sample_lister.c")
                let sdk = repoRoot.appendingPathComponent("Plugins/SDK")
                let out = cache.appendingPathComponent("libsamplelister.dylib")
                let p = Process()
                p.executableURL = URL(fileURLWithPath: clang)
                p.arguments = ["-dynamiclib", "-std=c11", "-I", sdk.path, "-o", out.path, src.path]
                let pipe = Pipe(); p.standardError = pipe
                try p.run(); p.waitUntilExit()
                guard p.terminationStatus == 0 else {
                    let e = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    throw PluginBuildFailure(description: "clang failed: \(e)")
                }
                return out
            }
        } catch let failure as PluginBuildFailure {
            // Recorded per test, as it was when every test compiled its own copy.
            XCTFail(failure.description); return nil
        }
        // Also resolve the test-only live-count helper alongside the PLX symbols.
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PLXSymbols.required,
            optional: PLXSymbols.optional + ["SampleGetLiveCount", "SampleGetScrolledLine",
                                             "SampleGotServices", "SampleGetSurface"]) else {
            XCTFail("open failed"); return nil
        }
        return lib
    }

    /// Resolve a test-only helper the sample exports beside the ABI.
    private func helper<T>(_ lib: PluginLibrary, _ name: String, as: T.Type) -> T? {
        lib.symbol(name).map { unsafeBitCast($0, to: T.self) }
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

    // MARK: - The additive entry points

    func testLoadExDeliversTheHostsContextToThePlugin() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        XCTAssertTrue(lister.takesServices)
        let path = try writeFile("ctx.txt", "body")

        // The one fact ListLoadEx exists to deliver: which of the host's surfaces this is.
        fakeListerContext = ["lister.surface": "preview", "lister.width": "240"]
        var services = PcHostServices()
        services.getContext = fakeListerGetContext
        let handle = try XCTUnwrap(withUnsafePointer(to: &services) { ptr in
            lister.loadEx(parent: nil, file: path, services: UnsafeRawPointer(ptr))
        })
        defer { lister.close(handle) }

        typealias GotFn = @convention(c) (UnsafeMutableRawPointer?) -> Int32
        typealias SurfaceFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafePointer<CChar>?
        XCTAssertEqual(helper(lib, "SampleGotServices", as: GotFn.self)?(handle), 1)
        let surface = helper(lib, "SampleGetSurface", as: SurfaceFn.self)?(handle)
        XCTAssertEqual(surface.map { String(cString: $0) }, "preview",
                       "the plugin must read the surface the host published, not guess it")
    }

    func testLoadExFallsBackToListLoadWhenThePluginHasOnlyThat() throws {
        // The promise that makes the addition additive: nothing breaks for a plugin that never
        // heard of ListLoadEx. Simulated by asking the adapter to load with a nil table, which is
        // also what a host with nothing to offer passes.
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        let path = try writeFile("fallback.txt", "still loads")
        let handle = try XCTUnwrap(lister.loadEx(parent: nil, file: path, services: nil))
        defer { lister.close(handle) }
        XCTAssertEqual(lister.text(of: handle), "still loads")
    }

    func testOutlineIsParsedIntoRows() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        XCTAssertTrue(lister.canOutline)
        let path = try writeFile("out.txt", "# Top\nbody\n## Nested\nmore\n# Second\n")
        let handle = try XCTUnwrap(lister.load(parent: nil, file: path))
        defer { lister.close(handle) }

        let rows = lister.outline(of: handle)
        XCTAssertEqual(rows.map(\.title), ["Top", "Nested", "Second"])
        XCTAssertEqual(rows.map(\.depth), [0, 1, 0])
        XCTAssertEqual(rows.map(\.line), [1, 3, 5])
        XCTAssertEqual(rows.map(\.anchor), ["h1", "h3", "h5"])
    }

    func testAnOutlineAnchorRoundTripsBackToThePlugin() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        XCTAssertTrue(lister.canGotoAnchor)
        let path = try writeFile("nav.txt", "# One\nx\n# Two\n")
        let handle = try XCTUnwrap(lister.load(parent: nil, file: path))
        defer { lister.close(handle) }

        let second = try XCTUnwrap(lister.outline(of: handle).last)
        XCTAssertTrue(lister.gotoAnchor(second.anchor, in: handle))
        // Asserting the effect, not the return code: a plugin that answers OK and scrolls nowhere
        // is exactly the failure a boolean cannot show.
        typealias ScrolledFn = @convention(c) (UnsafeMutableRawPointer?) -> Int32
        XCTAssertEqual(helper(lib, "SampleGetScrolledLine", as: ScrolledFn.self)?(handle), 3)
        XCTAssertFalse(lister.gotoAnchor("nonsense", in: handle))
    }

    func testTextComesBackWholeThroughTheTwoCallSizing() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        XCTAssertTrue(lister.canProvideText)
        // Longer than any buffer the adapter could have guessed at, which is the point of asking
        // the plugin for the size first.
        let body = String(repeating: "Zeile mit Umlauten: äöü ß\n", count: 5_000)
        let path = try writeFile("big.txt", body)
        let handle = try XCTUnwrap(lister.load(parent: nil, file: path))
        defer { lister.close(handle) }
        XCTAssertEqual(lister.text(of: handle), body)
    }

    func testAnEmptyDocumentHasNoOutlineAndNoText() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        let path = try writeFile("empty.txt", "")
        let handle = try XCTUnwrap(lister.load(parent: nil, file: path))
        defer { lister.close(handle) }
        // Nil and empty are normal answers here, not errors — the caller falls back to what it did
        // before, and a plugin showing an image says the same thing.
        XCTAssertEqual(lister.outline(of: handle), [])
        XCTAssertNil(lister.text(of: handle))
    }

    func testTheNewCommandsAreAccepted() throws {
        guard let lib = try buildSampleLister() else { throw XCTSkip("clang unavailable") }
        let lister = PLXLister(library: lib)
        let path = try writeFile("cmd.txt", "x")
        let handle = try XCTUnwrap(lister.load(parent: nil, file: path))
        defer { lister.close(handle) }
        XCTAssertTrue(lister.send(.reload, to: handle))
        XCTAssertTrue(lister.send(.themeChanged, to: handle))
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
