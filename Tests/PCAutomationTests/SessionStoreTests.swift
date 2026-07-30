import XCTest
@testable import PCAutomation

final class SessionStoreTests: XCTestCase {

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    // Factory building sessions over the FakeBridge core + a scripted provider.
    private var factory: @Sendable (AgentSession.Snapshot?) -> AgentSession {
        { snapshot in
            let core = DefaultAutomationCore(bridge: FakeBridge())
            let provider = ScriptedProvider([.text("ok")])
            if let snapshot { return AgentSession(restoring: snapshot, core: core, provider: provider) }
            return AgentSession(core: core, provider: provider)
        }
    }

    func test_store_roundTrip_and_delete() throws {
        let store = SessionStore(directory: tempDir())
        let snap = AgentSession.Snapshot(id: "s1", title: "First",
                                         messages: [ModelMessage(role: .user, content: "hi")])
        try store.save(snap)
        XCTAssertEqual(store.load(id: "s1"), snap)
        XCTAssertEqual(store.loadAll().count, 1)
        store.delete(id: "s1")
        XCTAssertNil(store.load(id: "s1"))
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    func test_manager_createsParallelSessions() async throws {
        let mgr = SessionManager(store: SessionStore(directory: tempDir()), makeSession: factory)
        let a = await mgr.create(title: "Alpha")
        let b = await mgr.create(title: "Beta")
        let ida = await a.id, idb = await b.id
        XCTAssertNotEqual(ida, idb)                    // independent, parallel sessions
        let list = await mgr.list()
        XCTAssertEqual(Set(list.map(\.title)), ["Alpha", "Beta"])
    }

    func test_persistAndReload_restoresHistory() async throws {
        let dir = tempDir()
        let mgr = SessionManager(store: SessionStore(directory: dir), makeSession: factory)
        let session = await mgr.create(title: "Work")
        let id = await session.id
        _ = try await session.send("do something")     // history now: user + assistant
        await mgr.persist(id: id)

        // A fresh manager over the same directory rehydrates it.
        let mgr2 = SessionManager(store: SessionStore(directory: dir), makeSession: factory)
        await mgr2.loadIndex()
        let listed = await mgr2.list()
        XCTAssertEqual(listed.first?.title, "Work")
        let maybe = await mgr2.session(id: id)
        let restored = try XCTUnwrap(maybe)
        let count = await restored.messageCount
        XCTAssertEqual(count, 2)                        // user + assistant restored
    }

    func test_rename_isPersisted() async throws {
        let dir = tempDir()
        let mgr = SessionManager(store: SessionStore(directory: dir), makeSession: factory)
        let s = await mgr.create(title: "Old")
        let id = await s.id
        await mgr.rename(id: id, to: "New name")
        let title1 = await mgr.list().first?.title
        XCTAssertEqual(title1, "New name")
        // persisted for a fresh manager
        let mgr2 = SessionManager(store: SessionStore(directory: dir), makeSession: factory)
        await mgr2.loadIndex()
        let title2 = await mgr2.list().first?.title
        XCTAssertEqual(title2, "New name")
    }

    func test_delete_removesFromDiskAndIndex() async throws {
        let dir = tempDir()
        let store = SessionStore(directory: dir)
        let mgr = SessionManager(store: store, makeSession: factory)
        let s = await mgr.create(title: "Temp")
        let id = await s.id
        await mgr.delete(id: id)
        let empty = await mgr.list().isEmpty
        XCTAssertTrue(empty)
        XCTAssertNil(store.load(id: id))
    }
}
