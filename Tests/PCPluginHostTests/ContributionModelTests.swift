// SPDX-License-Identifier: Apache-2.0
// ContributionModelTests.swift - ContributionParser + WhenExpression (SPEC-013 P1).

import XCTest
@testable import PCPluginHost

final class ContributionParserTests: XCTestCase {
    func test_emptyWhenNoContributionsKey() {
        let r = ContributionParser.parse(infoPlist: ["PCPluginName": "X"])
        XCTAssertTrue(r.contributions.isEmpty)
        XCTAssertTrue(r.warnings.isEmpty)
    }

    func test_parsesAllSectionsWithDefaults() {
        let dict: [String: Any] = ["PCContributions": [
            "commands": [["id": "p.cmd", "title": "Do It", "category": "Tools", "needsLocalPath": true]],
            "menus": [["command": "p.cmd", "menu": "File"]],  // group/order defaulted
            "contextMenus": [["command": "p.cmd", "surface": "panel.item", "when": "cursorIsApp"]],
            "keybindings": [["command": "p.cmd", "key": "cmd+shift+u"]],
            "views": [["id": "p.view", "container": "sidebar", "title": "Map", "order": 5]],
            "hides": [["command": "builtin.foo"]],
        ]]
        let c = ContributionParser.parse(infoPlist: dict).contributions
        XCTAssertEqual(c.commands, [CommandContribution(id: "p.cmd", title: "Do It", category: "Tools", needsLocalPath: true)])
        XCTAssertEqual(c.menus.first?.group, "9_plugins")
        XCTAssertEqual(c.menus.first?.order, 100)
        XCTAssertEqual(c.menus.first?.menu, "File")
        XCTAssertEqual(c.contextMenus.first?.surface, "panel.item")
        XCTAssertEqual(c.contextMenus.first?.when, "cursorIsApp")
        XCTAssertEqual(c.keybindings.first?.key, "cmd+shift+u")
        XCTAssertEqual(c.views.first, ViewContribution(id: "p.view", container: "sidebar", title: "Map", order: 5, when: nil))
        XCTAssertEqual(c.hides.first?.command, "builtin.foo")
    }

    func test_parsesToolContributions() {
        let dict: [String: Any] = ["PCContributions": [
            "tools": [[
                "name": "plugin.weather",
                "description": "Get the weather.",
                "capability": "network",
                "params": [["name": "city", "type": "string", "description": "City", "required": true],
                           ["name": "days", "type": "integer", "description": "Days", "required": false]],
            ]],
        ]]
        let c = ContributionParser.parse(infoPlist: dict).contributions
        XCTAssertEqual(c.tools.count, 1)
        let t = c.tools[0]
        XCTAssertEqual(t.name, "plugin.weather")
        XCTAssertEqual(t.capability, "network")
        XCTAssertEqual(t.params.map(\.name), ["city", "days"])
        XCTAssertEqual(t.params[0].required, true)
        XCTAssertEqual(t.params[1].required, false)
        XCTAssertEqual(t.params[1].type, "integer")
    }

    func test_skipsMalformedEntriesWithWarnings() {
        let dict: [String: Any] = ["PCContributions": [
            "commands": [["id": "ok", "title": "OK"], ["title": "no id"]],
            "menus": [["command": "ok"]],  // missing menu
        ]]
        let r = ContributionParser.parse(infoPlist: dict)
        XCTAssertEqual(r.contributions.commands.count, 1)
        XCTAssertTrue(r.contributions.menus.isEmpty)
        XCTAssertEqual(r.warnings.count, 2)
    }

    func test_orderAcceptsStringOrInt() {
        let dict: [String: Any] = ["PCContributions": [
            "menus": [["command": "c", "menu": "File", "order": "42"]],
        ]]
        XCTAssertEqual(ContributionParser.parse(infoPlist: dict).contributions.menus.first?.order, 42)
    }
}

final class WhenExpressionTests: XCTestCase {
    private func ctx(_ v: [String: WhenValue]) -> ContributionContext { ContributionContext(v) }

    func test_boolIdentifierAndNegation() {
        XCTAssertTrue(WhenExpression.evaluate("cursorIsApp", context: ctx(["cursorIsApp": .bool(true)])))
        XCTAssertFalse(WhenExpression.evaluate("!cursorIsApp", context: ctx(["cursorIsApp": .bool(true)])))
        XCTAssertFalse(WhenExpression.evaluate("missing", context: ctx([:])))
    }

    func test_comparisonsAndRegex() {
        let c = ctx(["cursorPath": .string("/Apps/Foo.app"), "selectionCount": .int(2)])
        XCTAssertTrue(WhenExpression.evaluate(#"cursorPath =~ "\.app$""#, context: c))
        XCTAssertTrue(WhenExpression.evaluate("cursorPath endswith \".app\"", context: c))
        XCTAssertTrue(WhenExpression.evaluate("selectionCount > 1", context: c))
        XCTAssertFalse(WhenExpression.evaluate("selectionCount >= 3", context: c))
        XCTAssertTrue(WhenExpression.evaluate("selectionCount == 2", context: c))
    }

    func test_booleanCombinationsAndPrecedence() {
        let c = ctx(["a": .bool(true), "b": .bool(false), "n": .int(5)])
        XCTAssertTrue(WhenExpression.evaluate("a && !b", context: c))
        XCTAssertTrue(WhenExpression.evaluate("b || n > 3", context: c))
        XCTAssertFalse(WhenExpression.evaluate("a && (b || n < 3)", context: c))
        XCTAssertTrue(WhenExpression.evaluate("a && (b || n >= 5)", context: c))
    }

    func test_inList() {
        let c = ctx(["ext": .string("log")])
        XCTAssertTrue(WhenExpression.evaluate("ext in (\"log\", \"txt\")", context: c))
        XCTAssertFalse(WhenExpression.evaluate("ext in (\"csv\", \"txt\")", context: c))
    }

    func test_emptyOrNilIsAlwaysTrue() {
        XCTAssertTrue(WhenExpression.evaluate(nil, context: ctx([:])))
        XCTAssertTrue(WhenExpression.evaluate("   ", context: ctx([:])))
    }

    func test_malformedFailsClosed() {
        XCTAssertFalse(WhenExpression.evaluate("a &&", context: ctx(["a": .bool(true)])))
        XCTAssertFalse(WhenExpression.evaluate("== 3", context: ctx([:])))
        XCTAssertThrowsError(try WhenExpression("a &&"))
    }
}
