// SPDX-License-Identifier: Apache-2.0
// ChunkSearcher.swift - Plain byte-string search for the Lister (I07),
// both in-memory (for a decoded/visible window) and streamed over a whole
// file via FileSlice so a multi-gigabyte file can be searched without
// loading it entirely into memory.

import Foundation

/// Plain (non-regex) byte-sequence search.
public enum ChunkSearcher {
    /// Fold an ASCII uppercase letter to lowercase (identity for other bytes).
    @inline(__always) private static func fold(_ b: UInt8) -> UInt8 {
        (b >= 65 && b <= 90) ? b + 32 : b
    }

    @inline(__always) private static func matches(_ haystack: [UInt8], at i: Int,
                                                  _ needle: [UInt8], caseInsensitive: Bool) -> Bool {
        var j = 0
        while j < needle.count {
            let h = haystack[i + j], n = needle[j]
            if caseInsensitive ? (fold(h) != fold(n)) : (h != n) { return false }
            j += 1
        }
        return true
    }

    /// First index at/after `from` where `needle` occurs in `haystack`,
    /// using a plain byte-by-byte compare, or `nil` if it does not occur.
    /// With `caseInsensitive`, ASCII letters compare case-insensitively.
    ///
    /// An empty `needle` matches at `from` itself (as long as `from` is
    /// within `haystack`'s bounds, inclusive of its end).
    public static func firstIndex(of needle: [UInt8], in haystack: [UInt8], from: Int = 0,
                                  caseInsensitive: Bool = false) -> Int? {
        guard from >= 0 else { return nil }

        if needle.isEmpty {
            return from <= haystack.count ? from : nil
        }

        let lastStart = haystack.count - needle.count
        guard from <= lastStart else { return nil }

        var i = from
        while i <= lastStart {
            if matches(haystack, at: i, needle, caseInsensitive: caseInsensitive) { return i }
            i += 1
        }
        return nil
    }

    /// Last index strictly before `upTo` where `needle` occurs in `haystack`
    /// (for backward search), or `nil`. `upTo` defaults to the end.
    public static func lastIndex(of needle: [UInt8], in haystack: [UInt8], upTo: Int? = nil,
                                 caseInsensitive: Bool = false) -> Int? {
        guard !needle.isEmpty else {
            let u = upTo ?? haystack.count
            return u >= 1 ? min(u - 1, haystack.count) : nil
        }
        let cap = min(upTo ?? haystack.count, haystack.count)
        var i = cap - needle.count
        while i >= 0 {
            if matches(haystack, at: i, needle, caseInsensitive: caseInsensitive) { return i }
            i -= 1
        }
        return nil
    }

    /// Streaming search for `needle` over an entire `FileSlice`, without
    /// materializing the whole file at once.
    ///
    /// Scans in `chunkSize`-byte windows. Consecutive windows overlap by
    /// `needle.count - 1` bytes so a match that straddles a chunk boundary
    /// is still found. Returns the absolute byte offset of the first match
    /// at/after `from`, or `nil` if there is none.
    public static func search(
        _ needle: [UInt8],
        in slice: FileSlice,
        from: Int64 = 0,
        chunkSize: Int = 1 << 20,
        caseInsensitive: Bool = false
    ) -> Int64? {
        guard !needle.isEmpty else {
            return from >= 0 && from <= slice.count ? from : nil
        }
        guard from >= 0, from < slice.count else { return nil }

        let overlap = needle.count - 1
        var pos = from

        while pos < slice.count {
            let remaining = slice.count - pos
            let readLength = Int(min(Int64(chunkSize), remaining))
            guard readLength > 0 else { break }

            let chunk = slice.bytes(at: pos, length: readLength)
            if let localIndex = firstIndex(of: needle, in: chunk, from: 0, caseInsensitive: caseInsensitive) {
                return pos + Int64(localIndex)
            }

            let advance = max(readLength - overlap, 1)
            pos += Int64(advance)
        }

        return nil
    }

    /// Streaming BACKWARD search: the last match strictly before `before`
    /// (default: end of file), or `nil`. Scans in overlapping windows from the
    /// end so a straddling match is still found.
    public static func searchBackward(
        _ needle: [UInt8],
        in slice: FileSlice,
        before: Int64? = nil,
        chunkSize: Int = 1 << 20,
        caseInsensitive: Bool = false
    ) -> Int64? {
        guard !needle.isEmpty else { return nil }
        let cap = min(before ?? slice.count, slice.count)
        guard cap >= Int64(needle.count) else { return nil }

        let overlap = Int64(needle.count - 1)
        var end = cap                      // exclusive upper bound of the window
        while end > 0 {
            let start = max(Int64(0), end - Int64(chunkSize))
            let readLength = Int(end - start)
            let chunk = slice.bytes(at: start, length: readLength)
            // Only accept matches that start within [start, cap - needle.count].
            let limit = min(readLength, Int(cap - start))
            if let localIndex = lastIndex(of: needle, in: chunk, upTo: limit, caseInsensitive: caseInsensitive) {
                return start + Int64(localIndex)
            }
            if start == 0 { break }
            end = start + overlap          // overlap so a straddling match isn't missed
        }
        return nil
    }
}
