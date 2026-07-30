// main.swift - Entry point for PeachCommander

import AppKit

/// Application delegate: owns the main window controller and persists state on quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: MainWindowController?
    private let crashReports = CrashReportCollector()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MainWindowController()
        mainWindow = controller
        // Build the content (and set the window frame) BEFORE showing the window.
        // Replacing the contentView of an already-visible Auto Layout window makes
        // AppKit resize it to the content's fitting size (collapsing it to a strip).
        controller.start()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Let the Services menu offer services that act on file selections; the
        // active panel supplies the URLs via NSServicesMenuRequestor.
        NSApp.registerServicesMenuSendTypes([.fileURL], returnTypes: [])
        // Surface any crash report that appeared since we last looked (F-313).
        crashReports.checkForNewReports()
        // Guide the user to grant Full Disk Access if it's missing (F-299).
        FullDiskAccessGuide.checkAndPromptIfNeeded()
        // Per-window menu swapping lives in MainWindowController (it owns the command
        // target + the cached full menu bar).
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Persist session/config before quitting (async → reply when done).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller = mainWindow else { return .terminateNow }
        Task { @MainActor in
            await controller.persistNow()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
