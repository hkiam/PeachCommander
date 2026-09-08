// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCOperations
import PCFoundation
import PCVFS

final class EncodeDecodeEngineTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-enc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func vpath(_ name: String) -> VFSPath { VFSPath(filesystemId: "file", path: dir.appendingPathComponent(name).path) }

    func testEncodeThenDecodeRoundTrip() async throws {
        let original = Data((0..<5000).map { UInt8(($0 * 7) & 0xFF) })
        try original.write(to: dir.appendingPathComponent("in.bin"))
        try await EncodeDecodeEngine.encodeBase64(vpath("in.bin"), to: vpath("in.bin.b64"), on: fs)
        try await EncodeDecodeEngine.decodeBase64(vpath("in.bin.b64"), to: vpath("out.bin"), on: fs)
        let out = try Data(contentsOf: dir.appendingPathComponent("out.bin"))
        XCTAssertEqual(out, original)
    }

    func testEncodedFileMatchesCodec() async throws {
        try Data("hello world".utf8).write(to: dir.appendingPathComponent("h.txt"))
        try await EncodeDecodeEngine.encodeBase64(vpath("h.txt"), to: vpath("h.b64"), on: fs, wrap: false)
        let encoded = try String(contentsOf: dir.appendingPathComponent("h.b64"), encoding: .utf8)
        XCTAssertEqual(encoded, "aGVsbG8gd29ybGQ=")
    }

    func testDecodeInvalidThrows() async throws {
        try Data("@@@ not base64 @@@".utf8).write(to: dir.appendingPathComponent("bad.b64"))
        do {
            try await EncodeDecodeEngine.decodeBase64(vpath("bad.b64"), to: vpath("out.bin"), on: fs)
            XCTFail("expected decode failure")
        } catch EncodeDecodeError.notValidBase64 {
            // expected
        }
    }

    // MARK: - Nothing is written over unasked

    /// The command drops a known encoded extension, so `report.txt.b64` targets `report.txt` — the
    /// file it was made from, still sitting next to it. That made replacing an existing file the
    /// ordinary outcome rather than an unlucky one, and it happened without a word. Measured.
    func test_decodingRefusesToReplaceAnExistingFileUnlessTold() async throws {
        let plain = dir.appendingPathComponent("report.txt")
        let stranger = "SOMEBODY ELSE'S FILE"
        try Data(stranger.utf8).write(to: plain)
        let encoded = dir.appendingPathComponent("payload.b64")
        try Data("aGVsbG8=".utf8).write(to: encoded)          // "hello"

        let src = VFSPath(filesystemId: "file", path: encoded.path)
        let dst = VFSPath(filesystemId: "file", path: plain.path)
        do {
            try await EncodeDecodeEngine.decodeBase64(src, to: dst, on: fs)
            XCTFail("the existing file was replaced without being asked about")
        } catch {
            XCTAssertEqual(error as? EncodeDecodeError, .targetExists("report.txt"))
        }
        XCTAssertEqual(try String(contentsOf: plain, encoding: .utf8), stranger)

        // And with permission it does replace it — that is what the caller's dialog answers.
        try await EncodeDecodeEngine.decodeBase64(src, to: dst, on: fs, overwrite: true)
        XCTAssertEqual(try String(contentsOf: plain, encoding: .utf8), "hello")
    }

    /// `decodeAuto` asks once, up front, rather than once per branch of its scheme detection.
    func test_decodeAutoRefusesAnExistingTargetWhateverTheScheme() async throws {
        let plain = dir.appendingPathComponent("out.bin")
        try Data("keep me".utf8).write(to: plain)
        for (name, body) in [("a.b64", "aGVsbG8="), ("a.hex", "68656c6c6f")] {
            let encoded = dir.appendingPathComponent(name)
            try Data(body.utf8).write(to: encoded)
            do {
                try await EncodeDecodeEngine.decodeAuto(
                    VFSPath(filesystemId: "file", path: encoded.path),
                    to: VFSPath(filesystemId: "file", path: plain.path), on: fs)
                XCTFail("\(name): the existing file was replaced")
            } catch {
                XCTAssertEqual(error as? EncodeDecodeError, .targetExists("out.bin"), name)
            }
        }
        XCTAssertEqual(try String(contentsOf: plain, encoding: .utf8), "keep me")
    }

    /// A fresh target still writes without a question — the guard must refuse one thing only.
    func test_decodingToANewNameNeedsNoPermission() async throws {
        let encoded = dir.appendingPathComponent("fresh.b64")
        try Data("aGVsbG8=".utf8).write(to: encoded)
        let out = dir.appendingPathComponent("fresh")
        try await EncodeDecodeEngine.decodeBase64(VFSPath(filesystemId: "file", path: encoded.path),
                                                  to: VFSPath(filesystemId: "file", path: out.path), on: fs)
        XCTAssertEqual(try String(contentsOf: out, encoding: .utf8), "hello")
    }
}
