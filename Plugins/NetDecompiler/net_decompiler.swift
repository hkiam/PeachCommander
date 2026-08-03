// SPDX-License-Identifier: Apache-2.0
// net_decompiler.swift — the .NET decompiler plugin: a profile and the C exports (F-353).
//
// The whole plugin. Everything it does is shared with the Java decompiler in
// Plugins/SDK/PluginDecompiler*.swift; what is specific to .NET is the profile in
// PluginDecompilerProfile.dotNet and the detect string below. That was the test the architecture had
// to pass, and it is why this file is short.
//
// Two things are genuinely different from Java and both are data, not code:
//
//   * An assembly is one file holding many types, so a `.dll` takes the same path a JAR does. Which
//     of the two views opens depends on the installed engine — ILSpy writes a project tree, monodis
//     prints one IL listing of the same file.
//   * `.dll` and `.exe` name native binaries too, and no detect string can tell them apart: the CLI
//     header sits behind a pointer at offset 0x3C and the grammar has fixed offsets only. The profile
//     therefore checks at load time, and declining lets the host show its own viewer.
//
// No engine is bundled and nothing is downloaded. ILSpy is MIT and monodis ships with Mono; dnSpy is
// GPLv3 and dotPeek is proprietary and Windows-only, which is the same licence wall JD-Core put up on
// the Java side. The engine folder's README names each one, its licence and its install command.

import AppKit

/// This plugin's formats, ids and language.
private let profile = PluginDecompilerProfile.dotNet

// MARK: - Lister (plx)

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("ListGetDetectString")
public func ListGetDetectString(_ buf: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) {
    guard let buf, maxlen > 0 else { return }
    // The extensions, guarded by the DOS header so a file that is not a Windows image at all never
    // reaches the plugin. "Is it *managed*" cannot be asked here — see the profile's `claims`.
    // Read at call time, not baked into the manifest, so the setting works without a rebuild.
    let claims = PluginDecompilerOptions.read(configRoot: configRoot(), profile: profile.id).claimArchives
    let detect = claims
        ? "(EXT=\"DLL\" | EXT=\"EXE\" | EXT=\"WINMD\" | EXT=\"NETMODULE\") & [0]=77 & [1]=90"
        : ""
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

// MARK: - Content field (pdx), so the host's search can look inside an assembly

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
