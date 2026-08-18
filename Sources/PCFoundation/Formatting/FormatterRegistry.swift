// SPDX-License-Identifier: Apache-2.0
// FormatterRegistry.swift - Resolves a formatter for a file extension.
//
// Resolution order, first available wins:
//
//   1. user-configured tool for that extension   (formatters.ini — always beats the rest)
//   2. plugin formatters                          (registered by the host at load time)
//   3. installed external tools                   (yq, taplo, prettier, jq, xmllint, …)
//   4. built-ins                                  (JSON, XML, HTML, INI, YAML tidy)
//
// The user is first on purpose: someone who configured `swiftformat` for .swift has said
// what they want. Built-ins are last so an installed, format-specific tool takes over
// automatically — that is what makes the feature grow without code changes.

import Foundation

public final class FormatterRegistry: @unchecked Sendable {
    /// The registry the app uses. Plugins register into this at load time.
    public static let shared = FormatterRegistry()

    private let lock = NSLock()
    private var userConfigured: [TextFormatter] = []
    private var pluginProvided: [TextFormatter] = []
    private var external: [TextFormatter]
    private var builtIn: [TextFormatter]

    public init(external: [TextFormatter]? = nil, builtIn: [TextFormatter]? = nil) {
        self.external = external ?? DefaultExternalFormatters.all()
        self.builtIn = builtIn ?? [
            JSONFormatter(), JSONLinesFormatter(), XMLFormatter(), HTMLFormatter(), INIFormatter(),
            YAMLTidyFormatter()
        ]
    }

    // MARK: - Registration

    /// Add formatters a plugin contributes. Ahead of the external tools and built-ins, behind
    /// the user's own configuration.
    public func registerPlugin(_ formatters: [TextFormatter]) {
        lock.lock(); pluginProvided.append(contentsOf: formatters); lock.unlock()
    }

    /// Replace the user-configured formatters (called when formatters.ini is loaded or edited).
    public func setUserConfigured(_ formatters: [TextFormatter]) {
        lock.lock(); userConfigured = formatters; lock.unlock()
    }

    /// Drop everything a plugin registered — used when plugins are reloaded.
    public func removePluginFormatters() {
        lock.lock(); pluginProvided.removeAll(); lock.unlock()
    }

    // MARK: - Lookup

    /// Every candidate for `ext`, in resolution order, whether available or not.
    public func candidates(for ext: String) -> [TextFormatter] {
        lock.lock()
        let all = userConfigured + pluginProvided + external + builtIn
        lock.unlock()
        return all.filter { $0.handles(extension: ext) }
    }

    /// The formatter that would run for `ext`, or nil when none is available.
    public func formatter(for ext: String) -> TextFormatter? {
        candidates(for: ext).first { $0.isAvailable }
    }

    /// Whether anything can format `ext` — for enabling the Format action.
    public func canFormat(extension ext: String) -> Bool { formatter(for: ext) != nil }

    /// Extensions with at least one available formatter, for settings UI and diagnostics.
    public func availableExtensions() -> [String] {
        lock.lock()
        let all = userConfigured + pluginProvided + external + builtIn
        lock.unlock()
        return Array(Set(all.filter(\.isAvailable).flatMap(\.supportedExtensions))).sorted()
    }

    // MARK: - Formatting

    /// Format `text` for `ext`.
    ///
    /// Candidates are tried in order and a `.toolNotFound` or `.invalidInput` failure falls
    /// through to the next one — an installed tool that rejects the file should not stop the
    /// built-in from trying. `.unchanged` is returned as-is, because "already formatted" is an
    /// answer rather than a failure to route around.
    public func format(_ text: String, extension ext: String) throws -> (text: String, formatter: String) {
        let candidates = self.candidates(for: ext)
        guard !candidates.isEmpty else { throw FormatError.noFormatterAvailable(extension: ext) }

        var firstError: FormatError?
        for candidate in candidates where candidate.isAvailable {
            do {
                return (try candidate.format(text), candidate.name)
            } catch let error as FormatError {
                if case .unchanged = error { throw error }
                if firstError == nil { firstError = error }
                continue
            }
        }
        throw firstError ?? .noFormatterAvailable(extension: ext)
    }
}
