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
