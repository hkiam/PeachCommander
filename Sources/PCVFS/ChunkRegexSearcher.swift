// SPDX-License-Identifier: Apache-2.0
// ChunkRegexSearcher.swift - Regular-expression search over a file of any size (F-151).
//
// The viewer searches *bytes*: that is why it opens a 4 GB file instantly and why it has a hex mode.
// A regular expression cannot work that way — it needs decoded text — and a file that does not fit in
// memory cannot simply be turned into a String. So this walks the same overlapping windows
// `ChunkSearcher` already uses for plain byte search, decodes each window, and runs the pattern over
// it.
//
// Two things follow from that, and both are limits worth stating rather than hiding:
//
//   * **A match longer than the overlap can be missed** when it straddles a window boundary. With a
//     plain needle the overlap is `needle.count - 1`, which is exactly enough; a pattern has no
//     length to read off, so the overlap is a *choice* — `maxMatchLength`, 64 KB by default. Beyond
//     that the search is not wrong, it is incomplete, which is why the number is a parameter with a
//     name rather than a constant buried in a loop.
//   * **The window is decoded, not the file.** `^` and `$` are line anchors here (grep's meaning,
//     and what anyone typing `^ERROR` expects), which raises a trap: a window that begins in the
//     middle of a line would offer a `^` where there is no line start. So every window after the
//     first is trimmed to its first newline — the bytes dropped are ones the previous window
//     already covered, which is what the overlap is for. `\A`/`\z` still refer to the window and
//     are not useful.
//
// Byte offsets in, byte offsets out: the viewer scrolls to a byte, and a UTF-16 range into a decoded
// window is of no use to it. Converting back is the fiddly part and is done by measuring the encoded
// length of the text before the match, never by assuming one byte per character.

import Foundation

public enum ChunkRegexSearcher {

    /// How much of each window the next one repeats — and therefore the longest match that can
    /// still be found across a boundary.
    public static let defaultMaxMatchLength = 64 * 1024

    /// Compile `pattern`, or return the reason it will not compile.
    ///
    /// Separate from the search so a caller can say *why* a pattern was rejected. A search that
    /// quietly finds nothing because the expression was malformed reads exactly like "the text is
    /// not in this file", and the user concludes the wrong thing and stops looking.
    public static func compile(_ pattern: String,
                               caseInsensitive: Bool) -> (regex: NSRegularExpression?, error: String?) {
        // Line anchors, because this searches a file a person is reading: `^ERROR` should mean
        // "a line beginning with ERROR", which is what grep means and what anyone typing it expects.
        // Without this `^` binds to the start of the decoded window, which in a 4 GB file is a place
        // of no significance to anybody.
        var options: NSRegularExpression.Options = [.anchorsMatchLines]
        if caseInsensitive { options.insert(.caseInsensitive) }
        do { return (try NSRegularExpression(pattern: pattern, options: options), nil) }
        catch { return (nil, error.localizedDescription) }
    }

    /// The byte offset of the first match at or after `from`, or nil when there is none.
    public static func search(
        _ regex: NSRegularExpression,
        in slice: FileSlice,
        from: Int64 = 0,
        encoding: String.Encoding = .utf8,
        chunkSize: Int = 1 << 20,
        maxMatchLength: Int = defaultMaxMatchLength
    ) -> Int64? {
        forEachWindow(in: slice, from: from, encoding: encoding,
                      chunkSize: chunkSize, maxMatchLength: maxMatchLength) { text, windowStart in
            let ns = text as NSString
            guard let m = regex.firstMatch(in: text, options: [],
                                           range: NSRange(location: 0, length: ns.length)),
                  m.range.location != NSNotFound else { return nil }
            guard let offset = byteOffset(of: m.range.location, in: text, encoding: encoding) else { return nil }
            let absolute = windowStart + Int64(offset)
            // A window starts before `from` only when `from` sits mid-character; a match found in
            // that skipped head is not one the caller asked for.
            return absolute >= from ? absolute : nil
        }
    }

