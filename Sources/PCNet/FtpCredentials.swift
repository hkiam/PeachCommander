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

    // MARK: - Proxy credentials (F-210/F-212)
    //
    // A proxy that wants a login had a `proxyUser` and a `proxyPassword` in the model, a `proxyuser` key
    // in the ini — and no way at all to set either, so it could not be used. The password gets the same
    // treatment as the site's own: the Keychain, never the file. Keyed by the *proxy*, not by the site,
    // because one proxy usually serves all of them and re-typing it per site would be busywork.

    /// Stable account key for a proxy login: `proxy://user@host:port`.
    public static func proxyAccount(for site: FtpSite) -> String? {
        guard let host = site.proxyHost, !host.isEmpty,
              let user = site.proxyUser, !user.isEmpty else { return nil }
        return "proxy://\(user)@\(host):\(site.proxyPort)"
    }

    public static func saveProxyPassword(_ password: String, for site: FtpSite, in store: SecretStore) throws {
        guard let account = proxyAccount(for: site) else { return }
        try store.setPassword(password, service: service, account: account)
    }

    public static func proxyPassword(for site: FtpSite, in store: SecretStore) throws -> String? {
        guard let account = proxyAccount(for: site) else { return nil }
        return try store.password(service: service, account: account)
    }
}
