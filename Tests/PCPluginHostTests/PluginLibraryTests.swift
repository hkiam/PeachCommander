// PluginLibraryTests.swift - dlopen/dlsym host tests using clang-built C fixtures.
//
// Each test compiles a tiny C dylib at runtime (clang -dynamiclib) exposing a
// chosen set of exports, then loads it through PluginLibrary to verify symbol
// resolution, the version handshake, and unload policy. Skipped if clang is
// unavailable.

import XCTest
@testable import PCPluginHost

final class PluginLibraryTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pclib-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// Compile `source` into a dylib and return its path, or nil if clang is missing.
    private func buildDylib(_ source: String, name: String) throws -> String? {
        let clang = "/usr/bin/clang"
        guard FileManager.default.isExecutableFile(atPath: clang) else { return nil }
        let src = dir.appendingPathComponent("\(name).c")
        let out = dir.appendingPathComponent("lib\(name).dylib")
        try source.write(to: src, atomically: true, encoding: .utf8)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: clang)
        p.arguments = ["-dynamiclib", "-o", out.path, src.path]
        let pipe = Pipe(); p.standardError = pipe
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("clang failed: \(err)"); return nil
        }
        return out.path
    }

    /// A C source defining the given exports (each a trivial stub).
    private func pcxSource(exports: [String], apiVersion: Int? = nil, safeToUnload: Bool = false) -> String {
        var lines = ["#include <stdint.h>"]
        for e in exports { lines.append("void \(e)(void) {}") }
        if let apiVersion { lines.append("int PcGetApiVersion(void) { return \(apiVersion); }") }
        if safeToUnload { lines.append("void PcSafeToUnload(void) {}") }
        return lines.joined(separator: "\n") + "\n"
    }

    func testLoadsAllRequiredSymbols() throws {
        guard let path = try buildDylib(pcxSource(exports: PCXSymbols.required, apiVersion: 1),
                                        name: "good") else {
            throw XCTSkip("clang unavailable")
        }
        let result = PluginLibrary.open(path: path, required: PCXSymbols.required,
                                        optional: PCXSymbols.optional)
        guard case .success(let lib) = result else { return XCTFail("expected success, got \(result)") }
        for s in PCXSymbols.required { XCTAssertNotNil(lib.symbol(s), "missing \(s)") }
        XCTAssertTrue(lib.resolvedSymbols.contains("PcGetApiVersion"))
    }

    func testMissingRequiredSymbolReported() throws {
        // Omit ProcessFile.
        let exports = PCXSymbols.required.filter { $0 != "ProcessFile" }
        guard let path = try buildDylib(pcxSource(exports: exports, apiVersion: 1), name: "broken") else {
            throw XCTSkip("clang unavailable")
        }
        let result = PluginLibrary.open(path: path, required: PCXSymbols.required)
        guard case .failure(.missingRequiredSymbols(let missing)) = result else {
            return XCTFail("expected missingRequiredSymbols, got \(result)")
        }
        XCTAssertEqual(missing, ["ProcessFile"])
    }

    func testVersionMismatchRejected() throws {
        guard let path = try buildDylib(pcxSource(exports: PCXSymbols.required, apiVersion: 2),
                                        name: "oldapi") else {
            throw XCTSkip("clang unavailable")
        }
        let result = PluginLibrary.open(path: path, required: PCXSymbols.required,
                                        optional: PCXSymbols.optional, expectedAPIVersion: 1)
        guard case .failure(.apiVersionMismatch(found: 2, expected: 1)) = result else {
            return XCTFail("expected apiVersionMismatch, got \(result)")
        }
    }

    func testNoHandshakeSymbolIsAccepted() throws {
        // No PcGetApiVersion export → handshake skipped, load succeeds.
        guard let path = try buildDylib(pcxSource(exports: PCXSymbols.required), name: "nover") else {
            throw XCTSkip("clang unavailable")
        }
        let result = PluginLibrary.open(path: path, required: PCXSymbols.required,
                                        optional: PCXSymbols.optional)
        guard case .success = result else { return XCTFail("expected success, got \(result)") }
    }

    func testUnloadPolicyFromSafeToUnload() throws {
        guard let withUnload = try buildDylib(
                pcxSource(exports: PCXSymbols.required, apiVersion: 1, safeToUnload: true), name: "safe"),
              let without = try buildDylib(
                pcxSource(exports: PCXSymbols.required, apiVersion: 1), name: "unsafe") else {
            throw XCTSkip("clang unavailable")
        }
        if case .success(let a) = PluginLibrary.open(path: withUnload, required: PCXSymbols.required,
                                                     optional: PCXSymbols.optional) {
            XCTAssertTrue(a.canUnload)
        } else { XCTFail("safe load failed") }
        if case .success(let b) = PluginLibrary.open(path: without, required: PCXSymbols.required,
                                                     optional: PCXSymbols.optional) {
            XCTAssertFalse(b.canUnload)
        } else { XCTFail("unsafe load failed") }
    }

    func testDlopenFailureForMissingFile() {
        let result = PluginLibrary.open(path: dir.appendingPathComponent("nope.dylib").path,
                                        required: PCXSymbols.required)
        guard case .failure(.dlopenFailed) = result else { return XCTFail("expected dlopenFailed") }
    }
}
