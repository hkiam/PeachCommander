// SPDX-License-Identifier: Apache-2.0
// ACLEntry.swift - Model + parser for macOS access-control-list entries (F-298).
//
// macOS ACLs are surfaced by `/bin/ls -le` as one line per entry:
//
//      0: user:maik1 allow read,write,delete
//      1: group:everyone deny delete
//
// and are rewritten with `/bin/chmod +a "<subject> <action> <perms>"`. This type
// models a single entry and round-trips to/from those two textual forms so the GUI
// editor stays a thin shell over tested string handling.

import Foundation

/// One ACL entry: a subject (user/group) granted or denied a set of rights.
public struct ACLEntry: Equatable {
    public enum Kind: String, CaseIterable { case user, group }
    public enum Action: String, CaseIterable { case allow, deny }

    public var kind: Kind
    public var name: String
    public var action: Action
    public var permissions: [String]   // e.g. ["read", "write", "delete"]

    public init(kind: Kind, name: String, action: Action, permissions: [String]) {
        self.kind = kind
        self.name = name
        self.action = action
        self.permissions = permissions
    }

    /// The `chmod +a` rule string, e.g. `user:maik1 allow read,write`.
    public var ruleString: String {
        "\(kind.rawValue):\(name) \(action.rawValue) \(permissions.joined(separator: ","))"
    }

    /// Parse the ACL lines of `ls -le`/`ls -led` output into entries, preserving order.
    /// The leading stat line and any non-ACL lines are ignored.
    public static func parse(lsOutput: String) -> [ACLEntry] {
        var out: [ACLEntry] = []
        for rawLine in lsOutput.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            // ACL lines start with "<index>:"; the stat line does not.
            guard let colon = line.firstIndex(of: ":"),
                  Int(line[line.startIndex..<colon]) != nil else { continue }
            let rest = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            let tokens = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard tokens.count >= 3 else { continue }
            // tokens[0] = "user:name" | "group:name", tokens[1] = allow|deny, tokens[2] = perms
            let subject = tokens[0].split(separator: ":", maxSplits: 1).map(String.init)
            guard subject.count == 2, let kind = Kind(rawValue: subject[0]),
                  let action = Action(rawValue: tokens[1]) else { continue }
            let perms = tokens[2].split(separator: ",").map(String.init)
            out.append(ACLEntry(kind: kind, name: subject[1], action: action, permissions: perms))
        }
        return out
    }
}
