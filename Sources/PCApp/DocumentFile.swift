// SPDX-License-Identifier: Apache-2.0
// DocumentFile.swift - Shared save/close helpers for the editable document
// windows (text editor, hex editor), which previously each carried an identical
// copy of the one-time `.bak` backup, the save-error alert, and the
// "Save changes to X?" dirty-close prompt.

import AppKit

enum DocumentFile {
    /// Write `data` to `path`, making a one-time `.bak` copy of the original
    /// before the first overwrite this session. Shows an error alert on failure.
    /// Returns whether the write succeeded.
    @MainActor @discardableResult
    static func writeWithBackup(_ data: Data, toPath path: String, didBackup: inout Bool) -> Bool {
        let fm = FileManager.default
        if !didBackup, fm.fileExists(atPath: path) {
            let backup = path + ".bak"
            try? fm.removeItem(atPath: backup)
            try? fm.copyItem(atPath: path, toPath: backup)
        }
        didBackup = true
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "Could not save")
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
    }

    enum CloseChoice { case save, discard, cancel }

    /// The standard "Save changes to X?" prompt shown when a modified document is
    /// closing.
    @MainActor
    static func confirmClose(name: String) -> CloseChoice {
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Save changes to “%@”?", comment: ""), name)
        alert.addButton(withTitle: String(localized: "Save"))
        alert.addButton(withTitle: String(localized: "Discard"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }
}
