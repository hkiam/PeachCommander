// SPDX-License-Identifier: Apache-2.0
// ThemedWindows.swift — paint the app's own windows in the selected palette (F-339).
//
// A named theme sets `NSApp.appearance` from its own light/dark base, which already gives every
// dialog matching system controls, scrollers and sheets. What it does not give is the *background*:
// an app-owned dialog shows the window background wherever no opaque view covers it, and that stays
// the macOS default — which is how the Settings window came up in system grey next to CGA-blue
// panels.
//
// One central sweep rather than a call in each of the 26 window-creation sites: those are easy to
// miss and a window added next year would silently be left out. The cost of centralising is that
// eligibility has to be decided here, deliberately — see `isOurs`.
//
// Scope is the window background only. Retinting the views *inside* a window (tables, text areas)
// was tried and removed: it cannot be undone soundly. Restoring needs the pre-theme colour, and
// for the views the app already binds to `Theme.current` — the Settings source list is one — the
// value captured on first touch is *already themed*, so switching back to the default restored the
// theme colour and left the default appearance wrong. Those surfaces are handled by their own
// window's `applyTheme()`, which re-derives from `Theme.current` instead of remembering.
//
// Nothing here runs unless a named palette is selected. With "system" — the default — every window
// keeps the exact background macOS gives it, so this file cannot change the default appearance.

import AppKit

@MainActor
enum ThemedWindows {
    /// Whether the app may paint this window.
    ///
    /// Two rules, both chosen so that nothing has to be kept in a list that can go stale:
    ///
    ///   * **Exact class, or one of ours.** Every dialog the app creates is a plain `NSWindow` (or
    ///     the single `NSPanel`), and the one subclass, `MainWindow`, comes from our own bundle.
    ///     AppKit's own panels are all *subclasses* — NSOpenPanel, NSSavePanel, NSColorPanel,
    ///     NSFontPanel, NSPrintPanel, and the private panel behind NSAlert. Requiring an exact
    ///     class or our bundle excludes every one of them without naming any: an alert is a
    ///     system-level interruption and a print panel draws content that assumes the standard
    ///     background, so neither is ours to restyle.
    ///   * **No plugin views.** A plugin's window is its own chrome; plugins are told about the
    ///     theme through `PcNotifyThemeChanged` and decide for themselves, and the host reaching
    ///     into their windows would fight them. Checking the *content view's* bundle is not enough:
    ///     every shipped plugin adds its subviews to the default content view, which is a plain
    ///     AppKit `NSView`, so all of them looked like ours. The whole tree has to be checked.
    ///
    /// The main window is excluded because `applyAppearance` paints it directly and more precisely.
    private static func isOurs(_ window: NSWindow, mainWindow: NSWindow?) -> Bool {
        if window === mainWindow { return false }
        let cls: AnyClass = type(of: window)
        let isPlainWindow = cls == NSWindow.self || cls == NSPanel.self
        if !isPlainWindow, Bundle(for: cls) !== Bundle.main { return false }
        if let content = window.contentView, containsPluginView(content) { return false }
        return true
    }

    /// Whether any view in this tree was defined by a loaded plugin.
    ///
    /// Tested by bundle path rather than by "is it AppKit": our own windows legitimately contain
    /// views from other system frameworks (the viewer's `WKWebView`), and treating any non-AppKit
    /// bundle as foreign would wrongly skip them. All five plugin kinds end in "plugin".
    private static func containsPluginView(_ view: NSView) -> Bool {
        let bundle = Bundle(for: type(of: view))
        if bundle !== Bundle.main, bundle.bundlePath.hasSuffix("plugin") { return true }
        return view.subviews.contains { containsPluginView($0) }
    }

    /// Paint every eligible window, or restore the system background when no palette is selected.
    /// Called from `applyAppearance`, so it runs on every theme change and once at startup.
    static func apply(themeId: String, mainWindow: NSWindow?) {
        for window in NSApp.windows { consider(window, themeId: themeId, mainWindow: mainWindow) }
    }

    /// Paint one window as it opens.
    ///
    /// `apply` only reaches windows that exist at the time, and most dialogs are created long after
    /// the theme was set. `NSWindow.didBecomeKeyNotification` is the hook that catches them: a
    /// window becomes key when it is shown, including a modal one.
    static func applyOnOpen(_ window: NSWindow, themeId: String, mainWindow: NSWindow?) {
        consider(window, themeId: themeId, mainWindow: mainWindow)
    }

    /// The theme a window was last painted for, so the eligibility checks and the tree walk stay
    /// off the focus-switch path — `didBecomeKeyNotification` fires on every focus change.
    ///
    /// A one-byte allocation rather than `&someStaticVar`: Swift does not promise a stable address
    /// for a static stored property accessed with `&`, and an association key that moves would
    /// never match on read — the guard would silently stop working and every set would leak a new
    /// association. Allocated once for the process lifetime and deliberately never freed.
    private static let paintedThemeKey = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

    private static func consider(_ window: NSWindow, themeId: String, mainWindow: NSWindow?) {
        // Marked before the eligibility test, and for ineligible windows too: otherwise a plugin
        // window would have its whole view tree walked again on every focus change.
        if let painted = objc_getAssociatedObject(window, paintedThemeKey) as? String, painted == themeId {
            return
        }
        objc_setAssociatedObject(window, paintedThemeKey, themeId, .OBJC_ASSOCIATION_RETAIN)
        guard isOurs(window, mainWindow: mainWindow) else { return }
        // NSWindow.backgroundColor is not optional, and a titled window's default value *is*
        // windowBackgroundColor — a dynamic colour that tracks the appearance — so assigning it
        // back is a genuine restore rather than an approximation of one.
        window.backgroundColor = Theme.palette(id: themeId) != nil
            ? Theme.current.windowBackground
            : .windowBackgroundColor
    }
}
