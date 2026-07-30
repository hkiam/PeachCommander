// SPDX-License-Identifier: Apache-2.0
// HostAutomationBridge.swift - the PCApp implementation of AutomationHostBridge.
//
// Wires the Automation Core to the real file manager: panels, the background op
// engine (TransferManager), the command bridge, and ConfigStore. Reuses the same
// accessors the contribution/tool bridges use, so the agent, the (planned) MCP
// server and the Python plugin all drive the app through one audited seam.
//
// v1 scope: context, config get/set, navigation, run-command, copy/move (via the
// background transfer queue), trash/delete, mkdir/rename, and local directory
// listing / stat / file read. Not yet wired (return .notImplemented): structured
// search, command/plugin enumeration, select-by-mask — follow-up increments.

import AppKit
import Foundation
import PCAutomation
import PCOperations
import NaturalLanguage
import CryptoKit

@MainActor
final class HostAutomationBridge: AutomationHostBridge {
    private weak var host: MainWindowController?
    init(host: MainWindowController) { self.host = host }

    // MARK: Context / reads

    func context() async throws -> AutomationContext {
        guard let host else { throw AutomationError.notImplemented("host released") }
        let active = host.activePanel
        let inactive = (active === host.leftPanelController) ? host.rightPanelController : host.leftPanelController
        let selection = await active?.selectedOrCursorPaths() ?? []
        return AutomationContext(
            activePanelPath: active?.directoryPath ?? "",
            inactivePanelPath: inactive?.directoryPath ?? "",
            cursorPath: active?.tableView.cursorItemFullPath(),
            selection: selection,
            tabPaths: active.map { [$0.directoryPath] } ?? [],
            viewMode: active?.viewMode.rawValue ?? "details")
    }

    func listDirectory(_ path: String) async throws -> [AutomationEntry] {
        let fm = FileManager.default
        return try fm.contentsOfDirectory(atPath: path).map { name in
            let full = (path as NSString).appendingPathComponent(name)
            let attrs = try? fm.attributesOfItem(atPath: full)
            return AutomationEntry(name: name, path: full,
                                   isDirectory: (attrs?[.type] as? FileAttributeType) == .typeDirectory,
                                   size: (attrs?[.size] as? NSNumber)?.int64Value ?? 0,
                                   modified: attrs?[.modificationDate] as? Date)
        }
    }

    func stat(_ path: String) async throws -> AutomationEntry {
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        return AutomationEntry(name: (path as NSString).lastPathComponent, path: path,
                               isDirectory: (attrs[.type] as? FileAttributeType) == .typeDirectory,
                               size: (attrs[.size] as? NSNumber)?.int64Value ?? 0,
                               modified: attrs[.modificationDate] as? Date)
    }

