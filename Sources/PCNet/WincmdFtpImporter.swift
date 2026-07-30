// WincmdFtpImporter.swift - Import Total Commander FTP sites (F-276).
//
// TC stores FTP connections in `wcx_ftp.ini` (NOT wincmd.ini), one [section] per
// site listed in a `[connections]` index. Passwords are stored obfuscated with
// TC's own reversible encoding; we deliberately do NOT import them — the user
// re-enters the password (stored in the Keychain) on first connect. We import the
// non-secret fields (host/port, username, remote dir, passive, TLS) as best effort.

import Foundation
import PCFoundation

public enum WincmdFtpImporter {

    /// Parse TC `wcx_ftp.ini` text into sites. Order follows the `[connections]`
    /// index when present; otherwise every non-index section with a `host` is used.
    /// Passwords are never imported.
    public static func parse(_ text: String) -> [FtpSite] {
        let doc = INIDocument(parsing: text)

        // Ordered site names from the [connections] index (1=, 2=, …).
        var names: [String] = []
        var i = 1
        var consecutiveMisses = 0
        while consecutiveMisses < 3 {
            if let n = doc.value(section: "connections", key: "\(i)"), !n.isEmpty {
                names.append(n)
                consecutiveMisses = 0
            } else {
                consecutiveMisses += 1
            }
            i += 1
        }
        // Fall back to all real site sections if there is no index.
        if names.isEmpty {
            names = doc.sections().filter {
                let l = $0.lowercased()
                return l != "connections" && l != "default" && l != "meta"
            }
        }

        var sites: [FtpSite] = []
        for name in names {
            guard let rawHost = doc.value(section: name, key: "host"), !rawHost.isEmpty else { continue }

            // TC often stores "host:port" in the host field.
            var host = rawHost
            var port: Int?
            if let colon = rawHost.lastIndex(of: ":"),
               let p = Int(rawHost[rawHost.index(after: colon)...]) {
                host = String(rawHost[..<colon])
                port = p
            }
            if port == nil, let p = doc.value(section: name, key: "port"), let v = Int(p) { port = v }

            let user = doc.value(section: name, key: "username") ?? "anonymous"
            let dir = doc.value(section: name, key: "directory")
                ?? doc.value(section: name, key: "defremdir")
                ?? doc.value(section: name, key: "remotedir")
                ?? ""
            let passive = (doc.value(section: name, key: "pasvmode") ?? "1") != "0"
            // TC flags TLS via `usetls`/`servertype`; treat any non-zero usetls as FTPS.
            let tls = (doc.value(section: name, key: "usetls").map { $0 != "0" }) ?? false
            let proto: FtpProtocol = tls ? .ftps : .ftp

            let site = FtpSite(name: name, host: host, port: port, proto: proto, user: user,
                               auth: (user.isEmpty || user == "anonymous") ? .anonymous : .password,
                               remoteDir: dir, passive: passive)
            sites.append(site)
        }
        return sites
    }
}
