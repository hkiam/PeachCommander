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
            parts.append("[Context — active folder: \(c.folder); selection: \(sel)]")
        }
        if !attachments.isEmpty {
            parts.append("[Attached paths:\n" + attachments.joined(separator: "\n") + "]")
        }
        parts.append(userText)
        return parts.joined(separator: "\n")
    }
}
