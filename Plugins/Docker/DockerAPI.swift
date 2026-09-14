// SPDX-License-Identifier: Apache-2.0
// DockerAPI.swift — the engine's objects, and the calls that fetch them.
//
// Everything above this file thinks in containers, volumes and mounts; everything below it
// thinks in sockets and JSON. The two facts worth knowing here:
//
//   * **Compose is a label, not an endpoint.** Docker Compose stamps every container it creates
//     with `com.docker.compose.project` and `com.docker.compose.service`, and every volume it
//     creates with `com.docker.compose.project` and `com.docker.compose.volume`. There is no
//     "list my stacks" call and none is needed — the grouping in the panel is read straight off
//     the labels, which means it is right even for a stack whose `docker-compose.yml` is long
//     gone from this machine.
//
//   * **A file mode from the engine is a Go mode, not a POSIX one.** `HEAD …/archive` answers
//     with `{"mode": 2147484141}`; that is Go's `os.FileMode`, whose type bits sit at the top of
//     a 32-bit word (`ModeDir` is 1<<31, `ModeSymlink` 1<<27) and have nothing to do with
//     `S_IFDIR`. Read as POSIX it says "a file with mode 0755 and some impossible type", which
//     is exactly the sort of wrong that looks right in a listing.

import Foundation

// MARK: - Values

/// A container, as much of it as the panel needs.
struct DockerContainer {
    var id: String
    var name: String              // without the leading '/'
    var image: String
    var state: String             // running | exited | paused | restarting | created | dead
    var status: String            // the engine's human sentence, e.g. "Up 3 days"
    var labels: [String: String]
    var mounts: [DockerMount]
    /// Set from `inspect`, which is the only place it appears; nil until asked for.
    var readOnlyRootfs: Bool?

    var composeProject: String? { nonEmpty(labels["com.docker.compose.project"]) }
    var composeService: String? { nonEmpty(labels["com.docker.compose.service"]) }
    /// A one-off `docker compose run` container is labelled with the project but is not part of
    /// the stack's steady state; it is left in the standalone list rather than inserted as a
    /// phantom service that disappears on the next listing.
    var isComposeOneOff: Bool { (labels["com.docker.compose.oneoff"] ?? "False").lowercased() == "true" }

    var isRunning: Bool { state == "running" }
    var canExec: Bool { state == "running" }

    /// The glyph the requirement asks for, with the word beside it.
    var statusDisplay: String {
        switch state {
        case "running": return "● running"
        case "paused": return "◌ paused"
        case "restarting": return "! restarting"
        case "created": return "○ created"
        case "dead": return "! dead"
        default: return "○ stopped"
        }
    }

    var shortID: String { String(id.prefix(12)) }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

/// One mount a container carries — the thing that makes a path inside it something other than
/// the container's own writable layer.
struct DockerMount {
    var type: String              // volume | bind | tmpfs | npipe
    var name: String              // volume name, "" for a bind
    var source: String            // host path for a bind
    var destination: String       // path inside the container
    var readWrite: Bool

    /// The four-letter tag the requirement asks for.
    var accessTag: String {
        switch type {
        case "volume": return readWrite ? "VOL" : "VOL RO"
        case "bind": return readWrite ? "BIND" : "BIND RO"
        case "tmpfs": return "TMP"
        default: return readWrite ? "RW" : "RO"
        }
    }

    /// What the Mount column says about this destination.
    var display: String {
        switch type {
        case "volume": return "Volume: \(name)"
        case "bind": return "Bind: \(source)"
        case "tmpfs": return "tmpfs"
        default: return type
        }
    }
}

struct DockerVolume {
    var name: String
    var driver: String
    var mountpoint: String
    var labels: [String: String]
    var createdAt: String

    var composeProject: String? {
        guard let value = labels["com.docker.compose.project"], !value.isEmpty else { return nil }
        return value
    }
    /// Anonymous volumes are the ones Docker named with a 64-character digest because nobody
    /// else did. They are real and sometimes hold the data, so they are listed — just last.
    var isAnonymous: Bool { labels["com.docker.volume.anonymous"] != nil }
}

/// What `HEAD /containers/{id}/archive` says about one path.
struct DockerPathStat {
    var name: String
    var size: Int64
    var mode: UInt32          // POSIX, already translated out of Go's FileMode
    var mtime: Int64
    var linkTarget: String

