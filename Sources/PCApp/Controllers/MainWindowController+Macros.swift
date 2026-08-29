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

    var macroStore: MacroStore {
        MacroStore(directory: configPaths.macrosDirectory, legacyFile: configPaths.legacyMacrosFile)
    }

    /// Read the macros and register one command per macro. Called at startup.
    ///
    /// Silent about problems on purpose: this runs during launch, and an alert there is the thing
    /// F-436 was about — a modal nobody is present to click turns a start into a hang. They are
    /// logged here and shown by `reloadMacrosFromDisk`, which is the path an *edit* takes.
    func loadMacros() {
        // Before the first read, and only ever once: a `macros.json` from before macros became one
        // file each is moved across and renamed out of the way. Silent, because it is not a decision
        // the user makes and there is nothing for them to do about it — the old file is still there,
        // under `.migrated`, if they want to look (F-478).
        if macroStore.migrateIfNeeded() {
            logger.info("macros: macros.json was moved to macros/ and renamed .migrated")
        }
        applyMacros(readMacros(), announcingProblems: false)
    }

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
            // The Core's `plan` is English and stays so — an MCP client reads that same string. The
            // sentence above the rows is for a person, so the host writes it, out of the macro it
            // already knows it is running. Falls back to the Core's when the macro cannot be found,
            // which is a state `refusalBeforeAsking` should already have caught.
            // Interpolated rather than `String(format:)` over a fetched format: the catalogue entry
            // carries plural variations, and `%#@…@` is expanded by the *lookup*, which therefore has
            // to be the thing that knows the count. Fetching the format first and formatting it
            // afterwards hands `String(format:)` a specifier it does not understand. This read
            // "— 2 step(s)." in every language until it did, the parenthetical having been carried
            // into thirteen translations that inflect the noun properly.
            let heading = macroStore.macro(id: id).map {
                String(localized: "Run the macro “\($0.title)” — \($0.steps.count) steps.")
            } ?? plan
            guard let decision = MacroConfirmSheet.present(plan: heading, rows: rows,
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
    /// Files, not a form — the same answer the Start menu gets (`showEditMainMenu`). A macro is a list
    /// of tool names and arguments, which is what JSON is; a form over it would be a worse editor than
    /// the one the app already has, and it would need a control per tool in the catalogue. The examples
    /// in `MacroSeed` and the recorder are the two on-ramps, so nobody has to start from an empty
    /// folder — and a broken edit is reported when it is saved, by `reloadMacrosFromDisk`.
    ///
    /// With one file per macro there is no single file to open, so this shows the *folder* in the
    /// active panel: F3 reads one, F4 edits one, and F8 deletes one. Which is the app doing what it is
    /// for, rather than a second, worse file browser inside a dialog. Editing one macro directly is
    /// what the manager's **Edit File…** is for, because there a macro is selected.
    func showMacroEditor() {
        seedMacrosIfEmpty()
        Task { @MainActor in
            await activePanel?.loadDirectory(configPaths.macrosDirectory.path)
        }
    }

    /// Write the shipped examples, once, into an empty (or absent) macros folder.
    ///
    /// Only when there is nothing there: a user with one macro of their own must not find eight more
    /// under it because they opened the folder.
    func seedMacrosIfEmpty() {
        let directory = configPaths.macrosDirectory
        guard macroStore.macros().isEmpty else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Written as the seed's own text, not encoded from `Macro` values: each example carries a
        // `_comment` explaining what it does and what to change, and an encoder drops every key the
        // type does not declare. `_readme.json` comes with them — no steps, so it is not a command,
        // and it is the thing a new user opens first.
        for file in MacroSeed.files() {
            let url = directory.appendingPathComponent(file.name)
            guard !FileManager.default.fileExists(atPath: url.path) else { continue }
            try? file.data.write(to: url, options: .atomic)
        }
        // Registered right away, so the examples are in the Command Browser and the button-bar picker
        // while the folder is still open — which is where somebody reads them and then goes looking.
        reloadMacrosFromDisk()
    }

    /// Open one macro's own file in the built-in editor.
    func editMacroFile(_ macro: Macro) {
        openEditor(path: macroStore.file(for: macro.id).path,
                   onSaved: { [weak self] in
                       self?.reloadMacrosFromDisk()
                       self?.macroManagerWindow?.reload()
                   })
    }

    /// cm_MacroFromRecentActions: offer what the assistant and earlier macros have just done as the
    /// steps of a new macro.
    func showMacroFromRecentActions() {
        Task { @MainActor in
            let candidates = MacroRecorder.candidates(from: await recentActionsForMacro())
            guard candidates.contains(where: \.isReplayable) else {
                presentMacroNotice(String(localized: "There is nothing to make a macro from yet."),
                                   detail: nothingRecentDetail())
                return
            }
            saveMacro(from: candidates, recorded: false)
        }
    }

    /// Why the list is empty, in the terms of whichever cause it actually was.
    ///
    /// This is the failure the feature shipped with. Everything the user does by hand is read back out
    /// of the operation history — and the history can be switched off, at which point the recorder went
    /// on reporting "do one of those first" to somebody who had just done four of them. A wrong
    /// diagnosis is worse than no diagnosis: it sends the user off to repeat work that was never going
    /// to be recorded. So when the history is off, that is what it says, and it names the switch.
    private func nothingRecentDetail() -> String {
        guard HistoryService.shared.isRecordingEnabled else {
            return String(localized: """
                What you do in the panels is read back out of the history, and the history is switched \
                off — so nothing you did by hand was kept. Settings ▸ Misc ▸ “Record a global history” \
                is the switch. Or use “Record Macro…”, which records into the macro itself and does not \
                need the history at all.
                """)
        }
        return String(localized: """
            A macro is built from what has already happened — files you have copied, moved, renamed or \
            deleted, and anything the assistant did. Do one of those first, then come back — or use \
            “Record Macro…”, which marks the beginning and the end itself.
            """)
    }

    /// Put `candidates` in front of the user and save what they keep.
    ///
    /// Shared by both ways in — the explicit recording and the read of what recently happened — because
    /// from this point on they are the same question. `recorded` only changes what the sheet says it is
    /// showing.
    func saveMacro(from candidates: [MacroRecorder.Candidate], recorded: Bool) {
        Task { @MainActor in
            // The panels as they are *now*, which is what "follow the panels" has to mean: the folder
            // an entry was recorded in may be nowhere in sight, and a macro written against a folder
            // the user is not looking at is the guess this feature must not make.
            let context = await macroContextForRecording()
            guard let result = MacroRecorderSheet.present(candidates: candidates,
                                                          existingIDs: macroStore.macros().map(\.id),
                                                          context: context,
                                                          fromRecording: recorded,
                                                          in: window) else { return }
            let macro = MacroRecorder.macro(id: result.id, title: result.title,
                                            from: candidates, keeping: result.kept,
                                            following: result.followsPanels ? context : nil)
            guard !macro.steps.isEmpty else { return }
            do {
                try macroStore.upsert(macro)
                reloadMacrosFromDisk()
                if result.addsButton { addButtonForMacro(macro) }
                macroManagerWindow?.reload()
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
            existing.recordingChanged(isRecording: isRecordingMacro)
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let manager = MacroManagerWindowController(store: macroStore)
        manager.onChanged = { [weak self] in self?.reloadMacrosFromDisk() }
        manager.onAddButton = { [weak self] macro in self?.addButtonForMacro(macro) }
        manager.onEditFile = { [weak self] macro in
            guard let self else { return }
            // With a macro selected the button means "edit *this* one", which is what it could not mean
            // while they all lived in one file. With none selected it falls back to showing the folder
            // in the panel, which is the honest answer to "the file" when there are eight of them.
            if let macro { editMacroFile(macro) } else { showMacroEditor() }
        }
        manager.onRemoveButtons = { [weak self] names in
            self?.removeButtonsRunning(names) ?? 0
        }
        manager.onToggleRecording = { [weak self] in
            guard let self else { return }
            // Starting closes this window, because the recording happens in the panels and a floating
            // list of macros over them is in the way. The indicator takes its place and is the thing
            // that stops it. Stopping keeps the window: the sheet it opens belongs over the list the
            // new macro is about to appear in.
            let starting = !self.isRecordingMacro
            self.toggleMacroRecording()
            if starting { self.macroManagerWindow?.close() }
        }
        manager.onMacroFromRecentActions = { [weak self] in self?.showMacroFromRecentActions() }
        manager.onRun = { [weak self] macro in
            guard let self else { return }
            Task { await self.runMacro(id: macro.id) }
        }
        manager.isRecording = isRecordingMacro
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

    func presentMacroNotice(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: String(localized: "OK"))
        if let window { alert.beginSheetModal(for: window) } else { alert.runModal() }
    }

}
