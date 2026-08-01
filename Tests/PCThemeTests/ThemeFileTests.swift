// SPDX-License-Identifier: Apache-2.0
// ThemeFileTests.swift — the user-theme format (F-337).
//
// This parser is the one part of the theme system that reads input nobody reviewed, so the tests
// lean on the failure modes rather than the happy path: a typo must cost the user one colour and
// a log line, never the whole theme, and never a crash on startup. `parse` is pure, so all of
// that is testable without touching a filesystem; only the directory-scan tests use a temp dir.

import AppKit
import XCTest

final class ThemeFileTests: XCTestCase {
    private func rgba(_ c: NSColor) -> String {
        let s = c.usingColorSpace(.sRGB) ?? c
        return String(format: "%02x%02x%02x@%.3f", Int((s.redComponent * 255).rounded()),
                      Int((s.greenComponent * 255).rounded()), Int((s.blueComponent * 255).rounded()),
                      s.alphaComponent)
    }

    override func tearDown() {
        Theme.userPalettes = []   // static state; a leak here would corrupt unrelated tests
        super.tearDown()
    }

    // MARK: - The happy path

    func testFullThemeIsParsed() {
        let result = ThemeFile.parse("""
            [Theme]
            Name = Midnight
            Base = dark

            [Colors]
            ListBackground = #101020
            ListText = #C0C0D0
            """, id: "midnight")
        guard let p = result.palette else { return XCTFail("not parsed: \(result.warnings)") }
        XCTAssertEqual(p.id, "midnight")
        XCTAssertEqual(p.name, "Midnight")
        XCTAssertTrue(p.isDark)
        XCTAssertEqual(rgba(p.colors.listBackground), "101020@1.000")
        XCTAssertEqual(rgba(p.colors.listText), "c0c0d0@1.000")
        XCTAssertTrue(result.warnings.isEmpty, "unexpected warnings: \(result.warnings)")
    }

    /// The whole point of `Base`: name the two colours you care about, inherit 27.
    func testUnlistedColorsAreInheritedFromTheBase() {
        let dark = ThemeFile.parse("[Theme]\nBase = dark\n[Colors]\nListText = #FF0000", id: "d").palette
        let light = ThemeFile.parse("[Theme]\nBase = light\n[Colors]\nListText = #FF0000", id: "l").palette
        XCTAssertEqual(rgba(dark!.colors.listBackground), rgba(Theme.dark.listBackground))
        XCTAssertEqual(rgba(light!.colors.listBackground), rgba(Theme.light.listBackground))
        XCTAssertFalse(light!.isDark)
        // …and the overridden one really did change, in both.
        XCTAssertEqual(rgba(dark!.colors.listText), "ff0000@1.000")
        XCTAssertEqual(rgba(light!.colors.listText), "ff0000@1.000")
    }

    func testColorKeysAreCaseInsensitiveAndWhitespaceTolerant() {
        let result = ThemeFile.parse("""
            [colors]
               listbackground   =    #010203
            LISTTEXT=#040506
            """, id: "x")
        guard let p = result.palette else { return XCTFail("not parsed: \(result.warnings)") }
        XCTAssertEqual(rgba(p.colors.listBackground), "010203@1.000")
        XCTAssertEqual(rgba(p.colors.listText), "040506@1.000")
        XCTAssertTrue(result.warnings.isEmpty, "unexpected warnings: \(result.warnings)")
    }

    func testEveryColorNameInTheExampleIsAccepted() {
        // The shipped example doubles as the reference list of keys. If a key in it were wrong,
        // users would copy the mistake — so parse the example itself and require zero warnings.
        let result = ThemeFile.parse(ThemeFile.exampleFileContents(), id: "example")
        XCTAssertTrue(result.warnings.isEmpty, "the shipped example is not clean: \(result.warnings)")
        guard let p = result.palette else { return XCTFail("the shipped example does not parse") }
        // It reproduces the built-in Norton palette, so it must render as that palette.
        XCTAssertEqual(rgba(p.colors.listBackground), rgba(Theme.norton.listBackground))
        XCTAssertEqual(rgba(p.colors.activeCursorFrame), rgba(Theme.norton.activeCursorFrame))
        XCTAssertEqual(rgba(p.colors.driveBarHighlightText), rgba(Theme.norton.driveBarHighlightText))
    }

    /// Guards the two lists against drifting apart: the example is the documentation, so a colour
    /// that exists but is not in it is a colour users cannot discover.
    func testExampleCoversEveryColor() {
        let example = ThemeFile.exampleFileContents().lowercased()
        let declared = Mirror(reflecting: Theme.light).children.compactMap(\.label)
        let missing = declared.filter { !example.contains($0.lowercased() + " ") }
        XCTAssertTrue(missing.isEmpty,
                      "colours missing from the example theme file: " + missing.joined(separator: ", "))
    }

