// SPDX-License-Identifier: Apache-2.0
// SkillCatalog.swift - named AI actions ("Mit KI…") for the context menu.
//
// A skill is just a titled prompt template targeting the file(s) under the cursor.
// Selecting one opens the assistant with the prompt pre-filled; the model then uses
// the Automation Core tools (read_file, etc.) to carry it out — under the same
// permission model as any agent turn. Skills are data, so they are easy to extend or
// make user-configurable later.

import Foundation

public struct Skill: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let title: String
    /// Prompt template; `{name}` and `{path}` are substituted with the target file.
    public let promptTemplate: String
    public init(id: String, title: String, promptTemplate: String) {
        self.id = id; self.title = title; self.promptTemplate = promptTemplate
    }
    /// The concrete prompt for a target file.
    public func prompt(name: String, path: String) -> String {
        promptTemplate
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{path}", with: path)
    }
}

public enum SkillCatalog {
    /// Skills that act on the file under the cursor.
    public static let fileSkills: [Skill] = [
        .init(id: "summarize", title: "Summarize",
              promptTemplate: "Read the file \"{name}\" at {path} and give me a short summary."),
        .init(id: "explain", title: "Explain",
              promptTemplate: "Read \"{name}\" ({path}) and explain what it is and what it does."),
        .init(id: "suggest-rename", title: "Suggest a name",
              promptTemplate: "Read \"{name}\" ({path}) and suggest a clearer, descriptive file name based on its contents. Do not rename it — just propose the name."),
        .init(id: "translate", title: "Translate to English",
              promptTemplate: "Read \"{name}\" ({path}) and translate its text content to English."),
        .init(id: "check", title: "Proofread",
              promptTemplate: "Read \"{name}\" ({path}) and proofread it — list spelling, grammar and clarity issues."),
        .init(id: "detect-tasks", title: "Detect tasks",
              promptTemplate: "Read \"{name}\" ({path}) and list any action items, tasks or deadlines it mentions."),
        .init(id: "make-table", title: "Make a table",
              promptTemplate: "Read the structured data in \"{name}\" ({path}) and turn it into a Markdown table."),
    ]

    /// Skills that act on the whole active folder / selection.
    public static let folderSkills: [Skill] = [
        .init(id: "organize", title: "Organize this folder",
              promptTemplate: "Look at the folder {path} and propose a plan to organize its files by type. Show the plan before doing anything."),
        .init(id: "find-duplicates", title: "Find likely duplicates",
              promptTemplate: "Examine the files in {path} and point out likely duplicate or redundant files."),
    ]
}
