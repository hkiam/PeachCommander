// Theme.swift - UI theme constants for Peach Commander
//
// This file defines colors, fonts, and metrics for the TC-style UI.
// See docs/product/ui-reference.md for the visual target.

import AppKit

/// Theme constants for Peach Commander UI
public struct Theme {
    /// Light mode colors
    public static let light = Colors(
        windowBackground: NSColor(white: 1.0, alpha: 1.0),
        listBackground: NSColor(white: 1.0, alpha: 1.0),
        listText: NSColor.black,
        selectedText: NSColor.red,
        cursorFrame: NSColor(red: 0, green: 0, blue: 0.5, alpha: 1.0),
        activePathBarBackground: NSColor(red: 0.80, green: 0.88, blue: 1.0, alpha: 1.0),
        activePathBarText: NSColor.black,
        inactivePathBarBackground: NSColor(white: 0.9, alpha: 1.0),
        inactivePathBarText: NSColor(white: 0.3, alpha: 1.0),
        pathBarBackground: NSColor(white: 0.95, alpha: 1.0),
        pathBarText: NSColor.black,
        pathBarHoverBackground: NSColor(red: 0, green: 0, blue: 0.5, alpha: 0.2),
        pathBarSeparator: NSColor(white: 0.7, alpha: 1.0),
        pathBarFreeSpaceText: NSColor(white: 0.5, alpha: 1.0),
        columnSeparator: NSColor(white: 0.8, alpha: 1.0),
        functionButtonBackground: NSColor(white: 0.95, alpha: 1.0),
        functionButtonPressed: NSColor(white: 0.85, alpha: 1.0),
        functionButtonText: NSColor.black,
        statusBarBackground: NSColor(white: 0.95, alpha: 1.0),
        statusBarText: NSColor.black
    )

    /// Dark mode colors (TC-style dark palette)
    public static let dark = Colors(
        windowBackground: NSColor(white: 0.15, alpha: 1.0),
        listBackground: NSColor(white: 0.2, alpha: 1.0),
        listText: NSColor(white: 0.9, alpha: 1.0),
        selectedText: NSColor.red,
        cursorFrame: NSColor(red: 0.3, green: 0.3, blue: 1.0, alpha: 1.0),
        activePathBarBackground: NSColor(red: 0.24, green: 0.30, blue: 0.45, alpha: 1.0),
        activePathBarText: NSColor(white: 0.95, alpha: 1.0),
        inactivePathBarBackground: NSColor(white: 0.25, alpha: 1.0),
        inactivePathBarText: NSColor(white: 0.5, alpha: 1.0),
        pathBarBackground: NSColor(white: 0.25, alpha: 1.0),
        pathBarText: NSColor(white: 0.9, alpha: 1.0),
        pathBarHoverBackground: NSColor(red: 0.2, green: 0.2, blue: 0.6, alpha: 0.3),
        pathBarSeparator: NSColor(white: 0.3, alpha: 1.0),
        pathBarFreeSpaceText: NSColor(white: 0.6, alpha: 1.0),
        columnSeparator: NSColor(white: 0.3, alpha: 1.0),
        functionButtonBackground: NSColor(white: 0.25, alpha: 1.0),
        functionButtonPressed: NSColor(white: 0.35, alpha: 1.0),
        functionButtonText: NSColor(white: 0.9, alpha: 1.0),
        statusBarBackground: NSColor(white: 0.25, alpha: 1.0),
        statusBarText: NSColor(white: 0.9, alpha: 1.0)
    )

    /// Current theme (light or dark)
    public static var current: Colors = light

    // MARK: - Syntax highlighting palette (theme-aware)

    /// Colors for syntax-highlight capture families (tree-sitter + the built-in
    /// lexer). Kept separate from `Colors` so the large initializer is untouched.
    public struct SyntaxColors {
        public let comment, string, number, keyword, type, function, property, constant, escape: NSColor
        public init(comment: NSColor, string: NSColor, number: NSColor, keyword: NSColor,
                    type: NSColor, function: NSColor, property: NSColor, constant: NSColor, escape: NSColor) {
            self.comment = comment; self.string = string; self.number = number; self.keyword = keyword
            self.type = type; self.function = function; self.property = property
            self.constant = constant; self.escape = escape
        }
    }

