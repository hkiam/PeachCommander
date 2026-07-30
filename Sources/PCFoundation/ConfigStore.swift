// ConfigStore.swift - Thread-safe, comment-preserving config storage.
//
// Wraps an INIDocument behind an actor: typed accessors, per-change
// notifications (for UI live-binding), and atomic debounced disk writes.

import Foundation

/// A notification that a single config key changed.
public struct ConfigChange: Sendable, Equatable {
    public let section: String
    public let key: String

    public init(section: String, key: String) {
        self.section = section
        self.key = key
    }
}

/// Thread-safe access to a single INI-backed config file.
///
/// Reads are served from an in-memory ``INIDocument``. Writes update memory
/// immediately, broadcast a ``ConfigChange`` to all subscribers, and schedule
/// a debounced atomic write to disk (temp file + rename) so bursts of
/// changes coalesce into a single I/O operation.
public actor ConfigStore {

    private let url: URL
    private let debounceSeconds: Double
    private var document: INIDocument
    private var continuations: [UUID: AsyncStream<ConfigChange>.Continuation] = [:]
    private var pendingWriteTask: Task<Void, Never>?

    /// Load the INI at `url` (creating an empty doc if missing). If the file
    /// exists but its bytes can't be decoded as UTF-8, it is moved aside to
    /// `<name>.bak` and an empty document is used instead, so a corrupt file
    /// never blocks startup.
    public init(url: URL, debounceSeconds: Double = 1.0) {
        self.url = url
        self.debounceSeconds = debounceSeconds

        if let data = try? Data(contentsOf: url) {
            if let text = String(data: data, encoding: .utf8) {
                self.document = INIDocument(parsing: text)
            } else {
                self.document = ConfigStore.recoverFromUndecodableFile(at: url)
            }
        } else {
            self.document = INIDocument()
        }
    }

    /// Move an undecodable config file aside as `<name>.bak` and return a
    /// fresh, empty document to start from.
    private static func recoverFromUndecodableFile(at url: URL) -> INIDocument {
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".bak")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: url, to: backupURL)
        PCFoundationLogger.error(
            "ConfigStore: \(url.lastPathComponent) could not be decoded as UTF-8; moved aside to .bak"
        )
        return INIDocument()
    }

    // MARK: - Typed reads

    /// Read a boolean. Accepts "1"/"0" (the canonical stored form) as well as
    /// true/false/yes/no, case-insensitively. Falls back to `def` if the key
    /// is absent or unrecognized.
    public func bool(_ section: String, _ key: String, default def: Bool) -> Bool {
        guard let raw = document.value(section: section, key: key) else { return def }
        switch raw.lowercased() {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return def
        }
    }

    /// Read an integer, falling back to `def` if absent or unparsable.
    public func int(_ section: String, _ key: String, default def: Int) -> Int {
        guard let raw = document.value(section: section, key: key), let parsed = Int(raw) else { return def }
        return parsed
    }

    /// Read a double, falling back to `def` if absent or unparsable.
    public func double(_ section: String, _ key: String, default def: Double) -> Double {
        guard let raw = document.value(section: section, key: key), let parsed = Double(raw) else { return def }
        return parsed
    }

    /// Read a string, falling back to `def` if absent.
    public func string(_ section: String, _ key: String, default def: String) -> String {
        document.value(section: section, key: key) ?? def
    }

    // MARK: - Typed writes

    public func setBool(_ v: Bool, _ section: String, _ key: String) {
        setRaw(v ? "1" : "0", section, key)
    }

    public func setInt(_ v: Int, _ section: String, _ key: String) {
        setRaw(String(v), section, key)
    }

    public func setDouble(_ v: Double, _ section: String, _ key: String) {
        setRaw(String(v), section, key)
    }

    public func setString(_ v: String, _ section: String, _ key: String) {
        setRaw(v, section, key)
    }

    private func setRaw(_ value: String, _ section: String, _ key: String) {
        document.set(value, section: section, key: key)
        ensureMetaVersion()
        notify(section: section, key: key)
        scheduleDebouncedWrite()
    }

    /// Ensure `[meta] version=1` is present so future migrations have
    /// something to key off of.
    private func ensureMetaVersion() {
        if document.value(section: "meta", key: "version") == nil {
            document.set("1", section: "meta", key: "version")
        }
    }

    // MARK: - Change notifications

    /// A stream of change notifications. Multiple concurrent subscribers are
    /// supported; each call returns an independent stream.
    public func changes() -> AsyncStream<ConfigChange> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func notify(section: String, key: String) {
        guard !continuations.isEmpty else { return }
        let change = ConfigChange(section: section, key: key)
        for continuation in continuations.values {
            continuation.yield(change)
        }
    }

    // MARK: - Persistence

    /// Cancel any pending debounce and schedule a fresh one.
    private func scheduleDebouncedWrite() {
        pendingWriteTask?.cancel()
        let seconds = debounceSeconds
        pendingWriteTask = Task { [weak self] in
            let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await self?.performWrite()
        }
    }

    /// Force an immediate atomic write (temp file + rename), canceling any
    /// pending debounced write. Safe to call redundantly (e.g. on quit).
    public func flush() async {
        pendingWriteTask?.cancel()
        pendingWriteTask = nil
        await performWrite()
    }

    private func performWrite() async {
        do {
            try writeAtomically()
        } catch {
            PCFoundationLogger.error(
                "ConfigStore failed to write \(url.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }

    /// Serialize the current document and atomically replace `url`'s
    /// contents via a temp file + rename, creating the parent directory if
    /// needed.
    private func writeAtomically() throws {
        let data = Data(document.serialized().utf8)
        let directory = url.deletingLastPathComponent()

        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let tempURL = directory.appendingPathComponent(url.lastPathComponent + ".tmp")
        try data.write(to: tempURL, options: .atomic)

        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: url)
        }
    }
}
