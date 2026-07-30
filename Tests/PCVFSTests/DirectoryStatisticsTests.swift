// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCVFS

final class DirectoryStatisticsTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pc-dirstats-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func write(_ rel: String, bytes: Int) throws {
        let url = root.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    func testCountsFilesFoldersAndBytesRecursively() async throws {
        try write("a.txt", bytes: 100)
        try write("b.bin", bytes: 200)
        try write("sub/c.txt", bytes: 50)
        try write("sub/deep/d.dat", bytes: 25)
        // sub and sub/deep are the two folders; 4 files; 375 bytes.
        let stats = await DirectoryStatistics().measure(root.path)
        XCTAssertEqual(stats.files, 4)
        XCTAssertEqual(stats.folders, 2)
        XCTAssertEqual(stats.totalBytes, 375)
        XCTAssertEqual(stats.name, root.lastPathComponent)
        XCTAssertEqual(stats.path, root.path)
    }

    func testEmptyDirectory() async throws {
        let stats = await DirectoryStatistics().measure(root.path)
        XCTAssertEqual(stats.files, 0)
        XCTAssertEqual(stats.folders, 0)
        XCTAssertEqual(stats.totalBytes, 0)
    }

    func testMissingDirectoryIsZero() async throws {
        let stats = await DirectoryStatistics().measure(root.appendingPathComponent("nope").path)
        XCTAssertEqual(stats, DirectoryStats(path: root.appendingPathComponent("nope").path,
                                             name: "nope", files: 0, folders: 0, totalBytes: 0))
    }

    func testSymlinkCountedAsFileNotFollowed() async throws {
        try write("real/big.bin", bytes: 1000)
        // A symlink to the 'real' directory must count as one file, not add 1000 bytes again.
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent("real"))
        let stats = await DirectoryStatistics().measure(root.path)
        XCTAssertEqual(stats.folders, 1)          // only 'real'
        XCTAssertEqual(stats.files, 2)            // big.bin + the symlink
        XCTAssertEqual(stats.totalBytes, 1000)    // symlink not followed
    }
}
