// SPDX-License-Identifier: Apache-2.0
// PluginTheme.swift - Shared colour-theme helper for PeachCommander plugins (F-338).
//
// Add this file to a plugin's swiftc sources (see Tools/build-*-plugin.sh) and read the host's
// colours instead of hardcoding them, so a plugin's own window or view matches whatever theme the
// user picked — including Norton Commander, whose CGA blue looks nothing like any macOS
// appearance.
//
//     let theme = PluginTheme(services)
//     view.layer?.backgroundColor = theme.background.cgColor
//     label.textColor = theme.text
//
// Every property falls back to the system colour the plugins used before this existed, so:
//
//   * a plugin using PluginTheme against an OLDER host (no theme.* keys) looks exactly as it does
//     today — the fallbacks *are* today's colours, and
//   * a plugin that never adopts PluginTheme is equally unaffected.
//
// To follow theme changes while a window is open, export PcNotifyThemeChanged and rebuild:
//
//     @_cdecl("PcNotifyThemeChanged")
//     public func PcNotifyThemeChanged() { myWindowController?.applyTheme() }
//
// Views built with PcMakeView are additionally told through PcNotifyView(view, "theme", <id>).

import AppKit
// Plugins get PcHostServices from their bridging header (see Tools/build-*-plugin.sh), where no
// module exists; the host's own test target imports it as a module. Conditional so this one file
// compiles unchanged in both, which is what lets the SDK helper be tested at all.
#if canImport(CContrib)
import CContrib
#endif

/// The host's current colour theme, read once from `getContext`.
///
/// A snapshot, not a live view: colours cannot change under you mid-draw, and re-reading is one
/// cheap call when the host says the theme changed.
struct PluginTheme {
    /// Whether the host's UI is dark right now — a named theme decides this itself, so it is not
    /// the same as the macOS appearance. Use it to pick between two of your own assets.
    let isDark: Bool
    /// The selected theme's id ("system" when the user picked none).
    let id: String

    /// Background of a list or content area.
    let background: NSColor
    /// Background of the window as a whole (chrome around the content).
    let windowBackground: NSColor
    /// Primary text.
    let text: NSColor
    /// Dimmed text: captions, units, secondary detail.
    let secondaryText: NSColor
    /// The theme's accent — a focus ring, an active bar, a highlighted series.
    let accent: NSColor
    /// Hairlines between columns, rows and sections.
    let separator: NSColor
    /// Fill behind a selected row, and the text colour to use on top of it.
    let selectionBackground: NSColor
    let selectionText: NSColor
    /// The colour the host marks files with — use it for "flagged" state, not for selection.
    let markedText: NSColor
    /// Buttons and bars, and their labels.
    let controlBackground: NSColor
    let controlText: NSColor

    /// All system colours, for a property's initial value before services arrive. Spelled out
    /// rather than `PluginTheme(nil)`, which is ambiguous between the two initialisers below.
    static var systemFallback: PluginTheme { PluginTheme(nil as PcHostServices?) }

    /// Read the theme from the host. Falls back to system colours for any key the host does not
    /// answer, which is how an older host (or a future host that drops a key) behaves.
    init(_ services: UnsafePointer<PcHostServices>?) {
        self.init(services?.pointee)
    }

    /// Value-based, for the plugins that keep `services.pointee` rather than the pointer.
    ///
    /// The struct is copied deliberately: it is a plain table of function pointers plus the opaque
    /// `host` token, so a copy stays valid exactly as long as the original does — and holding a
    /// copy removes any question about the caller's pointer outliving this object.
    init(_ services: PcHostServices?) {
        func string(_ key: String) -> String? {
            guard let services, let get = services.getContext else { return nil }
            var buf = [CChar](repeating: 0, count: 128)
            let ok = key.withCString { k in get(services.host, k, &buf, Int32(buf.count)) }
            guard ok == 1 else { return nil }
            let s = String(cString: buf)
            return s.isEmpty ? nil : s
        }
        func color(_ key: String, _ fallback: NSColor) -> NSColor {
            string(key).flatMap { NSColor(pcHexString: $0) } ?? fallback
        }

        rawServices = services
        let hostId = string("theme.id")
        hostSuppliesTheme = hostId != nil
        id = hostId ?? "system"
        isDark = string("theme.isDark") == "1"

        // The fallbacks are exactly what the plugins hardcoded before, so adopting this helper is
        // never a visual change on its own — only picking a theme is.
        background = color("theme.background", .textBackgroundColor)
        windowBackground = color("theme.windowBackground", .windowBackgroundColor)
        text = color("theme.text", .labelColor)
        secondaryText = color("theme.secondaryText", .secondaryLabelColor)
        accent = color("theme.accent", .controlAccentColor)
        separator = color("theme.separator", .separatorColor)
        selectionBackground = color("theme.selectionBackground", .selectedContentBackgroundColor)
        // alternateSelectedControlTextColor is AppKit's "text on a selected control background";
        // selectedMenuItemTextColor is a menu-specific colour and was the wrong role here.
        selectionText = color("theme.selectionText", .alternateSelectedControlTextColor)
        markedText = color("theme.markedText", .systemRed)
        controlBackground = color("theme.controlBackground", .controlColor)
        controlText = color("theme.controlText", .labelColor)
    }

    /// One of the host's raw panel colours by name (e.g. "statusBarBackground") — the same names a
    /// user theme file uses. For the rare case where a plugin wants to match one specific host
    /// element rather than a semantic role.
    func hostColor(_ name: String, fallback: NSColor) -> NSColor {
        guard let services = rawServices, let get = services.getContext else { return fallback }
        var buf = [CChar](repeating: 0, count: 128)
        let ok = "theme.color.\(name)".withCString { k in get(services.host, k, &buf, Int32(buf.count)) }
        guard ok == 1 else { return fallback }
        return NSColor(pcHexString: String(cString: buf)) ?? fallback
    }

    /// A copy of the services table, so `hostColor` works after init without the caller storing
    /// `services` twice.
    private var rawServices: PcHostServices?

    /// Whether the host answered the theme keys at all. False against a host that predates them,
    /// in which case every property here is the system-colour fallback. Useful if a plugin wants
    /// a different code path rather than the fallbacks.
    private(set) var hostSuppliesTheme: Bool
}

extension NSColor {
    /// Parse the host's "#RRGGBB" or "#RRGGBBAA" (sRGB). Named distinctly from any host-internal
    /// helper because this file is compiled *into* plugins, where a plain `init?(hexString:)`
    /// would collide with a plugin's own.
    convenience init?(pcHexString: String) {
        var s = pcHexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        if s.count == 8 {
            self.init(srgbRed: CGFloat((v >> 24) & 0xFF) / 255, green: CGFloat((v >> 16) & 0xFF) / 255,
                      blue: CGFloat((v >> 8) & 0xFF) / 255, alpha: CGFloat(v & 0xFF) / 255)
        } else {
            self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                      blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        }
    }
}
