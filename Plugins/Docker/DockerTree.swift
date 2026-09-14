// SPDX-License-Identifier: Apache-2.0
// DockerTree.swift — the shape the panel walks, and how a path in it turns back into an engine
// object.
//
//     /
//     ├── Compose Projects/<project>/<service>[/<container>]/…
//     ├── Standalone Containers/<container>/…
//     └── Volumes/<volume>/…
//
// Two decisions in here are worth stating, because both could reasonably have gone the other way.
//
// **The three section names are English, always.** They are path components: they end up in the
// panel's location bar, in a tab that is restored after a restart, in a script someone writes.
// A component that changed with the interface language would break every one of those the first
// time somebody switched to German, so the tree is addressed in English and only the *columns*
// are translated.
//
// **A service with one container has no container level.** `…/my-stack/backend/etc` is the
// backend's `/etc` when the service runs a single replica, and `…/my-stack/backend/backend-2/etc`
// when it runs three. Which it is is decided from the live container list at the moment the path
// is resolved, not guessed from the shape of the path — so the two cases cannot be confused, and
// scaling a service up while a panel sits inside it moves the panel's directory rather than
// silently pointing it at a different container.

import Foundation

enum DockerSection: String, CaseIterable {
    case composeProjects = "Compose Projects"
    case standaloneContainers = "Standalone Containers"
    case volumes = "Volumes"
}

/// What a virtual path turns out to mean.
enum DockerRoute {
    case root
    case section(DockerSection)
    case composeProject(String)
    /// Only reached for a service that runs more than one container.
    case composeService(project: String, service: String)
    /// A path inside a container's own filesystem. `inner` is absolute, "/" for its root.
    case container(DockerContainer, inner: String)
    /// A path inside a volume. `inner` is absolute within the volume, "/" for its root.
    case volume(DockerVolume, inner: String)
    case notFound
}

/// A snapshot of what the engine currently has.
///
/// Cached for a moment rather than fetched per call: drawing one directory of 200 rows asks for a
/// content row per entry, and each of those has to resolve a path. Two seconds is long enough to
/// make that free and short enough that a container someone just started shows up on the next
/// keystroke.
struct DockerInventory {
    var containers: [DockerContainer] = []
    var volumes: [DockerVolume] = []
    var taken = Date.distantPast

    var isStale: Bool { Date().timeIntervalSince(taken) > 2.0 }

    /// Containers that belong to a compose project, by project then service.
    func composeContainers() -> [String: [String: [DockerContainer]]] {
        var grouped: [String: [String: [DockerContainer]]] = [:]
        for container in containers {
            guard !container.isComposeOneOff,
                  let project = container.composeProject,
                  let service = container.composeService else { continue }
            grouped[project, default: [:]][service, default: []].append(container)
        }
        for (project, services) in grouped {
            for (service, list) in services {
                grouped[project]![service] = list.sorted { $0.name < $1.name }
            }
        }
        return grouped
    }

    /// Containers that are not part of a compose stack — plus the one-off `compose run`
    /// containers, which belong to a stack by label but not to its steady state.
    func standaloneContainers() -> [DockerContainer] {
        containers
            .filter { $0.isComposeOneOff || $0.composeProject == nil || $0.composeService == nil }
            .sorted { $0.name < $1.name }
    }

    func composeProjects() -> [String] { composeContainers().keys.sorted() }
}

enum DockerPath {
    /// Split a PFX path into its components, dropping empties so "/a//b/" and "/a/b" agree.
    static func components(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    /// Join components back into an absolute path inside a container or volume.
    static func inner(_ components: ArraySlice<String>) -> String {
        components.isEmpty ? "/" : "/" + components.joined(separator: "/")
    }

    /// The parent of an absolute path, and its leaf.
    static func split(_ path: String) -> (parent: String, leaf: String) {
        var trimmed = path
        while trimmed.count > 1, trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let slash = trimmed.lastIndex(of: "/") else { return ("/", trimmed) }
        let leaf = String(trimmed[trimmed.index(after: slash)...])
        let parent = slash == trimmed.startIndex ? "/" : String(trimmed[trimmed.startIndex..<slash])
        return (parent, leaf)
    }

    /// `base` with `leaf` appended, keeping exactly one separator.
    static func join(_ base: String, _ leaf: String) -> String {
        if base.isEmpty || base == "/" { return "/" + leaf }
        return base.hasSuffix("/") ? base + leaf : base + "/" + leaf
    }
}

extension DockerInventory {

    /// Resolve a virtual path against this snapshot.
    func route(_ path: String) -> DockerRoute {
        let parts = DockerPath.components(path)
        guard let first = parts.first else { return .root }
        guard let section = DockerSection(rawValue: first) else { return .notFound }
        let rest = parts.dropFirst()

        switch section {
        case .composeProjects:
            return composeRoute(Array(rest))

        case .standaloneContainers:
            guard let name = rest.first else { return .section(.standaloneContainers) }
            guard let container = standaloneContainers().first(where: { $0.name == name }) else {
                return .notFound
            }
            return .container(container, inner: DockerPath.inner(rest.dropFirst()))

        case .volumes:
            guard let name = rest.first else { return .section(.volumes) }
            guard let volume = volumes.first(where: { $0.name == name }) else { return .notFound }
            return .volume(volume, inner: DockerPath.inner(rest.dropFirst()))
        }
    }

    private func composeRoute(_ parts: [String]) -> DockerRoute {
        guard let project = parts.first else { return .section(.composeProjects) }
        let grouped = composeContainers()
        guard let services = grouped[project] else { return .notFound }
        guard parts.count > 1 else { return .composeProject(project) }
        let service = parts[1]
        guard let replicas = services[service], !replicas.isEmpty else { return .notFound }
        let rest = parts.dropFirst(2)

        if replicas.count == 1 {
            return .container(replicas[0], inner: DockerPath.inner(rest))
        }
        guard let replicaName = rest.first else {
            return .composeService(project: project, service: service)
        }
        guard let container = replicas.first(where: { $0.name == replicaName }) else {
            return .notFound
        }
        return .container(container, inner: DockerPath.inner(rest.dropFirst()))
    }

    /// The mount, if any, that owns `inner` inside `container` — the deepest destination that is
    /// a prefix of the path. Used for the Access and Mount columns, and to tell a write that is
    /// about to hit a read-only mount from one that is not.
    func mount(for container: DockerContainer, inner: String) -> DockerMount? {
        var best: DockerMount?
        for mount in container.mounts {
            let destination = mount.destination
            guard inner == destination || inner.hasPrefix(destination.hasSuffix("/")
                                                          ? destination : destination + "/") else {
                continue
            }
            if best == nil || destination.count > best!.destination.count { best = mount }
        }
        return best
    }
}