    public static let lightSyntax = SyntaxColors(
        comment: .systemGreen, string: .systemRed, number: .systemBlue, keyword: .systemPurple,
        type: .systemIndigo, function: .systemTeal, property: .systemBrown,
        constant: .systemOrange, escape: .systemPink)

    /// Brighter, higher-contrast variants for the dark background.
    public static let darkSyntax = SyntaxColors(
        comment: NSColor(red: 0.55, green: 0.78, blue: 0.55, alpha: 1),
        string: NSColor(red: 0.95, green: 0.55, blue: 0.52, alpha: 1),
        number: NSColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1),
        keyword: NSColor(red: 0.83, green: 0.62, blue: 0.98, alpha: 1),
        type: NSColor(red: 0.60, green: 0.72, blue: 1.0, alpha: 1),
        function: NSColor(red: 0.45, green: 0.85, blue: 0.85, alpha: 1),
        property: NSColor(red: 0.86, green: 0.72, blue: 0.55, alpha: 1),
        constant: NSColor(red: 0.98, green: 0.72, blue: 0.45, alpha: 1),
        escape: NSColor(red: 0.96, green: 0.62, blue: 0.78, alpha: 1))

    /// The syntax palette matching the active theme (set alongside `current`).
    public static var currentSyntax: SyntaxColors = lightSyntax

    /// Colors struct
    public struct Colors {
        public let windowBackground: NSColor
        public let listBackground: NSColor
        public let listText: NSColor
        public let selectedText: NSColor
        public let cursorFrame: NSColor
        public let activePathBarBackground: NSColor
        public let activePathBarText: NSColor
        public let inactivePathBarBackground: NSColor
        public let inactivePathBarText: NSColor
        public let pathBarBackground: NSColor
        public let pathBarText: NSColor
        public let pathBarHoverBackground: NSColor
        public let pathBarSeparator: NSColor
        public let pathBarFreeSpaceText: NSColor
        public let columnSeparator: NSColor
        public let functionButtonBackground: NSColor
        public let functionButtonPressed: NSColor
        public let functionButtonText: NSColor
        public let statusBarBackground: NSColor
        public let statusBarText: NSColor

        public init(
            windowBackground: NSColor,
            listBackground: NSColor,
            listText: NSColor,
            selectedText: NSColor,
            cursorFrame: NSColor,
            activePathBarBackground: NSColor,
            activePathBarText: NSColor,
            inactivePathBarBackground: NSColor,
            inactivePathBarText: NSColor,
            pathBarBackground: NSColor,
            pathBarText: NSColor,
            pathBarHoverBackground: NSColor,
            pathBarSeparator: NSColor,
            pathBarFreeSpaceText: NSColor,
            columnSeparator: NSColor,
            functionButtonBackground: NSColor,
            functionButtonPressed: NSColor,
            functionButtonText: NSColor,
            statusBarBackground: NSColor,
            statusBarText: NSColor
        ) {
            self.windowBackground = windowBackground
            self.listBackground = listBackground
            self.listText = listText
            self.selectedText = selectedText
            self.cursorFrame = cursorFrame
            self.activePathBarBackground = activePathBarBackground
            self.activePathBarText = activePathBarText
            self.inactivePathBarBackground = inactivePathBarBackground
            self.inactivePathBarText = inactivePathBarText
            self.pathBarBackground = pathBarBackground
            self.pathBarText = pathBarText
            self.pathBarHoverBackground = pathBarHoverBackground
            self.pathBarSeparator = pathBarSeparator
            self.pathBarFreeSpaceText = pathBarFreeSpaceText
            self.columnSeparator = columnSeparator
            self.functionButtonBackground = functionButtonBackground
            self.functionButtonPressed = functionButtonPressed
            self.functionButtonText = functionButtonText
            self.statusBarBackground = statusBarBackground
            self.statusBarText = statusBarText
        }

        /// Return a copy with the four user-customisable panel colours overridden
        /// where the override is non-nil (F-272). Everything else is inherited.
        func applying(_ o: ColorOverride) -> Colors {
            Colors(
                windowBackground: windowBackground,
                listBackground: o.listBackground ?? listBackground,
                listText: o.listText ?? listText,
                selectedText: o.selectedText ?? selectedText,
                cursorFrame: o.cursorFrame ?? cursorFrame,
                activePathBarBackground: activePathBarBackground,
                activePathBarText: activePathBarText,
                inactivePathBarBackground: inactivePathBarBackground,
                inactivePathBarText: inactivePathBarText,
                pathBarBackground: pathBarBackground,
                pathBarText: pathBarText,
                pathBarHoverBackground: pathBarHoverBackground,
                pathBarSeparator: pathBarSeparator,
                pathBarFreeSpaceText: pathBarFreeSpaceText,
                columnSeparator: columnSeparator,
                functionButtonBackground: functionButtonBackground,
                functionButtonPressed: functionButtonPressed,
                functionButtonText: functionButtonText,
                statusBarBackground: statusBarBackground,
                statusBarText: statusBarText)
        }
    }

    /// User overrides for the four main panel colours (F-272). nil = theme default.
    public struct ColorOverride {
        public var listText: NSColor?
        public var listBackground: NSColor?
        public var selectedText: NSColor?
        public var cursorFrame: NSColor?
        public init(listText: NSColor? = nil, listBackground: NSColor? = nil,
                    selectedText: NSColor? = nil, cursorFrame: NSColor? = nil) {
            self.listText = listText; self.listBackground = listBackground
            self.selectedText = selectedText; self.cursorFrame = cursorFrame
        }
    }

    /// The active custom-colour overrides; `applyAppearance` folds these into `current`.
    nonisolated(unsafe) public static var customColors = ColorOverride()
}

