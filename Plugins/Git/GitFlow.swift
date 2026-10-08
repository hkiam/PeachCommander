// SPDX-License-Identifier: Apache-2.0
// GitFlow.swift — git-flow in the Git panel (phase 9).
//
// A convention, not a feature of git: feature branches off develop, release and hotfix branches that
// end in main with a tag and go back into develop. The names come from Settings ▸ Git; the merges and
// the tag are ordinary git calls (`PluginGit.flowStartArguments` / `flowFinishArguments`), run through
// the panel's own sequence, so a conflict stops it the way any merge stops — the panel's banner offers
// Continue and Abort, and finishing again picks up where it stopped (`FlowFinishState`).

import AppKit

extension GitPanelView: NSMenuDelegate {
    /// The pull-down in the header: its face is a symbol, its menu is built when it opens — from the
    /// branches the last reload read, so opening it never waits for git.
    func setUpFlowButton() {
        flowButton.bezelStyle = .texturedRounded
        flowButton.isBordered = false
        flowButton.controlSize = .small
        flowButton.toolTip = L("Git flow")
        (flowButton.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        flowButton.menu?.delegate = self
        flowButton.menu?.autoenablesItems = false
        rebuildFlowMenu()
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === flowButton.menu { rebuildFlowMenu() }
    }

    /// The verification dump reads the menu as it would open.
    func rebuildFlowMenuForReport() { rebuildFlowMenu() }

    private func rebuildFlowMenu() {
        flowButton.removeAllItems()
        flowButton.addItem(withTitle: "")
        flowButton.item(at: 0)?.image = NSImage(systemSymbolName: "arrow.triangle.branch",
                                                accessibilityDescription: L("Git flow"))
        guard let menu = flowButton.menu else { return }
        let hasRepo = root != nil
        for (kind, title) in [(PluginGit.FlowKind.feature, L("Start feature…")),
                              (.release, L("Start release…")), (.hotfix, L("Start hotfix…"))] {
            let item = NSMenuItem(title: title, action: #selector(flowStart(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = kind.rawValue
            item.isEnabled = hasRepo
            menu.addItem(item)
        }
        let flow = GitSettingsStore.current.flow
        let open = localBranches.filter { flow.kind(ofBranch: $0) != nil }.sorted()
        if !open.isEmpty {
            menu.addItem(.separator())
            for branch in open {
                let item = NSMenuItem(title: String(format: L("Finish %@"), branch), action: #selector(flowFinish(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = branch
                item.isEnabled = hasRepo
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let note = NSMenuItem(title: String(format: L("Branches: %@ and %@ — names in Settings ▸ Git"),
                                            flow.mainBranch, flow.developBranch), action: nil, keyEquivalent: "")
        note.isEnabled = false
        menu.addItem(note)
        flowButton.isEnabled = hasRepo
    }

    @objc private func flowStart(_ sender: NSMenuItem) {
        guard let root, let raw = sender.representedObject as? String, let kind = PluginGit.FlowKind(rawValue: raw)
        else { return }
        let flow = GitSettingsStore.current.flow
        let prompt: String
        switch kind {
        case .feature: prompt = String(format: L("Name of the feature (the branch becomes %@name, from %@):"),
                                       flow.featurePrefix, flow.developBranch)
        case .release: prompt = String(format: L("Version of the release (the branch becomes %@version, from %@):"),
                                       flow.releasePrefix, flow.developBranch)
        case .hotfix: prompt = String(format: L("Version of the hotfix (the branch becomes %@version, from %@):"),
                                      flow.hotfixPrefix, flow.mainBranch)
        }
        guard let name = gitPrompt(sender.title, prompt)?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }
        guard PluginGit.isValidFlowName(name) else {
            report(L("Git flow"), String(format: L("“%@” cannot be part of a branch name."), name))
            return
        }
        let base = flow.base(kind)
        let hasDevelop = localBranches.contains(flow.developBranch)
        let hasMain = localBranches.contains(flow.mainBranch)
        // A fresh clone of a git-flow repository has develop only as origin/develop: asked off the main
        // thread, and followed rather than made anew from main.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let remoteDevelop = hasDevelop ? nil : PluginGit.preferredRemoteBranch(
                PluginGitRepo.run(["-C", root] + PluginGit.remoteBranchesArguments(named: flow.developBranch)).out)
            DispatchQueue.main.async {
                self?.startFlow(kind, name: name, root: root, flow: flow, base: base, hasDevelop: hasDevelop,
                                hasMain: hasMain, remoteDevelop: remoteDevelop)
            }
        }
    }

    private func startFlow(_ kind: PluginGit.FlowKind, name: String, root: String, flow: PluginGit.Flow, base: String,
                           hasDevelop: Bool, hasMain: Bool, remoteDevelop: String?) {
        let baseThere = kind == .hotfix ? hasMain : (hasDevelop || remoteDevelop != nil || hasMain)
        guard baseThere else {
            report(L("Git flow"), String(format: L("This repository has no branch %@. Set the branch names in Settings ▸ Git."), base))
            return
        }
        if !hasDevelop, remoteDevelop == nil, kind != .hotfix {
            // Said once, before it happens: the first feature or release of a repository creates develop.
            let alert = NSAlert()
            alert.messageText = String(format: L("Create %@ from %@?"), flow.developBranch, flow.mainBranch)
            alert.informativeText = L("git-flow develops on its own branch and releases into the main one. This repository has no development branch yet.")
            alert.addButton(withTitle: L("Create"))
            alert.addButton(withTitle: L("Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        let calls = PluginGit.flowStartArguments(kind, name: name, flow: flow, hasDevelop: hasDevelop,
                                                 remoteDevelop: remoteDevelop)
        runSequence(calls.map { ["-C", root] + $0 })
    }

    /// Finishing asks git first what is already done — merged into main, tagged, merged into develop —
    /// so a finish that stopped in a conflict and is chosen again carries on instead of repeating.
    @objc private func flowFinish(_ sender: NSMenuItem) {
        guard let root, let branch = sender.representedObject as? String else { return }
        let flow = GitSettingsStore.current.flow
        guard let (kind, name) = flow.kind(ofBranch: branch) else { return }
        let alert = NSAlert()
        alert.messageText = String(format: L("Finish %@?"), branch)
        switch kind {
        case .feature:
            alert.informativeText = String(format: L("It is merged into %@ and then deleted."), flow.developBranch)
        case .release, .hotfix:
            alert.informativeText = String(format: L("It is merged into %@, tagged %@ there, merged into %@ and then deleted."),
                                           flow.mainBranch, flow.tag(for: name), flow.developBranch)
        }
        alert.addButton(withTitle: L("Finish"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let status, status.files.values.contains(where: { $0.summary != .untracked && $0.summary != .ignored }) {
            report(L("Git flow"), L("Commit or stash the changes in the working tree first: finishing switches branches."))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            func ok(_ arguments: [String]) -> Bool { PluginGitRepo.run(["-C", root] + arguments).ok }
            let state = PluginGit.FlowFinishState(
                mergedIntoMain: kind != .feature && ok(PluginGit.isAncestorArguments(branch, of: flow.mainBranch)),
                tagged: kind != .feature && ok(PluginGit.tagExistsArguments(flow.tag(for: name))),
                mergedIntoDevelop: ok(PluginGit.isAncestorArguments(branch, of: flow.developBranch)))
            let calls = PluginGit.flowFinishArguments(kind, name: name, flow: flow, state: state)
            DispatchQueue.main.async {
                self?.runSequence(calls.map { ["-C", root] + $0 }) { done in
                    if done { self?.flash(String(format: L("%@ finished."), branch)) }
                }
            }
        }
    }
}
