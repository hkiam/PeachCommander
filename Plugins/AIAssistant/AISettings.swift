// SPDX-License-Identifier: Apache-2.0
// AISettings.swift — plugin-owned config model (aichat/config.json).
//
// The ASSISTANT-specific preferences (preferred model, custom system prompt) live in
// this JSON under the host config root. The editing UI is on the host's unified
// Settings ▸ AI page (the plugin no longer contributes its own settings pane); the
// host writes the same two keys this struct reads, so the plugin picks them up when
// it next builds a chat. Host concerns (autonomy, MCP, cloud endpoint/key) stay on
// that page too.

import Foundation

struct AIPluginConfig: Codable {
    var modelPreference: String = "auto"   // "auto" | "local" | "cloud"
    var systemPrompt: String = ""          // "" = built-in default

    static func url(root: String) -> URL {
        URL(fileURLWithPath: root).appendingPathComponent("aichat/config.json")
    }
    static func load(root: String) -> AIPluginConfig {
        guard let d = try? Data(contentsOf: url(root: root)),
              let c = try? JSONDecoder().decode(AIPluginConfig.self, from: d) else { return AIPluginConfig() }
        return c
    }
    func save(root: String) {
        let u = Self.url(root: root)
        try? FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(self).write(to: u, options: .atomic)
    }
}
