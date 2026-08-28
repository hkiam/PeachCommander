// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class ButtonBarTests: XCTestCase {

    /// A representative 3-button TC .bar sample. Button 2's menu deliberately
    /// contains spaces to exercise value preservation.
    private let sampleBar = """
    [Buttonbar]
    Buttoncount=3
    button1=wcmicons.dll,5
    cmd1=cm_Copy
    param1=
    path1=
    menu1=Copy files
    iconic1=1
    button2=/Applications/Preview.app
    cmd2=/Applications/Preview.app
    param2=-a
    path2=/Users/test
    menu2=Open in Preview App
    iconic2=0
    button3=wcmicons.dll,12
    cmd3=cm_RenameOnly
    param3=
    path3=
    menu3=Rename
    iconic3=1
    """

    // MARK: - Basic parsing

    func testParseThreeButtonSample() {
        let bar = ButtonBar(parsing: sampleBar)
        XCTAssertEqual(bar.buttons.count, 3)

        let b1 = bar.buttons[0]
        XCTAssertEqual(b1.icon, "wcmicons.dll,5")
        XCTAssertEqual(b1.cmd, "cm_Copy")
        XCTAssertEqual(b1.param, "")
        XCTAssertEqual(b1.path, "")
        XCTAssertEqual(b1.menu, "Copy files")
        XCTAssertTrue(b1.iconic)

        let b2 = bar.buttons[1]
        XCTAssertEqual(b2.icon, "/Applications/Preview.app")
        XCTAssertEqual(b2.cmd, "/Applications/Preview.app")
        XCTAssertEqual(b2.param, "-a")
        XCTAssertEqual(b2.path, "/Users/test")
        XCTAssertEqual(b2.menu, "Open in Preview App")
        XCTAssertFalse(b2.iconic)

        let b3 = bar.buttons[2]
        XCTAssertEqual(b3.icon, "wcmicons.dll,12")
        XCTAssertEqual(b3.cmd, "cm_RenameOnly")
        XCTAssertEqual(b3.menu, "Rename")
        XCTAssertTrue(b3.iconic)
    }

    func testEmptyTextGivesEmptyBar() {
        let bar = ButtonBar(parsing: "")
        XCTAssertTrue(bar.buttons.isEmpty)
    }

    func testMissingSectionGivesEmptyBar() {
        let text = """
        [SomeOtherSection]
        Foo=Bar
        """
        let bar = ButtonBar(parsing: text)
        XCTAssertTrue(bar.buttons.isEmpty)
    }

    func testButtoncountLargerThanPresentKeysFillsDefaults() {
        // Buttoncount says 2 but only button1's keys are actually present;
        // button 2 must be filled in with all-empty defaults.
        let text = """
        [Buttonbar]
        Buttoncount=2
        button1=wcmicons.dll,5
        cmd1=cm_Copy
        menu1=Copy
        iconic1=1
        """
        let bar = ButtonBar(parsing: text)
        XCTAssertEqual(bar.buttons.count, 2)
        XCTAssertEqual(bar.buttons[0].cmd, "cm_Copy")

        let missing = bar.buttons[1]
        XCTAssertEqual(missing.icon, "")
        XCTAssertEqual(missing.cmd, "")
        XCTAssertEqual(missing.param, "")
        XCTAssertEqual(missing.path, "")
        XCTAssertEqual(missing.menu, "")
        XCTAssertFalse(missing.iconic)
        XCTAssertTrue(missing.isSeparator)
    }

    func testButtoncountSmallerThanPresentKeysIgnoresExtras() {
        // Buttoncount=1 means only button1 should be read, even though
        // button2's keys are present in the text.
        let text = """
        [Buttonbar]
        Buttoncount=1
        button1=wcmicons.dll,5
        cmd1=cm_Copy
        button2=/bin/ls
        cmd2=/bin/ls
        """
        let bar = ButtonBar(parsing: text)
        XCTAssertEqual(bar.buttons.count, 1)
        XCTAssertEqual(bar.buttons[0].cmd, "cm_Copy")
    }

    // MARK: - Separators

    func testSeparatorButtonHasEmptyIconAndCmd() {
        let text = """
        [Buttonbar]
        Buttoncount=1
        button1=
        cmd1=
        param1=
        path1=
        menu1=
        iconic1=0
        """
        let bar = ButtonBar(parsing: text)
        XCTAssertEqual(bar.buttons.count, 1)
        XCTAssertTrue(bar.buttons[0].isSeparator)
    }

    func testNonSeparatorButtonIsNotSeparator() {
        let bar = ButtonBar(parsing: sampleBar)
        XCTAssertFalse(bar.buttons[0].isSeparator)
    }

    // MARK: - iconic parsing

    func testIconicOneParsesTrue() {
        let text = """
        [Buttonbar]
        Buttoncount=1
        cmd1=cm_Copy
        iconic1=1
        """
        XCTAssertTrue(ButtonBar(parsing: text).buttons[0].iconic)
    }

    func testIconicZeroParsesFalse() {
        let text = """
        [Buttonbar]
        Buttoncount=1
        cmd1=cm_Copy
        iconic1=0
        """
        XCTAssertFalse(ButtonBar(parsing: text).buttons[0].iconic)
    }

    func testIconicAbsentDefaultsFalse() {
        let text = """
        [Buttonbar]
        Buttoncount=1
        cmd1=cm_Copy
        """
        XCTAssertFalse(ButtonBar(parsing: text).buttons[0].iconic)
    }

    // MARK: - Value fidelity & case-insensitivity

    func testValueWithSpacesPreserved() {
        let bar = ButtonBar(parsing: sampleBar)
        XCTAssertEqual(bar.buttons[1].menu, "Open in Preview App")
    }

    func testCaseInsensitiveSectionAndKeys() {
        let text = """
        [BUTTONBAR]
        BUTTONCOUNT=1
        BUTTON1=wcmicons.dll,5
        CMD1=cm_Copy
        MENU1=Copy files
        ICONIC1=1
        """
        let bar = ButtonBar(parsing: text)
        XCTAssertEqual(bar.buttons.count, 1)
        XCTAssertEqual(bar.buttons[0].icon, "wcmicons.dll,5")
        XCTAssertEqual(bar.buttons[0].cmd, "cm_Copy")
        XCTAssertEqual(bar.buttons[0].menu, "Copy files")
        XCTAssertTrue(bar.buttons[0].iconic)
    }

    // MARK: - Serialization

    func testSerializeWritesButtoncountAndIconicLines() {
        let bar = ButtonBar(buttons: [
            BarButton(icon: "wcmicons.dll,5", cmd: "cm_Copy", menu: "Copy files", iconic: true),
            BarButton(), // separator
        ])
        let text = bar.serialize()
        XCTAssertTrue(text.contains("[Buttonbar]"))
        XCTAssertTrue(text.contains("Buttoncount=2"))
        XCTAssertTrue(text.contains("iconic1=1"))
        XCTAssertTrue(text.contains("iconic2=0"))
        // Empty fields must not produce key lines.
        XCTAssertFalse(text.contains("param1="))
        XCTAssertFalse(text.contains("button2="))
        XCTAssertFalse(text.contains("cmd2="))
    }

    // MARK: - Round trips

    func testRoundTripThreeButtonSample() {
        let original = ButtonBar(parsing: sampleBar)
        let reparsed = ButtonBar(parsing: original.serialize())
        XCTAssertEqual(reparsed, original)
    }

    func testRoundTripProgrammaticBarWithSeparator() {
        let original = ButtonBar(buttons: [
            BarButton(icon: "wcmicons.dll,5", cmd: "cm_Copy", param: "", path: "", menu: "Copy files", iconic: true),
            BarButton(), // separator in the middle
            BarButton(icon: "/Applications/Preview.app", cmd: "/Applications/Preview.app",
                      param: "-a", path: "/Users/test", menu: "Open Preview", iconic: false),
        ])
        let serialized = original.serialize()
        let reparsed = ButtonBar(parsing: serialized)
        XCTAssertEqual(reparsed, original)
        XCTAssertTrue(reparsed.buttons[1].isSeparator)
    }

    func testRoundTripEmptyBar() {
        let original = ButtonBar()
        let reparsed = ButtonBar(parsing: original.serialize())
        XCTAssertEqual(reparsed, original)
        XCTAssertTrue(reparsed.buttons.isEmpty)
    }
}

