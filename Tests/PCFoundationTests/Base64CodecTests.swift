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
}
