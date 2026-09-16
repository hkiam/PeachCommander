// SPDX-License-Identifier: Apache-2.0
// WorkspaceScopeGate.swift - Asking before an operation reaches outside its workspace (F-499).
//
// Modelled on `ImplicitWork`: the arithmetic is a pure type in PCFoundation, and this is where a
// refusal turns into a sentence somebody can act on. Naming the cost and naming the way to pay it
// anyway is the whole difference between a guard people keep and one they switch off.
//
// **Navigation is never checked.** A scope governs what is written, never what is shown — see
// `DECISIONS.md`. What is checked is the destination of a copy, the sources of a delete, and both for
// a move, because those are the three shapes in which an operation leaves the folder it was meant for.

import AppKit
import PCFoundation
import PCOperations

@MainActor
enum WorkspaceScopeGate {

    /// May this operation go ahead?
    ///
    /// Returns true when there is nothing to ask about — no workspace, no root, or everything inside —
    /// so the call site reads as a guard rather than as a special case.
    ///
    /// The sheet's **default button is Cancel**. A destructive question defaulting to yes is how a
    /// dialog becomes something people dismiss without reading, and this one exists precisely for the
    /// moment somebody is moving fast.
    static func allows(scope: WorkspaceScope,
                       workspaceName: String,
                       sources: [String] = [],
                       destination: String? = nil,
                       host: NSWindow? = nil) -> Bool {
        let verdict = ScopeCheck.decide(scope: scope, sources: sources, destination: destination,
                                        resolve: Self.resolve)
        guard case .outside(let offenders, let side) = verdict else { return true }

        // A scripted run answers from the environment rather than hanging on a modal nobody is there
        // to click — the same escape hatch the macro manager and the stash use (F-436).
        if let scripted = AutomationProbe.value("PC_SCOPE") { return scripted == "allow" }
        // **And a scripted run with no answer configured still must not stop**, which is not belt and
        // braces: an automation verb once left a scope behind that matched nothing, so every operation
        // in every *later* scenario was "outside" and fourteen of them hung on this sheet with no
        // `PC_SCOPE` set — reported as "the app never finished", which is a long way from the cause.
        // Refusing is the right default for a guard whose question cannot be put: it is the answer a
        // person clicking Cancel would give, and the log line says why the run saw it.
        if AutomationProbe.isScriptedRun {
            NSLog("[scope] refused in a scripted run with no PC_SCOPE set: %d path(s) outside %@",
                  offenders.count, scope.root)
            return false
        }

        let alert = NSAlert()
        alert.messageText = message(side: side, count: offenders.count, enforcement: scope.enforcement)
        alert.informativeText = detail(scope: scope, workspaceName: workspaceName,
                                       offenders: offenders, side: side)
        alert.alertStyle = .warning

        if scope.enforcement == .refuse {
            alert.addButton(withTitle: String(localized: "OK"))
            alert.runModal()
            return false
        }
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.addButton(withTitle: String(localized: "Do It Anyway"))
        return alert.runModal() == .alertSecondButtonReturn
    }

    /// The same question asked of an `OperationKind`.
    ///
    /// **This is why the check sits on the kind rather than on each caller.** F5, F6, drag-and-drop,
    /// paste, same-panel copy, adding to an archive, repeating an operation from the history and the
    /// stash's bulk operation are all different call sites that build one of these — and every one of
    /// them funnels through `runTransfer` or `enqueueBackground`. Two places, instead of a dozen that
    /// each have to remember.
    ///
    /// Which side is judged depends on the operation, and not arbitrarily: a copy is judged by where
    /// it lands (the sources are only read), a delete by what it takes, and a move by both, because it
    /// both reads and removes.
    static func allows(kind: OperationKind, scope: WorkspaceScope, workspaceName: String) -> Bool {
        switch kind {
        case .copy(_, let dest, _):
            // Only the destination: a copy reads its sources and leaves them where they are, so a
            // scope has no business objecting to where they came from.
            return allows(scope: scope, workspaceName: workspaceName, destination: dest)
        case .move(let items, let dest, _):
            return allows(scope: scope, workspaceName: workspaceName,
                          sources: items, destination: dest)
        case .trash(let items), .delete(let items):
            return allows(scope: scope, workspaceName: workspaceName, sources: items)
        case .custom:
            // Pack, unpack and the rest: the kind carries a closure and no paths, so there is nothing
            // here to judge. They are checked where they are built instead, which is the honest place
            // — this one would have to guess.
            return true
        }
    }

    /// The last line, asked where a job actually starts rather than where it was ordered.
    ///
    /// Silent: it asks nothing and shows nothing, because by the time a transfer reaches the queue
    /// there is no sensible dialog left — the caller that built it is what needs fixing. `refuse`
    /// stops it, `ask` lets it through on the grounds that nobody was asked and refusing silently
    /// would be worse than the thing it is guarding against.
    static func backstopAllows(kind: OperationKind) -> Bool {
        guard let workspace = MainWindowController.shared?.activeWorkspace,
              workspace.scope.isSet, workspace.scope.enforcement == .refuse else { return true }
        let sources: [String]
        let destination: String?
        switch kind {
        case .copy(_, let dest, _): sources = []; destination = dest
        case .move(let items, let dest, _): sources = items; destination = dest
        case .trash(let items), .delete(let items): sources = items; destination = nil
        case .custom: return true
        }
        return ScopeCheck.decide(scope: workspace.scope, sources: sources,
                                 destination: destination, resolve: Self.resolve) == .inside
    }

    /// Symlinks resolved on both sides before comparing, or a scope is one alias away from meaning
    /// nothing. Kept here rather than in `ScopeCheck` so that type stays free of the file system.
    private static func resolve(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    private static func message(side: ScopeSide, count: Int,
                                enforcement: ScopeEnforcement) -> String {
        if enforcement == .refuse {
            return String(localized: "This workspace only works inside its own folder.")
        }
        switch side {
        case .destination: return String(localized: "Send these out of this workspace?")
        case .source:      return String(localized: "Act on files from outside this workspace?")
        }
    }

    /// Names the folder, then the offenders — in that order, because the folder is the thing that can
    /// be changed and the file names are what identify the mistake.
    private static func detail(scope: WorkspaceScope, workspaceName: String,
                               offenders: [String], side: ScopeSide) -> String {
        let root = (scope.root as NSString).abbreviatingWithTildeInPath
        let head = String(format: String(localized: "“%1$@” covers %2$@."), workspaceName, root)
        let shown = offenders.prefix(4)
            .map { ($0 as NSString).abbreviatingWithTildeInPath }
            .joined(separator: "\n")
        let more = offenders.count > 4 ? "\n…" : ""
        let lead = side == .destination
            ? String(localized: "The destination is outside it:")
            : String(localized: "These are not in it:")
        return head + "\n\n" + lead + "\n" + shown + more
    }
}
