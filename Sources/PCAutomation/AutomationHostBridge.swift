// AutomationHostBridge.swift - the minimal host capability surface the Automation
// Core needs. PCApp conforms to this (it owns the panels, op engine, config and
// command registry); DefaultAutomationCore drives it. Keeping the bridge in terms
// of Core vocabulary (paths, AutomationEntry, JSON) decouples the core logic from
// AppKit and makes it unit-testable against a fake bridge.

import Foundation

public protocol AutomationHostBridge: Sendable {
    // Context / reads
    func context() async throws -> AutomationContext
    func listDirectory(_ path: String) async throws -> [AutomationEntry]
    func stat(_ path: String) async throws -> AutomationEntry
    func readFile(_ path: String, maxBytes: Int) async throws -> String
    func search(queryJSON: Data) async throws -> [AutomationEntry]
    func getConfig(_ key: String) async throws -> String?
    func listCommandsJSON() async throws -> Data
    func listPluginsJSON() async throws -> Data

    // Navigate
    func openPath(_ path: String) async throws
    func openInPanel(_ path: String, side: String) async throws
    func setSelection(mask: String) async throws
    func runCommand(_ id: String) async throws

    // Write / delete / config (only reached after the policy allows/confirms)
    func copy(sources: [String], destination: String) async throws
    func move(sources: [String], destination: String) async throws
    func rename(path: String, newName: String) async throws
    func makeDirectory(_ path: String) async throws
    func setConfig(_ key: String, _ value: String) async throws
    func moveToTrash(_ paths: [String]) async throws
    func deletePermanently(_ paths: [String]) async throws

    /// Rank files in `path` (or the active folder) by semantic similarity of their
    /// names to `query`, best first. Default: unsupported (empty).
    func semanticSearch(query: String, path: String?, limit: Int) async throws -> [AutomationEntry]

    /// Long-term memory (persists across chats). Defaults: no-op / empty.
    func remember(_ text: String) async throws
    func recall(_ query: String, limit: Int) async throws -> [String]

    /// Compute a file's hash (algorithm: sha256|sha1|md5). Write UTF-8 text to a file.
    func hashFile(_ path: String, algorithm: String) async throws -> (hash: String, algorithm: String)
    func writeFile(_ path: String, content: String) async throws

    /// Merge `sources` (or the current selection when empty) into a single new file at
    /// `destination`, keeping a CSV header only once. Returns the resolved destination
    /// path, how many files were merged, and how many data rows were written.
    func mergeFiles(sources: [String], destination: String) async throws -> (destination: String, count: Int, rows: Int)
}

public extension AutomationHostBridge {
    func semanticSearch(query: String, path: String?, limit: Int) async throws -> [AutomationEntry] { [] }
    func remember(_ text: String) async throws {}
    func recall(_ query: String, limit: Int) async throws -> [String] { [] }
    func hashFile(_ path: String, algorithm: String) async throws -> (hash: String, algorithm: String) {
        throw AutomationError.notImplemented("hash_file")
    }
    func writeFile(_ path: String, content: String) async throws { throw AutomationError.notImplemented("write_file") }
    func mergeFiles(sources: [String], destination: String) async throws -> (destination: String, count: Int, rows: Int) {
        throw AutomationError.notImplemented("merge_files")
    }
}
