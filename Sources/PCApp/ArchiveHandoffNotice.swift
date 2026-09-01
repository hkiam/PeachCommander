// SPDX-License-Identifier: Apache-2.0
// ArchiveHandoffNotice.swift - Saying once that the copy is a copy (F-479).
//
// Opening a spreadsheet out of a zip works now, and the thing it does is open a *copy*: the archive
// is not rewritten when the user saves. Silence there is the worst of the three possible answers —
// worse than refusing, which is what F4 does today, and worse than writing back, which is a feature
// of its own. An application that has been handed a read-only file says "read only" at the top, and
// this says why, once, with a box to stop saying it.
//
// Modelled on `FullDiskAccessGuide`: same suppression key shape, same one-off shape.

import AppKit
import PCFoundation

@MainActor
enum ArchiveHandoffNotice {

    private static let suppressKey = "PCArchiveHandoffNoticeSuppressed"

    /// Shown before the file reaches the other application, so the sentence arrives before the
    /// document does rather than behind it.
    ///
    /// Never during a scripted run: `runModal` spins a nested runloop that drains the main queue, so
    /// the script carries on and *looks* fine while `quit` never lands and the run hangs until
    /// somebody clicks. F-436 fixed exactly this for the two launch-time prompts, and the rule the
    /// project wrote down then applies to every dialog added since.
    static func presentIfNeeded(name: String) {
        guard LaunchOptions.parse(CommandLine.arguments).automationScript == nil else { return }
        guard !UserDefaults.standard.bool(forKey: suppressKey) else { return }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: "Opening a copy of “\(name)”")
        alert.informativeText = String(localized: """
            The file was unpacked from the archive to a temporary, read-only copy, and that copy is \
            what opens. Changes are not written back into the archive.

            To edit it, unpack it first (F5) and work on the unpacked file.
            """)
        alert.addButton(withTitle: String(localized: "Open"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = String(localized: "Don't show this again")
        alert.runModal()
        if alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: suppressKey)
        }
    }
}
