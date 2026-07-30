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
}
