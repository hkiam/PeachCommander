// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class UserCommandsTests: XCTestCase {

    /// A 2-command usercmd.ini sample plus a non-em_ section that must be ignored.
    private let sample = """
    [em_MyBackup]
    cmd=/usr/bin/rsync
    param=-a %P %T
    path=%P
    menu=Backup active panel
    key=C+S+B

    [SomeOtherSection]
    ignored=yes

    [em_OpenTerminal]
    cmd=open
    param=-a Terminal %P
    menu=Open Terminal Here
    """

    // MARK: - Parsing

    func testParseSampleFieldsAndOrder() {
        let commands = UserCommands(parsing: sample)
        XCTAssertEqual(commands.commands.count, 2)

        let first = commands.commands[0]
        XCTAssertEqual(first.name, "em_MyBackup")
        XCTAssertEqual(first.cmd, "/usr/bin/rsync")
        XCTAssertEqual(first.param, "-a %P %T")
        XCTAssertEqual(first.path, "%P")
        XCTAssertEqual(first.menu, "Backup active panel")
        XCTAssertEqual(first.key, "C+S+B")

        let second = commands.commands[1]
        XCTAssertEqual(second.name, "em_OpenTerminal")
        XCTAssertEqual(second.cmd, "open")
        XCTAssertEqual(second.param, "-a Terminal %P")
        XCTAssertEqual(second.path, "")
        XCTAssertEqual(second.menu, "Open Terminal Here")
        XCTAssertEqual(second.key, "")

        // Order must follow declaration order in the file.
        XCTAssertEqual(commands.commands.map { $0.name }, ["em_MyBackup", "em_OpenTerminal"])
    }

    func testNonEmSectionsAreIgnored() {
        let commands = UserCommands(parsing: sample)
        XCTAssertNil(commands.command(named: "SomeOtherSection"))
        XCTAssertFalse(commands.commands.contains { $0.name == "SomeOtherSection" })
    }

    func testEmptyTextYieldsNoCommands() {
        let commands = UserCommands(parsing: "")
        XCTAssertTrue(commands.commands.isEmpty)
    }

    func testCommandWithOnlyCmdDefaultsOtherFieldsToEmpty() {
        let text = """
        [em_Minimal]
        cmd=echo hi
        """
        let commands = UserCommands(parsing: text)
        XCTAssertEqual(commands.commands.count, 1)
        let command = commands.commands[0]
        XCTAssertEqual(command.name, "em_Minimal")
        XCTAssertEqual(command.cmd, "echo hi")
        XCTAssertEqual(command.param, "")
        XCTAssertEqual(command.path, "")
        XCTAssertEqual(command.menu, "")
        XCTAssertEqual(command.key, "")
    }

    func testEmPrefixMatchIsCaseInsensitiveButNameCasingIsPreserved() {
        let text = """
        [EM_weird]
        cmd=true
        """
        let commands = UserCommands(parsing: text)
        XCTAssertEqual(commands.commands.count, 1)
        // Section is recognized as a user command (case-insensitive "em_" match)...
        XCTAssertEqual(commands.commands[0].name, "EM_weird") // ...but original casing is preserved.
    }

    // MARK: - displayTitle

    func testDisplayTitleUsesMenuWhenPresent() {
        let command = UserCommand(name: "em_X", menu: "My Title")
        XCTAssertEqual(command.displayTitle, "My Title")
    }

    func testDisplayTitleFallsBackToNameWhenMenuEmpty() {
        let command = UserCommand(name: "em_NoMenu")
        XCTAssertEqual(command.displayTitle, "em_NoMenu")
    }

    // MARK: - command(named:)

    func testCommandNamedIsCaseInsensitiveHit() {
        let commands = UserCommands(parsing: sample)
        XCTAssertEqual(commands.command(named: "em_mybackup")?.name, "em_MyBackup")
        XCTAssertEqual(commands.command(named: "EM_OPENTERMINAL")?.name, "em_OpenTerminal")
    }

    func testCommandNamedMiss() {
        let commands = UserCommands(parsing: sample)
        XCTAssertNil(commands.command(named: "em_DoesNotExist"))
    }

    // MARK: - Serialization / round-trip

    func testSerializeOmitsEmptyKeysButKeepsOrder() {
        let commands = UserCommands(commands: [
            UserCommand(name: "em_Only", cmd: "true"),
        ])
        let text = commands.serialize()
        XCTAssertEqual(text, "[em_Only]\ncmd=true\n")
    }

    func testSerializeKeyOrderIsCmdParamPathMenuKey() {
        let commands = UserCommands(commands: [
            UserCommand(name: "em_Full", cmd: "c", param: "p", path: "d", menu: "m", key: "k"),
        ])
        let text = commands.serialize()
        XCTAssertEqual(text, "[em_Full]\ncmd=c\nparam=p\npath=d\nmenu=m\nkey=k\n")
    }

    func testRoundTripSample() {
        let parsed = UserCommands(parsing: sample)
        let reparsed = UserCommands(parsing: parsed.serialize())
        XCTAssertEqual(parsed, reparsed)
        XCTAssertEqual(reparsed.commands.map { $0.name }, ["em_MyBackup", "em_OpenTerminal"])
    }

    func testRoundTripProgrammaticallyBuilt() {
        let original = UserCommands(commands: [
            UserCommand(name: "em_First", cmd: "a", menu: "First Command"),
            UserCommand(name: "em_Second", cmd: "b", param: "%P", key: "C+1"),
        ])
        let reloaded = UserCommands(parsing: original.serialize())
        XCTAssertEqual(reloaded, original)
    }

    func testTwoCommandsKeepDeclaredOrderAfterRoundTrip() {
        let original = UserCommands(commands: [
            UserCommand(name: "em_Zeta", cmd: "z"),
            UserCommand(name: "em_Alpha", cmd: "a"),
        ])
        let reloaded = UserCommands(parsing: original.serialize())
        XCTAssertEqual(reloaded.commands.map { $0.name }, ["em_Zeta", "em_Alpha"])
    }
}