// MARK: - Buttons created by dropping a program on the bar (F-342)
//
// The decision "what does this dropped path become?" is the whole feature: get it wrong and you
// either create a button that cannot run, or refuse a tool the user legitimately dropped. It lives
// on MainWindowController (AppKit), so the rule is mirrored here against the same criteria — an
// app bundle, an executable file, or a directory — over real files in a temp tree.

final class ButtonBarDropTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-bardrop-\(ProcessInfo.processInfo.globallyUniqueString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func file(_ name: String, executable: Bool) throws -> String {
        let url = dir.appendingPathComponent(name)
        try "#!/bin/sh\necho hi\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: executable ? 0o755 : 0o644],
                                              ofItemAtPath: url.path)
        return url.path
    }

    /// A script has to carry an execute bit to be worth a button — a plain .txt dropped by accident
    /// would otherwise become a button that fails the moment it is clicked.
    func testOnlyExecutableFilesQualify() throws {
        let runnable = try file("tool.sh", executable: true)
        let plain = try file("notes.txt", executable: false)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: runnable))
        XCTAssertFalse(FileManager.default.isExecutableFile(atPath: plain))
    }

    /// An .app is a *directory*, so the naive "is it a folder?" test would turn every app into a
    /// navigation button instead of something you can launch.
    func testAppBundleIsTreatedAsAProgramNotAFolder() throws {
        let app = dir.appendingPathComponent("Demo.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: app.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue, "an app bundle really is a directory — hence the extra check")
        XCTAssertEqual((app.path as NSString).pathExtension.lowercased(), "app")
    }

    /// Serialising and re-parsing has to survive a button whose command is a path with spaces and
    /// whose parameter is `%S`, because that is exactly what a drop produces.
    func testDroppedButtonSurvivesSerialisation() throws {
        let button = BarButton(icon: "/Applications/My Tool.app", cmd: "/Applications/My Tool.app",
                               param: "%S", path: "", menu: "My Tool", iconic: true)
        let restored = ButtonBar(parsing: ButtonBar(buttons: [button]).serialize())
        XCTAssertEqual(restored.buttons.count, 1)
        XCTAssertEqual(restored.buttons.first?.cmd, "/Applications/My Tool.app")
        XCTAssertEqual(restored.buttons.first?.param, "%S")
        XCTAssertEqual(restored.buttons.first?.menu, "My Tool")
    }

    /// Insertion has to respect the drop position, and clamp rather than trap when the index is
    /// past the end — the bar view derives it from a mouse location.
    func testInsertionAtIndexClampsInsteadOfTrapping() {
        var buttons = [BarButton(cmd: "cm_A"), BarButton(cmd: "cm_B")]
        let dropped = BarButton(cmd: "/bin/ls", param: "%S")
        buttons.insert(dropped, at: min(1, buttons.count))
        XCTAssertEqual(buttons.map(\.cmd), ["cm_A", "/bin/ls", "cm_B"])
        buttons.insert(dropped, at: min(99, buttons.count))
        XCTAssertEqual(buttons.last?.cmd, "/bin/ls")
    }
}

