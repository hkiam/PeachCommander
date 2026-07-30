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

    func test_load_returnsUserSkills() throws {
        let dir = tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let custom = [Skill(id: "translate-de", title: "Translate to German",
                            promptTemplate: "Translate {name} ({path}) to German.")]
        let data = try JSONEncoder().encode(custom)
        try data.write(to: dir.appendingPathComponent("skills.json"))
        let store = SkillStore(directory: dir)
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Translate to German")
        XCTAssertTrue(loaded.first!.prompt(name: "a.txt", path: "/a.txt").contains("German"))
    }

    func test_load_ignoresEmptyArray() throws {
        let dir = tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: dir.appendingPathComponent("skills.json"))
        XCTAssertEqual(SkillStore(directory: dir).load().map(\.id), SkillCatalog.fileSkills.map(\.id))
    }
}
