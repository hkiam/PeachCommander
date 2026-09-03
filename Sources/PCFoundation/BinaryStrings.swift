// SPDX-License-Identifier: Apache-2.0
// BinaryStrings.swift - Find the readable text inside a blob of bytes, in several
// encodings at once (F-489).
//
// This is `strings(1)` with the part that makes `strings(1)` tiring taken out. The
// classic tool scans one encoding per run: `strings -e l` for UTF-16LE, another run for
// ASCII, and the reader merges two lists by hand. A hex viewer is exactly where that is
// wrong — you do not know yet what is in the file, which is why you opened it in hex.
//
// So every reading asked for runs over the same bytes and the results are *reconciled*
// rather than concatenated. That reconciliation is the whole design:
//
//   * "Hello" as ASCII is also a perfectly valid pair of CJK ideographs when read as
//     UTF-16LE, and a different pair when read as UTF-16BE. Emitting all three is not
//     three findings, it is one finding and two artefacts.
//   * A UTF-16 string need not begin at an even file offset, so both alignments have to be
//     tried — which produces, for every real hit, a shifted near-miss one byte over.
//
// Overlapping candidates are therefore scored on how much like text they read (see
// `plausibility`) and the best one wins its byte range outright. The ASCII reading of
// "Hello" beats both ideogram readings because every one of its scalars is ASCII; the
// correctly aligned UTF-16 reading beats the shifted one because it is longer.
//
// The other half of "meaningful" is `qualifies`, which throws away runs that are printable
// without being text at all. Without it the five passes report 65,000 runs over `/bin/zsh`
// and 4,400 of them are strings; with it, 8,000 and nearly all of them are.
//
// Pure and IO-free: the callers (the hex viewer's and hex editor's strings panel) do the
// chunking, the threading and the cancellation. Everything here is a function of its input.

import Foundation

/// How a run of bytes was read.
public enum StringEncodingKind: String, CaseIterable, Sendable {
    /// Every byte in 0x20…0x7E (plus tab).
    case ascii
    /// Single bytes above 0x7E that are not valid UTF-8 — ISO-8859-1 / Windows text.
    case latin1
    /// A run containing at least one valid multi-byte UTF-8 sequence.
    case utf8
    case utf16le
    case utf16be

    /// The readings a scan performs unless told otherwise — every one except Latin-1.
    ///
    /// Latin-1 is left out on purpose, and it is the one judgement call in this file worth
    /// arguing with. Three quarters of all byte values are printable Latin-1, so compiled
    /// code passes the reading in bulk: over `/bin/zsh` it contributes 3,583 findings, and
    /// they are not weak findings that a longer minimum length or a stricter shape test
    /// would remove — `åAWAVAUATSH` is a function prologue, and no rule short of knowing the
    /// language tells it from a word. Switched on it is worth having over a Windows-1252
    /// text file, where it is the difference between `Gr`, `e` and `Grüße`; switched on by
    /// default it would bury the four readings that are reliable.
    public static let defaults: Set<StringEncodingKind> = [.ascii, .utf8, .utf16le, .utf16be]

    /// Order used to break a tie between two equally plausible readings of the same bytes.
    var precedence: Int {
        switch self {
        case .ascii: return 0
        case .utf8: return 1
        case .latin1: return 2
        case .utf16le: return 3
        case .utf16be: return 4
        }
    }
}

/// One readable run of bytes.
public struct FoundString: Equatable, Sendable {
    /// Byte offset of the first byte of the run, in the file (not in the scanned chunk).
    public let offset: Int64
    /// How many bytes the run occupies — two per character for UTF-16, more for
    /// multi-byte UTF-8. This is what a hex view has to select.
    public let byteLength: Int
    public let encoding: StringEncodingKind
    public let text: String

    public init(offset: Int64, byteLength: Int, encoding: StringEncodingKind, text: String) {
        self.offset = offset
        self.byteLength = byteLength
        self.encoding = encoding
        self.text = text
    }

    /// The byte range the run occupies, half-open.
    public var range: Range<Int64> { offset ..< (offset + Int64(byteLength)) }
}

