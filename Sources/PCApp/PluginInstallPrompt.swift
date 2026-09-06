// SPDX-License-Identifier: Apache-2.0
// PluginInstallPrompt.swift - What the user is told before a plugin is loaded (F-482).
//
// Installing a plugin is running somebody else's code inside a file manager that has the whole
// disk in reach. Until now it looked like copying a file: pick a .zip, and the next thing that
// happened was a dylib in the process. Nobody was ever shown the plugin's name, its version, or
// what it was about to claim.
//
// So the install is two steps. `PluginManager.stage` unpacks and reads the manifest — no code is
// loaded to do that, by design — and this sheet reports what it found. Only "Install" commits.
//
// Three things are worth saying out loud here rather than hiding:
//   * what the plugin will take over (its file extensions), because a packer plugin quietly wins
//     over the built-in reader for every name it claims;
//   * that it runs unsandboxed in this process;
//   * whether it came from the internet, and that installing clears the quarantine flag — which
//     is the user's decision replacing Gatekeeper's, and should be made knowingly.

import AppKit
import PCPluginHost

enum PluginInstallPrompt {
    /// Ask about a staged plugin. Returns true when the user wants it installed.
    @MainActor
    static func confirm(_ staged: StagedPlugin, over window: NSWindow?) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = messageText(for: staged)
        alert.informativeText = informativeText(for: staged)
        alert.addButton(withTitle: String(localized: "Install"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        // Cancel is the safe answer, so it is the one Return must not reach by accident.
        alert.buttons.last?.keyEquivalent = "\u{1b}"
        if let window {
            // A sheet would be better still, but every caller here is a synchronous decision
            // point in a command handler; `beginSheetModal` would return before the answer.
            alert.window.setFrameOrigin(NSPoint(x: window.frame.midX - alert.window.frame.width / 2,
                                                y: window.frame.midY))
        }
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func messageText(for staged: StagedPlugin) -> String {
        let name = staged.manifest.name
        let version = staged.manifest.version.description
        guard let installed = staged.installedVersion else {
            return String(localized: "Install the plugin “\(name)” \(version)?")
        }
        if staged.manifest.version > installed {
            return String(localized: "Update the plugin “\(name)” from \(installed.description) to \(version)?")
        }
        if staged.manifest.version < installed {
            return String(localized: "Replace the plugin “\(name)” \(installed.description) with the OLDER version \(version)?")
        }
        return String(localized: "Reinstall the plugin “\(name)” \(version)?")
    }

    private static func informativeText(for staged: StagedPlugin) -> String {
        var lines: [String] = []
        let m = staged.manifest
        lines.append(String(localized: "Identifier: \(m.identifier)"))
        lines.append(String(localized: "Type: \(typeDescription(m.type))"))
        if !m.extensions.isEmpty {
            // Named explicitly because this is the part with a consequence the user cannot see:
            // a packer plugin is consulted before the built-in readers for every name it claims.
            let claimed = m.extensions.map { ".\($0)" }.joined(separator: ", ")
            lines.append(String(localized: "Takes over these file types: \(claimed)"))
        }
        if let description = staged.installInfo?.description, !description.isEmpty {
            lines.append(description)
        }
        lines.append("")
        lines.append(String(localized: "A plugin runs inside Peach Commander with the same access to your files that Peach Commander has. Install it only if you trust where it came from."))
        if staged.isQuarantined {
            lines.append("")
            lines.append(String(localized: "This plugin was downloaded from the internet. Installing it tells macOS to allow it to load."))
        }
        return lines.joined(separator: "\n")
    }

    private static func typeDescription(_ type: PluginType) -> String {
        switch type {
        case .pcx: return String(localized: "Archive format (pcx)")
        case .pfx: return String(localized: "File system (pfx)")
        case .plx: return String(localized: "Viewer (plx)")
        case .pdx: return String(localized: "Content fields (pdx)")
        case .ptx: return String(localized: "Tool (ptx)")
        }
    }
}
