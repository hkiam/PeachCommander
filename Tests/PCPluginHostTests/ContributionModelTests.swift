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
        XCTAssertEqual(c.commands, [CommandContribution(id: "p.cmd", title: "Do It", category: "Tools",
                                                        needsLocalPath: true)])
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

    /// A command declared long-running: the host runs it off the main thread (F-422). Declared rather than
    /// detected, because it changes the contract the plugin's own code is written against.
    func testAsyncFlagIsParsed() {
        let plist: [String: Any] = ["PCContributions": ["commands": [
            ["id": "p.slow", "title": "Push", "async": true],
            ["id": "p.quick", "title": "Status"],
            ["id": "p.explicit", "title": "Pull", "async": false],
        ]]]
        let commands = ContributionParser.parse(infoPlist: plist).contributions.commands
        let byId = Dictionary(uniqueKeysWithValues: commands.map { ($0.id, $0) })
        XCTAssertEqual(byId["p.slow"]?.isAsync, true)
        XCTAssertEqual(byId["p.quick"]?.isAsync, false, "absent means synchronous — the old contract")
        XCTAssertEqual(byId["p.explicit"]?.isAsync, false)
    }
}

// An "open family" declaration: `acceptsSuffix` lets a command id the manifest does not declare
// reach the plugin anyway, provided it extends a declared one by exactly one component. This is
// what makes a user-invented "AI ▸" action reachable — from the user menu, the button bar or a
// keyboard shortcut — without the host having to load a plugin to find out what it offers.
final class OpenCommandFamilyTests: XCTestCase {

    private func contributions(acceptsSuffix: Bool) -> PluginContributions {
        var c = PluginContributions()
        c.commands = [
            CommandContribution(id: "plugin.ai.skill.summarize", title: "Summarize"),
            CommandContribution(id: "plugin.ai.skill.custom", title: "Custom",
                                acceptsSuffix: acceptsSuffix),
        ]
        return c
    }

    func test_declaredCommand_answersForItself() {
        let c = contributions(acceptsSuffix: true)
        XCTAssertEqual(c.command(answering: "plugin.ai.skill.summarize")?.title, "Summarize")
    }

    func test_undeclaredSuffix_reachesTheOpenDeclaration() {
        let c = contributions(acceptsSuffix: true)
        XCTAssertEqual(c.command(answering: "plugin.ai.skill.mein-eigener")?.id,
                       "plugin.ai.skill.custom")
    }

    func test_withoutTheFlag_anUndeclaredIdIsNotAnswered() {
        XCTAssertNil(contributions(acceptsSuffix: false).command(answering: "plugin.ai.skill.mein-eigener"))
    }

    // A family is one level deep: an open family must not answer for everything beneath it.
    func test_deeperNesting_isNotAnswered() {
        XCTAssertNil(contributions(acceptsSuffix: true).command(answering: "plugin.ai.skill.a.b"))
    }

    func test_emptySuffix_isNotAnswered() {
        XCTAssertNil(contributions(acceptsSuffix: true).command(answering: "plugin.ai.skill."))
    }

    func test_anotherFamily_isNotAnswered() {
        let c = contributions(acceptsSuffix: true)
        XCTAssertNil(c.command(answering: "plugin.ai.folderskill.organize"))
        XCTAssertNil(c.command(answering: "plugin.git.commit"))
    }

    // An exact declaration wins, so opening a family cannot shadow a real entry.
    func test_exactMatchWins_overTheOpenFamily() {
        let c = contributions(acceptsSuffix: true)
        XCTAssertEqual(c.command(answering: "plugin.ai.skill.summarize")?.id, "plugin.ai.skill.summarize")
    }

    func test_flagIsParsedFromTheManifest() {
        let plist: [String: Any] = ["PCContributions": ["commands": [
            ["id": "plugin.ai.skill.custom", "title": "Custom", "acceptsSuffix": true],
            ["id": "plugin.ai.skill.summarize", "title": "Summarize"],
        ]]]
        let parsed = ContributionParser.parse(infoPlist: plist).contributions
        XCTAssertTrue(parsed.commands.first { $0.id.hasSuffix("custom") }?.acceptsSuffix ?? false)
        XCTAssertFalse(parsed.commands.first { $0.id.hasSuffix("summarize") }?.acceptsSuffix ?? true)
        XCTAssertEqual(parsed.command(answering: "plugin.ai.skill.was-anderes")?.id,
                       "plugin.ai.skill.custom")
    }

    // The real manifest, so the declaration cannot quietly go missing from the shipped plugin.
    func test_theAssistantsManifest_opensItsSkillFamily() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Plugins/AIAssistant/Info.plist")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let parsed = ContributionParser.parse(infoPlist: plist ?? [:]).contributions
        XCTAssertNotNil(parsed.command(answering: "plugin.ai.skill.eine-eigene-aktion"),
                        "a skill the user invents must be reachable")
        XCTAssertNil(parsed.command(answering: "plugin.ai.nonsense.thing"))
    }
}
