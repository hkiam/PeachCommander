// SPDX-License-Identifier: Apache-2.0
// FinderTagWriteTests.swift - Applying a Finder colour label from the panel (F-291).
//
// The reading side of this was always careful: it resolves the colour from the trailing index in the
// `_kMDItemUserTags` xattr, and its own comment says why — "the tag *names* are localized; the colour
// index is not". The writing side did not follow that through. It went via
// `URLResourceValues.tagNames`, which stores a bare name, so the entry landed as "Red\n0" — index 0
// meaning *no colour*. The result: a grey dot in this app's own column, a colourless custom tag in the
// Finder, and on a non-English system a second tag beside the "Rot" that was already there.
//
// The witness is the extended attribute itself, read back with `xattr`, because that is what the Finder
// and Spotlight look at. Asking Foundation what it just wrote would only show the two halves of one API
// agreeing.

import XCTest
import AppKit
import PCVFS
import PCFoundation

final class FinderTagWriteTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-tags-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    @discardableResult
    private func makeFile(_ name: String) throws -> String {
        let path = dir.appendingPathComponent(name).path
        try Data("x".utf8).write(to: URL(fileURLWithPath: path))
        return path
    }

    /// The entries actually stored on the file, read through `xattr` rather than through Foundation.
    private func storedTags(_ path: String) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-px", "com.apple.metadata:_kMDItemUserTags", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }
        let hex = out.filter { $0.isHexDigit }
        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex, let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) {
            bytes.append(UInt8(hex[index..<next], radix: 16) ?? 0)
            index = next
        }
        let plist = try PropertyListSerialization.propertyList(from: Data(bytes), options: [], format: nil)
        return plist as? [String] ?? []
    }

    // MARK: -

    func testAnAppliedLabelCarriesItsColourIndex() throws {
        let path = try makeFile("red.txt")
        FinderTagColor.writeRawTags(["Red\n6"], toPath: path)

        XCTAssertEqual(try storedTags(path), ["Red\n6"], "the colour index is what makes it a *label*")
        XCTAssertEqual(FinderTagColor.tagColorIndices(forPath: path), [6])
        XCTAssertEqual(FinderTagColor.colors(forPath: path), [.systemRed],
                       "index 0 would show the neutral dot — which is what the old writer produced")
    }

    func testALocalizedLabelIsRecognisedByItsIndex() throws {
        // What a file tagged red on a German system actually carries. A name comparison finds nothing
        // here, which is how a second tag ended up beside it.
        let path = try makeFile("rot.txt")
        FinderTagColor.writeRawTags(["Rot\n6"], toPath: path)
        XCTAssertEqual(FinderTagColor.tagColorIndices(forPath: path), [6])
        XCTAssertEqual(FinderTagColor.colors(forPath: path), [.systemRed])
    }

    func testRemovingTheLastTagRemovesTheAttribute() throws {
        // An empty plist array is not the same as no tags: the Finder shows a file with an empty tag
        // attribute differently from one with none, and it lingers in backups and Spotlight.
        let path = try makeFile("cleared.txt")
        FinderTagColor.writeRawTags(["Blue\n4"], toPath: path)
        XCTAssertFalse(FinderTagColor.rawTags(forPath: path).isEmpty)

        FinderTagColor.writeRawTags([], toPath: path)
        XCTAssertTrue(FinderTagColor.rawTags(forPath: path).isEmpty)
        XCTAssertEqual(try storedTags(path), [], "the attribute itself should be gone")
    }

    func testSeveralTagsKeepTheirOrderAndColours() throws {
        let path = try makeFile("many.txt")
        FinderTagColor.writeRawTags(["Rot\n6", "Wichtig", "Blau\n4"], toPath: path)
        XCTAssertEqual(FinderTagColor.tagColorIndices(forPath: path), [6, 0, 4])
        // A named tag with no colour keeps its place and shows the neutral dot — that is a real thing a
        // user creates in the Finder, not a defect.
        XCTAssertEqual(FinderTagColor.colors(forPath: path), [.systemRed, .tertiaryLabelColor, .systemBlue])
    }

    func testTheNameToIndexMapCoversBothLanguagesThisAppWritesIn() {
        for (name, index) in [("red", 6), ("Rot", 6), ("blue", 4), ("Blau", 4),
                              ("green", 2), ("Grün", 2), ("gray", 1), ("Grau", 1),
                              ("yellow", 5), ("Gelb", 5), ("purple", 3), ("Lila", 3), ("orange", 7)] {
            XCTAssertEqual(FinderTagColor.colorIndex(forName: name), index, name)
        }
        XCTAssertNil(FinderTagColor.colorIndex(forName: "Steuer 2026"), "a user's own tag has no index")
    }
}
