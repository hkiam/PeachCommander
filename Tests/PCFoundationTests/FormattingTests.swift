// SPDX-License-Identifier: Apache-2.0
// FormattingTests.swift - The formatter protocol, the built-ins, and registry resolution.

import XCTest
@testable import PCFoundation

final class FormattingTests: XCTestCase {

    // MARK: - JSON

    func testJSONPrettyPrintsAndSortsKeys() throws {
        let out = try JSONFormatter().format(#"{"b":2,"a":1}"#)
        XCTAssertTrue(out.contains("\"a\""))
        XCTAssertLessThan(try XCTUnwrap(out.range(of: "\"a\"")).lowerBound,
                          try XCTUnwrap(out.range(of: "\"b\"")).lowerBound, "keys should be sorted")
    }

    func testJSONInvalidThrowsInvalidInput() {
        XCTAssertThrowsError(try JSONFormatter().format("{not json")) { error in
            XCTAssertEqual(error as? FormatError, .invalidInput("JSON"))
        }
    }

    func testJSONUnchangedThrowsUnchanged() throws {
        let formatted = try JSONFormatter().format(#"{"a":1}"#)
        XCTAssertThrowsError(try JSONFormatter().format(formatted)) { error in
            XCTAssertEqual(error as? FormatError, .unchanged)
        }
    }

    // MARK: - XML / HTML

    func testXMLPrettyPrints() throws {
        let out = try XMLFormatter().format("<a><b>1</b></a>")
        XCTAssertTrue(out.contains("<b>1</b>"))
        XCTAssertTrue(out.contains("\n"), "expected indentation:\n\(out)")
    }

    func testXMLInvalidThrows() {
        XCTAssertThrowsError(try XMLFormatter().format("<a><b></a>")) { error in
            XCTAssertEqual(error as? FormatError, .invalidInput("XML"))
        }
    }

    /// Why HTML is not simply routed through XMLFormatter: real pages are not well-formed
    /// XML, and libxml2's HTML mode accepts them.
    func testHTMLAcceptsUnclosedTagsThatXMLRejects() throws {
        let soup = "<html><body><p>one<p>two</body></html>"
        XCTAssertThrowsError(try XMLFormatter().format(soup))
        let out = try HTMLFormatter().format(soup)
        XCTAssertTrue(out.contains("one"))
        XCTAssertTrue(out.contains("two"))
    }

    // MARK: - INI

    func testINIRoundTripsThroughTheProjectsOwnParser() throws {
        let out = try INIFormatter().format("[b]\nkey=1\n[a]\nother = 2\n")
        XCTAssertTrue(out.contains("[a]"))
        XCTAssertTrue(out.contains("[b]"))
    }

    // MARK: - YAML tidy (whitespace only)

    func testYAMLStripsTrailingWhitespaceAndCollapsesBlankLines() throws {
        let out = try YAMLTidyFormatter().format("name: peach   \n\n\n\nport: 8080\t\n")
        XCTAssertEqual(out, "name: peach\n\nport: 8080\n")
    }

    func testYAMLConvertsIndentationTabsOnly() throws {
        let out = try YAMLTidyFormatter().format("root:\n\tchild:\tvalue\n")
        XCTAssertEqual(out, "root:\n  child:\tvalue\n")
    }

    func testYAMLAlreadyTidyThrowsUnchanged() {
        XCTAssertThrowsError(try YAMLTidyFormatter().format("name: peach\nport: 8080\n")) { error in
            XCTAssertEqual(error as? FormatError, .unchanged)
        }
    }

    /// Safety-critical: inside a block scalar, whitespace is content.
    func testYAMLPreservesBlockScalarContentVerbatim() throws {
        let input = "script: |\n  line one   \n    indented deeper\n\n  after a blank line\nnext: 1   \n"
        let out = try YAMLTidyFormatter().format(input)
        XCTAssertTrue(out.contains("  line one   \n"), "trailing spaces inside | must survive:\n\(out)")
        XCTAssertTrue(out.contains("    indented deeper\n"), "inner indentation must survive:\n\(out)")
        XCTAssertTrue(out.contains("\n\n  after a blank line\n"), "blank line inside | must survive:\n\(out)")
        XCTAssertTrue(out.contains("next: 1\n"), "the line after the block must still be tidied:\n\(out)")
    }

    func testYAMLBlockScalarIndicatorVariantsAreRecognised() throws {
        for indicator in ["|", "|-", "|+", ">", ">-", "|2"] {
            let out = try YAMLTidyFormatter().format("s: \(indicator)\n  keep me   \nafter: 1   \n")
            XCTAssertTrue(out.contains("  keep me   \n"),
                          "indicator \(indicator) should open a block scalar:\n\(out)")
        }
    }

    func testYAMLTrailingCommentIsNotMistakenForBlockScalar() throws {
        let out = try YAMLTidyFormatter().format("a: value # |\n  b: 1   \n")
        XCTAssertFalse(out.contains("  b: 1   \n"), "should have been tidied:\n\(out)")
    }

    func testYAMLKeepsTabsInsideQuotedScalars() {
        XCTAssertThrowsError(try YAMLTidyFormatter().format("k: \"a\tb\"\n")) { error in
            XCTAssertEqual(error as? FormatError, .unchanged)
        }
    }

    // MARK: - Registry resolution

    private struct StubFormatter: TextFormatter {
        let name: String
        let supportedExtensions: [String]
        let isAvailable: Bool
        let output: String
        func format(_ text: String) throws -> String { output }
    }

    func testRegistryPrefersUserConfiguredOverBuiltIn() throws {
        let registry = FormatterRegistry(external: [], builtIn: [
            StubFormatter(name: "built-in", supportedExtensions: ["x"], isAvailable: true, output: "B")])
        registry.setUserConfigured([
            StubFormatter(name: "user", supportedExtensions: ["x"], isAvailable: true, output: "U")])
        let result = try registry.format("in", extension: "x")
        XCTAssertEqual(result.formatter, "user")
        XCTAssertEqual(result.text, "U")
    }

    func testRegistryPrefersPluginOverExternalAndBuiltIn() throws {
        let registry = FormatterRegistry(
            external: [StubFormatter(name: "tool", supportedExtensions: ["x"], isAvailable: true, output: "T")],
            builtIn: [StubFormatter(name: "built-in", supportedExtensions: ["x"], isAvailable: true, output: "B")])
        registry.registerPlugin([
            StubFormatter(name: "plugin", supportedExtensions: ["x"], isAvailable: true, output: "P")])
        XCTAssertEqual(try registry.format("in", extension: "x").formatter, "plugin")
    }

    func testRegistrySkipsUnavailableCandidates() throws {
        let registry = FormatterRegistry(
            external: [StubFormatter(name: "missing", supportedExtensions: ["x"], isAvailable: false, output: "T")],
            builtIn: [StubFormatter(name: "built-in", supportedExtensions: ["x"], isAvailable: true, output: "B")])
        XCTAssertEqual(try registry.format("in", extension: "x").formatter, "built-in")
    }

    func testRegistryFallsThroughWhenAFormatterRejectsTheInput() throws {
        struct Rejecting: TextFormatter {
            let name = "picky"
            let supportedExtensions = ["x"]
            func format(_ text: String) throws -> String { throw FormatError.invalidInput("X") }
        }
        let registry = FormatterRegistry(external: [Rejecting()], builtIn: [
            StubFormatter(name: "built-in", supportedExtensions: ["x"], isAvailable: true, output: "B")])
        XCTAssertEqual(try registry.format("in", extension: "x").formatter, "built-in")
    }

    func testRegistryUnchangedIsNotRoutedAround() {
        struct AlreadyDone: TextFormatter {
            let name = "done"
            let supportedExtensions = ["x"]
            func format(_ text: String) throws -> String { throw FormatError.unchanged }
        }
        let registry = FormatterRegistry(external: [AlreadyDone()], builtIn: [
            StubFormatter(name: "built-in", supportedExtensions: ["x"], isAvailable: true, output: "B")])
        XCTAssertThrowsError(try registry.format("in", extension: "x")) { error in
            XCTAssertEqual(error as? FormatError, .unchanged)
        }
    }

    func testRegistryReportsNoFormatterForUnknownExtension() {
        let registry = FormatterRegistry(external: [], builtIn: [])
        XCTAssertThrowsError(try registry.format("in", extension: "zzz")) { error in
            XCTAssertEqual(error as? FormatError, .noFormatterAvailable(extension: "zzz"))
        }
        XCTAssertFalse(registry.canFormat(extension: "zzz"))
    }

    func testDefaultRegistryFormatsTheBuiltInTypes() {
        let registry = FormatterRegistry()
        for ext in ["json", "xml", "html", "ini", "yml", "yaml", "svg", "plist"] {
            XCTAssertTrue(registry.canFormat(extension: ext), "expected a formatter for .\(ext)")
        }
    }

    // MARK: - External tools

    func testExternalToolReportsUnavailableWhenNotInstalled() {
        let formatter = ExternalToolFormatter(tool: "definitely-not-installed-xyz",
                                              arguments: [], extensions: ["x"])
        XCTAssertFalse(formatter.isAvailable)
        XCTAssertThrowsError(try formatter.format("in")) { error in
            XCTAssertEqual(error as? FormatError, .toolNotFound("definitely-not-installed-xyz"))
        }
    }

    /// sed is always present, so the stdin/stdout plumbing is testable without depending on
    /// jq or yq being installed.
    func testExternalToolPipesThroughStdinAndStdout() throws {
        let sed = ExternalToolFormatter(tool: "/usr/bin/sed", arguments: ["s/a/b/"], extensions: ["x"])
        XCTAssertTrue(sed.isAvailable)
        XCTAssertEqual(try sed.format("aaa\n"), "baa\n")
    }

    func testExternalToolSurfacesFailureWithDiagnostics() {
        let failing = ExternalToolFormatter(tool: "/usr/bin/false", arguments: [], extensions: ["x"])
        XCTAssertThrowsError(try failing.format("in")) { error in
            guard case .toolFailed(_, let code, _)? = error as? FormatError else {
                return XCTFail("expected toolFailed, got \(error)")
            }
            XCTAssertNotEqual(code, 0)
        }
    }

    func testToolLocatorFindsASystemBinary() {
        XCTAssertNotNil(ToolLocator.path(for: "sed"))
        XCTAssertNil(ToolLocator.path(for: "definitely-not-installed-xyz"))
    }

    // MARK: - User configuration

    func testFormatterConfigParsesSectionsPerExtension() {
        let formatters = FormatterConfig.parse("[swift]\ntool = swiftformat\nargs = --quiet stdin\n\n[go]\ntool = gofmt\n")
        XCTAssertEqual(formatters.count, 2)
        let swift = formatters.first { $0.supportedExtensions == ["swift"] }
        XCTAssertEqual(swift?.tool, "swiftformat")
        XCTAssertEqual(swift?.arguments, ["--quiet", "stdin"])
        XCTAssertEqual(formatters.first { $0.supportedExtensions == ["go"] }?.arguments, [])
    }

    func testFormatterConfigSkipsSectionsWithoutATool() {
        let formatters = FormatterConfig.parse("[a]\nargs = --x\n\n[b]\ntool = gofmt\n")
        XCTAssertEqual(formatters.map(\.supportedExtensions), [["b"]])
    }

    func testFormatterConfigHonoursQuotedArguments() {
        XCTAssertEqual(FormatterConfig.splitArguments(#"--config "/a path/x.json" -q"#),
                       ["--config", "/a path/x.json", "-q"])
    }

    func testFormatterConfigNameOverridesTheDisplayedLabel() {
        let formatters = FormatterConfig.parse("[rs]\ntool = rustfmt\nname = rustfmt edition2021\n")
        XCTAssertEqual(formatters.first?.name, "rustfmt edition2021")
    }

    func testFormatterConfigLoadReturnsEmptyWhenAbsent() {
        let missing = URL(fileURLWithPath: "/tmp/pc-formatters-\(UUID().uuidString)")
        XCTAssertTrue(FormatterConfig.load(from: missing).isEmpty)
    }

    // MARK: - Errors

    func testErrorMessagesAreSpecificAboutTheCause() {
        XCTAssertEqual(FormatError.invalidInput("JSON").userMessage, "Not valid JSON")
        XCTAssertEqual(FormatError.unchanged.userMessage, "Already formatted")
        XCTAssertEqual(FormatError.toolNotFound("jq").userMessage, "jq is not installed")
        XCTAssertEqual(FormatError.noFormatterAvailable(extension: "sql").userMessage,
                       "No formatter for .sql")
        XCTAssertEqual(FormatError.toolFailed(tool: "yq", exitCode: 1, message: "bad input\nmore")
                        .userMessage, "yq: bad input")
    }
}
