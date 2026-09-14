// SPDX-License-Identifier: Apache-2.0
// DockerFS.swift — one mounted engine, and reading through it.
//
// `DockerConnection` is what `PfxConnect` hands back to the host: it owns the socket, a short
// lived snapshot of what the engine has, the throwaway containers made to reach volumes, and the
// row cache the content columns are answered from.
//
// The listing strategy is the part with a decision in it. The Docker Engine API has **no call
// that lists a directory**. What it has is `GET /containers/{id}/archive?path=…`, which answers
// with a tar of that path *and its whole subtree*. So:
//
//   1. The archive is read first, as a stream, taking only the entries one level down and
//      throwing the file data away, with a budget on how many bytes are worth reading
//      (`ProbeBudgetMB`, 16 MB). This is exact — mode, size, mtime and symlink target come from
//      the tar itself — it needs nothing installed in the image, and it works on a container
//      that has been stopped for a month. For an ordinary directory it is also fast: a
//      container's `/etc` is a few hundred kilobytes.
//
//   2. A directory whose subtree blows through the budget — which in practice means a container's
//      own `/` — falls back to running `ls -1 -A` *in* the container and stating each name with
//      `HEAD …/archive`. This needs the container to be running and to have an `ls`, which is
//      why it is the fallback and not the foundation, and it can be switched off entirely
//      (`ExecFallback=0`).
//
//   3. With no fallback available, the archive is tried again with the large budget
//      (`MaxBudgetMB`), and if that is exceeded the listing fails with a reason the user can act
//      on rather than an empty directory.
//
// The order matters: correctness first, and the expensive-but-universal path is the one that is
// always tried. Nothing here depends on `sh`, `cat` or `tar` existing in the image.

import Foundation

enum DockerFSError: Error {
    /// The subtree under this directory is larger than the configured budget.
    case listingTooLarge
    /// The operation needs a running container and there is not one.
    case needsRunningContainer
    /// The container has no usable `ls`, and the archive was too large.
    case cannotList
    case notFound
    /// The path is on a read-only rootfs or a read-only mount.
    case readOnly
    /// The container's own user may not do this. Reported as it is, never worked around: running
    /// the command as root instead would be the application quietly overriding the permissions
    /// the image set, which is not a decision a file manager gets to make.
    case permissionDenied
    case unsupported
}

/// The container's log, offered as a file in its own root.
///
/// A file rather than a window, because a file is what makes the *viewer's* search, its jump to a
/// line, its encoding choice and its follow work — none of which a window of the plugin's own would
/// have, and all of which are the reason anybody opens a log.
///
/// It is **not** a path in the container: `ls /` inside it shows no such file, and the engine is
/// asked for the log rather than for a file. Two consequences are deliberate. A real entry of this
/// name wins — a container that genuinely ships `/docker-logs.txt` shows its own file, because
/// hiding a file that is really there would be the worse trade. And the entry's timestamp is the
/// moment it was listed, which is what keeps the host from serving a temporary copy it made
/// earlier: `MemberStage` keys its copies by size and modification time, and a log that never
/// changed either would be fetched once and shown for the rest of the session.
enum DockerLog {
    static let name = "docker-logs.txt"
    /// Lines taken from the end. The engine counts them itself.
    static let tail = 2000
}

/// One row as the panel wants it.
struct DockerEntry {
    var name: String
    var size: Int64 = -1
    var mtime: Int64 = 0
    var isDir: Bool = false
    /// POSIX `st_mode`: permission bits and the `S_IF*` type, so the host can draw `l` for a
    /// symlink and the real rwx triple rather than a blank Attr column.
    var mode: UInt32 = 0
    var linkTarget: String = ""

    // Column values. Empty is a perfectly good answer for a row the column does not apply to.
    var status: String = ""
    var access: String = ""
    var image: String = ""
    var mountInfo: String = ""
    var identifier: String = ""
}

/// The handle behind a PFX connection.
final class DockerConnection {
    let client: DockerClient
    let api: DockerAPI
    var settings: DockerSettings

    /// The last PC_E_* worth reporting through `PfxLastError`. `PfxFindFirst` can only answer
    /// NULL, so without this the host cannot tell "no such directory" from "the engine is gone"
    /// — and guessing the first tells the user a folder vanished when their daemon stopped.
    var lastError: Int32 = 0

