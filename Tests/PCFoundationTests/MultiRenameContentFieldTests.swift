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
