// SPDX-License-Identifier: Apache-2.0
// docker.swift — Docker as an external PFX file-system plugin.
//
// The engine becomes a drive: a container's filesystem is a directory tree like any other, so F3,
// F5, F7, Shift+F4 and the rest work on it without knowing what a container is. The tree is
//
//     Docker
//     ├── Compose Projects/<project>/<service>[/<container>]/…
//     ├── Standalone Containers/<container>/…
//     └── Volumes/<volume>/…
//
// and everything below the first two levels is the real filesystem of a real container — running
// or stopped, because Docker's archive API answers for both.
//
// Shipped switched off (`PCPluginEnabledByDefault` is false in Info.plist). A connection to a
// Docker daemon is a privileged thing on this machine, and a provider that could reach one should
// be switched on deliberately rather than found already running.
//
// What is here and what is not:
//   * Browsing, reading, writing, creating directories — Docker's archive API, which needs
//     nothing installed inside the image and works on stopped containers.
//   * Deleting and renaming — `execve` inside a *running* container, because the Docker Engine
//     API has no endpoint for either. Refused with a clear code when the container is stopped.
//   * Volumes as first-class drives, reached through a container that mounts them or through a
//     throwaway one created for the purpose and removed on disconnect.
//   * Not here, deliberately: remote engines over SSH/TLS, container lifecycle commands, logs as
//     a virtual file, and an interactive shell. See the plugin's help page.

import AppKit

// MARK: - C-string helper

private func setCString(_ string: String, _ dst: UnsafeMutablePointer<CChar>, _ capacity: Int) {
    string.withCString { _ = strlcpy(dst, $0, capacity) }
}

/// An automation probe setting: the environment first, then the argument domain.
///
/// Both channels are needed and neither is optional. The unit tests `setenv` in their own process,
/// which is the only thing that reaches a dlopen'd plugin from inside a test. The VM harness cannot:
/// it launches the app with `open`, which hands over arguments and never the caller's environment,
/// so `Tools/vm/regress-guest.sh` passes each setting as `-KEY value` and it arrives in
/// `UserDefaults`. Reading only the environment made the harness's variable have no effect at all —
/// the scenario hung on a modal that was supposed to have been skipped, which reads exactly like the
/// dialog being broken.
func dockerProbe(_ key: String) -> String? {
    if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty { return value }
    let value = UserDefaults.standard.string(forKey: key)
    return (value?.isEmpty ?? true) ? nil : value
}

/// The services table, kept from `PfxInit` — `PfxConnect` gets one too, but the settings have to
/// be readable before there is anything to connect.
private nonisolated(unsafe) var hostServices: PfxHostServices?

/// An open enumeration. Materialised in full by `PfxFindFirst`, which is what the WFX model asks
/// for: the host streams it out in batches of its own.
private final class DockerFind {
    let entries: [DockerEntry]
    var index = 0
    init(_ entries: [DockerEntry]) { self.entries = entries }
}

// MARK: - Errors

/// A PC_E_* for anything this plugin can fail with, and the connection's memory of it.
private func record(_ error: Error, on connection: DockerConnection?) -> Int32 {
    let code = pcCode(error)
    connection?.lastError = code
    return code
}

private func pcCode(_ error: Error) -> Int32 {
    switch error {
    case DockerFSError.notFound:
        return Int32(PC_E_EOPEN)
    case DockerFSError.readOnly, DockerFSError.permissionDenied:
        // The host turns this into "permission denied", which is what a read-only rootfs, a
        // read-only mount and a file the container's own user may not write all are.
        return Int32(PC_E_ECREATE)
    case DockerFSError.needsRunningContainer, DockerFSError.unsupported,
         DockerFSError.cannotList, DockerFSError.listingTooLarge:
        return Int32(PC_E_NOT_SUPPORTED)
    case DockerError.unreachable:
        // The end of this mount, not a fact about the file. Saying so lets the host leave the
        // drive and name the engine instead of reporting a directory as missing.
        return Int32(PC_E_CONNECTION_LOST)
    case DockerError.http(let status, _):
        switch status {
        case 404: return Int32(PC_E_EOPEN)
        case 403: return Int32(PC_E_ECREATE)
        case 409: return Int32(PC_E_NOT_SUPPORTED)
        case 500, 502, 503, 504: return Int32(PC_E_CONNECTION_LOST)
        default: return Int32(PC_E_BAD_DATA)
        }
    default:
        return Int32(PC_E_BAD_DATA)
    }
}

