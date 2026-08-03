// SPDX-License-Identifier: Apache-2.0
// ShellQuoteTests.swift - The quoting that stands between a file name and a privileged shell.
//
// The editor's elevated save builds `cat 'tmp' > 'target'` and hands it to a shell running as root.
// The target is whatever the user was editing, so its name is untrusted input in the only place in
// this app where a quoting mistake would run as root. Hence a test rather than a careful read.

import XCTest
import AppKit
@testable import PCFoundation

@MainActor
final class ShellQuoteTests: XCTestCase {
    /// Run the quoted string through a real shell and see what a program actually receives.
    private func echoed(_ path: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // `printf %s` rather than echo: no escape interpretation to confuse the comparison.
        process.arguments = ["-c", "printf %s " + PrivilegedRunner.shellQuote(path)]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func testOrdinaryPathSurvives() throws {
        XCTAssertEqual(try echoed("/etc/hosts"), "/etc/hosts")
    }

    func testSpacesAndSpecialCharactersSurviveVerbatim() throws {
        for path in ["/tmp/my file.conf", "/tmp/a;b", "/tmp/a&b", "/tmp/a|b", "/tmp/a$b",
                     "/tmp/a`b", "/tmp/a\\b", "/tmp/a*b", "/tmp/a(b)c", "/tmp/über.conf"] {
            XCTAssertEqual(try echoed(path), path, path)
        }
    }

    func testASingleQuoteInTheNameCannotBreakOut() throws {
        // The one character that could end the quoting and start a new command.
        XCTAssertEqual(try echoed("/tmp/it's here.conf"), "/tmp/it's here.conf")
        XCTAssertEqual(try echoed("/tmp/'; rm -rf /; echo '"), "/tmp/'; rm -rf /; echo '")
    }

    func testAnInjectionAttemptStaysOneArgument() throws {
        // If the quoting failed, the shell would run `id` and the output would contain "uid=".
        let hostile = "/tmp/x$(id)`id`.conf"
        XCTAssertEqual(try echoed(hostile), hostile)
        XCTAssertFalse(try echoed(hostile).contains("uid="))
    }
}
