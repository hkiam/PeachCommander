// SPDX-License-Identifier: Apache-2.0
// PlanPhraseText.swift — a plan row in the user's language (F-478).
//
// The twin of `PlanPhrase.english`. That one is what the model, an MCP client and the audit log read,
// and it stays English on purpose; this one is what a person reads in the confirmation dialog, and it
// had been English too — translated chrome around untranslated sentences, in the one window where
// somebody agrees to a permanent delete.
//
// It lives in PCApp rather than beside the phrase for one reason: this is where the string catalogue
// is, where `Tools/check-strings-extracted.py` looks, and where the coverage gate counts. PCAutomation
// owns *what* a row says; the app owns the words.
//
// The two cannot drift. Both are a `switch` over the same enum, and Swift makes both exhaustive — a
// case added to `PlanPhrase.Key` fails to compile here until it has been given words.

import Foundation
import PCAutomation

enum PlanPhraseText {

    /// A row as the user should read it: the phrase in their language, or the English text when there
    /// is no phrase — a bare file name, or a macro step whose `note` is the user's own wording.
    static func text(of item: PlanItem) -> String {
        item.phrase.map(localized) ?? item.text
    }

    static func localized(_ phrase: PlanPhrase) -> String {
        let a = value(phrase, 0), b = value(phrase, 1)
        let n = phrase.count ?? 0
        switch phrase.key {
        case .createFolder:
            return String(format: String(localized: "Create the folder “%@”"), a)
        case .moveInto:
            return String(format: String(localized: "Move %1$@ into “%2$@”"), a, b)
        case .moveIntoUnnamed:
            return String(format: String(localized: "Move into “%@”"), a)
        case .copyInto:
            return String(format: String(localized: "Copy %1$@ into “%2$@”"), a, b)
        case .copyIntoUnnamed:
            return String(format: String(localized: "Copy into “%@”"), a)
        case .rename:
            return String(format: String(localized: "Rename “%1$@” to “%2$@”"), a, b)
        case .renameBatch:
            return String(format: String(localized: "Rename %lld file(s)"), n)
        case .trash:
            return String(format: String(localized: "Move %@ to the Trash"), a)
        case .deleteForever:
            return String(format: String(localized: "Permanently delete %@"), a)
        case .clearComment:
            return String(format: String(localized: "Clear the comment on “%@”"), a)
        case .setComment:
            return String(format: String(localized: "Comment “%1$@”: %2$@"), a, b)
        case .setTags:
            return String(format: String(localized: "Tag “%1$@”: %2$@"), a, b)
        case .writeFile:
            return String(format: String(localized: "Write the file “%@”"), a)
        case .mergeFiles:
            return String(format: String(localized: "Merge %1$lld file(s) into “%2$@”"), n, a)
        case .setConfig:
            return String(format: String(localized: "Set %1$@ = %2$@"), a, b)
        case .selectMask:
            return String(format: String(localized: "Select %@"), a)
        case .openPath:
            return String(format: String(localized: "Open “%@”"), a)
        case .runCommand:
            return String(format: String(localized: "Run the command %@"), a)
        case .runShell:
            return String(format: String(localized: "Run “%@” in a terminal"), a)
        case .otherTool:
            // A tool this build has no phrasing for — in practice one contributed by a plugin. Its
            // name and its values, with nothing invented around them: there is no sentence to
            // translate when nobody knows what the verb is.
            return b.isEmpty ? a : "\(a): \(b)"
        case .andMore:
            return String(format: String(localized: "%1$@ +%2$lld more"), a, n)
        case .resultOfStep:
            return String(format: String(localized: "the result of step %@"), a)
        case .fieldOfStep:
            return String(format: String(localized: "the “%1$@” of step %2$@"), a, b)
        case .nothingSelected:
            return String(localized: "nothing (nothing is selected)")
        case .whatAnEarlierStepSelects:
            return String(localized: "what an earlier step selects")
        case .emptyToken:
            return String(format: String(localized: "nothing (“%@” is empty)"), a)
        case .notWorkedOutYet:
            return String(localized: "a value that cannot be worked out yet")
        case .answerTo:
            return String(format: String(localized: "the answer to “%@”"), a)
        }
    }

    /// One value of a phrase, itself localized when it is a nested phrase — "Move *the result of step
    /// 2* into “out”" is one sentence and has to be translated as one.
    private static func value(_ phrase: PlanPhrase, _ index: Int) -> String {
        guard phrase.values.indices.contains(index) else { return "" }
        switch phrase.values[index] {
        case .literal(let s): return s
        case .phrase(let p):  return localized(p)
        }
    }
}
