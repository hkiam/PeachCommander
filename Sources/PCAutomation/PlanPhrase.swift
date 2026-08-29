// SPDX-License-Identifier: Apache-2.0
// PlanPhrase.swift — what a plan row *says*, apart from which language it says it in (F-478).
//
// The rows of a macro's confirmation were English in an app that ships in nineteen languages. The
// chrome around them was translated and the sentences inside were not, in the one window where a
// person agrees to a permanent delete.
//
// The fix is not a second string catalogue. PCAutomation has no business owning UI language, and it
// has a second reader whose language *is* English by construction: the model, the MCP client and the
// audit log all take `PlanItem.text`, where a translated sentence would be a regression. So a row
// carries both — the phrase (a key and its values) and the English rendering of it. The host renders
// the phrase into the user's language; everything else keeps the text.
//
// One table of shapes, two renderers, and they cannot drift: `english` is a `switch` over `Key` in
// this file, the host's is a `switch` over the same enum, and Swift makes both exhaustive. Adding a
// case here fails to compile there until it is translated.

import Foundation

/// One value inside a phrase: a name, or another phrase standing in for a value that is not known yet.
///
/// The nesting exists for one real case and is not general. "Move *the result of step 2* into “out”"
/// is a row the confirmation really shows — for a macro whose second step has not run — and without
/// it the sentence would be translated around an English fragment.
public indirect enum PlanValue: Sendable, Equatable, Codable {
    case literal(String)
    case phrase(PlanPhrase)

    /// The English rendering, for `PlanItem.text`.
    public var english: String {
        switch self {
        case .literal(let s): return s
        case .phrase(let p):  return p.english
        }
    }
}

/// How a stand-in travels from where it is decided to where the row is built.
///
/// `MacroPlan.rows(of:resolvedWith:)` finds out that one argument cannot be resolved yet, and the
/// sentence for the row is assembled later, from a JSON dictionary, by `MacroPlan.phrase`. So the
/// stand-in has to be carried *inside the argument value*, and it has to survive being read as a path
/// component along the way.
///
/// A marker rather than a sentence, because the sentence has to be translatable at the far end. The
/// delimiters are U+0001 and U+001F: neither can appear in a macOS file name, and a value that somehow
/// held one would at worst be rendered as itself. Strictly internal — `MacroPlaceholders` never sees
/// it, the audit log never sees it, and a test asserts that no rendered row contains one.
enum StandIn {
    static let open: Character = "\u{1}"
    static let separator: Character = "\u{1F}"

    static func marker(_ key: PlanPhrase.Key, _ values: [String] = []) -> String {
        String(open) + ([key.rawValue] + values).joined(separator: String(separator)) + String(open)
    }

    /// The phrase a marker stands for, or nil when `raw` is an ordinary value.
    static func phrase(in raw: String) -> PlanPhrase? {
        guard raw.count > 2, raw.hasPrefix(String(open)), raw.hasSuffix(String(open)) else { return nil }
        let fields = raw.dropFirst().dropLast().split(separator: separator, omittingEmptySubsequences: false)
        guard let head = fields.first, let key = PlanPhrase.Key(rawValue: String(head)) else { return nil }
        return PlanPhrase(key, literals: fields.dropFirst().map(String.init))
    }
}

/// What a row says, as a key and the values that go in it.
public struct PlanPhrase: Sendable, Equatable, Codable {

    /// Every sentence a plan row can be. Adding one is a compile error in the host until it has words.
    public enum Key: String, Sendable, Equatable, Codable, CaseIterable {
        case createFolder            // 0: folder
        case moveInto                // 0: what, 1: where
        case moveIntoUnnamed         // 0: where
        case copyInto                // 0: what, 1: where
        case copyIntoUnnamed         // 0: where
        case rename                  // 0: from, 1: to
        case renameBatch             // count
        case trash                   // 0: what
        case deleteForever           // 0: what
        case clearComment            // 0: file
        case setComment              // 0: file, 1: comment
        case setTags                 // 0: file, 1: tags
        case createFile              // 0: file
        case writeFile               // 0: file
        case mergeFiles              // 0: destination, count
        case setConfig               // 0: key, 1: value
        case selectMask              // 0: mask
        case openPath                // 0: path
        case runCommand              // 0: command id
        case runShell                // 0: command line
        case otherTool               // 0: tool name, 1: its values
        case andMore                 // 0: the first few, count: how many more
        // The stand-ins: a value the row cannot know yet.
        case resultOfStep            // 0: step id
        case fieldOfStep             // 0: field, 1: step id
        case nothingSelected
        case whatAnEarlierStepSelects
        case emptyToken              // 0: the token
        case notWorkedOutYet
        case answerTo                // 0: the question
    }

    public let key: Key
    public let values: [PlanValue]
    /// The one number a phrase may carry, for the keys whose sentence counts something.
    public let count: Int?

    public init(_ key: Key, _ values: [PlanValue] = [], count: Int? = nil) {
        self.key = key
        self.values = values
        self.count = count
    }

    /// Convenience for the common all-literal case.
    public init(_ key: Key, literals: [String], count: Int? = nil) {
        self.init(key, literals.map(PlanValue.literal), count: count)
    }

    private func value(_ index: Int) -> String {
        values.indices.contains(index) ? values[index].english : ""
    }

    /// The English sentence. What the model, an MCP client and the audit log read.
    public var english: String {
        let n = count ?? 0
        switch key {
        case .createFolder:  return "Create the folder “\(value(0))”"
        case .moveInto:      return "Move \(value(0)) into “\(value(1))”"
        case .moveIntoUnnamed: return "Move into “\(value(0))”"
        case .copyInto:      return "Copy \(value(0)) into “\(value(1))”"
        case .copyIntoUnnamed: return "Copy into “\(value(0))”"
        case .rename:        return "Rename “\(value(0))” to “\(value(1))”"
        case .renameBatch:   return "Rename \(n) file(s)"
        case .trash:         return "Move \(value(0)) to the Trash"
        case .deleteForever: return "Permanently delete \(value(0))"
        case .clearComment:  return "Clear the comment on “\(value(0))”"
        case .setComment:    return "Comment “\(value(0))”: \(value(1))"
        case .setTags:       return "Tag “\(value(0))”: \(value(1))"
        case .createFile:    return "Create the file “\(value(0))”"
        case .writeFile:     return "Write the file “\(value(0))”"
        case .mergeFiles:    return "Merge \(n) file(s) into “\(value(0))”"
        case .setConfig:     return "Set \(value(0)) = \(value(1))"
        case .selectMask:    return "Select \(value(0))"
        case .openPath:      return "Open “\(value(0))”"
        case .runCommand:    return "Run the command \(value(0))"
        case .runShell:      return "Run “\(value(0))” in a terminal"
        case .otherTool:     return value(1).isEmpty ? value(0) : "\(value(0)): \(value(1))"
        case .andMore:       return "\(value(0)) +\(n) more"
        case .resultOfStep:  return "the result of step \(value(0))"
        case .fieldOfStep:   return "the “\(value(0))” of step \(value(1))"
        case .nothingSelected: return "nothing (nothing is selected)"
        case .whatAnEarlierStepSelects: return "what an earlier step selects"
        case .emptyToken:    return "nothing (“\(value(0))” is empty)"
        case .notWorkedOutYet: return "a value that cannot be worked out yet"
        case .answerTo:      return "the answer to “\(value(0))”"
        }
    }
}
