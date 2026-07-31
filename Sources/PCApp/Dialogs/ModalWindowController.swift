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
        // Deferred on purpose. Stopping the session *inside* this notification lets
        // runModal(for:) return while AppKit is still tearing this window down: the caller
        // then drops its last reference and the window is freed with a close animation
        // (_NSWindowTransformAnimation) still holding it — an over-release that crashed with
        // SIGSEGV in objc_release. One run-loop turn later the close has completed.
        DispatchQueue.main.async { NSApp.stopModal() }
    }
}
