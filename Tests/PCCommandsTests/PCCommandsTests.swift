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

    func testCommandIdsAreUnique() async {
        let registry = CommandRegistry()
        await registry.registerDefaultCommands()
        let commands = await registry.getAllCommands()

        // Check for duplicate IDs
        let ids = commands.map { $0.id }
        let uniqueIds = Set(ids)

        XCTAssertEqual(ids.count, uniqueIds.count, "Command IDs must be unique")
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
