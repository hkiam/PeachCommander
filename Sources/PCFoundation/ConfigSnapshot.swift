// SPDX-License-Identifier: Apache-2.0
// ConfigSnapshot.swift - Read config synchronously, once, before the window is on screen (F-360).
//
// `ConfigStore` is an actor, which is right for everything that happens while the app runs: writes are
// serialised, changes are broadcast, and disk I/O is debounced. It is wrong for exactly one moment —
// the one before the first frame is drawn.
//
// Every `await store.bool(…)` is a suspension point, and the window's whole appearance came from about
// fifty of them: the palette, the light/dark appearance, which bars are visible, side-by-side or
// stacked panels, the view modes, the saved window frame. All of that ran *after* the window was shown,
// so the first thing on screen was the built-in default and a moment later it corrected itself: a light
// window that turns dark, bars that appear and disappear, a window that jumps to another size.
//
// So this reads the file once, synchronously, at launch. Read-only on purpose: writes stay with the
// actor, which remains the single owner of the file, and this never becomes a second source of truth
// for anything but the first paint.

import Foundation

/// A synchronous, read-only view of an INI config file, for use before the first paint.
public struct ConfigSnapshot: Sendable {
    private let document: INIDocument

    /// Load and parse `url`. A missing or undecodable file reads as empty — every accessor takes a
    /// default, and a first launch must not be a special case.
    public init(url: URL) {
        if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
            document = INIDocument(parsing: text)
        } else {
            document = INIDocument()
        }
    }

    public func bool(_ section: String, _ key: String, default def: Bool) -> Bool {
        INIValue.bool(document.value(section: section, key: key), default: def)
    }

    public func int(_ section: String, _ key: String, default def: Int) -> Int {
        INIValue.int(document.value(section: section, key: key), default: def)
    }

    public func double(_ section: String, _ key: String, default def: Double) -> Double {
        INIValue.double(document.value(section: section, key: key), default: def)
    }

    public func string(_ section: String, _ key: String, default def: String) -> String {
        document.value(section: section, key: key) ?? def
    }

    /// Every key present in a section, in file order.
    ///
    /// The typed readers all ask about one known setting. A section whose keys are not known in
    /// advance — one per plugin view the user has moved — has to be enumerated instead.
    public func keys(inSection section: String) -> [String] {
        document.keys(inSection: section)
    }
}

/// How a raw INI string becomes a typed value.
///
/// Shared with ``ConfigStore`` rather than reimplemented: the snapshot and the actor read the same file
/// and must agree on what `Yes` means, or a setting would take effect differently before and after the
/// first paint — which is the one bug this whole exercise is about.
public enum INIValue {
    public static func bool(_ raw: String?, default def: Bool) -> Bool {
        guard let raw else { return def }
        switch raw.lowercased() {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: return def
        }
    }

    public static func int(_ raw: String?, default def: Int) -> Int {
        guard let raw, let parsed = Int(raw) else { return def }
        return parsed
    }

    public static func double(_ raw: String?, default def: Double) -> Double {
        guard let raw, let parsed = Double(raw) else { return def }
        return parsed
    }
}
