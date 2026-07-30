import XCTest
@testable import PCOperations
import PCFoundation

/// End-to-end proof that a copy carrying a `renameMask` (F-080) writes the
/// destination files under their masked names, through the real CopyEngine.
final class CopyMaskCopyTests: XCTestCase {
    private var root: URL!
    private var src: URL!
    private var dst: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pc-mask-\(UUID().uuidString)")
        src = root.appendingPathComponent("src")
        dst = root.appendingPathComponent("dst")
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func write(_ name: String, _ text: String) throws -> String {
        let p = src.appendingPathComponent(name)
        try text.data(using: .utf8)!.write(to: p)
        return p.path
    }

    func testCopyRenamesEachFileByMask() async throws {
        let a = try write("readme.txt", "A")
        let b = try write("notes.md", "B")
        var opts = CopyOptions()
        opts.renameMask = "*.bak"
        let engine = CopyEngine(options: opts, control: OperationControl(),
                                resolver: OverwriteAllResolver(), progress: { _ in })
        let processed = try await engine.run(items: [a, b], toDirectory: dst.path)

        XCTAssertEqual(processed.count, 2)
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: dst.appendingPathComponent("readme.bak").path))
        XCTAssertTrue(fm.fileExists(atPath: dst.appendingPathComponent("notes.bak").path))
        // Original names must NOT appear at the destination.
        XCTAssertFalse(fm.fileExists(atPath: dst.appendingPathComponent("readme.txt").path))
        // Content is intact.
        XCTAssertEqual(try String(contentsOf: dst.appendingPathComponent("readme.bak")), "A")
    }

    func testNilMaskKeepsOriginalNames() async throws {
        let a = try write("keep.txt", "K")
        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: OverwriteAllResolver(), progress: { _ in })
        _ = try await engine.run(items: [a], toDirectory: dst.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("keep.txt").path))
    }
}