/// What to look for.
public struct StringScanOptions: Sendable {
    /// Shortest run worth reporting, in characters. Four is `strings(1)`'s default and is
    /// the point where a byte sequence stops looking like an accident.
    public var minimumLength: Int
    /// Longest run kept as one finding. A run past this is cut and continues as the next
    /// one, so a megabyte of text cannot become a megabyte-long table row.
    public var maximumLength: Int
    /// Which readings to attempt, all of them at once — that is the feature.
    /// Defaults to ``StringEncodingKind/defaults``.
    public var encodings: Set<StringEncodingKind>
    /// Keep only runs that read like text (see ``BinaryStrings/qualifies(_:as:)``).
    ///
    /// On by default, and it is the difference between a usable list and an unusable one:
    /// over `/bin/zsh` the five passes find 65,000 runs, of which 4,400 are strings and the
    /// rest are byte soup that happens to be printable. Turning it off is the way to see a
    /// run this rule is wrong about — non-Latin UTF-16 text, above all.
    public var plausibleOnly: Bool

    public init(minimumLength: Int = 4,
                maximumLength: Int = 4096,
                encodings: Set<StringEncodingKind> = StringEncodingKind.defaults,
                plausibleOnly: Bool = true) {
        self.minimumLength = max(1, minimumLength)
        self.maximumLength = max(self.minimumLength, maximumLength)
        self.encodings = encodings
        self.plausibleOnly = plausibleOnly
    }

    /// The furthest a single finding can reach, in bytes: four bytes per character is the
    /// worst case (UTF-8 astral, or a UTF-16 surrogate pair). Callers that scan in chunks
    /// need this to size their overlap.
    public var maximumByteLength: Int { maximumLength * 4 }
}

/// The scanner.
public enum BinaryStrings {

    /// Every readable run in `bytes`, in file order, with overlapping readings reconciled.
    ///
    /// `baseOffset` is added to every reported offset, so a caller scanning a chunk of a
    /// large file gets file offsets back rather than chunk offsets.
    public static func scan(_ bytes: [UInt8],
                            baseOffset: Int64 = 0,
                            options: StringScanOptions = StringScanOptions()) -> [FoundString] {
        guard !bytes.isEmpty else { return [] }
        var hits: [FoundString] = []

        if options.encodings.contains(.ascii) || options.encodings.contains(.latin1)
            || options.encodings.contains(.utf8) {
            scanBytewise(bytes, base: baseOffset, options: options, into: &hits)
        }
        for kind in [StringEncodingKind.utf16le, .utf16be] where options.encodings.contains(kind) {
            // Both alignments: a UTF-16 string inside a container need not start on an even
            // file offset. The shifted duplicate this produces is what `reconcile` is for.
            for start in 0..<2 {
                scanUTF16(bytes, base: baseOffset, littleEndian: kind == .utf16le,
                          from: start, kind: kind, options: options, into: &hits)
            }
        }
        return reconcile(hits)
    }

    // MARK: - The byte-oriented pass (ASCII / Latin-1 / UTF-8)

    /// One walk covering all three single-byte-ish readings, because they compete for the
    /// same bytes and can only be told apart by what the run turned out to contain.
    ///
    /// The classification is "what did this run actually need": a run that stayed under
    /// 0x7F is ASCII, one that needed a valid multi-byte sequence is UTF-8, and one that
    /// contained a high byte no UTF-8 decoder would accept is Latin-1. A reading that was
    /// not asked for ends the run instead of extending it, so switching UTF-8 off really
    /// does stop UTF-8 text from being reported (rather than reporting it as something else).
    private static func scanBytewise(_ b: [UInt8], base: Int64,
                                     options: StringScanOptions, into hits: inout [FoundString]) {
        let wantUTF8 = options.encodings.contains(.utf8)
        let wantLatin1 = options.encodings.contains(.latin1)

        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(options.maximumLength)
        var runStart = -1
        var sawMultiByte = false
        var sawHighByte = false

        func flush(end: Int) {
            defer {
                runStart = -1
                scalars.removeAll(keepingCapacity: true)
                sawMultiByte = false
                sawHighByte = false
            }
            guard runStart >= 0, scalars.count >= options.minimumLength else { return }
            let kind: StringEncodingKind = sawHighByte ? .latin1 : (sawMultiByte ? .utf8 : .ascii)
            guard options.encodings.contains(kind) else { return }
            guard !options.plausibleOnly || qualifies(scalars, as: kind) else { return }
            hits.append(FoundString(offset: base + Int64(runStart), byteLength: end - runStart,
                                    encoding: kind, text: String(String.UnicodeScalarView(scalars))))
        }

        var i = 0
        while i < b.count {
            let byte = b[i]
            var advance = 1
            var scalar: Unicode.Scalar?
            var multiByte = false

            if byte < 0x80 {
                scalar = Unicode.Scalar(byte)
            } else if wantUTF8, let decoded = decodeUTF8(b, at: i) {
                scalar = decoded.scalar
                advance = decoded.length
                multiByte = true
            } else if wantLatin1, byte >= 0xA0 {
                // Latin-1 maps 1:1 onto U+00A0…U+00FF; 0x80…0x9F are C1 controls and end a run.
                scalar = Unicode.Scalar(byte)
            }

            if let scalar, isPrintable(scalar) {
                if runStart < 0 { runStart = i }
                scalars.append(scalar)
                if multiByte { sawMultiByte = true } else if byte >= 0x80 { sawHighByte = true }
                if scalars.count >= options.maximumLength { flush(end: i + advance) }
            } else {
                flush(end: i)
            }
            i += advance
        }
        flush(end: b.count)
    }

