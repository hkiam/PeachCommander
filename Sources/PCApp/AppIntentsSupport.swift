// SPDX-License-Identifier: Apache-2.0
// AppIntentsSupport.swift — native App Intents for Shortcuts / Siri / Spotlight (F-296).
//
// Same core verbs as the AppleScript dictionary, exposed as first-class App Intents so
// they appear as native actions in the Shortcuts app and can be invoked by Siri and
// Spotlight. Each intent is a thin adapter over MainWindowController's script helpers
// (the same audited seam the menus and the automation core use). AppShortcutsProvider
// surfaces a starter set with spoken phrases.

import AppIntents
import AppKit

enum PCIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case appNotRunning
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .appNotRunning: return "Open Peach Commander first, then run this action."
        }
    }
}

/// Which panel an action targets.
enum PanelSideAppEnum: String, AppEnum {
    case active, left, right
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Panel"
    static var caseDisplayRepresentations: [PanelSideAppEnum: DisplayRepresentation] = [
        .active: "Active panel", .left: "Left panel", .right: "Right panel",
    ]
    var side: Int? { self == .left ? 0 : self == .right ? 1 : nil }
}

@MainActor private func host() throws -> MainWindowController {
    guard let h = MainWindowController.shared else { throw PCIntentError.appNotRunning }
    return h
}
private func expand(_ path: String) -> String { (path as NSString).expandingTildeInPath }

// MARK: - Intents

struct OpenFolderInPanelIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Folder in Panel"
    static var description = IntentDescription("Navigate a Peach Commander panel to a folder.")
    static var openAppWhenRun = true

    @Parameter(title: "Folder path") var folder: String
    @Parameter(title: "Panel") var panel: PanelSideAppEnum?

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$folder) in \(\.$panel)")
    }

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try host().scriptGoTo(path: expand(folder), side: (panel ?? .active).side)
        return .result(value: result)
    }
}

struct SelectItemsIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Items by Mask"
    static var description = IntentDescription("Select items in the active panel by a wildcard mask.")
    static var openAppWhenRun = true

    @Parameter(title: "Mask", default: "*") var mask: String

    static var parameterSummary: some ParameterSummary { Summary("Select \(\.$mask)") }

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        .result(value: try host().scriptSelect(mask: mask))
    }
}

struct CopySelectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy Selection to Folder"
    static var description = IntentDescription("Copy the active panel's selection to a folder.")
    static var openAppWhenRun = true

    @Parameter(title: "Destination folder") var destination: String

    static var parameterSummary: some ParameterSummary { Summary("Copy selection to \(\.$destination)") }

    @MainActor func perform() async throws -> some IntentResult {
        try host().scriptTransferSelection(copy: true, to: expand(destination))
        return .result()
    }
}

struct MoveSelectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Move Selection to Folder"
    static var description = IntentDescription("Move the active panel's selection to a folder.")
    static var openAppWhenRun = true

    @Parameter(title: "Destination folder") var destination: String

    static var parameterSummary: some ParameterSummary { Summary("Move selection to \(\.$destination)") }

    @MainActor func perform() async throws -> some IntentResult {
        try host().scriptTransferSelection(copy: false, to: expand(destination))
        return .result()
    }
}

struct RunCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Command"
    static var description = IntentDescription("Run a Peach Commander command by its id (cm_*).")
    static var openAppWhenRun = true

    @Parameter(title: "Command id") var commandID: String

    static var parameterSummary: some ParameterSummary { Summary("Run command \(\.$commandID)") }

    @MainActor func perform() async throws -> some IntentResult {
        try host().scriptRunCommand(commandID)
        return .result()
    }
}

struct ActiveFolderIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Active Folder"
    static var description = IntentDescription("Return the path of the active panel's folder.")
    static var openAppWhenRun = false

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: try host().scriptActiveFolder)
    }
}

// MARK: - App Shortcuts (spoken phrases for Siri / Spotlight)

struct PeachCommanderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ActiveFolderIntent(),
                    phrases: ["Active folder in \(.applicationName)"],
                    shortTitle: "Active Folder", systemImageName: "folder")
        AppShortcut(intent: OpenFolderInPanelIntent(),
                    phrases: ["Open a folder in \(.applicationName)"],
                    shortTitle: "Open Folder", systemImageName: "folder.badge.gearshape")
        AppShortcut(intent: SelectItemsIntent(),
                    phrases: ["Select items in \(.applicationName)"],
                    shortTitle: "Select by Mask", systemImageName: "checkmark.circle")
        AppShortcut(intent: CopySelectionIntent(),
                    phrases: ["Copy the selection in \(.applicationName)"],
                    shortTitle: "Copy Selection", systemImageName: "doc.on.doc")
        AppShortcut(intent: RunCommandIntent(),
                    phrases: ["Run a command in \(.applicationName)"],
                    shortTitle: "Run Command", systemImageName: "terminal")
    }
}
