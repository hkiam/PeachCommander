// BinaryDiff.swift - Byte-level comparison of two files for the hex compare view.
//
// Streams both inputs in chunks (so multi-GB files never load into memory), counts
// differing byte positions within the common length, and collects the first N
// coalesced differing runs for navigation/highlighting. Works over a ByteSource so
// it is unit-testable with in-memory buffers as well as mmap'd files (FileSlice).

import Foundation

/// A random-access byte provider (FileSlice, or an in-memory buffer in tests).
public protocol ByteSource {
    var count: Int64 { get }
    func bytes(at offset: Int64, length: Int) -> [UInt8]
}

extension FileSlice: ByteSource {}

public struct BinaryDiffResult: Equatable, Sendable {
    public let sizeA: Int64
    public let sizeB: Int64
    /// First differing offset within the common length, or the common length itself
    /// when the shared prefix is identical but the sizes differ; nil when equal.
    public let firstDifference: Int64?
    /// Number of differing byte positions within the common length.
    public let differingBytes: Int64
    /// First up to `maxRanges` coalesced differing runs (offsets within the common length).
    public let ranges: [Range<Int64>]
    /// True if more differing runs existed than were captured in `ranges`.
    public let truncatedRanges: Bool

    public var equal: Bool { sizeA == sizeB && differingBytes == 0 }

    public init(sizeA: Int64, sizeB: Int64, firstDifference: Int64?, differingBytes: Int64,
                ranges: [Range<Int64>], truncatedRanges: Bool) {
        self.sizeA = sizeA
        self.sizeB = sizeB
        self.firstDifference = firstDifference
        self.differingBytes = differingBytes
        self.ranges = ranges
        self.truncatedRanges = truncatedRanges
    }
}

public enum BinaryDiff {
    /// Compare two byte sources. `chunk` bounds working-set memory; `maxRanges`
    /// bounds the returned run list (counting continues past the cap).
    public static func compare(_ a: ByteSource, _ b: ByteSource,
                               chunk: Int = 64 * 1024, maxRanges: Int = 4096) -> BinaryDiffResult {
        let sizeA = a.count, sizeB = b.count
        let common = Swift.min(sizeA, sizeB)
        var differing: Int64 = 0
        var ranges: [Range<Int64>] = []
        var truncated = false
        var runStart: Int64? = nil

        func closeRun(_ end: Int64) {
            guard let start = runStart else { return }
            if ranges.count < maxRanges { ranges.append(start..<end) } else { truncated = true }
            runStart = nil
        }

        var offset: Int64 = 0
        while offset < common {
            let len = Int(Swift.min(Int64(chunk), common - offset))
            let ba = a.bytes(at: offset, length: len)
            let bb = b.bytes(at: offset, length: len)
            let n = Swift.min(len, Swift.min(ba.count, bb.count))
            for i in 0..<n {
                if ba[i] != bb[i] {
                    differing += 1
                    if runStart == nil { runStart = offset + Int64(i) }
                } else if runStart != nil {
                    closeRun(offset + Int64(i))
                }
            }
            offset += Int64(len)
        }
        closeRun(common)

        let firstDifference: Int64?
        if let first = ranges.first {
            firstDifference = first.lowerBound
        } else if differing > 0 {
            // Differences exist but all runs were truncated away (maxRanges == 0).
            firstDifference = 0
        } else if sizeA != sizeB {
            firstDifference = common
        } else {
            firstDifference = nil
        }

        return BinaryDiffResult(sizeA: sizeA, sizeB: sizeB, firstDifference: firstDifference,
                                differingBytes: differing, ranges: ranges, truncatedRanges: truncated)
    }
}