    var isDirectory: Bool { mode & UInt32(S_IFMT) == UInt32(S_IFDIR) }
    var isSymlink: Bool { mode & UInt32(S_IFMT) == UInt32(S_IFLNK) }
}

// MARK: - Go's FileMode

enum GoFileMode {
    static let dir: UInt32        = 1 << 31
    static let symlink: UInt32    = 1 << 27
    static let device: UInt32     = 1 << 26
    static let namedPipe: UInt32  = 1 << 25
    static let socket: UInt32     = 1 << 24
    static let setuid: UInt32     = 1 << 23
    static let setgid: UInt32     = 1 << 22
    static let charDevice: UInt32 = 1 << 21
    static let sticky: UInt32     = 1 << 20

    /// A POSIX `st_mode` — permission bits plus the `S_IF*` type — out of a Go `os.FileMode`.
    static func toPOSIX(_ value: UInt32) -> UInt32 {
        var mode = value & 0o777
        if value & setuid != 0 { mode |= UInt32(S_ISUID) }
        if value & setgid != 0 { mode |= UInt32(S_ISGID) }
        if value & sticky != 0 { mode |= UInt32(S_ISVTX) }
        if value & dir != 0 { return mode | UInt32(S_IFDIR) }
        if value & symlink != 0 { return mode | UInt32(S_IFLNK) }
        if value & socket != 0 { return mode | UInt32(S_IFSOCK) }
        if value & namedPipe != 0 { return mode | UInt32(S_IFIFO) }
        if value & device != 0 {
            return mode | UInt32(value & charDevice != 0 ? S_IFCHR : S_IFBLK)
        }
        return mode | UInt32(S_IFREG)
    }
}

// MARK: - Calls

/// The engine calls this plugin makes, and nothing else.
struct DockerAPI {
    let client: DockerClient

    // MARK: Inventory

    func containers() throws -> [DockerContainer] {
        let object = try client.json(path: "/containers/json", query: ["all": "true"])
        guard let list = object as? [[String: Any]] else { return [] }
        return list.map { item in
            let names = (item["Names"] as? [String]) ?? []
            let first = names.first ?? (item["Id"] as? String ?? "")
            return DockerContainer(
                id: item["Id"] as? String ?? "",
                name: first.hasPrefix("/") ? String(first.dropFirst()) : first,
                image: item["Image"] as? String ?? "",
                state: (item["State"] as? String ?? "").lowercased(),
                status: item["Status"] as? String ?? "",
                labels: (item["Labels"] as? [String: String]) ?? [:],
                mounts: mounts(from: item["Mounts"]),
                readOnlyRootfs: nil)
        }
    }

    func volumes() throws -> [DockerVolume] {
        let object = try client.json(path: "/volumes")
        guard let root = object as? [String: Any],
              let list = root["Volumes"] as? [[String: Any]] else { return [] }
        return list.map { item in
            DockerVolume(name: item["Name"] as? String ?? "",
                         driver: item["Driver"] as? String ?? "",
                         mountpoint: item["Mountpoint"] as? String ?? "",
                         labels: (item["Labels"] as? [String: String]) ?? [:],
                         createdAt: item["CreatedAt"] as? String ?? "")
        }
    }

    /// `inspect`, raw — used for the read-only-rootfs flag and for the Inspect view.
    func inspect(container id: String) throws -> [String: Any] {
        (try client.json(path: "/containers/\(id)/json") as? [String: Any]) ?? [:]
    }

    func readOnlyRootfs(container id: String) throws -> Bool {
        let detail = try inspect(container: id)
        let hostConfig = detail["HostConfig"] as? [String: Any]
        return (hostConfig?["ReadonlyRootfs"] as? Bool) ?? false
    }

    private func mounts(from value: Any?) -> [DockerMount] {
        guard let list = value as? [[String: Any]] else { return [] }
        return list.map { item in
            DockerMount(type: (item["Type"] as? String ?? "").lowercased(),
                        name: item["Name"] as? String ?? "",
                        source: item["Source"] as? String ?? "",
                        destination: item["Destination"] as? String ?? "",
                        readWrite: (item["RW"] as? Bool) ?? true)
        }
    }

    // MARK: Paths

    /// `HEAD …/archive` — one path's metadata, without transferring anything.
    ///
    /// This is the only stat the engine offers, and it is a good one: it answers for a stopped
    /// container, it costs a header, and it reports the symlink target rather than following it.
    func stat(container id: String, path: String) throws -> DockerPathStat? {
        let response = try client.send(method: "HEAD", path: "/containers/\(id)/archive",
                                       query: ["path": path])
        guard response.status == 200 else {
            if response.status == 404 { return nil }
            throw DockerError.http(status: response.status, message: response.message)
        }
        guard let header = response.headers["x-docker-container-path-stat"],
              let data = Data(base64Encoded: header),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let goMode = UInt32(truncatingIfNeeded: (object["mode"] as? NSNumber)?.int64Value ?? 0)
        return DockerPathStat(name: object["name"] as? String ?? "",
                              size: (object["size"] as? NSNumber)?.int64Value ?? 0,
                              mode: GoFileMode.toPOSIX(goMode),
                              mtime: Self.parseTime(object["mtime"] as? String),
                              linkTarget: object["linkTarget"] as? String ?? "")
    }

