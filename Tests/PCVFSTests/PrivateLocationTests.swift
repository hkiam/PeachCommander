// SPDX-License-Identifier: Apache-2.0
// PrivateLocationTests.swift - Telling macOS's privacy gate from an ordinary permission (F-445).
//
// The rule is tested rather than the situation, because the situation cannot be built: the protected
// locations are macOS's own list and no fixture can join it. What can be pinned is the contradiction the
// rule is looking for — EPERM together with mode bits that would have allowed the read — and, just as
// importantly, that an ordinary EACCES refusal is left alone. Calling a plain permission problem a
// privacy problem would send the reader to System Settings for a chmod.

import XCTest
@testable import PCVFS

final class PrivateLocationTests: XCTestCase {

    private let us: uid_t = 501
    private let them: uid_t = 502

    // MARK: - The rule

    func testEaccesIsNeverAPrivacyRefusal() {
        // The mode bits refused, which they are entitled to do; that says nothing about privacy.
        XCTAssertFalse(PrivateLocation.isPrivacyRefusal(eperm: false, mode: 0o755, owner: us, us: us))
        XCTAssertFalse(PrivateLocation.isPrivacyRefusal(eperm: false, mode: 0o000, owner: us, us: us))
    }

    func testEpermOnADirectoryWeMayReadIsTheContradiction() {
        for mode: mode_t in [0o700, 0o750, 0o755, 0o500] {
            XCTAssertTrue(PrivateLocation.isPrivacyRefusal(eperm: true, mode: mode, owner: us, us: us),
                          "mode \(String(mode, radix: 8)) allows the owner to list it")
        }
    }

    func testEpermOnADirectoryTheModeAlreadyRefusesIsNot() {
        // No read bit, or no traverse bit: a directory needs both to be listed, so the refusal is the
        // mode's own and there is no contradiction to report.
        for mode: mode_t in [0o000, 0o300, 0o600, 0o100, 0o400] {
            XCTAssertFalse(PrivateLocation.isPrivacyRefusal(eperm: true, mode: mode, owner: us, us: us),
                           "mode \(String(mode, radix: 8)) does not allow the owner to list it")
        }
    }

    func testSomebodyElsesDirectoryIsJudgedByTheOtherBits() {
        XCTAssertTrue(PrivateLocation.isPrivacyRefusal(eperm: true, mode: 0o755, owner: them, us: us))
        // 0o750 grants the group, not the world — and the group is not what this checks.
        XCTAssertFalse(PrivateLocation.isPrivacyRefusal(eperm: true, mode: 0o750, owner: them, us: us))
        XCTAssertFalse(PrivateLocation.isPrivacyRefusal(eperm: true, mode: 0o700, owner: them, us: us))
    }

    // MARK: - The error the file system actually throws

    private var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-priv-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func testTheErrorOverloadReadsTheDistinctionVFSErrorAlreadyCarries() {
        // `fromErrno` records `.notPermitted` for EPERM and `.modeBits` for EACCES, which is the only
        // place the two are still told apart by the time the panel sees the failure.
        XCTAssertTrue(PrivateLocation.isPrivacyRefusal(VFSError.permissionDenied(.notPermitted),
                                                       path: dir.path))
        XCTAssertFalse(PrivateLocation.isPrivacyRefusal(VFSError.permissionDenied(.modeBits),
                                                        path: dir.path))
    }

    func testEveryOtherFailureIsNotAPrivacyRefusal() {
        for error: VFSError in [.notFound(dir.path), .connectionLost(retryable: true), .unsupported,
                               .cancelled, .underlying(code: 5, message: "I/O")] {
            XCTAssertFalse(PrivateLocation.isPrivacyRefusal(error, path: dir.path), "\(error)")
        }
    }

    func testAPathThatIsNotThereIsNotAPrivacyRefusal() {
        // `stat` fails, and a guess in either direction would be worse than saying no: the ordinary
        // message still names the folder.
        XCTAssertFalse(PrivateLocation.isPrivacyRefusal(VFSError.permissionDenied(.notPermitted),
                                                        path: dir.appendingPathComponent("gone").path))
    }
}
