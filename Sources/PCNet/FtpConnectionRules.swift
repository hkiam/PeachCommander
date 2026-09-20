// SPDX-License-Identifier: Apache-2.0
// FtpConnectionRules.swift - Which site settings apply to which protocol, and which
// combinations cannot work (SPEC-011 §2).
//
// The connection dialog offered every setting for every protocol: passive mode and
// "Anonymous" on an SFTP site, a SOCKS5 proxy on an FTPS site whose transport refuses
// to tunnel TLS, an HTTP proxy that the FTP transport silently handshakes as SOCKS5.
// Nothing said so; the connection simply failed later, or worse, quietly did something
// else. The rules live here rather than in the AppKit controller because they are
// statements about the model — the dialog greys controls out with them, `connectToSite`
// refuses with them, and both then say the same thing.

import Foundation

/// A control in the connection dialog, as far as "does this setting mean anything for
/// the selected protocol" is concerned.
public enum FtpSiteSetting: String, Sendable, CaseIterable {
    case user
    /// The one secret field. It is the account's password, or — when a key file is named — that
    /// key's passphrase, which is what libssh2 wants in its place rather than as well as it.
    case password
    case anonymous
    case passive
    case proxy
    case proxyLogin
    case scp
    case insecureTLS
    case keyFile
    /// Name encoding on the wire. SFTP mandates UTF-8, so the choice exists only for FTP/FTPS.
    case encoding
    /// The local folder the other panel opens on connect.
    case localDir
}

/// Something about a site that cannot work, or works differently than the form suggests.
public enum FtpSiteProblem: Equatable, Sendable {
    case missingHost
    case portOutOfRange(Int)
    case missingUser
    /// Explicit FTPS (AUTH TLS) has no transport yet — `connectToSite` refuses it.
    case explicitFTPSUnsupported
    /// A proxy cannot carry FTPS: the tunnel cannot be upgraded to TLS-to-target.
    case proxyWithTLS
    /// SFTP goes out directly; the proxy fields are ignored for it.
    case proxyWithSFTP
    /// Only SOCKS5 is implemented for FTP; an HTTP proxy would not be spoken to correctly.
    case proxyKindUnsupported(ProxyKind)
    /// Active mode needs the server to dial back to us, which a proxied client cannot offer.
    case activeModeThroughProxy
    /// A proxy login was typed but no proxy host — the credentials go nowhere.
    case proxyLoginWithoutProxy
    /// A key file is named that is not there. Blocking, because the fallback is silent: libssh2
    /// skips a key it cannot open and tries `~/.ssh/id_*` instead, so a typo in the path shows up
    /// as "authentication failed" against a server the default key may not even be enrolled at.
    case keyFileMissing(String)

    /// Whether this stops the connection from being attempted at all. The rest are
    /// warnings: the connection is made, but a setting on the form is not doing what it
    /// looks like it is doing.
    public var isBlocking: Bool {
        switch self {
        case .missingHost, .portOutOfRange, .missingUser, .explicitFTPSUnsupported,
             .proxyWithTLS, .proxyKindUnsupported, .activeModeThroughProxy, .keyFileMissing:
            return true
        case .proxyWithSFTP, .proxyLoginWithoutProxy:
            return false
        }
    }
}

public enum FtpConnectionRules {
    /// Whether the protocol has an anonymous login at all. Its own predicate because two rules
    /// read it and they must not drift apart: the checkbox is offered only where it is true, and
    /// `auth(for:)` refuses to honour a stored `.anonymous` where it is false.
    static func hasAnonymousLogin(_ proto: FtpProtocol) -> Bool { proto != .sftp }

    /// The authentication this site really uses, which is not always the one it stores.
    ///
    /// `auth` is the one setting that decides whether *other* settings apply: an anonymous login
    /// has no user name and no password, so both fields go dead with it. A protocol that has no
    /// anonymous login must therefore never be left holding `.anonymous` — the user name, the
    /// password *and* the checkbox that is the only way back all grey out together, and the site
    /// is stuck that way (issue #4). A named key file decides for key authentication here for the
    /// same reason it does in the dialog: there is no third control to tick.
    ///
    /// Resolved on read rather than repaired where it is found, so a site already saved this way
    /// behaves correctly without ftp-sites.ini being rewritten behind the user's back.
    public static func auth(for site: FtpSite) -> FtpAuth {
        guard site.auth == .anonymous, !hasAnonymousLogin(site.proto) else { return site.auth }
        return (site.keyFile?.isEmpty == false) ? .keyFile : .password
    }