    /// Strictly decode one UTF-8 sequence at `i`: overlong forms, surrogates and anything
    /// past U+10FFFF are rejected, because accepting them is how a byte pattern that is not
    /// text gets reported as text.
    private static func decodeUTF8(_ b: [UInt8], at i: Int) -> (scalar: Unicode.Scalar, length: Int)? {
        let first = b[i]
        let length: Int
        var value: UInt32
        switch first {
        case 0xC2...0xDF: length = 2; value = UInt32(first & 0x1F)
        case 0xE0...0xEF: length = 3; value = UInt32(first & 0x0F)
        case 0xF0...0xF4: length = 4; value = UInt32(first & 0x07)
        default: return nil                       // continuation byte, or 0xC0/0xC1/0xF5+
        }
        guard i + length <= b.count else { return nil }
        for k in 1..<length {
            let cont = b[i + k]
            guard cont & 0xC0 == 0x80 else { return nil }
            value = (value << 6) | UInt32(cont & 0x3F)
        }
        switch length {
        case 3 where value < 0x800, 4 where value < 0x10000: return nil   // overlong
        default: break
        }
        guard value <= 0x10FFFF, !(0xD800...0xDFFF).contains(value),
              let scalar = Unicode.Scalar(value) else { return nil }
        return (scalar, length)
    }

    // MARK: - The UTF-16 passes

    private static func scanUTF16(_ b: [UInt8], base: Int64, littleEndian: Bool, from start: Int,
                                  kind: StringEncodingKind, options: StringScanOptions,
                                  into hits: inout [FoundString]) {
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(options.maximumLength)
        var runStart = -1

        func unit(_ at: Int) -> UInt16 {
            littleEndian ? UInt16(b[at]) | (UInt16(b[at + 1]) << 8)
                         : (UInt16(b[at]) << 8) | UInt16(b[at + 1])
        }
        func flush(end: Int) {
            defer { runStart = -1; scalars.removeAll(keepingCapacity: true) }
            guard runStart >= 0, scalars.count >= options.minimumLength else { return }
            guard !options.plausibleOnly || qualifies(scalars, as: kind) else { return }
            hits.append(FoundString(offset: base + Int64(runStart), byteLength: end - runStart,
                                    encoding: kind, text: String(String.UnicodeScalarView(scalars))))
        }

        var i = start
        while i + 1 < b.count {
            let u = unit(i)
            var advance = 2
            var scalar: Unicode.Scalar?
            if (0xD800...0xDBFF).contains(u) {
                // A high surrogate is only text if its low surrogate follows.
                if i + 3 < b.count {
                    let low = unit(i + 2)
                    if (0xDC00...0xDFFF).contains(low) {
                        let value = 0x10000 + (UInt32(u - 0xD800) << 10) + UInt32(low - 0xDC00)
                        scalar = Unicode.Scalar(value)
                        advance = 4
                    }
                }
            } else if !(0xDC00...0xDFFF).contains(u) {
                scalar = Unicode.Scalar(u)
            }

            if let scalar, isPrintable(scalar) {
                if runStart < 0 { runStart = i }
                scalars.append(scalar)
                if scalars.count >= options.maximumLength { flush(end: i + advance) }
            } else {
                flush(end: i)
            }
            i += advance
        }
        flush(end: i)
    }

    // MARK: - "Is this a string, or bytes that happen to be printable?"

