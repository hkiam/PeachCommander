// SPDX-License-Identifier: Apache-2.0
// ChatComposer.swift - build the message actually sent to the model from the user's
// text plus file-manager context, so the assistant is grounded in the active panel
// and any explicitly attached files without the user typing paths. (ki.md: the AI
// knows the current selection, active panel, etc.)

import Foundation

/// A snapshot of the file-manager context attached to a message.
public struct ChatContext: Sendable, Equatable {
    public let folder: String
    public let selection: [String]
    public init(folder: String, selection: [String]) {
        self.folder = folder
        self.selection = selection
    }
}

public enum ChatComposer {
    /// The pieces of the composed format. Kept here so `compose` and `stripPaths`
    /// share one definition of it.
    private static let contextPrefix = "[Context — "
    private static let attachmentPrefix = "[Attached paths:"
    private static let folderField = "active folder: "

    /// Compose the model-facing message: a compact context header (active folder +
    /// selection), any explicitly attached paths, then the user's text. The UI shows
    /// the user's plain text; this composed form is what the model receives.
    public static func compose(userText: String, context: ChatContext?, attachments: [String]) -> String {
        var parts: [String] = []
        if let c = context {
            let sel: String
            if c.selection.isEmpty {
                sel = "none"
            } else {
                let names = c.selection.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
                sel = "\(c.selection.count) item(s): \(names)"
            }
            parts.append("\(contextPrefix)\(folderField)\(c.folder); selection: \(sel)]")
        }
        if !attachments.isEmpty {
            parts.append(attachmentPrefix + "\n" + attachments.joined(separator: "\n") + "]")
        }
        parts.append(userText)
        return parts.joined(separator: "\n")
    }

    /// The composed message with filesystem paths reduced to plain names — the form to
    /// resend when the on-device model rejects the original.
    ///
    /// Apple's on-device model screens its input and refuses what it doesn't read as
    /// natural language; one opaque path in the header (a temp folder, a UUID- or
    /// hash-named directory) is enough, and the turn then fails with
    /// `unsupportedLanguageOrLocale` however often the same text is resent. The names
    /// are the part the model actually needs: measured against the on-device model,
    /// keeping them while dropping the paths is accepted and answers correctly, whereas
    /// dropping the header wholesale is accepted but leaves the model nothing to go on.
    /// It still has `get_context` for the exact paths. Idempotent, and a message with no
    /// header comes back unchanged.
    public static func stripPaths(_ composed: String) -> String {
        var lines = composed.components(separatedBy: "\n")
        var header: [String] = []
        while let first = lines.first {
            if first.hasPrefix(contextPrefix), first.hasSuffix("]") {
                lines.removeFirst()
                // Every field survives except the active folder — the path-heavy one.
                let fields = first.dropFirst(contextPrefix.count).dropLast()
                    .components(separatedBy: "; ")
                    .filter { !$0.hasPrefix(folderField) }
                if !fields.isEmpty { header.append(contextPrefix + fields.joined(separator: "; ") + "]") }
            } else if first.hasPrefix(attachmentPrefix) {
                lines.removeFirst()
                var names: [String] = []
                while let path = lines.first {
                    lines.removeFirst()
                    let closes = path.hasSuffix("]")
                    let bare = closes ? String(path.dropLast()) : path
                    if !bare.isEmpty { names.append((bare as NSString).lastPathComponent) }
                    if closes { break }
                }
                if !names.isEmpty { header.append("[Attached files: " + names.joined(separator: ", ") + "]") }
            } else {
                break
            }
        }
        return (header + lines).joined(separator: "\n")
    }
}
