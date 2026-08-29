// SPDX-License-Identifier: Apache-2.0
// MainWindowController+MacroRecording.swift — turning what the user did by hand into macro steps (F-478).
//
// The macro recorder reads two records. The audit log is PCAutomation's own and needs no translation.
// The app's operation history (F-402) is the other one, and it is the one that holds F5, F6, F7, F8 and
// a rename in the panel — everything a person actually does, none of which goes through the Automation
// Core. Without it "Macro from Recent Actions…" was empty for anybody who had not switched the
// assistant on, which is most people, and the feature's own headline did not hold.
//
// The split is deliberate and follows the dependency direction. This file knows only how the *history*
// encodes an operation, which is the app's business; `RecordedAction.PanelOperation` knows what each
// operation is called in the catalogue, which is PCAutomation's, and can be tested there without a
// window.

import Foundation
import PCAutomation
import PCFoundation

/// `MainWindowController.logger` is private to its own file, and this is a different one.
private let logger = PCFoundationLogger.logger

extension MainWindowController {

    /// Everything worth offering as a macro step, from both records.
    ///
    /// `MacroRecorder` sorts by time, so the two lists are simply concatenated here — they interleave in
    /// practice (a copy by hand, then a rename through the assistant) and pre-merging them would only
    /// duplicate that.
    func recentActionsForMacro(limit: Int = 30) async -> [RecordedAction] {
        let audited = await automationCore.auditTrail(limit: limit).map(RecordedAction.init)
        return audited + Self.recordedPanelActions(HistoryService.shared.ranked(kind: .operation),
                                                   limit: limit)
    }

    /// The operation history as candidate actions.
    ///
    /// Only entries carrying a payload: the history also holds a *label* for what it cannot describe in
    /// enough detail to repeat — packing an archive, and anything routed through `.custom` — and a row
    /// offering one of those would be offering something this cannot build.
    static func recordedPanelActions(_ entries: [HistoryEntry], limit: Int) -> [RecordedAction] {
        entries
            .filter { $0.kind == .operation && !$0.payload.isEmpty }
            // By time, not by the history's own ranking: that one weighs how often an entry has been
            // used, which is right for a palette offering favourites and wrong for a list whose whole
            // question is "what did I just do".
            .sorted { $0.lastUsed > $1.lastUsed }
            .prefix(limit)
            .compactMap { entry in
                guard let operation = Self.operation(for: entry) else { return nil }
                return RecordedAction.panel(operation, summary: entry.detail, at: entry.lastUsed)
            }
    }

    /// One history entry as the operation it recorded.
    private static func operation(for entry: HistoryEntry) -> RecordedAction.PanelOperation? {
        if let pairs = HistoryOperation.decodeRenames(entry.payload) {
            return .rename(pairs: pairs, directory: entry.path)
        }
        guard let (kind, items, mask) = HistoryOperation.decodeAny(entry.payload) else { return nil }
        switch kind {
        case HistoryOperation.kindCopy, HistoryOperation.kindMove:
            // A copy that renamed as it went is dropped rather than approximated: `copy` and `move`
            // take no rename mask, and a macro that quietly copied without renaming would be a
            // different operation wearing the same row.
            guard mask == nil else { return nil }
            return kind == HistoryOperation.kindCopy
                ? .copy(items: items, destination: entry.path)
                : .move(items: items, destination: entry.path)
        case HistoryOperation.kindTrash:      return .trash(items)
        case HistoryOperation.kindDelete:     return .deletePermanently(items)
        case HistoryOperation.kindMakeDirectory:
            // One step per folder is what the catalogue offers, and a batch of new folders is rare
            // enough that the first is the one somebody means.
            return items.first.map { .makeDirectory($0) }
        case HistoryOperation.kindCreateFile:
            return items.first.map { .createFile($0) }
        default:
            return nil
        }
    }
}

extension MainWindowController {

    /// The panel state a recorded macro can be written in terms of.
    ///
    /// Only the two folders are filled in: the selection and the cursor are what `%S` and `%N` will
    /// mean *when the macro runs*, and putting today's values in here would invite exactly the
    /// substitution this must not make — folding a recorded path into `%N` because it happens to be
    /// the file under the cursor right now.
    func macroContextForRecording() async -> MacroContext {
        MacroContext(activeDirectory: activePanel?.directoryPath ?? "",
                     inactiveDirectory: getInactivePanel()?.directoryPath ?? "",
                     startedAt: Date())
    }
}

// MARK: - The explicit recording (start → do the work → stop)

// Reading the last thirty things that happened is one way into a macro and it cannot answer the
// question the user actually has — *where does it begin and where does it end*. This is the other way:
// the boundaries are pressed rather than guessed, and the list that comes back is only what happened
// between them.
//
// The panel operations are pushed in from `PanelController.recordInHistory` — the choke point every
// finished operation already passes — rather than read back out of the history afterwards. That is
// deliberate: the history can be switched off in Settings ▸ Interface, and a deliberate recording that
// silently records nothing because of an unrelated privacy setting is the defect this replaces.
extension MainWindowController {

    var isRecordingMacro: Bool { macroRecording.isRecording }

    /// cm_MacroRecord: start a recording, or stop the one that is running.
    func toggleMacroRecording() {
        if macroRecording.isRecording { stopMacroRecording() } else { startMacroRecording() }
    }

