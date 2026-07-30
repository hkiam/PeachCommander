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
