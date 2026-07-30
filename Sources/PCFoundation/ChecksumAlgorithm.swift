// ChecksumAlgorithm.swift - File checksum algorithms (SPEC-016 §6).
//
// Pure, streamable hashing used by the create/verify-checksum feature. CRC32 is
// implemented directly (for .sfv files); the cryptographic hashes wrap CryptoKit.
// Everything here is deterministic and verified against published test vectors.

import Foundation
import CryptoKit

public enum ChecksumAlgorithm: String, CaseIterable, Sendable {
    case crc32
    case md5
    case sha1
    case sha256
    case sha512

    /// Conventional checksum-file extension for this algorithm.
    public var fileExtension: String {
        switch self {
        case .crc32: return "sfv"
        case .md5: return "md5"
        case .sha1: return "sha1"
        case .sha256: return "sha256"
        case .sha512: return "sha512"
        }
    }

    /// Number of lowercase hex characters in a digest.
    public var hexWidth: Int {
        switch self {
        case .crc32: return 8
        case .md5: return 32
        case .sha1: return 40
        case .sha256: return 64
        case .sha512: return 128
        }
    }

    /// One-shot hex digest of a buffer.
    public func hex(of data: Data) -> String {
        let hasher = ChecksumHasher(self)
        hasher.update(data)
        return hasher.finalizeHex()
    }
}

/// Incremental hasher so large files can be streamed chunk by chunk.
public final class ChecksumHasher {
    private let algorithm: ChecksumAlgorithm
    private var crc: UInt32 = 0xFFFF_FFFF
    private var md5 = Insecure.MD5()
    private var sha1 = Insecure.SHA1()
    private var sha256 = SHA256()
    private var sha512 = SHA512()

    public init(_ algorithm: ChecksumAlgorithm) { self.algorithm = algorithm }

    public func update(_ data: Data) {
        switch algorithm {
        case .crc32: crc = CRC32.update(crc, data)
        case .md5: md5.update(data: data)
        case .sha1: sha1.update(data: data)
        case .sha256: sha256.update(data: data)
        case .sha512: sha512.update(data: data)
        }
    }

    /// Finalize and return the lowercase hex digest.
    public func finalizeHex() -> String {
        switch algorithm {
        case .crc32:
            return String(format: "%08x", crc ^ 0xFFFF_FFFF)
        case .md5:   return Self.hexString(md5.finalize())
        case .sha1:  return Self.hexString(sha1.finalize())
        case .sha256: return Self.hexString(sha256.finalize())
        case .sha512: return Self.hexString(sha512.finalize())
        }
    }

    private static func hexString<D: Digest>(_ digest: D) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Table-based CRC-32 (IEEE 802.3, the polynomial used by .sfv / zip).
public enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
            return c
        }
    }()

    /// Continue a running CRC (seeded with 0xFFFFFFFF, finalized by XOR 0xFFFFFFFF).
    public static func update(_ crc: UInt32, _ data: Data) -> UInt32 {
        var c = crc
        for byte in data {
            c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
        }
        return c
    }

    /// One-shot CRC-32 value of a buffer.
    public static func checksum(_ data: Data) -> UInt32 {
        update(0xFFFF_FFFF, data) ^ 0xFFFF_FFFF
    }
}
