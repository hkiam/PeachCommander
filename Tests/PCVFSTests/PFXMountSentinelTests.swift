// SPDX-License-Identifier: Apache-2.0
// PFXMountSentinelTests.swift - The sentinel a plugin drive chip carries.
//
// Small and worth having, because the format is the only carrier of "which chip did the user click".
// `driveBar.onSelect` passes this string and nothing else, so anything the encoding loses is lost for
// good — and what it lost was the volume, which is why a plugin with a chip per saved connection
// could only ever open its own dialog.

import XCTest
@testable import PCVFS

final class PFXMountSentinelTests: XCTestCase {

    func test_aPluginAndVolumeRoundTrip() {
        let made = PFXMountSentinel.make(pluginId: "/Library/PlugIns/S3.pfxplugin", volumeId: "s3:Work")
        let parsed = PFXMountSentinel.parse(made)
        XCTAssertEqual(parsed?.pluginId, "/Library/PlugIns/S3.pfxplugin")
        XCTAssertEqual(parsed?.volumeId, "s3:Work")
    }

    func test_aVolumeIdFullOfSeparatorsStillRoundTrips() {
        // Both halves are hostile: the plugin id is a filesystem path and the volume id is a token the
        // plugin chose. A volume id containing "#", ":" and "/" is legal, and splitting on the first
        // separator — or not encoding at all — is how one of them eats the other.
        let awkward = "s3:a#b/c:d e"
        let made = PFXMountSentinel.make(pluginId: "/Users/x/My Plug#Ins/S3.pfxplugin",
                                        volumeId: awkward)
        let parsed = PFXMountSentinel.parse(made)
        XCTAssertEqual(parsed?.pluginId, "/Users/x/My Plug#Ins/S3.pfxplugin")
        XCTAssertEqual(parsed?.volumeId, awkward)
    }

    func test_aSentinelWithoutAVolumeIsStillValid() {
        // `session.ini` holds these. A session written by a build that predates the volume id has to
        // restore, not be discarded — and it restores as "this plugin, no particular volume", which is
        // exactly what it meant then.
        let parsed = PFXMountSentinel.parse("pfxmount:/Library/PlugIns/TaskManager.pfxplugin")
        XCTAssertEqual(parsed?.pluginId, "/Library/PlugIns/TaskManager.pfxplugin")
        XCTAssertNil(parsed?.volumeId)
    }

    func test_anEmptyVolumeIdIsNotEncodedAtAll() {
        // A plugin may leave the id empty. Appending a bare "#" would then produce a sentinel that
        // parses back to an empty-but-present volume, which is a third state nothing wants.
        let made = PFXMountSentinel.make(pluginId: "/p", volumeId: "")
        XCTAssertEqual(made, "pfxmount:/p")
        XCTAssertNil(PFXMountSentinel.parse(made)?.volumeId)
    }

    func test_somethingThatIsNotAPluginSentinelIsRefused() {
        // The drive bar routes on this: a local path or an open network connection must NOT be read as
        // a plugin mount, or clicking the boot disk would try to connect a plugin.
        XCTAssertNil(PFXMountSentinel.parse("/Users/admin"))
        XCTAssertNil(PFXMountSentinel.parse("netmount:3"))
        XCTAssertNil(PFXMountSentinel.parse(""))
    }

    func test_theDriveBarStillClassifiesAWidenedSentinelAsAPluginDrive() {
        // `VolumeKind` decides the icon and the VoiceOver word from this prefix. The sentinel grew a
        // suffix; the classification must not have noticed.
        let volume = Volume(id: "pfxvol:x:s3:Work", name: "Work",
                            path: PFXMountSentinel.make(pluginId: "/p", volumeId: "s3:Work"),
                            isRemovable: false, isEjectable: false, isHidden: false,
                            capacity: 0, freeSpace: 0, fsType: "Plugin", isLocal: false)
        XCTAssertEqual(VolumeKind.of(volume), .pluginDrive)
    }
}
