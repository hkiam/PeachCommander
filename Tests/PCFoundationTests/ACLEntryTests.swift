// SPDX-License-Identifier: Apache-2.0
// ACLEntryTests.swift - parser + round-trip for macOS ACL entries (F-298).

import XCTest
@testable import PCFoundation

final class ACLEntryTests: XCTestCase {
    func testParsesLsOutput() {
        let out = """
        -rw-r--r--@ 1 me  staff  0 Jul 28 00:48 /tmp/acltest.txt
         0: group:everyone deny delete
         1: user:me allow read,write,delete
        """
        let entries = ACLEntry.parse(lsOutput: out)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0], ACLEntry(kind: .group, name: "everyone", action: .deny, permissions: ["delete"]))
        XCTAssertEqual(entries[1], ACLEntry(kind: .user, name: "me", action: .allow,
                                            permissions: ["read", "write", "delete"]))
    }

    func testStatLineIgnored() {
        // A path with no ACL: only the stat line, no entries.
        let out = "-rw-r--r--@ 1 me  staff  0 Jul 28 00:48 /tmp/plain.txt\n"
        XCTAssertTrue(ACLEntry.parse(lsOutput: out).isEmpty)
    }

    func testRuleString() {
        let e = ACLEntry(kind: .user, name: "me", action: .allow, permissions: ["read", "write"])
        XCTAssertEqual(e.ruleString, "user:me allow read,write")
    }

    func testRoundTripThroughRuleString() {
        // ruleString feeds `chmod +a`; the resulting ls line must parse back equal.
        let e = ACLEntry(kind: .group, name: "staff", action: .deny, permissions: ["delete", "append"])
        let synthetic = " 0: \(e.ruleString)"
        XCTAssertEqual(ACLEntry.parse(lsOutput: synthetic), [e])
    }
}
