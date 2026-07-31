// SPDX-License-Identifier: Apache-2.0
// aiplugin.swift — AIAssistant.ptxplugin entry points (contrib.h behavior ABI).
//
// The removable AI assistant. PcMakeView builds the full chat panel (moved here from
// the app) backed by a RemoteAutomationCore that drives the host's file manager over
// the automation C-ABI; AgentSession / AppleNativeToolSession (in PCAutomation, which
// this bundle links) are unchanged — only the core is remote. The host applies the
// permission policy, so plan-then-confirm still flows through it.

import AppKit
import PCAutomation

private var aiVCKey: UInt8 = 0   // associates the view controller's lifetime with its container view

/// The live chat view controller (weak) + a prompt queued before it exists, so an
/// "AI ▸" context-menu skill can send even if the panel isn't mounted yet.
@MainActor private weak var liveChatVC: AIChatViewController?
/// The services table the live chat was built with, so PcNotifyView("theme") can re-read colours.
@MainActor private var liveChatServices: PcHostServices?
@MainActor private var pendingSkillPrompt: (prompt: String, title: String)?
@MainActor private var pendingTableRequest: (path: String, name: String)?

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?,
                       _ containerId: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    guard let services else { return nil }
    let svc = services.pointee
    // The assistant preferences (model + system prompt) now live on the host's unified
    // Settings ▸ AI page; the plugin no longer contributes a separate settings pane.
    // Chat sidebar: return a container immediately; build the (async) chat into it.
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 520))
    Task { @MainActor in
        let vc = await AIPlugin.buildChat(svc)
        let v = vc.view
        v.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: container.topAnchor),
            v.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            v.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        objc_setAssociatedObject(container, &aiVCKey, vc, .OBJC_ASSOCIATION_RETAIN)
        liveChatVC = vc
        // F-338: colour the chat for the host's theme, and remember the services table so a later
        // theme change can be re-read (PcNotifyView below).
        liveChatServices = svc
        vc.applyTheme(svc)
        await vc.start()
        vc.focusInput()
        // A skill invoked before the panel existed queued its request — run it now.
        if let q = pendingSkillPrompt { pendingSkillPrompt = nil; vc.sendInNewChat(q.prompt, title: q.title) }
        if let t = pendingTableRequest { pendingTableRequest = nil; vc.sendTableRequest(path: t.path, displayName: t.name) }
        // DEBUG host-verification: auto-send a probe message and log the transcript.
        if let probe = ProcessInfo.processInfo.environment["PC_AI_PROBE"] {
            await vc.sendProgrammatically(probe)
            try? await Task.sleep(nanoseconds: 14_000_000_000)
            if ProcessInfo.processInfo.environment["PC_AI_CONFIRM"] != nil {
                vc.debugConfirm()
                try? await Task.sleep(nanoseconds: 8_000_000_000)
            }
            vc.dumpTranscriptToLog()
        }
    }
    return Unmanaged.passRetained(container).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    Unmanaged<NSView>.fromOpaque(view).release()
}

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let commandId, let services else { return }
    let id = String(cString: commandId)
    let svc = services.pointee

    if id == "plugin.ai.toggle" {
        presentAIView(svc)
        return
    }
    // "Make a table" uses guided generation (read file → structured table).
    if id == "plugin.ai.skill.make-table" {
        guard let path = AIPlugin.cursorPath(svc) else { return }
        let name = (path as NSString).lastPathComponent
        Task { @MainActor in
            presentAIView(svc)
            if let vc = liveChatVC { vc.sendTableRequest(path: path, displayName: name) }
            else { pendingTableRequest = (path, name) }
        }
        return
    }
    // Other "AI ▸" skills: build the prompt from the skill template + the cursor path.
    if id.hasPrefix("plugin.ai.skill.") {
        let skillId = String(id.dropFirst("plugin.ai.skill.".count))
        guard let skill = SkillCatalog.fileSkills.first(where: { $0.id == skillId }),
              let path = AIPlugin.cursorPath(svc) else { return }
        let name = (path as NSString).lastPathComponent
        sendSkill(skill.prompt(name: name, path: path), title: "\(skill.title) – \(name)", svc)
    }
    // "AI ▸" folder skill (panel background): acts on the active folder.
    if id.hasPrefix("plugin.ai.folderskill.") {
        let skillId = String(id.dropFirst("plugin.ai.folderskill.".count))
        guard let skill = SkillCatalog.folderSkills.first(where: { $0.id == skillId }),
              let folder = AIPlugin.hostContext(svc, "dir") else { return }
        let name = (folder as NSString).lastPathComponent
        sendSkill(skill.prompt(name: name, path: folder), title: "\(skill.title) – \(name)", svc)
    }
}

