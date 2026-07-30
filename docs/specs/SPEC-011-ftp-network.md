# SPEC-011 — FTP / SFTP / Network

Covers: F-210..F-218. Implemented as PFX plugins over SPEC-012 API (ADR-011),
shipped built-in. UI (connection manager, transfer integration) is core.

## §1 Architecture

- `PCNet` provides two bundled PFX plugins: `FTP` (Network.framework, own
  protocol impl: FTP, FTPS explicit AUTH TLS + implicit) and `SFTP` (libssh2).
- Panels reach them via the "Network" virtual root (PFX mount, SPEC-012 §4) or
  directly via `cd ftp://user@host/path` / connection manager.
- Connections are per-site sessions with a control connection + pooled data
  connections; one panel navigating = one session; transfers may open extra
  connections up to site limit (config, default 2).

## §2 Connection manager (Ctrl+F) (F-210)

List (folders allowed) of sites from ftp-sites.ini: name, host, port, protocol,
user, auth (password→Keychain / key file / agent), remote & local start dirs,
passive flag, proxy ref, server type/encoding (UTF-8 default, Latin-1 fallback),
keep-alive interval + command. Buttons: Connect, New, New URL, Duplicate, Edit,
Delete. Double-click connects. Ctrl+N quick URL dialog (F-211).

## §3 Protocol requirements (FTP)

- Modes: PASV/EPSV default, active PORT/EPRT option; proxies: HTTP CONNECT,
  SOCKS4/4a/5 (F-212). IPv6 via EPSV/EPRT.
- Listings: MLSD preferred; LIST parsers: UNIX ls, DOS, and fallback heuristic
  (test fixtures with captured real-world listings).
- Transfers: binary always (text-mode conversion option per site, off),
  REST resume (maps to `.resumeWrite` + Append), MDTM/MFMT set-time after
  upload, SITE CHMOD for attributes, RNFR/RNTO rename, DELE/RMD/MKD.
- Keep-alive NOOP timer; auto-reconnect with session state on timeout
  (question per SPEC-004 §6 if mid-transfer).
- Raw log window per connection (F-217), custom command box.
- FXP (F-216): PASV on one + PORT on other when both sites allow; feature-
  detect, warn, best effort. P3.

## §4 SFTP specifics

- libssh2: password, publickey (file + passphrase via Keychain prompt),
  ssh-agent; known_hosts check with trust-on-first-use dialog (fingerprint
  shown); ~/.ssh/config Host aliases parsed for convenience (P2).
- Concurrent streams over one SSH session; stat/setstat/rename/symlink support.

## §5 Transfer UX integration

- All copies run through the normal op engine (VFS) → progress, queue,
  bandwidth limit (F-215), background. "Download from list" (F-215): text file
  of URLs → enqueue (menu Net > FTP Download From List, TC parity).
- Sync (SPEC-010) and search (SPEC-008 name/attrs; content via download) work
  over these FS — capability-gated features degrade gracefully.

## §6 Secrets

Passwords/passphrases in Keychain only (configuration.md §Secrets). "Save
password" checkbox at prompt; Touch ID gate for reading (LAContext) optional.

## §7 Tests

- Protocol unit tests against a scripted mock server (in-process TCP fixture
  replaying canned dialogs: login, MLSD, LIST variants, REST resume, TLS).
- Integration (opt-in, CI-skipped): dockerized vsftpd/openssh fixtures via
  `Tools/dev-servers.sh` for manual runs.
- VFS conformance battery against both plugins (mock-backed).