    // MARK: - Comments, blank lines, junk

    func testCommentsAndBlankLinesAreIgnored() {
        let result = ThemeFile.parse("""
            ; a comment
            # another one

            [Colors]
            ListText = #FF0000   ; trailing comment
            """, id: "x")
        guard let p = result.palette else { return XCTFail("not parsed: \(result.warnings)") }
        XCTAssertEqual(rgba(p.colors.listText), "ff0000@1.000")
        XCTAssertTrue(result.warnings.isEmpty, "unexpected warnings: \(result.warnings)")
    }

    /// `#` starts a comment at the start of a line but must not inside a value, or every single
    /// `#RRGGBB` would be swallowed. This is the bug that comment handling invites.
    func testHashInsideAValueIsNotTreatedAsAComment() {
        let p = ThemeFile.parse("[Colors]\nListText = #ABCDEF", id: "x").palette
        XCTAssertEqual(rgba(p!.colors.listText), "abcdef@1.000")
    }

    func testColorsAreAcceptedWithOrWithoutTheHash() {
        XCTAssertEqual(rgba(ThemeFile.parse("[Colors]\nListText = 00FF00", id: "x").palette!.colors.listText),
                       "00ff00@1.000")
    }

    // MARK: - Malformed input

    /// One bad line costs one colour. Everything else in the file still loads — a theme is not
    /// all-or-nothing, because a single typo destroying someone's whole theme is worse than a
    /// theme that is 95% right and says so in the log.
    func testABadLineDoesNotCostTheWholeTheme() {
        let result = ThemeFile.parse("""
            [Colors]
            ListText = #FF0000
            ListBackground = octarine
            NoSuchColour = #00FF00
            this line has no equals sign
            """, id: "x")
        guard let p = result.palette else { return XCTFail("a single bad line dropped the theme") }
        XCTAssertEqual(rgba(p.colors.listText), "ff0000@1.000", "the good colour must survive")
        XCTAssertEqual(rgba(p.colors.listBackground), rgba(Theme.dark.listBackground),
                       "the unparsable colour must fall back to the base")
        XCTAssertEqual(result.warnings.count, 3, "each bad line must be reported: \(result.warnings)")
        // The messages have to name the line and the key, or they are useless for fixing the file.
        XCTAssertTrue(result.warnings.contains { $0.contains("line 3") && $0.contains("octarine") },
                      "warnings: \(result.warnings)")
        XCTAssertTrue(result.warnings.contains { $0.contains("line 4") && $0.contains("NoSuchColour") },
                      "warnings: \(result.warnings)")
        XCTAssertTrue(result.warnings.contains { $0.contains("line 5") }, "warnings: \(result.warnings)")
    }

    /// When the key *and* the value are both wrong — a line copied from another app's theme — the
    /// message must name the key, because that is the cause; the bad value is just the symptom.
    func testAnUnknownKeyIsReportedEvenWhenItsValueIsAlsoInvalid() {
        let result = ThemeFile.parse("[Colors]\nListText = #FF0000\nBackgroundColour = rebeccapurple", id: "x")
        XCTAssertNotNil(result.palette)
        XCTAssertEqual(result.warnings.count, 1, "warnings: \(result.warnings)")
        XCTAssertTrue(result.warnings[0].contains("unknown colour") && result.warnings[0].contains("BackgroundColour"),
                      "expected the key to be named, got: \(result.warnings[0])")
    }

    func testAFileWithNoUsableColorIsRejected() {
        for text in ["", "[Theme]\nName = Empty", "[Colors]\n", "nonsense", "[Colors]\nBogus = #FF0000"] {
            let result = ThemeFile.parse(text, id: "x")
            XCTAssertNil(result.palette, "\(text.debugDescription) should not produce a palette")
            XCTAssertFalse(result.warnings.isEmpty, "a rejected file must say why")
        }
    }

    func testMissingNameFallsBackToTheId() {
        XCTAssertEqual(ThemeFile.parse("[Colors]\nListText = #FF0000", id: "my-theme").palette?.name, "my-theme")
    }

    func testAnInvalidBaseWarnsAndDefaultsToDark() {
        let result = ThemeFile.parse("[Theme]\nBase = beige\n[Colors]\nListText = #FF0000", id: "x")
        XCTAssertTrue(result.palette!.isDark)
        XCTAssertTrue(result.warnings.contains { $0.contains("Base") }, "warnings: \(result.warnings)")
    }

