// SPDX-License-Identifier: Apache-2.0
// DockerWrite.swift — writing through the mount, and reaching a volume at all.
//
// **Uploading, creating a directory** go through the archive API, which takes a tar and applies
// it to a path. That works on a stopped container exactly as it does on a running one, and needs
// nothing installed in the image.
//
// **Deleting and renaming do not exist in the Docker Engine API.** There is no endpoint for
// either — `docker cp` has no counterpart, and the CLI has no `docker rm <file>`. The only way to
// remove or move a file inside a container is to run something in it, so that is what this does,
// and it says so plainly when it cannot: a stopped container refuses the operation with
// "unsupported" rather than pretending. This is not a shortcut around the archive API; it is the
// whole of what the engine offers.
//
// **Volumes are reached through a container.** The engine will not read a volume directly either
// — a volume is only ever visible from inside something that mounts it. So: if any container
// already mounts the volume, that container's mount point is the door, whether it is running or
// not. If none does, one is *created* (never started) with the volume bound into it, labelled as
// this plugin's, and removed again when the mount closes. That is what `docker cp` does under
// the surface, and it is why a volume whose last container was deleted months ago is still
// browsable.

import Foundation

enum DockerHelper {
    static let label = "com.peachcommander.helper"
    static let volumeLabel = "com.peachcommander.helper.volume"
    static let pidLabel = "com.peachcommander.helper.pid"
    /// Where a volume is bound inside the throwaway container. Deliberately not "/mnt" or
    /// "/data": those exist in real images and a bind onto an existing directory hides it, which
    /// would be confusing if this container were ever looked at by hand.
    static let mountPath = "/peachcommander-volume"
}

extension DockerConnection {

    // MARK: - Reaching a volume

    struct VolumeAccess {
        var containerID: String
        /// The path inside that container at which the volume's root sits.
        var prefix: String
        var canExec: Bool
    }

    /// A container through which `volume` can be read, making one if there is none.
    func volumeAccess(_ volume: DockerVolume) throws -> VolumeAccess {
        let inventory = try self.inventory()

        // A container that already mounts it is free, needs no cleanup, and — when it happens to
        // be running — is also the only way delete and rename can work inside the volume.
        var best: (DockerContainer, DockerMount)?
        for container in inventory.containers {
            for mount in container.mounts where mount.type == "volume" && mount.name == volume.name {
                if best == nil || (container.isRunning && !best!.0.isRunning) {
                    best = (container, mount)
                }
            }
        }
        if let (container, mount) = best {
            return VolumeAccess(containerID: container.id, prefix: mount.destination,
                                canExec: container.isRunning)
        }

        if let existing = helperContainers[volume.name] {
            return VolumeAccess(containerID: existing, prefix: DockerHelper.mountPath, canExec: false)
        }

        guard let image = try helperImage() else { throw DockerFSError.cannotList }
        let name = "peachcommander-volume-" + UUID().uuidString.prefix(8).lowercased()
        let id = try api.createHelper(name: name, image: image, volume: volume.name,
                                      at: DockerHelper.mountPath)
        helperContainers[volume.name] = id
        return VolumeAccess(containerID: id, prefix: DockerHelper.mountPath, canExec: false)
    }

    private func helperImage() throws -> String? {
        if !settings.helperImage.isEmpty { return settings.helperImage }
        return try api.anyLocalImage()
    }

