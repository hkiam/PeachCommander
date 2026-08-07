// SPDX-License-Identifier: Apache-2.0
// DocumentMenus.swift - One source of truth for the menu taxonomy shared by the
// text Editor and the file Viewer (and reusable by the hex editor / compare
// windows). Both windows expose the SAME top-level menus (File / Edit / View /
// Search) with the SAME key equivalents, so they feel identical; per-window
// differences are expressed only through DocumentMenuCaps (which items apply)
// and the uniform `doc*` action selectors each controller implements.
//
// Granular mark management (remove one occurrence / one search) lives in the
// docked marks panel; the menu only offers "Clear All Marks".

import AppKit

/// Which document actions a given window/mode supports. Drives which menu items
/// are built so the shared taxonomy adapts per window without diverging.
struct DocumentMenuCaps {
    var editable = false          // Save, Replace
    var saveAs = false            // Save As… (export the document, F-121)
    var printable = false         // Print… (F-121)
    var reprText = false, reprCode = false, reprHex = false
    var reprImage = false, reprRendered = false, reprAuto = false
    var encoding = false
    var format = false
    var xmlTree = false
    var xpath = false
    var goto = false
    var findPrev = false          // reverse search available
    var replace = false
    var marks = false
    var markNav = false           // Next/Previous Mark
    var multiFile = false         // Next/Previous File
    var note = false              // Note for This Line… (F-379; only when the Notes plugin is there)

    var hasRepresentations: Bool {
        reprText || reprCode || reprHex || reprImage || reprRendered || reprAuto
    }
}

/// Uniform action selectors both the Editor and Viewer controllers implement, so
/// one menu builder can target either. Names are the contract between
/// `DocumentMenus` and the controllers.
enum DocumentAction {
    static let save = Selector(("docSave"))
    static let saveAs = Selector(("docSaveAs"))
    static let print = Selector(("docPrint"))
    static let reload = Selector(("docReload"))
    static let nextFile = Selector(("docNextFile"))
    static let prevFile = Selector(("docPrevFile"))
    static let reprText = Selector(("docReprText"))
    static let reprCode = Selector(("docReprCode"))
    static let reprHex = Selector(("docReprHex"))
    static let reprImage = Selector(("docReprImage"))
    static let reprRendered = Selector(("docReprRendered"))
    static let reprAuto = Selector(("docReprAuto"))
    static let cycleEncoding = Selector(("docCycleEncoding"))
    static let format = Selector(("docFormat"))
    static let xmlTree = Selector(("docXMLTree"))
    static let xpath = Selector(("docXPath"))
    static let find = Selector(("docFind"))
    static let findNext = Selector(("docFindNext"))
    static let findPrev = Selector(("docFindPrev"))
    static let replace = Selector(("docReplace"))
    static let goToLocation = Selector(("docGoto"))
    static let markAll = Selector(("docMarkAll"))
    static let count = Selector(("docCount"))
    static let nextMark = Selector(("docNextMark"))
    static let prevMark = Selector(("docPrevMark"))
    static let toggleMarksPanel = Selector(("docToggleMarksPanel"))
    static let clearAllMarks = Selector(("docClearAllMarks"))
    static let copy = Selector(("docCopy"))
    static let selectAll = Selector(("docSelectAll"))
    static let note = Selector(("docNote"))
}

@MainActor
enum DocumentMenus {
    /// The ordered top-level menus for a document tool window: File, Edit, View,
    /// Search. `editMenu` is supplied by the controller (native for the editor,
    /// a Copy/Select-All menu for the read-only viewer).
    static func toolMenus(caps: DocumentMenuCaps, editMenu: NSMenu, target: AnyObject) -> [NSMenu] {
        [fileMenu(caps, target), editMenu, viewMenu(caps, target), searchMenu(caps, target)]
    }

    /// A right-click context menu mirroring View + Search (used by both windows so
    /// the contextual menu is consistent too).
    static func contextMenu(caps: DocumentMenuCaps, target: AnyObject) -> NSMenu {
        let menu = NSMenu()
        appendRepresentations(to: menu, caps, target)
        appendViewActions(to: menu, caps, target, leadingSeparator: caps.hasRepresentations)
        menu.addItem(.separator())
        appendSearch(to: menu, caps, target)
        if caps.multiFile {
            menu.addItem(.separator())
            add(menu, String(localized: "Previous File"), DocumentAction.prevFile, target)
            add(menu, String(localized: "Next File"), DocumentAction.nextFile, target)
        }
        return menu
    }

    // MARK: - Top-level menus