// MARK: - Connecting

private func makeConnection(endpoint: DockerEndpoint, settings: DockerSettings)
    -> UnsafeMutableRawPointer? {
    let client = DockerClient(endpoint: endpoint)
    do {
        try client.handshake()
    } catch {
        client.close()
        return nil
    }
    let connection = DockerConnection(client: client, settings: settings)
    connection.sweepAbandonedHelpers()
    // So the context-menu actions can find the engine this mount is on. They are handed a panel
    // scheme and nothing else, and they must not reach for this connection itself — see the note in
    // DockerCommands.swift.
    dockerRegisterMount(id: "docker:" + connection.title, endpoint: endpoint, settings: settings)
    return Unmanaged.passRetained(connection).toOpaque()
}

private func connection(_ pointer: UnsafeMutableRawPointer?) -> DockerConnection? {
    guard let pointer else { return nil }
    return Unmanaged<DockerConnection>.fromOpaque(pointer).takeUnretainedValue()
}

/// The drive chip's id for `endpoint`, short enough for the 128-byte field it goes into.
private func volumeIdentifier(for endpoint: DockerEndpoint) -> String {
    let full = "docker:" + endpoint.url
    return full.utf8.count < 128 ? full : "docker:default"
}

/// The engine this plugin would connect to without being asked, or nil.
private func preferredEndpoint(_ settings: DockerSettings) -> DockerEndpoint? {
    if !settings.endpoint.isEmpty,
       let explicit = DockerEndpoint.parse(settings.endpoint, label: "Docker") {
        return explicit
    }
    return DockerDiscovery.preferred()
}

// MARK: - PFX entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PfxInit")
public func PfxInit(_ services: UnsafePointer<PfxHostServices>?) {
    guard let svc = services?.pointee else { return }
    hostServices = svc
    guard let get = svc.getContext else { return }
    var buffer = [CChar](repeating: 0, count: 4096)
    let answered = "configRoot".withCString { key in get(svc.host, key, &buffer, 4096) }
    if answered == 1 {
        let root = String(cString: buffer)
        if !root.isEmpty { DockerSettings.configRoot = root }
    }
}

@_cdecl("PfxGetCapabilities")
public func PfxGetCapabilities() -> Int32 {
    // Not PC_PFX_CAP_VOLATILE. A container's filesystem does change under you, but auto-refresh
    // would re-read a directory on a timer, and on this provider re-reading a directory can mean
    // streaming a tar. The user refreshes.
    PC_PFX_CAP_READ | PC_PFX_CAP_WRITE | PC_PFX_CAP_RENAME
}

@_cdecl("PfxGetConnectTitle")
public func PfxGetConnectTitle(_ out: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let out else { return 0 }
    setCString(L("Docker Connect…"), out, Int(maxlen))
    return 1
}

/// One chip, and only when there is an engine to click on.
///
/// Publishing it unconditionally would put a drive in the bar that answers nothing on a Mac
/// without Docker installed, which is most of them.
@_cdecl("PfxGetVolumeCount")
public func PfxGetVolumeCount() -> Int32 {
    preferredEndpoint(DockerSettings.load()) != nil ? 1 : 0
}