    /// Remove helper containers left behind by a Peach Commander that is no longer running.
    ///
    /// Only those: a second window of this application has its own mount and its own helpers, and
    /// sweeping those away would break a panel somebody is looking at. The owner is recorded as a
    /// process id, and a helper is only removed when that process is gone.
    func sweepAbandonedHelpers() {
        guard let list = try? api.client.json(path: "/containers/json",
                                              query: ["all": "true",
                                                      "filters": #"{"label":["\#(DockerHelper.label)=1"]}"#])
                as? [[String: Any]] else { return }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        for item in list {
            guard let id = item["Id"] as? String else { continue }
            let labels = (item["Labels"] as? [String: String]) ?? [:]
            let owner = Int32(labels[DockerHelper.pidLabel] ?? "") ?? -1
            if owner == ownPID { continue }
            // `kill(pid, 0)` answers ESRCH for a process that no longer exists. A pid that has
            // since been reused belongs to someone else, who is not this application — so the
            // worst case is a helper that outlives its session and is swept on a later launch.
            if owner > 0, kill(owner, 0) == 0 { continue }
            try? api.remove(container: id)
        }
    }

    // MARK: - Where a write lands

    /// The container and absolute inner path a virtual path writes to, refusing the levels of the
    /// tree that are not a filesystem at all.
    func writeTarget(_ path: String) throws -> (containerID: String, inner: String,
                                                canExec: Bool, mount: DockerMount?) {
        // The log is not a path in the container, so nothing may be written *to* it. Without this a
        // copy onto the row would create a real `/docker-logs.txt` inside the container — which then
        // wins over the synthetic entry and looks like the log having been overwritten.
        if try logContainer(for: path) != nil { throw DockerFSError.unsupported }
        let inventory = try self.inventory()
        switch inventory.route(path) {
        case .container(let container, let inner):
            if (try? api.readOnlyRootfs(container: container.id)) == true,
               inventory.mount(for: container, inner: inner) == nil {
                throw DockerFSError.readOnly
            }
            let mount = inventory.mount(for: container, inner: inner)
            if let mount, !mount.readWrite { throw DockerFSError.readOnly }
            return (container.id, inner, container.canExec, mount)

        case .volume(let volume, let inner):
            let access = try volumeAccess(volume)
            return (access.containerID,
                    DockerPath.join(access.prefix, String(inner.dropFirst())),
                    access.canExec, nil)

        default:
            // "/", a section, a project, a service: these are a view of the engine, not a place
            // files can be put.
            throw DockerFSError.unsupported
        }
    }

    // MARK: - Upload / mkdir

    func upload(localPath: String, to path: String, progress: @escaping (Int) -> Bool) throws {
        // Checked on the destination itself, because `writeTarget` below is asked about the *parent*
        // and would not see the name being written.
        if try logContainer(for: path) != nil { throw DockerFSError.unsupported }
        let (parentPath, leaf) = DockerPath.split(path)
        let target = try writeTarget(parentPath)
        let attributes = try? FileManager.default.attributesOfItem(atPath: localPath)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let posix = (attributes?[.posixPermissions] as? NSNumber)?.uint32Value ?? 0o644
        let modified = (attributes?[.modificationDate] as? Date) ?? Date()

        // uid/gid 0 in the header, which is what `docker cp` writes too: the engine applies the
        // tar's ownership as given, and there is no way from here to know what a uid means inside
        // that image. A file that has to belong to the service's own user is chown'd by the user,
        // who can see which it is; guessing would be worse than not trying.
        let head = TarWriter.header(name: leaf, size: size, mode: posix,
                                    mtime: Int64(modified.timeIntervalSince1970),
                                    type: "0", linkName: "")
        var tail = TarWriter.padding(for: size)
        tail.append(Data(repeating: 0, count: 1024))
        let body = DockerClient.RequestBody.tarredFile(
            head: head, path: localPath, size: size, tail: tail,
            onProgress: { sent in progress(size > 0 ? Int((sent * 100) / size) : 100) })

        let response = try client.send(method: "PUT", path: "/containers/\(target.containerID)/archive",
                                       query: ["path": target.inner],
                                       body: body, contentType: "application/x-tar")
        guard (200..<300).contains(response.status) else {
            throw Self.writeError(status: response.status, message: response.message)
        }
    }

    func makeDirectory(_ path: String) throws {
        let (parentPath, leaf) = DockerPath.split(path)
        let target = try writeTarget(parentPath)
        let tar = TarWriter.directory(named: leaf, mtime: Int64(Date().timeIntervalSince1970))
        do {
            try api.upload(container: target.containerID, into: target.inner, tar: tar)
        } catch let error as DockerError {
            if case .http(let status, let message) = error {
                throw Self.writeError(status: status, message: message)
            }
            throw error
        }
    }

    // MARK: - Delete / rename (the two the engine cannot do)

    func delete(_ path: String) throws {
        let target = try writeTarget(path)
        guard target.canExec, settings.execFallback else { throw DockerFSError.needsRunningContainer }
        _ = try runTool(container: target.containerID, tool: "rm",
                        arguments: ["-r", "-f", "--", target.inner])
    }

    func rename(_ from: String, to: String) throws {
        let source = try writeTarget(from)
        let destination = try writeTarget(to)
        guard source.containerID == destination.containerID else { throw DockerFSError.unsupported }
        guard source.canExec, settings.execFallback else { throw DockerFSError.needsRunningContainer }
        _ = try runTool(container: source.containerID, tool: "mv",
                        arguments: ["-f", "--", source.inner, destination.inner])
    }

    /// Run a standard utility by trying the places it lives, without a shell.
    ///
    /// The arguments go to `execve` as an argument vector, so a file called `; rm -rf /` is a file
    /// called `; rm -rf /` and nothing else — which is the reason this can take a path the user
    /// typed at all.
    @discardableResult
    func runTool(container: String, tool: String, arguments: [String]) throws -> String {
        let candidates: [[String]] = [
            ["/bin/\(tool)"], ["/usr/bin/\(tool)"], ["/bin/busybox", tool],
        ]
        var lastMessage = ""
        for candidate in candidates {
            guard let result = try? api.exec(container: container, argv: candidate + arguments) else {
                continue
            }
            if result.exitCode == 0 { return result.output }
            lastMessage = result.errorText.isEmpty ? result.output : result.errorText
            // A non-zero exit from a tool that ran is a real answer — "read-only file system",
            // "permission denied" — and trying the next path would only re-run it.
            if !lastMessage.isEmpty { break }
        }
        throw Self.toolError(lastMessage)
    }

    /// What a standard utility's own complaint means.
    ///
    /// These sentences are the only report there is: the engine returns the exec's exit code and
    /// its stderr, and nothing structured. They are worth reading rather than flattening into
    /// "it did not work", because the two that actually happen are different problems with
    /// different answers — a read-only mount is a `docker run` flag, and "operation not
    /// permitted" is the container's own user not owning the file.
    private static func toolError(_ message: String) -> Error {
        let text = message.lowercased()
        if text.contains("read-only") { return DockerFSError.readOnly }
        if text.contains("permission denied") || text.contains("not permitted")
            || text.contains("operation not permitted") {
            return DockerFSError.permissionDenied
        }
        if text.contains("no such file") || text.contains("not found") {
            return DockerFSError.notFound
        }
        return message.isEmpty ? DockerFSError.needsRunningContainer : DockerFSError.unsupported
    }

    private static func writeError(status: Int, message: String) -> Error {
        let text = message.lowercased()
        if text.contains("read-only") { return DockerFSError.readOnly }
        if text.contains("permission denied") || text.contains("not permitted") {
            return DockerFSError.permissionDenied
        }
        switch status {
        case 403: return DockerFSError.permissionDenied
        case 404: return DockerFSError.notFound
        case 409: return DockerFSError.needsRunningContainer
        default: return DockerError.http(status: status, message: message)
        }
    }
}