    /// Whether a decoded run is worth showing, judged per reading.
    ///
    /// Printability alone is not a filter. Three quarters of all byte values are printable
    /// Latin-1, and *every* byte pair that is not a surrogate or an unassigned code point is
    /// printable UTF-16 — so over a compiled binary the two wide passes and the Latin-1 pass
    /// report tens of thousands of runs that are nothing but machine code seen through the
    /// wrong lens. The rule per reading:
    ///
    ///   * **ASCII and UTF-8** are kept as they are. A run of four or more ASCII characters
    ///     is what `strings(1)` reports and what people expect to see; a valid multi-byte
    ///     UTF-8 sequence is improbable enough by chance to need no further defence.
    ///   * **Latin-1** must look like accented text rather than byte soup: mostly ASCII, no
    ///     Latin-1 *symbols* (`¡ ¢ £ × ÷ °` and the rest — they occur in random data far more
    ///     than in prose), and at least one pair of adjacent ASCII letters. "Grüße" passes;
    ///     "å]éeë" does not.
    ///   * **UTF-16** must be predominantly ASCII, which is what the wide strings that
    ///     actually occur in files look like — Windows resources, .NET metadata, plists.
    ///     This is the rule that hides genuine CJK or Cyrillic UTF-16, because the same bytes
    ///     are also what ordinary ASCII text looks like read two bytes at a time and nothing
    ///     in the bytes themselves tells them apart. `plausibleOnly = false` is how to see it.
    static func qualifies(_ scalars: [Unicode.Scalar], as kind: StringEncodingKind) -> Bool {
        switch kind {
        case .ascii, .utf8:
            return true
        case .utf16le, .utf16be:
            return asciiFraction(scalars) >= 0.75
        case .latin1:
            guard asciiFraction(scalars) >= 0.6 else { return false }
            var previousWasASCIILetter = false
            var sawWord = false
            for s in scalars {
                if s.value >= 0xA0 {
                    // × (0xD7) and ÷ (0xF7) are the two non-letters inside the letter blocks.
                    guard (0xC0...0xFF).contains(s.value), s.value != 0xD7, s.value != 0xF7 else {
                        return false
                    }
                    previousWasASCIILetter = false
                    continue
                }
                let isLetter = (0x41...0x5A).contains(s.value) || (0x61...0x7A).contains(s.value)
                if isLetter, previousWasASCIILetter { sawWord = true }
                previousWasASCIILetter = isLetter
            }
            return sawWord
        }
    }

    private static func asciiFraction(_ scalars: [Unicode.Scalar]) -> Double {
        guard !scalars.isEmpty else { return 0 }
        var ascii = 0
        for s in scalars where s.value >= 0x20 && s.value < 0x7F { ascii += 1 }
        return Double(ascii) / Double(scalars.count)
    }

    // MARK: - Reconciliation

    /// Resolve candidates that claim the same bytes, keeping the one that reads most like
    /// text, and return what survives in file order.
    ///
    /// Candidates are clustered by overlap first, because the decision is only ever local:
    /// a run in one part of the file has nothing to say about a run in another. Within a
    /// cluster the best-scoring candidate takes its bytes and anything still disjoint from
    /// what has been kept is kept too — so a real short string next to a long one survives.
    static func reconcile(_ hits: [FoundString]) -> [FoundString] {
        guard hits.count > 1 else { return hits }
        let ordered = hits.sorted {
            $0.offset != $1.offset ? $0.offset < $1.offset : $0.byteLength > $1.byteLength
        }
        var out: [FoundString] = []
        out.reserveCapacity(ordered.count)
        var i = 0
        while i < ordered.count {
            var end = ordered[i].range.upperBound
            var j = i + 1
            while j < ordered.count, ordered[j].offset < end {
                end = Swift.max(end, ordered[j].range.upperBound)
                j += 1
            }
            if j == i + 1 {
                out.append(ordered[i])
            } else {
                out.append(contentsOf: best(in: Array(ordered[i..<j])))
            }
            i = j
        }
        return out.sorted { $0.offset < $1.offset }
    }

