import XCTest
@testable import PCAutomation

final class SkillCatalogTests: XCTestCase {
    func test_catalogs_areNonEmpty_withUniqueIds() {
        XCTAssertFalse(SkillCatalog.fileSkills.isEmpty)
        XCTAssertFalse(SkillCatalog.folderSkills.isEmpty)
        let ids = (SkillCatalog.fileSkills + SkillCatalog.folderSkills).map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_promptSubstitution() {
        let skill = SkillCatalog.fileSkills.first { $0.id == "summarize" }!
        let prompt = skill.prompt(name: "report.txt", path: "/Users/me/report.txt")
        XCTAssertTrue(prompt.contains("report.txt"))
        XCTAssertTrue(prompt.contains("/Users/me/report.txt"))
        XCTAssertFalse(prompt.contains("{name}"))
        XCTAssertFalse(prompt.contains("{path}"))
    }
}
