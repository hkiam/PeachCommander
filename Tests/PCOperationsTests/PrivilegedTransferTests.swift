// SPDX-License-Identifier: Apache-2.0
// PrivilegedTransferTests.swift - Retrying a copy or move as administrator (F-099).
//
// Deleting, chmod and the editor's save already offered this; copy and move did not, which is the case
// a file manager meets most — drop something into /Library and the operation stops with no way forward.
//
// The decision is tested here rather than through the dialog for two reasons. It is a question about
// paths and the file system, not about windows. And the elevated run itself cannot be automated at all:
// `do shell script … with administrator privileges` asks for a password, and nothing in this project
// types one — not even into a disposable VM. What *can* be pinned exactly is which items get offered
// and what command they would produce, which is also where a file name reaches a root shell.

import XCTest
@testable import PCFoundation
@testable import PCOperations

final class PrivilegedTransferTests: XCTestCase {

    private func item(_ src: String, _ dst: String) -> PrivilegedTransfer.Item {
        PrivilegedTransfer.Item(source: src, destination: dst)
    }

    // MARK: - Which items are offered

    func testAnItemThatArrivedIsNotOffered() {
        let items = [item("/src/a.txt", "/dst/a.txt")]
        XCTAssertTrue(PrivilegedTransfer.missing(items, exists: { _ in true }).isEmpty)
    }

    func testAnItemWithNoDestinationIsOffered() {
        let items = [item("/src/a.txt", "/dst/a.txt")]
        let found = PrivilegedTransfer.missing(items, exists: { $0.hasPrefix("/src") })
        XCTAssertEqual(found.map(\.source), ["/src/a.txt"])
    }

    func testAnItemWhoseSourceIsGoneIsNotOffered() {
        // Nothing left to retry from: a move that half-succeeded, or a file deleted meanwhile.
        let items = [item("/src/a.txt", "/dst/a.txt")]
        XCTAssertTrue(PrivilegedTransfer.missing(items, exists: { _ in false }).isEmpty)
    }

    func testSkippingInTheOverwriteDialogIsNotMistakenForAFailure() {
        // "Skip" leaves a destination that exists — which is why it was asked about in the first place.
        // Reading the operation's error messages instead would have to tell those apart by their text,
        // and those texts are localized.
        let items = [item("/src/a.txt", "/dst/a.txt"), item("/src/b.txt", "/dst/b.txt")]
        let found = PrivilegedTransfer.missing(items, exists: { $0 != "/dst/b.txt" })
        XCTAssertEqual(found.map(\.destination), ["/dst/b.txt"])
    }

    // MARK: - When privileges are the answer

    func testAWritableDestinationIsNotAPermissionProblem() {
        // A copy can also fail because the volume is full. Offering to redo that as root is a way to
        // fill it as root, and it teaches people to answer a password prompt to no purpose.
        XCTAssertFalse(PrivilegedTransfer.wouldPrivilegeHelp(destinationDirectory: "/tmp",
                                                             isWritable: { _ in true }))
    }

    func testAFolderThisUserCannotWriteToIs() {
        XCTAssertTrue(PrivilegedTransfer.wouldPrivilegeHelp(destinationDirectory: "/usr/local",
                                                            isWritable: { _ in false }))
    }

    // MARK: - The command, which runs as root

    func testNothingToRetryProducesNoCommand() {
        XCTAssertNil(PrivilegedTransfer.command(for: [], move: false))
    }

    func testCopyAndMoveUseTheRightTool() throws {
        let one = [item("/src/a.txt", "/dst/a.txt")]
        let copy = try XCTUnwrap(PrivilegedTransfer.command(for: one, move: false))
        XCTAssertTrue(copy.hasPrefix("/bin/cp -Rp "), copy)
        let move = try XCTUnwrap(PrivilegedTransfer.command(for: one, move: true))
        XCTAssertTrue(move.hasPrefix("/bin/mv -f "), move)
    }

    func testSeveralItemsAreOneInvocationSoThePasswordIsAskedOnce() throws {
        let many = [item("/src/a", "/dst/a"), item("/src/b", "/dst/b"), item("/src/c", "/dst/c")]
        let command = try XCTUnwrap(PrivilegedTransfer.command(for: many, move: false))
        XCTAssertEqual(command.components(separatedBy: "; ").count, 3)
        // `;` and not `&&`: one item that cannot be copied must not swallow the two behind it.
        XCTAssertFalse(command.contains("&&"), command)
    }

    func testAFileNameCannotRunACommandAsRoot() throws {
        // This is the one path in the app that runs as root. Every path is a single-quoted shell word;
        // that the quoting survives the AppleScript layer as well is measured in ShellQuoteTests.
        let hostile = [item("/src/$(id).txt", "/dst/`id`.txt"),
                       item("/src/a;id;b.txt", "/dst/it's here.txt")]
        let command = try XCTUnwrap(PrivilegedTransfer.command(for: hostile, move: false))
        XCTAssertTrue(command.contains("'/src/$(id).txt'"), command)
        XCTAssertTrue(command.contains("'/dst/`id`.txt'"), command)
        XCTAssertTrue(command.contains("'/src/a;id;b.txt'"), command)
        // The apostrophe closes, escapes and reopens rather than ending the word.
        XCTAssertTrue(command.contains(#"'/dst/it'\''s here.txt'"#), command)
    }

    func testTheCommandIsWhatAShellActuallyRuns() throws {
        // Not a comparison against an idea of what quoting looks like: the same line, with the tool
        // swapped for `printf`, handed to /bin/sh — and what the program received is the answer.
        let name = "/tmp/$(id) it's here.txt"
        let command = try XCTUnwrap(PrivilegedTransfer.command(for: [item(name, name)], move: false))
        let printfLine = command.replacingOccurrences(of: "/bin/cp -Rp ", with: "printf '%s\\n' ")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", printfLine]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        XCTAssertEqual(out, "\(name)\n\(name)\n")
        XCTAssertFalse(out.contains("uid="), "the name executed a command on its way to root")
    }
}
