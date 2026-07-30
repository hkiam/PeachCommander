// MainMenuUITests.swift - XCUITest scaffold: drives the real app via Accessibility.
//
// Native, repeatable UI automation (menus, windows, buttons) — no screenshots or
// synthetic global keystrokes. Runs the app in a fixed English locale with an
// isolated config root so assertions are deterministic. This is the scaffold for
// menu/button UI tests; deeper flows (e.g. network connect) are better driven by
// the DEBUG -AutomationScript hook, which bypasses fragile dialog typing.

import XCTest

final class MainMenuUITests: XCTestCase {

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        let cfg = NSTemporaryDirectory() + "pcui-\(UUID().uuidString)"
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-ConfigRoot", cfg,
            "-LeftPath", NSHomeDirectory(), "-RightPath", "/tmp",
        ]
        app.launch()
        return app
    }

    func test_app_launches_with_main_window() {
        let app = launchedApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "app did not reach foreground")
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10), "no main window")
    }

    func test_main_menu_has_command_menus() {
        let app = launchedApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        let menuBar = app.menuBars.firstMatch
        for title in ["File", "Commands", "Net", "Mark", "View", "Configuration"] {
            XCTAssertTrue(menuBar.menuBarItems[title].exists, "missing menu: \(title)")
        }
    }

    func test_view_menu_exposes_tree_command() {
        let app = launchedApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        let view = app.menuBars.menuBarItems["View"]
        XCTAssertTrue(view.waitForExistence(timeout: 5))
        view.click()
        let tree = app.menuItems["Tree"]
        XCTAssertTrue(tree.waitForExistence(timeout: 5), "View ▸ Tree missing")
        XCTAssertTrue(tree.isEnabled, "View ▸ Tree should be enabled")
        // Close the menu without invoking (keep the test read-only).
        app.typeKey(.escape, modifierFlags: [])
    }
}
