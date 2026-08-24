// SPDX-License-Identifier: Apache-2.0
// markdown_lister.swift — the PLX entry points of the Markdown lister plugin.
//
// Everything the host can ask this plugin, in one file, with the work in MarkdownListerView. The
// exports beyond ListLoad are the additive set from plx.h, and this is their first real user: the
// outline and its anchors (so the viewer's symbol sidebar keeps working for a rendered document),
// the document's text (so Find, Copy All, Mark All and Print keep working), and ListLoadEx (so the
// same renderer can be told it is being embedded in a 200-point preview column rather than a
// window).
//
// The host calls these from its @MainActor lister flow, so every entry point hops onto the main
// actor with `assumeIsolated` — an assertion about a documented fact rather than a hop that could
// deadlock. Handles are retained NSView pointers, balanced by ListCloseWindow.
//
// The C types come from MarkdownBridging.h rather than a module, the way every other plugin here
// gets them: a plugin is built by a shell script with `-import-objc-header`, where no module map
// exists. That is also why this file is not in the test bundle — the exports have nothing to test
// that the view behind them does not, and the bridging header is not available there.

import AppKit
import PCFoundation

// MARK: - Detection

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("ListGetDetectString")
public func ListGetDetectString(_ buf: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) {
    guard let buf, maxlen > 0 else { return }
    // Read at call time rather than baked into the manifest, so the setting takes effect without a
    // rebuild — the same reason the decompiler plugin reads its own claim switch here. Empty means
    // "not mine", and the host then shows the file with its own text viewer.
    guard MarkdownOptions.read(configRoot: pluginConfigRoot).claimFiles else {
        buf[0] = 0
        return
    }
    // Built from the same sets the load path uses, so "claimed" and "can be shown" cannot drift
    // apart. A file this plugin claims and then declines would send the reader to a viewer that
    // has already been ruled out.
    let exts = (MarkdownListerView.Kind.markdownExtensions.sorted()
                + MarkdownListerView.Kind.htmlExtensions.sorted())
        .map { "EXT=\"\($0.uppercased())\"" }
        .joined(separator: " | ")
    _ = exts.withCString { strlcpy(buf, $0, Int(maxlen)) }
}

// MARK: - Contributions (the settings pane)

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ containerId: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    var view: UnsafeMutableRawPointer?
    MainActor.assumeIsolated { view = makeMarkdownSettingsView(viewId, services) }
    return view
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    MainActor.assumeIsolated { releaseMarkdownSettingsView(view) }
}

/// Where this plugin's own settings live, learnt from the host and remembered.
///
/// `ListGetDetectString` takes no services table — it is asked before any view exists — so the config
/// root has to come from somewhere. `ListSetDefaultParams` is the ABI's answer and the host calls it
/// with exactly that; until it does, an empty root means "bundled engines, default settings", which is
/// the right behaviour for a host that publishes no context at all.
nonisolated(unsafe) private var pluginConfigRoot = ""

@_cdecl("ListSetDefaultParams")
public func ListSetDefaultParams(_ configDir: UnsafeMutablePointer<CChar>?) {
    guard let configDir, let path = String(validatingUTF8: configDir) else { return }
    pluginConfigRoot = path
}

// MARK: - Loading

@_cdecl("ListLoad")
public func ListLoad(_ parent: UnsafeMutableRawPointer?, _ file: UnsafeMutablePointer<CChar>?,
                     _ showFlags: Int32) -> UnsafeMutableRawPointer? {
    // No services table, so whatever ListSetDefaultParams was told — and nothing if it was never
    // called, which means bundled engines and default settings.
    load(file, surface: "", configRoot: pluginConfigRoot)
}

@_cdecl("ListLoadEx")
public func ListLoadEx(_ parent: UnsafeMutableRawPointer?, _ file: UnsafePointer<CChar>?,
                       _ showFlags: Int32,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    let root = contextValue(services, "configRoot")
    if !root.isEmpty { pluginConfigRoot = root }
    return load(UnsafeMutablePointer(mutating: file), surface: contextValue(services, "lister.surface"),
                configRoot: root)
}

