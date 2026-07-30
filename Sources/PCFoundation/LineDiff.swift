// LineDiff - Myers O(ND) line diff engine for side-by-side comparison
// A pure, deterministic diff engine used by the file comparison viewer.
// Depends on Foundation only (no AppKit / no Foundation-UI).

import Foundation

/// The kind of alignment a `DiffRow` represents in a two-column diff.
public enum DiffOp: Sendable, Equatable {
    /// Line present and equal (under the active `DiffOptions`) on both sides.
    case equal
    /// Line present only on the right side.
    case insert
    /// Line present only on the left side.
    case delete
    /// A left line paired with a differing right line.
    case change
}

/// One aligned row of a two-column diff.
///
/// For `.equal` and `.change` both indices are set; for `.delete` only
/// `leftIndex`; for `.insert` only `rightIndex`.
public struct DiffRow: Sendable, Equatable {
    /// The alignment kind of this row.
    public let op: DiffOp
    /// 0-based index into the left line array, or `nil` for `.insert`.
    public let leftIndex: Int?
    /// 0-based index into the right line array, or `nil` for `.delete`.
    public let rightIndex: Int?

    public init(op: DiffOp, leftIndex: Int?, rightIndex: Int?) {
        self.op = op
        self.leftIndex = leftIndex
        self.rightIndex = rightIndex
    }
}

/// How whitespace is treated when deciding whether two lines are equal.
public enum WhitespaceMode: Sendable, Equatable {
    /// Whitespace is significant (compared verbatim).
    case none
    /// Ignore all Unicode whitespace anywhere in the line.
    case all
    /// Trim leading and trailing Unicode whitespace before comparing.
    case leadingTrailing
}

/// Options controlling how lines are normalized before being compared.
///
/// Normalization only affects *equality*; emitted rows always reference the
/// original, unmodified line indices.
public struct DiffOptions: Sendable, Equatable {
    /// Compare case-insensitively (lines are lowercased before comparison).
    public var ignoreCase: Bool
    /// How whitespace is handled during comparison.
    public var whitespace: WhitespaceMode
    /// Treat a single trailing `"\r"` as absent (so CRLF matches LF).
    public var ignoreLineEndings: Bool

    public init(ignoreCase: Bool = false,
                whitespace: WhitespaceMode = .none,
                ignoreLineEndings: Bool = false) {
        self.ignoreCase = ignoreCase
        self.whitespace = whitespace
        self.ignoreLineEndings = ignoreLineEndings
    }
}

/// A classic Myers O(ND) diff over lines and characters.
public enum LineDiff {

    // MARK: - Public API

