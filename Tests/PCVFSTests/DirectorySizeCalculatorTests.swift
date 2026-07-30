// DirectorySizeCalculatorTests.swift - Unit tests for DirectorySizeCalculator

import XCTest
@testable import PCVFS

final class DirectorySizeCalculatorTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DirectorySizeCalculatorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        tempRoot = root
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        tempRoot = nil
        try super.tearDownWithError()
    }

    /// Writes a file of exactly `byteCount` bytes at `relativePath` under `tempRoot`,
    /// creating any intermediate directories as needed.
    @discardableResult
    private func writeFile(_ relativePath: String, byteCount: Int) throws -> URL {
        let url = tempRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = Data(repeating: 0x41, count: byteCount)
        try data.write(to: url)
        return url
    }

    // MARK: - Basic size computation

    func testSize_flatDirectory_sumsFileSizes() async throws {
        try writeFile("a.txt", byteCount: 10)
        try writeFile("b.txt", byteCount: 25)
        try writeFile("c.txt", byteCount: 7)

        let calculator = DirectorySizeCalculator()
        let total = await calculator.size(of: tempRoot.path)

        XCTAssertEqual(total, 42)
    }

    func testSize_nestedSubdirectories_sumsRecursively() async throws {
        try writeFile("top.bin", byteCount: 100)
        try writeFile("subA/inA.bin", byteCount: 50)
        try writeFile("subA/nested/deep.bin", byteCount: 33)
        try writeFile("subB/inB.bin", byteCount: 17)

        let calculator = DirectorySizeCalculator()
        let total = await calculator.size(of: tempRoot.path)

        XCTAssertEqual(total, 100 + 50 + 33 + 17)
    }

    func testSize_emptyDirectory_isZero() async throws {
        let calculator = DirectorySizeCalculator()
        let total = await calculator.size(of: tempRoot.path)

        XCTAssertEqual(total, 0)
    }

    func testSize_nonExistentPath_isZero() async throws {
        let calculator = DirectorySizeCalculator()
        let missing = tempRoot.appendingPathComponent("does-not-exist").path
        let total = await calculator.size(of: missing)

        XCTAssertEqual(total, 0)
    }

    // MARK: - Caching

    func testSize_calledTwice_returnsSameValueFromCache() async throws {
        try writeFile("file.bin", byteCount: 64)

        let calculator = DirectorySizeCalculator()
        let first = await calculator.size(of: tempRoot.path)
        let second = await calculator.size(of: tempRoot.path)

        XCTAssertEqual(first, 64)
        XCTAssertEqual(second, 64)
    }

    func testSize_afterDirectoryContentsChange_recomputes() async throws {
        try writeFile("file.bin", byteCount: 64)

        let calculator = DirectorySizeCalculator()
        let before = await calculator.size(of: tempRoot.path)
        XCTAssertEqual(before, 64)

        // Adding a file changes the directory's own mtime, invalidating the cache
        // entry without an explicit invalidate() call.
        try writeFile("another.bin", byteCount: 36)

        let after = await calculator.size(of: tempRoot.path)
        XCTAssertEqual(after, 100)
    }

    func testInvalidate_forcesRecomputationEvenWithoutMtimeChange() async throws {
        try writeFile("file.bin", byteCount: 10)

        let calculator = DirectorySizeCalculator()
        let first = await calculator.size(of: tempRoot.path)
        XCTAssertEqual(first, 10)

        await calculator.invalidate(tempRoot.path)

        // Cache entry gone: recomputing still yields the same (correct) answer.
        let second = await calculator.size(of: tempRoot.path)
        XCTAssertEqual(second, 10)
    }

    func testInvalidateAll_clearsEveryCachedPath() async throws {
        let dirA = tempRoot.appendingPathComponent("dirA")
        let dirB = tempRoot.appendingPathComponent("dirB")
        try writeFile("dirA/a.bin", byteCount: 5)
        try writeFile("dirB/b.bin", byteCount: 9)

        let calculator = DirectorySizeCalculator()
        _ = await calculator.size(of: dirA.path)
        _ = await calculator.size(of: dirB.path)

        await calculator.invalidateAll()

        let sizeA = await calculator.size(of: dirA.path)
        let sizeB = await calculator.size(of: dirB.path)
        XCTAssertEqual(sizeA, 5)
        XCTAssertEqual(sizeB, 9)
    }

    // MARK: - Symlink safety

    func testSize_symlinkToOutsideDirectory_isNotDescendedIntoOrCounted() async throws {
        // "outside" sits alongside the tree we measure and contains a large file that
        // must never be counted, and must never cause infinite recursion via a cycle.
        let outside = tempRoot.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 999).write(to: outside.appendingPathComponent("big.bin"))

        let measured = tempRoot.appendingPathComponent("measured")
        try writeFile("measured/real.bin", byteCount: 20)

        // Symlink inside the measured tree pointing out to "outside".
        try FileManager.default.createSymbolicLink(
            atPath: measured.appendingPathComponent("link-to-outside").path,
            withDestinationPath: outside.path
        )

        // Symlink that points back at an ancestor (self-cycle risk).
        try FileManager.default.createSymbolicLink(
            atPath: measured.appendingPathComponent("link-to-parent").path,
            withDestinationPath: tempRoot.path
        )

        let calculator = DirectorySizeCalculator()
        let total = await calculator.size(of: measured.path)

        XCTAssertEqual(total, 20, "symlinked directories must be skipped, not descended into")
    }

    func testSize_symlinkToFile_isNotCounted() async throws {
        try writeFile("real.bin", byteCount: 15)
        try FileManager.default.createSymbolicLink(
            atPath: tempRoot.appendingPathComponent("link-to-real.bin").path,
            withDestinationPath: tempRoot.appendingPathComponent("real.bin").path
        )

        let calculator = DirectorySizeCalculator()
        let total = await calculator.size(of: tempRoot.path)

        XCTAssertEqual(total, 15)
    }

    // MARK: - Batch sizes(of:)

    func testSizesOfBatch_computesEachDirectoryIndependently() async throws {
        try writeFile("one/a.bin", byteCount: 10)
        try writeFile("two/b.bin", byteCount: 20)
        try writeFile("two/nested/c.bin", byteCount: 5)
        try writeFile("three/d.bin", byteCount: 30)

        let one = tempRoot.appendingPathComponent("one").path
        let two = tempRoot.appendingPathComponent("two").path
        let three = tempRoot.appendingPathComponent("three").path

        let calculator = DirectorySizeCalculator()
        let results = await calculator.sizes(of: [one, two, three], maxConcurrency: 2)

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[one], 10)
        XCTAssertEqual(results[two], 25)
        XCTAssertEqual(results[three], 30)
    }

    func testSizesOfBatch_emptyInput_returnsEmptyMap() async {
        let calculator = DirectorySizeCalculator()
        let results = await calculator.sizes(of: [], maxConcurrency: 4)

        XCTAssertTrue(results.isEmpty)
    }

    func testSizesOfBatch_defaultConcurrency_matchesExplicitResults() async throws {
        try writeFile("dirX/x.bin", byteCount: 3)
        try writeFile("dirY/y.bin", byteCount: 4)

        let dirX = tempRoot.appendingPathComponent("dirX").path
        let dirY = tempRoot.appendingPathComponent("dirY").path

        let calculator = DirectorySizeCalculator()
        let results = await calculator.sizes(of: [dirX, dirY])

        XCTAssertEqual(results[dirX], 3)
        XCTAssertEqual(results[dirY], 4)
    }
}