    func testUnknownSectionsAndKeysAreReportedNotFatal() {
        let result = ThemeFile.parse("""
            [Theme]
            Author = someone
            [Fonts]
            Size = 13
            [Colors]
            ListText = #FF0000
            """, id: "x")
        XCTAssertNotNil(result.palette)
        XCTAssertEqual(result.warnings.count, 2, "warnings: \(result.warnings)")
    }

    /// A key before any section is a common mistake (forgetting `[Colors]`). It must not be
    /// silently applied, or the file would half-work in a way that is hard to explain.
    func testKeysBeforeAnySectionAreIgnoredWithAWarning() {
        let result = ThemeFile.parse("ListText = #FF0000", id: "x")
        XCTAssertNil(result.palette)
        XCTAssertTrue(result.warnings.contains { $0.contains("[section]") }, "warnings: \(result.warnings)")
    }

    /// CRLF, because a theme file shared over Windows or pasted from a web page is normal.
    func testWindowsLineEndingsWork() {
        let p = ThemeFile.parse("[Colors]\r\nListText = #FF0000\r\n", id: "x").palette
        XCTAssertEqual(rgba(p!.colors.listText), "ff0000@1.000")
    }

    // MARK: - Directory loading

    private func withTempDir(_ body: (URL) throws -> Void) rethrows {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-themes-\(ProcessInfo.processInfo.globallyUniqueString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir)
    }