    /// The port to show after the protocol changes from `old` to `new`.
    ///
    /// A port the user typed is theirs and survives; a port that is merely the old
    /// protocol's default was never a choice, so it follows the protocol (ftp 21 →
    /// sftp 22). An empty or nonsensical port becomes the new default rather than
    /// being carried forward as garbage.
    public static func port(changingTo new: FtpProtocol, from old: FtpProtocol,
                            current: Int?) -> Int {
        guard let current, current > 0, current <= 65535 else { return new.defaultPort }
        return current == old.defaultPort ? new.defaultPort : current
    }

    /// Whether `setting` means anything for this site — i.e. whether the connection
    /// actually reads it. A setting that does not apply is disabled in the dialog
    /// instead of being offered and ignored.
    public static func applies(_ setting: FtpSiteSetting, to site: FtpSite) -> Bool {
        let isSFTP = site.proto == .sftp
        let isTLS = site.proto == .ftps || site.proto == .ftpsImplicit
        // The effective auth, not the stored one: a site carrying `.anonymous` under a protocol
        // with no anonymous login must not be allowed to disable the two fields that are the way
        // out of it (issue #4).
        let auth = auth(for: site)
        let anonymous = auth == .anonymous
        let hasProxy = !(site.proxyHost ?? "").isEmpty
        switch setting {
        case .user:        return !anonymous
        // Enabled for a key file too: an encrypted key needs its passphrase typed somewhere, and
        // this is that somewhere. Only the ssh-agent needs no secret from us at all.
        case .password:    return !anonymous && auth != .agent
        case .anonymous:   return hasAnonymousLogin(site.proto)   // there is no anonymous SSH login
        case .passive:     return !isSFTP && !hasProxy // SFTP has no data channel to turn round;
                                                       // a tunnelled client cannot be dialled back
        case .proxy:       return site.proto == .ftp   // TLS cannot be tunnelled; SFTP ignores it
        case .proxyLogin:  return site.proto == .ftp && hasProxy
        case .scp:         return isSFTP
        case .insecureTLS: return isTLS
        case .keyFile:     return isSFTP
        case .encoding:    return !isSFTP   // SFTP names are UTF-8 by specification
        case .localDir:    return true
        }
    }

    /// Everything wrong with this site, worst first. Empty means it can be connected.
    public static func problems(with site: FtpSite) -> [FtpSiteProblem] {
        var found: [FtpSiteProblem] = []
        // The effective auth again, so the warning label and the greyed-out controls are talking
        // about the same login — a site stored as anonymous under SFTP is not one.
        let auth = auth(for: site)
        if site.host.trimmingCharacters(in: .whitespaces).isEmpty { found.append(.missingHost) }
        if site.port <= 0 || site.port > 65535 { found.append(.portOutOfRange(site.port)) }
        if auth != .anonymous, site.user.trimmingCharacters(in: .whitespaces).isEmpty {
            found.append(.missingUser)
        }
        if site.proto == .ftps { found.append(.explicitFTPSUnsupported) }
        if auth == .keyFile, let key = site.keyFile, !key.isEmpty,
           !FileManager.default.fileExists(atPath: (key as NSString).expandingTildeInPath) {
            found.append(.keyFileMissing(key))
        }

        let hasProxy = !(site.proxyHost ?? "").isEmpty
        if hasProxy {
            switch site.proto {
            case .ftps, .ftpsImplicit: found.append(.proxyWithTLS)
            case .sftp: found.append(.proxyWithSFTP)
            case .ftp:
                if site.proxyType != .socks5 { found.append(.proxyKindUnsupported(site.proxyType)) }
                if !site.passive { found.append(.activeModeThroughProxy) }
            }
        } else if !(site.proxyUser ?? "").isEmpty {
            found.append(.proxyLoginWithoutProxy)
        }
        // Partitioned rather than sorted: `sort` is not stable, and the order within each
        // half is the order the checks are written in, which is the order they read best in.
        return found.filter(\.isBlocking) + found.filter { !$0.isBlocking }
    }

    /// The problems that stop a connection being attempted.
    public static func blockingProblems(with site: FtpSite) -> [FtpSiteProblem] {
        problems(with: site).filter(\.isBlocking)
    }
}
