// SPDX-License-Identifier: Apache-2.0
// SkillStore.swift - user-editable "AI ▸" skills.
//
// Skills are data (title + prompt template), so users/teams can add their own
// context-menu AI actions without code: drop a skills.json under the config root
// (aichat/skills.json). If none exists the built-in SkillCatalog is used, and a
// template is seeded on first run so the format is discoverable.

import Foundation

public struct SkillStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    private var url: URL { directory.appendingPathComponent("skills.json") }

    /// User skills from skills.json, or the built-in file skills if absent/empty/invalid.
    public func load() -> [Skill] {
        guard let data = try? Data(contentsOf: url),
              let skills = try? JSONDecoder().decode([Skill].self, from: data),
              !skills.isEmpty else {
            return SkillCatalog.fileSkills
        }
        return skills
    }

    /// Write the built-in skills as an editable template if the user has none yet.
    public func seedTemplateIfMissing() {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(SkillCatalog.fileSkills) {
            try? data.write(to: url)
        }
    }
}