private func load(_ file: UnsafeMutablePointer<CChar>?, surface: String,
                  configRoot: String) -> UnsafeMutableRawPointer? {
    guard let file, let path = String(validatingUTF8: file) else { return nil }
    // The handle is carried out through a local rather than returned from `assumeIsolated`: a raw
    // pointer is not Sendable, so returning one across the isolation boundary is an error under the
    // Swift 6 language mode. The closure is non-escaping and runs before this returns, so writing to
    // a local is exactly as safe and says so.
    var handle: UnsafeMutableRawPointer?
    MainActor.assumeIsolated {
        if let view = MarkdownListerView.make(path: path, surface: surface, configRoot: configRoot) {
            handle = Unmanaged.passRetained(view).toOpaque()
        }
    }
    return handle
}

@_cdecl("ListLoadNext")
public func ListLoadNext(_ parent: UnsafeMutableRawPointer?, _ listWin: UnsafeMutableRawPointer?,
                         _ file: UnsafeMutablePointer<CChar>?, _ showFlags: Int32) -> Int32 {
    guard let view = view(listWin), let file, let path = String(validatingUTF8: file) else {
        return Int32(PC_LISTER_ERROR)
    }
    // Reusing the view is what keeps the preview panel cheap while the cursor walks a directory:
    // one web view for the whole walk instead of one per row.
    return MainActor.assumeIsolated {
        view.reload(path: path) ? Int32(PC_LISTER_OK) : Int32(PC_LISTER_ERROR)
    }
}

@_cdecl("ListCloseWindow")
public func ListCloseWindow(_ listWin: UnsafeMutableRawPointer?) {
    guard let listWin else { return }
    Unmanaged<MarkdownListerView>.fromOpaque(listWin).release()
}

// MARK: - Interaction

@_cdecl("ListSearchText")
public func ListSearchText(_ listWin: UnsafeMutableRawPointer?, _ searchString: UnsafeMutablePointer<CChar>?,
                           _ options: Int32) -> Int32 {
    guard let view = view(listWin), let searchString,
          let needle = String(validatingUTF8: searchString) else { return Int32(PC_LISTER_ERROR) }
    return MainActor.assumeIsolated {
        view.find(needle, matchCase: options & Int32(PC_LCS_MATCHCASE) != 0)
            ? Int32(PC_LISTER_OK) : Int32(PC_LISTER_ERROR)
    }
}

@_cdecl("ListSendCommand")
public func ListSendCommand(_ listWin: UnsafeMutableRawPointer?, _ command: Int32,
                            _ parameter: Int32) -> Int32 {
    guard let view = view(listWin) else { return Int32(PC_LISTER_ERROR) }
    return MainActor.assumeIsolated {
        switch command {
        case Int32(PC_LC_COPY): view.copy(nil); return Int32(PC_LISTER_OK)
        case Int32(PC_LC_SELECTALL): view.selectAll(nil); return Int32(PC_LISTER_OK)
        case Int32(PC_LC_RELOAD): view.reloadInPlace(); return Int32(PC_LISTER_OK)
        case Int32(PC_LC_THEMECHANGED):
            // The rendered page follows `prefers-color-scheme` through its own stylesheet, so a
            // light/dark switch needs nothing. A palette that is neither — Norton's CGA blue — will
            // need the page rebuilt, and that is where it belongs when the engines land.
            return Int32(PC_LISTER_OK)
        default: return Int32(PC_LISTER_ERROR)
        }
    }
}

@_cdecl("ListGetOutline")
public func ListGetOutline(_ listWin: UnsafeMutableRawPointer?, _ out: UnsafeMutablePointer<CChar>?,
                           _ maxlen: Int32) -> Int32 {
    guard let view = view(listWin) else { return -1 }
    let text = MainActor.assumeIsolated {
        view.outlineRows()
            .map { "\($0.depth)\t\($0.line)\t\($0.anchor)\t\($0.title)" }
            .joined(separator: "\n")
    }
    return sizedCopy(text, out, maxlen)
}