    /// Greedy pick over one overlap cluster, most text-like first.
    ///
    /// One tie this cannot break, and pretending otherwise would be worse than saying so:
    /// a big-endian run at offset *n* and a little-endian run at *n+1* over NUL-padded wide
    /// text decode to **the same characters over the same number of bytes**, because each
    /// reading takes the ASCII byte of every pair and one of the two zero bytes around the
    /// run. Nothing in the bytes distinguishes them. The tie therefore falls through to
    /// encoding precedence, which puts little-endian first — that is what wide strings in
    /// real files are, on every platform where UTF-16 in a binary is common. The cost when
    /// the guess is wrong is the label in the encoding column and one byte at each end of
    /// the selection; the text itself, which is what the row is read and clicked for, is
    /// identical either way.
    ///
    /// Clusters are a handful of candidates in practice (one real string plus the shifted
    /// and mis-endianed readings of it), which is why a quadratic disjointness check is the
    /// right one here. The 256 cap is a guard against a crafted file, not a normal path.
    private static func best(in cluster: [FoundString]) -> [FoundString] {
        var scored = cluster.map { (score: plausibility($0.text), hit: $0) }
        scored.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.hit.byteLength != $1.hit.byteLength { return $0.hit.byteLength > $1.hit.byteLength }
            if $0.hit.encoding != $1.hit.encoding {
                return $0.hit.encoding.precedence < $1.hit.encoding.precedence
            }
            return $0.hit.offset < $1.hit.offset
        }
        if scored.count > 256 { scored.removeSubrange(256...) }
        var kept: [FoundString] = []
        for candidate in scored {
            let r = candidate.hit.range
            if kept.contains(where: { $0.range.overlaps(r) }) { continue }
            kept.append(candidate.hit)
        }
        return kept
    }

    /// How much a decoded run reads like text, in 0…1.
    ///
    /// Two thirds of the weight is "is it ASCII", which is what separates a real string from
    /// the same bytes read as UTF-16 (that reading lands in the ideographs). The remaining
    /// third is "is it word-like" — letters, digits, spaces, punctuation — which is what
    /// keeps genuinely non-Latin text scoring above a run of assorted symbols.
    static func plausibility(_ text: String) -> Double {
        var total = 0.0, ascii = 0.0, wordish = 0.0
        for s in text.unicodeScalars {
            total += 1
            if s.value >= 0x20, s.value < 0x7F { ascii += 1 }
            if s.properties.isAlphabetic || CharacterSet.decimalDigits.contains(s)
                || CharacterSet.whitespaces.contains(s) || CharacterSet.punctuationCharacters.contains(s) {
                wordish += 1
            }
        }
        guard total > 0 else { return 0 }
        return (2 * ascii + wordish) / (3 * total)
    }

    // MARK: - Printability

    /// Is this scalar something a reader would recognise as part of a string?
    ///
    /// Tab counts; the other C0 controls, DEL, the C1 block, separators, formatting
    /// characters, private-use and unassigned code points do not. Unassigned matters more
    /// than it looks: it is what stops a UTF-16 pass from reporting arbitrary byte pairs as
    /// text, since most of the 16-bit space is not assigned to anything.
    static func isPrintable(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        if v == 0x09 { return true }
        if v < 0x20 || v == 0x7F { return false }
        if v < 0x80 { return true }
        if v <= 0x9F { return false }                    // C1 controls
        if v < 0x10000 { return printableBMP[Int(v) >> 6] & (1 << UInt64(v & 63)) != 0 }
        return isPrintableByCategory(s)
    }

    /// The rule itself, consulted directly for astral scalars and once per code point while
    /// the BMP table below is being built.
    static func isPrintableByCategory(_ s: Unicode.Scalar) -> Bool {
        switch s.properties.generalCategory {
        case .control, .format, .surrogate, .privateUse, .unassigned,
             .lineSeparator, .paragraphSeparator:
            return false
        default:
            return true
        }
    }
}

/// Printability of every BMP scalar as a bitmap, one bit per code point (8 KiB).
///
/// Built once, on first use. The alternative is an ICU property lookup per decoded scalar,
/// and the UTF-16 passes decode every second byte of the file twice over — that lookup was
/// the scan, by time. Below U+0080 the caller answers without consulting this at all.
private let printableBMP: [UInt64] = {
    var bits = [UInt64](repeating: 0, count: 0x10000 / 64)
    for v in 0..<UInt32(0x10000) {
        guard let scalar = Unicode.Scalar(v) else { continue }
        let printable: Bool
        if v == 0x09 { printable = true }
        else if v < 0x20 || v == 0x7F || (0x80...0x9F).contains(v) { printable = false }
        else if v < 0x80 { printable = true }
        else { printable = BinaryStrings.isPrintableByCategory(scalar) }
        if printable { bits[Int(v) >> 6] |= (1 << UInt64(v & 63)) }
    }
    return bits
}()
