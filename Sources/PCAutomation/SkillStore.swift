// SPDX-License-Identifier: Apache-2.0
// SkillStore.swift - user-editable "AI ▸" skills.
//
// Skills are data: what each context-menu AI action actually asks the model is a prompt
// template under the config root (aichat/skills.json for the file actions,
// aichat/folder-skills.json for the ones acting on a folder), so a user or a team can
// change the wording, the language, or the whole instruction without touching code. A
// template is written on first run so the format is discoverable, and anything missing or
// malformed falls back to the built-in catalogue.
//
// Scope, deliberately: this replaces the *prompts* of the declared actions. Adding an
// action with its own menu entry is not possible from here — the host builds plugin menus
// from the bundle's Info.plist without loading the plugin, so that a disabled plugin
// contributes nothing and no plugin code decides menu presence. Inventing new entries
// needs that ABI to grow a sidecar; overriding a prompt does not.

import Foundation

public struct SkillStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    private func url(_ name: String) -> URL { directory.appendingPathComponent(name) }

    /// The file-action skills: the user's, where present, else the built-ins.
    public func load() -> [Skill] {
        merged(userSkills(in: "skills.json"), with: SkillCatalog.fileSkills)
    }

    /// The folder-action skills, same rules.
    public func loadFolderSkills() -> [Skill] {
        merged(userSkills(in: "folder-skills.json"), with: SkillCatalog.folderSkills)
    }

    /// A skill by id, from the user's file or the built-ins. `nil` if no such skill exists.
    public func skill(id: String) -> Skill? {
        load().first { $0.id == id } ?? loadFolderSkills().first { $0.id == id }
    }

    /// Built-in skills are matched by id and their prompt replaced; an unknown id is simply
    /// carried along, so a file may also hold skills the current build does not declare
    /// (an older or newer plugin, or an entry kept for later).
    private func merged(_ user: [Skill], with builtin: [Skill]) -> [Skill] {
        guard !user.isEmpty else { return builtin }
        // `uniquingKeysWith`, not `uniqueKeysWithValues`: this is a file a person edits, and two
        // entries with the same id would otherwise trap — a hand-written file must not be able to
        // stop the application. The last one written wins, which is what an editor expects.
        var byId = Dictionary(user.map { ($0.id, $0) }, uniquingKeysWith: { _, later in later })
        var out: [Skill] = builtin.map { byId.removeValue(forKey: $0.id) ?? $0 }
        // Whatever is left is a skill the current build does not declare; keep the file's order.
        for skill in user where byId.removeValue(forKey: skill.id) != nil { out.append(skill) }
        return out
    }

    private func userSkills(in file: String) -> [Skill] {
        guard let data = try? Data(contentsOf: url(file)),
              let skills = try? JSONDecoder().decode([Skill].self, from: data) else { return [] }
        return skills.filter { !$0.id.isEmpty && !$0.promptTemplate.isEmpty }
    }

    /// Write the built-in skills as editable templates if the user has none yet.
    public func seedTemplateIfMissing() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for (file, skills) in [("skills.json", SkillCatalog.fileSkills),
                               ("folder-skills.json", SkillCatalog.folderSkills)] {
            let target = url(file)
            guard !FileManager.default.fileExists(atPath: target.path),
                  let data = try? encoder.encode(skills) else { continue }
            try? data.write(to: target)
        }
    }
}