    /// Computes a classic Myers O(ND) diff over lines and returns aligned rows
    /// in order.
    ///
    /// Comparison is performed on a normalized key per line (see `DiffOptions`),
    /// but every emitted `DiffRow` references the *original* line indices.
    ///
    /// Consecutive delete/insert runs are coalesced into `.change` rows: a
    /// maximal run of `k` deletes immediately followed by `m` inserts emits
    /// `min(k, m)` `.change` rows pairing them positionally (1st delete with
    /// 1st insert, and so on), followed by the remaining `|k - m|` rows as
    /// plain `.delete` or `.insert`. This matches the behaviour of typical
    /// side-by-side diff viewers.
    ///
    /// - Parameters:
    ///   - left: The left-hand lines.
    ///   - right: The right-hand lines.
    ///   - options: Normalization options controlling line equality.
    /// - Returns: The aligned diff rows, in top-to-bottom order.
    public static func compare(left: [String],
                               right: [String],
                               options: DiffOptions = DiffOptions()) -> [DiffRow] {
        // Compare using normalized keys, but emit original indices.
        let leftKeys = left.map { normalize($0, options) }
        let rightKeys = right.map { normalize($0, options) }

        let edits = myers(leftKeys, rightKeys)

        var rows: [DiffRow] = []
        rows.reserveCapacity(edits.count)

        // Pending delete/insert indices for the current contiguous edit block.
        var pendingDeletes: [Int] = []
        var pendingInserts: [Int] = []

        // Coalesces the buffered edit block into change/delete/insert rows.
        func flushBlock() {
            let paired = min(pendingDeletes.count, pendingInserts.count)
            for i in 0..<paired {
                rows.append(DiffRow(op: .change,
                                    leftIndex: pendingDeletes[i],
                                    rightIndex: pendingInserts[i]))
            }
            if pendingDeletes.count > paired {
                for i in paired..<pendingDeletes.count {
                    rows.append(DiffRow(op: .delete,
                                        leftIndex: pendingDeletes[i],
                                        rightIndex: nil))
                }
            }
            if pendingInserts.count > paired {
                for i in paired..<pendingInserts.count {
                    rows.append(DiffRow(op: .insert,
                                        leftIndex: nil,
                                        rightIndex: pendingInserts[i]))
                }
            }
            pendingDeletes.removeAll(keepingCapacity: true)
            pendingInserts.removeAll(keepingCapacity: true)
        }

        for edit in edits {
            switch edit {
            case let .delete(l):
                pendingDeletes.append(l)
            case let .insert(r):
                pendingInserts.append(r)
            case let .keep(l, r):
                // An equal line is an anchor: flush any accumulated block first.
                flushBlock()
                rows.append(DiffRow(op: .equal, leftIndex: l, rightIndex: r))
            }
        }
        flushBlock()

        return rows
    }

    /// Computes a character-level (grapheme cluster) diff of two strings.
    ///
    /// Indices are into `Array(a)` / `Array(b)` of `Character` values. The
    /// returned ranges are half-open, sorted, and non-overlapping, and describe
    /// the grapheme positions that differ on each side (for intra-line
    /// highlighting). Equal strings return `([], [])`.
    ///
    /// - Parameters:
    ///   - a: The left string.
    ///   - b: The right string.
    /// - Returns: The differing grapheme-index ranges on each side.
    public static func intraLine(_ a: String, _ b: String) -> (left: [Range<Int>], right: [Range<Int>]) {
        if a == b { return ([], []) }

        let aChars = Array(a)
        let bChars = Array(b)

        let edits = myers(aChars, bChars)

        // A deleted grapheme differs on the left; an inserted one on the right.
        var leftPositions: [Int] = []
        var rightPositions: [Int] = []
        for edit in edits {
            switch edit {
            case let .delete(l):
                leftPositions.append(l)
            case let .insert(r):
                rightPositions.append(r)
            case .keep:
                break
            }
        }

        return (groupConsecutive(leftPositions), groupConsecutive(rightPositions))
    }

    // MARK: - Normalization

    /// Produces the comparison key for a single line under the given options.
    private static func normalize(_ line: String, _ options: DiffOptions) -> String {
        var s = line

        // Strip a single trailing carriage return (CRLF vs LF).
        if options.ignoreLineEndings, s.hasSuffix("\r") {
            s.removeLast()
        }

        // Apply whitespace handling.
        switch options.whitespace {
        case .none:
            break
        case .all:
            s = String(s.filter { !$0.isWhitespace })
        case .leadingTrailing:
            s = trimmingWhitespace(s)
        }

        // Apply case folding last (order relative to whitespace is irrelevant).
        if options.ignoreCase {
            s = s.lowercased()
        }

        return s
    }

    /// Trims leading and trailing Unicode whitespace (grapheme-aware).
    private static func trimmingWhitespace(_ s: String) -> String {
        var slice = Substring(s)
        while let first = slice.first, first.isWhitespace {
            slice = slice.dropFirst()
        }
        while let last = slice.last, last.isWhitespace {
            slice = slice.dropLast()
        }
        return String(slice)
    }

    // MARK: - Grouping

