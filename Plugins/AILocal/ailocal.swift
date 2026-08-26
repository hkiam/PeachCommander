// SPDX-License-Identifier: Apache-2.0
// ailocal.swift — AILocal.ptxplugin entry points (contrib.h behavior ABI).
//
// The on-device half of the assistant: five actions that do their work and show you the result,
// with no chat and no conversation to manage. It exists as its own bundle because the two halves
// are answerable to different limits — this one has 4096 tokens to work in and offers the model no
// tools at all, while the cloud assistant next door has a window big enough for a conversation and
// thirty-two tools. Splitting them also means a reader can take the summariser without taking a
// component that can rename, move and delete files on a model's say-so.
//
// Everything of substance is in AIDirectActions.swift and AISheets.swift; this file is the profile
// and its C exports, the way the two decompiler plugins are a profile over a shared runner.

import AppKit
import PCAutomation

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let commandId, let services else { return }
    _ = AIDirect.handle(String(cString: commandId), services.pointee)
}
