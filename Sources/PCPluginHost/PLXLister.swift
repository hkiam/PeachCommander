// SPDX-License-Identifier: Apache-2.0
// PLXLister.swift - PLX lister plugin adapter (I16 T01).
//
// Drives a loaded PLX plugin's C ABI (plx.h via the CPLX module): load a file into
// a plugin view, cycle to the next file, search, send viewer commands, print, and
// render a window-less preview thumbnail. Detection reuses the shared F-238 detect
// string engine (DetectString) so viewer dispatch is consistent with the rest of
// the plugin system.
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

/// A viewer command sent to a loaded view (PC_LC_*).
public enum PLXCommand: Sendable {
    case copy, selectAll, fontPlus, fontMinus
    case newParams(PLXShowFlags)

    var command: Int32 {
        switch self {
        case .copy: return Int32(PC_LC_COPY)
        case .selectAll: return Int32(PC_LC_SELECTALL)
        case .fontPlus: return Int32(PC_LC_FONTPLUS)
        case .fontMinus: return Int32(PC_LC_FONTMINUS)
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

    private static let detectStringCapacity = 1024
    private static let previewBufferCapacity = 512 * 1024   // 512 KiB PNG ceiling

    // MARK: - Capabilities

    public var canLoadNext: Bool { lib.symbol("ListLoadNext") != nil }
    public var canSearch: Bool { lib.symbol("ListSearchText") != nil }
    public var canPreview: Bool { lib.symbol("ListGetPreviewBitmap") != nil }
    public var canPrint: Bool { lib.symbol("ListPrint") != nil }

    // MARK: - Loading

    /// Load `file` into a new plugin view under `parent` (an NSView* as raw pointer,
    /// may be nil). Returns the plugin's view handle, or nil if it declines the file.
    public func load(parent: PLXHandle?, file: String, showFlags: PLXShowFlags = []) -> PLXHandle? {
        guard let ptr = lib.symbol("ListLoad") else { return nil }
        let fn = unsafeBitCast(ptr, to: LoadFn.self)
        return file.withCString { fn(parent, UnsafeMutablePointer(mutating: $0), showFlags.rawValue) }
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
