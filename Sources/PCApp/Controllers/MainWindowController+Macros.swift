// SPDX-License-Identifier: Apache-2.0
// MainWindowController+Macros.swift — macros as first-class commands (F-478).
//
// A macro's *behaviour* lives in PCAutomation, where it can be tested without a window. This file is
// the part that cannot: turning each saved macro into a `mc_<id>` entry in the command registry, so it
// appears — with no further work anywhere — in the Command Browser, the shortcut editor, the button
// bar's command picker, `.mnu` resolution and the assistant's `run_command`. All of those read
// `commandRegistry.getAllCommands()`, which is the whole reason macros are commands rather than a
// feature with its own menu.

import AppKit
import PCAutomation
import PCCommands
import PCFoundation

/// `MainWindowController.logger` is private to its own file, and this is a different one.
private let logger = PCFoundationLogger.logger

extension MainWindowController {

    var macroStore: MacroStore { MacroStore(url: configPaths.macros) }

    /// Read the macros and register one command per macro. Called at startup and after every edit.
    func loadMacros() {
        let (macros, problems) = macroStore.load()
        for problem in problems { logger.error("macros.json: \(problem)") }
        let entries = macros.map { macro -> (name: String, title: String, handler: CommandHandler) in
            let id = macro.id
            return (name: macro.commandName, title: macro.title,
                    handler: { [weak self] _ in await self?.runMacro(id: id) })
        }
        Task { await commandRegistry.setMacroCommands(entries) }
    }

    /// Re-read `macros.json` and re-register, if anything changed.
    ///
    /// Compared on the decoded macros rather than the file's bytes: the editor rewrites the whole file
    /// with sorted keys, so a save that changed nothing still changes the text, and re-registering the
    /// command table on every activation would be work for nothing.
    func reloadMacrosFromDisk() {
        let macros = macroStore.macros()
        guard macros != lastLoadedMacros else { return }
        lastLoadedMacros = macros
        loadMacros()
    }

    /// Run one macro through the Automation Core.
    ///
    /// Everything that decides whether this is allowed — the capability, the confirmation, the audit
    /// entry per step — happens inside the Core. This method's whole job is to ask, to put the plan in
    /// front of the user when the Core asks for one, and to say what happened.
    func runMacro(id: String) async {
        let policy = await currentAutonomyPolicy()
        let arguments = try? JSONSerialization.data(withJSONObject: ["macro_id": id])
        do {
            let outcome = try await automationCore.invoke(tool: "run_macro", arguments: arguments,
                                                          policy: policy)
            await handleMacroOutcome(outcome, id: id)
        } catch {
            presentMacroProblem(String(localized: "The macro could not be run."),
                                detail: String(describing: error))
        }
    }

    private func handleMacroOutcome(_ outcome: AutomationOutcome, id: String) async {
        switch outcome {
        case .ok:
            break                                   // the steps' own progress and panels are the result
        case .refused(let reason):
            // A refusal is about permissions, not about the macro being wrong, so it points at where
            // the setting is instead of only reporting the wall.
            presentMacroProblem(String(localized: "This macro is not allowed to run."), detail: reason)
        case .failed(let error):
            presentMacroProblem(String(localized: "The macro did not finish."), detail: error)
        case .needsConfirmation(let plan, let token):
            let rows = await automationCore.planItems(token: token)
            guard let decision = MacroConfirmSheet.present(plan: plan, rows: rows,
                                                           in: window) else {
                // Cancelled. The token is left unconfirmed and expires with the session; nothing ran.
                return
            }
            do {
                let result = try await automationCore.confirm(token: token, rejecting: decision)
                await handleMacroOutcome(result, id: id)
            } catch {
                presentMacroProblem(String(localized: "The macro could not be run."),
                                    detail: String(describing: error))
            }
        }
    }

    private func presentMacroProblem(_ message: String, detail: String) {
        logger.error("macro: \(message) — \(detail)")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: String(localized: "OK"))
        if let window { alert.beginSheetModal(for: window) } else { alert.runModal() }
    }
}

// MARK: - Building and editing macros

extension MainWindowController {

