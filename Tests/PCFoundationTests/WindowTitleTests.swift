// SPDX-License-Identifier: Apache-2.0
// WindowTitleTests.swift - The window title says where you are (F-012).
//
// It did not. `window.title` was assigned the literal "Peach Commander" at startup and never touched
// again, so the title was the same whatever folder the panel showed — and that is the text Mission
// Control, the Window menu and Cmd-Tab display, which made two windows on two folders
// indistinguishable. Measured before the fix by dumping the window titles in the VM: one line,
// "window=Peach Commander".

import XCTest
@testable import PCFoundation

final class WindowTitleTests: XCTestCase {
    private let home = "/Users/me"

    func testThePathIsTheTitle() {
        XCTAssertEqual(WindowTitle.text(path: "/Users/me/Documents", home: home), "~/Documents")
    }

    func testTheHomeFolderItself() {
        XCTAssertEqual(WindowTitle.text(path: home, home: home), "~")
    }

    func testAPathOutsideTheHomeFolderIsLeftAlone() {
        XCTAssertEqual(WindowTitle.text(path: "/Volumes/Backup/2026", home: home), "/Volumes/Backup/2026")
        XCTAssertEqual(WindowTitle.text(path: "/", home: home), "/")
    }

    func testASiblingWhoseNameStartsWithTheHomePathIsNotAbbreviated() {
        // "/Users/mel" begins with "/Users/me" and is somebody else's folder. Without the
        // separator check it would be shown as "~l".
        XCTAssertEqual(WindowTitle.text(path: "/Users/mel/Documents", home: home),
                       "/Users/mel/Documents")
    }

    func testAnEmptyPathFallsBackToTheApplicationName() {
        XCTAssertEqual(WindowTitle.text(path: "", home: home), "Peach Commander")
    }

    // MARK: - The optional free-space part

    func testFreeSpaceIsLeftOutUnlessAskedFor() {
        let title = WindowTitle.text(path: home, home: home, freeSpace: 5_000_000_000,
                                     capacity: 10_000_000_000, showFreeSpace: false)
        XCTAssertEqual(title, "~")
    }

    func testFreeSpaceAndPercentage() {
        let title = WindowTitle.text(path: home, home: home, freeSpace: 5_000_000_000,
                                     capacity: 10_000_000_000, showFreeSpace: true,
                                     locale: Locale(identifier: "en_US"))
        XCTAssertTrue(title.hasPrefix("~ — "), title)
        XCTAssertTrue(title.contains("free"), title)
        XCTAssertTrue(title.contains("(50 %)"), title)
    }

    func testAVolumeThatWillNotSayHowBigItIsGetsNoPercentage() {
        // A network mount reporting a capacity of zero: "0 % free" is worse than saying nothing.
        let title = WindowTitle.text(path: home, home: home, freeSpace: 1_000_000, capacity: 0,
                                     showFreeSpace: true, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(title.contains("free"), title)
        XCTAssertFalse(title.contains("%"), title)
    }

    func testAVolumeThatReportsNothingAtAllIsJustThePath() {
        let title = WindowTitle.text(path: home, home: home, freeSpace: nil, capacity: nil,
                                     showFreeSpace: true)
        XCTAssertEqual(title, "~")
    }
}
