// SPDX-License-Identifier: Apache-2.0
// DockerCommands.swift — the actions on a container or a volume, in the panel's context menu.
//
// The drive answers "what is in here". These answer the questions a drive cannot: what is this
// container, what has it been saying, what is really mounted underneath this directory, and where
// is the volume that holds it. They are contributions (`contrib.h`), declared in Info.plist and
// gated on `panelScheme` — the key that says which filesystem the panel is showing, so an item meant
// for a container cannot offer itself over a local folder that happens to be called the same thing.
//
// **They do not borrow the mount's connection.** A command runs on the main thread while the mount's
// own calls run on the host's serial queue, and `DockerClient` owns one socket and is explicitly not
// safe to use from two threads: sharing it would corrupt a listing that happened to be in flight.
// What is shared is the *endpoint*, which is a value. Each command opens its own client, which on a
// Unix socket costs about a millisecond, and closes it again.

import AppKit

// MARK: - Which engines are mounted

/// Endpoint and settings per mounted connection id ("docker:Colima").
///
/// Written from the host's file-system queue when a mount opens and closes, read from the main
/// thread when a command runs — hence the lock. It holds values, not the connection.
private let dockerMountLock = NSLock()
private nonisolated(unsafe) var dockerMounts: [String: (DockerEndpoint, DockerSettings)] = [:]

func dockerRegisterMount(id: String, endpoint: DockerEndpoint, settings: DockerSettings) {
    dockerMountLock.lock(); defer { dockerMountLock.unlock() }
    dockerMounts[id] = (endpoint, settings)
}

func dockerForgetMount(id: String) {
    dockerMountLock.lock(); defer { dockerMountLock.unlock() }
    dockerMounts[id] = nil
}

private func dockerMount(for scheme: String) -> (DockerEndpoint, DockerSettings)? {
    dockerMountLock.lock(); defer { dockerMountLock.unlock() }
    if let exact = dockerMounts[scheme] { return exact }
    // One mount is the normal case, and a scheme that is not in the table means the panel is showing
    // a Docker drive this copy of the plugin did not open — which cannot happen, but answering the
    // only mount there is beats refusing to act on the drive the user is looking at.
    return dockerMounts.count == 1 ? dockerMounts.values.first : nil
}

// MARK: - Host services, read back

private struct CommandContext {
    var services: PcHostServices
    var cursorPath: String
    var panelScheme: String

    func value(_ key: String) -> String? {
        guard let get = services.getContext else { return nil }
        var buffer = [CChar](repeating: 0, count: 4096)
        guard key.withCString({ get(services.host, $0, &buffer, 4096) }) == 1 else { return nil }
        let text = String(cString: buffer)
        return text.isEmpty ? nil : text
    }

    func inform(_ message: String) {
        guard let present = services.presentInfo else { return }
        L("Docker").withCString { title in
            message.withCString { body in present(services.host, title, body) }
        }
    }

    /// Ask before changing the machine. Answers itself when a scenario says how to answer, because a
    /// modal raised from a plugin stops an automation run dead: the runner is an async task on the
    /// main actor and does not resume inside the modal's nested runloop. Same shape as the AI
    /// plugins' `PC_AI_DIRECT_APPLY`.
    func confirm(_ message: String, title: String) -> Bool {
        if let scripted = dockerProbe("PC_DOCKER_CONFIRM") { return scripted != "0" }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L("Continue"))
        alert.addButton(withTitle: L("Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    func reload() {
        services.reloadActivePanel?(services.host)
    }

    func open(_ path: String) {
        guard let openPath = services.openPath else { return }
        path.withCString { openPath(services.host, $0) }
    }
}

// MARK: - The entry point

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?,
                         _ services: UnsafePointer<PcHostServices>?) {
    guard let commandId, let services else { return }
    let id = String(cString: commandId)
    let svc = services.pointee

    var buffer = [CChar](repeating: 0, count: 4096)
    let gotCursor = svc.cursorPath.map { $0(svc.host, &buffer, 4096) } ?? 0
    var context = CommandContext(services: svc,
                                 cursorPath: gotCursor != 0 ? String(cString: buffer) : "",
                                 panelScheme: "")
    context.panelScheme = context.value("panelScheme") ?? ""

    // The declarative `when` already gates these to a Docker mount, but a command is also reachable
    // from the command browser, a shortcut and a button bar — none of which consult it.
    guard context.panelScheme.hasPrefix("docker:"),
          let (endpoint, settings) = dockerMount(for: context.panelScheme) else {
        context.inform(L("This works inside a Docker drive."))
        return
    }

    let client = DockerClient(endpoint: endpoint)
    defer { client.close() }
    do {
        try client.handshake()
    } catch {
        context.inform(String(format: L("No Docker engine answered at %@."), endpoint.url))
        return
    }
    // Not `cleanup()` at the end of this: that removes throwaway containers, and the ones on the
    // engine belong to the *mount*, not to this short-lived client. Only the socket is ours, and the
    // `defer` above closes it.
    let connection = DockerConnection(client: client, settings: settings)

    guard let inventory = try? connection.inventory(refresh: true) else {
        context.inform(L("The Docker engine could not be asked."))
        return
    }
    let route = inventory.route(context.cursorPath)

    // Start/stop/restart/pause/unpause: the id's last component is the engine's own verb, so there
    // is one branch rather than five that differ by a string.
    if id.hasPrefix("plugin.docker.lifecycle.") {
        let verb = String(id.dropFirst("plugin.docker.lifecycle.".count))
        lifecycle(route, connection, context, verb: verb)
        return
    }

    switch id {
    case "plugin.docker.inspect":      inspect(route, connection, context)
    case "plugin.docker.logs":         showLogs(route, connection, context)
    case "plugin.docker.mounts":       showMounts(route, inventory, context)
    case "plugin.docker.copyid":       copyIdentifier(route, context)
    case "plugin.docker.jumptovolume": jumpToVolume(route, inventory, context)
    case "plugin.docker.composeproject": openComposeProject(route, context)
    default: break
    }
}

