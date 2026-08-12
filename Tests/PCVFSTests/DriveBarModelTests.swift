// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCVFS

final class DriveBarModelTests: XCTestCase {
    private func vol(_ name: String, _ path: String, hidden: Bool = false) -> Volume {
        Volume(id: path, name: name, path: path, isRemovable: false, isEjectable: false,
               isHidden: hidden, capacity: 0, freeSpace: 0, fsType: "apfs")
    }

    func testDisplayRootFirstThenByNameHiddenDropped() {
        let volumes = [
            vol("USB", "/Volumes/USB"),
            vol("Macintosh HD", "/"),
            vol("Backup", "/Volumes/Backup"),
            vol("hidden", "/Volumes/.hidden", hidden: true)
        ]
        let shown = DriveBarModel.display(volumes)
        XCTAssertEqual(shown.map(\.path), ["/", "/Volumes/Backup", "/Volumes/USB"])
    }

    func testPluginPinnedVolumeRanksRightAfterBoot() {
        // A plugin-pinned volume (sortOrder > 0, e.g. TaskManager) sorts right
        // after the boot drive, ahead of ordinary volumes — even though its name
        // would otherwise sort last. Pinned volumes order among themselves by
        // sortOrder ascending.
        let taskman = Volume(id: "pfxvol:taskman", name: "TaskManager", path: "pfxmount:tm",
                             isRemovable: false, isEjectable: false, isHidden: false,
                             capacity: 0, freeSpace: 0, fsType: "Plugin", icon: "📊", sortOrder: 1)
        let other = Volume(id: "pfxvol:other", name: "Alpha", path: "pfxmount:o",
                           isRemovable: false, isEjectable: false, isHidden: false,
                           capacity: 0, freeSpace: 0, fsType: "Plugin", icon: "🔧", sortOrder: 2)
        let volumes = [vol("Backup", "/Volumes/Backup"), other, vol("Macintosh HD", "/"), taskman]
        let shown = DriveBarModel.display(volumes)
        XCTAssertEqual(shown.map(\.name), ["Macintosh HD", "TaskManager", "Alpha", "Backup"])
    }

    func testDisplayDedupesSameNamedVolumes() {
        // An APFS volume group exposes several volumes all named "Macintosh HD".
        let volumes = [
            vol("Macintosh HD", "/System/Volumes/Data"),
            vol("Macintosh HD", "/"),
            vol("Macintosh HD", "/System/Volumes/Update"),
            vol("USB", "/Volumes/USB")
        ]
        let shown = DriveBarModel.display(volumes)
        // One "Macintosh HD" (the root entry) plus the USB drive.
        XCTAssertEqual(shown.map(\.path), ["/", "/Volumes/USB"])
    }

    func testCurrentIndexLongestPrefixWins() {
        let volumes = [vol("HD", "/"), vol("USB", "/Volumes/USB")]
        XCTAssertEqual(DriveBarModel.currentIndex(in: volumes, for: "/Volumes/USB/photos"), 1)
        XCTAssertEqual(DriveBarModel.currentIndex(in: volumes, for: "/Users/foo"), 0)
        XCTAssertEqual(DriveBarModel.currentIndex(in: volumes, for: "/Volumes/USB"), 1)  // exact mount
    }

    func testCurrentIndexNoMatch() {
        let volumes = [vol("USB", "/Volumes/USB")]
        XCTAssertNil(DriveBarModel.currentIndex(in: volumes, for: "/Users/foo"))
        XCTAssertNil(DriveBarModel.currentIndex(in: [], for: "/"))
    }

    func testMountedPluginVolumeIsCurrentInsteadOfItsPath() {
        // Inside a plugin drive (TaskManager) the panel's path is that mount's own "/", which by
        // prefix belongs to the boot drive. The mounted volume decides instead, so the chip the
        // user clicked is the one lit.
        let taskman = Volume(id: "pfxvol:tm", name: "TaskManager", path: "pfxmount:tm",
                             isRemovable: false, isEjectable: false, isHidden: false,
                             capacity: 0, freeSpace: 0, fsType: "Plugin", icon: "📊", sortOrder: 1)
        let volumes = [vol("HD", "/"), taskman, vol("USB", "/Volumes/USB")]
        XCTAssertEqual(DriveBarModel.currentIndex(in: volumes, for: "/", mountedVolumePath: "pfxmount:tm"), 1)
        // No mount: the path decides, as before.
        XCTAssertEqual(DriveBarModel.currentIndex(in: volumes, for: "/"), 0)
    }

    func testMountedVolumeNoLongerInTheBarHighlightsNothing() {
        // An unplugged/unregistered mount must not fall back to the path — that is how the boot
        // drive ends up lit while the panel is somewhere else entirely.
        let volumes = [vol("HD", "/"), vol("USB", "/Volumes/USB")]
        XCTAssertNil(DriveBarModel.currentIndex(in: volumes, for: "/", mountedVolumePath: "pfxmount:tm"))
    }

    func testPrefixDoesNotMatchSiblingWithSharedName() {
        // "/Volumes/USB2" must not be considered inside "/Volumes/USB".
        let volumes = [vol("USB", "/Volumes/USB")]
        XCTAssertNil(DriveBarModel.currentIndex(in: volumes, for: "/Volumes/USB2/x"))
    }
}
