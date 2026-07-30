// PathNormalizationTests.swift - Unicode NFC/NFD name handling (F-100).

import XCTest
@testable import PCFoundation

final class PathNormalizationTests: XCTestCase {
    // "café" as precomposed (U+00E9) vs decomposed ("e" + U+0301).
    private let nfc = "caf\u{00E9}"
    private let nfd = "cafe\u{0301}"

    func testNormalizedProducesNFC() {
        XCTAssertEqual(PathUtils.normalized(nfd), nfc)
        XCTAssertEqual(PathUtils.normalized(nfc), nfc)
    }

    func testDecomposedProducesNFD() {
        XCTAssertEqual(PathUtils.decomposed(nfc), nfd)
    }

    func testNameEquivalentAcrossComposition() {
        // The two encodings must be treated as the same name (the fix applied to
        // panel name lookup, F-100).
        XCTAssertTrue(PathUtils.nameEquivalent(nfc, nfd))
        XCTAssertTrue(PathUtils.nameEquivalent(nfd, nfc))
    }

    func testNameEquivalentDoesNotFoldDiacritics() {
        // Normalization must not strip accents: "café" != "cafe".
        XCTAssertFalse(PathUtils.nameEquivalent(nfc, "cafe"))
    }

    func testNormalizationPreservesInformation() {
        // Round-tripping NFD → NFC → NFD is stable and lossless.
        XCTAssertEqual(PathUtils.decomposed(PathUtils.normalized(nfd)), nfd)
    }

    // MARK: - Colon/slash mapping (F-100)

    func testColonSlashMapping() {
        // POSIX ":" is shown to the user as "/"; a user-typed "/" is stored as ":".
        XCTAssertEqual(PathUtils.displayName(fromPOSIX: "12:31:2024"), "12/31/2024")
        XCTAssertEqual(PathUtils.posixName(fromDisplay: "12/31/2024"), "12:31:2024")
        // Round-trip.
        XCTAssertEqual(PathUtils.posixName(fromDisplay: PathUtils.displayName(fromPOSIX: "a:b")), "a:b")
        XCTAssertEqual(PathUtils.displayName(fromPOSIX: PathUtils.posixName(fromDisplay: "a/b")), "a/b")
        // Names without the special char are unchanged.
        XCTAssertEqual(PathUtils.displayName(fromPOSIX: "plain.txt"), "plain.txt")
        XCTAssertEqual(PathUtils.posixName(fromDisplay: "plain.txt"), "plain.txt")
    }

    // MARK: - Long names near the component limit round-trip (F-100)

    func testLongComponentNameRoundTrip() throws {
        // A single very long filename component (near NAME_MAX) must round-trip.
        // (Whole paths beyond the OS PATH_MAX/1024 syscall limit still require
        // openat-based traversal — tracked as remaining F-100 work.)
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("pc-longname-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let longName = String(repeating: "n", count: 200) + ".txt"
        let file = root.appendingPathComponent(longName)
        let payload = Data("long name payload".utf8)
        try payload.write(to: file)
        XCTAssertEqual(try Data(contentsOf: file), payload)
        XCTAssertTrue(fm.fileExists(atPath: file.path))
    }
}
