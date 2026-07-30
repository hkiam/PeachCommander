// ZipCryptoTests.swift - Reading traditional-ZipCrypto (password) archives,
// built on the fly with `/usr/bin/zip -P` (F-136).

import XCTest
@testable import PCArchive

final class ZipCryptoTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard FileManager.default.fileExists(atPath: "/usr/bin/zip") else {
            throw XCTSkip("/usr/bin/zip is not available on this machine")
        }
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchive-ZipCryptoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        tempDir = nil
        try super.tearDownWithError()
    }

    /// Build a classic password-protected zip (`zip -P <password>`), returning its URL.
    private func makeEncryptedZip(password: String, files: [String: Data]) throws -> URL {
        let payloadDir = tempDir.appendingPathComponent("payload", isDirectory: true)
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)
        for (name, data) in files {
            let url = payloadDir.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        let zipURL = tempDir.appendingPathComponent("secret.zip")
        let names = try FileManager.default.contentsOfDirectory(atPath: payloadDir.path).sorted()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-r", "-P", password, zipURL.path] + names
        p.currentDirectoryURL = payloadDir
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0, "zip tool exited non-zero")
        return zipURL
    }

    func test_encryptedEntry_isFlagged() throws {
        let url = try makeEncryptedZip(password: "hunter2", files: ["a.txt": Data("hello world".utf8)])
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "a.txt" })
        XCTAssertTrue(entry.isEncrypted)
    }

    func test_correctPassword_roundTrips() throws {
        // A deflate-compressible payload so we exercise decrypt → inflate.
        let content = Data(String(repeating: "The quick brown fox. ", count: 500).utf8)
        let url = try makeEncryptedZip(password: "s3cr3t", files: ["doc.txt": content])
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "doc.txt" })
        let out = try reader.data(for: entry, password: "s3cr3t")
        XCTAssertEqual(out, content)
    }

    func test_missingPassword_throwsPasswordRequired() throws {
        let url = try makeEncryptedZip(password: "pw", files: ["a.txt": Data("x".utf8)])
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "a.txt" })
        XCTAssertThrowsError(try reader.data(for: entry)) { error in
            XCTAssertEqual(error as? ZipError, .passwordRequired)
        }
    }

    func test_wrongPassword_throwsWrongPassword() throws {
        let url = try makeEncryptedZip(password: "correct", files: ["a.txt": Data("payload".utf8)])
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "a.txt" })
        XCTAssertThrowsError(try reader.data(for: entry, password: "wrong")) { error in
            XCTAssertEqual(error as? ZipError, .wrongPassword)
        }
    }
}
