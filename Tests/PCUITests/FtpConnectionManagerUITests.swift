// SPDX-License-Identifier: Apache-2.0
// FtpConnectionManagerUITests.swift - Issue #4: picking SFTP must not lock the site to Anonymous.
//
// Drives the real dialog through Accessibility, because the defect is in the interplay of
// `commitForm` (which reads the checkbox) and `updateEnabledState` (which disables it): neither
// is wrong on its own, and no unit test can see the combination.

import XCTest

final class FtpConnectionManagerUITests: XCTestCase {

    /// A fresh config root per run, optionally seeded with an `ftp-sites.ini`, so the site list is
    /// exactly what the test put there and the file can be read back after Save.
    ///
    /// Nothing here ever types into the password field: the app builds its own
    /// `KeychainSecretStore`, so a saved secret would land in the real login keychain.
    private func launchedApp(sites: String? = nil,
                             inMemorySecrets: Bool = false) -> (app: XCUIApplication,
                                                                configRoot: String) {
        let app = XCUIApplication()
        let cfg = NSTemporaryDirectory() + "pcui-\(UUID().uuidString)"
        if let sites {
            try? FileManager.default.createDirectory(atPath: cfg, withIntermediateDirectories: true)
            try? sites.write(toFile: cfg + "/ftp-sites.ini", atomically: true, encoding: .utf8)
        }
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-ApplePersistenceIgnoreState", "YES",
            "-ConfigRoot", cfg,
            "-LeftPath", NSHomeDirectory(), "-RightPath", "/tmp",
        ]
        // Only the one test that types a secret asks for this, and it is what lets it: without it
        // the dialog writes into the real login keychain.
        if inMemorySecrets { app.launchArguments += ["-PCSecretStore", "memory"] }
        app.launch()
        return (app, cfg)
    }

    /// Press Save and read back what landed in ftp-sites.ini.
    ///
    /// Waits on the file's modification date rather than on its contents: a save that correctly
    /// changes nothing is exactly what one of these tests asserts, so "wait until it differs"
    /// would hang on the passing case and read a stale file on the failing one.
    private func savedSites(in window: XCUIElement, configRoot: String) -> String {
        let path = configRoot + "/ftp-sites.ini"
        let before = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate])
            .flatMap { $0 as? Date } ?? .distantPast
        let save = window.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "no Save button")
        save.click()
        for _ in 0..<80 {
            let now = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate])
                .flatMap { $0 as? Date }
            if let now, now > before { break }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }

    /// Open Net ▸ FTP Connect…, leaving whatever the site list selected by itself.
    @discardableResult
    private func openManager(_ app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20), "app did not reach foreground")
        let net = app.menuBars.menuBarItems["Net"]
        XCTAssertTrue(net.waitForExistence(timeout: 10), "no Net menu")
        net.click()
        let item = app.menuItems["FTP Connect…"]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Net ▸ FTP Connect… missing")
        item.click()
        let window = app.windows["FTP Connection Manager"]
        XCTAssertTrue(window.waitForExistence(timeout: 10), "connection manager did not open")
        return window
    }

    /// The site's own secret field: the only one of the two that is live on an SFTP site, since
    /// the other is the proxy password and a proxy is not a thing there.
    private func accountSecretField(in window: XCUIElement) -> XCUIElement {
        let secrets = window.secureTextFields
        for i in 0..<secrets.count where secrets.element(boundBy: i).isEnabled {
            return secrets.element(boundBy: i)
        }
        XCTFail("no secret field is enabled")
        return secrets.firstMatch
    }

    /// Whether any of the two secure fields is live. Asked this way rather than by index: the
    /// other one is the proxy password, and a proxy is not a thing on SFTP either, so it is
    /// disabled whatever the order of the two.
    private func aPasswordCanBeTyped(in window: XCUIElement) -> Bool {
        let secrets = window.secureTextFields
        return (0..<secrets.count).contains { secrets.element(boundBy: $0).isEnabled }
    }

    /// Open the manager and press New, leaving a fresh site selected.
    private func openManagerWithNewSite(_ app: XCUIApplication) -> XCUIElement {
        let window = openManager(app)
        let new = window.buttons["New"]
        XCTAssertTrue(new.waitForExistence(timeout: 5), "no New button")
        new.click()
        return window
    }

    /// The protocol popup is the one showing a protocol name; the other two show an encoding
    /// and a proxy kind. Addressing it by index would depend on the grid's row order.
    private func protocolPopup(in window: XCUIElement) -> XCUIElement {
        let names = ["FTP", "FTPS (implicit)", "FTPS (explicit)", "SFTP"]
        for i in 0..<window.popUpButtons.count {
            let p = window.popUpButtons.element(boundBy: i)
            if let v = p.value as? String, names.contains(v) { return p }
        }
        XCTFail("no protocol popup found")
        return window.popUpButtons.firstMatch
    }

    func test_newSite_startsAnonymousAndOffersTheChoice() {
        let app = launchedApp().app
        let window = openManagerWithNewSite(app)
        let anonymous = window.checkBoxes["Anonymous"]
        XCTAssertTrue(anonymous.waitForExistence(timeout: 5), "no Anonymous checkbox")
        XCTAssertEqual(anonymous.value as? Int, 1, "a new site starts Anonymous")
        XCTAssertTrue(anonymous.isEnabled, "…and the user can turn it off")
    }

    /// Issue #4. Selecting SFTP while Anonymous is still ticked must leave the user a way to
    /// reach an authenticated login: either the box comes off with the protocol that has no
    /// anonymous login, or it stays clickable. Disabled *and* ticked is a dead end.
    func test_selectingSFTP_doesNotLockTheSiteToAnonymous() {
        let app = launchedApp().app
        let window = openManagerWithNewSite(app)

        let anonymous = window.checkBoxes["Anonymous"]
        XCTAssertTrue(anonymous.waitForExistence(timeout: 5), "no Anonymous checkbox")
        XCTAssertEqual(anonymous.value as? Int, 1, "precondition: a new site starts Anonymous")

        let proto = protocolPopup(in: window)
        proto.click()
        let sftp = app.menuItems["SFTP"]
        XCTAssertTrue(sftp.waitForExistence(timeout: 5), "no SFTP item in the protocol popup")
        sftp.click()
        XCTAssertEqual(proto.value as? String, "SFTP", "protocol did not change")

        let stillOn = (anonymous.value as? Int) == 1
        XCTAssertFalse(stillOn && !anonymous.isEnabled,
                       "SFTP left Anonymous ticked and greyed out — the site is locked to the "
                       + "anonymous login with no way back to a user name and password")
        // SSH has no anonymous login, so the box goes off rather than staying ticked and
        // unreachable. Off *and* disabled is honest: the setting does not exist here.
        XCTAssertEqual(anonymous.value as? Int, 0, "Anonymous should come off with the protocol")
        // And the login the user now has to make is reachable.
        XCTAssertTrue(aPasswordCanBeTyped(in: window),
                      "the password field is still disabled — no way to enter credentials")
    }

    /// The other half of issue #4, and the one that decides whether the fix reaches the people
    /// who reported it: the dialog persisted the dead end, so everybody affected already has
    /// `auth=anonymous` under `protocol=sftp` in their ftp-sites.ini. Opening such a site must
    /// not reproduce the lock.
    func test_aSiteAlreadySavedAsAnonymousSFTPOpensUnlocked() {
        let app = launchedApp(sites: """
            [Legacy SFTP]
            host=example.org
            port=22
            protocol=sftp
            user=anonymous
            auth=anonymous
            """).app
        let window = openManager(app)

        let anonymous = window.checkBoxes["Anonymous"]
        XCTAssertTrue(anonymous.waitForExistence(timeout: 5), "no Anonymous checkbox")
        XCTAssertEqual(anonymous.value as? Int, 0,
                       "the stored anonymous login is shown as in force although SSH has none")
        XCTAssertTrue(aPasswordCanBeTyped(in: window),
                      "a site saved this way is still locked out of its own credentials")
    }

    /// The passphrase of an encrypted key is offered by the dialog, so it has to be kept. It was
    /// read back from the Keychain on every selection and written on none, because `persist()`
    /// stored a secret only for a plain password login — and the field is *specially* enabled for
    /// a key file, that being where libssh2 wants the passphrase instead of a password.
    ///
    /// The round-trip is driven by moving the selection away and back, which is what makes
    /// `updateForm` re-read the store. Closing and reopening the window would prove the same
    /// thing, but the app does not reliably stay active across it and the menu bar goes away.
    func test_theKeyPassphraseIsRememberedAcrossASelectionChange() {
        // A key file that is really there: a named key is what puts the dialog into key
        // authentication, and a missing one would only add a warning.
        let key = NSTemporaryDirectory() + "pcui-key-\(UUID().uuidString)"
        FileManager.default.createFile(atPath: key, contents: Data("k".utf8))
        defer { try? FileManager.default.removeItem(atPath: key) }

        let (app, _) = launchedApp(sites: """
            [Key Box]
            host=box.example.org
            port=22
            protocol=sftp
            user=root
            auth=key
            keyfile=\(key)

            [Somewhere Else]
            host=other.example.org
            port=21
            protocol=ftp
            user=someone
            auth=password
            """, inMemorySecrets: true)
        let window = openManager(app)

        // The label is the dialog saying which secret it is asking for, and doubles as proof that
        // the seeded site really arrived in key authentication.
        XCTAssertTrue(window.staticTexts["Passphrase:"].waitForExistence(timeout: 5),
                      "the seeded site is not in key authentication")

        let field = accountSecretField(in: window)
        field.click()
        field.typeText("correct-horse")
        // A secure field reports its value as AppKit's masking glyph (U+F79A) once per character,
        // never the text — so this compares how much is in the field, not what, and no secret can
        // reach the log. Measured: 13 glyphs for the 13 characters above.
        let typed = (field.value as? String) ?? ""
        XCTAssertEqual(typed.count, "correct-horse".count,
                       "nothing reached the field; value: \(String(describing: field.value))")

        window.buttons["Save"].click()

        // Away and back. `updateForm` rewrites the secret field from the store on every selection
        // change, so what comes back is what was stored — or nothing, which was the defect.
        let other = window.staticTexts["Somewhere Else"]
        XCTAssertTrue(other.waitForExistence(timeout: 5), "the second seeded site is not listed")
        other.click()
        window.staticTexts["Key Box"].click()

        XCTAssertTrue(window.staticTexts["Passphrase:"].waitForExistence(timeout: 5),
                      "the key site did not come back")
        let reopened = (accountSecretField(in: window).value as? String) ?? ""
        XCTAssertEqual(reopened, typed,
                       "the passphrase was not kept — it came back "
                       + (reopened.isEmpty ? "empty" : "as something else"))
    }

    /// A setting the new protocol has no such thing for is not carried over behind a greyed-out
    /// tick. "Accept a self-signed certificate" is the one that matters: re-arming itself the next
    /// time the site becomes FTPS again is a security decision nobody made twice.
    func test_aTickThatNoLongerAppliesIsClearedByTheProtocolChange() {
        let (app, cfg) = launchedApp(sites: """
            [Carry Over]
            host=example.org
            port=22
            protocol=sftp
            user=root
            auth=password
            usescp=1
            allowinsecuretls=1
            """)
        let window = openManager(app)

        let scp = window.checkBoxes["Transfer via SCP (SFTP only)"]
        XCTAssertTrue(scp.waitForExistence(timeout: 5), "no SCP checkbox")
        XCTAssertEqual(scp.value as? Int, 1, "precondition: the seeded site transfers via SCP")

        let proto = protocolPopup(in: window)
        proto.click()
        let ftp = app.menuItems["FTP"]
        XCTAssertTrue(ftp.waitForExistence(timeout: 5), "no FTP item in the protocol popup")
        ftp.click()
        XCTAssertEqual(proto.value as? String, "FTP", "protocol did not change")

        XCTAssertEqual(scp.value as? Int, 0, "SCP is an SFTP setting and did not come off with it")
        let tls = window.checkBoxes["Accept self-signed certificate (FTPS)"]
        XCTAssertEqual(tls.value as? Int, 0, "plain FTP has no certificate to accept")

        // And what the form shows is what the file gets: both keys are written only when true.
        let ini = savedSites(in: window, configRoot: cfg)
        XCTAssertFalse(ini.contains("usescp"), "usescp survived into a plain FTP site:\n\(ini)")
        XCTAssertFalse(ini.contains("allowinsecuretls"),
                       "a plain FTP site was saved accepting self-signed certificates:\n\(ini)")
    }

    /// The ssh-agent is the one authentication no control in the dialog can set, so the dialog
    /// must not rewrite it either — and must still leave a way out of it.
    func test_anAgentSiteKeepsItsAuthenticationAndCanStillBeGivenAPassword() {
        let (app, cfg) = launchedApp(sites: """
            [Agent Box]
            host=box.example.org
            port=22
            protocol=sftp
            user=root
            auth=agent
            """)
        let window = openManager(app)

        // The way out: typing a password is what makes the site stop being an agent site, and a
        // disabled field made that impossible without hand-editing the file back.
        XCTAssertTrue(aPasswordCanBeTyped(in: window),
                      "an agent site cannot be given a password at all")

        // Saving without touching anything must not quietly demote it to a password login.
        let ini = savedSites(in: window, configRoot: cfg)
        XCTAssertTrue(ini.contains("auth=agent"),
                      "the ssh-agent setting was rewritten by a save that changed nothing:\n\(ini)")
    }
}
