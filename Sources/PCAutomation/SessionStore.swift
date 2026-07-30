// SPDX-License-Identifier: Apache-2.0
// SessionStore.swift - persistence + management of AI chat sessions.
//
// ki.md: the assistant opens several sessions, renames them, saves them historically,
// and supports parallel sessions. SessionStore persists one JSON file per session
// under a config-root directory (honoring -ConfigRoot); SessionManager keeps multiple
// live AgentSessions (each an independent actor = parallel) and handles
// create/rename/delete/list + load/save. Long-term cross-session memory is a separate,
// later store.

import Foundation

/// One-JSON-file-per-session persistence.
public struct SessionStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    private func url(_ id: String) -> URL { directory.appendingPathComponent("\(id).json") }

    public func save(_ snapshot: AgentSession.Snapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url(snapshot.id), options: .atomic)
    }

    public func load(id: String) -> AgentSession.Snapshot? {
        guard let data = try? Data(contentsOf: url(id)) else { return nil }
        return try? JSONDecoder().decode(AgentSession.Snapshot.self, from: data)
    }

    public func loadAll() -> [AgentSession.Snapshot] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }
            .compactMap { (try? Data(contentsOf: $0)).flatMap { try? JSONDecoder().decode(AgentSession.Snapshot.self, from: $0) } }
    }

    public func delete(id: String) { try? FileManager.default.removeItem(at: url(id)) }
}

/// Lightweight listing entry for the session switcher.
public struct SessionInfo: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
}

/// Manages multiple live, parallel AI chat sessions + their persistence.
public actor SessionManager {
    private let store: SessionStore
    private let makeSession: @Sendable (AgentSession.Snapshot?) -> AgentSession
    private var live: [String: AgentSession] = [:]
    private var order: [String] = []
    private var titles: [String: String] = [:]

    /// - Parameter makeSession: factory building an AgentSession, either fresh (nil)
    ///   or restored from a snapshot. The app injects the core + provider here.
    public init(store: SessionStore, makeSession: @escaping @Sendable (AgentSession.Snapshot?) -> AgentSession) {
        self.store = store
        self.makeSession = makeSession
    }

    /// Populate the index from saved sessions on disk.
    public func loadIndex() {
        for snap in store.loadAll().sorted(by: { $0.id < $1.id }) {
            if titles[snap.id] == nil { order.append(snap.id) }
            titles[snap.id] = snap.title
        }
    }

    public func list() -> [SessionInfo] {
        order.map { SessionInfo(id: $0, title: titles[$0] ?? "Chat") }
    }

    /// Open a new live session and persist it.
    @discardableResult
    public func create(title: String = "New chat") async -> AgentSession {
        let session = makeSession(nil)
        let id = await session.id
        await session.rename(title)
        live[id] = session
        if !order.contains(id) { order.append(id) }
        titles[id] = title
        try? store.save(await session.snapshot())
        return session
    }

    /// Get a live session, rehydrating from disk if it isn't loaded.
    public func session(id: String) async -> AgentSession? {
        if let s = live[id] { return s }
        guard let snap = store.load(id: id) else { return nil }
        let s = makeSession(snap)
        live[id] = s
        if !order.contains(id) { order.append(id) }
        titles[id] = snap.title
        return s
    }

    public func rename(id: String, to title: String) async {
        titles[id] = title
        if let s = live[id] {
            await s.rename(title)
            try? store.save(await s.snapshot())
        } else if var snap = store.load(id: id) {
            snap.title = title
            try? store.save(snap)
        }
    }

    public func delete(id: String) {
        live[id] = nil
        titles[id] = nil
        order.removeAll { $0 == id }
        store.delete(id: id)
    }

    /// Delete every session (discard all chats).
    public func deleteAll() {
        for id in order { store.delete(id: id) }
        live.removeAll(); titles.removeAll(); order.removeAll()
    }

    /// Number of user messages in a session (0 = never actually used).
    public func userMessageCount(id: String) async -> Int {
        if let s = live[id] { return await s.history.filter { $0.role == .user }.count }
        return store.load(id: id)?.messages.filter { $0.role == .user }.count ?? 0
    }

    /// Delete sessions the user never sent a message in (empty "New chat" leftovers),
    /// except the one to keep. Prevents empty sessions from accumulating on disk.
    public func deleteEmptySessions(keeping keepId: String?) async {
        for id in order where id != keepId {
            if await userMessageCount(id: id) == 0 { delete(id: id) }
        }
    }

    /// Persist a live session's current conversation.
    public func persist(id: String) async {
        guard let s = live[id] else { return }
        try? store.save(await s.snapshot())
    }
}