    private static func fileMenu(_ caps: DocumentMenuCaps, _ target: AnyObject) -> NSMenu {
        let menu = NSMenu(title: String(localized: "File"))
        if caps.editable { add(menu, String(localized: "Save"), DocumentAction.save, target, "s") }
        if caps.saveAs { add(menu, String(localized: "Save As…"), DocumentAction.saveAs, target, "s", [.command, .shift]) }
        if caps.printable { add(menu, String(localized: "Print…"), DocumentAction.print, target, "p") }
        add(menu, String(localized: "Reload"), DocumentAction.reload, target)
        if caps.multiFile {
            menu.addItem(.separator())
            add(menu, String(localized: "Next File"), DocumentAction.nextFile, target, "]")
            add(menu, String(localized: "Previous File"), DocumentAction.prevFile, target, "[")
        }
        menu.addItem(.separator())
        // Close routes through the responder chain (nil target).
        let close = NSMenuItem(title: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        close.keyEquivalentModifierMask = .command
        menu.addItem(close)
        return menu
    }

    private static func viewMenu(_ caps: DocumentMenuCaps, _ target: AnyObject) -> NSMenu {
        let menu = NSMenu(title: String(localized: "View"))
        appendRepresentations(to: menu, caps, target)
        appendViewActions(to: menu, caps, target, leadingSeparator: caps.hasRepresentations)
        return menu
    }

    private static func searchMenu(_ caps: DocumentMenuCaps, _ target: AnyObject) -> NSMenu {
        let menu = NSMenu(title: String(localized: "Search"))
        appendSearch(to: menu, caps, target)
        return menu
    }

    // MARK: - Shared sections

    private static func appendRepresentations(to menu: NSMenu, _ caps: DocumentMenuCaps, _ target: AnyObject) {
        if caps.reprText { add(menu, String(localized: "Text"), DocumentAction.reprText, target) }
        if caps.reprCode { add(menu, String(localized: "Code"), DocumentAction.reprCode, target) }
        if caps.reprHex { add(menu, String(localized: "Hex"), DocumentAction.reprHex, target) }
        if caps.reprImage { add(menu, String(localized: "Image"), DocumentAction.reprImage, target) }
        if caps.reprRendered { add(menu, String(localized: "Rendered (Markdown/HTML)"), DocumentAction.reprRendered, target) }
        if caps.reprAuto { add(menu, String(localized: "Auto-Detect"), DocumentAction.reprAuto, target) }
    }

    private static func appendViewActions(to menu: NSMenu, _ caps: DocumentMenuCaps, _ target: AnyObject, leadingSeparator: Bool) {
        var sepAdded = false
        func sep() { if leadingSeparator, !sepAdded { menu.addItem(.separator()); sepAdded = true } }
        if caps.encoding { sep(); add(menu, String(localized: "Cycle Text Encoding"), DocumentAction.cycleEncoding, target, "e", [.command, .option]) }
        if caps.format { sep(); add(menu, String(localized: "Format"), DocumentAction.format, target) }
        if caps.xmlTree { sep(); add(menu, String(localized: "XML Tree"), DocumentAction.xmlTree, target) }
        // A note about a place in the document: a view-level annotation, and the marks panel below is
        // where it shows up, so this is the menu it belongs in.
        if caps.note { sep(); add(menu, String(localized: "Note for This Line…"), DocumentAction.note, target, "n", [.command, .shift]) }
    }

    private static func appendSearch(to menu: NSMenu, _ caps: DocumentMenuCaps, _ target: AnyObject) {
        add(menu, String(localized: "Find…"), DocumentAction.find, target, "f")
        add(menu, String(localized: "Find Next"), DocumentAction.findNext, target, "g")
        if caps.findPrev { add(menu, String(localized: "Find Previous"), DocumentAction.findPrev, target, "g", [.command, .shift]) }
        if caps.replace { add(menu, String(localized: "Replace…"), DocumentAction.replace, target, "f", [.command, .option]) }
        if caps.goto {
            menu.addItem(.separator())
            add(menu, String(localized: "Go to Line/Offset…"), DocumentAction.goToLocation, target, "l")
        }
        if caps.xpath { add(menu, String(localized: "XPath Query…"), DocumentAction.xpath, target) }
        if caps.marks {
            menu.addItem(.separator())
            add(menu, String(localized: "Mark All Occurrences…"), DocumentAction.markAll, target, "m", [.command, .shift])
            add(menu, String(localized: "Count Occurrences"), DocumentAction.count, target, "k", [.command, .shift])
            if caps.markNav {
                add(menu, String(localized: "Next Mark"), DocumentAction.nextMark, target, ".")
                add(menu, String(localized: "Previous Mark"), DocumentAction.prevMark, target, ",")
            }
            add(menu, String(localized: "Marks Panel"), DocumentAction.toggleMarksPanel, target, "m", [.command, .control])
            add(menu, String(localized: "Clear All Marks"), DocumentAction.clearAllMarks, target)
        }
    }

    // MARK: - Helper

    private static func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ target: AnyObject,
                            _ key: String = "", _ mask: NSEvent.ModifierFlags = .command) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if !key.isEmpty { item.keyEquivalentModifierMask = mask }
        item.target = target
        menu.addItem(item)
    }
}
