// SPDX-License-Identifier: Apache-2.0
// AccessibleHotspot.swift - Make a custom-drawn control reachable by assistive technology (I19 T06).
//
// Several bars in this app draw their own controls and handle `mouseDown` themselves: the drive bar's
// volume chips, the tab bar's tabs. That is the right choice for how they look and how fast they
// draw, and it has one consequence nobody sees on screen — VoiceOver finds nothing there at all. Not
// "an unlabelled button": nothing. The view is one opaque rectangle, and every control inside it is
// invisible to anyone not using the mouse or the eyes.
//
// The fix is the same shape everywhere: those views already keep the frame of each chip so they can
// hit-test clicks, so they already know where their controls are and what they say. This wraps that
// into accessibility children — one element per chip, with a role, a label, and the same action the
// click performs.
//
// Deliberately not a general solution for the whole app. NSButton, NSTableView and friends bring
// their own support and need nothing; this is for the views that draw themselves.

import AppKit

/// One accessibility element standing in for a hand-drawn control.
///
/// `NSAccessibilityElement` exists precisely for this: the drawn thing has no view of its own, so the
/// element carries its frame and answers on its behalf. The press handler is the same closure the
/// view's `mouseDown` would run, so the two paths cannot drift apart.
final class AccessibleHotspot: NSAccessibilityElement {
    private let press: () -> Void

    /// - Parameters:
    ///   - label: what a screen reader announces — the volume's name, the tab's title.
    ///   - role: `.button` for something that acts, `.radioButton` for one of a set where one is on.
    ///   - selected: for radio buttons, whether this is the chosen one.
    ///   - frameInView: the chip's rect in its view's coordinates; converted on demand.
    ///   - parent: the drawing view, needed for the coordinate conversion.
    ///   - press: performed for an accessibility press, exactly as a click would.
    init(label: String, role: NSAccessibility.Role, selected: Bool = false,
         frameInView: NSRect, parent: NSView, press: @escaping () -> Void) {
        self.press = press
        super.init()
        setAccessibilityLabel(label)
        setAccessibilityRole(role)
        setAccessibilityParent(parent)
        setAccessibilityEnabled(true)
        if role == .radioButton {
            // A radio button's value is what tells the reader *which* tab is the current one; without
            // it every tab announces identically and the answer to "where am I" is missing.
            setAccessibilityValue(selected ? 1 : 0)
        }
        // Screen coordinates, because that is what the accessibility API asks for. Computed once here
        // rather than in an override: these bars are laid out and then redrawn as a whole, and a stale
        // frame is corrected by the rebuild rather than by a live query.
        if let window = parent.window {
            setAccessibilityFrame(window.convertToScreen(parent.convert(frameInView, to: nil)))
        } else {
            setAccessibilityFrame(frameInView)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        press()
        return true
    }

    /// What the element is for, spoken after the label. Kept short: VoiceOver reads it every time.
    override func accessibilityHelp() -> String? {
        accessibilityRole() == .radioButton
            ? String(localized: "Switch to this tab")
            : String(localized: "Open this location")
    }
}
