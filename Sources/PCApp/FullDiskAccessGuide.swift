// FullDiskAccessGuide.swift - Full Disk Access detection & onboarding (F-299)
//
// A file manager needs to reach TCC-protected locations (Mail, Messages, other
// apps' data under ~/Library, other users' folders). macOS gates those behind
// "Full Disk Access". This helper detects, with a best-effort heuristic, whether
// the app has it, and guides the user to the right System Settings pane. It never
// blocks: the app keeps working with reduced access until access is granted.

import AppKit
import PCFoundation

@MainActor
enum FullDiskAccessGuide {
    private static let suppressKey = "PCSuppressFDAPrompt"
    private static let logger = PCFoundationLogger.logger

    /// Best-effort check: the current user's TCC database is readable only with
    /// Full Disk Access. If the file is missing we assume access is fine (avoid
    /// a false prompt) rather than nagging.
    static var isGranted: Bool {
        let tcc = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        guard FileManager.default.fileExists(atPath: tcc) else { return true }
        return FileManager.default.isReadableFile(atPath: tcc)
    }

    /// Shown once on launch: prompt only when access is missing and the user has
    /// not asked us to stop reminding them.
    static func checkAndPromptIfNeeded() {
        guard !isGranted else { return }
        guard !UserDefaults.standard.bool(forKey: suppressKey) else {
            logger.info("Full Disk Access not granted (prompt suppressed)")
            return
        }
        presentPrompt(allowSuppress: true)
    }

    /// The onboarding dialog. `allowSuppress` adds a "Don't remind me again" box
    /// (used on the automatic launch prompt, not when opened from the menu).
    static func presentPrompt(allowSuppress: Bool = false) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: "Grant Full Disk Access")
        alert.informativeText = String(localized: """
            Peach Commander can browse and manage all your files, but macOS keeps \
            some locations private (Mail, Messages, and other apps' data) until you \
            grant Full Disk Access.

            Open System Settings ▸ Privacy & Security ▸ Full Disk Access and enable \
            Peach Commander. The app keeps working with reduced access until then.
            """)
        alert.addButton(withTitle: String(localized: "Open System Settings"))
        alert.addButton(withTitle: String(localized: "Later"))
        if allowSuppress {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = String(localized: "Don't remind me again")
        }

        let response = alert.runModal()
        if allowSuppress, alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: suppressKey)
        }
        if response == .alertFirstButtonReturn {
            openSettings()
        }
    }

    /// Opens the Full Disk Access pane in System Settings.
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