@_cdecl("PfxGetVolumeInfo")
public func PfxGetVolumeInfo(_ index: Int32, _ out: UnsafeMutablePointer<PfxVolumeInfo>?) {
    guard let out, index == 0, let endpoint = preferredEndpoint(DockerSettings.load()) else { return }
    // No PC_PFX_VOL_LOCAL: there is no local path behind this, so the host makes it a chip whose
    // click connects the plugin — and `PfxConnectVolume` below answers that click without a dialog.
    //
    // The id names the endpoint so a chip from an older configuration is recognisable as such — but
    // the field is 128 bytes and a socket path can be longer than that, and a *truncated* id is a
    // chip that connects to something else or to nothing. Over that length it says "default"
    // instead, which the connect below resolves the same way a fresh discovery would.
    setCString(volumeIdentifier(for: endpoint), &out.pointee.id.0, 128)
    setCString(L("Docker"), &out.pointee.name.0, 256)
    setCString("", &out.pointee.path.0, 1024)
    out.pointee.flags = 0
    setCString("🐳", &out.pointee.icon.0, 64)
    out.pointee.order = 0
}

@_cdecl("PfxConnect")
public func PfxConnect(_ services: UnsafePointer<PfxHostServices>?) -> UnsafeMutableRawPointer? {
    var settings = DockerSettings.load()

    // The environment path exists for the automated tests, which cannot answer a modal dialog —
    // and it is also how someone who already exported DOCKER_HOST connects without being asked.
    if let value = dockerProbe("PC_DOCKER_HOST"),
       let endpoint = DockerEndpoint.parse(value, label: "Docker") {
        if let exec = dockerProbe("PC_DOCKER_EXEC") {
            settings.execFallback = exec != "0"
        }
        return makeConnection(endpoint: endpoint, settings: settings)
    }

    let candidates = DockerDiscovery.candidates()
    guard let chosen = DockerConnectDialog(candidates: candidates, settings: settings).run() else {
        return nil
    }
    settings.endpoint = chosen.endpoint.url
    settings.execFallback = chosen.execFallback
    settings.save()

    guard let made = makeConnection(endpoint: chosen.endpoint, settings: settings) else {
        present(services, title: L("Docker"),
                message: String(format: L("No Docker engine answered at %@."), chosen.endpoint.url))
        return nil
    }
    return made
}

/// Connect the chip the user clicked, instead of asking them which engine they meant.
@_cdecl("PfxConnectVolume")
public func PfxConnectVolume(_ volumeId: UnsafePointer<CChar>?,
                             _ services: UnsafePointer<PfxHostServices>?) -> UnsafeMutableRawPointer? {
    guard let volumeId else { return nil }
    let wanted = String(cString: volumeId)
    guard wanted.hasPrefix("docker:") else { return nil }
    let url = String(wanted.dropFirst("docker:".count))
    let settings = DockerSettings.load()
    // An id from a configuration that has since changed is not one to guess at: answering NULL
    // tells the host the mount did not happen and it drops the chip.
    let endpoint: DockerEndpoint?
    if url == "default" {
        endpoint = preferredEndpoint(settings)
    } else {
        endpoint = DockerEndpoint.parse(url, label: preferredEndpoint(settings)?.label ?? "Docker")
    }
    guard let endpoint else { return nil }
    guard let made = makeConnection(endpoint: endpoint, settings: settings) else {
        present(services, title: L("Docker"),
                message: String(format: L("No Docker engine answered at %@."), url))
        return nil
    }
    return made
}

private func present(_ services: UnsafePointer<PfxHostServices>?, title: String, message: String) {
    let svc = services?.pointee ?? hostServices
    guard let svc, let show = svc.presentInfo else { return }
    title.withCString { t in message.withCString { m in show(svc.host, t, m) } }
}

@_cdecl("PfxLastError")
public func PfxLastError(_ conn: UnsafeMutableRawPointer?) -> Int32 {
    connection(conn)?.lastError ?? Int32(PC_OK)
}

@_cdecl("PfxConnectionId")
public func PfxConnectionId(_ conn: UnsafeMutableRawPointer?, _ out: UnsafeMutablePointer<CChar>?,
                            _ maxlen: Int32) -> Int32 {
    guard let connection = connection(conn), let out else { return 0 }
    // "docker:<label>" — the host splits this into a chip named after the engine with the kind
    // "Docker", so a Colima mount and a Docker Desktop mount are told apart in the drive bar.
    setCString("docker:\(connection.title)", out, Int(maxlen))
    return 1
}

