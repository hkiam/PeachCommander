// SPDX-License-Identifier: Apache-2.0
// ConfigSnapshotTests.swift - The synchronous pre-first-paint config read (F-360).
//
// The point of the snapshot is that it agrees with the actor about the same file. A dialect difference
// would show as a setting that takes effect differently before and after the first paint — exactly the
// bug the snapshot exists to fix, reintroduced one layer down. So the agreement is what is tested.

import XCTest
@testable import PCFoundation

final class ConfigSnapshotTests: XCTestCase {
    private var url = URL(fileURLWithPath: "/dev/null")

    override func setUpWithError() throws {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-snapshot-\(UUID().uuidString).ini")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url)
    }

    private func write(_ text: String) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func testReadsTypedValues() throws {
        try write("""
        [Colors]
        Theme=norton
        [Layout]
        ButtonBar=0
        PreviewWidth=420
        [Window]
        LeftWidth=612.5
        """)
        let snapshot = ConfigSnapshot(url: url)
        XCTAssertEqual(snapshot.string("Colors", "Theme", default: "system"), "norton")
        XCTAssertFalse(snapshot.bool("Layout", "ButtonBar", default: true))
        XCTAssertEqual(snapshot.int("Layout", "PreviewWidth", default: 0), 420)
        XCTAssertEqual(snapshot.double("Window", "LeftWidth", default: 0), 612.5)
    }

    func testAMissingFileReadsAsDefaults() {
        // First launch must not be a special case for the caller.
        let snapshot = ConfigSnapshot(url: url.appendingPathExtension("absent"))
        XCTAssertEqual(snapshot.string("Colors", "Theme", default: "system"), "system")
        XCTAssertTrue(snapshot.bool("Layout", "ButtonBar", default: true))
    }

    func testAbsentKeysFallBackToTheDefault() throws {
        try write("[Colors]\nTheme=norton\n")
        let snapshot = ConfigSnapshot(url: url)
        XCTAssertTrue(snapshot.bool("Layout", "TabBar", default: true))
        XCTAssertEqual(snapshot.int("Display", "FontSize", default: 13), 13)
    }

    func testTheSnapshotAndTheStoreAgreeOnEveryValueForm() async throws {
        // Both read the same file; a disagreement here is the bug this class prevents.
        try write("""
        [T]
        one=1
        zero=0
        yes=Yes
        no=NO
        t=true
        f=False
        nonsense=maybe
        number=42
        notanumber=x
        real=3.5
        """)
        let snapshot = ConfigSnapshot(url: url)
        let store = ConfigStore(url: url)
        for key in ["one", "zero", "yes", "no", "t", "f", "nonsense", "absent"] {
            for fallback in [true, false] {
                let expected = await store.bool("T", key, default: fallback)
                XCTAssertEqual(snapshot.bool("T", key, default: fallback), expected,
                               "bool \(key) default \(fallback)")
            }
        }
        for key in ["number", "notanumber", "absent"] {
            let expected = await store.int("T", key, default: 7)
            XCTAssertEqual(snapshot.int("T", key, default: 7), expected, "int \(key)")
        }
        for key in ["real", "number", "notanumber", "absent"] {
            let expected = await store.double("T", key, default: 1.5)
            XCTAssertEqual(snapshot.double("T", key, default: 1.5), expected, "double \(key)")
        }
        let expectedString = await store.string("T", "absent", default: "fallback")
        XCTAssertEqual(snapshot.string("T", "absent", default: "fallback"), expectedString)
    }

    func testUndecodableBytesReadAsDefaultsRatherThanThrowing() throws {
        try Data([0xff, 0xfe, 0x00, 0x01]).write(to: url)
        XCTAssertEqual(ConfigSnapshot(url: url).string("Colors", "Theme", default: "system"), "system")
    }
}
