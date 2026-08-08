// SPDX-License-Identifier: Apache-2.0
// ParamExpanderQuotingTests.swift - A file name must not become a command (F-252).
//
// The %-parameter tokens of a toolbar button or a user (Start-menu) command are substituted into a line
// that is then handed to `/bin/sh -c`. The values come from the panel — a file name, which is untrusted
// input: it arrives with a download, an extracted archive, a shared volume.
//
// The expander used to wrap a value in *double* quotes, and only when it contained whitespace. So
// `$(id).txt`, `` `id`.txt `` and `a;id;b.txt` — all legal macOS names — went into the line raw, and a
// name containing a double quote broke out of the quoting. Running any user-defined command on such a
// folder executed whatever the name said.
//
// Like the tests beside it, this asks a real shell what a program actually receives, rather than
// comparing strings against an idea of what quoting looks like.

import XCTest
@testable import PCFoundation

final class ParamExpanderQuotingTests: XCTestCase {

    /// Expand a template, run it through `/bin/sh`, and return what the program saw on stdout.
    private func runThroughShell(_ template: String, context: ParamContext) throws -> String {
        let line = ParamExpander.expand(template, context: context)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", line]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    /// Every name here is one macOS will let you create.
    private let hostileNames = [
        "ordinary.txt",
        "two words.txt",
        "he said \"hi\".txt",
        "it's mine.txt",
        "$(id).txt",
        "`id`.txt",
        "a;id;b.txt",
        "a|id.txt",
        "a&&id.txt",
        "back\\slash.txt",
        "$HOME.txt",
        "* everything.txt",
    ]

    func testAFileNameReachesTheProgramExactlyAsItIs() throws {
        for name in hostileNames {
            let context = ParamContext(sourceDir: "/tmp", cursorName: name, selectedNames: [name])
            // `printf %s` rather than echo: no escape interpretation to muddle the comparison.
            let seen = try runThroughShell("printf %%s %N", context: context)
            XCTAssertEqual(seen, name, "the program received something other than the file name")
        }
    }

    func testNoFileNameCanRunACommand() throws {
        for name in hostileNames {
            let context = ParamContext(sourceDir: "/tmp", cursorName: name, selectedNames: [name])
            let seen = try runThroughShell("printf %%s %N", context: context)
            // `id` prints "uid=…"; if any substitution had happened it would be in here.
            XCTAssertFalse(seen.contains("uid="), "\(name) executed a command")
            XCTAssertFalse(seen.contains("/Users/"), "\(name) expanded a variable")
        }
    }

    func testASelectionOfHostileNamesStaysThatManyArguments() throws {
        // %S joins the selection; a name with a space in it must not become two arguments, and one with
        // a semicolon must not become a second command.
        let names = ["one two.txt", "a;id;b.txt", "plain.txt"]
        let context = ParamContext(sourceDir: "/tmp", cursorName: "", selectedNames: names)
        // One line per argument, so the count is the thing being checked. `%%s`, not `%s`: the format
        // string's own `%s` is a token to this expander too (lowercase %s = the selection), so writing
        // it plainly made the template substitute the names into printf's format — my mistake, and
        // exactly what `%%` exists for.
        let seen = try runThroughShell("printf '%%s\\n' %S", context: context)
        XCTAssertEqual(seen.split(separator: "\n").map(String.init), names)
    }

    func testTheDirectoryTokensAreQuotedToo() throws {
        // %P and %T come from the panel path, which contains whatever folder names the user has.
        let context = ParamContext(sourceDir: "/tmp/$(id) dir", cursorName: "x",
                                   targetDir: "/tmp/other's dir")
        XCTAssertEqual(try runThroughShell("printf %%s %P", context: context), "/tmp/$(id) dir")
        XCTAssertEqual(try runThroughShell("printf %%s %T", context: context), "/tmp/other's dir")
    }

    func testAnUnknownTokenIsStillPassedThroughUnchanged() throws {
        // Behaviour that was already there and must survive the quoting change: %x is not a token.
        let context = ParamContext(sourceDir: "/tmp", cursorName: "a.txt")
        XCTAssertEqual(ParamExpander.expand("cmd %x %%", context: context), "cmd %x %")
    }

    // MARK: - The two places whose result is a path, not a shell word

    func testTheWorkingDirectoryIsExpandedWithoutQuotes() {
        // `%P` in the "start path" field becomes the process's working directory. Quoting it names a
        // directory that does not exist — a regression I introduced with the quoting and caught here.
        let context = ParamContext(sourceDir: "/Users/me/My Documents")
        XCTAssertEqual(ParamExpander.expand("%P", context: context, quoting: false),
                       "/Users/me/My Documents")
    }

    func testTheProgramIsExpandedWithoutQuotesSoItsSuffixCanBeTested() {
        // The caller checks whether the expanded program ends in ".app" to decide between `open -a` and
        // running it directly; a trailing quote makes that test false for every bundle.
        let context = ParamContext(cursorName: "Preview.app")
        let program = ParamExpander.expand("%N", context: context, quoting: false)
        XCTAssertEqual(program, "Preview.app")
        XCTAssertTrue(program.hasSuffix(".app"))
    }

    func testQuotingIsStillTheDefault() {
        // So that a caller which forgets the parameter gets the safe behaviour, not the raw one.
        let context = ParamContext(cursorName: "$(id).txt")
        XCTAssertEqual(ParamExpander.expand("%N", context: context), "'$(id).txt'")
    }
}