    func readFile(_ path: String, maxBytes: Int) async throws -> String {
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? handle.close() }
        let data = try handle.read(upToCount: max(0, maxBytes)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    func search(queryJSON: Data) async throws -> [AutomationEntry] {
        guard let host else { return [] }
        let d = (try? JSONSerialization.jsonObject(with: queryJSON)) as? [String: Any] ?? [:]
        let mask = (d["mask"] as? String) ?? (d["nameMask"] as? String) ?? "*"
        let text = d["text"] as? String
        let path = (d["path"] as? String) ?? (d["startDirectory"] as? String) ?? ""
        let start = path.isEmpty ? host.automationActivePath() : path
        let depth = d["maxDepth"] as? Int ?? 0
        let paths = await host.automationSearch(mask: mask, text: text, startDirectory: start,
                                                maxDepth: depth, limit: 200)
        var out: [AutomationEntry] = []
        for p in paths { if let e = try? await stat(p) { out.append(e) } }
        return out
    }

    func semanticSearch(query: String, path: String?, limit: Int) async throws -> [AutomationEntry] {
        let folder = (path?.isEmpty == false) ? path! : (host?.activePanel?.directoryPath ?? "")
        guard !folder.isEmpty else { return [] }
        let entries = (try? await listDirectory(folder))?.filter { !$0.isDirectory } ?? []
        let emb = NLEmbedding.sentenceEmbedding(for: .english)
        let q = query.lowercased()
        let qTokens = Set(q.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        func normalized(_ name: String) -> String {
            (name as NSString).deletingPathExtension
                .replacingOccurrences(of: "[_.\\-]", with: " ", options: .regularExpression).lowercased()
        }
        func score(_ name: String) -> Double {
            let n = normalized(name)
            if let emb {
                let d = emb.distance(between: q, and: n)     // smaller = closer
                if d.isFinite && d > 0 && d < 2 { return 2 - d }   // higher = better
            }
            // Lexical fallback: fraction of query tokens present in the name.
            let nTokens = Set(n.split(separator: " ").map(String.init))
            guard !qTokens.isEmpty else { return 0 }
            return Double(qTokens.intersection(nTokens).count) / Double(qTokens.count)
        }
        return entries
            .map { ($0, score($0.name)) }
            .sorted { $0.1 > $1.1 }
            .prefix(max(1, limit))
            .map { $0.0 }
    }

    func hashFile(_ path: String, algorithm: String) async throws -> (hash: String, algorithm: String) {
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        let algo = algorithm.lowercased()
        let hex: String
        switch algo {
        case "sha1":   hex = Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case "md5":    hex = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        default:       hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        return (hex, algo == "sha1" || algo == "md5" ? algo : "sha256")
    }

    func writeFile(_ path: String, content: String) async throws {
        try content.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        Task { @MainActor in await host?.activePanel?.reload() }
    }

    func mergeFiles(sources: [String], destination: String) async throws -> (destination: String, count: Int, rows: Int) {
        let fm = FileManager.default
        // Resolve the inputs: explicit list, otherwise the current panel selection.
        var srcs = sources
        if srcs.isEmpty { srcs = await host?.activePanel?.selectedOrCursorPaths() ?? [] }
        srcs = srcs.filter { p in
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: p, isDirectory: &isDir) && !isDir.boolValue
        }
        guard !srcs.isEmpty else {
            throw AutomationError.missingArgument("no files to merge (select the files first)")
        }
        // Resolve the destination relative to the active folder when it isn't absolute.
        let baseDir = host?.activePanel?.directoryPath ?? (srcs[0] as NSString).deletingLastPathComponent
        var dest = destination.isEmpty ? "merged.txt" : destination
        if !(dest as NSString).isAbsolutePath { dest = (baseDir as NSString).appendingPathComponent(dest) }

        let contents = try srcs.map { try String(contentsOf: URL(fileURLWithPath: $0), encoding: .utf8) }
        let allCSV = srcs.allSatisfy { ($0 as NSString).pathExtension.lowercased() == "csv" }
        var out = ""
        var rows = 0
        if allCSV {
            // Keep the header from the first file; drop a matching header row from the rest.
            var header: String?
            for text in contents {
                var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                if lines.last == "" { lines.removeLast() }
                guard !lines.isEmpty else { continue }
                if header == nil {
                    header = lines.first
                    out += lines.first! + "\n"
                    for l in lines.dropFirst() { out += l + "\n"; rows += 1 }
                } else {
                    if lines.first == header { lines.removeFirst() }
                    for l in lines { out += l + "\n"; rows += 1 }
                }
            }
        } else {
            for text in contents {
                out += text
                if !text.hasSuffix("\n") { out += "\n" }
                rows += 1
            }
        }
        try out.write(to: URL(fileURLWithPath: dest), atomically: true, encoding: .utf8)
        await host?.activePanel?.reload()
        return (dest, srcs.count, rows)
    }

    func remember(_ text: String) async throws {
        guard let url = host?.automationMemoryURL else { return }
        MemoryStore(url: url).add(text, at: Date().timeIntervalSince1970)
    }
    func recall(_ query: String, limit: Int) async throws -> [String] {
        guard let url = host?.automationMemoryURL else { return [] }
        return MemoryStore(url: url).recall(query, limit: limit)
    }

    func listCommandsJSON() async throws -> Data {
        guard let host else { return Data("[]".utf8) }
        return try JSONSerialization.data(withJSONObject: await host.automationCommands())
    }

    func listPluginsJSON() async throws -> Data {
        guard let host else { return Data("[]".utf8) }
        return try JSONSerialization.data(withJSONObject: await host.automationPlugins())
    }

    func getConfig(_ key: String) async throws -> String? {
        guard let host, let (section, k) = Self.splitKey(key) else {
            throw AutomationError.missingArgument("key must be \"Section.Key\"")
        }
        let v = await host.mainConfig.string(section, k, default: "")
        return v.isEmpty ? nil : v
    }

    // MARK: Navigate

    func openPath(_ path: String) async throws { host?.contribOpenPath(path) }
    func openInPanel(_ path: String, side: String) async throws {
        host?.contribOpenPathInPanel(side: side.lowercased() == "right" ? 1 : 0, path: path)
    }
    func setSelection(mask: String) async throws { throw AutomationError.notImplemented("set_selection") }
    func runCommand(_ id: String) async throws { host?.contribInvokeCommand(id) }

    // MARK: Write / delete / config (reached only after the policy allows/confirms)

    func copy(sources: [String], destination: String) async throws {
        TransferManager.shared.enqueue(.copy(items: sources, toDirectory: destination, options: CopyOptions()),
                                       title: "Copy \(sources.count) item(s)")
    }
    func move(sources: [String], destination: String) async throws {
        TransferManager.shared.enqueue(.move(items: sources, toDirectory: destination, options: CopyOptions()),
                                       title: "Move \(sources.count) item(s)")
    }
    func rename(path: String, newName: String) async throws {
        guard !newName.contains("/"), newName != ".", newName != ".." else {
            throw AutomationError.missingArgument("new_name must be a single path component")
        }
        let dst = (path as NSString).deletingLastPathComponent + "/" + newName
        try FileManager.default.moveItem(atPath: path, toPath: dst)
        host?.toolReloadActivePanel()
    }
    func makeDirectory(_ path: String) async throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        host?.toolReloadActivePanel()
    }
    func setConfig(_ key: String, _ value: String) async throws {
        guard let host, let (section, k) = Self.splitKey(key) else {
            throw AutomationError.missingArgument("key must be \"Section.Key\"")
        }
        await host.mainConfig.setString(value, section, k)
    }
    func moveToTrash(_ paths: [String]) async throws { host?.toolMoveToTrash(paths) }
    func deletePermanently(_ paths: [String]) async throws { host?.toolDeletePermanently(paths) }

    private static func splitKey(_ key: String) -> (String, String)? {
        let parts = key.split(separator: ".", maxSplits: 1).map(String.init)
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }
}
