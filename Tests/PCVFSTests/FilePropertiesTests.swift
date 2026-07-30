// FilePropertiesTests.swift - Unit tests for the pure FileProperties model/reader (I03-T07)

import XCTest
@testable import PCVFS

final class FilePropertiesTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FilePropertiesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - Regular file

    func testRegularFile_sizeMatchesContent() throws {
        let fileURL = tempDir.appendingPathComponent("hello.txt")
        let data = Data("Hello, Peach Commander!".utf8)
        try data.write(to: fileURL)

        let props = FilePropertiesReader.read(path: fileURL.path)

        XCTAssertEqual(props.byteSize, Int64(data.count))
        XCTAssertFalse(props.sizeText.isEmpty)
        XCTAssertNotEqual(props.sizeText, "—")
    }

    func testRegularFile_isNotDirectoryOrSymlink() throws {
        let fileURL = tempDir.appendingPathComponent("plain.txt")
        try Data("x".utf8).write(to: fileURL)

        let props = FilePropertiesReader.read(path: fileURL.path)

        XCTAssertFalse(props.isDirectory)
        XCTAssertFalse(props.isSymbolicLink)
        XCTAssertNil(props.symlinkTarget)
    }

    func testRegularFile_nameAndPath() throws {
        let fileURL = tempDir.appendingPathComponent("named-file.dat")
        try Data("data".utf8).write(to: fileURL)

        let props = FilePropertiesReader.read(path: fileURL.path)

        XCTAssertEqual(props.name, "named-file.dat")
        XCTAssertEqual(props.path, fileURL.path)
    }

    func testRegularFile_kindDescriptionIsNonEmpty() throws {
        let fileURL = tempDir.appendingPathComponent("readme.txt")
        try Data("content".utf8).write(to: fileURL)

        let props = FilePropertiesReader.read(path: fileURL.path)

        XCTAssertFalse(props.kindDescription.isEmpty)
    }

    func testRegularFile_permissionsTextStartsWithDash() throws {
        let fileURL = tempDir.appendingPathComponent("perms.txt")
        try Data("x".utf8).write(to: fileURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: fileURL.path
        )

        let props = FilePropertiesReader.read(path: fileURL.path)

        XCTAssertEqual(props.permissionsText.count, 10)
        XCTAssertTrue(props.permissionsText.hasPrefix("-"))
        XCTAssertEqual(props.permissionsText, "-rw-r--r--")
    }

    func testRegularFile_modifiedDateIsRecent() throws {
        let fileURL = tempDir.appendingPathComponent("dated.txt")
        try Data("x".utf8).write(to: fileURL)

        let props = FilePropertiesReader.read(path: fileURL.path)

        let modified = try XCTUnwrap(props.modified)
        XCTAssertLessThan(abs(modified.timeIntervalSinceNow), 60)
    }

    // MARK: - Directory

    func testDirectory_byteSizeIsUnknown() throws {
        let dirURL = tempDir.appendingPathComponent("subdir", isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let props = FilePropertiesReader.read(path: dirURL.path)

        XCTAssertEqual(props.byteSize, -1)
        XCTAssertEqual(props.sizeText, "—")
    }

    func testDirectory_isDirectoryTrueAndPermissionTypeIsD() throws {
        let dirURL = tempDir.appendingPathComponent("adir", isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let props = FilePropertiesReader.read(path: dirURL.path)

        XCTAssertTrue(props.isDirectory)
        XCTAssertFalse(props.isSymbolicLink)
        XCTAssertTrue(props.permissionsText.hasPrefix("d"))
        XCTAssertEqual(props.permissionsText.count, 10)
    }

    func testDirectory_kindDescriptionIsFolder() throws {
        let dirURL = tempDir.appendingPathComponent("folder1", isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let props = FilePropertiesReader.read(path: dirURL.path)

        XCTAssertEqual(props.kindDescription, "Folder")
    }

    // MARK: - Symbolic link

    func testSymlink_isSymbolicLinkAndHasTarget() throws {
        let targetURL = tempDir.appendingPathComponent("target.txt")
        try Data("target contents".utf8).write(to: targetURL)

        let linkURL = tempDir.appendingPathComponent("link-to-target.txt")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        let props = FilePropertiesReader.read(path: linkURL.path)

        XCTAssertTrue(props.isSymbolicLink)
        XCTAssertEqual(props.symlinkTarget, targetURL.path)
    }

    func testSymlink_permissionTypeIsL() throws {
        let targetURL = tempDir.appendingPathComponent("target2.txt")
        try Data("x".utf8).write(to: targetURL)

        let linkURL = tempDir.appendingPathComponent("link2.txt")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        let props = FilePropertiesReader.read(path: linkURL.path)

        XCTAssertTrue(props.permissionsText.hasPrefix("l"))
        XCTAssertEqual(props.permissionsText.count, 10)
    }

    func testSymlink_kindDescriptionIsSymbolicLink() throws {
        let targetURL = tempDir.appendingPathComponent("target3.txt")
        try Data("x".utf8).write(to: targetURL)

        let linkURL = tempDir.appendingPathComponent("link3.txt")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        let props = FilePropertiesReader.read(path: linkURL.path)

        XCTAssertEqual(props.kindDescription, "Symbolic Link")
    }

    func testSymlink_toDirectory_reportsTargetIsDirectory() throws {
        let targetDirURL = tempDir.appendingPathComponent("target-dir", isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirURL, withIntermediateDirectories: true)

        let linkURL = tempDir.appendingPathComponent("link-to-dir")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetDirURL)

        let props = FilePropertiesReader.read(path: linkURL.path)

        XCTAssertTrue(props.isSymbolicLink)
        XCTAssertTrue(props.isDirectory)
        XCTAssertTrue(props.permissionsText.hasPrefix("l"))
    }

    // MARK: - Equatable

    func testFileProperties_equatable() throws {
        let fileURL = tempDir.appendingPathComponent("eq.txt")
        try Data("x".utf8).write(to: fileURL)

        let a = FilePropertiesReader.read(path: fileURL.path)
        let b = FilePropertiesReader.read(path: fileURL.path)

        XCTAssertEqual(a, b)
    }
}