@_cdecl("PfxDisconnect")
public func PfxDisconnect(_ conn: UnsafeMutableRawPointer?) {
    guard let conn else { return }
    let connection = Unmanaged<DockerConnection>.fromOpaque(conn).takeUnretainedValue()
    dockerForgetMount(id: "docker:" + connection.title)
    // The throwaway containers made for volumes are this mount's, and letting ARC decide when
    // they go would leave containers behind on the user's machine.
    connection.cleanup()
    Unmanaged<DockerConnection>.fromOpaque(conn).release()
}

// MARK: - Enumeration

@_cdecl("PfxFindFirst")
public func PfxFindFirst(_ conn: UnsafeMutableRawPointer?,
                         _ dir: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    guard let connection = connection(conn), let dir else { return nil }
    do {
        let entries = try connection.list(String(cString: dir))
        connection.lastError = Int32(PC_OK)
        return Unmanaged.passRetained(DockerFind(entries)).toOpaque()
    } catch {
        _ = record(error, on: connection)
        return nil
    }
}

@_cdecl("PfxFindNext")
public func PfxFindNext(_ find: UnsafeMutableRawPointer?,
                        _ out: UnsafeMutablePointer<PfxFindData>?) -> Int32 {
    guard let find, let out else { return 0 }
    let handle = Unmanaged<DockerFind>.fromOpaque(find).takeUnretainedValue()
    guard handle.index < handle.entries.count else { return 0 }
    let entry = handle.entries[handle.index]
    handle.index += 1
    fill(out, from: entry)
    return 1
}

@_cdecl("PfxFindClose")
public func PfxFindClose(_ find: UnsafeMutableRawPointer?) {
    guard let find else { return }
    Unmanaged<DockerFind>.fromOpaque(find).release()
}

private func fill(_ out: UnsafeMutablePointer<PfxFindData>, from entry: DockerEntry) {
    setCString(entry.name, &out.pointee.name.0, 1024)
    out.pointee.size = entry.size
    out.pointee.mtime = entry.mtime
    out.pointee.isDir = entry.isDir ? 1 : 0
    // The full POSIX mode, type bits included: the host reads S_IFLNK out of it and draws the
    // entry as a link, which is the only way a PFX plugin can say "this is a symlink" — the find
    // record has an isDir flag and nothing else.
    out.pointee.mode = entry.mode
}

@_cdecl("PfxStat")
public func PfxStat(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?,
                    _ out: UnsafeMutablePointer<PfxFindData>?) -> Int32 {
    guard let connection = connection(conn), let path, let out else { return Int32(PC_E_NOT_SUPPORTED) }
    do {
        fill(out, from: try connection.stat(String(cString: path)))
        connection.lastError = Int32(PC_OK)
        return Int32(PC_OK)
    } catch {
        return record(error, on: connection)
    }
}

// MARK: - Transfer

@_cdecl("PfxGetFile")
public func PfxGetFile(_ conn: UnsafeMutableRawPointer?, _ remote: UnsafePointer<CChar>?,
                       _ local: UnsafePointer<CChar>?) -> Int32 {
    guard let connection = connection(conn), let remote, let local else {
        return Int32(PC_E_NOT_SUPPORTED)
    }
    let remotePath = String(cString: remote)
    let name = DockerPath.split(remotePath).leaf
    do {
        try connection.download(remotePath, to: String(cString: local)) { percent in
            report(name: name, percent: percent)
        }
        connection.lastError = Int32(PC_OK)
        return Int32(PC_OK)
    } catch {
        return record(error, on: connection)
    }
}

@_cdecl("PfxPutFile")
public func PfxPutFile(_ conn: UnsafeMutableRawPointer?, _ local: UnsafePointer<CChar>?,
                       _ remote: UnsafePointer<CChar>?) -> Int32 {
    guard let connection = connection(conn), let local, let remote else {
        return Int32(PC_E_NOT_SUPPORTED)
    }
    let remotePath = String(cString: remote)
    let name = DockerPath.split(remotePath).leaf
    do {
        try connection.upload(localPath: String(cString: local), to: remotePath) { percent in
            report(name: name, percent: percent)
        }
        connection.lastError = Int32(PC_OK)
        return Int32(PC_OK)
    } catch {
        return record(error, on: connection)
    }
}