    /// Stream the tar of `path` through `scanner`, stopping as soon as the scanner says so.
    ///
    /// `budget` caps how much of a recursive archive is worth reading — see `DockerFS` for why
    /// there is a budget at all.
    func archive(container id: String, path: String, budget: Int64,
                 seconds: Int = .max, scanner: TarScanner) throws {
        var read: Int64 = 0
        var overBudget = false
        let deadline = seconds == .max ? Date.distantFuture
                                       : Date().addingTimeInterval(TimeInterval(seconds))
        var sinceCheck = 0
        let (status, _) = try client.stream(method: "GET", path: "/containers/\(id)/archive",
                                            query: ["path": path]) { chunk in
            read += Int64(chunk.count)
            if read > budget { overBudget = true; return false }
            // The clock is consulted once per few megabytes rather than per chunk: a chunk is
            // 64 KB and `Date()` is not free enough to ask about eighty thousand times.
            sinceCheck += chunk.count
            if sinceCheck > 4 << 20 {
                sinceCheck = 0
                if Date() > deadline { overBudget = true; return false }
            }
            return try scanner.feed(chunk)
        }
        guard status == 200 else {
            throw DockerError.http(status: status, message: "")
        }
        if overBudget { throw DockerFSError.listingTooLarge }
    }

    /// Write a tar into `path` (which must be an existing directory in the container).
    func upload(container id: String, into path: String, tar: Data) throws {
        let response = try client.send(method: "PUT", path: "/containers/\(id)/archive",
                                       query: ["path": path, "noOverwriteDirNonDir": "false"],
                                       body: tar, contentType: "application/x-tar")
        guard (200..<300).contains(response.status) else {
            throw DockerError.http(status: response.status, message: response.message)
        }
    }

    // MARK: Exec

    struct ExecResult {
        var exitCode: Int
        var stdout: Data
        var stderr: Data

        var output: String { String(decoding: stdout, as: UTF8.self) }
        var errorText: String { String(decoding: stderr, as: UTF8.self) }
    }

    /// Run `argv` in a running container, without a shell.
    ///
    /// No `sh -c` anywhere in this plugin: the arguments go to `execve` as they are, so a file
    /// name holding a quote, a space or a `;` is a file name and never a second command. That is
    /// also why `delete` and `rename` below can pass a user-chosen path at all.
    func exec(container id: String, argv: [String], workingDir: String? = nil) throws -> ExecResult {
        var create: [String: Any] = [
            "AttachStdout": true, "AttachStderr": true, "Tty": false, "Cmd": argv,
        ]
        if let workingDir { create["WorkingDir"] = workingDir }
        let made = try client.json(method: "POST", path: "/containers/\(id)/exec", body: create)
        guard let object = made as? [String: Any], let execID = object["Id"] as? String else {
            throw DockerError.malformed("the engine did not return an exec id")
        }
        var stdout = Data()
        var stderr = Data()
        var demux = DockerStreamDemultiplexer()
        let body = try JSONSerialization.data(withJSONObject: ["Detach": false, "Tty": false])
        let (status, _) = try client.stream(method: "POST", path: "/exec/\(execID)/start",
                                            body: body, contentType: "application/json") { chunk in
            demux.feed(chunk, stdout: &stdout, stderr: &stderr)
            return true
        }
        guard (200..<300).contains(status) else {
            throw DockerError.http(status: status, message: String(decoding: stdout, as: UTF8.self))
        }
        let detail = (try? client.json(path: "/exec/\(execID)/json")) as? [String: Any]
        let code = (detail?["ExitCode"] as? NSNumber)?.intValue ?? 0
        return ExecResult(exitCode: code, stdout: stdout, stderr: stderr)
    }

    /// The tail of a container's log, as text.
    ///
    /// Multiplexed exactly like an attached exec — an 8-byte header per frame — unless the container
    /// was created with a TTY, in which case the stream is raw. Both shapes arrive here, so the
    /// demultiplexer is given the benefit of the doubt and the raw case falls back to the bytes as
    /// they came: a log shown with eight bytes of framing in front of every line is worse than one
    /// shown plainly.
    func logs(container id: String, tail: Int = DockerLog.tail) throws -> String {
        var stdout = Data(), stderr = Data()
        var demux = DockerStreamDemultiplexer()
        var raw = Data()
        let (status, _) = try client.stream(method: "GET", path: "/containers/\(id)/logs",
                                            query: ["stdout": "1", "stderr": "1",
                                                    "tail": String(tail), "timestamps": "0"]) { chunk in
            raw.append(contentsOf: chunk)
            demux.feed(chunk, stdout: &stdout, stderr: &stderr)
            return true
        }
        guard (200..<300).contains(status) else {
            throw DockerError.http(status: status, message: "")
        }
        let framed = stdout + stderr
        return String(decoding: framed.isEmpty ? raw : framed, as: UTF8.self)
    }