@_cdecl("ListGotoAnchor")
public func ListGotoAnchor(_ listWin: UnsafeMutableRawPointer?, _ anchor: UnsafePointer<CChar>?) -> Int32 {
    guard let view = view(listWin), let anchor,
          let id = String(validatingUTF8: anchor) else { return Int32(PC_LISTER_ERROR) }
    return MainActor.assumeIsolated {
        view.gotoAnchor(id) ? Int32(PC_LISTER_OK) : Int32(PC_LISTER_ERROR)
    }
}

@_cdecl("ListGetText")
public func ListGetText(_ listWin: UnsafeMutableRawPointer?, _ out: UnsafeMutablePointer<CChar>?,
                        _ maxlen: Int32) -> Int32 {
    guard let view = view(listWin) else { return -1 }
    return sizedCopy(MainActor.assumeIsolated { view.documentText }, out, maxlen)
}

@_cdecl("ListGetPreviewBitmap")
public func ListGetPreviewBitmap(_ file: UnsafeMutablePointer<CChar>?, _ maxWidth: Int32,
                                 _ maxHeight: Int32, _ outBuf: UnsafeMutableRawPointer?,
                                 _ outBufLen: Int32) -> Int32 {
    guard let file, let path = String(validatingUTF8: file), let outBuf, outBufLen > 0 else { return -1 }
    var png: Data?
    MainActor.assumeIsolated {
        png = MarkdownThumbnail.png(for: path, maxWidth: Int(maxWidth), maxHeight: Int(maxHeight))
    }
    // 0 rather than a negative value when there is nothing to draw: the ABI distinguishes "no
    // thumbnail for this file" from "something went wrong", and the gallery falls back to QuickLook
    // for the first without logging anything.
    guard let png, png.count <= Int(outBufLen) else { return png == nil ? 0 : -1 }
    png.withUnsafeBytes { _ = memcpy(outBuf, $0.baseAddress, png.count) }
    return Int32(png.count)
}

// MARK: - Plumbing

private func view(_ handle: UnsafeMutableRawPointer?) -> MarkdownListerView? {
    handle.map { Unmanaged<MarkdownListerView>.fromOpaque($0).takeUnretainedValue() }
}

/// One context value from the host's table, or "" when there is no table or no such key.
func contextValue(_ services: UnsafePointer<PcHostServices>?, _ key: String) -> String {
    guard let services, let getContext = services.pointee.getContext else { return "" }
    var buf = [CChar](repeating: 0, count: 256)
    let ok = key.withCString { k in
        buf.withUnsafeMutableBufferPointer { getContext(services.pointee.host, k, $0.baseAddress, 256) }
    }
    return ok != 0 ? String(cString: buf) : ""
}

/// The ABI's two-call sizing protocol: with `out` NULL, answer how many bytes are needed; otherwise
/// write that many (truncated to fit) and NUL-terminate.
///
/// Measured in UTF-8 bytes, not characters — the buffer is bytes, and a document full of umlauts
/// would otherwise be told it fits when it does not.
private func sizedCopy(_ text: String, _ out: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    let bytes = Array(text.utf8)
    guard let out else { return Int32(bytes.count) }
    guard maxlen > 0 else { return -1 }
    var n = min(bytes.count, Int(maxlen) - 1)
    // Back off to a character boundary. The host asks for the size first and allocates that, so a
    // truncation only happens when it clamps a size it considers unreasonable — and cutting a
    // multi-byte character in half would turn a too-long document into an undecodable one.
    while n > 0, n < bytes.count, bytes[n] & 0xC0 == 0x80 { n -= 1 }
    bytes.withUnsafeBufferPointer { src in
        _ = memcpy(out, src.baseAddress, n)
    }
    out[n] = 0
    return Int32(n)
}
