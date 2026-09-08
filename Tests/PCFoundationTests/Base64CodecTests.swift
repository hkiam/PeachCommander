// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class Base64CodecTests: XCTestCase {
    private func d(_ s: String) -> Data { Data(s.utf8) }

    func testRFC4648Vectors() {
        // RFC 4648 §10 test vectors (also what /usr/bin/base64 produces).
        XCTAssertEqual(Base64Codec.encode(d(""), wrap: false), "")
        XCTAssertEqual(Base64Codec.encode(d("f"), wrap: false), "Zg==")
        XCTAssertEqual(Base64Codec.encode(d("fo"), wrap: false), "Zm8=")
        XCTAssertEqual(Base64Codec.encode(d("foo"), wrap: false), "Zm9v")
        XCTAssertEqual(Base64Codec.encode(d("foob"), wrap: false), "Zm9vYg==")
        XCTAssertEqual(Base64Codec.encode(d("fooba"), wrap: false), "Zm9vYmE=")
        XCTAssertEqual(Base64Codec.encode(d("foobar"), wrap: false), "Zm9vYmFy")
    }

    func testWrappingAt76() {
        let data = Data(repeating: 0x41, count: 120)   // 120 'A' → 160 base64 chars
        let wrapped = Base64Codec.encode(data, wrap: true)
        let lines = wrapped.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertTrue(lines.count >= 2)
        XCTAssertTrue(lines.allSatisfy { $0.count <= 76 })
        // Decoding the wrapped form ignores the newlines and recovers the bytes.
        XCTAssertEqual(Base64Codec.decode(wrapped), data)
    }

    func testDecodeIgnoresWhitespace() {
        XCTAssertEqual(Base64Codec.decode("Zm9v\nYmFy"), d("foobar"))
        XCTAssertEqual(Base64Codec.decode("  Zm8=  "), d("fo"))
    }

    func testDecodeInvalidReturnsNil() {
        // 3 base64 chars is not a valid length (must be a multiple of 4).
        XCTAssertNil(Base64Codec.decode("abc"))
    }

    func testRoundTripBinary() {
        let bytes = Data((0..<512).map { UInt8($0 & 0xFF) })
        XCTAssertEqual(Base64Codec.decode(Base64Codec.encode(bytes)), bytes)
    }

    // MARK: - Streaming, which has to agree with the whole-buffer version exactly

    /// Every length from 0 to a few hundred, in several chunk sizes. "Close enough" in an encoder is
    /// a file that will not decode, and the interesting lengths are the ones around the group and
    /// line boundaries — 3, 4, 57, 58, 114 — which a handful of hand-picked cases would miss.
    func testTheStreamingEncoderMatchesTheWholeBufferOne() {
        for length in 0...400 {
            let data = Data((0..<length).map { UInt8(($0 * 7 + 13) & 0xFF) })
            for wrap in [true, false] {
                for chunk in [1, 3, 57, 64, 1000] {
                    var encoder = Base64StreamEncoder(wrap: wrap)
                    var out = ""
                    var offset = 0
                    while offset < data.count {
                        let end = min(offset + chunk, data.count)
                        out += encoder.encode(data.subdata(in: offset..<end))
                        offset = end
                    }
                    out += encoder.finish()
                    XCTAssertEqual(out, Base64Codec.encode(data, wrap: wrap),
                                   "length \(length), wrap \(wrap), chunk \(chunk)")
                }
            }
        }
    }

    func testTheStreamingDecoderMatchesTheWholeBufferOne() throws {
        for length in 0...300 {
            let data = Data((0..<length).map { UInt8(($0 * 11 + 5) & 0xFF) })
            let text = Base64Codec.encode(data, wrap: true)
            for chunk in [1, 4, 76, 500] {
                var decoder = Base64StreamDecoder()
                var out = Data()
                var rest = Substring(text)
                while !rest.isEmpty {
                    let piece = rest.prefix(chunk)
                    rest = rest.dropFirst(piece.count)
                    out += try XCTUnwrap(decoder.decode(String(piece)), "length \(length)")
                }
                out += try XCTUnwrap(decoder.finish(), "length \(length)")
                XCTAssertEqual(out, data, "length \(length), chunk \(chunk)")
            }
        }
    }

    /// Whitespace and unknown characters are skipped, the way `.ignoreUnknownCharacters` skips them
    /// for the whole-buffer decoder — a wrapped file is nothing but alphabet and newlines.
    func testTheStreamingDecoderIgnoresWhatTheOtherOneIgnores() throws {
        var decoder = Base64StreamDecoder()
        var out = try XCTUnwrap(decoder.decode("aGVs\n bG8= trailing rubbish"))
        out += try XCTUnwrap(decoder.finish())
        XCTAssertEqual(String(decoding: out, as: UTF8.self), "hello")
    }
}
