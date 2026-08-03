// SPDX-License-Identifier: Apache-2.0
// java_decompiler.swift — the Java decompiler plugin: a profile and the C exports (F-345).
//
// Everything this plugin *does* lives in Plugins/SDK/PluginDecompiler*.swift, shared with the .NET
// plugin. What is left here is what only this plugin can say — which formats it claims — plus the
// entry points the host resolves by name. That split is the point of the profile: adding a decompiler
// for another platform should cost a table and a manifest, not a copy of 1,600 lines of view code.

import AppKit

/// This plugin's formats, ids and language.
private let profile = PluginDecompilerProfile.java

// MARK: - Lister (plx)

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("ListGetDetectString")
public func ListGetDetectString(_ buf: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) {
    guard let buf, maxlen > 0 else { return }
    // Extension first, magic bytes second: CAFEBABE catches a class file whose name was lost.
    // Whole archives too (F-349) — a JAR or APK is claimed for F3 only. Enter still browses it
    // through the host's built-in ZIP support, which is a different verb and a different plugin
    // type, so the two never compete. The dialect has a single `=`, never `==`: an expression with
    // `==` parses as invalid and the plugin then silently claims nothing at all.
    //
    // Archives only when the user wants F3 to open this plugin for them (F-352). Read here rather
    // than baked into the manifest because the host calls this function: a setting that needed a
    // rebuilt Info.plist to take effect would not be a setting.
    let single = "EXT=\"CLASS\" | ([0]=202 & [1]=254 & [2]=186 & [3]=190)"
    let archives = " | EXT=\"DEX\" | EXT=\"JAR\" | EXT=\"APK\""
    let detect = PluginDecompilerOptions.read(configRoot: configRoot(), profile: profile.id).claimArchives
        ? single + archives : single
    _ = detect.withCString { strlcpy(buf, $0, Int(maxlen)) }
}

@_cdecl("ListLoad")
public func ListLoad(_ parent: UnsafeMutableRawPointer?, _ file: UnsafeMutablePointer<CChar>?,
                     _ showFlags: Int32) -> UnsafeMutableRawPointer? {
    makeDecompilerListerView(file, profile: profile)
}

@_cdecl("ListCloseWindow")
public func ListCloseWindow(_ listWin: UnsafeMutableRawPointer?) {
    guard let listWin else { return }
    Unmanaged<DecompilerListerView>.fromOpaque(listWin).release()
}

@_cdecl("ListSearchText")
public func ListSearchText(_ listWin: UnsafeMutableRawPointer?, _ searchString: UnsafeMutablePointer<CChar>?,
                           _ options: Int32) -> Int32 {
    guard let listWin, let searchString, let needle = String(validatingUTF8: searchString) else { return 1 }
    let view = Unmanaged<DecompilerListerView>.fromOpaque(listWin).takeUnretainedValue()
    return view.find(needle, matchCase: options & 0x0001 != 0) ? 0 : 1
}

@_cdecl("ListSendCommand")
public func ListSendCommand(_ listWin: UnsafeMutableRawPointer?, _ command: Int32, _ parameter: Int32) -> Int32 {
    guard let listWin else { return 1 }
    let view = Unmanaged<DecompilerListerView>.fromOpaque(listWin).takeUnretainedValue()
    switch command {
    case 1: view.copySelection(); return 0     // PC_LC_COPY
    case 2: view.selectAll(); return 0         // PC_LC_SELECTALL
    case 4: view.changeFontSize(by: 1); return 0   // PC_LC_FONTPLUS
    case 5: view.changeFontSize(by: -1); return 0  // PC_LC_FONTMINUS
    default: return 1
    }
}

// MARK: - Contributions (commands + the settings pane)

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let services else { return }
    runDecompilerCommand(commandId.map { String(cString: $0) } ?? "", services.pointee, profile: profile)
}

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ containerId: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    makeDecompilerSettingsView(viewId, services, profile: profile)
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    releaseDecompilerSettingsView(view)
}

// MARK: - Content field (pdx), so the host's search can look inside a class

@_cdecl("ContentGetSupportedField")
public func ContentGetSupportedField(_ fieldIndex: Int32, _ nameOut: UnsafeMutablePointer<CChar>?,
                                     _ units: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    decompilerContentField(fieldIndex, nameOut, units, maxlen)
}

@_cdecl("ContentGetValue")
public func ContentGetValue(_ fileName: UnsafeMutablePointer<CChar>?, _ fieldIndex: Int32,
                            _ unitIndex: Int32, _ fieldValue: UnsafeMutableRawPointer?,
                            _ maxlen: Int32, _ flags: Int32) -> Int32 {
    decompilerContentValue(fileName, fieldIndex, fieldValue, maxlen, profile: profile)
}

@_cdecl("ContentSearchText")
public func ContentSearchText(_ fileName: UnsafeMutablePointer<CChar>?, _ fieldIndex: Int32,
                              _ needle: UnsafePointer<CChar>?, _ flags: Int32,
                              _ matchLine: UnsafeMutablePointer<CChar>?, _ lineMax: Int32) -> Int32 {
    decompilerContentSearch(fileName, fieldIndex, needle, flags, matchLine, lineMax, profile: profile)
}
