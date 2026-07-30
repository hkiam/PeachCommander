// SPDX-License-Identifier: Apache-2.0
// EncodingDetector.swift - Cheap text-encoding heuristic for the Lister
// (I07). Used to pick a default encoding for text mode before the user
// overrides it via the encoding menu.

import Foundation

/// Detects a text encoding from a leading sample of a file's bytes.
public enum EncodingDetector {
    /// Only the first 64 KB is ever considered; sniffing more is unnecessary
    /// and would be wasteful for very large files.
    private static let maxSampleSize = 64 * 1024

    /// Detect a text encoding from a leading sample (first up to 64 KB).
    ///
    /// Checks for a byte-order mark first: UTF-8 (`EF BB BF`), UTF-16 little
    /// endian (`FF FE`), UTF-16 big endian (`FE FF`). Without a BOM, the
    /// sample is validated as UTF-8; if it decodes cleanly, `.utf8` is
    /// returned. Otherwise this falls back to `.windowsCP1252`, a superset
    /// of Latin-1 that can represent any byte sequence.
    public static func detect(_ sample: [UInt8]) -> String.Encoding {
        let head = sample.count > maxSampleSize ? Array(sample.prefix(maxSampleSize)) : sample

        if head.count >= 3, head[0] == 0xEF, head[1] == 0xBB, head[2] == 0xBF {
            return .utf8
        }
        if head.count >= 2, head[0] == 0xFF, head[1] == 0xFE {
            return .utf16LittleEndian
        }
        if head.count >= 2, head[0] == 0xFE, head[1] == 0xFF {
            return .utf16BigEndian
        }

        if String(bytes: head, encoding: .utf8) != nil {
            return .utf8
        }

        return .windowsCP1252
    }
}