    private var inventoryCache = DockerInventory()
    /// Rows from the most recent listings, keyed by full virtual path, for the content columns.
    private var rows: [String: DockerEntry] = [:]
    /// Which `ls` a container turned out to have, or nothing when it has none. Probing once per
    /// container per mount keeps a fallback listing to one exec instead of three.
    private var lsCommand: [String: [String]?] = [:]
    /// Container id + path for directories whose archive already exceeded the probe budget once.
    private var tooLargeToProbe: Set<String> = []
    /// Throwaway containers this mount created to reach a volume, by volume name.
    var helperContainers: [String: String] = [:]

    init(client: DockerClient, settings: DockerSettings) {
        self.client = client
        self.api = DockerAPI(client: client)
        self.settings = settings
    }

    var title: String { client.endpoint.label }

    // MARK: - Inventory

    @discardableResult
    func inventory(refresh: Bool = false) throws -> DockerInventory {
        if !refresh, !inventoryCache.isStale { return inventoryCache }
        var made = DockerInventory()
        made.containers = try api.containers()
        made.volumes = try api.volumes()
        made.taken = Date()
        inventoryCache = made
        return made
    }

    func route(_ path: String, refresh: Bool = false) throws -> DockerRoute {
        try inventory(refresh: refresh).route(path)
    }

    // MARK: - Listing

    func list(_ path: String) throws -> [DockerEntry] {
        let inventory = try self.inventory(refresh: true)
        let entries = try listing(for: inventory.route(path), inventory: inventory)
        remember(entries, under: path)
        return entries
    }

    private func remember(_ entries: [DockerEntry], under path: String) {
        // Bounded on purpose: this exists so a content row costs nothing, not so the mount
        // accumulates every directory ever visited.
        if rows.count > 20_000 { rows.removeAll(keepingCapacity: true) }
        for entry in entries { rows[DockerPath.join(path, entry.name)] = entry }
    }

    func cachedRow(_ path: String) -> DockerEntry? { rows[path] }

    private func listing(for route: DockerRoute, inventory: DockerInventory) throws -> [DockerEntry] {
        switch route {
        case .root:
            return DockerSection.allCases.map { DockerEntry(name: $0.rawValue, isDir: true,
                                                            mode: UInt32(S_IFDIR) | 0o755) }

        case .section(.composeProjects):
            return inventory.composeProjects().map { project in
                var entry = DockerEntry(name: project, isDir: true, mode: UInt32(S_IFDIR) | 0o755)
                let services = inventory.composeContainers()[project] ?? [:]
                let all = services.values.flatMap { $0 }
                let running = all.filter { $0.isRunning }.count
                entry.status = "\(running)/\(all.count) running"
                entry.identifier = project
                return entry
            }

        case .section(.standaloneContainers):
            return inventory.standaloneContainers().map(containerEntry)

        case .section(.volumes):
            return inventory.volumes
                .filter { settings.showAnonymousVolumes || !$0.isAnonymous }
                .sorted { lhs, rhs in
                    // Named volumes first: the digest-named ones are rarely what anybody came for.
                    if lhs.isAnonymous != rhs.isAnonymous { return !lhs.isAnonymous }
                    return lhs.name < rhs.name
                }
                .map(volumeEntry)

        case .composeProject(let project):
            let services = inventory.composeContainers()[project] ?? [:]
            return services.keys.sorted().map { service in
                let replicas = services[service]!
                // One replica and the service *is* the container: the level disappears, which is
                // what makes `my-stack/backend/etc` mean what it looks like it means.
                if replicas.count == 1 {
                    var entry = containerEntry(replicas[0])
                    entry.name = service
                    return entry
                }
                var entry = DockerEntry(name: service, isDir: true, mode: UInt32(S_IFDIR) | 0o755)
                entry.status = "\(replicas.filter { $0.isRunning }.count)/\(replicas.count) running"
                entry.image = replicas[0].image
                return entry
            }

        case .composeService(let project, let service):
            let replicas = inventory.composeContainers()[project]?[service] ?? []
            return replicas.map(containerEntry)

        case .container(let container, let inner):
            return try listContainer(container, inner: inner, inventory: inventory)

        case .volume(let volume, let inner):
            let access = try volumeAccess(volume)
            let entries = try listInner(containerID: access.containerID,
                                        path: DockerPath.join(access.prefix, String(inner.dropFirst())),
                                        canExec: access.canExec)
            return entries.map { entry in
                var copy = entry
                copy.access = "VOL"
                copy.identifier = volume.name
                return copy
            }

        case .notFound:
            throw DockerFSError.notFound
        }
    }