/// Forward transfer progress to the host, and pass its answer back. `false` means the user
/// pressed Cancel, which the transfer turns into an abort.
private func report(name: String, percent: Int) -> Bool {
    guard let svc = hostServices, let progress = svc.progress else { return true }
    return name.withCString { progress(svc.host, $0, Int32(percent)) } == PC_CONTINUE
}

// MARK: - Mutation

@_cdecl("PfxMkDir")
public func PfxMkDir(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?) -> Int32 {
    guard let connection = connection(conn), let path else { return Int32(PC_E_NOT_SUPPORTED) }
    do {
        try connection.makeDirectory(String(cString: path))
        connection.lastError = Int32(PC_OK)
        return Int32(PC_OK)
    } catch {
        return record(error, on: connection)
    }
}

@_cdecl("PfxDelete")
public func PfxDelete(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?) -> Int32 {
    guard let connection = connection(conn), let path else { return Int32(PC_E_NOT_SUPPORTED) }
    do {
        try connection.delete(String(cString: path))
        connection.lastError = Int32(PC_OK)
        return Int32(PC_OK)
    } catch {
        return record(error, on: connection)
    }
}

@_cdecl("PfxRenMov")
public func PfxRenMov(_ conn: UnsafeMutableRawPointer?, _ from: UnsafePointer<CChar>?,
                      _ to: UnsafePointer<CChar>?, _ move: Int32) -> Int32 {
    guard let connection = connection(conn), let from, let to else { return Int32(PC_E_NOT_SUPPORTED) }
    do {
        try connection.rename(String(cString: from), to: String(cString: to))
        connection.lastError = Int32(PC_OK)
        return Int32(PC_OK)
    } catch {
        return record(error, on: connection)
    }
}

// MARK: - Content columns

/// The columns this provider publishes. They are what makes a listing of containers readable —
/// a directory called `backend` says nothing about whether it is running, what image it came
/// from, or whether `/var/lib/postgresql/data` under it is really a volume.
private let dockerFields: [(name: String, title: String, width: Int32)] = [
    ("status", "Status", 120),
    ("access", "Access", 70),
    ("image", "Image", 200),
    ("mount", "Mount", 220),
    ("id", "ID", 110),
]

@_cdecl("PfxContentFieldCount")
public func PfxContentFieldCount() -> Int32 { Int32(dockerFields.count) }

@_cdecl("PfxContentField")
public func PfxContentField(_ index: Int32, _ out: UnsafeMutablePointer<PfxFieldInfo>?) {
    guard let out, index >= 0, Int(index) < dockerFields.count else { return }
    let field = dockerFields[Int(index)]
    setCString(field.name, &out.pointee.name.0, 128)
    setCString(L(field.title), &out.pointee.title.0, 128)
    // All five are strings. The state of a container, a four-letter access tag, an image
    // reference and a mount description are words; sorting any of them numerically would order
    // them by nothing.
    out.pointee.type = Int32(PFX_FT_STRING)
    out.pointee.defaultWidth = field.width
}

@_cdecl("PfxContentGetRow")
public func PfxContentGetRow(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?,
                             _ out: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let connection = connection(conn), let path, let out, maxlen > 0 else { return 0 }
    // Answered only from what a listing already said. A path this mount has not enumerated gets
    // 0 and the host draws an empty cell — fetching it here instead would be an engine round trip
    // per visible row, from the main thread, while the panel is drawing.
    guard let entry = connection.cachedRow(String(cString: path)) else { return 0 }
    let row = [entry.status, entry.access, entry.image, entry.mountInfo, entry.identifier]
        .joined(separator: "\t")
    setCString(row, out, Int(maxlen))
    return 1
}
