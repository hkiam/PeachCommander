// SplitInfo.swift - Metadata for split files (SPEC-016 §3).
//
// When a file is split into .001/.002/… parts, a sidecar "<name>.crc" file records
// the original name, total size, and CRC-32 so Combine can reassemble and verify.
// Format matches Total Commander's .crc file (simple key=value lines).

import Foundation

public struct SplitInfo: Equatable, Sendable {
    public var filename: String
    public var size: Int64
    public var crc32: UInt32

    public init(filename: String, size: Int64, crc32: UInt32) {
        self.filename = filename
        self.size = size
        self.crc32 = crc32
    }

    /// Serialize to .crc file text (CRC as 8 uppercase hex digits, TC-style).
    public func serialized() -> String {
        """
        filename=\(filename)
        size=\(size)
        crc32=\(String(format: "%08X", crc32))

        """
    }

    /// Parse a .crc file. Returns nil if the required keys are missing/invalid.
    public static func parse(_ text: String) -> SplitInfo? {
        var values: [String: String] = [:]
        for line in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[line.startIndex..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            values[key] = value
        }
        guard let filename = values["filename"], !filename.isEmpty,
              let sizeStr = values["size"], let size = Int64(sizeStr),
              let crcStr = values["crc32"], let crc = UInt32(crcStr, radix: 16) else { return nil }
        return SplitInfo(filename: filename, size: size, crc32: crc)
    }

    /// The part file name for a 1-based index, e.g. "movie.avi.001".
    public static func partName(_ base: String, index: Int) -> String {
        String(format: "%@.%03d", base, index)
    }

    /// Number of parts needed to split `size` bytes into `partSize` chunks.
    public static func partCount(size: Int64, partSize: Int64) -> Int {
        guard partSize > 0, size > 0 else { return size > 0 ? 1 : 0 }
        return Int((size + partSize - 1) / partSize)
    }
}
