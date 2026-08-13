// SPDX-License-Identifier: Apache-2.0
// FtpConnectionRulesTests.swift - Which settings apply to which protocol, and which
// combinations cannot work.
//
// Each case here is a form the connection dialog used to accept without comment, and whose
// only symptom was a socket error minutes later — or, worse, no symptom at all: a proxy that
// was never contacted, a passive box that the connection overrode anyway.

import XCTest
@testable import PCNet

final class FtpConnectionRulesTests: XCTestCase {

    private func site(_ proto: FtpProtocol, port: Int? = nil, user: String = "u",
                      auth: FtpAuth = .password, passive: Bool = true,
                      proxyHost: String? = nil, proxyKind: ProxyKind = .socks5,
                      proxyUser: String? = nil, host: String = "example.org",
                      keyFile: String? = nil) -> FtpSite {
        FtpSite(name: "s", host: host, port: port, proto: proto, user: user, auth: auth,
                keyFile: keyFile, passive: passive, proxyHost: proxyHost,
                proxyType: proxyKind, proxyUser: proxyUser)
    }

    // MARK: - Port follows the protocol

    func testTheDefaultPortFollowsTheProtocol() {
        // The reported case: switch an ftp site to sftp and 21 stays in the field, so the site
        // dials the FTP port over SSH and fails with a timeout that names nothing.
        XCTAssertEqual(FtpConnectionRules.port(changingTo: .sftp, from: .ftp, current: 21), 22)
        XCTAssertEqual(FtpConnectionRules.port(changingTo: .ftp, from: .sftp, current: 22), 21)
        XCTAssertEqual(FtpConnectionRules.port(changingTo: .ftpsImplicit, from: .ftp, current: 21), 990)
        XCTAssertEqual(FtpConnectionRules.port(changingTo: .ftp, from: .ftpsImplicit, current: 990), 21)
    }

    func testAPortTheUserTypedSurvivesAProtocolChange() {
        // 2121 was a decision. Overwriting it with 22 would be the same defect in the other
        // direction: the form quietly discarding what was typed into it.
        XCTAssertEqual(FtpConnectionRules.port(changingTo: .sftp, from: .ftp, current: 2121), 2121)
    }

    func testAnEmptyOrImpossiblePortBecomesTheNewDefault() {
        XCTAssertEqual(FtpConnectionRules.port(changingTo: .sftp, from: .ftp, current: nil), 22)
        XCTAssertEqual(FtpConnectionRules.port(changingTo: .sftp, from: .ftp, current: 0), 22)
        XCTAssertEqual(FtpConnectionRules.port(changingTo: .ftp, from: .sftp, current: 70000), 21)
    }

    func testExplicitAndImplicitFTPSKeepTheirOwnDefaults() {
        // They are different protocols on different ports, and 21 is explicit FTPS's real default —
        // so moving between the two is a genuine change and not a no-op.
        XCTAssertEqual(FtpConnectionRules.port(changingTo: .ftpsImplicit, from: .ftps, current: 21), 990)
        XCTAssertEqual(FtpConnectionRules.port(changingTo: .ftps, from: .ftpsImplicit, current: 990), 21)
    }

    // MARK: - Which settings mean anything

    func testSFTPHasNoAnonymousLoginAndNoPassiveMode() {
        let s = site(.sftp)
        XCTAssertFalse(FtpConnectionRules.applies(.anonymous, to: s))
        XCTAssertFalse(FtpConnectionRules.applies(.passive, to: s))
        XCTAssertFalse(FtpConnectionRules.applies(.insecureTLS, to: s))
        XCTAssertTrue(FtpConnectionRules.applies(.scp, to: s))
        XCTAssertTrue(FtpConnectionRules.applies(.keyFile, to: s))
    }

    func testSCPAndSelfSignedCertificatesBelongToDifferentProtocols() {
        XCTAssertFalse(FtpConnectionRules.applies(.scp, to: site(.ftp)))
        XCTAssertFalse(FtpConnectionRules.applies(.insecureTLS, to: site(.ftp)))
        XCTAssertTrue(FtpConnectionRules.applies(.insecureTLS, to: site(.ftpsImplicit)))
        XCTAssertTrue(FtpConnectionRules.applies(.insecureTLS, to: site(.ftps)))
    }

    func testOnlyPlainFTPCanBeProxied() {
        // The transport refuses to upgrade a tunnel to TLS, and the SFTP path never reads the
        // proxy fields at all — so on those protocols the fields are decoration.
        XCTAssertTrue(FtpConnectionRules.applies(.proxy, to: site(.ftp)))
        XCTAssertFalse(FtpConnectionRules.applies(.proxy, to: site(.ftps)))
        XCTAssertFalse(FtpConnectionRules.applies(.proxy, to: site(.ftpsImplicit)))
        XCTAssertFalse(FtpConnectionRules.applies(.proxy, to: site(.sftp)))
    }

