// SPDX-License-Identifier: Apache-2.0
// UUCodecTests.swift - Round-trip + cross-check for uuencode/xxencode (F-096).

import XCTest
@testable import PCFoundation

final class UUCodecTests: XCTestCase {
    private func roundTrip(_ data: Data, _ variant: UUCodec.Variant) {
        let text = UUCodec.encode(data, variant: variant, filename: "t.bin")
        let back = UUCodec.decode(text, variant: variant)
        XCTAssertEqual(back, data)
    }

    func test_uu_roundTrips_variousLengths() {
        for n in [0, 1, 2, 3, 44, 45, 46, 100, 1000] {
            roundTrip(Data((0..<n).map { UInt8($0 & 0xff) }), .uu)
        }
    }

    func test_xx_roundTrips_variousLengths() {
        for n in [1, 3, 45, 47, 256, 999] {
            roundTrip(Data((0..<n).map { UInt8(($0 * 7) & 0xff) }), .xx)
        }
    }

    func test_uu_hasBeginEndFrame() {
        let text = UUCodec.encode(Data("hi".utf8), variant: .uu, filename: "greeting.txt", mode: "644")
        XCTAssertTrue(text.hasPrefix("begin 644 greeting.txt\n"))
        XCTAssertTrue(text.hasSuffix("end\n"))
    }

    func test_uu_matchesSystemUuencode() throws {
        // Cross-check the encoder against /usr/bin/uuencode when available.
        guard FileManager.default.fileExists(atPath: "/usr/bin/uuencode") else {
            throw XCTSkip("/usr/bin/uuencode not available")
        }
        let payload = Data("The quick brown fox jumps over the lazy dog.\n".utf8)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = dir.appendingPathComponent("in.txt")
        try payload.write(to: input)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/uuencode")
        p.arguments = [input.path, "out.bin"]
        let pipe = Pipe(); p.standardOutput = pipe
        try p.run()
        let sysText = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        // Our decoder must read the system's uuencoded output back to the payload.
        XCTAssertEqual(UUCodec.decode(sysText, variant: .uu), payload)
    }
}
