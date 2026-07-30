// ChecksumFile.swift - Parse/generate checksum files (SPEC-016 §6).
//
// Two on-disk conventions are supported:
//   * SFV (.sfv):    "filename CRC32"           — checksum LAST, CRC uppercase.
//   * coreutils:     "DIGEST␠␠filename"          — checksum FIRST (md5sum/shasum),
//                    also accepts "DIGEST *filename" (binary marker).
// Both tolerate blank lines and ';'/'#' comments and filenames with spaces.

import Foundation

public struct ChecksumEntry: Equatable, Sendable {
    /// Lowercase hex digest.
    public var digest: String
    public var filename: String
    public init(digest: String, filename: String) {
        self.digest = digest.lowercased()
        self.filename = filename
    }
}

public enum ChecksumFileFormat: Equatable, Sendable {
    case sfv           // checksum last (CRC32)
    case digestFirst   // checksum first (md5/sha families)

    /// The conventional format for an algorithm.
    public static func `for`(_ algorithm: ChecksumAlgorithm) -> ChecksumFileFormat {
        algorithm == .crc32 ? .sfv : .digestFirst
    }
}

public enum ChecksumFile {
    /// Parse checksum-file text into entries (comments/blank lines skipped).
    public static func parse(_ text: String, format: ChecksumFileFormat) -> [ChecksumEntry] {
        var out: [ChecksumEntry] = []
        for rawLine in text.split(whereSeparator: { $0 == "\n" }) {
            let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(";") || trimmed.hasPrefix("#") { continue }
            switch format {
            case .sfv:
                // Split off the LAST whitespace-separated token as the checksum.
                guard let sep = trimmed.range(of: #"\s+\S+$"#, options: .regularExpression) else { continue }
                let name = String(trimmed[trimmed.startIndex..<sep.lowerBound])
                let digest = trimmed[sep.lowerBound...].trimmingCharacters(in: .whitespaces)
                guard isHex(digest) else { continue }
                out.append(ChecksumEntry(digest: digest, filename: name))
            case .digestFirst:
                // First token is the digest; the rest (after ws, optional '*') is the name.
                guard let sep = trimmed.range(of: #"\s+"#, options: .regularExpression) else { continue }
                let digest = String(trimmed[trimmed.startIndex..<sep.lowerBound])
                guard isHex(digest) else { continue }
                var name = String(trimmed[sep.upperBound...])
                if name.hasPrefix("*") { name.removeFirst() }   // binary-mode marker
                out.append(ChecksumEntry(digest: digest, filename: name))
            }
        }
        return out
    }

    /// Serialize entries to checksum-file text (trailing newline).
    public static func generate(_ entries: [ChecksumEntry], format: ChecksumFileFormat) -> String {
        var lines: [String] = []
        for e in entries {
            switch format {
            case .sfv: lines.append("\(e.filename) \(e.digest.uppercased())")
            case .digestFirst: lines.append("\(e.digest)  \(e.filename)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func isHex(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isHexDigit }
    }
}
