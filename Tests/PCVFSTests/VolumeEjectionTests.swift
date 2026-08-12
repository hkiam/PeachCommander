// SPDX-License-Identifier: Apache-2.0
// VolumeEjectionTests.swift - Which volume "Eject" means (F-006).

import XCTest
@testable import PCVFS

final class VolumeEjectionTests: XCTestCase {

    private func volume(_ name: String, _ path: String, ejectable: Bool = true) -> Volume {
        Volume(id: path, name: name, path: path, isRemovable: ejectable, isEjectable: ejectable,
               isHidden: false, capacity: 1000, freeSpace: 500, fsType: "apfs", icon: "", sortOrder: 0)
    }

    private var mounted: [Volume] {
        [volume("Macintosh HD", "/", ejectable: false),
         volume("Blender", "/Volumes/Blender"),
         volume("Blender Backup", "/Volumes/Blender Backup"),
         volume("Server", "/Volumes/Server", ejectable: false)]
    }

    func testTheVolumeUnderTheCursorWins() throws {
        let target = VolumeEjection.target(focusedPath: "/Volumes/Blender",
                                           currentDirectory: "/Volumes", volumes: mounted)
        XCTAssertEqual(try target.get().name, "Blender")
    }

    func testItWorksFromInsideTheVolume() throws {
        // The complaint that started this was "I have to switch to Finder", and a command that only
        // works from one directory above the stick would not fix that.
        let target = VolumeEjection.target(focusedPath: nil,
                                           currentDirectory: "/Volumes/Blender/scenes/2026",
                                           volumes: mounted)
        XCTAssertEqual(try target.get().name, "Blender")
    }

    func testTheDeepestVolumeWinsRatherThanTheFirstMatch() throws {
        // Every path is inside "/", so a first-match rule answers "the startup disk" for a file on a
        // stick — wrong, and the one answer that must never be acted on.
        let target = VolumeEjection.target(focusedPath: nil,
                                           currentDirectory: "/Volumes/Blender/scenes", volumes: mounted)
        XCTAssertEqual(try target.get().path, "/Volumes/Blender")
    }

    func testASiblingWhoseNameStartsWithAnotherVolumeIsNotConfusedForIt() throws {
        // "/Volumes/Blender Backup" begins with "/Volumes/Blender". Without the component boundary
        // the user would be asked to eject the wrong stick — and would say yes, because the name in
        // the confirmation would look right.
        let target = VolumeEjection.target(focusedPath: nil,
                                           currentDirectory: "/Volumes/Blender Backup/2026",
                                           volumes: mounted)
        XCTAssertEqual(try target.get().name, "Blender Backup")
    }

    func testTheStartupDiskIsRefused() {
        XCTAssertEqual(VolumeEjection.target(focusedPath: "/", currentDirectory: "/", volumes: mounted),
                       .failure(.bootVolume))
        // And from a path on it, which is the same mistake by another route.
        XCTAssertEqual(VolumeEjection.target(focusedPath: nil, currentDirectory: "/Users/me/Documents",
                                             volumes: mounted),
                       .failure(.bootVolume))
    }

    func testAVolumeThatCannotBeEjectedSaysSoByName() {
        XCTAssertEqual(VolumeEjection.target(focusedPath: "/Volumes/Server",
                                             currentDirectory: "/Volumes", volumes: mounted),
                       .failure(.notEjectable(name: "Server")))
    }

    func testATrailingSeparatorIsNotADifferentVolume() throws {
        // The drive bar hands out one form and the panel the other; a user cannot see the difference
        // and must not be able to feel it either.
        let target = VolumeEjection.target(focusedPath: "/Volumes/Blender/",
                                           currentDirectory: "/", volumes: mounted)
        XCTAssertEqual(try target.get().name, "Blender")
    }

    func testNothingMountedMeansNothingToEject() {
        XCTAssertEqual(VolumeEjection.target(focusedPath: "/Volumes/Gone",
                                             currentDirectory: "/Volumes/Gone", volumes: []),
                       .failure(.noVolume))
    }

    // MARK: - The rule a menu greys an entry out with (F-385)

    /// `refusal(for:)` exists so the drive bar's context menu and the command obey one rule. These
    /// pin that it answers the same three ways the command does — an "Eject" that is offered and
    /// then refuses is the failure this prevents.

    func testAMountedDiskImageCanBeEjected() {
        // The case this was built for: a .dmg the system reports as ejectable. Measured on APFS —
        // a mounted disk image comes back isEjectable = true, the boot volume false.
        XCTAssertNil(VolumeEjection.refusal(for: volume("Peach Commander", "/Volumes/Peach Commander")))
    }

    func testTheStartupDiskIsRefusedByName() {
        XCTAssertEqual(VolumeEjection.refusal(for: volume("Macintosh HD", "/")), .bootVolume)
    }

    func testANetworkShareIsRefusedAsNotEjectable() {
        XCTAssertEqual(VolumeEjection.refusal(for: volume("sambashare", "/Volumes/sambashare",
                                                          ejectable: false)),
                       .notEjectable(name: "sambashare"))
    }

    /// The rule the menu uses and the rule the command uses must be the same rule, not two that
    /// happen to agree today.
    func testTheMenuRuleAgreesWithTheCommand() {
        let stick = volume("Stick", "/Volumes/Stick")
        XCTAssertNil(VolumeEjection.refusal(for: stick))
        guard case .success(let chosen) = VolumeEjection.target(focusedPath: "/Volumes/Stick",
                                                               currentDirectory: "/",
                                                               volumes: [stick]) else {
            return XCTFail("the command refused a volume the menu would offer")
        }
        XCTAssertEqual(chosen.path, stick.path)
    }
}