    private func containerEntry(_ container: DockerContainer) -> DockerEntry {
        var entry = DockerEntry(name: container.name, isDir: true, mode: UInt32(S_IFDIR) | 0o755)
        entry.status = container.statusDisplay
        entry.image = container.image
        entry.identifier = container.shortID
        entry.access = container.readOnlyRootfs == true ? "RO" : "RW"
        return entry
    }

    /// The synthetic row for a container's log. See `DockerLog` for why the time is now and why the
    /// size is zero: nothing here knows how long the log is without fetching it, and the size is
    /// cosmetic — what the viewer reads is the file this provider writes when it is asked for it.
    private func logEntry(for container: DockerContainer) -> DockerEntry {
        var entry = DockerEntry(name: DockerLog.name)
        entry.size = 0
        entry.mtime = Int64(Date().timeIntervalSince1970)
        entry.mode = UInt32(S_IFREG) | 0o444
        entry.identifier = container.shortID
        entry.access = "RO"
        entry.image = container.image
        return entry
    }

    /// The container whose log `path` names, or nil when it names anything else — including a real
    /// file of the same name, which always wins.
    func logContainer(for path: String) throws -> DockerContainer? {
        guard case .container(let container, let inner) = try inventory().route(path),
              inner == "/" + DockerLog.name else { return nil }
        let real = (try? api.stat(container: container.id, path: inner)) ?? nil
        return real == nil ? container : nil
    }

    private func volumeEntry(_ volume: DockerVolume) -> DockerEntry {
        var entry = DockerEntry(name: volume.name, isDir: true, mode: UInt32(S_IFDIR) | 0o755)
        entry.mtime = DockerAPI.parseTime(volume.createdAt)
        entry.access = "VOL"
        entry.image = volume.driver
        entry.identifier = volume.composeProject ?? ""
        entry.mountInfo = volume.mountpoint
        return entry
    }

    private func listContainer(_ container: DockerContainer, inner: String,
                               inventory: DockerInventory) throws -> [DockerEntry] {
        var entries = try listInner(containerID: container.id, path: inner,
                                    canExec: container.canExec)
        if inner == "/", !entries.contains(where: { $0.name == DockerLog.name }) {
            entries.append(logEntry(for: container))
        }
        let readOnlyRoot = (try? api.readOnlyRootfs(container: container.id)) ?? false
        return entries.map { entry in
            var copy = entry
            copy.identifier = container.shortID
            let childPath = DockerPath.join(inner, entry.name)
            if let mount = inventory.mount(for: container, inner: childPath) {
                copy.access = mount.accessTag
                // The requirement the Mount column exists for: a directory that is really a
                // volume, a bind or a tmpfs says so, and names the volume it is.
                if mount.destination == childPath { copy.mountInfo = mount.display }
            } else {
                copy.access = readOnlyRoot ? "RO" : "RW"
            }
            return copy
        }
    }

    // MARK: - The two ways to read a directory

    func listInner(containerID: String, path: String, canExec: Bool) throws -> [DockerEntry] {
        // A directory already known to be too big to read as an archive is not probed again: the
        // probe costs its whole budget every time, and walking in and out of a container's "/"
        // is exactly what a file manager does.
        if !tooLargeToProbe.contains(containerID + path) {
            do {
                return try listByArchive(containerID: containerID, path: path,
                                         budget: settings.probeBudgetBytes)
            } catch DockerFSError.listingTooLarge {
                tooLargeToProbe.insert(containerID + path)
            }
        }
        if settings.execFallback, canExec,
           let entries = try? listByExec(containerID: containerID, path: path) {
            return entries
        }
        // Nothing left but the archive, with the large budget. A stopped container built on a
        // full-sized image fails here, which is the honest answer: see DockerSettings.maxBudgetMB.
        return try listByArchive(containerID: containerID, path: path,
                                 budget: settings.maxBudgetBytes,
                                 seconds: settings.maxBudgetSeconds)
    }

