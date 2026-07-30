// PluginGuardTests.swift - in-process crash guard + quarantine (F-230).
//
// Builds a tiny C dylib exporting a crashing function and a normal one, then
// verifies PluginGuard catches the crash (returning nil + quarantining the
// plugin) while letting well-behaved calls through — all without taking down the
// test process.

import XCTest
@testable import PCPluginHost

final class PluginGuardTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pg-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private static let source = """
    #include <stdlib.h>
    #include <signal.h>
    // Raise SIGSEGV directly (a real NULL deref becomes a Mach EXC_BAD_ACCESS that
    // the test harness's exception server can intercept before the POSIX signal
    // reaches our handler; raise() delivers the signal straight to it). In the
    // shipping app — no debugger attached — a genuine fault also arrives as SIGSEGV.
    void PgCrash(void) { raise(SIGSEGV); }
    // A normal function.
    int PgAddOne(int x) { return x + 1; }
    """

    /// Load the fake dylib and return dlsym'd handles for the two symbols.
    private func buildLibrary() throws -> UnsafeMutableRawPointer? {
        let clang = "/usr/bin/clang"
        guard FileManager.default.isExecutableFile(atPath: clang) else { return nil }
        let src = dir.appendingPathComponent("pg.c")
        let out = dir.appendingPathComponent("libpg.dylib")
        try Self.source.write(to: src, atomically: true, encoding: .utf8)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: clang)
        p.arguments = ["-dynamiclib", "-o", out.path, src.path]
        let pipe = Pipe(); p.standardError = pipe
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            XCTFail("clang failed: \(String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")")
            return nil
        }
        return dlopen(out.path, RTLD_NOW)
    }

    func testGuardCatchesCrashAndQuarantines() throws {
        guard let handle = try buildLibrary() else { throw XCTSkip("clang unavailable") }
        defer { dlclose(handle) }
        typealias VoidFn = @convention(c) () -> Void
        typealias IntFn = @convention(c) (Int32) -> Int32
        let crash = unsafeBitCast(dlsym(handle, "PgCrash")!, to: VoidFn.self)
        let addOne = unsafeBitCast(dlsym(handle, "PgAddOne")!, to: IntFn.self)

        let guardian = PluginGuard()

        // A normal call returns its result.
        XCTAssertEqual(guardian.guarded("plugin.ok") { addOne(41) }, 42)
        XCTAssertFalse(guardian.isQuarantined("plugin.ok"))

        // The crashing call is caught: returns nil, plugin quarantined, process alive.
        let crashed: Int? = guardian.guarded("plugin.bad") { crash(); return 0 }
        XCTAssertNil(crashed)
        XCTAssertTrue(guardian.isQuarantined("plugin.bad"))

        // A quarantined plugin is skipped (nil) without even calling — still alive.
        var called = false
        let skipped: Int? = guardian.guarded("plugin.bad") { called = true; return 7 }
        XCTAssertNil(skipped)
        XCTAssertFalse(called)

        // The guard did not poison unrelated plugins.
        XCTAssertEqual(guardian.guarded("plugin.ok") { addOne(1) }, 2)
    }
}