public extension NSColor {
    /// Parse "RRGGBB" / "#RRGGBB" (sRGB); nil for empty or malformed input.
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    /// "RRGGBB" for this colour in sRGB.
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "%02x%02x%02x", Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}

/// Font metrics for Peach Commander UI
public struct Fonts {
    /// System font at 13pt (TC-like)
    public static let system13 = NSFont.systemFont(ofSize: 13)

    /// System monospaced digit font for size/date columns
    public static let monospacedDigit13 = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)

    /// Bold font for headers
    public static let bold13 = NSFont.boldSystemFont(ofSize: 13)

    /// Configurable panel-list font size (F-272), applied to the name/text cells.
    /// A global (all panels share one size, a Display option); read on the main thread.
    nonisolated(unsafe) public static var panelSize: CGFloat = 13
    public static var panelText: NSFont { NSFont.systemFont(ofSize: panelSize) }
    public static var panelMono: NSFont { NSFont.monospacedDigitSystemFont(ofSize: panelSize, weight: .regular) }
}

/// Layout metrics for Peach Commander UI
public struct Metrics {
    /// Row height in points (TC uses ~16px @ 12px, we use 18-20pt)
    public static let rowHeight: CGFloat = 19

    /// Column header height
    public static let columnHeaderHeight: CGFloat = 24

    /// Function key bar height
    public static let functionKeyBarHeight: CGFloat = 32

    /// Status bar height
    public static let statusBarHeight: CGFloat = 24

    /// Command line height
    public static let commandLineHeight: CGFloat = 24

    /// Minimum panel width
    public static let minPanelWidth: CGFloat = 200

    /// Panel padding
    public static let panelPadding: CGFloat = 4

    /// Splitter handle width
    public static let splitterWidth: CGFloat = 8

    /// Button corner radius
    public static let buttonCornerRadius: CGFloat = 4

    /// Column widths (Name, Ext, Size, Date, Attr)
    public static let columnWidths = (
        name: 200,
        ext: 50,
        size: 80,
        date: 120,
        attr: 60
    )
}
