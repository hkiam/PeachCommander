// SPDX-License-Identifier: Apache-2.0
// ModalWindowController.swift - Base for dialogs shown with NSApp.runModal(for:).
//
// A modal window created with `.closable` can be dismissed with the red button or ⌘W, which
// runs none of the dialog's own OK/Cancel code. `NSApp.runModal(for:)` then never returns
// and the *whole application* stays inside the modal loop: the main window ignores clicks
// and its title-bar buttons do nothing, while the menu bar keeps working — a hang that looks
// like something else entirely.
//
// Every such dialog needs the same two lines, so they live here rather than being copied
// five times. A protocol extension would not do: windowWillClose is delivered through
// Objective-C delegate dispatch, which does not see Swift protocol-extension defaults —
// inheritance does.
//
// Subclasses must still set `window.delegate = self` when they create their window.

import AppKit

class ModalWindowController: NSWindowController, NSWindowDelegate {
    /// End the modal session however the window was dismissed.
    ///
    /// Guarded on `modalWindow` so the ordinary OK/Cancel path — which has already called
    /// `stopModal()` before closing — cannot stop a session that is no longer ours.
    func windowWillClose(_ notification: Notification) {
        guard NSApp.modalWindow === window else { return }
        // Deferred, but scheduled on the *run loop* including the modal mode — not
        // DispatchQueue.main.
        //
        // Deferral is needed because stopping the session inside this notification lets
        // runModal(for:) return while AppKit is still tearing the window down; the caller
        // drops its last reference and the window is freed with a close animation
        // (_NSWindowTransformAnimation) still holding it, which crashed in objc_release.
        //
        // But a main-queue block is the wrong vehicle here. These dialogs are opened from a
        // main-actor Task (plugin command → PcRunCommand → runModal), and while that task
        // sits in a nested modal loop the main queue is not serviced — so the block would
        // never run and the app would stay modal, i.e. exactly the hang this fixes.
        // Measured, not assumed: from a main-actor Task, DispatchQueue.main.async never
        // returns from runModal while perform(inModes:) does.
        RunLoop.main.perform(inModes: [.modalPanel, .default, .common]) { NSApp.stopModal() }
    }
}
