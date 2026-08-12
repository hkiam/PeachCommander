// SPDX-License-Identifier: Apache-2.0
// WorkspaceCodecTests.swift - Round-trips the Workspaces tab serialization.

import XCTest
@testable import PCFoundation

final class WorkspaceCodecTests: XCTestCase {
    func test_roundTrip_preservesAllFields() {
        let tabs = [
            PanelTabState(path: "/Users/me/Docs", sortColumn: "date", sortAscending: false,
                          locked: true, cursorName: "report.pdf"),
            PanelTabState(path: "/tmp", sortColumn: "name", sortAscending: true,
                          locked: false, cursorName: nil),
        ]
        let decoded = WorkspaceCodec.decode(WorkspaceCodec.encode(tabs))
        XCTAssertEqual(decoded, tabs)
    }

    func test_emptyString_decodesToNoTabs() {
        XCTAssertEqual(WorkspaceCodec.decode(""), [])
    }

    func test_pathWithSpacesAndUnicode_survives() {
        let tabs = [PanelTabState(path: "/Vôl ümes/Ärchïv 1/sub dir", sortColumn: "ext",
                                  sortAscending: true, locked: false, cursorName: "à b.txt")]
        XCTAssertEqual(WorkspaceCodec.decode(WorkspaceCodec.encode(tabs)), tabs)
    }

    func test_roundTrip_keepsATabOnAPluginDrive() {
        // The drive is what such a tab is on; its path is the mount's own "/", which on its own
        // would restore the startup disk's root and call it the same tab.
        let tabs = [PanelTabState(path: "/", sortColumn: "name", sortAscending: true, locked: false,
                                  cursorName: nil, driveVolume: "pfxmount:/Plugins/TaskManager.pfxplugin")]
        XCTAssertEqual(WorkspaceCodec.decode(WorkspaceCodec.encode(tabs)), tabs)
    }

    func test_aWorkspaceSavedBeforeDrivesExisted_stillLoads() {
        // Five fields, the format before the drive was recorded. It must decode as a tab with no
        // drive rather than be skipped — a saved workspace is the user's, not the format's.
        let old = ["/Users/me", "name", "1", "0", "note.txt"].joined(separator: "\u{1}")
        XCTAssertEqual(WorkspaceCodec.decode(old),
                       [PanelTabState(path: "/Users/me", sortColumn: "name", sortAscending: true,
                                      locked: false, cursorName: "note.txt", driveVolume: nil)])
    }

    func test_malformedRecord_isSkipped() {
        // Append a bogus record (a lone "onlypath" with no field separators, so
        // it has < 4 fields) after a valid one — only the valid tab decodes.
        let good = PanelTabState(path: "/ok", sortColumn: "name", sortAscending: true, locked: false)
        let mixed = WorkspaceCodec.encode([good]) + "\u{2}" + "onlypath"
        XCTAssertEqual(WorkspaceCodec.decode(mixed), [good])
    }
}
