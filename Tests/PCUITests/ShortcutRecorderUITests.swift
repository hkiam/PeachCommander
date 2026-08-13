// SPDX-License-Identifier: Apache-2.0
// ShortcutRecorderUITests.swift - The Record sheet in the keyboard-shortcut editor (F-254).
//
// A happy-path smoke test: the editor opens from the menu, Record puts up a capture sheet, a chord
// pressed into it lands in keymap-user.ini, and Esc cancels without binding anything.
//
// What it is NOT: a guard against the defect that prompted it. That bug — the capture sheet's window
// controller was a local, so it deallocated while AppKit kept the sheet on screen and every
// keystroke hit a `[weak self]` that had become nil — does not reproduce here, and the app's own
// log says why. Driven through Accessibility (`osascript`, `click button`, `key code`) the order is
//
//     beginSheet fr=true / controller deinit / keyDown        → no handler, nothing recorded
//
// and driven by XCUITest against the *same binary* it is
//
//     beginSheet fr=true / keyDown / handle / controller deinit
//
// — the leaked controller outlives the keystroke by exactly enough to serve it. Neither an
// interposed `hover()`, nor a `click()`, nor seconds of waiting moved the `deinit` ahead of the
// key; what decides it is how the Record button is activated (AXPress vs. injected mouse events)
// and the autorelease nesting AppKit uses for each. That last step is AppKit-internal and is not
// claimed here beyond what the log shows.
//
// The practical part is the point: an XCUITest that types into a dialog can pass while that dialog
// is, to a user, completely dead. Defects of this class need the AX/`key code` route, or a check
// that the *outcome* changed rather than that the UI moved.

import XCTest

final class ShortcutRecorderUITests: XCTestCase {

    /// The command to bind — picked with the editor's search box so the test never depends on which
    /// row happens to be where.
    private let target = "cm_BottomArea"

    private var configRoot = ""

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        configRoot = NSTemporaryDirectory() + "pcui-keys-\(UUID().uuidString)"
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-ConfigRoot", configRoot,
            "-LeftPath", NSHomeDirectory(), "-RightPath", "/tmp",
        ]
        app.launch()
        return app
    }

    private var userKeymap: String {
        (try? String(contentsOfFile: configRoot + "/keymap-user.ini", encoding: .utf8)) ?? ""
    }

    /// Open Configuration ▸ Edit Shortcuts…, filter to `target`, and select it.
    private func openEditorOnTarget(_ app: XCUIApplication) throws -> XCUIElement {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "app did not reach foreground")
        let menu = app.menuBars.firstMatch.menuBarItems["Configuration"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "no Configuration menu")
        menu.click()
        let item = app.menuItems["Edit Shortcuts…"]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "no Edit Shortcuts… item")
        item.click()

        let editor = app.windows["Keyboard Shortcuts"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "the shortcut editor did not open")
        let search = editor.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "no search field")
        search.click()
        search.typeText(target)

        let table = editor.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 5), "no command table")
        let row = table.tableRows.element(boundBy: 0)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "\(target) is not in the command list")
        row.click()
        return editor
    }

    private func beginRecording(in editor: XCUIElement) -> XCUIElement {
        editor.buttons["Record…"].click()
        let sheet = editor.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "the capture sheet did not appear")
        // A pause before typing, as a user would. It does not make this test able to catch the
        // lifetime defect — see the file header — but it keeps the flow honest to what a person does.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        return sheet
    }

    /// Poll for the binding: the app writes the file after the sheet closes.
    private func waitForKeymap(containing needle: String, timeout: TimeInterval = 6) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if userKeymap.contains(needle) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return userKeymap.contains(needle)
    }

    // MARK: - Tests

    func test_recordingAChord_actuallyBindsIt() throws {
        let app = launchedApp()
        let editor = try openEditorOnTarget(app)
        let sheet = beginRecording(in: editor)

        sheet.typeKey("k", modifierFlags: [.control, .shift])

        // The outcome a user is after: the key they pressed is now the command's shortcut.
        XCTAssertTrue(waitForKeymap(containing: "C+S+K=\(target)"),
                      "the chord never reached the capture sheet; keymap-user.ini is: \(userKeymap)")
    }

    func test_escCancels_andBindsNothing() throws {
        let app = launchedApp()
        let editor = try openEditorOnTarget(app)
        let sheet = beginRecording(in: editor)

        sheet.typeKey(.escape, modifierFlags: [])

        // Give the app the same chance to write that the recording test allows it, then require
        // that it did not: cancelling must leave the keymap untouched.
        _ = waitForKeymap(containing: target, timeout: 2)
        XCTAssertFalse(userKeymap.contains(target),
                       "Esc recorded a binding anyway: \(userKeymap)")
    }
}
