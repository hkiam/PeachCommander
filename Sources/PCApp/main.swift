// SPDX-License-Identifier: Apache-2.0
// main.swift - Entry point for PeachCommander

import AppKit
import PCFoundation

/// Application delegate: owns the main window controller and persists state on quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: MainWindowController?
    private let crashReports = CrashReportCollector()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Before any window exists: every window this app shows is built in code, and AppKit does not
        // maintain a key-view loop for those unless asked (I19 T06).
        KeyboardLoop.install()
        let controller = MainWindowController()
        mainWindow = controller
        // Build the content (and set the window frame) BEFORE showing the window.
        // Replacing the contentView of an already-visible Auto Layout window makes
        // AppKit resize it to the content's fitting size (collapsing it to a strip).
        controller.start()
        controller.showWindow(nil)
        #if DEBUG
        // Right after the window is shown, before anything asynchronous has had a turn: the state
        // recorded here is the state of the first frame (F-360).
        controller.writeStartupProbeIfRequested()
        #endif
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

    /// Persist session/config and tear plugin views down before quitting (async → reply when done).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller = mainWindow else {
            // Even with no window: a plugin view may still be holding a child process, and a reply of
            // .terminateNow is the last moment anything can be asked to let go.
            ViewContainerRegistry.shared.closeAll()
            return .terminateNow
        }
        Task { @MainActor in
            await controller.persistNow()
            // After the session is safely on disk and before the reply, because teardown can block for
            // as long as a child takes to die and must not cost the user their layout if it goes wrong.
            ViewContainerRegistry.shared.closeAll()
            // Open mounts get the same treatment as plugin views, and for the same reason: an FTP
            // control connection, an SSH session and a plugin's connection handle were all simply
            // killed with the process, because the only teardown they had was `deinit` — which does
            // not run at exit. `pfx.h` promises plugins this moment; this is where it is kept.
            // With a deadline, because `.terminateLater` means the reply below is the only thing
            // that ends the app — and AppKit spends the wait inside `-[NSApplication terminate:]`
            // running a restricted event loop, which is the user watching a frozen window. Measured
            // against a server that accepted the connection and then stopped answering: the app was
            // asked to quit and was still there 46 seconds later, with no way out but Force Quit.
            //
            // Three seconds is the whole budget for saying goodbye to every mount. A connection that
            // has not managed it by then is not going to, and the process is about to die anyway:
            // the sockets go with it, which is what used to happen before any of this existed.
            await withDeadline(seconds: 3) { @MainActor in
                await controller.closeAllMountsForTermination()
            }
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
