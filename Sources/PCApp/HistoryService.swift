// SPDX-License-Identifier: Apache-2.0
// HistoryService.swift - The one place the app records what the user did (F-402).
//
// The palette needs an answer the instant ⌘⇧H is pressed, so the list lives on the main actor and is
// read synchronously; the file behind it is written by a `ConfigStore`, which debounces and writes
// atomically off the main thread. That split is the same one `ConfigSnapshot` makes for everything the
// user can see: a suspension point between a keystroke and a window is a visible delay.
//
// Recording is deliberately a handful of one-line calls at *choke points* rather than at each of the
// dozens of places that can lead to them: every panel navigation goes through `PanelController.loadPath`,
// every completed operation through the same places that register an undo, every command line through
// `CommandLineView.run`. A recorder attached to each call site instead would have been wrong within a
// week — that is exactly how the drive bar came to disagree with the panel.

import AppKit
import PCFoundation

@MainActor
final class HistoryService {
    static let shared = HistoryService()

    /// Default size, overridable with `History.MaxEntries`. 500 is about a fortnight of heavy use, and
    /// the palette's own search — not the length of the list — is what makes it usable at that size.
    static let defaultCapacity = 500
    /// Entries older than this are dropped on load; `History.KeepDays`, 0 = keep forever.
    static let defaultKeepDays = 90

    private var history = GlobalHistory(capacity: HistoryService.defaultCapacity)
    private var store: ConfigStore?
    private var enabled = true

    private init() {}

    /// Attach the file and load what is in it. Called once at startup, before the first window.
    func configure(paths: ConfigPaths, capacity: Int? = nil, keepDays: Int? = nil, enabled: Bool = true) {
        self.enabled = enabled
        let store = ConfigStore(url: paths.history)
        self.store = store
        let capacity = capacity ?? Self.defaultCapacity
        let keepDays = keepDays ?? Self.defaultKeepDays
        Task { @MainActor in
            let encoded = await store.string("History", "Entries", default: "")
            var loaded = HistoryCodec.decode(encoded, capacity: capacity)
            loaded.prune(olderThanDays: keepDays)
            // Anything recorded while the file was being read stays: the app is usable before this
            // returns, and losing the first navigation of a session is exactly the kind of small
            // wrongness nobody would report.
            for entry in self.history.entries { loaded.record(entry) }
            self.history = loaded
            self.persist()
        }
    }

    // MARK: - Settings changed while running

    /// Applied at once rather than at the next launch: a setting that appears to do nothing until a
    /// restart reads as broken, and all three of these can be honoured immediately.
    func setEnabled(_ on: Bool) { enabled = on }

    func setCapacity(_ entries: Int) {
        history = GlobalHistory(capacity: max(1, entries), entries: history.entries)
        persist()
    }

    /// Also prunes now, so lowering the number takes visible effect instead of waiting for a launch.
    func setKeepDays(_ days: Int) {
        history.prune(olderThanDays: max(0, days))
        persist()
    }

    // MARK: - Reading

    var isEmpty: Bool { history.entries.isEmpty }

    func ranked(kind: HistoryKind? = nil, pinnedOnly: Bool = false, query: String = "") -> [HistoryEntry] {
        history.ranked(kind: kind, pinnedOnly: pinnedOnly, query: query)
    }

    // MARK: - Recording

    func recordFolder(_ path: String, panel: HistoryPanelSide?) {
        guard shouldRecord, !path.isEmpty else { return }
        record(HistoryEntry(kind: .folder, path: path, panel: panel))
    }

    func recordFile(_ path: String, panel: HistoryPanelSide? = nil) {
        guard shouldRecord, !path.isEmpty else { return }
        record(HistoryEntry(kind: .file, path: path, panel: panel))
    }

    /// A completed file operation. `payload` is `HistoryOperation`'s encoding when the operation can be
    /// repeated and empty when it cannot — a delete is never offered again.
    func recordOperation(label: String, directory: String, payload: String,
                         panel: HistoryPanelSide? = nil) {
        guard shouldRecord, !label.isEmpty else { return }
        record(HistoryEntry(kind: .operation, path: directory, detail: label, payload: payload,
                            panel: panel))
    }

    func recordCommand(_ line: String, directory: String) {
        guard shouldRecord else { return }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        record(HistoryEntry(kind: .command, path: directory, detail: trimmed))
    }

    private var shouldRecord: Bool { enabled }

    private func record(_ entry: HistoryEntry) {
        history.record(entry)
        persist()
    }

    // MARK: - Editing

    func remove(_ entry: HistoryEntry) {
        history.remove(identity: entry.identity)
        persist()
    }

    func togglePinned(_ entry: HistoryEntry) {
        history.setPinned(!entry.pinned, identity: entry.identity)
        persist()
    }

    func clear(keepingPinned: Bool) {
        history.removeAll(keepingPinned: keepingPinned)
        persist()
    }

    /// Count one use of an existing entry without changing what it is (the palette opened it).
    func touch(_ entry: HistoryEntry) {
        history.record(entry)
        persist()
    }

    private func persist() {
        guard let store else { return }
        let encoded = HistoryCodec.encode(history)
        Task { await store.setString(encoded, "History", "Entries") }
    }

    #if DEBUG
    /// Wait for the debounced write, so a script can read the file it just caused (automation only).
    func flushForAutomation() async {
        await store?.flush()
    }

    /// Replace everything (automation only), so a scenario does not depend on what a launch happened to
    /// visit before it.
    func resetForAutomation(capacity: Int = HistoryService.defaultCapacity) {
        history = GlobalHistory(capacity: capacity)
        persist()
    }
    #endif
}

// MARK: - What it takes to run an operation again

/// The payload of a repeatable operation, encoded into one string.
///
/// Only copy and move are repeatable, and that is a decision rather than an omission: repeating a
/// *delete* would be a destructive action offered from a list of things the user is browsing, and
/// repeating a rename has no meaning once the name has changed. Both still appear in the history — Enter
/// on one shows it in the panel instead of doing anything to it.
enum HistoryOperation {
    static let kindCopy = "copy"
    static let kindMove = "move"

    private static let separator = "\u{3}"

    static func encode(kind: String, items: [String], mask: String?) -> String {
        ([kind, mask ?? ""] + items).joined(separator: separator)
    }

    /// Returns nil when the payload is empty or not one of the repeatable kinds.
    static func decode(_ payload: String) -> (kind: String, items: [String], mask: String?)? {
        guard !payload.isEmpty else { return nil }
        let fields = payload.components(separatedBy: separator)
        guard fields.count >= 3, fields[0] == kindCopy || fields[0] == kindMove else { return nil }
        let items = Array(fields.dropFirst(2)).filter { !$0.isEmpty }
        guard !items.isEmpty else { return nil }
        return (fields[0], items, fields[1].isEmpty ? nil : fields[1])
    }
}