/// Reveal the panel and run a skill in ITS OWN fresh chat (queued if the view isn't
/// mounted yet), so each "AI ▸" action is a separate, discardable conversation.
private func sendSkill(_ base: String, title: String, _ svc: PcHostServices) {
    let prompt = base + "\n\n" + String(localized: "Respond in the language of this request.")
    Task { @MainActor in
        presentAIView(svc)
        if let vc = liveChatVC { vc.sendInNewChat(prompt, title: title) }
        else { pendingSkillPrompt = (prompt, title) }   // run once PcMakeView builds the VC
    }
}

private func presentAIView(_ svc: PcHostServices) {
    "plugin.ai.view".withCString { v in "".withCString { r in
        svc.presentSidebarView?(svc.host, v, r)
    } }
}

@_cdecl("PcNotifyView")
public func PcNotifyView(_ view: UnsafeMutableRawPointer?, _ key: UnsafePointer<CChar>?, _ value: UnsafePointer<CChar>?) {
    guard let key, String(cString: key) == "theme" else { return }
    MainActor.assumeIsolated { liveChatVC?.applyTheme(liveChatServices) }
}

// MARK: - Chat construction (mirrors the app's former openAIChat wiring)

enum AIPlugin {
    @MainActor
    static func buildChat(_ svc: PcHostServices) async -> AIChatViewController {
        let (mcp, mcpTools) = await connectMCP()
        let core = RemoteAutomationCore(services: svc, mcp: mcp, mcpTools: mcpTools)
        let root = hostContext(svc, "configRoot") ?? NSHomeDirectory()
        let cfg = AIPluginConfig.load(root: root)   // plugin-owned prefs (Settings pane)
        let (provider, providerName, useNative) = await pickProvider(svc, preference: cfg.modelPreference)
        let relay = ConfirmationRelay()
        let defaultSys = "You are the Peach Commander assistant. Help the user manage files in the "
            + "two-panel file manager. To answer what is INSIDE a file, you MUST call read_file "
            + "with its path — use get_context and list_directory to find exact paths in the "
            + "current folder. The search tool only finds files by name and does NOT return their "
            + "contents. Never guess or invent a file's contents. "
            + "When the user asks you to CREATE or SAVE a file, first gather the needed data with "
            + "the read tools (list_directory, read_file, hash_file, stat_path), then build the full "
            + "text yourself and call write_file EXACTLY ONCE with the complete content and the "
            + "target path. Do NOT call set_config, search, or unrelated tools unless the user "
            + "explicitly asks. Always show a plan before making changes. "
            + "Always reply in the same language the user writes in."
        let sys = cfg.systemPrompt.isEmpty ? defaultSys : cfg.systemPrompt
        let factory: @Sendable (AgentSession.Snapshot?) -> AgentSession = { snapshot in
            var native: (any NativeTurnRunner)?
            #if canImport(FoundationModels)
            if useNative, #available(macOS 26, *) {
                native = AppleNativeToolSession(core: core, policy: .standard, instructions: sys, broker: relay,
                                                onProgress: { n in await relay.reportProgress(n) },
                                                onPartial: { t in await relay.reportPartial(t) })
            }
            #endif
            if let snapshot {
                return AgentSession(restoring: snapshot, core: core, provider: provider, policy: .standard, nativeRunner: native)
            }
            return AgentSession(core: core, provider: provider, policy: .standard, systemPrompt: sys, nativeRunner: native)
        }
        let dir = URL(fileURLWithPath: root).appendingPathComponent("aichat/sessions")
        let manager = SessionManager(store: SessionStore(directory: dir), makeSession: factory)
        let vc = AIChatViewController(
            manager: manager, providerName: providerName,
            contextProvider: {
                guard let ctx = try? await core.context() else { return nil }
                return ChatContext(folder: ctx.activePanelPath, selection: ctx.selection)
            },
            onOpenPath: { path in path.withCString { p in svc.openPath?(svc.host, p) } },
            policyProvider: nil)   // the host applies its configured autonomy policy
        relay.target = vc
        return vc
    }

    @MainActor
    private static func pickProvider(_ svc: PcHostServices, preference: String) async -> (any ModelProvider, String, Bool) {
        let env = ProcessInfo.processInfo.environment
        let base = env["PEACHCMD_AI_BASE"] ?? hostContext(svc, "AI.CloudBaseURL")
        let cloudConfigured = (base?.isEmpty == false)
        // The plugin's model preference (Settings pane) gates the choice; "auto" prefers
        // a configured cloud endpoint, else the on-device model.
        let wantCloud = preference == "cloud" || (preference == "auto" && cloudConfigured)
        if wantCloud, let base, let url = URL(string: base) {
            let model = env["PEACHCMD_AI_MODEL"] ?? hostContext(svc, "AI.CloudModel") ?? "local"
            return (OpenAICompatibleProvider(baseURL: url, model: model, apiKey: cloudKey(svc)),
                    String(format: String(localized: "Cloud: %@"), model), false)
        }
        if preference != "cloud", #available(macOS 26, *) {   // don't fall back to local if cloud was explicitly required
            let fm = AppleFoundationModelsProvider()
            if await fm.isAvailable {
                return (fm, String(localized: "Apple Intelligence (on-device)"), true)
            }
        }
        return (PlaceholderModelProvider(), String(localized: "No model configured"), false)
    }

    /// Connect to an external MCP server if configured (env PEACHCMD_MCP_HOST/PORT) and
    /// return its tools as catalogue entries (KI-01). Best-effort; failures = no tools.
    private static func connectMCP() async -> (MCPClient?, [ToolDefinition]) {
        let env = ProcessInfo.processInfo.environment
        guard let host = env["PEACHCMD_MCP_HOST"],
              let portStr = env["PEACHCMD_MCP_PORT"], let port = UInt16(portStr) else { return (nil, []) }
        let client = MCPClient(host: host, port: port)
        do {
            try await client.initialize()
            let infos = try await client.listTools()
            let tools = infos.map {
                ToolDefinition($0.name, .runCommand,
                               $0.description.isEmpty ? "External MCP tool." : $0.description,
                               [ToolParameter("arguments", .object, "Tool arguments as a JSON object.", required: false)])
            }
            return (client, tools)
        } catch { return (nil, []) }
    }

    /// Read a host context value via the getContext service callback.
    static func hostContext(_ svc: PcHostServices, _ key: String) -> String? {
        guard let fn = svc.getContext else { return nil }
        var buf = [CChar](repeating: 0, count: 4096)
        let ok = key.withCString { k in fn(svc.host, k, &buf, 4096) }
        return ok == 1 ? String(cString: buf) : nil
    }

    /// The Cloud API key: from the environment, else the host Keychain via crypt.
    static func cloudKey(_ svc: PcHostServices) -> String? {
        if let e = ProcessInfo.processInfo.environment["PEACHCMD_AI_KEY"], !e.isEmpty { return e }
        guard let fn = svc.crypt else { return nil }
        var buf = [CChar](repeating: 0, count: 2048)
        let rc = "AI.CloudKey".withCString { s in fn(svc.host, Int32(PC_CRYPT_LOAD_PASSWORD), s, &buf, 2048) }
        let key = rc == Int32(PC_OK) ? String(cString: buf) : ""
        return key.isEmpty ? nil : key
    }

    /// The full path of the file under the cursor (for "AI ▸" skills).
    static func cursorPath(_ svc: PcHostServices) -> String? {
        guard let fn = svc.cursorPath else { return nil }
        var buf = [CChar](repeating: 0, count: 4096)
        return fn(svc.host, &buf, 4096) == 1 ? String(cString: buf) : nil
    }
}