    /// One volume's own record, for Inspect.
    func inspect(volume name: String) throws -> [String: Any] {
        (try client.json(path: "/volumes/\(name)") as? [String: Any]) ?? [:]
    }

    // MARK: Lifecycle

    /// Start, stop, restart, pause or unpause a container.
    ///
    /// The engine answers 304 for "it was already like that" — already started, already unpaused —
    /// which is a success and not an error: the user asked for a state and the container is in it.
    /// Treating it as a failure would report "the engine refused" for the one case where nothing was
    /// wrong at all.
    func lifecycle(container id: String, action: String) throws {
        let response = try client.send(method: "POST", path: "/containers/\(id)/\(action)")
        guard (200..<300).contains(response.status) || response.status == 304 else {
            throw DockerError.http(status: response.status, message: response.message)
        }
    }

    // MARK: Helper containers (volume access)

    /// Create a container that exists only to have a volume mounted into it. It is never started.
    func createHelper(name: String, image: String, volume: String, at mountPath: String) throws -> String {
        let body: [String: Any] = [
            "Image": image,
            "Cmd": ["/bin/true"],
            "Labels": [
                DockerHelper.label: "1",
                DockerHelper.volumeLabel: volume,
                // Whose helper this is, so a later launch can tell a leftover from one another
                // window is using right now. See `sweepAbandonedHelpers`.
                DockerHelper.pidLabel: String(ProcessInfo.processInfo.processIdentifier),
            ],
            "HostConfig": ["Binds": ["\(volume):\(mountPath)"], "AutoRemove": false],
        ]
        let object = try client.json(method: "POST", path: "/containers/create",
                                     query: ["name": name], body: body)
        guard let made = object as? [String: Any], let id = made["Id"] as? String else {
            throw DockerError.malformed("the engine did not return a container id")
        }
        return id
    }

    func remove(container id: String) throws {
        _ = try client.send(method: "DELETE", path: "/containers/\(id)",
                            query: ["force": "true", "v": "false"])
    }

    /// Any image that is present locally, preferring one that is small and certain to exist.
    func anyLocalImage() throws -> String? {
        let object = try client.json(path: "/images/json")
        guard let list = object as? [[String: Any]] else { return nil }
        var fallback: String?
        for item in list {
            let tags = (item["RepoTags"] as? [String]) ?? []
            for tag in tags where tag != "<none>:<none>" {
                if tag.contains("alpine") || tag.contains("busybox") { return tag }
                if fallback == nil { fallback = tag }
            }
            if fallback == nil, let id = item["Id"] as? String { fallback = id }
        }
        return fallback
    }

    // MARK: Times

    /// The engine writes RFC 3339 with nanoseconds; `ISO8601DateFormatter` rejects those unless
    /// told to expect them, and returning 0 for every file's date is not a small cosmetic loss.
    static func parseTime(_ text: String?) -> Int64 {
        guard let text, !text.isEmpty else { return 0 }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return Int64(date.timeIntervalSince1970) }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) { return Int64(date.timeIntervalSince1970) }
        return 0
    }
}

/// Docker multiplexes a non-TTY exec's stdout and stderr over one stream, framed as an 8-byte
/// header (stream id, three zero bytes, a big-endian length) followed by that many bytes.
struct DockerStreamDemultiplexer {
    private var carry: [UInt8] = []

    mutating func feed(_ chunk: UnsafeRawBufferPointer, stdout: inout Data, stderr: inout Data) {
        carry.append(contentsOf: chunk)
        var offset = 0
        while carry.count - offset >= 8 {
            let stream = carry[offset]
            let length = (Int(carry[offset + 4]) << 24) | (Int(carry[offset + 5]) << 16)
                       | (Int(carry[offset + 6]) << 8) | Int(carry[offset + 7])
            guard carry.count - offset - 8 >= length else { break }
            let body = carry[(offset + 8)..<(offset + 8 + length)]
            if stream == 2 { stderr.append(contentsOf: body) } else { stdout.append(contentsOf: body) }
            offset += 8 + length
        }
        if offset > 0 { carry.removeFirst(offset) }
    }
}
