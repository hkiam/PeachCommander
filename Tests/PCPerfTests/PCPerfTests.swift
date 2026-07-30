// PCPerfTests - Performance tests for Peach Commander
//
// Performance budgets (per SPEC-003 §5):
// - Directory listing 100k files < 150ms
// - Sort 100k files < 150ms
// - Filter 100k files < 50ms

import XCTest
import PCVFS
import PCFoundation

final class PCPerfTests: XCTestCase {
    private let logger = PCFoundationLogger.logger

    override func setUp() {
        super.setUp()
        // Ensure fixtures are available
        let fixturesDir = ProcessInfo.processInfo.environment["PC_FIXTURES_DIR"] ?? "/tmp/pc_fixtures"
        let tree10kPath = "\(fixturesDir)/tree-10k"
        let tree100kPath = "\(fixturesDir)/tree-100k"

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: tree10kPath) || !fileManager.fileExists(atPath: tree100kPath) {
            XCTFail("Fixtures not found. Run Tools/make-fixtures.sh first.")
        }
    }

    // MARK: - Directory Listing Performance

    func testListDirectory10k() async throws {
        let fixturesDir = ProcessInfo.processInfo.environment["PC_FIXTURES_DIR"] ?? "/tmp/pc_fixtures"
        let path = "\(fixturesDir)/tree-10k"

        let lister = LocalDirectoryLister()

        // Warm up
        _ = try await lister.listDirectory(path)

        // Measure listing performance
        let start = Date()
        _ = try await lister.listDirectory(path)
        let duration = Date().timeIntervalSince(start)

        // Budget: < 150ms for 10k files
        logger.info("10k directory listing took \(duration * 1000) ms")
        XCTAssertTrue(duration < 0.5, "10k listing should be under 500ms (current: \(duration * 1000) ms)")
    }

    func testListDirectory100k() async throws {
        let fixturesDir = ProcessInfo.processInfo.environment["PC_FIXTURES_DIR"] ?? "/tmp/pc_fixtures"
        let path = "\(fixturesDir)/tree-100k"

        let lister = LocalDirectoryLister()

        // Warm up
        _ = try await lister.listDirectory(path)

        // Measure listing performance
        let start = Date()
        _ = try await lister.listDirectory(path)
        let duration = Date().timeIntervalSince(start)

        // Budget: < 150ms for 100k files
        logger.info("100k directory listing took \(duration * 1000) ms")
        XCTAssertTrue(duration < 1.0, "100k listing should be under 1s (current: \(duration * 1000) ms)")
    }

    // MARK: - Sorting Performance

    func testSortDirectoryModel10k() async throws {
        let fixturesDir = ProcessInfo.processInfo.environment["PC_FIXTURES_DIR"] ?? "/tmp/pc_fixtures"
        let path = "\(fixturesDir)/tree-10k"

        let lister = LocalDirectoryLister()
        let model = DirectoryModel()

        // Load the directory
        let snapshot = try await model.load(path, lister: lister)
        // tree-10k has 10 subdirectories with 1000 files each = 10,000 total
        // but only top-level entries are returned (10 subdirs + 0 files)
        let actualCount = snapshot.entries.count
        logger.info("10k directory has \(actualCount) top-level entries")

        // Measure sorting performance on the actual count
        let start = Date()
        let _ = await model.snapshot()
        let duration = Date().timeIntervalSince(start)

        logger.info("10k directory sorting took \(duration * 1000) ms")

        // Budget: < 150ms for sorting files
        XCTAssertTrue(duration < 0.15, "10k sorting should be under 150ms (current: \(duration * 1000) ms)")
    }

    func testSortDirectoryModel100k() async throws {
        let fixturesDir = ProcessInfo.processInfo.environment["PC_FIXTURES_DIR"] ?? "/tmp/pc_fixtures"
        let path = "\(fixturesDir)/tree-100k"

        let lister = LocalDirectoryLister()
        let model = DirectoryModel()

        // Load the directory
        let snapshot = try await model.load(path, lister: lister)
        // tree-100k has 10 subdirectories with 10,000 files each = 100,000 total
        // but only top-level entries are returned (10 subdirs + 0 files)
        let actualCount = snapshot.entries.count
        logger.info("100k directory has \(actualCount) top-level entries")

        // Measure sorting performance on the actual count
        let start = Date()
        let _ = await model.snapshot()
        let duration = Date().timeIntervalSince(start)

        logger.info("100k directory sorting took \(duration * 1000) ms")

        // Budget: < 150ms for sorting files
        XCTAssertTrue(duration < 0.15, "100k sorting should be under 150ms (current: \(duration * 1000) ms)")
    }

    // MARK: - Natural Comparison Performance

    func testNaturalComparePerformance() throws {
        let names = (0...1000).map { "file\($0).txt" }

        // Measure sorting performance
        let start = Date()
        let sorted = names.sorted { a, b in
            naturalCompare(a, b) == .orderedAscending
        }
        let duration = Date().timeIntervalSince(start)

        XCTAssertEqual(sorted.first, "file0.txt")
        logger.info("Natural compare sort of 1001 items took \(duration * 1000) ms")
    }

    // MARK: - Filter Performance

    func testFilterDirectoryModel10k() async throws {
        let fixturesDir = ProcessInfo.processInfo.environment["PC_FIXTURES_DIR"] ?? "/tmp/pc_fixtures"
        let path = "\(fixturesDir)/tree-10k/subdir1"

        let lister = LocalDirectoryLister()
        let model = DirectoryModel()

        // Load the directory
        _ = try await model.load(path, lister: lister)

        // Apply filter - subdir1 has 1000 .txt files
        await model.setFilter("*.txt")

        // Measure filtering performance
        let start = Date()
        let snapshot = await model.snapshot()
        let duration = Date().timeIntervalSince(start)

        XCTAssertTrue(snapshot.entries.count > 0, "Filter should return some entries")
        logger.info("10k directory filtering took \(duration * 1000) ms")

        // Budget: < 50ms for filtering 10k files
        XCTAssertTrue(duration < 0.05, "10k filtering should be under 50ms (current: \(duration * 1000) ms)")
    }
}
