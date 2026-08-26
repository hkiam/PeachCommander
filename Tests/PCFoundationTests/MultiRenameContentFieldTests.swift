// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class MultiRenameContentFieldTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 0)

    func testContentFieldPlaceholder() {
        let input = RenameInput(name: "photo.jpg", modified: epoch,
                                fields: ["fileinfo.width": "1920", "fileinfo.height": "1080"])
        let spec = RenameSpec(nameMask: "[N]_[=fileinfo.width]x[=fileinfo.height]", extMask: "[E]")
        let result = MultiRenameEngine.compute([input], spec: spec)
        XCTAssertEqual(result.first?.newName, "photo_1920x1080.jpg")
    }

    func testMissingFieldExpandsEmpty() {
        let input = RenameInput(name: "a.txt", modified: epoch, fields: [:])
        let spec = RenameSpec(nameMask: "[N][=fileinfo.width]", extMask: "[E]")
        XCTAssertEqual(MultiRenameEngine.compute([input], spec: spec).first?.newName, "a.txt")
    }

    func testContentFieldCombinesWithCounter() {
        let inputs = [
            RenameInput(name: "one.png", modified: epoch, fields: ["fileinfo.dimensions": "800 × 600"]),
            RenameInput(name: "two.png", modified: epoch, fields: ["fileinfo.dimensions": "640 × 480"])
        ]
        let spec = RenameSpec(nameMask: "[C]_[=fileinfo.dimensions]", extMask: "[E]",
                              counterStart: 1, counterStep: 1, counterDigits: 2)
        let names = MultiRenameEngine.compute(inputs, spec: spec).map(\.newName)
        XCTAssertEqual(names, ["01_800 × 600.png", "02_640 × 480.png"])
    }

    // MARK: - The AI fields as rename tokens
    //
    // The AI On-Device plugin's Classify action writes a kind, a topic and a date into a cache that
    // the AI Column plugin serves as content fields. Nothing about renaming was built for that —
    // `[=provider.field]` has always resolved through the content-field registry — which is exactly
    // why it is worth a test: the feature is the composition, and a composition breaks silently.

    func testAnAITopicIsARenameToken() {
        let input = RenameInput(name: "dokument1.pdf", modified: epoch,
                                fields: ["ai_column.ai_topic": "dachreparatur",
                                         "ai_column.ai_date": "2024-03-12"])
        let spec = RenameSpec(nameMask: "[=ai_column.ai_topic]-[=ai_column.ai_date]", extMask: "[E]")
        XCTAssertEqual(MultiRenameEngine.compute([input], spec: spec).first?.newName,
                       "dachreparatur-2024-03-12.pdf")
    }

    func testAnAIKindCombinesWithTheFilesOwnDate() {
        // The mask carries the calendar tokens; the model only ever supplies the words. That split
        // is the point — a date the file system knows is not a date a model should be inventing.
        let input = RenameInput(name: "scan.png", modified: Date(timeIntervalSince1970: 1_700_000_000),
                                fields: ["ai_column.ai_kind": "Rechnungen"])
        let spec = RenameSpec(nameMask: "[=ai_column.ai_kind]-[Y]-[M]", extMask: "[E]")
        XCTAssertEqual(MultiRenameEngine.compute([input], spec: spec).first?.newName,
                       "Rechnungen-2023-11.png")
    }

    func testAFileTheAssistantKnowsNothingAboutKeepsItsName() {
        // Classify skips what it cannot place, so a mask made of AI tokens has to degrade to
        // something rather than produce a file called "-".
        let input = RenameInput(name: "unknown.bin", modified: epoch, fields: [:])
        let spec = RenameSpec(nameMask: "[=ai_column.ai_topic]", extMask: "[E]")
        XCTAssertEqual(MultiRenameEngine.compute([input], spec: spec).first?.newName, ".bin")
    }

    // MARK: - What an unresolved field placeholder does (F-172)
    //
    // The values behind `[=provider.field]` are fetched before the dialog opens, and that was capped at
    // 500 files "for latency" — so a selection of 600 resolved every placeholder to an empty string and
    // renamed them all with that part missing. Renaming 600 photos by their EXIF date is precisely what
    // this feature is for.
    //
    // The engine cannot know a value is missing versus genuinely empty, so it must at least be
    // predictable about it; the caller now fetches on demand instead of capping. These pin the engine's
    // half of that contract.

    func testAnUnknownFieldExpandsToNothingRatherThanToItsOwnName() {
        let input = RenameInput(name: "photo.jpg", modified: Date(timeIntervalSince1970: 0))
        let spec = RenameSpec(nameMask: "[=exif.date]-[N]", extMask: "[E]")
        let result = MultiRenameEngine.compute([input], spec: spec)
        XCTAssertEqual(result.first?.newName, "-photo.jpg",
                       "a placeholder with no value must not leak its own text into the name")
    }

    func testAKnownFieldIsSubstituted() {
        let input = RenameInput(name: "photo.jpg", modified: Date(timeIntervalSince1970: 0),
                                fields: ["exif.date": "2026-08-08"])
        let spec = RenameSpec(nameMask: "[=exif.date]-[N]", extMask: "[E]")
        XCTAssertEqual(MultiRenameEngine.compute([input], spec: spec).first?.newName,
                       "2026-08-08-photo.jpg")
    }

    func testAFieldValueContainingASeparatorMakesTheNameInvalid() {
        // A plugin can return anything; a "/" in a value would otherwise silently produce a rename into
        // another directory. The preview marks it rather than the rename attempting it.
        let input = RenameInput(name: "a.txt", modified: Date(timeIntervalSince1970: 0),
                                fields: ["plugin.path": "sub/dir"])
        let spec = RenameSpec(nameMask: "[=plugin.path]", extMask: "[E]")
        let result = MultiRenameEngine.compute([input], spec: spec).first
        XCTAssertEqual(result?.isValid, false)
    }

    func testEveryFileGettingTheSameEmptyValueCollides() {
        // The shape of the defect: with the values missing, every name became the same one — and the
        // collision flag is what stops that batch from running.
        let inputs = (1...3).map {
            RenameInput(name: "photo\($0).jpg", modified: Date(timeIntervalSince1970: 0))
        }
        let spec = RenameSpec(nameMask: "[=exif.date]", extMask: "[E]")
        let results = MultiRenameEngine.compute(inputs, spec: spec)
        XCTAssertTrue(results.allSatisfy(\.collides),
                      "three files renamed to the same empty-derived name must be flagged")
    }
}
