// SPDX-License-Identifier: Apache-2.0
// KeyboardLoop.swift - Make every window Tab-navigable (I19 T06, F-363).
//
// Measured, not suspected: `autorecalculatesKeyViewLoop` is **false** for a window created in code, and
// every window in this app is created in code. AppKit therefore never links the controls into a key-view
// loop, and Tab reaches only whatever chain happens to exist by accident. What that meant in practice:
//
//   * Settings — Tab reached the page list and nothing else. Every checkbox on every page and the Close
//     button were unreachable, and the loop was not even closed.
//   * Find Files — the search fields were reachable, but Start, View, Feed to Listbox, Close, the results
//     table and the tab switcher were not. The dialog could be filled in and not run.
//   * The editor's filter prompt — Tab reached Cancel and Run but not the command field.
//
// None of that is visible on screen, and none of it shows up in a screenshot: it is the same class of
// defect as a hand-drawn control with no accessibility element. A label nobody can focus is never read
// out either, so this is the half of accessibility that has to work first.
//
// Fixed centrally rather than window by window: the flag is a property of every window the app shows,
// including the ones added later, and a per-window call is a line each future dialog would have to
// remember. `recalculateKeyViewLoop()` then builds the loop in view order — exactly what a window loaded
// from a nib gets for free.

import AppKit

enum KeyboardLoop {
    private static var observer: NSObjectProtocol?

    /// Start giving every window that becomes key a working key-view loop.
    ///
    /// On becoming key, not on creation: a window's controls are built at various times — some in
    /// `init`, some when a page is first shown — and the loop has to be calculated after they exist.
    /// Becoming key is the moment the user can first press Tab, which is the only moment that matters.
    @MainActor
    static func install() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
                MainActor.assumeIsolated {
                    guard let window = note.object as? NSWindow else { return }
                    enable(for: window)
                }
            }
    }

    /// Rebuild `window`'s loop after its contents were exchanged.
    ///
    /// Needed even with the flag set: measured, AppKit does not notice a view swapped into a scroll
    /// view's document view, so Settings kept the loop it had when it opened — Tab reached the page list
    /// and not one control on any page.
    @MainActor
    static func rebuild(for window: NSWindow?) {
        guard let window else { return }
        enable(for: window)
        window.recalculateKeyViewLoop()
    }

    /// Turn on automatic key-loop maintenance for `window` and build the loop now.
    ///
    /// Idempotent, and cheap after the first time: with the flag set, AppKit keeps the loop up to date as
    /// views come and go, so this does its work once per window.
    @MainActor
    static func enable(for window: NSWindow) {
        guard !window.autorecalculatesKeyViewLoop else { return }
        window.autorecalculatesKeyViewLoop = true
        window.recalculateKeyViewLoop()
    }
}
