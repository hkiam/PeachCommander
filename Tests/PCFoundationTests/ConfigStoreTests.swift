// ConfigStoreTests.swift - Unit tests for ConfigStore and ConfigPaths

import XCTest
@testable import PCFoundation

final class ConfigStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let unique = "ConfigStoreTests-\(UUID().uuidString)"
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(unique, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    private func configURL(_ name: String = "test.ini") -> URL {
        tempDir.appendingPathComponent(name)
    }

    // MARK: - Typed accessors

    func testSetStringThenGetStringReturnsValue() async {
        let store = ConfigStore(url: configURL())
        await store.setString("classic", "Layout", "Style")
        let value = await store.string("Layout", "Style", default: "fallback")
        XCTAssertEqual(value, "classic")
    }

    /// Workspaces encode tab lists with U+0001/U+0002 separators in a single
    /// value; ConfigStore must round-trip those control characters through disk.
    func testControlCharacterValueRoundTripsThroughFile() async {
        let url = configURL("ctrl.ini")
        let value = "a\u{1}b\u{1}c\u{2}d\u{1}e"
        let writer = ConfigStore(url: url)
        await writer.setString(value, "Workspaces", "Left0")
        await writer.flush()

        // Fresh store reading the same file must return the exact bytes.
        let reader = ConfigStore(url: url)
        let read = await reader.string("Workspaces", "Left0", default: "")
        XCTAssertEqual(read, value)
    }

    func testSetIntThenGetIntReturnsValue() async {
        let store = ConfigStore(url: configURL())
        await store.setInt(42, "Window", "Width")
        let value = await store.int("Window", "Width", default: -1)
        XCTAssertEqual(value, 42)
    }

    func testSetBoolThenGetBoolReturnsValue() async {
        let store = ConfigStore(url: configURL())
        await store.setBool(true, "Configuration", "ShowHiddenSystem")
        let value = await store.bool("Configuration", "ShowHiddenSystem", default: false)
        XCTAssertTrue(value)
    }

    func testSetDoubleThenGetDoubleReturnsValue() async {
        let store = ConfigStore(url: configURL())
        await store.setDouble(3.5, "Display", "ZoomFactor")
        let value = await store.double("Display", "ZoomFactor", default: 1.0)
        XCTAssertEqual(value, 3.5)
    }

    func testDefaultsReturnedWhenKeyAbsent() async {
        let store = ConfigStore(url: configURL())
        let s = await store.string("None", "Missing", default: "def")
        let i = await store.int("None", "Missing", default: 7)
        let b = await store.bool("None", "Missing", default: true)
        let d = await store.double("None", "Missing", default: 2.5)

        XCTAssertEqual(s, "def")
        XCTAssertEqual(i, 7)
        XCTAssertTrue(b)
        XCTAssertEqual(d, 2.5)
    }

    func testBoolParsingAcceptsMultipleTruthyAndFalsyForms() async {
        let store = ConfigStore(url: configURL())

        await store.setString("1", "B", "a")
        await store.setString("0", "B", "b")
        await store.setString("true", "B", "c")
        await store.setString("FALSE", "B", "d")
        await store.setString("Yes", "B", "e")
        await store.setString("no", "B", "f")

        let a = await store.bool("B", "a", default: false)
        let b = await store.bool("B", "b", default: true)
        let c = await store.bool("B", "c", default: false)
        let d = await store.bool("B", "d", default: true)
        let e = await store.bool("B", "e", default: false)
        let f = await store.bool("B", "f", default: true)

        XCTAssertTrue(a)
        XCTAssertFalse(b)
        XCTAssertTrue(c)
        XCTAssertFalse(d)
        XCTAssertTrue(e)
        XCTAssertFalse(f)
    }

    // MARK: - Persistence

    func testFlushWritesFileReadableBySecondStore() async {
        let url = configURL()
        let store = ConfigStore(url: url)
        await store.setString("classic", "Layout", "Style")
        await store.flush()

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let secondStore = ConfigStore(url: url)
        let value = await secondStore.string("Layout", "Style", default: "missing")
        XCTAssertEqual(value, "classic")
    }

    func testFlushWritesMetaVersion() async {
        let url = configURL()
        let store = ConfigStore(url: url)
        await store.setInt(1, "A", "B")
        await store.flush()

        let secondStore = ConfigStore(url: url)
        let version = await secondStore.int("meta", "version", default: -1)
        XCTAssertEqual(version, 1)
    }

    /// Verifies the debounced write eventually reaches disk on its own,
    /// without calling `flush()`, by using a short debounce interval and
    /// waiting comfortably past it before reading the file directly.
    func testDebouncedWriteEventuallyPersistsWithoutExplicitFlush() async throws {
        let url = configURL()
        let store = ConfigStore(url: url, debounceSeconds: 0.05)
        await store.setString("classic", "Layout", "Style")

        try await Task.sleep(nanoseconds: 500_000_000)

        let data = try XCTUnwrap(FileManager.default.contents(atPath: url.path))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        let doc = INIDocument(parsing: text)
        XCTAssertEqual(doc.value(section: "Layout", key: "Style"), "classic")
    }

    // MARK: - Corrupt file recovery
    //
    // INIDocument's parser is permissive: any line it doesn't recognize is
    // preserved verbatim as a comment rather than causing a parse failure.
    // So the only way ConfigStore's ".bak" recovery path triggers is a
    // decoding failure — bytes that aren't valid UTF-8 — which is what this
    // test exercises directly.

    func testCorruptFileRecoveryMovesInvalidUTF8FileAsideAndUsesEmptyDoc() async {
        let url = configURL()
        let invalidBytes = Data([0xFF, 0xFE, 0x00, 0xFF])
        try? invalidBytes.write(to: url)

        let store = ConfigStore(url: url)
        let value = await store.string("Layout", "Style", default: "fallback")
        XCTAssertEqual(value, "fallback")

        let backupURL = URL(fileURLWithPath: url.path + ".bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        XCTAssertEqual(FileManager.default.contents(atPath: backupURL.path), invalidBytes)

        // The store should still be fully usable after recovering from the bad file.
        await store.setString("classic", "Layout", "Style")
        await store.flush()

        let reloaded = ConfigStore(url: url)
        let reloadedValue = await reloaded.string("Layout", "Style", default: "fallback")
        XCTAssertEqual(reloadedValue, "classic")
    }

    // MARK: - ConfigPaths

    func testConfigPathsResolveHonorsExplicitConfigRootArgument() {
        let customRoot = tempDir.appendingPathComponent("arg-root", isDirectory: true)
        let paths = ConfigPaths.resolve(
            arguments: ["/usr/bin/peachcmd", "-ConfigRoot", customRoot.path],
            environment: [:]
        )

        XCTAssertEqual(paths.root.standardizedFileURL.path, customRoot.standardizedFileURL.path)
        XCTAssertEqual(paths.mainConfig.lastPathComponent, "peachcmd.ini")
        XCTAssertEqual(paths.session.lastPathComponent, "session.ini")
        XCTAssertEqual(paths.hotlist.lastPathComponent, "hotlist.ini")
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.root.path))
    }

    func testConfigPathsResolveHonorsEnvironmentVariable() {
        let envRoot = tempDir.appendingPathComponent("env-root", isDirectory: true)
        let paths = ConfigPaths.resolve(
            arguments: ["/usr/bin/peachcmd"],
            environment: ["PEACHCMD_CONFIG_ROOT": envRoot.path]
        )

        XCTAssertEqual(paths.root.standardizedFileURL.path, envRoot.standardizedFileURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.root.path))
    }

    // MARK: - Concurrency

    func testConcurrentSetIntFromMultipleTasksDoesNotCrashAndProducesConsistentValue() async {
        let store = ConfigStore(url: configURL())

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    await store.setInt(i, "Concurrency", "Counter")
                }
            }
        }

        let finalValue = await store.int("Concurrency", "Counter", default: -1)
        XCTAssertTrue((0..<50).contains(finalValue))
    }

    // MARK: - Change notifications

    func testChangesStreamReceivesNotificationOnSet() async {
        let store = ConfigStore(url: configURL())
        let stream = await store.changes()

        Task {
            await store.setString("classic", "Layout", "Style")
        }

        var iterator = stream.makeAsyncIterator()
        let change = await iterator.next()
        XCTAssertEqual(change, ConfigChange(section: "Layout", key: "Style"))
    }

    func testMultipleConcurrentSubscribersBothReceiveChange() async {
        let store = ConfigStore(url: configURL())
        let streamA = await store.changes()
        let streamB = await store.changes()

        Task {
            await store.setString("classic", "Layout", "Style")
        }

        var iteratorA = streamA.makeAsyncIterator()
        var iteratorB = streamB.makeAsyncIterator()
        let changeA = await iteratorA.next()
        let changeB = await iteratorB.next()

        XCTAssertEqual(changeA, ConfigChange(section: "Layout", key: "Style"))
        XCTAssertEqual(changeB, ConfigChange(section: "Layout", key: "Style"))
    }
}