    func testAProxyLoginNeedsAProxyToLogInTo() {
        XCTAssertFalse(FtpConnectionRules.applies(.proxyLogin, to: site(.ftp)))
        XCTAssertTrue(FtpConnectionRules.applies(.proxyLogin, to: site(.ftp, proxyHost: "socks.local")))
    }

    func testAnAnonymousLoginHasNoUserNameOrPasswordToEnter() {
        let anon = site(.ftp, user: "anonymous", auth: .anonymous)
        XCTAssertFalse(FtpConnectionRules.applies(.user, to: anon))
        XCTAssertFalse(FtpConnectionRules.applies(.password, to: anon))
        XCTAssertTrue(FtpConnectionRules.applies(.user, to: site(.ftp)))
    }

    // MARK: - Settings that used to round-trip and do nothing

    func testTheEncodingChoiceExistsOnlyWhereItIsAChoice() {
        // SFTP mandates UTF-8, so offering latin-1 there would be a setting the connection ignores.
        XCTAssertTrue(FtpConnectionRules.applies(.encoding, to: site(.ftp)))
        XCTAssertTrue(FtpConnectionRules.applies(.encoding, to: site(.ftpsImplicit)))
        XCTAssertFalse(FtpConnectionRules.applies(.encoding, to: site(.sftp)))
    }

    func testTheSiteSaysWhichEncodingItsNamesAreIn() {
        // Unknown values mean UTF-8: it is the default, the modern answer, and the only safe guess
        // for an ini somebody edited by hand.
        XCTAssertEqual(FtpSite(name: "s", host: "h", encoding: "latin-1").textEncoding, .isoLatin1)
        XCTAssertEqual(FtpSite(name: "s", host: "h", encoding: "LATIN-1").textEncoding, .isoLatin1)
        XCTAssertEqual(FtpSite(name: "s", host: "h", encoding: "utf-8").textEncoding, .utf8)
        XCTAssertEqual(FtpSite(name: "s", host: "h", encoding: "klingon").textEncoding, .utf8)
    }

    func testALatin1ListingIsReadableAndStillRoundTrips() {
        // The defect this setting exists for: a latin-1 server's "Größe.txt" decoded as UTF-8 is
        // mojibake or replacement characters, and a name the panel cannot spell is one it cannot
        // open, rename or delete either.
        let bytes = "Größe.txt".data(using: .isoLatin1)!
        XCTAssertEqual(FTPControlConnection.decode(bytes, as: .isoLatin1), "Größe.txt")
        // Asked for UTF-8, those same bytes are not valid UTF-8. Latin-1 is the fallback rather
        // than U+FFFD, because a replacement character destroys the byte it stands for and the
        // name can then never be sent back to the server.
        let viaUTF8 = FTPControlConnection.decode(bytes, as: .utf8)
        XCTAssertFalse(viaUTF8.contains("\u{FFFD}"), "lossy decode: \(viaUTF8)")
        XCTAssertEqual(viaUTF8.data(using: .isoLatin1), bytes, "the name no longer round-trips")
        // And a genuine UTF-8 listing is unaffected.
        XCTAssertEqual(FTPControlConnection.decode(Data("Größe.txt".utf8), as: .utf8), "Größe.txt")
    }

    func testALocalDirIsOfferedForEveryProtocol() {
        // It is a local folder; nothing about the wire protocol makes it more or less meaningful.
        for proto in FtpProtocol.allCases {
            XCTAssertTrue(FtpConnectionRules.applies(.localDir, to: site(proto)))
        }
    }

    // MARK: - SFTP key authentication

    func testAKeyFileIsOfferedOnlyWhereItMeansSomething() {
        XCTAssertTrue(FtpConnectionRules.applies(.keyFile, to: site(.sftp)))
        XCTAssertFalse(FtpConnectionRules.applies(.keyFile, to: site(.ftp)))
        XCTAssertFalse(FtpConnectionRules.applies(.keyFile, to: site(.ftpsImplicit)))
    }

    func testTheSecretFieldStaysUsableForAnEncryptedKey() {
        // It is the key's passphrase there rather than a password, and an encrypted key needs it
        // typed somewhere. Disabling the field — which the rules used to do for `.keyFile` — left
        // an encrypted key unusable unless the ssh-agent happened to be holding it.
        XCTAssertTrue(FtpConnectionRules.applies(.password, to: site(.sftp, auth: .keyFile,
                                                                    keyFile: "/tmp/k")))
        // The agent is the one case that needs no secret from us at all.
        XCTAssertFalse(FtpConnectionRules.applies(.password, to: site(.sftp, auth: .agent)))
    }

