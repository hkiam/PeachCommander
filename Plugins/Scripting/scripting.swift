// SPDX-License-Identifier: Apache-2.0
// scripting.swift — Scripting.ptxplugin entry points (contrib.h behavior ABI), F-477.
//
// The inbound half of scripting. Peach Commander could already be driven *from* AppleScript
// (`Resources/PeachCommander.sdef`, F-296); this is the app running a script of the user's, which is
// the other direction and needed the opposite thing: not a dictionary but an interpreter, a context to
// hand it, and a permission gate.
//
// **It is a plugin, and off by default.** Running a script of somebody's choosing can do everything the
// tool catalogue can and several things none of it covers, which is the same argument `PermissionPolicy`
// already makes about the shell: "a dialog is a poor place to meet a capability for the first time".
// So it ships disabled, its tools carry the `script` capability, and that capability is granted once in
// Settings or not at all. Keeping OSAKit out of the app binary is the secondary benefit.
//
// Two ways in, both of them the same runner:
//   * a command per saved script — `plugin.script.run.<id>` — reachable from a menu, a button, a key;
//   * three tools in the catalogue — `run_applescript`, `run_jxa`, `check_script` — so the assistant, a
//     macro step and an MCP client reach scripting through the same gate as everything else.

import AppKit
import PCAutomation

// MARK: - Host access

/// The scripts folder, resolved the way every plugin has to resolve it.
///
/// `PEACHCMD_CONFIG_ROOT` is published into the process by `ConfigPaths.resolve`, precisely so a plugin
/// — which may be handed nothing but a file name — agrees with the host about where configuration
/// lives. Reading the default location instead is what made the AI Column unverifiable under
/// `-ConfigRoot`.
private func scriptStore() -> ScriptStore {
    let root = ProcessInfo.processInfo.environment["PEACHCMD_CONFIG_ROOT"]
        ?? (NSHomeDirectory() + "/Library/Application Support/PeachCommander")
    return ScriptStore(directory: URL(fileURLWithPath: root).appendingPathComponent("scripts",
                                                                                   isDirectory: true))
}

/// The panel state, from the host's main-thread-safe services.
///
/// **Not from `automationContextJson`, which would be the obvious choice and deadlocks.** `contrib.h`
/// says the `automation*` calls must be made off the main thread; both `PcRunCommand` and `PcInvokeTool`
/// are dispatched *on* it, and the host's implementation blocks that thread waiting for an actor that
/// needs it. Measured: `aitool list_scripts` hung the application until it was killed. `getContext`,
/// `cursorPath` and `selectionPath` all take the same-thread path and are safe from here.
private func context(from services: PcHostServices) -> ScriptContext {
    var out = ScriptContext()
    out.activeDirectory = contextValue("dir", services) ?? ""
    out.inactiveDirectory = contextValue("targetDir", services) ?? ""

    var buffer = [CChar](repeating: 0, count: 4096)
    if services.cursorPath?(services.host, &buffer, Int32(buffer.count)) == 1 {
        out.cursorName = (String(cString: buffer) as NSString).lastPathComponent
    }
    let count = Int(services.selectionCount?(services.host) ?? 0)
    out.selection = (0..<count).compactMap { index in
        var path = [CChar](repeating: 0, count: 4096)
        guard services.selectionPath?(services.host, Int32(index), &path, Int32(path.count)) == 1
        else { return nil }
        return String(cString: path)
    }
    return out
}

private func contextValue(_ key: String, _ services: PcHostServices) -> String? {
    var buffer = [CChar](repeating: 0, count: 4096)
    guard services.getContext?(services.host, key, &buffer, Int32(buffer.count)) == 1 else { return nil }
    let value = String(cString: buffer)
    return value.isEmpty ? nil : value
}

/// Show a result, or write it to a file when this is a verification run.
///
/// `presentInfo` is `runModal`, and a modal is what turns an automation run into a run that hangs until
/// somebody clicks it. The AI plugins solve it with an env-gated dump and so does this: with
/// `PC_SCRIPT_DUMP=<path>` set, the output goes to the file and no dialog appears, so the whole path
/// including the run underneath is exercised headlessly.
private func report(_ title: String, _ message: String, _ services: PcHostServices) {
    if let path = ProcessInfo.processInfo.environment["PC_SCRIPT_DUMP"] {
        let block = "\(title)\n\(message)\n---\n"
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        try? (existing + block).write(toFile: path, atomically: true, encoding: .utf8)
        return
    }
    services.presentInfo?(services.host, title, message)
}

/// `L` from Plugins/SDK/PluginLoc.swift, aliased so the call sites read as intent.
private func localized(_ key: String) -> String { L(key) }

// MARK: - Running a saved script

