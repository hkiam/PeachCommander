// SPDX-License-Identifier: Apache-2.0
// TextContentKind.swift - May this content go into an NSTextView? (Viewer, F-110/F-112)
//
// The viewer shows a file as text in one of two ways: a read-only NSTextView, which brings the native
// find bar, selection and marks, or a virtual view that indexes line starts and draws only what is on
// screen. The choice used to be made on size alone — under 4 MiB got the NSTextView.
//
// Size is the wrong question. Reported: open a ~1 MB PNG, switch to hex (instant), switch to text —
// and the app stops responding. Sampled in the act, the whole time was inside CoreText's
// `CTFontGetGlyphsForCharacters` and cmap-table parsing, reached from a full-document layout. Decoded,
// that PNG is 931,257 characters drawn from over 3,000 *different* Unicode scalars, and CoreText hunts
// through the font cascade for every one the monospaced font does not have. In a bare text view that
// layout took 2.0 s; in the running app it had not finished after twenty-six minutes.
//
// Being able to look at a binary as text is worth keeping — it is how you find the strings in one — so
// the answer is not to forbid it but to send it to the view that can cope, which never asks AppKit to
// lay the document out at all.
//
// Two questions decide it, because either alone lets a case through:
//
//   * the byte heuristic that already picks the initial mode — but it is a *proportion* of control
//     bytes, and it caught the reported PNG by 5.8 % against a 5 % threshold, while uniformly
//     distributed binary sits at 3.5 % and passes for text;
//   * whether the bytes decoded at all. Content that is not valid in its own encoding goes through a
//     lossy decode, and that is precisely what scatters scalars across Unicode. Measured both ways: a
//     900 KB uniformly random file (3.52 % control bytes, under the threshold) is caught by this one,
//     and a 444 KB German CP1252 text — not valid UTF-8 either — is not.

import Foundation

public enum TextContentKind {

    /// The bytes as text, and whether that text belongs in a virtual view rather than an NSTextView.
    ///
    /// One decode, not two: the caller needs the string anyway, and deciding on a second pass would
    /// mean two answers that can disagree about the same file.
    public static func decode(_ bytes: [UInt8], encoding: String.Encoding) -> (text: String, needsVirtualView: Bool) {
        let binaryBySample = BinaryHeuristic.isProbablyBinary(Array(bytes.prefix(4096)))
        if let exact = String(bytes: bytes, encoding: encoding) {
            return (exact, binaryBySample)
        }
        // Not valid in the encoding it was taken for: salvage what is there, and treat it as binary.
        return (String(decoding: bytes, as: UTF8.self), true)
    }

    // MARK: - One line too long to lay out unwrapped

    /// The longest line, in UTF-16 units, above which the viewer must wrap the text.
    ///
    /// Reported: the `document.xml` of a Word file — 620,490 characters on one line — took the app
    /// minutes to open. Sampled in the act, the whole time was inside `NSTextView.sizeToFit`, where
    /// TextKit 2 measures that line as a single CTLine and walks its caret offsets. Without wrapping the
    /// cost grows with the length of the line; wrapped, TextKit 2 lays out only what is on screen.
    /// Measured on that file in a bare text view: 0.94 s unwrapped, 0.03 s wrapped, and 17 ms unwrapped
    /// at 10,000 characters. The running app was far slower than the bare view, so the limit sits where
    /// even the bare view is still cheap, and long above any line written by hand.
    public static let wrapLineLength = 10_000

    /// Whether `text` has a line longer than `wrapLineLength`, so that it may go into an NSTextView only
    /// wrapped. CR, LF and CRLF all end a line.
    public static func hasOverlongLine(_ text: String, limit: Int = wrapLineLength) -> Bool {
        var run = 0
        for unit in text.utf16 {
            if unit == 0x0A || unit == 0x0D {
                run = 0
            } else {
                run += 1
                if run > limit { return true }
            }
        }
        return false
    }
}
