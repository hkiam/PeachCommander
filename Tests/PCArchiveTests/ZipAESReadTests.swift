// SPDX-License-Identifier: Apache-2.0
// ZipAESReadTests.swift - Reading WinZip AES (AE-2) encrypted zips created by 7z (F-136).

import XCTest
@testable import PCArchive

final class ZipAESReadTests: XCTestCase {
    private var dir: URL!
    private let sevenZip = "/opt/homebrew/bin/7z"

    override func setUpWithError() throws {
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: sevenZip), "7z not installed")
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("ZipAES-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    /// Build an AES-256 zip with `content` at `name` and return its URL.
    private func makeAESZip(name: String, content: Data, password: String, store: Bool = false) throws -> URL {
        let src = dir.appendingPathComponent("src"); try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try content.write(to: src.appendingPathComponent(name))
        let zipURL = dir.appendingPathComponent("aes.zip"); try? FileManager.default.removeItem(at: zipURL)
        let p = Process(); p.executableURL = URL(fileURLWithPath: sevenZip)
        p.arguments = ["a", "-tzip", "-mem=AES256", "-p\(password)"] + (store ? ["-mx=0"] : []) + ["-y", zipURL.path, name]
        p.currentDirectoryURL = src
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0)
        return zipURL
    }

    func test_aes256_deflated_roundTrips() throws {
        let content = Data(String(repeating: "The quick brown fox. ", count: 300).utf8)
        let url = try makeAESZip(name: "doc.txt", content: content, password: "geheim")
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "doc.txt" })
        XCTAssertTrue(entry.isEncrypted)
        XCTAssertEqual(try reader.data(for: entry, password: "geheim"), content)
    }

    func test_aes256_stored_roundTrips() throws {
        let content = Data("hello aes world\n".utf8)
        let url = try makeAESZip(name: "msg.txt", content: content, password: "pw", store: true)
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "msg.txt" })
        XCTAssertEqual(try reader.data(for: entry, password: "pw"), content)
    }

    func test_wrongPassword_throws() throws {
        let url = try makeAESZip(name: "a.txt", content: Data("secret".utf8), password: "right")
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "a.txt" })
        XCTAssertThrowsError(try reader.data(for: entry, password: "wrong")) {
            XCTAssertEqual($0 as? ZipError, .wrongPassword)
        }
    }

    func test_missingPassword_throwsPasswordRequired() throws {
        let url = try makeAESZip(name: "a.txt", content: Data("x".utf8), password: "pw")
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "a.txt" })
        XCTAssertThrowsError(try reader.data(for: entry)) {
            XCTAssertEqual($0 as? ZipError, .passwordRequired)
        }
    }

    // ArchiveFS.passwordIsValid drives the Keychain-remembered-password path (F-136).
    func test_archiveFS_passwordIsValid() throws {
        let url = try makeAESZip(name: "a.txt", content: Data("secret".utf8), password: "right")
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: url, fsID: "aes:1"))
        fs.password = "right"
        XCTAssertTrue(fs.passwordIsValid())
        fs.password = "wrong"
        XCTAssertFalse(fs.passwordIsValid())
    }

    func test_archiveFS_passwordIsValid_trueForUnencrypted() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let zip = dir.appendingPathComponent("plain.zip")
        try Data("plain content".utf8).write(to: dir.appendingPathComponent("f.txt"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-j", "-q", zip.path, dir.appendingPathComponent("f.txt").path]
        p.standardOutput = FileHandle.nullDevice; try p.run(); p.waitUntilExit()
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: zip, fsID: "plain:1"))
        XCTAssertTrue(fs.passwordIsValid())   // nothing encrypted → always valid
    }
}