    /// The byte offset of the last match strictly before `before`, for a backward search.
    ///
    /// Scans forward within each window and keeps the last hit rather than searching backwards:
    /// `NSRegularExpression` has no reverse mode, and "the last match before X" is only answerable
    /// by looking at all of them in a window anyway.
    public static func searchBackwards(
        _ regex: NSRegularExpression,
        in slice: FileSlice,
        before: Int64,
        encoding: String.Encoding = .utf8,
        chunkSize: Int = 1 << 20,
        maxMatchLength: Int = defaultMaxMatchLength
    ) -> Int64? {
        guard before > 0 else { return nil }
        var best: Int64?
        _ = forEachWindow(in: slice, from: 0, encoding: encoding,
                          chunkSize: chunkSize, maxMatchLength: maxMatchLength) { text, windowStart -> Int64? in
            let ns = text as NSString
            regex.enumerateMatches(in: text, options: [],
                                   range: NSRange(location: 0, length: ns.length)) { m, _, stop in
                guard let m, m.range.location != NSNotFound,
                      let offset = byteOffset(of: m.range.location, in: text, encoding: encoding) else { return }
                let absolute = windowStart + Int64(offset)
                if absolute < before { best = max(best ?? absolute, absolute) } else { stop.pointee = true }
            }
            return nil   // never stop early: a later window may still hold a closer match
        }
        return best
    }

    // MARK: - Internals

    /// Walk overlapping windows, decode each, and hand it to `body` with its absolute start.
    /// Stops at the first window for which `body` answers non-nil.
    private static func forEachWindow(
        in slice: FileSlice, from: Int64, encoding: String.Encoding,
        chunkSize: Int, maxMatchLength: Int,
        _ body: (String, Int64) -> Int64?
    ) -> Int64? {
        guard from >= 0, from < slice.count, chunkSize > 0 else { return nil }
        let overlap = max(0, min(maxMatchLength, chunkSize - 1))
        var pos = from

        while pos < slice.count {
            let readLength = Int(min(Int64(chunkSize), slice.count - pos))
            guard readLength > 0 else { break }
            var bytes = slice.bytes(at: pos, length: readLength)
            var windowStart = pos

            // A window that begins in the middle of a multi-byte character would decode to
            // replacement characters and shift every offset after it. Step over the continuation
            // bytes instead — the previous window covered them, and it overlaps this one.
            if encoding == .utf8, windowStart > 0 {
                var skipped = 0
                while skipped < bytes.count, bytes[skipped] & 0xC0 == 0x80 { skipped += 1 }
                if skipped > 0 {
                    bytes.removeFirst(skipped)
                    windowStart += Int64(skipped)
                }
            }
            // A window that starts mid-line would let `^` match where no line begins. Drop the
            // partial first line; the overlap means the previous window already covered it. Never
            // for the first window — there the caller's `from` is the start, mid-line or not.
            if windowStart > from, let nl = bytes.firstIndex(of: 0x0A), nl + 1 < bytes.count {
                bytes.removeFirst(nl + 1)
                windowStart += Int64(nl + 1)
            }
            // …and one that ends mid-character would do the same at the tail. Only trim when there
            // is more file to come; at EOF the bytes are all there is.
            if encoding == .utf8, pos + Int64(readLength) < slice.count {
                var drop = 0
                while drop < 3, drop < bytes.count, bytes[bytes.count - 1 - drop] & 0xC0 == 0x80 { drop += 1 }
                if drop < bytes.count, drop > 0 || bytes.last.map({ $0 & 0x80 != 0 }) == true {
                    // Drop the trailing partial sequence, lead byte included.
                    if drop < bytes.count, bytes[bytes.count - 1 - drop] & 0xC0 == 0xC0 {
                        bytes.removeLast(drop + 1)
                    }
                }
            }

            if let text = String(bytes: bytes, encoding: encoding) ?? String(bytes: bytes, encoding: .isoLatin1),
               let hit = body(text, windowStart) {
                return hit
            }

            let advance = max(readLength - overlap, 1)
            pos += Int64(advance)
        }
        return nil
    }

    /// How many encoded bytes precede the character at UTF-16 offset `utf16Offset`.
    ///
    /// Measured, not assumed: one character is one byte only in a single-byte encoding, and the
    /// viewer scrolls to the number this returns — an assumption here puts the cursor in the wrong
    /// place in every file with an umlaut in it.
    static func byteOffset(of utf16Offset: Int, in text: String, encoding: String.Encoding) -> Int? {
        let ns = text as NSString
        guard utf16Offset >= 0, utf16Offset <= ns.length else { return nil }
        let prefix = ns.substring(to: utf16Offset)
        return prefix.data(using: encoding)?.count ?? prefix.utf8.count
    }
}
