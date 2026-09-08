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

    // MARK: - Streamed, and still byte-for-byte the same

    /// Bigger than one read chunk and not a multiple of anything, so the group and line boundaries
    /// fall inside the stream rather than at its ends. The engine used to hold the whole file, a
    /// string a third larger again, and a copy of that string as bytes.
    func test_aFileLargerThanOneChunkRoundTripsThroughTheStreamingPath() async throws {
        let count = 300 * 1024 + 7
        var original = Data(capacity: count)
        for i in 0..<count { original.append(UInt8((i * 31 + 17) % 251)) }
        let src = dir.appendingPathComponent("big.bin")
        try original.write(to: src)
        let encoded = dir.appendingPathComponent("big.b64")
        let back = dir.appendingPathComponent("big.out")

        try await EncodeDecodeEngine.encodeBase64(vpath("big.bin"), to: vpath("big.b64"), on: fs)
        // The same bytes the whole-buffer encoder would have produced — the format is the contract.
        XCTAssertEqual(try Data(contentsOf: encoded),
                       Data(Base64Codec.encode(original, wrap: true).utf8))

        try await EncodeDecodeEngine.decodeBase64(vpath("big.b64"), to: vpath("big.out"), on: fs)
        XCTAssertEqual(try Data(contentsOf: back), original)
    }

    /// The scheme is decided from the head of the file now, so each branch has to still be reached.
    func test_decodeAutoStillPicksTheRightSchemeFromTheHead() async throws {
        let cases: [(name: String, body: String, expected: String)] = [
            ("a.b64", Base64Codec.encode(Data("hello base64".utf8), wrap: true), "hello base64"),
            ("a.hex", "68656c6c6f20686578", "hello hex"),
        ]
        for c in cases {
            let src = dir.appendingPathComponent(c.name)
            try Data(c.body.utf8).write(to: src)
            let out = dir.appendingPathComponent(c.name + ".out")
            try await EncodeDecodeEngine.decodeAuto(vpath(c.name), to: vpath(c.name + ".out"), on: fs)
            XCTAssertEqual(try String(contentsOf: out, encoding: .utf8), c.expected, c.name)
        }
    }

    /// A hex payload with an odd number of digits is half a byte short, and refused — the same answer
    /// the whole-buffer `decodeHex` gave.
    func test_anOddNumberOfHexDigitsIsRefused() async throws {
        let src = dir.appendingPathComponent("odd.hex")
        try Data("68656c6c6".utf8).write(to: src)
        do {
            try await EncodeDecodeEngine.decodeAuto(vpath("odd.hex"), to: vpath("odd.out"), on: fs)
            XCTFail("half a byte was accepted")
        } catch {
            XCTAssertEqual(error as? EncodeDecodeError, .notValidBase64)
        }
    }

    // MARK: - uu/xx goes through the same streaming path as the rest

    /// The format is the contract: what the streaming encoder writes to a file has to be exactly
    /// what the whole-buffer codec would have produced, and `test_uu_matchesSystemUuencode` pins
    /// that against the system tool.
    func test_aLargeFileUUEncodesThroughTheStreamingPath() async throws {
        let count = 300 * 1024 + 7
        var original = Data(capacity: count)
        for i in 0..<count { original.append(UInt8((i * 31 + 17) % 251)) }
        try original.write(to: dir.appendingPathComponent("big.bin"))

        try await EncodeDecodeEngine.encodeUUXX(vpath("big.bin"), to: vpath("big.uue"),
                                                on: fs, variant: .uu)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("big.uue")),
                       Data(UUCodec.encode(original, variant: .uu, filename: "big.bin").utf8))

        try await EncodeDecodeEngine.decodeAuto(vpath("big.uue"), to: vpath("big.out"), on: fs)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("big.out")), original)
    }

    /// The two variants share the `begin` frame and differ only in the alphabet, so the streaming
    /// decoder has to settle which one it is *before* it starts — it cannot try one and fall back
    /// halfway through a file the way the whole-text version did. Decided from the head; both
    /// answers have to be right.
    func test_decodeAutoTellsUUFromXX() async throws {
        let payload = Data((0..<4000).map { UInt8(($0 * 13 + 5) & 0xFF) })
        for (variant, name) in [(UUCodec.Variant.uu, "p.uue"), (.xx, "p.xxe")] {
            try Data(UUCodec.encode(payload, variant: variant, filename: "p.bin").utf8)
                .write(to: dir.appendingPathComponent(name))
            try await EncodeDecodeEngine.decodeAuto(vpath(name), to: vpath(name + ".out"), on: fs)
            XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(name + ".out")), payload,
                           "\(variant) was decoded with the wrong alphabet")
        }
    }

    /// And a `begin` frame whose payload is neither is refused rather than written out empty.
    func test_aBeginFrameWithAnUnreadablePayloadIsRefused() async throws {
        try Data("begin 644 f.bin\n\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\n`\nend\n".utf8)
            .write(to: dir.appendingPathComponent("bad.uue"))
        do {
            try await EncodeDecodeEngine.decodeAuto(vpath("bad.uue"), to: vpath("bad.out"), on: fs)
            XCTFail("an unreadable uu/xx payload was accepted")
        } catch {
            XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("bad.out").path),
                           "a target was left behind for a payload that could not be decoded")
        }
    }

    /// "Streamed" is not shown by the output — the bytes are identical either way, which is the
    /// point. What shows it is how the output arrived: a filesystem that tallies every write sees
    /// several bounded ones from a streaming encoder and one big one from an encoder that built the
    /// whole text first. This guards all four schemes against quietly going back to reading whole
    /// files.
    ///
    /// Three megabytes, and the size is the measurement rather than a round number:
    /// `LocalReadStream` reads in 1 MiB chunks, so anything smaller than that arrives in one piece
    /// and is written in one piece by a perfectly streaming encoder. Measured — at 300 KB this test
    /// failed while the code was doing exactly what it should.
    func test_everySchemeWritesItsOutputInPieces() async throws {
        let count = 3 * 1024 * 1024 + 7
        var original = Data(capacity: count)
        for i in 0..<count { original.append(UInt8((i * 31 + 17) % 251)) }
        try original.write(to: dir.appendingPathComponent("big.bin"))

        for (name, encode) in [
            ("big.b64", { (t: TallyFS) in
                try await EncodeDecodeEngine.encodeBase64(self.vpath("big.bin"),
                                                          to: self.vpath("big.b64"), on: t) }),
            ("big.uue", { (t: TallyFS) in
                try await EncodeDecodeEngine.encodeUUXX(self.vpath("big.bin"),
                                                        to: self.vpath("big.uue"), on: t,
                                                        variant: .uu) }),
        ] {
            let tally = TallyFS()
            try await encode(tally)
            XCTAssertGreaterThan(tally.writes, 3, "\(name) was written in one piece")
            XCTAssertLessThan(tally.largestWrite, count,
                              "\(name) held the whole encoding in one write")
        }
    }
}