    /// Read the directory out of its own tar, keeping only what is one level down.
    private func listByArchive(containerID: String, path: String, budget: Int64,
                               seconds: Int = .max) throws -> [DockerEntry] {
        var entries: [DockerEntry] = []
        var base: String?
        let scanner = TarScanner(onEntry: { entry in
            guard let prefix = base else {
                // The first entry is the directory itself, and its recorded name is the prefix
                // every child carries — "etc/" for /etc, "/" for the container's root.
                base = entry.name
                return .skip
            }
            guard entry.name.hasPrefix(prefix) else { return .skip }
            var relative = String(entry.name.dropFirst(prefix.count))
            if relative.hasSuffix("/") { relative.removeLast() }
            guard !relative.isEmpty, !relative.contains("/") else { return .skip }
            entries.append(Self.entry(from: entry, named: relative))
            return .skip
        })
        do {
            try api.archive(container: containerID, path: path, budget: budget,
                            seconds: seconds, scanner: scanner)
        } catch let error as DockerError {
            if case .http(let status, _) = error, status == 404 { throw DockerFSError.notFound }
            throw error
        }
        return entries
    }

    private static func entry(from tar: TarEntry, named name: String) -> DockerEntry {
        var entry = DockerEntry(name: name)
        entry.size = tar.kind == .directory ? -1 : tar.size
        entry.mtime = tar.mtime
        entry.isDir = tar.kind == .directory
        entry.linkTarget = tar.linkName
        let type: UInt32
        switch tar.kind {
        case .directory: type = UInt32(S_IFDIR)
        case .symlink: type = UInt32(S_IFLNK)
        default: type = UInt32(S_IFREG)
        }
        entry.mode = (tar.mode & 0o7777) | type
        return entry
    }

    /// Ask the container what is in the directory, then ask the *engine* about each name.
    ///
    /// Only the names come from inside the container; every size, mode and time still comes from
    /// `HEAD …/archive`, so there is no `ls -l` output being parsed and no difference between a
    /// GNU, a BusyBox and a Toybox image. The one thing this cannot see is a name containing a
    /// newline, which `ls -1` cannot express — such a name is listed by the archive path, which
    /// is what a directory small enough to read that way always uses.
    private func listByExec(containerID: String, path: String) throws -> [DockerEntry] {
        guard let command = try lsFor(containerID: containerID) else { throw DockerFSError.cannotList }
        let result = try api.exec(container: containerID, argv: command + ["--", path])
        guard result.exitCode == 0 else { throw DockerFSError.cannotList }
        let names = result.output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        var entries: [DockerEntry] = []
        entries.reserveCapacity(names.count)
        for name in names {
            let child = DockerPath.join(path, name)
            guard let stat = (try? api.stat(container: containerID, path: child)) ?? nil else { continue }
            var entry = DockerEntry(name: name)
            entry.mode = stat.mode
            entry.isDir = stat.isDirectory
            entry.size = stat.isDirectory ? -1 : stat.size
            entry.mtime = stat.mtime
            entry.linkTarget = stat.linkTarget
            entries.append(entry)
        }
        return entries
    }

    private func lsFor(containerID: String) throws -> [String]? {
        if let known = lsCommand[containerID] { return known }
        let candidates: [[String]] = [
            ["/bin/ls", "-1", "-A"],
            ["/usr/bin/ls", "-1", "-A"],
            ["/bin/busybox", "ls", "-1", "-A"],
        ]
        for candidate in candidates {
            guard let result = try? api.exec(container: containerID, argv: candidate + ["--", "/"]),
                  result.exitCode == 0, !result.stdout.isEmpty else { continue }
            lsCommand[containerID] = candidate
            return candidate
        }
        lsCommand[containerID] = .some(nil)
        return nil
    }

    // MARK: - Stat

    func stat(_ path: String) throws -> DockerEntry {
        let inventory = try self.inventory()
        switch inventory.route(path) {
        case .root, .section, .composeProject, .composeService:
            let (_, leaf) = DockerPath.split(path)
            return DockerEntry(name: leaf.isEmpty ? "/" : leaf, isDir: true,
                               mode: UInt32(S_IFDIR) | 0o755)

        case .container(let container, let inner):
            if inner == "/" { return containerEntry(container) }
            if try logContainer(for: path) != nil { return logEntry(for: container) }
            return try statInner(containerID: container.id, path: inner)

        case .volume(let volume, let inner):
            if inner == "/" { return volumeEntry(volume) }
            let access = try volumeAccess(volume)
            return try statInner(containerID: access.containerID,
                                 path: DockerPath.join(access.prefix, String(inner.dropFirst())))

        case .notFound:
            throw DockerFSError.notFound
        }
    }

