// SPDX-License-Identifier: Apache-2.0
// PLXLister.swift - PLX lister plugin adapter (I16 T01).
//
// Drives a loaded PLX plugin's C ABI (plx.h via the CPLX module): load a file into
// a plugin view, cycle to the next file, search, send viewer commands, print,
// render a window-less preview thumbnail, and ask the view for its outline, its
// text and to scroll somewhere. Detection reuses the shared F-238 detect string
// engine (DetectString) so viewer dispatch is consistent with the rest of the
// plugin system.
//
// Every entry point except ListLoad is optional and guarded by `lib.symbol(…)`, so
// a plugin built against an older header keeps working and simply reports the
// capability as absent. That is what makes the ABI additive in practice rather
// than only on paper.
//
// View handles are opaque `UnsafeMutableRawPointer` (an NSView* on the app side):
// the app passes its container view's pointer to `load` and casts the returned
// handle back to an NSView to embed it. This adapter itself never touches AppKit
// or the filesystem, so the choreography is unit-testable headlessly with a fake
// plugin; the app layer owns the NSView bridging and lifetime.

import Foundation
import CPLX

/// Handle to a plugin's lister view (an NSView* reinterpreted as a raw pointer).
public typealias PLXHandle = UnsafeMutableRawPointer

/// ShowFlags controlling how a file is displayed (PC_LCP_*).
public struct PLXShowFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
    public static let wrapText = PLXShowFlags(rawValue: Int32(PC_LCP_WRAPTEXT))
    public static let fitToWindow = PLXShowFlags(rawValue: Int32(PC_LCP_FITTOWINDOW))
    public static let center = PLXShowFlags(rawValue: Int32(PC_LCP_CENTER))
    public static let forceShow = PLXShowFlags(rawValue: Int32(PC_LCP_FORCESHOW))
    public static let darkMode = PLXShowFlags(rawValue: Int32(PC_LCP_DARKMODE))
}

/// Search options for `searchText` (PC_LCS_*).
public struct PLXSearchOptions: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
    public static let matchCase = PLXSearchOptions(rawValue: Int32(PC_LCS_MATCHCASE))
    public static let wholeWords = PLXSearchOptions(rawValue: Int32(PC_LCS_WHOLEWORDS))
    public static let backwards = PLXSearchOptions(rawValue: Int32(PC_LCS_BACKWARDS))
    public static let findFirst = PLXSearchOptions(rawValue: Int32(PC_LCS_FINDFIRST))
}

/// One row of a plugin's document outline (`ListGetOutline`).
public struct PLXOutlineEntry: Sendable, Equatable {
    /// 0-based nesting depth.
    public let depth: Int
    /// 1-based source line, or 0 when the plugin has no line to name.
    public let line: Int
    /// Opaque token to hand back to `gotoAnchor`.
    public let anchor: String
    /// What the sidebar shows.
    public let title: String

    public init(depth: Int, line: Int, anchor: String, title: String) {
        self.depth = depth
        self.line = line
        self.anchor = anchor
        self.title = title
    }
}

/// A viewer command sent to a loaded view (PC_LC_*).
public enum PLXCommand: Sendable {
    case copy, selectAll, fontPlus, fontMinus
    /// Re-read the file from disk — the viewer's reload, which a plugin view could
    /// not be told about before and so kept showing the previous contents.
    case reload
    /// The host's colour theme changed. `PcNotifyThemeChanged` addresses a plugin's
    /// own windows and `PcNotifyView` only views built by `PcMakeView`; a lister view
    /// is neither, so without this it had no way to hear about a theme switch.
    case themeChanged
    case newParams(PLXShowFlags)

    var command: Int32 {
        switch self {
        case .copy: return Int32(PC_LC_COPY)
        case .selectAll: return Int32(PC_LC_SELECTALL)
        case .fontPlus: return Int32(PC_LC_FONTPLUS)
        case .fontMinus: return Int32(PC_LC_FONTMINUS)
        case .reload: return Int32(PC_LC_RELOAD)
        case .themeChanged: return Int32(PC_LC_THEMECHANGED)
        case .newParams: return Int32(PC_LC_NEWPARAMS)
        }
    }
    var parameter: Int32 {
        if case .newParams(let flags) = self { return flags.rawValue }
        return 0
    }
}

