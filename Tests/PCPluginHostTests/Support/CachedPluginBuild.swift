// SPDX-License-Identifier: Apache-2.0
// CachedPluginBuild.swift - compile a plugin once per test run, hand each test its own copy.
//
// Several test classes build the plugin they exercise from its real sources, so that a source
// file missing from the build list fails here loudly rather than shipping absent. That property
// is worth keeping. Paying for it once per *test method* was not: `FSImagePluginTests` compiled
// 32 Swift files and a vendored zstd on every one of its 79 tests, which measured at 9.7 s each —
// 12.8 minutes of a 29-minute suite spent producing 79 identical dylibs.
//
// So the compile is memoized per key, and each test still gets a freshly `dlopen`ed image: the
// cached artifact is *copied* to a unique path under the test's own temporary directory before
// it is opened. dyld keys on the path, so a copy is a distinct image with its own globals —
// exactly what building per test used to give, for the price of a file copy instead of a compiler
// invocation. (It also matters that `PluginLibrary` only `dlclose`s plugins exporting
// `PcSafeToUnload`: reusing one open handle across tests would have leaked state between them.)
//
// Failures are cached too, and rethrown per test. A plugin that does not compile therefore still
// turns every test in its class red — the compiler just runs once to establish it. `XCTSkip`
// travels the same way, so a machine without a compiler skips exactly as before.

import Foundation
import XCTest

enum CachedPluginBuild {
    private static let lock = NSLock()
    private static var artifacts: [String: Result<URL, Error>] = [:]
    private static var root: URL?

    /// The built artifact for `key`, compiling it on first use.
    ///
    /// `build` receives a directory of its own to work in — intermediates may be left there — and
    /// returns the file that tests should open. It runs at most once per process, under a lock, so
    /// two parallel test classes asking for the same plugin cannot compile it twice.
    static func artifact(key: String, build: (URL) throws -> URL) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        if let cached = artifacts[key] { return try cached.get() }

        let result: Result<URL, Error>
        do {
            let dir = try cacheRoot().appendingPathComponent(key, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            result = .success(try build(dir))
        } catch {
            result = .failure(error)
        }
        artifacts[key] = result
        return try result.get()
    }

    /// A private copy of `artifact` inside `dir`, so opening it yields an image of its own.
    static func freshCopy(of artifact: URL, into dir: URL) throws -> URL {
        let copy = dir.appendingPathComponent("\(UUID().uuidString)-\(artifact.lastPathComponent)")
        try FileManager.default.copyItem(at: artifact, to: copy)
        return copy
    }

    /// Compile-once + copy, the shape every caller actually wants.
    static func freshBuild(key: String, into dir: URL, build: (URL) throws -> URL) throws -> URL {
        try freshCopy(of: try artifact(key: key, build: build), into: dir)
    }

    private static func cacheRoot() throws -> URL {
        if let root { return root }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-plugin-build-cache-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        root = url
        // The runner process is torn down between bundles, so this is the only place the cache
        // can be swept without a class knowing whether it was the last to use it.
        atexit { CachedPluginBuild.removeCacheRoot() }
        return url
    }

    private static func removeCacheRoot() {
        // No lock: atexit runs after the tests, and taking one here risks deadlocking teardown.
        if let root { try? FileManager.default.removeItem(at: root) }
    }
}

/// A plugin that ran the compiler and was refused by it.
///
/// Thrown rather than reported with `XCTFail`, because these builds happen in `setUpWithError`:
/// `XCTFail` records the failure and lets setUp finish, leaving the test body to force-unwrap a
/// nil library — a `fatalError` that takes the whole runner down along with every test after it.
/// Throwing costs one red test and keeps the rest of the results.
struct PluginBuildFailure: Error, CustomStringConvertible {
    let description: String
}
