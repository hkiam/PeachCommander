// LineIndexer.swift - Byte-offset line indexing for the Lister text mode
// (I07). Scans raw bytes once to find where each line begins, without
// decoding text, so it works uniformly regardless of the file's encoding.

import Foundation

/// Computes line-start byte offsets for text-mode viewing.
public enum LineIndexer {
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
