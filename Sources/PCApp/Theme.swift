// SPDX-License-Identifier: Apache-2.0
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
        statusBarText: NSColor.black,
        tabBarBackground: NSColor(white: 0.82, alpha: 1.0),
        tabBarActiveChip: NSColor.white,
        tabBarInactiveChip: NSColor(white: 0.90, alpha: 1.0),
        tabBarChipText: NSColor(white: 0.10, alpha: 1.0),
        tabBarActiveChipText: NSColor(white: 0.10, alpha: 1.0)
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
        statusBarText: NSColor(white: 0.9, alpha: 1.0),
        tabBarBackground: NSColor(white: 0.16, alpha: 1.0),
        tabBarActiveChip: NSColor(white: 0.34, alpha: 1.0),
        tabBarInactiveChip: NSColor(white: 0.22, alpha: 1.0),
        tabBarChipText: NSColor(white: 0.92, alpha: 1.0),
        tabBarActiveChipText: NSColor(white: 0.92, alpha: 1.0)
    )

    // MARK: - Norton Commander (F-2xx: selectable themes)
    //
    // The authentic CGA 16-colour values, which is what makes it read as the real thing:
    // blue #0000AA ground, cyan #00AAAA text, light cyan #55FFFF for the cursor row and
    // headers, yellow #FFFF55 as the accent, black on cyan for the bars.
    //
    // Colour only. The double-line box frames and the DOS raster font are structural and
    // typographic, not palette — deliberately out of scope, see DECISIONS.
    private static func cga(_ hex: String) -> NSColor { NSColor(hexString: hex)! }

    public static let norton = Colors(
        windowBackground: cga("0000AA"),
        listBackground: cga("0000AA"),
        listText: cga("00AAAA"),
        selectedText: cga("FFFF55"),          // marked files: NC's yellow
        cursorFrame: cga("00AAAA"),
        activePathBarBackground: cga("00AAAA"),
        activePathBarText: cga("000000"),
        inactivePathBarBackground: cga("0000AA"),
        inactivePathBarText: cga("AAAAAA"),
        pathBarBackground: cga("00AAAA"),
        pathBarText: cga("000000"),
        pathBarHoverBackground: cga("55FFFF"),
        pathBarSeparator: cga("000080"),
        pathBarFreeSpaceText: cga("000000"),
        columnSeparator: cga("000080"),
        functionButtonBackground: cga("00AAAA"),
        functionButtonPressed: cga("55FFFF"),
        functionButtonText: cga("000000"),
        statusBarBackground: cga("00AAAA"),
        statusBarText: cga("000000"),
        // The panel-drawing colours Phase 1 exposed. Without these the cursor row and the
        // drive bar would stay macOS-accent blue inside a CGA-blue panel.
        zebraRow: cga("000080").withAlphaComponent(0.35),
        selectionFillActive: cga("00AAAA"),          // NC inverts the cursor row…
        selectionFillInactive: cga("000080"),
        activeCursorFrame: cga("55FFFF"),
        headerSeparator: cga("000080"),
        driveBarBackground: cga("00AAAA"),
        driveBarHighlight: cga("55FFFF"),
        driveBarText: cga("000000"),
        driveBarHighlightText: cga("000000"),
        // The active panel's cursor bar is cyan, and the panel keeps the row's normal text
        // colour — which here is the same cyan. Without this the cursor row is invisible.
        cursorRowText: cga("000000"),
        // NC had no tabs; cyan-on-blue with the active tab inverted is the natural extension.
        tabBarBackground: cga("0000AA"),
        tabBarActiveChip: cga("00AAAA"),
        tabBarInactiveChip: cga("000080"),
        tabBarChipText: cga("00AAAA"),
        tabBarActiveChipText: cga("000000")   // black on the cyan active chip
    )

    // MARK: - Midnight (F-341)

    /// A dark palette that is not just "dark": deep indigo panels with a soft blue-grey text.
    ///
    /// Composed from `dark` with a dozen overrides rather than spelled out in full, which is
    /// exactly what a theme file with `Base = dark` does — the shipped palette and the documented
    /// user-theme mechanism are the same thing, so neither can drift from the other.
    public static let midnight: Colors = {
        var c = dark
        c.windowBackground = cga("0C0C18")
        c.listBackground = cga("101020")
        c.listText = cga("C8C8E0")
        c.selectedText = cga("FFD060")
        c.selectionFillActive = cga("2A2A55")
        c.activeCursorFrame = cga("6A6ACC")
        c.cursorRowText = cga("FFFFFF")
        c.activePathBarBackground = cga("2A2A55")
        c.activePathBarText = cga("E0E0F0")
        c.inactivePathBarBackground = cga("151528")
        c.inactivePathBarText = cga("9090B0")
        c.statusBarBackground = cga("1A1A30")
        c.statusBarText = cga("C8C8E0")
        c.functionButtonBackground = cga("1A1A30")
        c.functionButtonText = cga("C8C8E0")
        c.tabBarBackground = cga("101020")
        c.tabBarActiveChip = cga("2A2A55")
        c.tabBarInactiveChip = cga("181830")
        c.tabBarChipText = cga("9090B0")
        c.tabBarActiveChipText = cga("E0E0F0")
        return c
    }()

    // MARK: - Named palettes

    /// A selectable theme. `base` decides the window appearance (so system controls, sheets
    /// and scrollers match) while `colors` supplies the panel palette.
    public struct Palette {
        public let id: String
        public let name: String
        public let isDark: Bool
        public let colors: Colors
        public let syntax: SyntaxColors
        public init(id: String, name: String, isDark: Bool, colors: Colors, syntax: SyntaxColors) {
            self.id = id; self.name = name; self.isDark = isDark
            self.colors = colors; self.syntax = syntax
        }
    }

    /// `system` is not in this list on purpose: it means "follow the appearance", which is the
    /// default and resolves to the untouched light/dark palettes.
    /// Display names are localized, because they sit one row above the Appearance popup, which
    /// has always been localized — "Light / Dark" over "Hell / Dunkel" reads like a bug. "Norton
    /// Commander" stays as it is: it is the name of a program, not a description of a colour.
    static let builtInPalettes: [Palette] = [
        Palette(id: "light", name: String(localized: "Light"), isDark: false,
                colors: light, syntax: lightSyntax),
        Palette(id: "dark", name: String(localized: "Dark"), isDark: true,
                colors: dark, syntax: darkSyntax),
        Palette(id: "midnight", name: String(localized: "Midnight"), isDark: true,
                colors: midnight, syntax: darkSyntax),
        Palette(id: "norton", name: "Norton Commander", isDark: true,
                colors: norton, syntax: darkSyntax),
    ]

    /// Themes loaded from the user's `themes/` directory (F-274). Set once at startup by
    /// `ThemeFile.loadUserPalettes`; empty in tests and until that runs.
    public static var userPalettes: [Palette] = []

    /// Built-in palettes first, so a user file can never shadow a shipped one — `palette(id:)`
    /// takes the first match and `ThemeFile` rejects reserved ids outright.
    public static var palettes: [Palette] { builtInPalettes + userPalettes }

    /// Ids that a user theme file may not claim.
    public static var reservedPaletteIds: Set<String> { Set(["system"] + builtInPalettes.map(\.id)) }

    public static func palette(id: String) -> Palette? { palettes.first { $0.id == id } }

    /// Resolve the palette for a theme id, falling back to the appearance-driven default.
    ///
    /// Anything unknown — a removed theme, a typo in the config — lands on `system`, so a bad
    /// value can never leave the app unreadable.
    public static func resolve(themeId: String, isDark: Bool) -> (colors: Colors, syntax: SyntaxColors) {
        if let p = palette(id: themeId) { return (p.colors, p.syntax) }
        return isDark ? (dark, darkSyntax) : (light, lightSyntax)
    }

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
        // `var`, not `let`: a theme file names the colours it wants and the rest are inherited
        // from its base palette, which needs a keyed setter (see `setColor`). Nothing mutates
        // `Theme.current` in place — every assignment goes through a fresh copy.
        public var windowBackground: NSColor
        public var listBackground: NSColor
        public var listText: NSColor
        public var selectedText: NSColor
        public var cursorFrame: NSColor
        public var activePathBarBackground: NSColor
        public var activePathBarText: NSColor
        public var inactivePathBarBackground: NSColor
        public var inactivePathBarText: NSColor
        public var pathBarBackground: NSColor
        public var pathBarText: NSColor
        public var pathBarHoverBackground: NSColor
        public var pathBarSeparator: NSColor
        public var pathBarFreeSpaceText: NSColor
        public var columnSeparator: NSColor
        public var functionButtonBackground: NSColor
        public var functionButtonPressed: NSColor
        public var functionButtonText: NSColor
        public var statusBarBackground: NSColor
        public var statusBarText: NSColor

        // Panel-drawing colours that used to be hardcoded in PanelCells/DriveBarView. Their
        // defaults below reproduce exactly what was drawn before, so a palette that does not
        // mention them looks unchanged — that is what keeps light/dark pixel-identical.
        /// Zebra striping on alternate rows.
        public var zebraRow: NSColor
        /// Fill behind a selected row, active and inactive panel.
        public var selectionFillActive: NSColor
        public var selectionFillInactive: NSColor
        /// Cursor frame in the *active* panel (the inactive one uses `cursorFrame`).
        public var activeCursorFrame: NSColor
        /// Hairline under the column headers.
        public var headerSeparator: NSColor
        /// Drive bar: normal and highlighted button, and their labels.
        public var driveBarBackground: NSColor
        public var driveBarHighlight: NSColor
        public var driveBarText: NSColor
        public var driveBarHighlightText: NSColor

        /// Text colour for the cursor row in the *active* panel, or nil to leave the row's text
        /// alone (the default, and what the panel did before palettes existed).
        ///
        /// Needed because the cursor row is drawn as a filled bar while the text keeps its normal
        /// colour. A palette whose fill is close to its text colour then makes the cursor row
        /// unreadable — Norton's authentic cyan bar over cyan text is exactly that case, and it
        /// shipped that way. Marked files keep `selectedText`, so marking stays visible on the bar.
        public var cursorRowText: NSColor?

        // Tab bar (F-340). These were four hardcoded greys picked from the dark/light appearance,
        // so the bar stayed macOS-grey under a palette. The light/dark defaults below are exactly
        // those greys, which is why extracting them changes nothing.
        public var tabBarBackground: NSColor
        public var tabBarActiveChip: NSColor
        public var tabBarInactiveChip: NSColor
        /// Two text colours, because a palette may invert the active chip the way the cursor row is
        /// inverted — with one shared colour, Norton's cyan chip carried cyan text.
        public var tabBarChipText: NSColor
        public var tabBarActiveChipText: NSColor

        /// Set one colour by its declared name, case-insensitively. Returns `false` for an
        /// unknown name so a theme-file loader can report the typo instead of ignoring it.
        ///
        /// A switch rather than reflection: `Mirror` cannot write, and a `KeyPath` table would
        /// still have to be maintained by hand. `ThemeFile.colorKeys` is generated from this
        /// switch's cases by a test, so the two cannot drift apart.
        public mutating func setColor(named name: String, to color: NSColor) -> Bool {
            switch name.lowercased() {
            case "windowbackground": windowBackground = color
            case "listbackground": listBackground = color
            case "listtext": listText = color
            case "selectedtext": selectedText = color
            case "cursorframe": cursorFrame = color
            case "activepathbarbackground": activePathBarBackground = color
            case "activepathbartext": activePathBarText = color
            case "inactivepathbarbackground": inactivePathBarBackground = color
            case "inactivepathbartext": inactivePathBarText = color
            case "pathbarbackground": pathBarBackground = color
            case "pathbartext": pathBarText = color
            case "pathbarhoverbackground": pathBarHoverBackground = color
            case "pathbarseparator": pathBarSeparator = color
            case "pathbarfreespacetext": pathBarFreeSpaceText = color
            case "columnseparator": columnSeparator = color
            case "functionbuttonbackground": functionButtonBackground = color
            case "functionbuttonpressed": functionButtonPressed = color
            case "functionbuttontext": functionButtonText = color
            case "statusbarbackground": statusBarBackground = color
            case "statusbartext": statusBarText = color
            case "zebrarow": zebraRow = color
            case "selectionfillactive": selectionFillActive = color
            case "selectionfillinactive": selectionFillInactive = color
            case "activecursorframe": activeCursorFrame = color
            case "headerseparator": headerSeparator = color
            case "drivebarbackground": driveBarBackground = color
            case "drivebarhighlight": driveBarHighlight = color
            case "drivebartext": driveBarText = color
            case "drivebarhighlighttext": driveBarHighlightText = color
            // Optional in the struct, but a file can only ever *set* it — absence means nil, which
            // is the default. There is no way to write "leave the cursor row alone" explicitly,
            // and none is needed: omitting the key does exactly that.
            case "tabbarbackground": tabBarBackground = color
            case "tabbaractivechip": tabBarActiveChip = color
            case "tabbarinactivechip": tabBarInactiveChip = color
            case "tabbarchiptext": tabBarChipText = color
            case "tabbaractivechiptext": tabBarActiveChipText = color
            case "cursorrowtext": cursorRowText = color
            default: return false
            }
            return true
        }

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
            statusBarText: NSColor,
            // Defaults = the values these were hardcoded to, so the existing light/dark
            // literals stay valid and unchanged.
            zebraRow: NSColor = NSColor.gray.withAlphaComponent(0.08),
            selectionFillActive: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.22),
            selectionFillInactive: NSColor = NSColor.gray.withAlphaComponent(0.10),
            activeCursorFrame: NSColor = NSColor.controlAccentColor,
            headerSeparator: NSColor = NSColor.separatorColor,
            driveBarBackground: NSColor = NSColor.controlColor,
            driveBarHighlight: NSColor = NSColor.controlAccentColor,
            driveBarText: NSColor = NSColor.labelColor,
            driveBarHighlightText: NSColor = NSColor.white,
            cursorRowText: NSColor? = nil,
            tabBarBackground: NSColor,
            tabBarActiveChip: NSColor,
            tabBarInactiveChip: NSColor,
            tabBarChipText: NSColor,
            tabBarActiveChipText: NSColor
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
            self.zebraRow = zebraRow
            self.selectionFillActive = selectionFillActive
            self.selectionFillInactive = selectionFillInactive
            self.activeCursorFrame = activeCursorFrame
            self.headerSeparator = headerSeparator
            self.driveBarBackground = driveBarBackground
            self.driveBarHighlight = driveBarHighlight
            self.driveBarText = driveBarText
            self.driveBarHighlightText = driveBarHighlightText
            self.cursorRowText = cursorRowText
            self.tabBarBackground = tabBarBackground
            self.tabBarActiveChip = tabBarActiveChip
            self.tabBarInactiveChip = tabBarInactiveChip
            self.tabBarChipText = tabBarChipText
            self.tabBarActiveChipText = tabBarActiveChipText
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
                statusBarText: statusBarText,
                // Carried through explicitly. Without this the initialiser defaults would win
                // and a palette's own panel colours would silently revert to the macOS ones as
                // soon as the user has any custom colour set.
                zebraRow: zebraRow,
                selectionFillActive: selectionFillActive,
                selectionFillInactive: selectionFillInactive,
                activeCursorFrame: activeCursorFrame,
                headerSeparator: headerSeparator,
                driveBarBackground: driveBarBackground,
                driveBarHighlight: driveBarHighlight,
                driveBarText: driveBarText,
                driveBarHighlightText: driveBarHighlightText,
                cursorRowText: cursorRowText,
                tabBarBackground: tabBarBackground,
                tabBarActiveChip: tabBarActiveChip,
                tabBarInactiveChip: tabBarInactiveChip,
                tabBarChipText: tabBarChipText,
                tabBarActiveChipText: tabBarActiveChipText)
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

    // MARK: - Plugin bridge (F-338)

    /// "#RRGGBB", or "#RRGGBBAA" when the colour is translucent.
    ///
    /// Separate from `NSColor.hexString` on purpose: that one is what the settings colour wells
    /// round-trip through the config file, and widening its output would change values already
    /// written there. This one only ever feeds the plugin bridge.
    public static func pluginHex(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Int((c.redComponent * 255).rounded()), g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded()), a = Int((c.alphaComponent * 255).rounded())
        return a >= 255 ? String(format: "#%02X%02X%02X", r, g, b)
                        : String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }

    /// The theme as `getContext` keys a plugin can read (SPEC: contrib.h "theme.*").
    ///
    /// Two vocabularies, on purpose:
    ///
    ///   * **Semantic** — `theme.background`, `theme.text`, `theme.accent`, … A plugin draws a
    ///     list or a chart, not a drive bar, so it should not have to learn which panel element
    ///     happens to carry the colour it wants. These names also stay stable if the panel
    ///     colours are reorganised later.
    ///   * **Raw** — `theme.color.<propertyName>` for every colour in `Colors`, for the rare
    ///     plugin that wants to match one specific panel element exactly.
    ///
    /// A plugin that reads none of these is unaffected: the host simply answers keys nobody asks
    /// about. That is what makes this a pure addition rather than an ABI change.
    /// The current theme's plugin keys, rebuilt only when the theme changes.
    ///
    /// Not a convenience: `contribContextValue` builds the *whole* contribution context to answer a
    /// single key, and the context is built on every keystroke for keybinding lookup and on every
    /// menu validation. Computing this dictionary there — a Mirror pass over 30 fields plus 42 hex
    /// formats — put all of that on the key-handling path. Set by `applyAppearance`.
    nonisolated(unsafe) public static var pluginContext: [String: String] = [:]

    /// The nine syntax colours as `theme.syntax.<role>` keys.
    ///
    /// Separate from the panel colours because they answer a different question: a plugin that
    /// renders *code* needs a comment colour, not a drive-bar colour. Without these a plugin
    /// showing source had to invent its own palette, which is precisely the mismatch the theme
    /// bridge exists to avoid.
    public static func pluginSyntaxValues(_ s: SyntaxColors) -> [String: String] {
        [
            "theme.syntax.comment": pluginHex(s.comment),
            "theme.syntax.string": pluginHex(s.string),
            "theme.syntax.number": pluginHex(s.number),
            "theme.syntax.keyword": pluginHex(s.keyword),
            "theme.syntax.type": pluginHex(s.type),
            "theme.syntax.function": pluginHex(s.function),
            "theme.syntax.property": pluginHex(s.property),
            "theme.syntax.constant": pluginHex(s.constant),
            "theme.syntax.escape": pluginHex(s.escape),
        ]
    }

    public static func pluginContextValues(colors: Colors, isDark: Bool, themeId: String) -> [String: String] {
        var v: [String: String] = [
            "theme.id": themeId,
            "theme.isDark": isDark ? "1" : "0",
            // Semantic set. Deliberately small — every entry is something a plugin view actually
            // needs to draw a list, a chart or a form.
            "theme.background": pluginHex(colors.listBackground),
            "theme.windowBackground": pluginHex(colors.windowBackground),
            "theme.text": pluginHex(colors.listText),
            "theme.secondaryText": pluginHex(colors.pathBarFreeSpaceText),
            "theme.accent": pluginHex(colors.activeCursorFrame),
            "theme.separator": pluginHex(colors.columnSeparator),
            "theme.selectionBackground": pluginHex(colors.selectionFillActive),
            // The text colour to use *on* selectionBackground. A palette that inverts its cursor
            // row says so via cursorRowText; otherwise the normal text colour is what the panel
            // itself draws there, so a plugin matching the panel should use the same.
            "theme.selectionText": pluginHex(colors.cursorRowText ?? colors.listText),
            "theme.markedText": pluginHex(colors.selectedText),
            "theme.controlBackground": pluginHex(colors.driveBarBackground),
            "theme.controlText": pluginHex(colors.driveBarText),
        ]
        v.merge(pluginSyntaxValues(isDark ? darkSyntax : lightSyntax)) { a, _ in a }
        for (label, value) in Mirror(reflecting: colors).children {
            guard let label else { continue }
            if let c = value as? NSColor {
                v["theme.color.\(label)"] = pluginHex(c)
            } else if let c = value as? NSColor? {
                // Optional colours (cursorRowText): omit the key entirely when unset, so a plugin
                // can tell "the palette does not re-colour the cursor row" from "it is black".
                if let c { v["theme.color.\(label)"] = pluginHex(c) }
            }
        }
        return v
    }

    /// The palette id in effect, or "system" when none is selected (F-340).
    ///
    /// Needed by the few places that must draw *differently* rather than just with other colours —
    /// the column header hands its drawing back to AppKit unless a palette is active, which is what
    /// keeps the default header pixel-identical instead of a re-implementation of it.
    nonisolated(unsafe) public static var activePaletteId: String = "system"

    /// Whether a named palette is in effect.
    public static var paletteActive: Bool { palette(id: activePaletteId) != nil }

    /// The active custom-colour overrides; `applyAppearance` folds these into `current`.
    nonisolated(unsafe) public static var customColors = ColorOverride()
}

public extension NSColor {
    /// Parse "RRGGBB" / "#RRGGBB", or "RRGGBBAA" / "#RRGGBBAA" with alpha (sRGB);
    /// nil for empty or malformed input.
    ///
    /// Eight digits exist because two of the panel colours are deliberately translucent — the
    /// zebra stripe and the selection fill sit *over* the background. Without alpha a theme file
    /// could not express them and would have to fake the blend against one fixed background.
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
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
