// SPDX-License-Identifier: Apache-2.0
// icloud.swift — iCloud Drive as an external PFX file-system plugin.
//
// iCloud Drive syncs to a local folder, so this plugin implements only the PFX
// "static volumes" facet: it contributes one drive-bar entry pointing at the
// local iCloud path (PC_PFX_VOL_LOCAL). No connect/file-op facet is needed — the
// host browses the local path directly. Built into ICloudDrive.pfxplugin.

import Foundation

private var iCloudPath: String {
    (NSHomeDirectory() as NSString)
        .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
}

private func iCloudAvailable() -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: iCloudPath, isDirectory: &isDir) && isDir.boolValue
}

/// Copy a Swift string into a fixed C char buffer (truncating to `capacity`).
private func setCString(_ string: String, _ dst: UnsafeMutablePointer<CChar>, _ capacity: Int) {
    string.withCString { _ = strlcpy(dst, $0, capacity) }
}

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PfxGetVolumeCount")
public func PfxGetVolumeCount() -> Int32 { iCloudAvailable() ? 1 : 0 }

@_cdecl("PfxGetVolumeInfo")
public func PfxGetVolumeInfo(_ index: Int32, _ out: UnsafeMutablePointer<PfxVolumeInfo>?) {
    guard let out, index == 0 else { return }
    setCString("cloud:icloud", &out.pointee.id.0, 128)
    setCString(L("iCloud Drive"), &out.pointee.name.0, 256)
    setCString(iCloudPath, &out.pointee.path.0, 1024)
    out.pointee.flags = PC_PFX_VOL_LOCAL
}
