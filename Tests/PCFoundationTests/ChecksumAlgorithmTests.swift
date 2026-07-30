// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class ChecksumAlgorithmTests: XCTestCase {
    private func data(_ s: String) -> Data { Data(s.utf8) }

    // Published test vectors.

    func testCRC32KnownVector() {
        // CRC-32 of "123456789" is 0xCBF43926.
        XCTAssertEqual(CRC32.checksum(data("123456789")), 0xCBF4_3926)
        XCTAssertEqual(ChecksumAlgorithm.crc32.hex(of: data("123456789")), "cbf43926")
    }

    func testCRC32Empty() {
        XCTAssertEqual(CRC32.checksum(Data()), 0)
        XCTAssertEqual(ChecksumAlgorithm.crc32.hex(of: Data()), "00000000")
    }

    func testMD5KnownVectors() {
        XCTAssertEqual(ChecksumAlgorithm.md5.hex(of: data("abc")), "900150983cd24fb0d6963f7d28e17f72")
        XCTAssertEqual(ChecksumAlgorithm.md5.hex(of: Data()), "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testSHA1KnownVector() {
        XCTAssertEqual(ChecksumAlgorithm.sha1.hex(of: data("abc")), "a9993e364706816aba3e25717850c26c9cd0d89d")
    }

    func testSHA256KnownVector() {
        XCTAssertEqual(ChecksumAlgorithm.sha256.hex(of: data("abc")),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testSHA512KnownVector() {
        XCTAssertEqual(ChecksumAlgorithm.sha512.hex(of: data("abc")),
                       "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a" +
                       "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")
    }

    func testIncrementalMatchesOneShot() {
        let full = data("The quick brown fox jumps over the lazy dog")
        for algo in ChecksumAlgorithm.allCases {
            let hasher = ChecksumHasher(algo)
            // feed in three chunks
            hasher.update(full.prefix(10))
            hasher.update(full.dropFirst(10).prefix(20))
            hasher.update(full.dropFirst(30))
            XCTAssertEqual(hasher.finalizeHex(), algo.hex(of: full), "\(algo) streaming mismatch")
            XCTAssertEqual(hasher.finalizeHex().count, algo.hexWidth)
        }
    }
}
