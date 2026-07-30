// WinZipAES.swift - Decrypt WinZip AES (AE-1/AE-2) zip entries (F-136).
//
// Layout of an AES-encrypted entry body: salt | 2-byte password verifier |
// AES-CTR ciphertext | 10-byte HMAC-SHA1 authentication code. The key material
// is PBKDF2-HMAC-SHA1(password, salt, 1000 iterations) → AES key | HMAC key |
// 2-byte verifier. WinZip's CTR uses a 128-bit LITTLE-ENDIAN counter starting at
// 1 (so keystream block i = AES-ECB(key, LE128(i))), unlike CommonCrypto's
// built-in big-endian CTR — hence the manual keystream below.

import Foundation
import CommonCrypto

enum WinZipAES {
    /// Salt / AES-key lengths for the strength code (1=128, 2=192, 3=256 bit).
    private static func sizes(for strengthCode: UInt8) throws -> (salt: Int, key: Int) {
        switch strengthCode {
        case 1: return (8, 16)
        case 2: return (12, 24)
        case 3: return (16, 32)
        default: throw ZipError.malformed("bad AES strength \(strengthCode)")
        }
    }

    /// Decrypt an AES entry body, returning the (still-compressed) plaintext.
    /// Throws `ZipError.wrongPassword` on a verifier or HMAC mismatch.
    static func decrypt(_ raw: Data, password: String, strengthCode: UInt8) throws -> Data {
        let (saltLen, keyLen) = try sizes(for: strengthCode)
        let bytes = [UInt8](raw)
        guard bytes.count >= saltLen + 2 + 10 else { throw ZipError.malformed("AES entry too short") }
        let salt = Array(bytes[0..<saltLen])
        let verifier = Array(bytes[saltLen..<saltLen + 2])
        let cipher = Array(bytes[(saltLen + 2)..<(bytes.count - 10)])
        let authCode = Array(bytes[(bytes.count - 10)...])

        // PBKDF2 → AES key | HMAC key | 2-byte verifier.
        let derivedLen = 2 * keyLen + 2
        var derived = [UInt8](repeating: 0, count: derivedLen)
        let rc = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), password, password.utf8.count,
                                      salt, saltLen, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                                      1000, &derived, derivedLen)
        guard rc == kCCSuccess else { throw ZipError.malformed("PBKDF2 failed (\(rc))") }
        let aesKey = Array(derived[0..<keyLen])
        let hmacKey = Array(derived[keyLen..<2 * keyLen])
        guard Array(derived[(2 * keyLen)...]) == verifier else { throw ZipError.wrongPassword }

        // Integrity: HMAC-SHA1(hmacKey, ciphertext) truncated to 10 bytes.
        var mac = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), hmacKey, hmacKey.count, cipher, cipher.count, &mac)
        guard Array(mac[0..<10]) == authCode else { throw ZipError.wrongPassword }

        return Data(ctr(cipher, key: aesKey))
    }

    /// AES-CTR with a little-endian 128-bit counter starting at 1.
    private static func ctr(_ cipher: [UInt8], key: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: cipher.count)
        var counter = [UInt8](repeating: 0, count: 16)
        var keystream = [UInt8](repeating: 0, count: 16)
        var block: UInt64 = 1   // low 64 bits are ample for any real entry size
        var offset = 0
        while offset < cipher.count {
            for b in 0..<8 { counter[b] = UInt8((block >> (8 * UInt64(b))) & 0xff) }
            var moved = 0
            _ = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode),
                        key, key.count, nil, counter, 16, &keystream, 16, &moved)
            let n = min(16, cipher.count - offset)
            for j in 0..<n { out[offset + j] = cipher[offset + j] ^ keystream[j] }
            offset += 16
            block += 1
        }
        return out
    }
}
