// SPDX-License-Identifier: Apache-2.0
// Scripting.swift — AppleScript support (F-296).
//
// A thin adapter that exposes the file manager's core verbs and reads to AppleScript
// (and, via the Shortcuts app's "Run AppleScript" action, to Shortcuts). The dictionary
// lives in Resources/PeachCommander.sdef and is wired through Info.plist keys
// NSAppleScriptEnabled + OSAScriptingDefinition (set in project.yml).
//
// Reads are KVC properties on the application object (NSApplication) that delegate to
// the live MainWindowController. Verbs are NSScriptCommand subclasses that run on the
// main thread and call the same host entry points the menus and automation core use,
// so scripted actions behave exactly like manual ones.

import AppKit

/// AppleScript "a required parameter is missing" error (Carbon errMissingParameter),
/// spelled out so we don't pull in OSAKit/Carbon just for one constant.
private let errMissingParameter = -1701

/// FourCharCode for a 4-character enumerator code (e.g. "Plft").
private func fourChar(_ s: String) -> UInt32 {
    var code: UInt32 = 0
    for b in s.utf8.prefix(4) { code = (code << 8) | UInt32(b) }
    return code
}

// MARK: - Read-only application properties (mapped in the .sdef via cocoa key)

extension NSApplication {
    @objc var scriptActiveFolder: String {
        MainWindowController.shared?.scriptActiveFolder ?? NSHomeDirectory()
    }
    @objc var scriptInactiveFolder: String {
        MainWindowController.shared?.scriptInactiveFolder ?? ""
    }
    @objc var scriptSelectionPaths: [String] {
        MainWindowController.shared?.scriptSelectionPaths ?? []
    }
}

// MARK: - Commands

@objc(PCGoToCommand)
final class PCGoToCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let host = MainWindowController.shared else { return nil }
        let path = (directParameter as? String) ?? ""
        guard !path.isEmpty else {
            scriptErrorNumber = errMissingParameter; return nil
        }
        let code = (evaluatedArguments?["panel"] as? NSNumber)?.uint32Value
        let side: Int? = (code == fourChar("Plft")) ? 0 : (code == fourChar("Prgt")) ? 1 : nil
        return host.scriptGoTo(path: path, side: side)
    }
}

@objc(PCSelectCommand)
final class PCSelectCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let host = MainWindowController.shared else { return nil }
        let mask = (directParameter as? String) ?? "*"
        return host.scriptSelect(mask: mask)
    }
}

@objc(PCCopyCommand)
final class PCCopyCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let host = MainWindowController.shared,
              let dest = evaluatedArguments?["destination"] as? String, !dest.isEmpty else {
            scriptErrorNumber = errMissingParameter; return nil
        }
        host.scriptTransferSelection(copy: true, to: dest)
        return nil
    }
}

@objc(PCMoveCommand)
final class PCMoveCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let host = MainWindowController.shared,
              let dest = evaluatedArguments?["destination"] as? String, !dest.isEmpty else {
            scriptErrorNumber = errMissingParameter; return nil
        }
        host.scriptTransferSelection(copy: false, to: dest)
        return nil
    }
}

@objc(PCRunCommand)
final class PCRunCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let host = MainWindowController.shared else { return nil }
        let id = (directParameter as? String) ?? ""
        guard !id.isEmpty else { scriptErrorNumber = errMissingParameter; return nil }
        host.scriptRunCommand(id)
        return nil
    }
}
