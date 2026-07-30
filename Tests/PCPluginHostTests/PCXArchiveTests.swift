// PCXArchiveTests.swift - PCX adapter driven against a clang-built C fake plugin.
//
// Compiles a tiny PCX plugin (implementing the required C ABI over pcx.h) at
// runtime and verifies the Swift adapter can list and extract through the real
// C function pointers. Skipped if clang is unavailable.

import XCTest
import CPCX
@testable import PCPluginHost

final class PCXArchiveTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pcx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    /// Path to Plugins/SDK relative to this test source, for the fixture's -I flag.
    private var sdkIncludeDir: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PCPluginHostTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Plugins/SDK").path
    }

    private static let fakePlugin = """
    #include "pcx.h"
    #include <string.h>
    #include <stdlib.h>
    #include <stdio.h>
    typedef struct { int idx; } St;
    PC_HANDLE OpenArchive(PcOpenArchiveData *d) { St *s = calloc(1, sizeof(St)); d->openResult = PC_OK; return s; }
    int ReadHeaderEx(PC_HANDLE h, PcHeaderDataEx *hd) {
        St *s = (St *)h;
        if (s->idx > 0) return PC_E_END_ARCHIVE;
        memset(hd, 0, sizeof(*hd));
        strcpy(hd->fileName, "hello.txt");
        hd->unpSize = 5; hd->packSize = 5; hd->fileTime = 1000;
        s->idx = 1;
        return PC_OK;
    }
    int ProcessFile(PC_HANDLE h, int op, char *dp, char *dn) {
        (void)h; (void)dp;
        if (op == PC_EXTRACT && dn) { FILE *f = fopen(dn, "wb"); if (f) { fwrite("hello", 1, 5, f); fclose(f); } }
        return PC_OK;
    }
    int CloseArchive(PC_HANDLE h) { free(h); return PC_OK; }
    void SetChangeVolProc(PC_HANDLE h, PcChangeVolProc p) { (void)h; (void)p; }
    void SetProcessDataProc(PC_HANDLE h, PcProcessDataProc p) { (void)h; (void)p; }
    int GetPackerCaps(void) { return PC_CAP_NEW | PC_CAP_MODIFY | PC_CAP_DELETE; }
    int CanYouHandleThisFile(char *name) { return name && strstr(name, ".pak") ? 1 : 0; }
    int PcGetApiVersion(void) { return 1; }
    """

    /// A fake plugin whose PackFiles crashes (raises SIGSEGV) — for the crash guard.
    private static let crashingPackPlugin = """
    #include "pcx.h"
    #include <string.h>
    #include <stdlib.h>
    #include <signal.h>
    PC_HANDLE OpenArchive(PcOpenArchiveData *d) { d->openResult = PC_OK; return calloc(1, 1); }
    int ReadHeaderEx(PC_HANDLE h, PcHeaderDataEx *hd) { (void)h; (void)hd; return PC_E_END_ARCHIVE; }
    int ProcessFile(PC_HANDLE h, int op, char *dp, char *dn) { (void)h; (void)op; (void)dp; (void)dn; return PC_OK; }
    int CloseArchive(PC_HANDLE h) { free(h); return PC_OK; }
    void SetChangeVolProc(PC_HANDLE h, PcChangeVolProc p) { (void)h; (void)p; }
    void SetProcessDataProc(PC_HANDLE h, PcProcessDataProc p) { (void)h; (void)p; }
    int PackFiles(char *a, char *s, char *r, char *l, int f) { (void)a;(void)s;(void)r;(void)l;(void)f; raise(SIGSEGV); return PC_OK; }
    int PcGetApiVersion(void) { return 1; }
    """

    /// A fake packer whose PackFiles reports progress via the stored callback (F-231).
    private static let progressPackPlugin = """
    #include "pcx.h"
    #include <string.h>
    #include <stdlib.h>
    static PcProcessDataProc g_proc = 0;
    PC_HANDLE OpenArchive(PcOpenArchiveData *d) { d->openResult = PC_OK; return calloc(1,1); }
    int ReadHeaderEx(PC_HANDLE h, PcHeaderDataEx *hd) { (void)h;(void)hd; return PC_E_END_ARCHIVE; }
    int ProcessFile(PC_HANDLE h, int op, char *dp, char *dn) { (void)h;(void)op;(void)dp;(void)dn; return PC_OK; }
    int CloseArchive(PC_HANDLE h) { free(h); return PC_OK; }
    void SetChangeVolProc(PC_HANDLE h, PcChangeVolProc p) { (void)h;(void)p; }
    void SetProcessDataProc(PC_HANDLE h, PcProcessDataProc p) { (void)h; g_proc = p; }
    int PackFiles(char *a, char *s, char *r, char *l, int f) {
        (void)a;(void)s;(void)r;(void)l;(void)f;
        if (g_proc) { g_proc("a.txt", 100); g_proc("b.txt", 200); }
        return PC_OK;
    }
    int PcGetApiVersion(void) { return 1; }
    """

    private func buildFakeLibrary(source: String? = nil) throws -> PluginLibrary? {
        let clang = "/usr/bin/clang"
        guard FileManager.default.isExecutableFile(atPath: clang) else { return nil }
        let src = dir.appendingPathComponent("fake.c")
        let out = dir.appendingPathComponent("libfake.dylib")
        try (source ?? Self.fakePlugin).write(to: src, atomically: true, encoding: .utf8)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: clang)
        p.arguments = ["-dynamiclib", "-I", sdkIncludeDir, "-o", out.path, src.path]
        let pipe = Pipe(); p.standardError = pipe
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("clang failed: \(err)"); return nil
        }
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PCXSymbols.required, optional: PCXSymbols.optional) else {
            XCTFail("PluginLibrary.open failed"); return nil
        }
        return lib
    }

    func testListsEntries() throws {
        guard let lib = try buildFakeLibrary() else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)
        let entries = try archive.list(archivePath: dir.appendingPathComponent("whatever.pak").path)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.path, "hello.txt")
        XCTAssertEqual(entries.first?.size, 5)
        XCTAssertEqual(entries.first?.isDirectory, false)
        XCTAssertEqual(entries.first?.modified, Date(timeIntervalSince1970: 1000))
    }

    func testExtractsEntry() throws {
        guard let lib = try buildFakeLibrary() else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)
        let dest = dir.appendingPathComponent("out.txt")
        try archive.extract(archivePath: dir.appendingPathComponent("whatever.pak").path,
                            entryPath: "hello.txt", to: dest.path)
        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "hello")
    }

    func testPackerCapsAndCanHandle() throws {   // F-231
        guard let lib = try buildFakeLibrary() else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)
        let caps = try XCTUnwrap(archive.packerCaps())
        XCTAssertEqual(caps & Int(PC_CAP_NEW), Int(PC_CAP_NEW))
        XCTAssertEqual(caps & Int(PC_CAP_DELETE), Int(PC_CAP_DELETE))
        // Capability-derived flags.
        XCTAssertTrue(archive.canPack)
        XCTAssertTrue(archive.canDelete)
        // CanYouHandleThisFile detection.
        XCTAssertEqual(archive.canHandle(fileName: "foo.pak"), true)
        XCTAssertEqual(archive.canHandle(fileName: "foo.zip"), false)
    }

    func testGuardCatchesCrashingPack() throws {   // F-230
        guard let lib = try buildFakeLibrary(source: Self.crashingPackPlugin) else { throw XCTSkip("clang unavailable") }
        let guardian = PluginGuard()
        let archive = PCXArchive(library: lib, pluginID: "pcx.crasher", guard: guardian)
        // The crashing PackFiles is caught and surfaced as .crashed, not a process death.
        XCTAssertThrowsError(try archive.pack(archivePath: dir.appendingPathComponent("out.pak").path,
                                              sourceDir: dir.path, files: ["x"])) { error in
            XCTAssertEqual(error as? PCXArchive.PCXError, .crashed)
        }
        // The plugin is now quarantined → further calls fail fast, still no crash.
        XCTAssertTrue(guardian.isQuarantined("pcx.crasher"))
        XCTAssertThrowsError(try archive.list(archivePath: dir.appendingPathComponent("out.pak").path)) { error in
            XCTAssertEqual(error as? PCXArchive.PCXError, .crashed)
        }
    }

    func testProgressCallbackDuringPack() throws {   // F-231
        guard let lib = try buildFakeLibrary(source: Self.progressPackPlugin) else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)
        var received: [(String, Int64)] = []
        archive.onProgress = { received.append(($0.file, $0.bytes)); return true }
        try archive.pack(archivePath: dir.appendingPathComponent("out.pak").path,
                         sourceDir: dir.path, files: ["x"])
        XCTAssertEqual(received.map(\.0), ["a.txt", "b.txt"])
        XCTAssertEqual(received.map(\.1), [100, 200])
    }

    func testExtractMissingEntryThrows() throws {
        guard let lib = try buildFakeLibrary() else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)
        XCTAssertThrowsError(try archive.extract(
            archivePath: dir.appendingPathComponent("whatever.pak").path,
            entryPath: "nope.txt", to: dir.appendingPathComponent("x").path)) { error in
            XCTAssertEqual(error as? PCXArchive.PCXError, .entryNotFound("nope.txt"))
        }
    }
}
