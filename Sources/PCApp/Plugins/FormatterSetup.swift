// SPDX-License-Identifier: Apache-2.0
// FormatterSetup.swift - Populates FormatterRegistry from the user's config and the
// enabled plugins.
//
// The registry itself knows nothing about the app: it holds formatters and resolves them by
// extension. This is the wiring that fills it, so the resolution order in FormatterRegistry
// (user config → plugins → installed tools → built-ins) actually reflects what is present.

import Foundation
import PCFoundation
import PCPluginHost

enum FormatterSetup {
    /// Load `formatters.ini`. Called at startup and whenever the file may have changed.
    static func refreshUserFormatters(configRoot: URL) {
        let formatters = FormatterConfig.load(from: configRoot)
        FormatterRegistry.shared.setUserConfigured(formatters)
        if !formatters.isEmpty {
            let summary = formatters
                .map { "\($0.supportedExtensions.joined(separator: "/"))→\($0.name)" }
                .joined(separator: ", ")
            PCFoundationLogger.logger.info("User formatters: \(summary, privacy: .public)")
        }
    }

    /// Rebuild the plugin-provided formatters from the currently enabled contributions.
    ///
    /// Replaces the whole set rather than adding to it, because plugins can be enabled and
    /// disabled at runtime and a stale formatter would keep claiming its extension.
    @MainActor
    static func refreshPluginFormatters(host: ContributionHost) {
        FormatterRegistry.shared.removePluginFormatters()

        var formatters: [TextFormatter] = []
        for tool in ContributionRegistry.shared.allTools() where !tool.formatsExtensions.isEmpty {
            formatters.append(PluginTextFormatter(
                toolName: tool.name,
                displayName: tool.description.isEmpty ? tool.name : tool.description,
                extensions: tool.formatsExtensions,
                host: { [weak host] in host }))
        }
        guard !formatters.isEmpty else { return }
        FormatterRegistry.shared.registerPlugin(formatters)
        PCFoundationLogger.logger.info(
            "Plugin formatters: \(formatters.map(\.name).joined(separator: ", "), privacy: .public)")
    }

    /// Write a commented `formatters.ini` template if none exists, so the feature is
    /// discoverable by opening the config directory rather than only from the docs.
    static func ensureTemplate(at url: URL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FormatterConfig.template().write(to: url, atomically: true, encoding: .utf8)
    }
}