/// Forwards everything to the real filesystem and counts how the writes arrived.
///
/// The tally is the measurement: an encoder that reads its input whole produces one write, and one
/// that streams produces many. Nothing about the resulting file can tell those apart.
private final class TallyFS: VirtualFileSystem, @unchecked Sendable {
    private let inner = LocalFS()
    private let lock = NSLock()
    private var _writes = 0
    private var _largest = 0
    var writes: Int { lock.lock(); defer { lock.unlock() }; return _writes }
    var largestWrite: Int { lock.lock(); defer { lock.unlock() }; return _largest }

    var scheme: String { inner.scheme }
    var capabilities: VFSCapabilities { inner.capabilities }

    private func note(_ n: Int) {
        lock.lock(); _writes += 1; _largest = Swift.max(_largest, n); lock.unlock()
    }

    private struct Counting: VFSWriteStream {
        let inner: VFSWriteStream
        let note: @Sendable (Int) -> Void
        func write(_ data: Data) async throws { note(data.count); try await inner.write(data) }
        func close() async throws { try await inner.close() }
    }

    func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> { inner.list(dir) }
    func stat(_ path: VFSPath) async throws -> VFSEntry { try await inner.stat(path) }
    func openRead(_ path: VFSPath) async throws -> VFSReadStream { try await inner.openRead(path) }
    func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        Counting(inner: try await inner.openWrite(path, options: options),
                 note: { [weak self] in self?.note($0) })
    }
    func mkdir(_ path: VFSPath) async throws { try await inner.mkdir(path) }
    func delete(_ path: VFSPath) async throws { try await inner.delete(path) }
    func rename(_ from: VFSPath, to: VFSPath) async throws { try await inner.rename(from, to: to) }
    func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {
        try await inner.setAttributes(path, attributes: attributes)
    }
    func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { inner.watch(dir) }
    func localFileIfAvailable(_ path: VFSPath) async throws -> URL? {
        try await inner.localFileIfAvailable(path)
    }
}
