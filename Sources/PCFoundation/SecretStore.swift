// SecretStore.swift - Secure credential storage (SPEC-011 §6, configuration.md).
//
// FTP/SFTP passwords and key passphrases must live in the Keychain only, never in
// any .ini file. `SecretStore` is the abstraction the rest of the app uses; the
// production implementation is Keychain-backed, and an in-memory implementation
// is provided for tests (so credential round-trips can be verified without
// touching the real Keychain or prompting the user).

import Foundation
import Security

public enum SecretStoreError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case dataDecodingFailed
}

/// Stores/retrieves secrets keyed by (service, account).
public protocol SecretStore: Sendable {
    func setPassword(_ password: String, service: String, account: String) throws
    func password(service: String, account: String) throws -> String?
    func deletePassword(service: String, account: String) throws
}

/// Keychain-backed store using generic-password items (Security.framework).
public struct KeychainSecretStore: SecretStore {
    public init() {}

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    public func setPassword(_ password: String, service: String, account: String) throws {
        // Replace any existing item to keep the write idempotent.
        SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        var query = baseQuery(service: service, account: account)
        query[kSecValueData as String] = Data(password.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecretStoreError.unexpectedStatus(status) }
    }

    public func password(service: String, account: String) throws -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SecretStoreError.unexpectedStatus(status) }
        guard let data = item as? Data, let s = String(data: data, encoding: .utf8) else {
            throw SecretStoreError.dataDecodingFailed
        }
        return s
    }

    public func deletePassword(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretStoreError.unexpectedStatus(status)
        }
    }
}

/// In-memory store for tests and previews. Thread-safe.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var items: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    private func key(_ service: String, _ account: String) -> String { "\(service)\u{0}\(account)" }

    public func setPassword(_ password: String, service: String, account: String) throws {
        lock.lock(); defer { lock.unlock() }
        items[key(service, account)] = password
    }

    public func password(service: String, account: String) throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return items[key(service, account)]
    }

    public func deletePassword(service: String, account: String) throws {
        lock.lock(); defer { lock.unlock() }
        items[key(service, account)] = nil
    }
}
