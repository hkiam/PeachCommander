// SPDX-License-Identifier: Apache-2.0
// VolumeKindTests.swift - What the drive bar says a volume is (F-386).
//
// The categories overlap in the data — a cloud folder is a local directory, a plugin drive's "path"
// is not a path at all — so what is tested here is mostly the *order* the questions are asked in.
// Each case below is one that an earlier question would have answered wrongly.

import XCTest
@testable import PCVFS

final class VolumeKindTests: XCTestCase {
    private func vol(_ name: String, _ path: String, removable: Bool = false, ejectable: Bool = false,
                     fsType: String = "APFS", icon: String = "", isLocal: Bool = true) -> Volume {
        Volume(id: path, name: name, path: path, isRemovable: removable, isEjectable: ejectable,
               isHidden: false, capacity: 0, freeSpace: 0, fsType: fsType, icon: icon,
               isLocal: isLocal)
    }

    func testTheStartupDiskIsItsOwnKind() {
        XCTAssertEqual(VolumeKind.of(vol("Macintosh HD", "/")), .startupDisk)
    }

    func testAnOrdinaryMountedDiskIsInternal() {
        XCTAssertEqual(VolumeKind.of(vol("Data", "/Volumes/Data")), .internalDisk)
    }

    func testRemovableOrEjectableIsExternal() {
        XCTAssertEqual(VolumeKind.of(vol("Stick", "/Volumes/Stick", removable: true, ejectable: true)),
                       .externalDisk)
        // A mounted disk image and an external drive both report ejectable and nothing else in the
        // data separates them, so both land here rather than being guessed apart. The icon the bar
        // draws is the system's and does know the difference.
        XCTAssertEqual(VolumeKind.of(vol("PeachCommander", "/Volumes/PeachCommander", ejectable: true)),
                       .externalDisk)
    }

    func testAShareIsRecognisedByBeingRemoteNotByItsFormatName() {
        // fsType is `volumeLocalizedFormatDescription` — localized, so matching it for "SMB" works in
        // English and stops working in the other eighteen languages. isLocal is the fact.
        let share = vol("team", "/Volumes/team", fsType: "Netzwerkdateisystem", isLocal: false)
        XCTAssertEqual(VolumeKind.of(share), .networkShare)
        // …and a local volume whose format description happens to mention a network protocol is not
        // a share.
        XCTAssertEqual(VolumeKind.of(vol("SMB Backup", "/Volumes/SMB Backup", fsType: "SMB")), .internalDisk)
    }

    func testACloudFolderIsNotAnInternalVolume() {
        // It really is a directory on the startup disk, so every question after the cloud one would
        // call it internal.
        let cloud = vol("iCloud Drive", "/Users/me/Library/Mobile Documents", fsType: "Cloud")
        XCTAssertEqual(VolumeKind.of(cloud), .cloudFolder)
    }

    func testAPluginDriveIsAskedAboutBeforeItsPathIsBelieved() {
        // "pfxmount:<id>" is a sentinel, not a place: read as a path it is neither "/" nor local
        // anything, and every later question would be answered about a directory that does not exist.
        let taskman = vol("TaskManager", "pfxmount:/Plugins/TaskManager.pfxplugin",
                          fsType: "Plugin", icon: "📊")
        XCTAssertEqual(VolumeKind.of(taskman), .pluginDrive)
    }

    func testAnOpenConnectionIsAskedAboutBeforeItLooksLikeAShare() {
        // "netmount:<n>" is a sentinel like the plugin one, and the question order matters for a
        // second reason here: a connection is not local, so the share question one line down would
        // have claimed it — promising a mount the system knows about, which Finder can see and
        // which can be unmounted from somewhere other than its own chip. None of that is true.
        let session = vol("prod-ftp", "netmount:1", fsType: "FTP", isLocal: false)
        XCTAssertEqual(VolumeKind.of(session), .networkConnection)
    }

    func testOnlyRealVolumesAreWorthAskingTheSystemAbout() {
        // The two that are not volumes: a cloud folder is a directory and comes back as the generic
        // blue folder — the same icon as everything else on screen — and a plugin drive has no path
        // to ask about. Both keep their glyph instead, which is the more informative answer.
        XCTAssertFalse(VolumeKind.cloudFolder.hasSystemIcon)
        XCTAssertFalse(VolumeKind.pluginDrive.hasSystemIcon)
        XCTAssertFalse(VolumeKind.networkConnection.hasSystemIcon)
        for kind in [VolumeKind.startupDisk, .internalDisk, .externalDisk, .networkShare] {
            XCTAssertTrue(kind.hasSystemIcon, "\(kind) is a real volume and has an icon of its own")
        }
    }

    func testEveryKindHasItsOwnGlyph() {
        // The glyph is what stands in until an icon is read, so two kinds sharing one would show the
        // same placeholder for volumes the bar exists to tell apart.
        let glyphs = VolumeKind.allCases.map(\.glyph)
        XCTAssertEqual(Set(glyphs).count, VolumeKind.allCases.count)
        XCTAssertFalse(glyphs.contains(where: \.isEmpty))
    }
}