/// Taking a macro's buttons back out of the bar (F-478).
///
/// A macro deleted by hand used to leave its button behind, and pressing it did nothing at all. The
/// removal is a filter on `cmd` — kept here rather than in the window, because what has to hold is
/// that the *rest of the bar survives it*: the other buttons, their order, and the file's format.
final class ButtonBarMacroRemovalTests: XCTestCase {

    private func bar() -> ButtonBar {
        ButtonBar(buttons: [
            BarButton(icon: "a", cmd: "cm_Copy", param: "", path: "", menu: "Copy", iconic: false),
            BarButton(icon: "b", cmd: "mc_tidy", param: "", path: "", menu: "Tidy", iconic: false),
            BarButton(icon: "c", cmd: "cm_PackFiles", param: "", path: "", menu: "Pack", iconic: false),
            BarButton(icon: "d", cmd: "mc_tidy", param: "", path: "", menu: "Tidy again", iconic: false),
        ])
    }

    func test_everyButtonForThatMacroGoesAndTheOthersStay() {
        var b = bar()
        b.buttons.removeAll { ["mc_tidy"].contains($0.cmd) }
        XCTAssertEqual(b.buttons.map(\.cmd), ["cm_Copy", "cm_PackFiles"],
                       "both copies of the macro's button go, in one pass, and order is kept")
    }

    /// A macro whose name resembles another's must not be caught: the match is the whole command name.
    func test_aSimilarlyNamedMacroIsNotTouched() {
        var b = ButtonBar(buttons: [
            BarButton(icon: "a", cmd: "mc_tidy", param: "", path: "", menu: "", iconic: false),
            BarButton(icon: "b", cmd: "mc_tidy-2", param: "", path: "", menu: "", iconic: false),
        ])
        b.buttons.removeAll { ["mc_tidy"].contains($0.cmd) }
        XCTAssertEqual(b.buttons.map(\.cmd), ["mc_tidy-2"])
    }

    /// And the bar still round-trips through the Total Commander format afterwards, so a user's own
    /// bar is not rewritten into something else by a macro being deleted.
    func test_theBarStillRoundTripsAfterTheRemoval() {
        var b = bar()
        b.buttons.removeAll { ["mc_tidy"].contains($0.cmd) }
        let reparsed = ButtonBar(parsing: b.serialize())
        XCTAssertEqual(reparsed.buttons.map(\.cmd), ["cm_Copy", "cm_PackFiles"])
        XCTAssertEqual(reparsed.buttons.map(\.menu), ["Copy", "Pack"])
    }
}
