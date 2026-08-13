// SPDX-License-Identifier: Apache-2.0
// FtpSite.swift - Connection site model + ftp-sites.ini round-trip + URL parsing.
//
// SPEC-011 §2 (connection manager) and §6 (secrets): a site stores everything
// needed to connect EXCEPT the password/passphrase, which live in the Keychain
// only (see SecretStore). Sites persist to ftp-sites.ini, one [section] per site,
// order-preserving via INIDocument. Quick-connect URLs (Ctrl+N, F-211) parse into
// a transient FtpURL that the UI can turn into a site.

import Foundation
import PCFoundation

/// Transfer protocol for a network site.
public enum FtpProtocol: String, Sendable, CaseIterable {
    case ftp                              // plain FTP
    case ftps = "ftps"                    // FTPS explicit (AUTH TLS)
    case ftpsImplicit = "ftps-implicit"   // FTPS implicit (port 990)
    case sftp                             // SSH file transfer

    public var defaultPort: Int {
        switch self {
        case .ftp, .ftps: return 21
        case .ftpsImplicit: return 990
        case .sftp: return 22
        }
    }

    /// URL scheme understood by `FtpURL.parse`.
    public var urlScheme: String {
        switch self {
        case .ftp: return "ftp"
        case .ftps, .ftpsImplicit: return "ftps"
        case .sftp: return "sftp"
        }
    }
}

/// How the site authenticates.
public enum FtpAuth: String, Sendable, CaseIterable {
    case password        // password stored in Keychain
    case keyFile = "key" // SFTP private key file (passphrase in Keychain)
    case agent           // SSH agent
    case anonymous       // anonymous FTP (user "anonymous")
}

/// A saved connection. No secret material is kept here (Keychain only).
public struct FtpSite: Equatable, Sendable {
    public var name: String
    public var host: String
    public var port: Int
    public var proto: FtpProtocol
    public var user: String
    public var auth: FtpAuth
    public var keyFile: String?
    public var remoteDir: String
    public var localDir: String
    public var passive: Bool
    public var encoding: String            // "utf-8" (default) or "latin-1"

    /// The site's `encoding` as a `String.Encoding`; unknown values mean UTF-8, which is both the
    /// default and the only safe guess. SFTP ignores it — the protocol mandates UTF-8.
    public var textEncoding: String.Encoding {
        encoding.lowercased() == "latin-1" ? .isoLatin1 : .utf8
    }
    public var keepAliveSeconds: Int       // 0 = disabled
    public var keepAliveCommand: String?
    public var folder: String?             // grouping folder in the manager tree
    public var useSCP: Bool                // SFTP sites: transfer files via SCP instead of SFTP
    public var allowInsecureTLS: Bool      // FTPS: accept a self-signed/untrusted certificate
    // SOCKS5 proxy for plain FTP (F-212). nil host = direct connection.
    public var proxyHost: String?
    public var proxyPort: Int
    public var proxyType: ProxyKind
    public var proxyUser: String?
    public var proxyPassword: String?

    /// The proxy to route this site through, or nil for a direct connection (F-212).
    public var proxyConfig: ProxyConfig? {
        guard let host = proxyHost, !host.isEmpty else { return nil }
        return ProxyConfig(kind: proxyType, host: host, port: proxyPort,
                           username: proxyUser, password: proxyPassword)
    }

    public init(name: String, host: String, port: Int? = nil, proto: FtpProtocol = .ftp,
                user: String = "anonymous", auth: FtpAuth = .password, keyFile: String? = nil,
                remoteDir: String = "", localDir: String = "", passive: Bool = true,
                encoding: String = "utf-8", keepAliveSeconds: Int = 0,
                keepAliveCommand: String? = nil, folder: String? = nil, useSCP: Bool = false,
                allowInsecureTLS: Bool = false, proxyHost: String? = nil, proxyPort: Int = 1080,
                proxyType: ProxyKind = .socks5, proxyUser: String? = nil, proxyPassword: String? = nil) {
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
        self.proxyType = proxyType
        self.proxyUser = proxyUser
        self.proxyPassword = proxyPassword
        self.name = name
        self.host = host
        self.port = port ?? proto.defaultPort
        self.proto = proto
        self.user = user
        self.auth = auth
        self.keyFile = keyFile
        self.remoteDir = remoteDir
        self.localDir = localDir
        self.passive = passive
        self.encoding = encoding
        self.keepAliveSeconds = keepAliveSeconds
        self.keepAliveCommand = keepAliveCommand
        self.folder = folder
        self.useSCP = useSCP
        self.allowInsecureTLS = allowInsecureTLS
    }

    /// Effective keep-alive interval in seconds: the site's own value when set
    /// (> 0), otherwise the global default from Options → FTP. 0 = disabled.
    public func effectiveKeepAlive(globalDefault: Int) -> Int {
        keepAliveSeconds > 0 ? keepAliveSeconds : max(0, globalDefault)
    }
}