private func runSavedScript(id: String, services: PcHostServices) {
    let store = scriptStore()
    guard let script = store.script(id: id) else {
        report(localized("Script not found"),
               String(format: localized("There is no script called “%@” in the scripts folder."), id),
               services)
        return
    }
    guard let source = try? String(contentsOf: store.url(of: script), encoding: .utf8) else {
        report(localized("Script not readable"),
               String(format: localized("“%@” could not be read."), script.fileName), services)
        return
    }
    let result = ScriptRunner.run(source: source, language: script.language, mode: script.mode,
                                  timeoutSeconds: script.timeoutSeconds,
                                  context: context(from: services))
    // Always reported, success included. The output *is* the result of running a script, and a script
    // that printed something to a dialog nobody showed has been run in secret — the same reasoning the
    // catalogue gives for putting `run_shell` in a visible terminal tab.
    if let error = result.error {
        report(String(format: localized("“%@” did not finish"), script.title),
               result.output.isEmpty ? error : error + "\n\n" + result.output, services)
    } else {
        report(script.title, result.output.isEmpty ? localized("The script finished.") : result.output,
               services)
    }
}

// MARK: - C-ABI exports

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let commandId, let services else { return }
    let id = String(cString: commandId)
    let s = services.pointee
    // One declaration with `acceptsSuffix` covers every script, so the plugin resolves the suffix.
    //
    // The declaration is `plugin.script.run.any`, with a final component that means nothing. That is
    // what the ABI requires: `CommandContribution.family` is the id truncated at its *last* dot, so a
    // declaration of `plugin.script.run` opens the family `plugin.script.` — and `plugin.script.run.x`
    // then has two components after it and is refused. Declaring `plugin.ai.skill.custom` is the same
    // shape in the AI plugin. Costed a run to find, so it is written down.
    let family = "plugin.script.run."
    if id.hasPrefix(family), id.count > family.count {
        runSavedScript(id: String(id.dropFirst(family.count)), services: s)
        return
    }
    switch id {
    case "plugin.script.manage":
        // The folder, opened in the active panel. Scripts are files a person edits in Script Editor, so
        // the useful thing to offer is the folder they are in — not a second editor inside this app.
        let store = scriptStore()
        try? store.seedIfEmpty()
        s.openPath?(s.host, store.directory.path)
    default:
        break
    }
}

/// Tools the plugin contributes to the catalogue (`PCContributions.tools`), routed here by the host and
/// gated by their declared capability before they ever reach this function.
@_cdecl("PcInvokeTool")
public func PcInvokeTool(_ toolName: UnsafePointer<CChar>?, _ argumentsJson: UnsafePointer<CChar>?,
                         _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutablePointer<CChar>? {
    guard let toolName, let services else { return nil }
    let name = String(cString: toolName)
    let arguments = argumentsJson.flatMap {
        (try? JSONSerialization.jsonObject(with: Data(String(cString: $0).utf8))) as? [String: Any]
    } ?? [:]
    let ctx = context(from: services.pointee)

    func answer(_ text: String) -> UnsafeMutablePointer<CChar>? { strdup(text) }

    switch name {
    case "run_applescript", "run_jxa":
        guard let source = arguments["source"] as? String, !source.isEmpty else {
            return answer("The argument \"source\" is required and must not be empty.")
        }
        let language = name == "run_jxa" ? "JavaScript" : "AppleScript"
        // A tool call always runs in a subprocess, whatever a saved script may prefer: this source came
        // from a model or an external client, it has no editor behind it that chose otherwise, and the
        // timeout is the only thing standing between a generated `repeat` loop and a frozen app.
        let timeout = (arguments["timeout_seconds"] as? NSNumber)?.intValue ?? 30
        let result = ScriptRunner.run(source: source, language: language, mode: .subprocess,
                                      timeoutSeconds: max(1, min(timeout, 300)), context: ctx)
        if let error = result.error {
            return answer(result.output.isEmpty ? error : error + "\n" + result.output)
        }
        return answer(result.output.isEmpty ? "The script finished and returned nothing." : result.output)

    case "check_script":
        guard let source = arguments["source"] as? String else {
            return answer("The argument \"source\" is required.")
        }
        let language = (arguments["language"] as? String) ?? "AppleScript"
        if let problem = ScriptRunner.check(source: source, language: language) {
            return answer(problem)
        }
        return answer("It compiles.")

    case "list_scripts":
        let scripts = scriptStore().scripts().map {
            ["id": $0.id, "title": $0.title, "language": $0.language,
             "command": $0.commandName, "mode": $0.mode.rawValue] as [String: Any]
        }
        let data = (try? JSONSerialization.data(withJSONObject: scripts, options: [.sortedKeys]))
        return answer(data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]")

    default:
        return nil
    }
}

@_cdecl("PcConfigure")
public func PcConfigure(_ parentWindow: UnsafeMutableRawPointer?) {
    // No settings of its own: what there is to configure is the scripts, and those are files. The
    // folder is opened by `plugin.script.manage`, which is in the menu.
    let store = scriptStore()
    try? store.seedIfEmpty()
    NSWorkspace.shared.open(store.directory)
}