    private func write(_ text: String, _ name: String, in dir: URL) {
        try? text.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    /// The normal case for almost every user: no themes folder at all. Must be silent, not an error.
    func testAMissingDirectoryIsNotAnError() {
        let result = ThemeFile.loadPalettes(from: URL(fileURLWithPath: "/nonexistent/pc/themes"))
        XCTAssertTrue(result.palettes.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty, "a missing folder must not warn: \(result.warnings)")
    }

    /// The counterpart to the test above: a folder that *is* there but cannot be listed must say
    /// so. Collapsing both cases into a silent empty result made a real failure look like an
    /// empty folder, which is how a broken load went unnoticed during development.
    func testAnUnreadableThemesPathIsReported() {
        withTempDir { parent in
            // A regular file where the folder should be: fileExists is true, listing it throws.
            let notADirectory = parent.appendingPathComponent("themes")
            try? "not a directory".write(to: notADirectory, atomically: true, encoding: .utf8)
            let result = ThemeFile.loadPalettes(from: notADirectory)
            XCTAssertTrue(result.palettes.isEmpty)
            XCTAssertEqual(result.warnings.count, 1, "warnings: \(result.warnings)")
            XCTAssertTrue(result.warnings[0].contains("could not be read"), "warnings: \(result.warnings)")
        }
    }

    func testIdComesFromTheFilenameAndNonIniFilesAreSkipped() {
        withTempDir { dir in
            write("[Colors]\nListText = #FF0000", "twilight.ini", in: dir)
            write("[Colors]\nListText = #00FF00", "notes.txt", in: dir)
            write("[Colors]\nListText = #0000FF", "UPPER.INI", in: dir)
            let result = ThemeFile.loadPalettes(from: dir)
            XCTAssertEqual(Set(result.palettes.map(\.id)), ["twilight", "UPPER"],
                           "only .ini files, id = filename stem")
        }
    }

    /// A user file must not be able to redefine a shipped palette: `palette(id:)` takes the first
    /// match, so it would silently depend on ordering, and the golden tests would stop describing
    /// what the app actually renders.
    func testReservedIdsAreRejected() {
        withTempDir { dir in
            // Every shipped id, derived rather than listed: a palette added later is covered
            // automatically instead of quietly slipping past this test.
            let reserved = (Theme.reservedPaletteIds).map { "\($0).ini" }
            for name in reserved { write("[Colors]\nListText = #FF0000", name, in: dir) }
            let result = ThemeFile.loadPalettes(from: dir)
            XCTAssertTrue(result.palettes.isEmpty, "loaded: \(result.palettes.map(\.id))")
            XCTAssertEqual(result.warnings.count, reserved.count, "each must be reported: \(result.warnings)")
            // Still resolves to the shipped palette, which is the point.
            XCTAssertEqual(rgba(Theme.resolve(themeId: "norton", isDark: true).colors.listBackground),
                           "0000aa@1.000")
        }
    }

    /// Separate from the test above because `dark.ini` and `Dark.ini` are the *same file* on a
    /// case-insensitive volume, which is the macOS default — writing both proves nothing.
    func testReservedIdMatchingIgnoresFilenameCase() {
        withTempDir { dir in
            write("[Colors]\nListText = #FF0000", "Dark.ini", in: dir)
            let result = ThemeFile.loadPalettes(from: dir)
            XCTAssertTrue(result.palettes.isEmpty, "\"Dark\" must be rejected just like \"dark\"")
            XCTAssertEqual(result.warnings.count, 1, "warnings: \(result.warnings)")
        }
    }

    func testPalettesAreSortedByDisplayName() {
        withTempDir { dir in
            write("[Theme]\nName = Zulu\n[Colors]\nListText = #FF0000", "a.ini", in: dir)
            write("[Theme]\nName = alpha\n[Colors]\nListText = #FF0000", "z.ini", in: dir)
            XCTAssertEqual(ThemeFile.loadPalettes(from: dir).palettes.map(\.name), ["alpha", "Zulu"],
                           "sorted case-insensitively by name, not by filename")
        }
    }

    func testBrokenFilesDoNotBlockGoodOnes() {
        withTempDir { dir in
            write("this is not a theme at all", "broken.ini", in: dir)
            write("[Colors]\nListText = #FF0000", "good.ini", in: dir)
            let result = ThemeFile.loadPalettes(from: dir)
            XCTAssertEqual(result.palettes.map(\.id), ["good"])
            XCTAssertTrue(result.warnings.contains { $0.hasPrefix("broken.ini:") },
                          "a warning must name the file it came from: \(result.warnings)")
        }
    }

    func testUserPalettesAppearAfterBuiltInsAndResolve() {
        withTempDir { dir in
            write("[Theme]\nName = Mine\n[Colors]\nListBackground = #123456", "mine.ini", in: dir)
            Theme.userPalettes = ThemeFile.loadPalettes(from: dir).palettes
            XCTAssertEqual(Theme.palettes.map(\.id).prefix(Theme.builtInPalettes.count).map { $0 },
                           Theme.builtInPalettes.map(\.id), "built-ins must stay first")
            XCTAssertEqual(rgba(Theme.resolve(themeId: "mine", isDark: false).colors.listBackground),
                           "123456@1.000")
            // And removing the file falls the app back to the default, rather than to nothing.
            Theme.userPalettes = []
            XCTAssertEqual(rgba(Theme.resolve(themeId: "mine", isDark: false).colors.listBackground),
                           rgba(Theme.light.listBackground))
        }
    }

    // MARK: - prepareDirectory

    func testPrepareDirectoryCreatesTheFolderAndAWorkingExample() throws {
        try withTempDir { parent in
            let dir = parent.appendingPathComponent("themes")
            _ = try ThemeFile.prepareDirectory(dir)
            let example = dir.appendingPathComponent(ThemeFile.exampleFileName)
            XCTAssertTrue(FileManager.default.fileExists(atPath: example.path))
            // It must load as a real theme, not just exist — an example that does not work is a
            // worse starting point than none.
            let loaded = ThemeFile.loadPalettes(from: dir)
            XCTAssertEqual(loaded.palettes.count, 1, "warnings: \(loaded.warnings)")
            XCTAssertTrue(loaded.warnings.isEmpty, "warnings: \(loaded.warnings)")
        }
    }

    /// Called every time the user opens the folder, so it must not overwrite their work or pile
    /// up copies of the example.
    func testPrepareDirectoryIsIdempotentAndNeverOverwritesUserFiles() throws {
        try withTempDir { parent in
            let dir = parent.appendingPathComponent("themes")
            _ = try ThemeFile.prepareDirectory(dir)
            let example = dir.appendingPathComponent(ThemeFile.exampleFileName)
            try "[Colors]\nListText = #FF0000\n".write(to: example, atomically: true, encoding: .utf8)
            _ = try ThemeFile.prepareDirectory(dir)
            XCTAssertEqual(try String(contentsOf: example, encoding: .utf8), "[Colors]\nListText = #FF0000\n",
                           "an edited example must not be restored from under the user")
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).count, 1)
        }
    }

    /// Once the user has their own theme, the example is not re-created — the folder is theirs.
    func testPrepareDirectoryDoesNotAddAnExampleNextToExistingThemes() throws {
        try withTempDir { parent in
            let dir = parent.appendingPathComponent("themes")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try "[Colors]\nListText = #FF0000".write(to: dir.appendingPathComponent("mine.ini"),
                                                    atomically: true, encoding: .utf8)
            _ = try ThemeFile.prepareDirectory(dir)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["mine.ini"])
        }
    }

    // MARK: - setColor

    func testSetColorRejectsUnknownNamesAndAcceptsEveryDeclaredOne() {
        var c = Theme.light
        XCTAssertFalse(c.setColor(named: "notAColour", to: .red))
        XCTAssertFalse(c.setColor(named: "", to: .red))
        // Every stored property must be reachable by name, or a theme file cannot set it.
        for name in Mirror(reflecting: Theme.light).children.compactMap(\.label) {
            XCTAssertTrue(c.setColor(named: name, to: .red), "\(name) is not settable by name")
        }
    }
}