public final class PLXLister: @unchecked Sendable {
    private let lib: PluginLibrary
    /// Display name (plugin manifest name), used to label the viewer's plugin
    /// choices when several plugins claim the same file (F-119).
    public let name: String

    public init(library: PluginLibrary, name: String = "") {
        self.lib = library
        self.name = name
    }

    // C function-pointer signatures (plx.h).
    private typealias LoadFn = @convention(c) (UnsafeMutableRawPointer?,
                                               UnsafeMutablePointer<CChar>?, Int32) -> UnsafeMutableRawPointer?
    private typealias LoadNextFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?,
                                                   UnsafeMutablePointer<CChar>?, Int32) -> Int32
    private typealias CloseFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias DetectFn = @convention(c) (UnsafeMutablePointer<CChar>?, Int32) -> Void
    private typealias SearchFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<CChar>?, Int32) -> Int32
    private typealias CommandFn = @convention(c) (UnsafeMutableRawPointer?, Int32, Int32) -> Int32
    private typealias PrintFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<CChar>?, Int32) -> Int32
    private typealias PreviewFn = @convention(c) (UnsafeMutablePointer<CChar>?, Int32, Int32,
                                                  UnsafeMutableRawPointer?, Int32) -> Int32
    /// `services` is `const struct PcHostServices *`, declared but not defined in plx.h so the
    /// header stays standalone C11. Typed as a raw pointer here for the same reason: this module
    /// only forwards it, and the host that builds the table is the one that knows its shape.
    private typealias LoadExFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?,
                                                 Int32, UnsafeRawPointer?) -> UnsafeMutableRawPointer?
    private typealias SizedFn = @convention(c) (UnsafeMutableRawPointer?,
                                                UnsafeMutablePointer<CChar>?, Int32) -> Int32
    private typealias AnchorFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Int32

    private static let detectStringCapacity = 1024
    private static let previewBufferCapacity = 512 * 1024   // 512 KiB PNG ceiling
    /// Ceilings for the two-call size protocol. A plugin answers how much it needs and the host
    /// allocates that — but a wrong answer must cost a truncated outline, not the address space,
    /// so what a plugin asks for is clamped rather than trusted.
    private static let outlineCeiling = 4 * 1024 * 1024      // 4 MiB of outline lines
    private static let textCeiling = 64 * 1024 * 1024        // 64 MiB of document text

    // MARK: - Capabilities

    public var canLoadNext: Bool { lib.symbol("ListLoadNext") != nil }
    public var canSearch: Bool { lib.symbol("ListSearchText") != nil }
    public var canPreview: Bool { lib.symbol("ListGetPreviewBitmap") != nil }
    public var canPrint: Bool { lib.symbol("ListPrint") != nil }
    /// Whether the plugin takes the host's services table, and so can be told which surface it is
    /// being embedded in.
    public var takesServices: Bool { lib.symbol("ListLoadEx") != nil }
    /// Whether the plugin can describe the document's structure (the viewer's symbol sidebar).
    public var canOutline: Bool { lib.symbol("ListGetOutline") != nil }
    /// Whether the plugin can scroll to an anchor from its own outline.
    public var canGotoAnchor: Bool { lib.symbol("ListGotoAnchor") != nil }
    /// Whether the plugin can hand over the document's plain text (find, copy, mark, print).
    public var canProvideText: Bool { lib.symbol("ListGetText") != nil }

    // MARK: - Loading

    /// Load `file` into a new plugin view under `parent` (an NSView* as raw pointer,
    /// may be nil). Returns the plugin's view handle, or nil if it declines the file.
    public func load(parent: PLXHandle?, file: String, showFlags: PLXShowFlags = []) -> PLXHandle? {
        guard let ptr = lib.symbol("ListLoad") else { return nil }
        let fn = unsafeBitCast(ptr, to: LoadFn.self)
        return file.withCString { fn(parent, UnsafeMutablePointer(mutating: $0), showFlags.rawValue) }
    }

    /// Load `file` under `parent`, handing the plugin the host's services table so it can read the
    /// surface it is being embedded in, the container's size, the theme and the config root.
    ///
    /// Falls back to `load` when the plugin exports only `ListLoad` — which is every plugin written
    /// before this existed, and stays a valid thing to be. `services` is the `PcHostServices*` the
    /// contribution host already builds; this module never looks inside it.
    public func loadEx(parent: PLXHandle?, file: String, showFlags: PLXShowFlags = [],
                       services: UnsafeRawPointer?) -> PLXHandle? {
        guard let ptr = lib.symbol("ListLoadEx") else {
            return load(parent: parent, file: file, showFlags: showFlags)
        }
        let fn = unsafeBitCast(ptr, to: LoadExFn.self)
        return file.withCString { fn(parent, $0, showFlags.rawValue, services) }
    }

    /// Reuse `listWin` for another file (viewer cycling). Returns false if the
    /// plugin can't display it in the existing view (or lacks the export).
    public func loadNext(parent: PLXHandle?, listWin: PLXHandle, file: String,
                         showFlags: PLXShowFlags = []) -> Bool {
        guard let ptr = lib.symbol("ListLoadNext") else { return false }
        let fn = unsafeBitCast(ptr, to: LoadNextFn.self)
        let rc = file.withCString { fn(parent, listWin, UnsafeMutablePointer(mutating: $0), showFlags.rawValue) }
        return rc == Int32(PC_LISTER_OK)
    }

    /// Destroy a view returned by `load`. No-op if the plugin lacks the export.
    public func close(_ listWin: PLXHandle) {
        guard let ptr = lib.symbol("ListCloseWindow") else { return }
        unsafeBitCast(ptr, to: CloseFn.self)(listWin)
    }

    // MARK: - Detection (F-238 dispatch)

    /// The plugin's declared detect string ("" if it exports none).
    public func detectString() -> String {
        guard let ptr = lib.symbol("ListGetDetectString") else { return "" }
        let fn = unsafeBitCast(ptr, to: DetectFn.self)
        let cap = Self.detectStringCapacity
        var buf = [CChar](repeating: 0, count: cap)
        buf.withUnsafeMutableBufferPointer { fn($0.baseAddress, Int32(cap)) }
        return String(cString: buf)
    }

    /// Whether this plugin claims a file, per its detect string evaluated with the
    /// shared F-238 engine. A plugin with no detect string never auto-claims.
    public func handles(_ context: DetectContext) -> Bool {
        let detect = detectString()
        guard !detect.isEmpty else { return false }
        return DetectString.matches(detect, context: context)
    }

    // MARK: - Interaction

    /// Search the loaded view; returns true if a match was found.
    public func searchText(in listWin: PLXHandle, _ text: String, options: PLXSearchOptions = []) -> Bool {
        guard let ptr = lib.symbol("ListSearchText") else { return false }
        let fn = unsafeBitCast(ptr, to: SearchFn.self)
        let rc = text.withCString { fn(listWin, UnsafeMutablePointer(mutating: $0), options.rawValue) }
        return rc == Int32(PC_LISTER_OK)
    }

    /// Send a viewer command; returns true on PC_LISTER_OK.
    public func send(_ command: PLXCommand, to listWin: PLXHandle) -> Bool {
        guard let ptr = lib.symbol("ListSendCommand") else { return false }
        let fn = unsafeBitCast(ptr, to: CommandFn.self)
        return fn(listWin, command.command, command.parameter) == Int32(PC_LISTER_OK)
    }

    /// Print `file`; returns true on PC_LISTER_OK.
    public func printFile(_ file: String, in listWin: PLXHandle, flags: Int32 = 0) -> Bool {
        guard let ptr = lib.symbol("ListPrint") else { return false }
        let fn = unsafeBitCast(ptr, to: PrintFn.self)
        let rc = file.withCString { fn(listWin, UnsafeMutablePointer(mutating: $0), flags) }
        return rc == Int32(PC_LISTER_OK)
    }

    // MARK: - What the view knows about its document

    /// The document's structure, as the plugin describes it: `(depth, line, anchor, title)` per row.
    ///
    /// Empty when the plugin has no outline for this file, which is a normal answer and not a
    /// failure — the caller then falls back to whatever it did before. Malformed rows are dropped
    /// rather than guessed at: a row without the four fields says nothing a sidebar could show.
    public func outline(of listWin: PLXHandle) -> [PLXOutlineEntry] {
        guard let text = sizedString("ListGetOutline", listWin, ceiling: Self.outlineCeiling) else {
            return []
        }
        return text.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let f = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
            guard f.count == 4, let depth = Int(f[0]), let source = Int(f[1]) else { return nil }
            return PLXOutlineEntry(depth: max(0, depth), line: max(0, source),
                                   anchor: String(f[2]), title: String(f[3]))
        }
    }

    /// Scroll the view to an anchor from `outline(of:)`. False if the plugin lacks the export or
    /// does not know the anchor.
    public func gotoAnchor(_ anchor: String, in listWin: PLXHandle) -> Bool {
        guard let ptr = lib.symbol("ListGotoAnchor") else { return false }
        let fn = unsafeBitCast(ptr, to: AnchorFn.self)
        return anchor.withCString { fn(listWin, $0) } == Int32(PC_LISTER_OK)
    }

    /// The plain text of what the view shows, or nil when the plugin cannot say (an image lister,
    /// or one built before the export existed).
    public func text(of listWin: PLXHandle) -> String? {
        sizedString("ListGetText", listWin, ceiling: Self.textCeiling)
    }

    /// The two-call size protocol shared by `ListGetOutline` and `ListGetText`: ask with a NULL
    /// buffer how much is needed, then ask again with one that big.
    ///
    /// Two calls rather than a growing retry loop because the ABI offers the size and a loop would
    /// re-render the document each round. The answer is clamped to `ceiling` — a plugin that
    /// reports nonsense should cost a truncated result, not an allocation the host cannot make —
    /// and a plugin that then writes less than it asked for is taken at its second word.
    private func sizedString(_ symbol: String, _ listWin: PLXHandle, ceiling: Int) -> String? {
        guard let ptr = lib.symbol(symbol) else { return nil }
        let fn = unsafeBitCast(ptr, to: SizedFn.self)
        let needed = fn(listWin, nil, 0)
        guard needed > 0 else { return nil }
        let cap = Swift.min(Int(needed), ceiling)
        var buf = [CChar](repeating: 0, count: cap + 1)
        let written = buf.withUnsafeMutableBufferPointer { fn(listWin, $0.baseAddress, Int32(cap + 1)) }
        guard written > 0 else { return nil }
        return String(cString: buf)
    }

    // MARK: - Thumbnails

    /// Render a window-less preview thumbnail (PNG bytes), or nil if unsupported.
    public func previewBitmap(file: String, maxWidth: Int, maxHeight: Int) -> Data? {
        guard let ptr = lib.symbol("ListGetPreviewBitmap") else { return nil }
        let fn = unsafeBitCast(ptr, to: PreviewFn.self)
        let cap = Self.previewBufferCapacity
        var buf = [UInt8](repeating: 0, count: cap)
        let written = file.withCString { cfile -> Int32 in
            buf.withUnsafeMutableBytes { raw in
                fn(UnsafeMutablePointer(mutating: cfile), Int32(maxWidth), Int32(maxHeight),
                   raw.baseAddress, Int32(cap))
            }
        }
        guard written > 0 else { return nil }
        return Data(buf.prefix(Int(written)))
    }
}