/// Reads/writes the list of sites to an INI document (ftp-sites.ini).
public enum FtpSitesFile {
    /// Parse all sites from ini text, preserving section order.
    public static func parse(_ text: String) -> [FtpSite] {
        let doc = INIDocument(parsing: text)
        var sites: [FtpSite] = []
        for section in doc.sections() where section.lowercased() != "meta" {
            guard let host = doc.value(section: section, key: "host"), !host.isEmpty else { continue }
            let proto = FtpProtocol(rawValue: doc.value(section: section, key: "protocol") ?? "ftp") ?? .ftp
            var site = FtpSite(name: section, host: host, proto: proto)
            if let p = doc.value(section: section, key: "port"), let v = Int(p) { site.port = v }
            site.user = doc.value(section: section, key: "user") ?? "anonymous"
            site.auth = FtpAuth(rawValue: doc.value(section: section, key: "auth") ?? "password") ?? .password
            site.keyFile = doc.value(section: section, key: "keyfile")
            site.remoteDir = doc.value(section: section, key: "remotedir") ?? ""
            site.localDir = doc.value(section: section, key: "localdir") ?? ""
            site.passive = (doc.value(section: section, key: "passive") ?? "1") != "0"
            site.encoding = doc.value(section: section, key: "encoding") ?? "utf-8"
            if let k = doc.value(section: section, key: "keepalive"), let v = Int(k) { site.keepAliveSeconds = v }
            site.keepAliveCommand = doc.value(section: section, key: "keepalivecmd")
            site.folder = doc.value(section: section, key: "folder")
            site.useSCP = (doc.value(section: section, key: "usescp") ?? "0") == "1"
            site.allowInsecureTLS = (doc.value(section: section, key: "allowinsecuretls") ?? "0") == "1"
            site.proxyHost = doc.value(section: section, key: "proxyhost")
            if let pp = doc.value(section: section, key: "proxyport"), let v = Int(pp) { site.proxyPort = v }
            site.proxyType = ProxyKind(rawValue: doc.value(section: section, key: "proxytype") ?? "socks5") ?? .socks5
            site.proxyUser = doc.value(section: section, key: "proxyuser")
            sites.append(site)
        }
        return sites
    }

    /// Serialize sites back to ini text.
    public static func serialize(_ sites: [FtpSite]) -> String {
        var doc = INIDocument()
        for site in sites {
            let s = site.name
            doc.set(site.host, section: s, key: "host")
            doc.set(String(site.port), section: s, key: "port")
            doc.set(site.proto.rawValue, section: s, key: "protocol")
            doc.set(site.user, section: s, key: "user")
            doc.set(site.auth.rawValue, section: s, key: "auth")
            if let k = site.keyFile { doc.set(k, section: s, key: "keyfile") }
            doc.set(site.remoteDir, section: s, key: "remotedir")
            doc.set(site.localDir, section: s, key: "localdir")
            doc.set(site.passive ? "1" : "0", section: s, key: "passive")
            doc.set(site.encoding, section: s, key: "encoding")
            doc.set(String(site.keepAliveSeconds), section: s, key: "keepalive")
            if let c = site.keepAliveCommand { doc.set(c, section: s, key: "keepalivecmd") }
            if let f = site.folder { doc.set(f, section: s, key: "folder") }
            if site.useSCP { doc.set("1", section: s, key: "usescp") }
            if site.allowInsecureTLS { doc.set("1", section: s, key: "allowinsecuretls") }
            if let ph = site.proxyHost, !ph.isEmpty {
                doc.set(ph, section: s, key: "proxyhost")
                doc.set(String(site.proxyPort), section: s, key: "proxyport")
                doc.set(site.proxyType.rawValue, section: s, key: "proxytype")
                if let pu = site.proxyUser, !pu.isEmpty { doc.set(pu, section: s, key: "proxyuser") }
            }
        }
        return doc.serialized()
    }
}

/// A parsed quick-connect URL (Ctrl+N). The password, if present in the URL, is
/// returned separately so the caller can move it into the Keychain rather than
/// persisting it.
public struct FtpURL: Equatable, Sendable {
    public var proto: FtpProtocol
    public var user: String
    public var password: String?
    public var host: String
    public var port: Int
    public var path: String

    /// Parse `scheme://[user[:password]@]host[:port][/path]`. Recognized schemes:
    /// ftp, ftps, ftpes (→explicit FTPS), sftp. Returns nil if there is no host.
    public static func parse(_ string: String) -> FtpURL? {
        var s = string.trimmingCharacters(in: .whitespaces)
        // Allow a bare "host/path" by assuming ftp.
        if !s.contains("://") { s = "ftp://" + s }
        guard let comps = URLComponents(string: s), let host = comps.host, !host.isEmpty else { return nil }
        let proto: FtpProtocol
        switch comps.scheme?.lowercased() {
        case "ftp": proto = .ftp
        case "ftps", "ftpes": proto = .ftps
        case "ftps-implicit", "ftpsi": proto = .ftpsImplicit
        case "sftp": proto = .sftp
        default: return nil
        }
        let user = (comps.user?.isEmpty == false) ? comps.user!
                   : (proto == .sftp ? "" : "anonymous")
        let path = comps.path.isEmpty ? "" : comps.path
        return FtpURL(proto: proto, user: user, password: comps.password,
                      host: host, port: comps.port ?? proto.defaultPort, path: path)
    }

    /// Build a site from this URL (name defaults to the host).
    public func toSite(name: String? = nil) -> FtpSite {
        FtpSite(name: name ?? host, host: host, port: port, proto: proto,
                user: user.isEmpty ? "anonymous" : user,
                auth: user.isEmpty || user == "anonymous" ? .anonymous : .password,
                remoteDir: path)
    }
}