    func testAKeyFileThatIsNotThereIsRefusedRatherThanFallenBackFrom() throws {
        // libssh2 skips a key it cannot open and tries ~/.ssh/id_* instead, so a typo surfaces as
        // "authentication failed" against a server the default key may not even be enrolled at.
        let missing = site(.sftp, auth: .keyFile, keyFile: "/nope/id_ed25519")
        XCTAssertEqual(FtpConnectionRules.blockingProblems(with: missing),
                       [.keyFileMissing("/nope/id_ed25519")])

        // A key that is there is not complained about…
        let real = FileManager.default.temporaryDirectory
            .appendingPathComponent("key-\(UUID().uuidString)")
        try Data("key".utf8).write(to: real)
        defer { try? FileManager.default.removeItem(at: real) }
        XCTAssertTrue(FtpConnectionRules.problems(with:
            site(.sftp, auth: .keyFile, keyFile: real.path)).isEmpty)
        // …and neither is a site that names no key at all, which is the agent/default-key path.
        XCTAssertTrue(FtpConnectionRules.problems(with: site(.sftp)).isEmpty)
    }

    func testATildeInTheKeyPathIsExpandedBeforeItIsLookedFor() {
        // "~/.ssh/id_rsa" is what a user types and what the ini carries; checked literally it is
        // always missing, so the dialog would refuse every key written the normal way.
        let home = NSHomeDirectory()
        let name = "pc-key-\(UUID().uuidString)"
        let path = (home as NSString).appendingPathComponent(name)
        FileManager.default.createFile(atPath: path, contents: Data("k".utf8))
        defer { try? FileManager.default.removeItem(atPath: path) }
        XCTAssertTrue(FtpConnectionRules.problems(with:
            site(.sftp, auth: .keyFile, keyFile: "~/\(name)")).isEmpty)
    }

    func testPassiveModeIsNotAChoiceBehindAProxy() {
        // The server would have to open the data connection back to us, and a tunnelled client
        // has no address to offer it.
        XCTAssertTrue(FtpConnectionRules.applies(.passive, to: site(.ftp)))
        XCTAssertFalse(FtpConnectionRules.applies(.passive, to: site(.ftp, proxyHost: "socks.local")))
    }

    // MARK: - Combinations that cannot work

    func testACleanSiteHasNothingWrongWithIt() {
        XCTAssertTrue(FtpConnectionRules.problems(with: site(.ftp)).isEmpty)
        XCTAssertTrue(FtpConnectionRules.problems(with: site(.sftp)).isEmpty)
    }

    func testTheThingsThatStopAConnectionBeingAttempted() {
        XCTAssertEqual(FtpConnectionRules.blockingProblems(with: site(.ftp, host: "  ")), [.missingHost])
        XCTAssertEqual(FtpConnectionRules.blockingProblems(with: site(.ftp, port: 99999)),
                       [.portOutOfRange(99999)])
        XCTAssertEqual(FtpConnectionRules.blockingProblems(with: site(.ftp, user: "")), [.missingUser])
        XCTAssertEqual(FtpConnectionRules.blockingProblems(with: site(.ftps)), [.explicitFTPSUnsupported])
    }

    func testAnAnonymousSiteNeedsNoUserName() {
        // The user field is disabled for it, so demanding one would be an error nothing could clear.
        XCTAssertTrue(FtpConnectionRules.blockingProblems(with:
            site(.ftp, user: "", auth: .anonymous)).isEmpty)
    }

    func testFTPSThroughAProxyIsRefusedRatherThanAttempted() {
        // The tunnel cannot be upgraded to TLS-to-target; the transport throws, and it should be
        // said here, next to the setting, rather than as a socket error later.
        XCTAssertEqual(FtpConnectionRules.blockingProblems(with:
            site(.ftpsImplicit, proxyHost: "socks.local")), [.proxyWithTLS])
    }

    func testOnlySOCKS5CanCarryFTP() {
        // An HTTP proxy was offered by the dialog and then handshaken as SOCKS5 — the one failure
        // mode worse than refusing it, because the error names a protocol nobody chose.
        XCTAssertEqual(FtpConnectionRules.blockingProblems(with:
            site(.ftp, proxyHost: "proxy.local", proxyKind: .http)), [.proxyKindUnsupported(.http)])
    }

    func testActiveModeThroughAProxyIsRefused() {
        XCTAssertEqual(FtpConnectionRules.blockingProblems(with:
            site(.ftp, passive: false, proxyHost: "socks.local")), [.activeModeThroughProxy])
    }

    func testSettingsThatAreIgnoredRatherThanFatalAreWarningsOnly() {
        // The connection is made; the point is that the form is showing settings it is not using.
        let sftpWithProxy = FtpConnectionRules.problems(with: site(.sftp, proxyHost: "socks.local"))
        XCTAssertEqual(sftpWithProxy, [.proxyWithSFTP])
        XCTAssertTrue(FtpConnectionRules.blockingProblems(with: site(.sftp, proxyHost: "socks.local")).isEmpty)

        let orphanLogin = FtpConnectionRules.problems(with: site(.ftp, proxyUser: "me"))
        XCTAssertEqual(orphanLogin, [.proxyLoginWithoutProxy])
    }

    func testBlockingProblemsAreListedBeforeWarnings() {
        // The first line of the dialog's warning label is the one that has to be read.
        let problems = FtpConnectionRules.problems(with: site(.sftp, proxyHost: "socks.local", host: ""))
        XCTAssertEqual(problems, [.missingHost, .proxyWithSFTP])
    }
}
