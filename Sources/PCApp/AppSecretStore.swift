// SPDX-License-Identifier: Apache-2.0
// AppSecretStore.swift - The one secret store the app writes its credentials through.
//
// Two call sites used to build a `KeychainSecretStore()` of their own, which made the code that
// decides *whether* to store a secret impossible to test: the only store it could reach was the
// developer's real login keychain. This repo keeps its real-Keychain test behind
// `PC_KEYCHAIN_TEST` for exactly that reason, so a UI test covering the FTP dialog's save path had
// nowhere to write. The passphrase-persistence defect fixed in a825c4fd was found by reading, not
// by a failing test, which is the gap this closes.

import Foundation
import PCFoundation

enum AppSecretStore {
    /// One instance for the whole process, because a store can carry state: the in-memory one
    /// does, and a fresh instance per dialog would lose every secret between two openings of the
    /// connection manager — which is precisely the round-trip worth testing.
    static let shared: SecretStore = make()

    /// `-PCSecretStore memory` swaps in a store that lives and dies with the process.
    ///
    /// A launch argument rather than an environment variable, for the same reason `-ConfigRoot` is
    /// one: it lands in `UserDefaults`' argument domain, which is the channel that survives being
    /// launched by `open` and by XCUITest. It only makes secrets non-persistent — nothing is
    /// written anywhere new — so the worst a stray flag can do is make the app forget a password.
    private static func make() -> SecretStore {
        UserDefaults.standard.string(forKey: "PCSecretStore") == "memory"
            ? InMemorySecretStore()
            : KeychainSecretStore()
    }
}
