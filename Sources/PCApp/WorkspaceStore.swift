// SPDX-License-Identifier: Apache-2.0
// WorkspaceStore.swift - Named panel layouts (Workspaces backlog item).
//
// A workspace captures both panels' open tabs (path + sort + lock + cursor) and
// which side is active, so the user can save several working setups and switch
// between them. Persisted to workspaces.ini via ConfigStore, mirroring the tab
// serialization used for the session.

import Foundation
import PCFoundation

/// Both panels' tab layout plus the active side.
struct WorkspaceLayout: Sendable {
    var left: [PanelTabState]
    var leftActive: Int
    var right: [PanelTabState]
    var rightActive: Int
    var activeSide: String   // "left" | "right"
}

actor WorkspaceStore {
    private let store: ConfigStore
    private static let section = "Workspaces"

    init(url: URL) {
        store = ConfigStore(url: url)
    }

    /// Names of all saved workspaces, in stored order.
    func names() async -> [String] {
        await loadAll().map(\.name)
    }

    /// Saves (or replaces, by name) a workspace and flushes to disk.
    func save(_ name: String, layout: WorkspaceLayout) async {
        var list = await loadAll()
        if let i = list.firstIndex(where: { $0.name == name }) {
            list[i].layout = layout
        } else {
            list.append((name: name, layout: layout))
        }
        await writeAll(list)
    }

    /// The named workspace's layout, or nil if it doesn't exist.
    func load(_ name: String) async -> WorkspaceLayout? {
        await loadAll().first { $0.name == name }?.layout
    }

    /// Deletes the named workspace (no-op if absent).
    func delete(_ name: String) async {
        let list = await loadAll().filter { $0.name != name }
        await writeAll(list)
    }

    // MARK: - Persistence

    private func loadAll() async -> [(name: String, layout: WorkspaceLayout)] {
        let count = await store.int(Self.section, "Count", default: 0)
        var out: [(name: String, layout: WorkspaceLayout)] = []
        for i in 0..<max(0, count) {
            let name = await store.string(Self.section, "Name\(i)", default: "")
            guard !name.isEmpty else { continue }
            let layout = WorkspaceLayout(
                left: WorkspaceCodec.decode(await store.string(Self.section, "Left\(i)", default: "")),
                leftActive: await store.int(Self.section, "LeftActive\(i)", default: 0),
                right: WorkspaceCodec.decode(await store.string(Self.section, "Right\(i)", default: "")),
                rightActive: await store.int(Self.section, "RightActive\(i)", default: 0),
                activeSide: await store.string(Self.section, "Active\(i)", default: "left")
            )
            out.append((name, layout))
        }
        return out
    }

    private func writeAll(_ list: [(name: String, layout: WorkspaceLayout)]) async {
        await store.setInt(list.count, Self.section, "Count")
        for (i, entry) in list.enumerated() {
            await store.setString(entry.name, Self.section, "Name\(i)")
            await store.setString(WorkspaceCodec.encode(entry.layout.left), Self.section, "Left\(i)")
            await store.setInt(entry.layout.leftActive, Self.section, "LeftActive\(i)")
            await store.setString(WorkspaceCodec.encode(entry.layout.right), Self.section, "Right\(i)")
            await store.setInt(entry.layout.rightActive, Self.section, "RightActive\(i)")
            await store.setString(entry.layout.activeSide, Self.section, "Active\(i)")
        }
        await store.flush()
    }
}
