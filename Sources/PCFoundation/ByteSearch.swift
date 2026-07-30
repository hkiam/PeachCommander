// ByteSearch.swift - Parse a hex query and find a byte pattern (hex editor find/replace).
//
// Pure helpers: turn "48 65 6C" (or "48656c") into bytes, and locate a pattern in a
// buffer from a start index. Unit-testable; the hex editor drives find/replace with these.

import Foundation

public enum ByteSearch {
    /// Parse a whitespace-tolerant hex string into bytes; nil if it has odd length or
    /// a non-hex character.
    public static func parseHex(_ string: String) -> [UInt8]? {
        let compact = string.filter { !$0.isWhitespace }
        guard !compact.isEmpty, compact.count % 2 == 0 else { return nil }
        var out: [UInt8] = []
        out.reserveCapacity(compact.count / 2)
        var i = compact.startIndex
        while i < compact.endIndex {
            let next = compact.index(i, offsetBy: 2)
            guard let byte = UInt8(compact[i..<next], radix: 16) else { return nil }
            out.append(byte)
            i = next
        }
        return out
    }

    /// First index of `pattern` in `bytes` at or after `from`, or nil.
    public static func firstIndex(of pattern: [UInt8], in bytes: [UInt8], from: Int = 0) -> Int? {
        guard !pattern.isEmpty, pattern.count <= bytes.count else { return nil }
        var i = max(0, from)
        let last = bytes.count - pattern.count
        while i <= last {
            if Array(bytes[i..<(i + pattern.count)]) == pattern { return i }
            i += 1
        }
        return nil
    }

    /// All non-overlapping match start indices of `pattern` in `bytes`.
    public static func allIndices(of pattern: [UInt8], in bytes: [UInt8]) -> [Int] {
        guard !pattern.isEmpty else { return [] }
        var result: [Int] = []
        var from = 0
        while let i = firstIndex(of: pattern, in: bytes, from: from) {
            result.append(i)
            from = i + pattern.count
        }
        return result
    }
}