    /// cm_MacroEditor: edit `macros.json` in the built-in editor, seeding a commented example first.
    ///
    /// A file, not a form — the same answer the Start menu gets (`showEditMainMenu`). A macro is a list
    /// of tool names and arguments, which is what JSON is; a form over it would be a worse editor than
    /// the one the app already has, and it would need a control per tool in the catalogue. The recorder
    /// below is the on-ramp, so nobody has to start from an empty file.
    func showMacroEditor() {
        let url = configPaths.macros
        if !FileManager.default.fileExists(atPath: url.path) {
            try? Self.macroTemplate().write(to: url, atomically: true, encoding: .utf8)
        }
        openEditor(path: url.path, onSaved: { [weak self] in self?.reloadMacrosFromDisk() })
    }

    /// cm_MacroFromRecentActions: offer what the assistant and earlier macros have just done as the
    /// steps of a new macro.
    func showMacroFromRecentActions() {
        Task { @MainActor in
            let entries = await automationCore.auditTrail(limit: 30)
            let candidates = MacroRecorder.candidates(from: entries)
            guard candidates.contains(where: \.isReplayable) else {
                // Said plainly, including *why* there might be nothing: manual panel work is not in the
                // log, and a user who just copied a folder with F5 would otherwise read this as a bug.
                presentMacroNotice(
                    String(localized: "There is nothing to make a macro from yet."),
                    detail: String(localized: """
                        A macro is built from actions that went through the assistant or another macro. \
                        Copying, moving or renaming in the panels by hand is not recorded, so it cannot \
                        be turned into a macro.
                        """))
                return
            }
            guard let result = MacroRecorderSheet.present(candidates: candidates,
                                                          existingIDs: macroStore.macros().map(\.id),
                                                          in: window) else { return }
            let macro = MacroRecorder.macro(id: result.id, title: result.title,
                                            from: candidates, keeping: result.kept)
            guard !macro.steps.isEmpty else { return }
            do {
                try macroStore.upsert(macro)
                reloadMacrosFromDisk()
                if result.addsButton { addButtonForMacro(macro) }
            } catch {
                presentMacroProblem(String(localized: "The macro could not be saved."),
                                    detail: String(describing: error))
            }
        }
    }

    /// Append a button running `macro` to the default button bar and reload the strip.
    ///
    /// Written through the existing `.bar` serialiser, so the file stays the Total Commander format the
    /// rest of the button bar reads and a user's own bar is not rewritten into something else.
    func addButtonForMacro(_ macro: Macro) {
        let url = configPaths.buttonBar
        var bar = ButtonBar(parsing: WindowsTextFile.read(url) ?? "")
        bar.buttons.append(BarButton(icon: macro.icon ?? "wand.and.stars",
                                     cmd: macro.commandName, param: "", path: "",
                                     menu: macro.title, iconic: false))
        do {
            try bar.serialize().write(to: url, atomically: true, encoding: .utf8)
            loadButtonBar()
        } catch {
            presentMacroProblem(String(localized: "The button could not be added."),
                                detail: String(describing: error))
        }
    }

    private func presentMacroNotice(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: String(localized: "OK"))
        if let window { alert.beginSheetModal(for: window) } else { alert.runModal() }
    }

    /// The seed file: a comment explaining the shape, and one macro that does something useful.
    ///
    /// JSON has no comments, so the explanation lives in a `_comment` key the decoder ignores — the
    /// same trick the `.mnu` and `usercmd.ini` seeds use with `;`, in the one form this format allows.
    private static func macroTemplate() -> String {
        """
        [
          {
            "id": "_readme",
            "title": "How this file works (delete this entry)",
            "steps": [],
            "_comment": [
              "A macro is a list of steps. Each step names a tool and its arguments.",
              "Run 'Configuration > Command Browser' to see the tools; 'list_macros' lists these.",
              "Placeholders in an argument:",
              "  %P  the active panel's folder        %T  the other panel's folder",
              "  %N  the file under the cursor        %S  the selected files (a list)",
              "A macro can select its own files: a set_selection step replaces the selection with",
              "everything matching a mask, and stops the macro if nothing matches.",
              "  %{date:yyyy-MM}  today, formatted    %{1}  the result of step 1",
              "A step whose list placeholder comes out empty stops the macro instead of doing nothing.",
              "Each macro becomes a command called mc_<id>, so it can go on a button, in the Start",
              "menu, or on a key — see 'Configuration > Edit Shortcuts'."
            ]
          },
          {
            "id": "stage-by-month",
            "title": "File the selection into a dated folder",
            "icon": "calendar",
            "steps": [
              { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
              { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
              { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
            ]
          }
        ]

        """
    }
}
