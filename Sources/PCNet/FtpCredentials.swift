// SPDX-License-Identifier: Apache-2.0
// FtpCredentials.swift - Map a connection site to its Keychain secret.
//
// The site model (ftp-sites.ini) never holds a password; it is stored in a
// SecretStore keyed by a stable account string derived from the site. This keeps
// SPEC-011 §6 (secrets in Keychain only) enforced at the seam between the site
// list and the credential store.

import Foundation
import PCFoundation

public enum FtpCredentials {
    /// Keychain service name for all Peach Commander network credentials.
    public static let service = "PeachCommander Network"

    /// Stable account key for a site: `scheme://user@host:port`.
    public static func account(for site: FtpSite) -> String {
        "\(site.proto.urlScheme)://\(site.user)@\(site.host):\(site.port)"
    }

    public static func savePassword(_ password: String, for site: FtpSite, in store: SecretStore) throws {
        try store.setPassword(password, service: service, account: account(for: site))
    }

    public static func password(for site: FtpSite, in store: SecretStore) throws -> String? {
        try store.password(service: service, account: account(for: site))
    }

    public static func deletePassword(for site: FtpSite, in store: SecretStore) throws {
        try store.deletePassword(service: service, account: account(for: site))
    }
}
