// SPDX-License-Identifier: Apache-2.0
// StructureProblemText.swift - What a validation result says to the user (F-369).
//
// The check lives in PCFoundation and returns *reasons*; the words live here. Two reasons for the split,
// and the second one is the one that bites:
//
//   * CONVENTIONS.md: engine modules produce typed values, PCApp maps them to text.
//   * `Tools/extract-strings.sh` collects `String(localized:)` only from PCApp's own module, so a
//     sentence written in PCFoundation never enters `Localizable.xcstrings` — it would have shipped in
//     English in all eighteen translated languages, and no gate would have said a word.

import Foundation
import PCFoundation

enum StructureProblemText {

    /// The sentence for a problem, without the line number (the caller puts that in front).
    static func message(for reason: StructureValidator.Reason) -> String {
        switch reason {
        case .parser(let text):
            // The platform's own message, which macOS has already localized.
            return text
        case .parserMayBeAboutComments(let text):
            return text + " "
                + String(localized: "(this format allows comments, which the validator does not read)")
        case .duplicateKey(let key, let firstLine):
            return String(format: String(localized:
                "Duplicate key “%@” — also on line %d. The last one silently wins."), key, firstLine)
        case .trailingComma:
            return String(localized:
                "Trailing comma. Apple's parser accepts it; Python, Go and jq do not.")
        case .tabIndentation:
            return String(localized: "Tab in the indentation. YAML does not allow tabs to indent.")
        case .indentedUnderValue:
            return String(localized:
                "Indented deeper than the line above, which already has a value.")
        case .indentationMismatch(let indent, let open):
            return String(format: String(localized:
                "Indented by %d, which lines up with no level open here (%@)."),
                indent, open.map(String.init).joined(separator: ", "))
        case .unterminatedQuote:
            return String(localized: "Unterminated quote.")
        case .notWellFormedXML:
            return String(localized: "The document is not well-formed XML.")
        }
    }

    /// What the whole outcome says. `.checked` deliberately does not say "valid": there is no YAML parser
    /// on the system, and the difference between "parsed" and "looked at" is the user's to know.
    static func summary(for outcome: StructureValidator.Outcome) -> String {
        switch outcome {
        case .valid(let parser):
            return String(format: String(localized: "Valid — parsed by %@."), parser)
        case .checked:
            return String(localized: "No problem found — checked for structure, tabs, duplicate keys and quotes (not a full parse).")
        case .unsupported:
            return String(localized: "This format cannot be validated.")
        case .problem(let problem):
            return String(format: String(localized: "Line %d: %@"), problem.line,
                          message(for: problem.reason))
        }
    }
}