// MARK: - The actions

private func inspect(_ route: DockerRoute, _ connection: DockerConnection, _ context: CommandContext) {
    switch route {
    case .container(let container, _):
        guard let detail = try? connection.api.inspect(container: container.id) else {
            return context.inform(L("The Docker engine could not be asked."))
        }
        DockerTextWindow.show(title: L("Docker Inspect"), subtitle: container.name,
                              text: prettyJSON(detail))
    case .volume(let volume, _):
        guard let detail = try? connection.api.inspect(volume: volume.name) else {
            return context.inform(L("The Docker engine could not be asked."))
        }
        DockerTextWindow.show(title: L("Docker Inspect"), subtitle: volume.name,
                              text: prettyJSON(detail))
    default:
        context.inform(L("Put the cursor on a container or a volume."))
    }
}

private func showLogs(_ route: DockerRoute, _ connection: DockerConnection, _ context: CommandContext) {
    guard case .container(let container, _) = route else {
        return context.inform(L("Put the cursor on a container."))
    }
    guard let text = try? connection.api.logs(container: container.id) else {
        return context.inform(L("The Docker engine could not be asked."))
    }
    DockerTextWindow.show(
        title: L("Docker Logs"), subtitle: container.name,
        // An empty log is an answer, and one worth writing out: an empty window reads as a failure.
        text: text.isEmpty ? L("This container has written nothing to its log.") : text)
}

private func showMounts(_ route: DockerRoute, _ inventory: DockerInventory, _ context: CommandContext) {
    guard case .container(let container, _) = route else {
        return context.inform(L("Put the cursor on a container."))
    }
    guard !container.mounts.isEmpty else {
        return context.inform(String(format: L("“%@” mounts nothing."), container.name))
    }
    let rows = container.mounts
        .sorted { $0.destination < $1.destination }
        .map { "\($0.destination)\t\($0.accessTag)\t\($0.display)" }
    DockerTextWindow.show(title: L("Docker Mounts"), subtitle: container.name,
                          text: rows.joined(separator: "\n"))
}

private func copyIdentifier(_ route: DockerRoute, _ context: CommandContext) {
    let value: String
    switch route {
    case .container(let container, _): value = container.id
    case .volume(let volume, _): value = volume.name
    default: return context.inform(L("Put the cursor on a container or a volume."))
    }
    // The FULL id, not the twelve characters the column shows: what this is for is pasting into a
    // `docker` command, and a short id is a prefix that can stop being unique.
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

private func jumpToVolume(_ route: DockerRoute, _ inventory: DockerInventory,
                          _ context: CommandContext) {
    guard case .container(let container, let inner) = route,
          let mount = inventory.mount(for: container, inner: inner) else {
        return context.inform(L("This directory is not a Docker volume."))
    }
    guard mount.type == "volume", !mount.name.isEmpty else {
        return context.inform(String(format: L("This is a %@, not a volume."), mount.display))
    }
    // The whole reason the host's `openPath` had to learn about mounts: the destination is a path in
    // *this* drive, and the check in front of it used to be `FileManager.fileExists`.
    context.open(DockerPath.join("/" + DockerSection.volumes.rawValue, mount.name))
}

private func openComposeProject(_ route: DockerRoute, _ context: CommandContext) {
    guard case .container(let container, _) = route, let project = container.composeProject else {
        return context.inform(L("This container is not part of a Compose project."))
    }
    context.open(DockerPath.join("/" + DockerSection.composeProjects.rawValue, project))
}

/// Start, stop, restart, pause or resume the container under the cursor.
///
/// The one group of actions here that changes the machine rather than reading it, so it asks first —
/// and then tells the panel to reload, because the Status column it just changed is drawn from a
/// listing that was taken before.
private func lifecycle(_ route: DockerRoute, _ connection: DockerConnection,
                       _ context: CommandContext, verb: String) {
    guard case .container(let container, _) = route else {
        return context.inform(L("Put the cursor on a container."))
    }
    guard context.confirm(String(format: L("Carry this out on the container “%@”?"), container.name),
                          title: verb.capitalized) else { return }
    do {
        try connection.api.lifecycle(container: container.id, action: verb)
    } catch {
        let reason = (error as? DockerError)?.engineMessage ?? L("The Docker engine could not be asked.")
        return context.inform(String(format: L("The engine refused: %@"), reason))
    }
    // The Status column is drawn from a listing taken before this ran, so without the reload the
    // container the user just stopped goes on saying `● running` until something else refreshes.
    context.reload()
}

// MARK: - Formatting

/// The engine's answer, readable. Sorted keys so two inspections of the same thing can be compared
/// by eye, which is most of what anybody does with this.
private func prettyJSON(_ object: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: object,
                                                 options: [.prettyPrinted, .sortedKeys]),
          let text = String(data: data, encoding: .utf8) else {
        return String(describing: object)
    }
    return text
}
