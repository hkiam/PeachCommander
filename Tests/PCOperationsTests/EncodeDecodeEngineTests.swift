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
}