    func startMacroRecording() {
        guard !macroRecording.isRecording else { return }
        macroRecording.start()
        showMacroRecordingIndicator(resumed: false)
        // Written down immediately, not only at the next save point: the arming is the decision, and a
        // crash one minute in should come back to a running recording rather than to nothing.
        persistMacroRecording()
        Task { await refreshMacroRecordingCount() }
    }

    /// Put the indicator up and tell the manager window, for a recording that has just been armed or
    /// has just been picked back up after a restart.
    func showMacroRecordingIndicator(resumed: Bool) {
        let indicator = MacroRecordingIndicator()
        indicator.onStop = { [weak self] in self?.stopMacroRecording() }
        indicator.onCancel = { [weak self] in self?.cancelMacroRecording() }
        indicator.setResumed(resumed)
        macroRecordingIndicator = indicator
        indicator.present(relativeTo: window)
        macroManagerWindow?.recordingChanged(isRecording: true)
    }

    func cancelMacroRecording() {
        macroRecording.cancel()
        closeMacroRecordingIndicator()
        persistMacroRecording()
    }

    /// Stop, and put what was caught in front of the user as the steps of a new macro.
    ///
    /// The same sheet the "recent actions" path uses, because from here on the two are the same
    /// question — which of these should the macro repeat, and should it follow the panels. What differs
    /// is only where the list came from, and the sheet says so.
    func stopMacroRecording() {
        guard macroRecording.isRecording else { return }
        Task { @MainActor in
            let audit = await automationCore.auditTrail(limit: MacroRecordingSession.cap)
            let recorded = macroRecording.stop(mergingAudit: audit)
            closeMacroRecordingIndicator()
            persistMacroRecording()      // stopped: takes the file away
            let candidates = MacroRecorder.candidates(from: recorded)
            guard candidates.contains(where: \.isReplayable) else {
                presentMacroNotice(
                    String(localized: "The recording caught nothing that can be repeated."),
                    detail: String(localized: """
                        Copying, moving, renaming and deleting files, and creating folders, are what a \
                        macro can repeat. Browsing, selecting and opening files are not — they change \
                        nothing, so there is nothing to replay.
                        """))
                return
            }
            saveMacro(from: candidates, recorded: true)
        }
    }

    /// What the panels report while a recording is running.
    ///
    /// Takes the same three fields `HistoryService.recordOperation` takes, and is called from the same
    /// line, so an operation cannot reach one and miss the other.
    func noteForMacroRecording(label: String, directory: String, payload: String,
                               panel: HistoryPanelSide?) {
        guard macroRecording.isRecording, !payload.isEmpty else { return }
        let entry = HistoryEntry(kind: .operation, path: directory, detail: label, payload: payload,
                                 panel: panel)
        guard let operation = Self.operation(for: entry),
              let action = RecordedAction.panel(operation, summary: label, at: Date())
        else { return }
        macroRecording.record(action)
        persistMacroRecording()
        Task { await refreshMacroRecordingCount() }
    }

    /// The indicator's running total, including what the assistant has done inside the window.
    private func refreshMacroRecordingCount() async {
        guard macroRecording.isRecording else { return }
        let audit = await automationCore.auditTrail(limit: MacroRecordingSession.cap)
        guard macroRecording.isRecording else { return }
        macroRecordingIndicator?.update(
            count: macroRecording.count + macroRecording.automationActions(from: audit).count)
    }

    private func closeMacroRecordingIndicator() {
        macroRecordingIndicator?.close()
        macroRecordingIndicator = nil
        macroManagerWindow?.recordingChanged(isRecording: false)
    }
}

// MARK: - Surviving a quit

// A recording is armed by hand and then the user goes off and works. Quitting the app in the middle of
// that is not a decision to throw the recording away — and a crash certainly is not. So it is written
// down at every save point and picked up at the next launch: the indicator comes back saying it is
// still running, with the steps it had, and the user stops it or discards it as they meant to.
//
// The file is deleted the moment a recording ends, so its presence *is* the question. That also means
// a launch does no work at all in the ordinary case: one `fileExists` that says no.
extension MainWindowController {

    /// Write the running recording down, or take the file away when there is none.
    func persistMacroRecording() {
        let url = configPaths.macroRecording
        guard let resumable = macroRecording.resumable else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(resumable).write(to: url, options: .atomic)
        } catch {
            // Logged, not shown: this runs on the way out, where an alert is a modal nobody is present
            // to click (F-436). Losing the recording is bad; hanging the quit is worse.
            logger.error("macro recording could not be saved — \(String(describing: error))")
        }
    }

    /// Pick a recording back up, if one was left behind.
    func resumeMacroRecordingIfAny() {
        // Never over a recording that is already running: this is called during launch, and whatever
        // the user has started since is theirs. Belt as well as braces — the call site is early enough
        // that it cannot happen — because the failure it prevents is silent.
        guard !macroRecording.isRecording else { return }
        let url = configPaths.macroRecording
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        defer { try? FileManager.default.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let restored = try? decoder.decode(MacroRecordingSession.self, from: data),
              restored.isRecording
        else { return }
        macroRecording = restored
        showMacroRecordingIndicator(resumed: true)
        Task { await refreshMacroRecordingCount() }
    }
}
