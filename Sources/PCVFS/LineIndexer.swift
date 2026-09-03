// SPDX-License-Identifier: Apache-2.0
// LineIndexer.swift - Byte-offset line indexing for the Lister text mode
// (I07). Scans raw bytes once to find where each line begins, without
// decoding text, so it works uniformly regardless of the file's encoding.

import Foundation

/// Computes line-start byte offsets for text-mode viewing.
public enum LineIndexer {

    /// The index of the line containing `offset`, given ascending line-start offsets.
    ///
    /// The largest line whose start is at or before the offset — a binary search that the viewer's
    /// virtual text views had each written out for themselves. Kept here because it is the half of
    /// "show me the match" that has nothing to do with drawing, and because two copies of a search
    /// like this is one copy too many.
    ///
    /// Returns 0 for an empty index, and clamps an offset past the end to the last line.
    public static func line(containing offset: Int64, in starts: [Int64]) -> Int {
        guard !starts.isEmpty else { return 0 }
        var line = 0
        var lo = 0, hi = starts.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if starts[mid] <= offset { line = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        return line
    }
    private static let lf: UInt8 = 0x0A
    private static let cr: UInt8 = 0x0D

    /// Byte offsets at which each line starts, scanning `bytes`.
    ///
    /// Recognizes LF (`"\n"`), CRLF (`"\r\n"`) and lone CR (`"\r"`) as line
    /// terminators. The first line always starts at 0. A trailing terminator
    /// does not create an extra empty trailing line unless there are more
    /// bytes after it (so `"a\n"` yields `[0]`, not `[0, 2]`). Empty input
    /// returns `[]`.
    public static func lineStarts(in bytes: [UInt8]) -> [Int] {
        guard !bytes.isEmpty else { return [] }

        var starts = [0]
        let count = bytes.count
        var i = 0

        while i < count {
            let byte = bytes[i]
            var next: Int?

            if byte == lf {
                next = i + 1
            } else if byte == cr {
                if i + 1 < count, bytes[i + 1] == lf {
                    next = i + 2
                } else {
                    next = i + 1
                }
            }

            guard let terminatorEnd = next else {
                i += 1
                continue
            }

            if terminatorEnd < count {
                starts.append(terminatorEnd)
            }
            i = terminatorEnd
        }

        return starts
    }

    /// The result of a streaming line scan over a memory-mapped file (F-112).
    public struct StreamIndex {
        /// Byte offset (into the file) at which each displayable line starts.
        public let starts: [Int64]
        /// Byte offset just past the last displayable line (== file size unless
        /// the scan stopped early at `maxLines`).
        public let contentEnd: Int64
        /// True when the file has more lines than `maxLines` (content beyond
        /// `contentEnd` is not shown).
        public let truncated: Bool
    }

    /// Scan a memory-mapped buffer for line-start byte offsets without copying,
    /// stopping after `maxLines` lines so the viewer's frame height stays within
    /// AppKit's coordinate limits for pathologically large files (F-112).
    public static func lineStartOffsets(in buffer: UnsafeRawBufferPointer, maxLines: Int) -> StreamIndex {
        let count = buffer.count
        guard count > 0 else { return StreamIndex(starts: [], contentEnd: 0, truncated: false) }
        guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return StreamIndex(starts: [], contentEnd: 0, truncated: false)
        }
        var starts: [Int64] = [0]
        var i = 0
        while i < count {
            let byte = base[i]
            var next: Int?
            if byte == lf {
                next = i + 1
            } else if byte == cr {
                next = (i + 1 < count && base[i + 1] == lf) ? i + 2 : i + 1
            }
            guard let terminatorEnd = next else { i += 1; continue }
            if terminatorEnd < count {
                if starts.count >= maxLines {
                    // Stop: `terminatorEnd` bounds the last displayable line.
                    return StreamIndex(starts: starts, contentEnd: Int64(terminatorEnd), truncated: true)
                }
                starts.append(Int64(terminatorEnd))
            }
            i = terminatorEnd
        }
        return StreamIndex(starts: starts, contentEnd: Int64(count), truncated: false)
    }
}