    private func statInner(containerID: String, path: String) throws -> DockerEntry {
        guard let stat = try api.stat(container: containerID, path: path) else {
            throw DockerFSError.notFound
        }
        var entry = DockerEntry(name: stat.name)
        entry.mode = stat.mode
        entry.isDir = stat.isDirectory
        entry.size = stat.isDirectory ? -1 : stat.size
        entry.mtime = stat.mtime
        entry.linkTarget = stat.linkTarget
        return entry
    }

    // MARK: - Reading a file

    /// Download one file to `localPath`. `progress` is called with 0…100 and returns false to
    /// abort, which is exactly the host's `PfxHostServices.progress` contract.
    func download(_ path: String, to localPath: String,
                  progress: @escaping (Int) -> Bool) throws {
        // The log is not in the container, so it is not fetched like a file: the engine is asked for
        // it and the answer is written out whole. Small enough that progress is one step.
        if let container = try logContainer(for: path) {
            let text = try api.logs(container: container.id, tail: DockerLog.tail)
            try Data(text.utf8).write(to: URL(fileURLWithPath: localPath), options: .atomic)
            _ = progress(100)
            return
        }
        let target = try resolveForRead(path)
        let total = max(target.size, 0)
        FileManager.default.createFile(atPath: localPath, contents: nil)
        guard let handle = FileHandle(forWritingAtPath: localPath) else {
            throw DockerFSError.unsupported
        }
        defer { try? handle.close() }

        var written: Int64 = 0
        var lastReported = -1
        var aborted = false
        let scanner = TarScanner(onEntry: { entry in
            // One file was asked for, so the first regular entry is it; anything else in the
            // stream (there should be nothing) is not what the user asked to copy.
            entry.kind == .file ? .take : .skip
        }, onData: { chunk in
            handle.write(Data(chunk))
            written += Int64(chunk.count)
            let percent = total > 0 ? Int((written * 100) / total) : 0
            if percent != lastReported {
                lastReported = percent
                if !progress(percent) { aborted = true }
            }
        })
        try api.archive(container: target.containerID, path: target.path,
                        budget: .max, scanner: scanner)
        if aborted { throw DockerFSError.unsupported }
    }

    struct ReadTarget {
        var containerID: String
        var path: String
        var size: Int64
    }

    /// Where a virtual path's bytes actually are, following symlinks.
    ///
    /// A container's configuration is full of links — `/etc/nginx/nginx.conf` is one in the
    /// official image — and Docker's archive of a symlink is the *link*, a zero-byte entry. Left
    /// alone that copies out an empty file and reads as "the file is empty" rather than "this is
    /// a link". Following it here means F3 and F5 show the content; the panel still says `l` in
    /// the Attr column, because the listing's mode is the link's.
    func resolveForRead(_ path: String) throws -> ReadTarget {
        let inventory = try self.inventory()
        let containerID: String
        var inner: String
        switch inventory.route(path) {
        case .container(let container, let innerPath):
            containerID = container.id
            inner = innerPath
        case .volume(let volume, let innerPath):
            let access = try volumeAccess(volume)
            containerID = access.containerID
            inner = DockerPath.join(access.prefix, String(innerPath.dropFirst()))
        default:
            throw DockerFSError.notFound
        }

        var hops = 0
        while hops < 8 {
            guard let stat = try api.stat(container: containerID, path: inner) else {
                throw DockerFSError.notFound
            }
            guard stat.isSymlink, !stat.linkTarget.isEmpty else {
                return ReadTarget(containerID: containerID, path: inner, size: stat.size)
            }
            inner = stat.linkTarget.hasPrefix("/")
                ? stat.linkTarget
                : DockerPath.join(DockerPath.split(inner).parent, stat.linkTarget)
            hops += 1
        }
        throw DockerFSError.notFound
    }

    // MARK: - Teardown

    /// Remove the throwaway containers this mount made. Called from `PfxDisconnect`, which the
    /// host promises to call exactly once with no other call in flight.
    func cleanup() {
        for (_, id) in helperContainers { try? api.remove(container: id) }
        helperContainers.removeAll()
        client.close()
    }
}
