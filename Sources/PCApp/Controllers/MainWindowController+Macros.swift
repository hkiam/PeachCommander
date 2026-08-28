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

    /// Read the macros and register one command per macro. Called at startup.
    ///
    /// Silent about problems on purpose: this runs during launch, and an alert there is the thing
    /// F-436 was about — a modal nobody is present to click turns a start into a hang. They are
    /// logged here and shown by `reloadMacrosFromDisk`, which is the path an *edit* takes.
    func loadMacros() { applyMacros(readMacros(), announcingProblems: false) }

    /// Re-read `macros.json` and re-register, if anything changed.
    ///
    /// Compared on the decoded macros rather than the file's bytes: the editor rewrites the whole file
    /// with sorted keys, so a save that changed nothing still changes the text, and re-registering the
    /// command table on every activation would be work for nothing. The *problems* are part of that
    /// comparison, so saving a file that is still broken says so again rather than once.
    func reloadMacrosFromDisk() {
        let loaded = readMacros()
        guard loaded.macros != lastLoadedMacros || loaded.problems != lastMacroProblems else { return }
        applyMacros(loaded, announcingProblems: true)
    }

    /// The macros on disk, with everything wrong with them that can be seen without running one.
    ///
    /// Two kinds of problem, deliberately merged into one list: `MacroStore` reports the entries it
    /// had to *drop* (an unusable id, a duplicate, a file that is not a list at all), and
    /// `MacroPlan.problems` reports the steps of the ones it kept — a misspelled tool, a missing
    /// required argument. From the reader's side both are "this macro will not do what you wrote",
    /// and both are found at the moment they can still be fixed cheaply: the editor is open.
    private func readMacros() -> (macros: [Macro], problems: [String]) {
        var (macros, problems) = macroStore.load()
        let tools = automationCore.tools
        for macro in macros {
            problems += MacroPlan.problems(of: macro, tools: tools).map { "\(macro.id): \($0)" }
        }
        return (macros, problems)
    }

    private func applyMacros(_ loaded: (macros: [Macro], problems: [String]),
                             announcingProblems: Bool) {
        lastLoadedMacros = loaded.macros
        lastMacroProblems = loaded.problems
        for problem in loaded.problems { logger.error("macros.json: \(problem)") }
        let entries = loaded.macros.map { macro -> (name: String, title: String, handler: CommandHandler) in
            let id = macro.id
            return (name: macro.commandName, title: macro.title,
                    handler: { [weak self] _ in await self?.runMacro(id: id) })
        }
        Task { await commandRegistry.setMacroCommands(entries) }
        guard announcingProblems, !loaded.problems.isEmpty else { return }
        // Said out loud, because the alternative is what this used to do: drop the entry, write one
        // line to a log nobody has open, and leave the user looking at a button that does nothing.
        presentMacroNotice(String(localized: "Some macros could not be used."),
                           detail: loaded.problems.joined(separator: "\n"))
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
            // A refusal is about permissions, not about the macro being wrong, so it names where the
            // setting is instead of only reporting the wall. That the setting sits on the AI page is
            // worth saying out loud: macros and the assistant share one permission model, and somebody
            // who set that page to read-only to keep the assistant quiet has switched their own macros
            // off without being told so anywhere.
            presentMacroProblem(
                String(localized: "This macro is not allowed to run."),
                detail: reason + "\n\n" + String(localized: """
                    Macros are held to the same permissions as the assistant. \
                    Settings ▸ AI ▸ “What either assistant may do” is where they are set.
                    """))
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

    /// cm_MacroEditor: edit `macros.json` in the built-in editor, seeding the shipped examples first.
    ///
    /// A file, not a form — the same answer the Start menu gets (`showEditMainMenu`). A macro is a list
    /// of tool names and arguments, which is what JSON is; a form over it would be a worse editor than
    /// the one the app already has, and it would need a control per tool in the catalogue. The examples
    /// in `MacroSeed` and the recorder below are the two on-ramps, so nobody has to start from an empty
    /// file — and a broken edit is reported when it is saved, by `reloadMacrosFromDisk`.
    func showMacroEditor() {
        let url = configPaths.macros
        if !FileManager.default.fileExists(atPath: url.path) {
            // The shipped examples (`MacroSeed`), written once and the user's afterwards. Only when
            // there is no file at all: a user who has one macro of their own must not have seven
            // appear under it because they opened the editor.
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? MacroSeed.json.write(to: url, atomically: true, encoding: .utf8)
            // Registered right away, so the examples are in the Command Browser and the button-bar
            // picker while the editor is still open — which is where somebody reads them and then
            // goes looking for them.
            reloadMacrosFromDisk()
        }
        openEditor(path: url.path, onSaved: { [weak self] in self?.reloadMacrosFromDisk() })
    }

    /// cm_MacroFromRecentActions: offer what the assistant and earlier macros have just done as the
    /// steps of a new macro.
    func showMacroFromRecentActions() {
        Task { @MainActor in
            let candidates = MacroRecorder.candidates(from: await recentActionsForMacro())
            guard candidates.contains(where: \.isReplayable) else {
                presentMacroNotice(
                    String(localized: "There is nothing to make a macro from yet."),
                    detail: String(localized: """
                        A macro is built from what has already happened — files you have copied, moved, \
                        renamed or deleted, and anything the assistant did. Do one of those first, then \
                        come back.
                        """))
                return
            }
            // The panels as they are *now*, which is what "follow the panels" has to mean: the folder
            // an entry was recorded in may be nowhere in sight, and a macro written against a folder
            // the user is not looking at is the guess this feature must not make.
            let context = await macroContextForRecording()
            guard let result = MacroRecorderSheet.present(candidates: candidates,
                                                          existingIDs: macroStore.macros().map(\.id),
                                                          context: context,
                                                          in: window) else { return }
            let macro = MacroRecorder.macro(id: result.id, title: result.title,
                                            from: candidates, keeping: result.kept,
                                            following: result.followsPanels ? context : nil)
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

    /// cm_MacroManager: the macros as a list — rename, duplicate, reorder, delete (F-478).
    ///
    /// One window, kept alive while it is open, because it is a list the user works down rather than a
    /// question with an answer. It writes through the same `MacroStore` the editor's save path reads,
    /// so the two cannot get out of step.
    func showMacroManager() {
        if let existing = macroManagerWindow {
            existing.reload()
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let manager = MacroManagerWindowController(store: macroStore)
        manager.onChanged = { [weak self] in self?.reloadMacrosFromDisk() }
        manager.onAddButton = { [weak self] macro in self?.addButtonForMacro(macro) }
        manager.onEditFile = { [weak self] in self?.showMacroEditor() }
        manager.onRemoveButtons = { [weak self] names in
            self?.removeButtonsRunning(names) ?? 0
        }
        macroManagerWindow = manager
        manager.showWindow(nil)
        manager.window?.makeKeyAndOrderFront(nil)
    }

    /// Take every button whose command is one of `names` out of the button bar. Returns how many went.
    ///
    /// Through the same `.bar` serialiser the adding side uses, so a user's own bar keeps its format
    /// rather than being rewritten into something else.
    func removeButtonsRunning(_ names: [String]) -> Int {
        let url = configPaths.buttonBar
        var bar = ButtonBar(parsing: WindowsTextFile.read(url) ?? "")
        let before = bar.buttons.count
        bar.buttons.removeAll { names.contains($0.cmd) }
        let removed = before - bar.buttons.count
        guard removed > 0 else { return 0 }
        do {
            try bar.serialize().write(to: url, atomically: true, encoding: .utf8)
            loadButtonBar()
        } catch {
            logger.error("macro: could not rewrite the button bar — \(String(describing: error))")
            return 0
        }
        return removed
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

}
