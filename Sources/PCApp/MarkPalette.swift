// SPDX-License-Identifier: Apache-2.0
// MarkPalette.swift - The shared, user-extensible highlight palette for the
// "Mark All" feature (editor + viewer). A fixed set of built-in colors plus
// any number of user-defined ones the user creates from the Mark dialog. Custom
// colors persist as `#RRGGBB` lines in markcolors.ini so they survive restarts;
// the marks that reference them are still session-only. All highlight colors are
// rendered at a fixed alpha so the underlying text stays readable.

import AppKit
import PCFoundation

@MainActor
enum MarkPalette {
    /// Alpha applied to every highlight color so text remains readable.
    static let highlightAlpha: CGFloat = 0.40

    /// Built-in colors (index 0 first, then cycled when no explicit choice).
    static let builtin: [NSColor] = [
        NSColor.systemYellow, .systemGreen, .systemTeal, .systemOrange, .systemPink, .systemPurple,
    ].map { $0.withAlphaComponent(highlightAlpha) }

    static let builtinNames = ["Yellow", "Green", "Teal", "Orange", "Pink", "Purple"]

    /// User-defined colors, as `#RRGGBB` (loaded once, appended by `addCustom`).
    private static var customHex: [String] = loadCustom()

    /// The full palette: built-in colors followed by user-defined ones.
    static var colors: [NSColor] {
        builtin + customHex.compactMap { hexColor($0)?.withAlphaComponent(highlightAlpha) }
    }

    /// Human-readable name for a palette index.
    static func name(_ i: Int) -> String {
        if i >= 0, i < builtinNames.count { return builtinNames[i] }
        return String(localized: "Custom \(i - builtinNames.count + 1)")
    }

    /// Append a user color (stored opaque; rendered translucent). Returns the
    /// palette index of the color — an existing one if identical.
    @discardableResult
    static func addCustom(_ color: NSColor) -> Int {
        let hex = hexString(color)
        if let ci = customHex.firstIndex(of: hex) { return builtin.count + ci }
        customHex.append(hex)
        save()
        return builtin.count + customHex.count - 1
    }

    // MARK: - Hex conversion

    /// `#RRGGBB` for a color (converted to sRGB; alpha dropped).
    static func hexString(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Parse `#RRGGBB` (or `RRGGBB`) into an opaque sRGB color.
    static func hexColor(_ hex: String) -> NSColor? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                       green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    // MARK: - Persistence (one #RRGGBB per line, markcolors.ini)

    private static var url: URL { ConfigPaths.resolve().markColors }

    private static func loadCustom() -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { hexColor($0) != nil }
    }

    private static func save() {
        let text = customHex.joined(separator: "\n") + "\n"
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
