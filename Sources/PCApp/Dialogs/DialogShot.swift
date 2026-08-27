// SPDX-License-Identifier: Apache-2.0
// DialogShot.swift — photographing a dialog without running it (F-478).
//
// CONVENTIONS.md: "A view is only verified by a picture." For a modal dialog that is harder than it
// sounds. `NSAlert.runModal()` called from a main-actor Task holds the main queue, so the automation
// script's next line — the one that would take the shot — never runs; the run hangs at `quit` instead.
// And a screen capture needs Screen Recording permission and photographs whatever else is on the
// display, which is both unreliable in a headless run and none of our business.
//
// So the alert is laid out, rendered with `cacheDisplay` — the same technique the `mainshot` verb uses
// — and never shown. Nothing is modal, the script runs on, and the picture is of this dialog alone.

import AppKit

enum DialogShot {

    /// Render `alert`'s window content to a PNG at `path`. Returns what it wrote, for the log.
    @MainActor
    static func capture(_ alert: NSAlert, to path: String) -> String {
        // `layout()` first: an alert built in code has no size until it is asked for one, and a
        // zero-sized content view photographs as nothing at all.
        alert.layout()
        guard let content = alert.window.contentView else { return "no content view" }
        let bounds = content.bounds
        guard bounds.width > 1, bounds.height > 1,
              let rep = content.bitmapImageRepForCachingDisplay(in: bounds) else {
            return "not renderable (\(Int(bounds.width))x\(Int(bounds.height)))"
        }
        content.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            return "PNG encoding failed"
        }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            // NSLogged as well as returned, because it is often the whole answer: a dialog that came
            // back 230 points wide was the defect, and the number said so before the picture did.
            let size = "\(Int(bounds.width))x\(Int(bounds.height))"
            NSLog("[dialogshot] %@ %@", size, path)
            return size
        } catch {
            return "could not write \(path): \(error)"
        }
    }
}
