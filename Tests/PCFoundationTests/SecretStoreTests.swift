import XCTest
@testable import PCFoundation

final class SecretStoreTests: XCTestCase {
    func testRoundTrip() throws {
        let store = InMemorySecretStore()
        try store.setPassword("hunter2", service: "svc", account: "acct")
        XCTAssertEqual(try store.password(service: "svc", account: "acct"), "hunter2")
    }

    func testMissReturnsNil() throws {
        let store = InMemorySecretStore()
        XCTAssertNil(try store.password(service: "svc", account: "nope"))
    }

    func testOverwrite() throws {
        let store = InMemorySecretStore()
        try store.setPassword("a", service: "s", account: "u")
        try store.setPassword("b", service: "s", account: "u")
        XCTAssertEqual(try store.password(service: "s", account: "u"), "b")
    }

    func testDelete() throws {
        let store = InMemorySecretStore()
        try store.setPassword("x", service: "s", account: "u")
        try store.deletePassword(service: "s", account: "u")
        XCTAssertNil(try store.password(service: "s", account: "u"))
    }

    func testDistinctAccountsIsolated() throws {
        let store = InMemorySecretStore()
        try store.setPassword("p1", service: "s", account: "a")
        try store.setPassword("p2", service: "s", account: "b")
        XCTAssertEqual(try store.password(service: "s", account: "a"), "p1")
        XCTAssertEqual(try store.password(service: "s", account: "b"), "p2")
    }

    /// Opt-in real-Keychain check (skipped by default so CI never prompts).
    func testKeychainRoundTripOptIn() throws {
        guard ProcessInfo.processInfo.environment["PC_KEYCHAIN_TEST"] != nil else {
            throw XCTSkip("Set PC_KEYCHAIN_TEST=1 to exercise the real Keychain.")
        }
        let store = KeychainSecretStore()
        let acct = "unit-test-\(UUID().uuidString)"
        try store.setPassword("secret", service: "PeachCommanderTest", account: acct)
        XCTAssertEqual(try store.password(service: "PeachCommanderTest", account: acct), "secret")
        try store.deletePassword(service: "PeachCommanderTest", account: acct)
        XCTAssertNil(try store.password(service: "PeachCommanderTest", account: acct))
    }
}