    /// Groups a sorted, ascending list of indices into half-open ranges of
    /// consecutive integers.
    private static func groupConsecutive(_ positions: [Int]) -> [Range<Int>] {
        guard !positions.isEmpty else { return [] }

        var ranges: [Range<Int>] = []
        var start = positions[0]
        var prev = positions[0]

        for value in positions.dropFirst() {
            if value == prev + 1 {
                prev = value
            } else {
                ranges.append(start..<(prev + 1))
                start = value
                prev = value
            }
        }
        ranges.append(start..<(prev + 1))
        return ranges
    }

    // MARK: - Myers O(ND) core

    /// A single edit operation produced by the Myers algorithm, expressed in
    /// terms of source indices.
    private enum Edit {
        /// A matched pair: `a[left]` equals `b[right]`.
        case keep(left: Int, right: Int)
        /// `a[left]` is present only on the left.
        case delete(left: Int)
        /// `b[right]` is present only on the right.
        case insert(right: Int)
    }

    /// Runs the classic greedy Myers shortest-edit-script algorithm over two
    /// arrays and returns the edit script in forward (top-to-bottom) order.
    ///
    /// This is the O(ND) formulation that records the search frontier (the `V`
    /// arrays) at each edit distance and then backtracks to recover the path.
    private static func myers<T: Equatable>(_ a: [T], _ b: [T]) -> [Edit] {
        let n = a.count
        let m = b.count

        // Fast paths keep the common cases cheap and unambiguous.
        if n == 0 && m == 0 { return [] }
        if n == 0 { return (0..<m).map { .insert(right: $0) } }
        if m == 0 { return (0..<n).map { .delete(left: $0) } }

        let maxD = n + m
        let offset = maxD                     // maps diagonal k in [-maxD, maxD] to a non-negative index
        var v = [Int](repeating: 0, count: 2 * maxD + 1)

        // Snapshot of `v` at the start of each edit-distance iteration, used for
        // backtracking once the end is reached.
        var trace: [[Int]] = []
        trace.reserveCapacity(maxD + 1)

        var foundD = -1

        outer: for d in 0...maxD {
            trace.append(v)
            var k = -d
            while k <= d {
                // Decide whether to extend from the diagonal above (a down move,
                // i.e. an insertion) or the one below (a right move, a deletion).
                var x: Int
                if k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) {
                    x = v[offset + k + 1]        // move down: insert b[y]
                } else {
                    x = v[offset + k - 1] + 1    // move right: delete a[x]
                }
                var y = x - k

                // Follow the diagonal ("snake") of equal elements.
                while x < n && y < m && a[x] == b[y] {
                    x += 1
                    y += 1
                }

                v[offset + k] = x

                if x >= n && y >= m {
                    foundD = d
                    break outer
                }
                k += 2
            }
        }

        // Backtrack from the bottom-right corner to reconstruct the script.
        var reversed: [Edit] = []
        var x = n
        var y = m

        for d in stride(from: foundD, through: 0, by: -1) {
            let vPrev = trace[d]
            let k = x - y

            let prevK: Int
            if k == -d || (k != d && vPrev[offset + k - 1] < vPrev[offset + k + 1]) {
                prevK = k + 1                    // came from a down move (insertion)
            } else {
                prevK = k - 1                    // came from a right move (deletion)
            }
            let prevX = vPrev[offset + prevK]
            let prevY = prevX - prevK

            // Emit the diagonal snake that preceded this edit (in reverse).
            while x > prevX && y > prevY {
                reversed.append(.keep(left: x - 1, right: y - 1))
                x -= 1
                y -= 1
            }

            // The single edit that bridged the two diagonals (none at d == 0,
            // which only carries the initial common prefix).
            if d > 0 {
                if x == prevX {
                    reversed.append(.insert(right: y - 1))
                } else {
                    reversed.append(.delete(left: x - 1))
                }
                x = prevX
                y = prevY
            }
        }

        return reversed.reversed()
    }
}
