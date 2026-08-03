// SPDX-License-Identifier: Apache-2.0
// DocumentFile.swift - Shared save/close helpers for the editable document
// windows (text editor, hex editor), which previously each carried an identical
// copy of the one-time `.bak` backup, the save-error alert, and the
// "Save changes to X?" dirty-close prompt.

import AppKit

@MainActor
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
            // A root-owned file is the ordinary case for an administrator, not an exception: /etc/hosts,
            // an nginx site, a launchd plist. Until now that ended here with "permission denied" and no
            // way forward, even though the app already knows how to ask for authorization (F-099).
            if (error as NSError).isPermissionDenied, offerPrivilegedSave(data, toPath: path) {
                return true
            }
            let alert = NSAlert()
            alert.messageText = String(localized: "Could not save")
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
    }

    /// Offer to save with administrator rights, and do it if the user agrees.
    ///
    /// The content goes through a temporary file and is moved into place by the privileged shell, not
    /// passed on a command line: an argument list is visible to every process on the machine via `ps`,
    /// and the whole point of the files an administrator edits this way is that their contents are not
    /// public. The temp file is created with 0600 before anything is written to it and removed
    /// afterwards, whatever happens.
    ///
    /// `cat > target` rather than `mv`, so the target keeps its own inode, owner and mode — replacing
    /// the file would silently hand a root-owned config to the editing user.
    private static func offerPrivilegedSave(_ data: Data, toPath path: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Save as administrator?")
        // One literal: String(localized:) takes a LocalizationValue, and a concatenation is not one.
        let explanation = String(localized: "%@ cannot be written with your current rights. macOS will ask for authorization; the file keeps its owner and permissions.")
        alert.informativeText = String(format: explanation, (path as NSString).lastPathComponent)
        alert.addButton(withTitle: String(localized: "Authorize…"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        let temporary = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("pc-privileged-\(ProcessInfo.processInfo.globallyUniqueString)")
        defer { try? FileManager.default.removeItem(atPath: temporary) }
        guard FileManager.default.createFile(atPath: temporary, contents: nil,
                                             attributes: [.posixPermissions: 0o600]),
              (try? data.write(to: URL(fileURLWithPath: temporary))) != nil else {
            return false
        }
        let command = "cat " + PrivilegedRunner.shellQuote(temporary)
            + " > " + PrivilegedRunner.shellQuote(path)
        if let failure = PrivilegedRunner.runShell(command) {
            let alert = NSAlert()
            alert.messageText = String(localized: "Could not save as administrator")
            alert.informativeText = failure
            alert.runModal()
            return false
        }
        return true
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
