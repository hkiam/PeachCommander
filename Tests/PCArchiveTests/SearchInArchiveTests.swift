// SPDX-License-Identifier: Apache-2.0
// SearchInArchiveTests.swift - FileSearchEngine descending into archives via the
// shared ArchiveRegistry (search-in-archives option, F-153/F-463).
//
// The opener here used to be a hand-written copy of the app's, which meant the tests
// agreed with a duplicate rather than with production — and both were wrong about the
// tar family in exactly the same way. It is now the real `ArchiveRegistry`, so what
// these tests prove is what the app does.

import XCTest
import PCVFS
@testable import PCArchive

final class SearchInArchiveTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/usr/bin/zip"), "zip missing")
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("SearchArch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    /// Build `dir/<name>` (a zip) containing inner/secret.txt with `content`.
    private func makeZip(named name: String, content: String) throws {
        let payload = dir.appendingPathComponent("payload")
        let inner = payload.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try content.data(using: .utf8)!.write(to: inner.appendingPathComponent("secret.txt"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-r", "-q", dir.appendingPathComponent(name).path, "inner"]
        p.currentDirectoryURL = payload
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: payload)
    }

    /// The production authority, minus the plugin backend (PCPluginHost is not a
    /// dependency of this test target). The native backend alone covers zip and tar.
    private var opener: ArchiveRegistry { ArchiveRegistry(backends: [NativeArchiveBackend()]) }

    private func collect(_ query: SearchQuery) async -> [String] {
        await run(query).hits
    }

    /// Hits and whatever the run declined to look inside.
    private func run(_ query: SearchQuery) async -> (hits: [String], notices: [SearchNotice]) {
        let full = await runFull(query)
        return (full.hits.map(\.path), full.notices)
    }

    private func runFull(_ query: SearchQuery) async -> (hits: [SearchHit], notices: [SearchNotice]) {
        let engine = FileSearchEngine()
        var hits: [SearchHit] = []
        for await hit in await engine.search(query, fs: LocalFS(), archiveOpener: opener) {
            hits.append(hit)
        }
        return (hits, await engine.takeNotices())
    }

    /// Build `dir/<name>` as a tar (compressed when the name says so) holding inner/secret.txt.
    private func makeTar(named name: String, content: String) throws {
        let payload = dir.appendingPathComponent("payload")
        let inner = payload.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try content.data(using: .utf8)!.write(to: inner.appendingPathComponent("secret.txt"))
        let compressed = name.hasSuffix(".gz") || name.hasSuffix(".tgz")
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = [compressed ? "-czf" : "-cf", dir.appendingPathComponent(name).path, "inner"]
        p.currentDirectoryURL = payload
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: payload)
    }

    func test_contentSearch_descendsIntoZip_whenEnabled() async throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "plain note".data(using: .utf8)!.write(to: dir.appendingPathComponent("note.txt"))
        try makeZip(named: "data.zip", content: "the needle is here\n")

        let on = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                           contentText: "needle", searchArchives: true))
        XCTAssertTrue(on.contains { $0.contains("data.zip") && $0.hasSuffix("secret.txt") },
                      "inner archive file not found: \(on)")

        let off = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                            contentText: "needle", searchArchives: false))
        XCTAssertFalse(off.contains { $0.hasSuffix("secret.txt") }, "should not descend when off: \(off)")
    }

    func test_zipFamilyExtension_jar_isSearched() async throws {
        try makeZip(named: "app.jar", content: "META needle INF\n")
        let hits = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                             contentText: "needle", searchArchives: true))
        XCTAssertTrue(hits.contains { $0.contains("app.jar") && $0.hasSuffix("secret.txt") },
                      ".jar not searched: \(hits)")
    }

    func test_nestedArchive_isSearchedRecursively() async throws {
        // Build inner.zip (containing inner/secret.txt), then wrap it in outer.zip.
        try makeZip(named: "inner.zip", content: "deeply buried needle\n")
        let wrap = dir.appendingPathComponent("wrap")
        try FileManager.default.createDirectory(at: wrap, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: dir.appendingPathComponent("inner.zip"),
                                         to: wrap.appendingPathComponent("inner.zip"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-r", "-q", dir.appendingPathComponent("outer.zip").path, "inner.zip"]
        p.currentDirectoryURL = wrap
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: wrap)

        let hits = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                             contentText: "needle", searchArchives: true))
        XCTAssertTrue(hits.contains { $0.contains("outer.zip") && $0.contains("inner.zip")
                                       && $0.hasSuffix("secret.txt") },
                      "nested archive not searched: \(hits)")
    }

    // MARK: - The tar family (F-463)

    /// The reported defect, as a test: a folder holding a `.tar.gz` whose config file
    /// contains the term reported "nothing found". `pathExtension` of "x.tar.gz" is
    /// "gz", so the old zip-family gate never even asked the opener.
    func test_contentSearch_descendsIntoTarGz() async throws {
        try makeTar(named: "backup.tar.gz", content: "listen = 0.0.0.0\nneedle = yes\n")

        let hits = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                             contentText: "needle", searchArchives: true))
        XCTAssertTrue(hits.contains { $0.contains("backup.tar.gz") && $0.hasSuffix("secret.txt") },
                      "tar.gz not searched: \(hits)")
    }

    func test_contentSearch_descendsIntoPlainTarAndTgz() async throws {
        try makeTar(named: "plain.tar", content: "needle in a plain tar\n")
        try makeTar(named: "short.tgz", content: "needle in a tgz\n")

        let hits = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                             contentText: "needle", searchArchives: true))
        XCTAssertTrue(hits.contains { $0.contains("plain.tar") }, ".tar not searched: \(hits)")
        XCTAssertTrue(hits.contains { $0.contains("short.tgz") }, ".tgz not searched: \(hits)")
    }

    /// Mixed nesting: the outer container and the inner one are different formats, so
    /// this fails if either half of the descent still assumes zip.
    func test_tarGzInsideZip_isSearched() async throws {
        try makeTar(named: "inner.tar.gz", content: "deeply buried needle\n")
        let wrap = dir.appendingPathComponent("wrap")
        try FileManager.default.createDirectory(at: wrap, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: dir.appendingPathComponent("inner.tar.gz"),
                                         to: wrap.appendingPathComponent("inner.tar.gz"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-r", "-q", dir.appendingPathComponent("outer.zip").path, "inner.tar.gz"]
        p.currentDirectoryURL = wrap
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: wrap)

        let hits = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                             contentText: "needle", searchArchives: true))
        XCTAssertTrue(hits.contains { $0.contains("outer.zip") && $0.contains("inner.tar.gz")
                                       && $0.hasSuffix("secret.txt") },
                      "tar.gz nested in a zip not searched: \(hits)")
    }

    /// Descending into a nested archive extracts it; the run must hand that back.
    /// Every nested archive used to leave a `PCArchive-<uuid>/` directory behind.
    func test_nestedArchiveSearch_leavesNoTempDirectories() async throws {
        try makeTar(named: "inner.tar.gz", content: "buried needle\n")
        let wrap = dir.appendingPathComponent("wrap")
        try FileManager.default.createDirectory(at: wrap, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: dir.appendingPathComponent("inner.tar.gz"),
                                         to: wrap.appendingPathComponent("inner.tar.gz"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-r", "-q", dir.appendingPathComponent("outer.zip").path, "inner.tar.gz"]
        p.currentDirectoryURL = wrap
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: wrap)

        _ = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                      contentText: "needle", searchArchives: true))
        XCTAssertTrue(Self.extractionsLeftBehind(named: "inner.tar.gz").isEmpty,
                      "the search left extracted archives behind: "
                        + "\(Self.extractionsLeftBehind(named: "inner.tar.gz"))")
    }

    /// Extractions still sitting in the temp directory, found by the member's own name.
    ///
    /// Counting `PCArchive-*` directories was the first attempt and it failed only in a
    /// full run: the other suites extract archives at the same time, so the count moves
    /// underneath the assertion. Asking for this member by name is a statement about
    /// this test's own leak and nobody else's.
    private static func extractionsLeftBehind(named name: String) -> [String] {
        let tmp = FileManager.default.temporaryDirectory
        let fm = FileManager.default
        let roots = ((try? fm.contentsOfDirectory(atPath: tmp.path)) ?? [])
            .filter { $0.hasPrefix("PCArchive-") }
        var found: [String] = []
        for root in roots {
            let base = tmp.appendingPathComponent(root)
            guard let walker = fm.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.lastPathComponent == name {
                found.append(url.path)
            }
        }
        return found
    }

    /// An archive we recognised and could not open has to be reported. A run that
    /// looked everywhere must stay silent, or the line stops being worth reading.
    func test_unreadableArchive_isReportedRatherThanIgnored() async throws {
        try makeTar(named: "good.tar.gz", content: "needle here\n")
        try Data("this is not an archive at all".utf8)
            .write(to: dir.appendingPathComponent("broken.tar.gz"))

        let result = await run(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                           contentText: "needle", searchArchives: true))
        XCTAssertTrue(result.hits.contains { $0.contains("good.tar.gz") })
        XCTAssertTrue(result.notices.contains { $0.path.hasSuffix("broken.tar.gz")
                                                 && $0.reason == .unreadable },
                      "unreadable archive not reported: \(result.notices)")
    }

    func test_searchThatLookedEverywhere_reportsNothing() async throws {
        try makeTar(named: "good.tar.gz", content: "needle here\n")

        let result = await run(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                           contentText: "needle", searchArchives: true))
        XCTAssertFalse(result.hits.isEmpty)
        XCTAssertTrue(result.notices.isEmpty, "a clean run must say nothing: \(result.notices)")
    }

    // MARK: - Provenance (F-463)

    /// A hit's path is the archive's and the member's glued together, which cannot be
    /// told apart from a hit in a real folder named `data.zip`. The origin can.
    func test_hitInsideArchive_carriesItsOrigin() async throws {
        try makeTar(named: "backup.tar.gz", content: "needle = yes\n")
        try "needle = yes\n".write(to: dir.appendingPathComponent("loose.txt"),
                                   atomically: true, encoding: .utf8)

        let result = await runFull(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                               contentText: "needle", searchArchives: true))
        let inArchive = result.hits.first { $0.path.contains("backup.tar.gz") }
        let onDisk = result.hits.first { $0.path.hasSuffix("loose.txt") }

        XCTAssertNil(onDisk?.origin, "an ordinary file must carry no origin")
        let origin = try XCTUnwrap(inArchive?.origin, "archive hit carries no origin")
        XCTAssertEqual(origin.containers.count, 1)
        XCTAssertTrue(origin.containers[0].hasSuffix("backup.tar.gz"))
        XCTAssertTrue(origin.member.hasSuffix("secret.txt"), "member was \(origin.member)")
    }

    /// Nested: the containers list has to name both, outermost first, each in its
    /// parent's terms — that is what makes re-opening it possible at all.
    func test_nestedHit_namesEveryContainerOutermostFirst() async throws {
        try makeTar(named: "inner.tar.gz", content: "buried needle\n")
        let wrap = dir.appendingPathComponent("wrap")
        try FileManager.default.createDirectory(at: wrap, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: dir.appendingPathComponent("inner.tar.gz"),
                                         to: wrap.appendingPathComponent("inner.tar.gz"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-r", "-q", dir.appendingPathComponent("outer.zip").path, "inner.tar.gz"]
        p.currentDirectoryURL = wrap
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: wrap)

        let result = await runFull(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                               contentText: "needle", searchArchives: true))
        let hit = try XCTUnwrap(result.hits.first { $0.path.contains("outer.zip") })
        let origin = try XCTUnwrap(hit.origin)
        XCTAssertEqual(origin.containers.count, 2, "containers were \(origin.containers)")
        XCTAssertTrue(origin.containers[0].hasSuffix("outer.zip"))
        XCTAssertTrue(origin.containers[1].hasSuffix("inner.tar.gz"))
        XCTAssertTrue(origin.member.hasSuffix("secret.txt"))
    }

    // MARK: - Admission control (F-463)

    /// Widening the gate to the tar family made the reader's cost reachable from a walk:
    /// a gzip-wrapped tar has to be inflated whole, and the compressed size on disk says
    /// almost nothing about how much that is. The ceiling is on the *expanded* size.
    func test_tarGzOverTheExpandedCeiling_isRefusedBeforeInflating() throws {
        // ~8 MB of repeated text: tiny on disk, well past the ceiling used here.
        let payload = dir.appendingPathComponent("payload")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        let big = String(repeating: "needle and hay\n", count: 560_000)
        try big.data(using: .utf8)!.write(to: payload.appendingPathComponent("big.txt"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = ["-czf", dir.appendingPathComponent("big.tar.gz").path, "big.txt"]
        p.currentDirectoryURL = payload
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()

        let url = dir.appendingPathComponent("big.tar.gz")
        XCTAssertNotNil(TarReader(fileURL: url), "no ceiling: must still open")
        XCTAssertNil(TarReader(fileURL: url, limits: .init(maxExpandedBytes: 1024)),
                     "a ceiling of 1 KB must refuse an 8 MB payload")
    }

    /// And an archive over that ceiling must not simply vanish. `ArchiveFS` falls
    /// through to the bsdtar-backed reader, which streams instead of inflating — so the
    /// ceiling diverts the walk to the slower reader rather than costing it the archive.
    /// The whole point of this work is that nothing is dropped in silence.
    func test_tarGzOverTheCeiling_isStillSearchedByTheStreamingReader() async throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/usr/bin/bsdtar")
                            || FileManager.default.fileExists(atPath: "/usr/bin/tar"),
                          "bsdtar missing")
        let payload = dir.appendingPathComponent("payload")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try String(repeating: "hay hay hay\n", count: 400_000).data(using: .utf8)!
            .write(to: payload.appendingPathComponent("big.txt"))
        try "the needle is here\n".data(using: .utf8)!
            .write(to: payload.appendingPathComponent("small.txt"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = ["-czf", dir.appendingPathComponent("big.tar.gz").path, "big.txt", "small.txt"]
        p.currentDirectoryURL = payload
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: payload)

        let url = dir.appendingPathComponent("big.tar.gz")
        XCTAssertNil(TarReader(fileURL: url, limits: .init(maxExpandedBytes: 1024)),
                     "the tar reader must decline this one")
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: url, fsID: "zip:\(url.path)",
                                         tarLimits: .init(maxExpandedBytes: 1024)),
                               "declined by one reader must not mean lost")
        XCTAssertEqual(fs.memberAccessCost, .processPerMember,
                       "the fallback reader streams per member")
    }

    // MARK: - Cancellation (F-463)

    /// The walk checked cancellation around the open and never inside it, so a search
    /// meeting a large archive could not be stopped until the reader had finished with
    /// it. The readers now look at the task that started them — they run synchronously
    /// on it, so its cancellation is visible without threading a flag down.
    ///
    /// Asserted on the mechanism rather than on a stopwatch: an archive small enough to
    /// build in a test opens in milliseconds, so a timing test would pass whether the
    /// checks existed or not.
    func test_readerDeclinesToFinishWorkForACancelledTask() async throws {
        let payload = dir.appendingPathComponent("payload")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        // Past the reader's first check, which sits every 1024 header blocks.
        for i in 0..<3000 {
            try Data("hay\n".utf8).write(to: payload.appendingPathComponent("f\(i).txt"))
        }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = ["-cf", dir.appendingPathComponent("many.tar").path, "."]
        p.currentDirectoryURL = payload
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: payload)

        let url = dir.appendingPathComponent("many.tar")
        XCTAssertNotNil(TarReader(fileURL: url), "control: it opens when nobody cancelled")

        let task = Task<Bool, Never> {
            while !Task.isCancelled { await Task.yield() }
            return TarReader(fileURL: url) == nil
        }
        task.cancel()
        let declined = await task.value
        XCTAssertTrue(declined, "the reader finished the work of a cancelled task")
    }

    // MARK: - Same bytes, same answer (F-463)

    /// A match past the 16 MB streaming cap. On disk it was always found; inside an
    /// archive it was silently missed, so the same file answered two different ways
    /// depending on where it sat. That is the reported defect one level down.
    func test_matchBeyondTheStreamingCap_isFoundInsideAnArchiveToo() async throws {
        let payload = dir.appendingPathComponent("payload")
        let inner = payload.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)

        // 20 MB of filler, then the needle: past the cap, but only just, so the fixture
        // stays cheap to build.
        var big = Data(String(repeating: "hay hay hay hay\n", count: 1_310_720).utf8)
        big.append(Data("the needle is here\n".utf8))
        try big.write(to: inner.appendingPathComponent("late.log"))

        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-r", "-q", "-0", dir.appendingPathComponent("logs.zip").path, "inner"]
        p.currentDirectoryURL = payload
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        // Keep a copy on disk as the control: both must answer the same.
        try FileManager.default.moveItem(at: inner.appendingPathComponent("late.log"),
                                         to: dir.appendingPathComponent("ondisk.log"))
        try? FileManager.default.removeItem(at: payload)

        let hits = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                             contentText: "the needle is here",
                                             searchArchives: true))
        XCTAssertTrue(hits.contains { $0.hasSuffix("ondisk.log") },
                      "control: the loose file must match — \(hits)")
        XCTAssertTrue(hits.contains { $0.contains("logs.zip") && $0.hasSuffix("late.log") },
                      "a match past 16 MB inside an archive was missed: \(hits)")
    }

    /// A background walk prefers a backend that can seek over one that spawns a process
    /// per member — the difference between reading a 5,000-member tarball once and
    /// re-scanning it 5,000 times.
    func test_backgroundOpen_prefersTheSeekableBackend() async throws {
        try makeTar(named: "some.tar.gz", content: "needle\n")
        let registry = ArchiveRegistry(backends: [ProcessPerMemberBackend(), NativeArchiveBackend()])
        await registry.refresh()

        let outcome = await registry.open(fs: LocalFS(),
                                          path: dir.appendingPathComponent("some.tar.gz").path,
                                          intent: .background)
        guard case .opened(let opened, _) = outcome else { return XCTFail("did not open") }
        XCTAssertEqual(opened.backendID, "native", "a walk must not take the per-member backend")
        XCTAssertEqual(opened.memberAccessCost, .cheapRandomAccess)
    }

    /// Interactive keeps the declared order: a plugin the user installed for a format wins.
    func test_interactiveOpen_keepsBackendOrder() async throws {
        try makeTar(named: "some.tar.gz", content: "needle\n")
        let registry = ArchiveRegistry(backends: [ProcessPerMemberBackend(), NativeArchiveBackend()])
        await registry.refresh()

        let outcome = await registry.open(fs: LocalFS(),
                                          path: dir.appendingPathComponent("some.tar.gz").path,
                                          intent: .interactive)
        guard case .opened(let opened, _) = outcome else { return XCTFail("did not open") }
        XCTAssertEqual(opened.backendID, "slow-stand-in")
    }
}

/// Stands in for a plugin: opens the same archives, but a member costs a subprocess.
private struct ProcessPerMemberBackend: ArchiveBackend {
    let backendID = "slow-stand-in"
    func nameSet() async -> ArchiveNameSet { NativeArchiveBackend.nameSet }
    var staticNameSet: ArchiveNameSet { NativeArchiveBackend.nameSet }
    func open(localFile: URL, intent: ArchiveOpenIntent) async -> ArchiveOpenOutcome {
        guard let fs = ArchiveFS(archiveFileURL: localFile, fsID: "slow:\(localFile.path)") else {
            return .notAnArchive
        }
        return .opened(OpenedArchive(fs: fs, localURL: localFile, isTemporary: false,
                                     memberAccessCost: .processPerMember, backendID: backendID),
                       dispose: {})
    }
}
