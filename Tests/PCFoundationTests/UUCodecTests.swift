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

    // MARK: - Streaming, which has to produce and accept exactly the same bytes

    /// The encoder's whole point: byte-identical output, whatever the caller feeds it in.
    ///
    /// Every length from 0 to 200 and four different chunk sizes, because the interesting lengths are
    /// the ones around a 45-byte line boundary and the interesting chunk sizes are the ones that do
    /// not line up with it. "Close enough" in an encoder is a file that will not decode.
    func test_theStreamedEncodingIsByteIdenticalToTheWholeBufferOne() {
        for variant in [UUCodec.Variant.uu, .xx] {
            for length in 0...200 {
                let data = Data((0..<length).map { UInt8(($0 * 31 + 7) & 0xFF) })
                let expected = UUCodec.encode(data, variant: variant, filename: "f.bin")
                for chunkSize in [1, 7, 45, 64] {
                    var encoder = UUStreamEncoder(variant: variant, filename: "f.bin")
                    var out = ""
                    var offset = 0
                    while offset < data.count {
                        let end = Swift.min(offset + chunkSize, data.count)
                        out += encoder.encode(data.subdata(in: offset..<end))
                        offset = end
                    }
                    out += encoder.finish()
                    XCTAssertEqual(out, expected,
                                   "length \(length), chunk \(chunkSize), \(variant)")
                }
            }
        }
    }

    /// An empty payload still gets a valid frame — the header comes out of `finish` when nothing
    /// else has emitted it.
    func test_anEmptyPayloadStillGetsAFrame() {
        var encoder = UUStreamEncoder(variant: .uu, filename: "empty.bin")
        let text = encoder.finish()
        XCTAssertEqual(text, UUCodec.encode(Data(), variant: .uu, filename: "empty.bin"))
        XCTAssertTrue(text.hasPrefix("begin 644 empty.bin\n"))
        XCTAssertTrue(text.hasSuffix("end\n"))
    }

    /// And the decoder takes it back, however the text arrives — one character at a time included,
    /// which is the case that finds a decoder assuming it gets whole lines.
    func test_theStreamedDecoderTakesBackWhatTheEncoderProduced() {
        for variant in [UUCodec.Variant.uu, .xx] {
            for length in [0, 1, 44, 45, 46, 90, 137] {
                let data = Data((0..<length).map { UInt8(($0 * 17 + 3) & 0xFF) })
                let text = UUCodec.encode(data, variant: variant, filename: "f.bin")
                for chunkSize in [1, 13, 61, 4096] {
                    var decoder = UUStreamDecoder(variant: variant)
                    var out = Data()
                    var index = text.startIndex
                    while index < text.endIndex {
                        let end = text.index(index, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
                        guard let piece = decoder.decode(String(text[index..<end])) else {
                            return XCTFail("refused its own encoder's output at \(length)/\(chunkSize)")
                        }
                        out.append(piece)
                        index = end
                    }
                    guard let tail = decoder.finish() else { return XCTFail("finish refused") }
                    out.append(tail)
                    XCTAssertEqual(out, data, "length \(length), chunk \(chunkSize), \(variant)")
                }
            }
        }
    }

    /// Text after the terminator is not more data. A decoder that kept going would append whatever
    /// a mail client had put below the `end` line.
    func test_nothingAfterTheEndLineIsData() {
        let text = UUCodec.encode(Data("payload".utf8), variant: .uu)
            + "\nSent from my telephone\n"
        var decoder = UUStreamDecoder(variant: .uu)
        var out = Data(decoder.decode(text) ?? Data())
        out.append(decoder.finish() ?? Data())
        XCTAssertEqual(out, Data("payload".utf8))
    }

    /// A line whose symbols are outside the alphabet is refused rather than silently shortened —
    /// the whole-text decoder answers nil for the same input.
    func test_aMalformedLineIsRefused() {
        // A valid frame with one line's payload replaced by something not in the uu alphabet.
        let text = "begin 644 f.bin\nM\u{7f}\u{7f}\u{7f}\u{7f}\n`\nend\n"
        XCTAssertNil(UUCodec.decode(text, variant: .uu))
        var decoder = UUStreamDecoder(variant: .uu)
        XCTAssertNil(decoder.decode(text))
        XCTAssertNil(decoder.finish(), "a decoder that had already failed answered again")
    }

    /// A payload with no `begin` line starts at the first data line, the same as the whole-text
    /// decoder allows.
    func test_aPayloadWithoutAHeaderIsStillDecoded() {
        let framed = UUCodec.encode(Data("no header here".utf8), variant: .uu)
        let bare = framed.split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst().joined(separator: "\n")
        var decoder = UUStreamDecoder(variant: .uu)
        var out = Data(decoder.decode(bare) ?? Data())
        out.append(decoder.finish() ?? Data())
        XCTAssertEqual(out, Data("no header here".utf8))
        XCTAssertEqual(UUCodec.decode(bare, variant: .uu), Data("no header here".utf8))
    }
}
