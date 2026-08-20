// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

final class SkillStoreTests: XCTestCase {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func test_load_fallsBackToBuiltins_whenNoFile() {
        let store = SkillStore(directory: tempDir())
        XCTAssertEqual(store.load().map(\.id), SkillCatalog.fileSkills.map(\.id))
    }

    func test_seedTemplate_thenLoadReturnsBuiltins() {
        let store = SkillStore(directory: tempDir())
        store.seedTemplateIfMissing()
        XCTAssertEqual(store.load().count, SkillCatalog.fileSkills.count)
    }

    /// A user's file ADDS to and overrides the built-ins rather than replacing them.
    ///
    /// This test used to assert the opposite — that `load()` returns the user's list alone.
    /// That cannot be right while the *menu* is declared in the plugin's Info.plist, which the
    /// host reads without loading the plugin: a file with one skill in it would leave the other
    /// seven "AI ▸" entries on screen with no prompt behind them, and clicking one would do
    /// nothing at all. Every declared action keeps a prompt; the user's version wins where the
    /// ids meet.
    func test_load_addsUserSkills_andKeepsTheDeclaredOnes() throws {
        let dir = tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let custom = [Skill(id: "translate-de", title: "Translate to German",
                            promptTemplate: "Translate {name} ({path}) to German.")]
        let data = try JSONEncoder().encode(custom)
        try data.write(to: dir.appendingPathComponent("skills.json"))
        let loaded = SkillStore(directory: dir).load()
        let mine = loaded.first { $0.id == "translate-de" }
        XCTAssertNotNil(mine)
        XCTAssertTrue(mine!.prompt(name: "a.txt", path: "/a.txt").contains("German"))
        for declared in SkillCatalog.fileSkills {
            XCTAssertNotNil(loaded.first { $0.id == declared.id },
                            "\(declared.id) is in the menu, so it must still have a prompt")
        }
    }

    func test_load_ignoresEmptyArray() throws {
        let dir = tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: dir.appendingPathComponent("skills.json"))
        XCTAssertEqual(SkillStore(directory: dir).load().map(\.id), SkillCatalog.fileSkills.map(\.id))
    }
}

// The store is what makes the "AI ▸" prompts data rather than code. These pin the rules the
// plugin relies on: an override replaces the built-in prompt, the built-in list stays
// complete, and anything unreadable falls back instead of emptying the menu.
final class SkillStoreOverrideTests: XCTestCase {

    private func store() throws -> (SkillStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (SkillStore(directory: dir), dir)
    }

    func test_seed_writesBothTemplates() throws {
        let (store, dir) = try store()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.seedTemplateIfMissing()
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("skills.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("folder-skills.json").path))
        XCTAssertEqual(store.load().count, SkillCatalog.fileSkills.count)
    }

    func test_userPrompt_overridesTheBuiltIn_keepingTheRest() throws {
        let (store, dir) = try store()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mine = [Skill(id: "summarize", title: "Summarize",
                          promptTemplate: "Fasse {name} in genau einem Satz zusammen.")]
        try JSONEncoder().encode(mine).write(to: dir.appendingPathComponent("skills.json"))
        let loaded = store.load()
        XCTAssertEqual(loaded.count, SkillCatalog.fileSkills.count, "the other actions stay")
        XCTAssertEqual(loaded.first { $0.id == "summarize" }?.promptTemplate,
                       "Fasse {name} in genau einem Satz zusammen.")
        XCTAssertEqual(loaded.first { $0.id == "translate" }?.promptTemplate,
                       SkillCatalog.fileSkills.first { $0.id == "translate" }?.promptTemplate)
    }

    func test_unknownId_isCarriedAlong() throws {
        let (store, dir) = try store()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mine = [Skill(id: "team-review", title: "Review", promptTemplate: "Prüfe {path}.")]
        try JSONEncoder().encode(mine).write(to: dir.appendingPathComponent("skills.json"))
        XCTAssertNotNil(store.load().first { $0.id == "team-review" })
    }

    func test_brokenFile_fallsBackToTheBuiltIns() throws {
        let (store, dir) = try store()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("not json at all".utf8).write(to: dir.appendingPathComponent("skills.json"))
        XCTAssertEqual(store.load().map(\.id), SkillCatalog.fileSkills.map(\.id))
    }

    func test_emptyPromptsAreIgnored() throws {
        let (store, dir) = try store()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mine = [Skill(id: "summarize", title: "Summarize", promptTemplate: "")]
        try JSONEncoder().encode(mine).write(to: dir.appendingPathComponent("skills.json"))
        XCTAssertEqual(store.load().first { $0.id == "summarize" }?.promptTemplate,
                       SkillCatalog.fileSkills.first { $0.id == "summarize" }?.promptTemplate)
    }

    func test_folderSkills_haveTheirOwnFile() throws {
        let (store, dir) = try store()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mine = [Skill(id: "organize", title: "Organize", promptTemplate: "Sortiere {path} nach Datum.")]
        try JSONEncoder().encode(mine).write(to: dir.appendingPathComponent("folder-skills.json"))
        XCTAssertEqual(store.loadFolderSkills().first { $0.id == "organize" }?.promptTemplate,
                       "Sortiere {path} nach Datum.")
        XCTAssertEqual(store.load().map(\.id), SkillCatalog.fileSkills.map(\.id), "unaffected")
    }

    // A hand-edited file must not be able to stop the application: two entries with the same id
    // used to trap in `Dictionary(uniqueKeysWithValues:)`.
    func test_duplicateIds_doNotCrash_andTheLastOneWins() throws {
        let (store, dir) = try store(); defer { try? FileManager.default.removeItem(at: dir) }
        let mine = [Skill(id: "summarize", title: "A", promptTemplate: "erste"),
                    Skill(id: "summarize", title: "B", promptTemplate: "zweite")]
        try JSONEncoder().encode(mine).write(to: dir.appendingPathComponent("skills.json"))
        let loaded = store.load()
        XCTAssertEqual(loaded.filter { $0.id == "summarize" }.count, 1)
        XCTAssertEqual(loaded.first { $0.id == "summarize" }?.promptTemplate, "zweite")
    }

    func test_duplicateUnknownIds_appearOnce() throws {
        let (store, dir) = try store(); defer { try? FileManager.default.removeItem(at: dir) }
        let mine = [Skill(id: "eigen", title: "A", promptTemplate: "eins"),
                    Skill(id: "eigen", title: "B", promptTemplate: "zwei")]
        try JSONEncoder().encode(mine).write(to: dir.appendingPathComponent("skills.json"))
        XCTAssertEqual(store.load().filter { $0.id == "eigen" }.count, 1)
    }
}
