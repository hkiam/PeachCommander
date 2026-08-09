// SPDX-License-Identifier: Apache-2.0
// PCCommandsTests - Unit tests for the command registry

import XCTest
import PCCommands

final class PCCommandsTests: XCTestCase {
    func testRegistryRegisterCommand() async {
        let registry = CommandRegistry()

        // Register a new command
        let cmd = PCCommand(
            id: 20001,
            name: "cm_TestCommand",
            category: "Test",
            help: "Test command",
            handler: { _ in }
        )
        await registry.register(cmd)

        let commands = await registry.getAllCommands()
        XCTAssertEqual(commands.count, 1)
    }

    func testRegistryUniqueIdsAndNames() async {
        let registry = CommandRegistry()
        await registry.registerDefaultCommands()
        let all = await registry.getAllCommands()
        XCTAssertFalse(all.isEmpty)
        // register() asserts on duplicates; verify the invariant explicitly too.
        XCTAssertEqual(Set(all.map { $0.id }).count, all.count, "duplicate command ids")
        XCTAssertEqual(Set(all.map { $0.name }).count, all.count, "duplicate command names")
    }

    func testStubCommandsMarkedNotImplemented() async {
        let registry = CommandRegistry()
        await registry.registerDefaultCommands()
        let all = await registry.getAllCommands()
        let byName = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })
        // A placeholder is registered but not implemented…
        XCTAssertEqual(byName["cm_ChangeTransferMode"]?.implemented, false)
        // …while a real command is implemented (incl. cm_FtpConnect, now the FTP
        // manager; cm_TestArchive, the integrity check; and cm_UnpackFiles, now
        // wired to ArchiveExtractor).
        XCTAssertEqual(byName["cm_Copy"]?.implemented, true)
        XCTAssertEqual(byName["cm_SelectAll"]?.implemented, true)
        XCTAssertEqual(byName["cm_FtpConnect"]?.implemented, true)
        XCTAssertEqual(byName["cm_TestArchive"]?.implemented, true)
        XCTAssertEqual(byName["cm_UnpackFiles"]?.implemented, true)
    }

    func testRegistryExecuteByName() async {
        let registry = CommandRegistry()
        let context = CommandContext(activePanel: nil, inactivePanel: nil, windowController: nil)

        // First register default commands
        await registry.registerDefaultCommands()

        // Try to execute a known command
        try? await registry.execute("cm_GoToParent", context: context)
    }

    func testRegistryExecuteUnknownCommand() async {
        let registry = CommandRegistry()
        let context = CommandContext(activePanel: nil, inactivePanel: nil, windowController: nil)

        // Try to execute unknown command
        do {
            try await registry.execute("cm_UnknownCommand", context: context)
            XCTFail("Expected unknown command error")
        } catch {
            XCTAssertTrue(error is CommandError)
        }
    }

    func testCommandNamesAreUnique() async {
        let registry = CommandRegistry()
        await registry.registerDefaultCommands()
        let commands = await registry.getAllCommands()

        // Check for duplicate names
        let names = commands.map { $0.name }
        let uniqueNames = Set(names)

        XCTAssertEqual(names.count, uniqueNames.count, "Command names must be unique")
    }

    func testEveryDefinedCommandSurvivesRegistration() async {
        // This replaces a test that could not fail. It compared the ids coming out of
        // `getAllCommands()` against the set of them — but the registry stores commands in a dictionary
        // keyed by id, so two commands sharing one are already collapsed to a single entry by the time
        // the test looks: `ids.count == Set(ids).count` was true no matter what the source said.
        //
        // Counting instead is a claim that can be wrong: a collision loses a command, and the number
        // drops. `register` does call `assertionFailure` on a duplicate, but that is compiled out of a
        // release build, where the second definition silently replaces the first.
        //
        // The number itself is checked against the source by Tools/check-command-ids.py, which also
        // pins each name to its id — the part of "stable name + numeric id" that matters to a `.bar`
        // file written months ago.
        let registry = CommandRegistry()
        await registry.registerDefaultCommands()
        let commands = await registry.getAllCommands()
        // 136 real commands plus 26 not-yet-implemented placeholders; the split, and that the two
        // blocks of ids do not overlap, is checked by the gate.
        XCTAssertEqual(commands.count, 162,
                       "a command defined in the source did not reach the registry — most likely two "
                       + "of them share an id, and the dictionary kept one")
    }

    func testEveryCommandIsNamedLikeACommand() async {
        // The name is half the interface: a .bar file, a keyboard mapping and the AI's `run_command`
        // all name a command as a string.
        let registry = CommandRegistry()
        await registry.registerDefaultCommands()
        for command in await registry.getAllCommands() {
            XCTAssertTrue(command.name.hasPrefix("cm_"), "\(command.name) is not a cm_ name")
            XCTAssertFalse(command.help.isEmpty, "\(command.name) has no help text to show anywhere")
        }
    }

    func testCommandIdsMatchTC() async {
        let registry = CommandRegistry()
        await registry.registerDefaultCommands()

        // Verify TC-compatible command IDs
        let goParent = await registry.getCommand("cm_GoToParent")
        XCTAssertEqual(goParent?.id, 1)

        let openDir = await registry.getCommand("cm_OpenDirUnderCursor")
        XCTAssertEqual(openDir?.id, 2)

        let switchPanel = await registry.getCommand("cm_SwitchPanel")
        XCTAssertEqual(switchPanel?.id, 3)
    }
}
