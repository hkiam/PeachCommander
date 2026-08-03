// SPDX-License-Identifier: Apache-2.0
// LineEndings.swift - Which line terminator a text uses, and converting between them (F-358).
//
// A file that came from a Windows colleague, a CRLF-terminated .bat, a diff that is entirely "^M" —
// line endings are invisible until they break something: a shell script that fails with `\r: command
// not found`, a config the parser reads wrong, a diff that shows every line as changed. The editor knew
// nothing about them, so it could neither tell you nor fix it.
//
// The buffer holds the real terminators: an NSTextView round-trips CRLF unchanged (measured, not
// assumed), so both showing and converting are honest — nothing is normalised behind the user's back at
// load, and nothing is re-encoded at save.

import Foundation

/// A line terminator.
public enum LineEnding: String, CaseIterable, Sendable {
    /// `\n` — Unix, macOS, and everything a developer's tooling expects by default.
    case lf
    /// `\r\n` — Windows, and the network protocols that inherited it.
    case crlf
    /// `\r` — classic Mac OS. Rare, and worth naming when it does turn up.
    case cr

    public var characters: String {
        switch self {
        case .lf: return "\n"
        case .crlf: return "\r\n"
        case .cr: return "\r"
        }
    }

    /// The name to show. Not localised: these are the names in every editor, diff and protocol
    /// document, and translating them would make them harder to recognise, not easier.
    public var displayName: String {
        switch self {
        case .lf: return "LF"
        case .crlf: return "CRLF"
        case .cr: return "CR"
        }
    }
}

/// What terminators a text actually contains.
public struct LineEndingSurvey: Equatable, Sendable {
    public let lf: Int
    public let crlf: Int
    public let cr: Int

    public init(lf: Int, crlf: Int, cr: Int) {
        self.lf = lf
        self.crlf = crlf
        self.cr = cr
    }

    /// The terminator to show and to treat as the file's own. The most frequent one wins; ties go to
    /// LF, which is what a new file gets.
    public var dominant: LineEnding {
        if crlf > lf && crlf >= cr { return .crlf }
        if cr > lf && cr > crlf { return .cr }
        return .lf
    }

    /// Whether more than one kind is present — the case that actually causes trouble, and the reason
    /// this is a survey rather than a single answer.
    public var isMixed: Bool {
        [lf, crlf, cr].filter { $0 > 0 }.count > 1
    }

    /// No terminators at all: a single line, or an empty file. Then there is nothing to report.
    public var isEmpty: Bool { lf == 0 && crlf == 0 && cr == 0 }

    /// `LF`, or `CRLF (mixed)` — what the status line shows.
    public var displayName: String {
        isMixed ? "\(dominant.displayName) (mixed)" : dominant.displayName
    }
}

public enum LineEndings {
    /// Count each kind of terminator. A `\r\n` counts once, as CRLF — not as a CR and an LF.
    public static func survey(_ text: String) -> LineEndingSurvey {
        var lf = 0, crlf = 0, cr = 0
        var pendingCR = false
        for unit in text.utf8 {
            if pendingCR {
                pendingCR = false
                if unit == 0x0A { crlf += 1; continue }
                cr += 1
            }
            if unit == 0x0D { pendingCR = true } else if unit == 0x0A { lf += 1 }
        }
        if pendingCR { cr += 1 }
        return LineEndingSurvey(lf: lf, crlf: crlf, cr: cr)
    }

    /// How many lines `text` contains.
    ///
    /// Not `split(separator: "\n").count`: in Swift `"\r\n"` is a *single* Character, so splitting a
    /// CRLF text on "\n" matches nothing and reports one line for a whole file. That is not a corner
    /// case — it made the editor say "1 line(s)" after sorting a four-line Windows file, and it is
    /// invisible in any test written with LF input.
    ///
    /// A final terminator does not add a line: "a\n" is one line, as `wc -l` counts it.
    public static func lineCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let survey = survey(text)
        let terminators = survey.lf + survey.crlf + survey.cr
        let last = text.utf8.last
        return terminators + ((last == 0x0A || last == 0x0D) ? 0 : 1)
    }

    /// Rewrite every terminator as `ending`.
    ///
    /// Via LF: converting CRLF to CR directly would need every pairing rule again, and normalising
    /// first makes mixed input — the case this exists for — fall out correctly.
    public static func convert(_ text: String, to ending: LineEnding) -> String {
        let normalised = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return ending == .lf ? normalised
            : normalised.replacingOccurrences(of: "\n", with: ending.characters)
    }
}
