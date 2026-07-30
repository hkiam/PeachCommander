import XCTest
@testable import PCVFS

/// macOS Finder alias files (F-036) must list like symlinks: a symlinkDir/
/// symlinkFile kind with the resolved target in `linkTarget`, so the panel shows
/// the arrow badge and follows the alias on Enter.
final class AliasDetectionTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-alias-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func makeAlias(target: URL, named name: String) throws -> URL {
        let alias = dir.appendingPathComponent(name)
        let bm = try target.bookmarkData(options: .suitableForBookmarkFile,
                                         includingResourceValuesForKeys: nil, relativeTo: nil)
        try URL.writeBookmarkData(bm, to: alias)
        return alias
    }

    private func entries() async throws -> [VFSEntry] {
        var all: [VFSEntry] = []
        for try await batch in fs.list(LocalFS.path(dir.path)) { all.append(contentsOf: batch.entries) }
        return all
    }

    func testFolderAndFileAliasesListAsSymlinksWithTarget() async throws {
        let realFolder = dir.appendingPathComponent("RealFolder")
        try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
        let realFile = dir.appendingPathComponent("RealFile.txt")
        try "hi".data(using: .utf8)!.write(to: realFile)

        _ = try makeAlias(target: realFolder, named: "FolderAlias")
        _ = try makeAlias(target: realFile, named: "FileAlias")

        let byName = Dictionary(uniqueKeysWithValues: try await entries().map { ($0.name, $0) })

        // resolveAlias returns the fully resolved target (temp lives under the
        // /var → /private/var firmlink), so normalize that prefix before comparing.
        func norm(_ p: String) -> String { p.hasPrefix("/var/") ? "/private" + p : p }

        let folderAlias = try XCTUnwrap(byName["FolderAlias"])
        XCTAssertEqual(folderAlias.kind, .symlinkDir)
        XCTAssertEqual(folderAlias.linkTarget, norm(realFolder.path))

        let fileAlias = try XCTUnwrap(byName["FileAlias"])
        XCTAssertEqual(fileAlias.kind, .symlinkFile)
        XCTAssertEqual(fileAlias.linkTarget, norm(realFile.path))

        // A plain file must not be mistaken for an alias.
        XCTAssertEqual(try XCTUnwrap(byName["RealFile.txt"]).kind, .file)
        XCTAssertNil(byName["RealFile.txt"]?.linkTarget)
    }
}
