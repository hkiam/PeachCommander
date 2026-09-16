// SPDX-License-Identifier: Apache-2.0
// WorkspaceTests.swift - The workspace model, its file format, and the one-way migration (F-499).

import XCTest
@testable import PCFoundation

final class WorkspaceTests: XCTestCase {

    // MARK: - Helpers

    private func pane(_ paths: [String],
                      active: Int = 0,
                      viewMode: String = "details",
                      tree: Bool = false,
                      history: [String] = [],
                      historyIndex: Int = 0) -> PaneState {
        PaneState(tabs: paths.map { PanelTabState(path: $0) }, activeIndex: active,
                  viewMode: viewMode, treeVisible: tree,
                  history: history, historyIndex: historyIndex)
    }

    private func state(left: PaneState? = nil, right: PaneState? = nil,
                       side: PaneSide = .left,
                       chrome: WindowChromeState = .standard) -> WorkspaceState {
        WorkspaceState(chrome: chrome, left: left ?? pane(["/a"]),
                       right: right ?? pane(["/b"]), activeSide: side)
    }

    private func workspace(id: String = "w", name: String = "W",
                           state s: WorkspaceState? = nil) -> Workspace {
        let value = s ?? state()
        return Workspace(id: id, name: name, tint: 0, order: 0,
                         created: Date(timeIntervalSince1970: 1_700_000_000),
                         lastUsed: nil, baseline: value, live: value)
    }

    // MARK: - PanelTabState as a file format

    func test_tab_roundTrips_throughJSON() throws {
        let tab = PanelTabState(path: "/Users/me/Docs", sortColumn: "date", sortAscending: false,
                                locked: true, cursorName: "report.pdf",
                                driveVolume: "pfxmount:/P/TaskManager.pfxplugin",
                                marked: ["a.txt", "b.txt"], filterText: "*.pdf")
        let data = try JSONEncoder().encode(tab)
        XCTAssertEqual(try JSONDecoder().decode(PanelTabState.self, from: data), tab)
    }

    func test_anOrdinaryTab_writesOnlyItsPath() throws {
        // The point of the hand-written encoder: a workspace file has to stay readable, and a plain
        // tab carrying six default values is five-sixths noise.
        let json = String(data: try JSONEncoder().encode(PanelTabState(path: "/tmp")), encoding: .utf8)
        XCTAssertEqual(json, #"{"path":"\/tmp"}"#)
    }

    func test_anEmptyMarkedList_isNotWritten() throws {
        // "marked": [] and no key at all say the same thing; only one of them is worth the bytes.
        let json = String(data: try JSONEncoder().encode(
            PanelTabState(path: "/tmp", marked: [], filterText: "")), encoding: .utf8)
        XCTAssertEqual(json, #"{"path":"\/tmp"}"#)
    }

    func test_aTabWrittenBeforeTheNewFieldsExisted_stillLoads() throws {
        // The rule `WorkspaceCodec` had, carried across to JSON: trailing fields are optional, and a
        // stored workspace is the user's rather than the format's.
        let old = #"{"path":"/Users/me","sort":"ext","locked":true}"#
        let tab = try JSONDecoder().decode(PanelTabState.self, from: Data(old.utf8))
        XCTAssertEqual(tab, PanelTabState(path: "/Users/me", sortColumn: "ext", locked: true))
        XCTAssertNil(tab.marked)
        XCTAssertNil(tab.filterText)
    }

    // MARK: - Workspace as a file format

    func test_workspace_roundTripsThroughTheStoresCoders() throws {
        let w = workspace(id: "backups", name: "Clean up backups",
                          state: state(left: pane(["/a", "/b"], active: 1, viewMode: "brief", tree: true,
                                                  history: ["/x", "/a"], historyIndex: 1),
                                       side: .right))
        let data = try WorkspaceStore.encoder.encode(w)
        XCTAssertEqual(try WorkspaceStore.decoder.decode(Workspace.self, from: data), w)
    }

    func test_paneDefaults_areOmittedAndRestored() throws {
        let p = pane(["/tmp"])
        let json = String(data: try JSONEncoder().encode(p), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("viewMode"), "the default view mode should not be written: \(json)")
        XCTAssertFalse(json.contains("tree"))
        XCTAssertFalse(json.contains("history"))
        XCTAssertEqual(try JSONDecoder().decode(PaneState.self, from: Data(json.utf8)), p)
    }

    func test_commandName_followsTheMacroPrecedent() {
        XCTAssertEqual(workspace(id: "backups").commandName, "ws_backups")
    }

    // MARK: - Journal

    private func entry(_ kind: JournalEntry.Kind, _ label: String, dir: String = "/d",
                       at seconds: Double = 0,
                       outcome: JournalEntry.Outcome = .done) -> JournalEntry {
        JournalEntry(kind: kind, at: Date(timeIntervalSince1970: 1_700_000_000 + seconds),
                     label: label, directory: dir, outcome: outcome)
    }

    func test_journal_appendsRepeatsRatherThanCountingThem() {
        // The reason this is not a filter over the global history: that one would collapse these into
        // a single row saying "used 2 times", and the sequence is the whole value here.
        var journal = WorkspaceJournal()
        journal.append(entry(.operation, "Copy 3 items", at: 1))
        journal.append(entry(.operation, "Copy 3 items", at: 2))
        XCTAssertEqual(journal.count, 2)
    }

    func test_journal_collapsesOnlyConsecutiveNavigationToTheSameFolder() {
        var journal = WorkspaceJournal()
        journal.append(entry(.navigation, "cd /a", dir: "/a", at: 1))
        journal.append(entry(.navigation, "cd /a", dir: "/a", at: 2))
        XCTAssertEqual(journal.count, 1, "walking in and out says nothing a single line does not")

        journal.append(entry(.navigation, "cd /b", dir: "/b", at: 3))
        journal.append(entry(.navigation, "cd /a", dir: "/a", at: 4))
        XCTAssertEqual(journal.count, 3, "going away and coming back is two visits")

        // And an operation between them keeps both, because the second navigation is now information.
        var other = WorkspaceJournal()
        other.append(entry(.navigation, "cd /a", dir: "/a", at: 1))
        other.append(entry(.operation, "Delete 1 item", dir: "/a", at: 2))
        other.append(entry(.navigation, "cd /a", dir: "/a", at: 3))
        XCTAssertEqual(other.count, 3)
    }

    func test_journal_keepsEverythingByDefault() {
        // Deliberately unlike the history's ninety days: a record of what was done to somebody's files
        // should not forget by itself.
        var journal = WorkspaceJournal()
        journal.append(entry(.operation, "old", at: -400 * 86_400))
        journal.prune(olderThanDays: 0)
        XCTAssertEqual(journal.count, 1)

        journal.prune(olderThanDays: 30, now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(journal.count, 0, "an explicit retention still works")
    }

    func test_journal_dropsTheOldestPastCapacity() {
        var journal = WorkspaceJournal(capacity: 3)
        for i in 1...5 { journal.append(entry(.operation, "op \(i)", at: Double(i))) }
        XCTAssertEqual(journal.entries.map(\.label), ["op 3", "op 4", "op 5"])
    }

    func test_journal_problemsFilterIsWhatMakesItWorthOpening() {
        var journal = WorkspaceJournal()
        journal.append(entry(.operation, "Copy 3 items", at: 1))
        journal.append(entry(.scope, "Delete 4 items", at: 2,
                             outcome: .refused("outside this workspace")))
        journal.append(entry(.operation, "Move 1 item", at: 3, outcome: .failed("permission denied")))

        let problems = journal.filtered(problemsOnly: true)
        XCTAssertEqual(problems.map(\.label), ["Move 1 item", "Delete 4 items"], "newest first")
        XCTAssertEqual(problems.last?.reason, "outside this workspace")
        XCTAssertFalse(journal.entries[0].isProblem)
    }

    func test_journal_filtersByKindAndText() {
        var journal = WorkspaceJournal()
        journal.append(entry(.operation, "Copy report.pdf", dir: "/invoices", at: 1))
        journal.append(entry(.command, "git status", dir: "/repo", at: 2))
        XCTAssertEqual(journal.filtered(kind: .command).map(\.label), ["git status"])
        // The folder is searched as well as the label: "what did I do in invoices" is the question.
        XCTAssertEqual(journal.filtered(query: "invoices").map(\.label), ["Copy report.pdf"])
    }

    func test_journal_groupsByDayNewestFirst() {
        var journal = WorkspaceJournal()
        journal.append(entry(.operation, "yesterday", at: 0))
        journal.append(entry(.operation, "today", at: 86_400))
        let groups = journal.grouped(calendar: Calendar(identifier: .gregorian))
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.entries.map(\.label), ["today"])
    }

    func test_journal_roundTripsIncludingTheRefusalReason() throws {
        var journal = WorkspaceJournal()
        journal.append(entry(.scope, "Delete 2 items", at: 1, outcome: .refused("outside")))
        journal.append(entry(.operation, "Copy 1 item", at: 2))
        let data = try JSONEncoder().encode(journal)
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceJournal.self, from: data), journal)
    }

    // MARK: - Scope

    func test_containment_isByComponentNotByPrefix() {
        // The defect this type exists to avoid: `hasPrefix` says Backups2 is inside Backups, and a
        // warning that never fires for the folder next door is worse than no warning at all, because
        // people rely on it.
        XCTAssertTrue(ScopeCheck.contains(root: "/Users/m/Backups", path: "/Users/m/Backups/old.dmg"))
        XCTAssertFalse(ScopeCheck.contains(root: "/Users/m/Backups", path: "/Users/m/Backups2/old.dmg"))
        XCTAssertFalse(ScopeCheck.contains(root: "/Users/m/Backups", path: "/Users/m/Back"))
    }

    func test_containment_theRootItselfIsInside() {
        // Creating a folder *in* the root is the commonest thing somebody does inside a scope.
        XCTAssertTrue(ScopeCheck.contains(root: "/a/b", path: "/a/b"))
        XCTAssertTrue(ScopeCheck.contains(root: "/a/b/", path: "/a/b"))
        XCTAssertTrue(ScopeCheck.contains(root: "/a/b", path: "/a/b/"))
    }

    func test_containment_normalisesBeforeComparing() {
        // A root typed by hand, or arriving from a `.pcworkspace`, carries any of these.
        XCTAssertTrue(ScopeCheck.contains(root: "/a//b/./", path: "/a/b/c"))
        XCTAssertTrue(ScopeCheck.contains(root: "/a/b", path: "/a/b/./c"))
    }

    func test_containment_anEmptyRootMeansEverythingIsInside() {
        XCTAssertTrue(ScopeCheck.contains(root: "", path: "/anywhere"))
    }

    func test_containment_followsTheCallersSymlinkResolution() {
        // Kept out of this type so it stays pure; the app passes the real resolver.
        let resolve: (String) -> String = { $0 == "/link" ? "/a/b" : $0 }
        XCTAssertTrue(ScopeCheck.contains(root: "/a/b", path: "/link", resolve: resolve))
    }

    func test_decide_judgesTheDestinationFirst() {
        let scope = WorkspaceScope(root: "/keep", enforcement: .ask)
        // Both outside: the destination is reported, because that is the one the user can fix by
        // picking a different folder.
        let verdict = ScopeCheck.decide(scope: scope, sources: ["/stray/a"], destination: "/elsewhere")
        XCTAssertEqual(verdict, .outside(offenders: ["/elsewhere"], side: .destination))
    }

    func test_decide_reportsEveryStraySource() {
        let scope = WorkspaceScope(root: "/keep", enforcement: .refuse)
        let verdict = ScopeCheck.decide(scope: scope,
                                        sources: ["/keep/a", "/stray/b", "/stray/c"],
                                        destination: "/keep/sub")
        XCTAssertEqual(verdict, .outside(offenders: ["/stray/b", "/stray/c"], side: .source))
    }

    func test_decide_saysNothingWithoutARootOrWhenAllowed() {
        XCTAssertEqual(ScopeCheck.decide(scope: WorkspaceScope(), sources: ["/anywhere"]), .inside)
        XCTAssertEqual(
            ScopeCheck.decide(scope: WorkspaceScope(root: "/keep", enforcement: .allow),
                              sources: ["/stray"]),
            .inside)
    }

    func test_aWorkspaceWithoutAScope_writesNothingAboutOne() throws {
        let json = String(data: try JSONEncoder().encode(WorkspaceScope()), encoding: .utf8)
        XCTAssertEqual(json, "{}")
        let set = WorkspaceScope(root: "/keep", enforcement: .refuse)
        XCTAssertEqual(try JSONDecoder().decode(
            WorkspaceScope.self, from: try JSONEncoder().encode(set)), set)
    }

    // MARK: - The stash

    func test_stash_addsInOrderAndSkipsWhatIsAlreadyThere() {
        var stash = WorkspaceStash()
        XCTAssertEqual(stash.add(["/a/one.txt", "/b/two.txt"]).added, 2)
        // Insertion order, not sorted: the order things were found in is information.
        XCTAssertEqual(stash.items.map(\.name), ["one.txt", "two.txt"])

        let again = stash.add(["/b/two.txt", "/c/three.txt"])
        XCTAssertEqual(again.added, 1)
        // Reported separately, because "3 added" leaves somebody wondering where the fourth went.
        XCTAssertEqual(again.duplicates, 1)
        XCTAssertEqual(stash.count, 3)
    }

    func test_stash_identityIsTheWholePathNotTheName() {
        // Two files called report.pdf from different folders is the normal case for a basket filled
        // across an afternoon, not an edge case.
        var stash = WorkspaceStash()
        stash.add(["/jan/report.pdf", "/feb/report.pdf"])
        XCTAssertEqual(stash.count, 2)
    }

    func test_stash_removeAndNotes() {
        var stash = WorkspaceStash()
        stash.add(["/a", "/b", "/c"])
        stash.setNote("the big one", for: "/b")
        XCTAssertEqual(stash.items[1].note, "the big one")
        stash.remove(paths: ["/a", "/c"])
        XCTAssertEqual(stash.items.map(\.path), ["/b"])
        XCTAssertEqual(stash.items[0].note, "the big one", "removing others must not disturb a note")
    }

    func test_stash_partitionsWithoutPruning() {
        // A file missing because a volume is unmounted has to come back when it is mounted, so the
        // stale ones are reported rather than dropped.
        var stash = WorkspaceStash()
        stash.add(["/here/a.txt", "/gone/b.txt", "/here/c.txt"])
        let split = stash.partition { $0.hasPrefix("/here/") }
        XCTAssertEqual(split.live.map(\.name), ["a.txt", "c.txt"])
        XCTAssertEqual(split.stale.map(\.name), ["b.txt"])
        XCTAssertEqual(stash.count, 3, "partition must not remove anything")
    }

    func test_anEmptyStash_isNotWrittenAndAnOldWorkspaceHasOne() throws {
        let json = String(data: try WorkspaceStore.encoder.encode(workspace()), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("stash"), "an empty basket should not be written: \(json)")

        // And a workspace stored before stashes existed decodes as one with an empty basket.
        var w = workspace()
        w.stash.add(["/x/y.txt"])
        let round = try WorkspaceStore.decoder.decode(
            Workspace.self, from: try WorkspaceStore.encoder.encode(w))
        XCTAssertEqual(round.stash.items.map(\.path), ["/x/y.txt"])
    }

    func test_theStashSurvivesAResetToBaseline() {
        // The basket is outside `live` and `baseline` on purpose: putting the panels back must not
        // throw away the eleven files somebody spent the afternoon collecting.
        var w = workspace()
        w.stash.add(["/found/one", "/found/two"])
        w.live = state(left: pane(["/somewhere/else"]))
        // What "reset" does:
        w.live = w.baseline
        XCTAssertEqual(w.stash.count, 2)
    }

    // MARK: - Marks and the quick filter

    func test_marksAndFilter_rideAlongInTheActiveTab() throws {
        var tab = PanelTabState(path: "/Volumes/Backup")
        tab.marked = ["old.dmg", "older.dmg"]
        tab.filterText = "*.dmg"
        let decoded = try JSONDecoder().decode(
            PanelTabState.self, from: try JSONEncoder().encode(tab))
        XCTAssertEqual(decoded.marked, ["old.dmg", "older.dmg"])
        XCTAssertEqual(decoded.filterText, "*.dmg")
    }

    func test_diff_noticesAChangedSelection() {
        // The field most likely to be captured and then never applied, because nothing else in the
        // app would say a word about it: the marks would simply be the previous workspace's.
        let a = state()
        var b = a
        b.left.tabs[0].marked = ["something.txt"]
        XCTAssertEqual(WorkspaceState.diff(a, b), ["left.tabs.0.marked"])
    }

    // MARK: - Window chrome

    func test_theStandardArrangement_writesNothing() throws {
        // Sixteen lines of "yes, the usual" is not information, and these files are read by people.
        let json = String(data: try JSONEncoder().encode(WindowChromeState.standard), encoding: .utf8)
        XCTAssertEqual(json, "{}")
    }

    func test_chrome_roundTripsWhatDiffers() throws {
        var chrome = WindowChromeState.standard
        chrome.previewVisible = true
        chrome.previewWidth = 420
        chrome.dockVisible = true
        chrome.dockPanel = "plugin.terminal.view"
        chrome.buttonBarVertical = true
        chrome.pathBarVisible = false
        chrome.splitterLeftWidth = 733

        let data = try JSONEncoder().encode(chrome)
        XCTAssertEqual(try JSONDecoder().decode(WindowChromeState.self, from: data), chrome)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("statusBarVisible"), "unchanged fields should stay out: \(json)")
    }

    func test_aWorkspaceStoredBeforeChromeExisted_loadsAsTheUsualArrangement() throws {
        // The failure this prevents is not a crash: it is a workspace opening with every bar switched
        // off, which reads as the upgrade having broken the window.
        let old = #"{"left":{"tabs":[{"path":"/a"}]},"right":{"tabs":[{"path":"/b"}]},"activeSide":"left"}"#
        let state = try JSONDecoder().decode(WorkspaceState.self, from: Data(old.utf8))
        XCTAssertEqual(state.chrome, .standard)
        XCTAssertEqual(state.left.tabs.map(\.path), ["/a"])
    }

    func test_fieldKeys_coverTheChromeToo() {
        let keys = Set(WorkspaceState.fieldKeys(of: state()))
        for expected in ["chrome.previewVisible", "chrome.dockPanel", "chrome.splitterLeftWidth",
                         "chrome.buttonBarVertical", "chrome.horizontalPanels"] {
            XCTAssertTrue(keys.contains(expected), "missing \(expected)")
        }
    }

    func test_diff_reachesIntoTheChrome() {
        let a = state()
        var b = a
        b.chrome.dockVisible = true
        XCTAssertEqual(WorkspaceState.diff(a, b), ["chrome.dockVisible"])
    }

    // MARK: - Identifiers

    func test_slug_keepsOnlyWhatACommandIdMayHold() {
        XCTAssertEqual(WorkspaceID.slug(from: "Clean up backups"), "clean-up-backups")
        XCTAssertEqual(WorkspaceID.slug(from: "Bewerbungen 2026"), "bewerbungen-2026")
        // A name that is entirely punctuation, or entirely non-ASCII, must still produce a findable
        // file name rather than ".json".
        XCTAssertEqual(WorkspaceID.slug(from: "!!!"), "workspace")
        XCTAssertEqual(WorkspaceID.slug(from: ""), "workspace")
        // No slashes, ever: the id is a file name.
        XCTAssertFalse(WorkspaceID.slug(from: "a/b/c").contains("/"))
    }

    func test_unique_stepsAsideForAnIdAlreadyTaken() {
        XCTAssertEqual(WorkspaceID.unique(from: "Backups", taken: []), "backups")
        XCTAssertEqual(WorkspaceID.unique(from: "Backups", taken: ["backups"]), "backups-2")
        XCTAssertEqual(WorkspaceID.unique(from: "Backups", taken: ["backups", "backups-2"]), "backups-3")
    }

    // MARK: - Ghost-state detection

    func test_diff_isEmptyForEqualStates() {
        XCTAssertEqual(WorkspaceState.diff(state(), state()), [])
    }

    func test_diff_namesTheFieldThatChanged() {
        let a = state()
        var b = a
        b.left.viewMode = "brief"
        XCTAssertEqual(WorkspaceState.diff(a, b), ["left.viewMode"])
    }

    func test_diff_reachesIntoTabsAndOptionals() {
        var a = state()
        var b = a
        b.left.tabs[0].marked = ["x"]
        XCTAssertEqual(WorkspaceState.diff(a, b), ["left.tabs.0.marked"])

        a = state(); b = a
        b.right.tabs[0].filterText = "*.pdf"
        XCTAssertEqual(WorkspaceState.diff(a, b), ["right.tabs.0.filterText"])
    }

    func test_diff_ignoresTheCursor() {
        // A cursor whose file was deleted while the workspace was away is the honest case: the panel
        // lands somewhere else and is right to. Everything else must still be reported.
        var a = state()
        var b = a
        b.left.tabs[0].cursorName = "gone.txt"
        XCTAssertEqual(WorkspaceState.diff(a, b), [])

        a = state(); b = a
        b.left.tabs[0].cursorName = "gone.txt"
        b.left.treeVisible = true
        XCTAssertEqual(WorkspaceState.diff(a, b), ["left.treeVisible"])
    }

    func test_diff_noticesADifferentNumberOfTabs() {
        let a = state()
        var b = a
        b.left.tabs.append(PanelTabState(path: "/extra"))
        XCTAssertEqual(WorkspaceState.diff(a, b), ["left.tabs"])
    }

    func test_fieldKeys_coverEveryStoredField() {
        let keys = Set(WorkspaceState.fieldKeys(of: state()))
        // The test that fails when somebody adds a field and wires it nowhere. It runs in a second on
        // a laptop, long before the VM run would have a chance to notice.
        for expected in ["activeSide",
                         "left.activeIndex", "left.viewMode", "left.treeVisible",
                         "left.history", "left.historyIndex",
                         "right.activeIndex", "right.viewMode", "right.treeVisible",
                         "right.history", "right.historyIndex"] {
            XCTAssertTrue(keys.contains(expected), "missing \(expected) in \(keys.sorted())")
        }
        XCTAssertTrue(keys.contains { $0.hasPrefix("left.tabs") }, "tabs not covered: \(keys.sorted())")
    }

    // MARK: - Migration

    /// The old section, written the way `WorkspaceStore` used to write it.
    private func legacyINI(_ entries: [(name: String, left: [String], right: [String])]) -> String {
        let us = "\u{1}", rs = "\u{2}"
        func encode(_ paths: [String]) -> String {
            paths.map { [$0, "name", "1", "0", "", ""].joined(separator: us) }.joined(separator: rs)
        }
        var lines = ["[Workspaces]", "Count=\(entries.count)"]
        for (i, e) in entries.enumerated() {
            lines += ["Name\(i)=\(e.name)",
                      "Left\(i)=\(encode(e.left))", "LeftActive\(i)=0",
                      "Right\(i)=\(encode(e.right))", "RightActive\(i)=0",
                      "Active\(i)=left"]
        }
        return lines.joined(separator: "\n")
    }

    func test_migration_putsTheCurrentSessionFirst() {
        let session = workspace(id: "session", name: "Workspace 1")
        let out = WorkspaceMigration.workspaces(legacyINI: "", session: session)
        // The case that matters most, because it is nearly everybody: no saved layouts at all, and
        // the app still comes up exactly as it was left.
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].id, "session")
        XCTAssertEqual(out[0].order, 0)
        XCTAssertEqual(out[0].live, session.live)
    }

    func test_migration_turnsEverySavedLayoutIntoAWorkspace() {
        let ini = legacyINI([("Photo import", ["/Photos"], ["/Archive"]),
                             ("Backups", ["/Volumes/B"], ["/tmp"])])
        let out = WorkspaceMigration.workspaces(legacyINI: ini, session: workspace(id: "session"))

        XCTAssertEqual(out.map(\.name), ["W", "Photo import", "Backups"])
        XCTAssertEqual(out.map(\.order), [0, 1, 2])
        XCTAssertEqual(out.map(\.id), ["session", "photo-import", "backups"])
        XCTAssertEqual(out[1].live.left.tabs.map(\.path), ["/Photos"])
        XCTAssertEqual(out[2].live.right.tabs.map(\.path), ["/tmp"])
        // A saved layout is a starting point, so loading it and resetting to the baseline agree.
        XCTAssertEqual(out[1].baseline, out[1].live)
        // Colours are dealt out rather than left uniform, or a migrated list arrives looking broken.
        XCTAssertEqual(Set(out.map(\.tint)).count, 3)
    }

    func test_migration_skipsEntriesThatCouldNotBeSwitchedTo() {
        // A nameless entry and one with no tabs on either side would each be a chip that does nothing.
        let ini = legacyINI([("Good", ["/a"], ["/b"]), ("", ["/c"], ["/d"])])
        let out = WorkspaceMigration.workspaces(legacyINI: ini, session: workspace(id: "session"))
        XCTAssertEqual(out.map(\.name), ["W", "Good"])
    }

    func test_migration_survivesRubbish() {
        for junk in ["", "not an ini at all", "[Workspaces]\nCount=oops", "[Workspaces]\nCount=3"] {
            let out = WorkspaceMigration.workspaces(legacyINI: junk, session: workspace(id: "session"))
            XCTAssertEqual(out.first?.id, "session", "session lost for input: \(junk)")
        }
    }

    func test_migration_deduplicatesIdsAgainstTheSession() {
        let ini = legacyINI([("Session", ["/a"], ["/b"])])
        let out = WorkspaceMigration.workspaces(legacyINI: ini, session: workspace(id: "session"))
        XCTAssertEqual(out.map(\.id), ["session", "session-2"])
    }

    // MARK: - The store on disk

    private func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-workspaces-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func test_store_writesOneFilePerWorkspaceAndReadsThemBackInOrder() throws {
        let dir = try tempDirectory()
        let store = WorkspaceStore(directory: dir)
        var a = workspace(id: "a", name: "A"); a.order = 1
        var b = workspace(id: "b", name: "B"); b.order = 0
        XCTAssertTrue(store.saveAll([a, b]))

        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("a.json").path))
        let loaded = store.load()
        XCTAssertEqual(loaded.problems, [])
        XCTAssertEqual(loaded.workspaces.map(\.id), ["b", "a"], "stored order should win over file name")
    }

    func test_store_aFileThatWillNotParseCostsOnlyItself() throws {
        let dir = try tempDirectory()
        let store = WorkspaceStore(directory: dir)
        XCTAssertTrue(store.save(workspace(id: "good", name: "Good")))
        try "{ this is not json".write(to: dir.appendingPathComponent("bad.json"),
                                       atomically: true, encoding: .utf8)

        let loaded = store.load()
        XCTAssertEqual(loaded.workspaces.map(\.id), ["good"])
        XCTAssertEqual(loaded.problems.count, 1)
        XCTAssertTrue(loaded.problems[0].contains("bad.json"), loaded.problems[0])
    }

    func test_store_refusesAFileFromANewerVersion() throws {
        let dir = try tempDirectory()
        let store = WorkspaceStore(directory: dir)
        var future = workspace(id: "future", name: "Future")
        future.formatVersion = Workspace.currentFormatVersion + 1
        XCTAssertTrue(store.save(future))

        let loaded = store.load()
        XCTAssertEqual(loaded.workspaces, [], "a newer file must not be half-read")
        XCTAssertEqual(loaded.problems.count, 1)
        XCTAssertTrue(loaded.problems[0].contains("newer version"), loaded.problems[0])
    }

    func test_store_deleteRemovesJustThatOne() throws {
        let dir = try tempDirectory()
        let store = WorkspaceStore(directory: dir)
        store.saveAll([workspace(id: "a"), workspace(id: "b")])
        store.delete(id: "a")
        XCTAssertEqual(store.load().workspaces.map(\.id), ["b"])
    }

    func test_store_migratesOnceAndPutsTheOldFileAside() throws {
        let dir = try tempDirectory()
        try FileManager.default.createDirectory(at: dir.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let legacy = dir.deletingLastPathComponent()
            .appendingPathComponent("workspaces-\(UUID().uuidString).ini")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: legacy)
            try? FileManager.default.removeItem(at: legacy.appendingPathExtension("migrated"))
        }
        try legacyINI([("Backups", ["/Volumes/B"], ["/tmp"])])
            .write(to: legacy, atomically: true, encoding: .utf8)

        let store = WorkspaceStore(directory: dir, legacyFile: legacy)
        let migrated = store.migrateIfNeeded(sessionWorkspace: workspace(id: "session", name: "Workspace 1"))
        XCTAssertEqual(migrated?.map(\.id), ["session", "backups"])
        XCTAssertEqual(store.load().workspaces.map(\.id), ["session", "backups"])

        // Renamed, not deleted: it is the user's data and the move has to be reversible by hand.
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.appendingPathExtension("migrated").path))

        // And only once: a second call must not overwrite what the user has done since.
        XCTAssertNil(store.migrateIfNeeded(sessionWorkspace: workspace(id: "other", name: "Other")))
        XCTAssertEqual(store.load().workspaces.map(\.id), ["session", "backups"])
    }

    // MARK: - A scope that cannot protect anything is not a scope

    func test_scope_aRootThatIsNotAPathIsNoScopeAtAll() {
        // The one that cost fourteen scenarios. `ScopeCheck.contains` matches path *components*, so a
        // relative root matches nothing — and "matches nothing" means every operation is outside and
        // every one is refused or asked about, naming a folder that was never a folder. Unset is the
        // only honest reading.
        for nonsense in ["ask", "refuse", "Backups", "~/Backups", " ", "."] {
            let scope = WorkspaceScope(root: nonsense, enforcement: .refuse)
            XCTAssertFalse(scope.isSet, "a scope rooted at \(nonsense) would refuse everything")
            XCTAssertEqual(ScopeCheck.decide(scope: scope, sources: ["/Users/me/a.txt"],
                                             destination: nil), .inside)
        }
        XCTAssertFalse(WorkspaceScope(root: "").isSet)
        XCTAssertTrue(WorkspaceScope(root: "/Users/me/Backups").isSet)
    }

    func test_scope_aRootThatIsNotAPathIsNotWrittenToDisk() throws {
        // …and it does not survive a round trip either, so one that got in before this rule does not
        // come back on the next launch.
        var ws = workspace()
        ws.scope = WorkspaceScope(root: "ask", enforcement: .refuse)
        let data = try WorkspaceStore.encoder.encode(ws)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("\"root\""))
        let back = try WorkspaceStore.decoder.decode(Workspace.self, from: data)
        XCTAssertFalse(back.scope.isSet)
    }

    // MARK: - `.pcworkspace`, the file you hand over

    /// The claim the whole export rests on, checked the only way worth checking it: export a
    /// workspace that is sitting on an FTP connection and a mounted plugin drive, then search the
    /// bytes. Nothing about either may be in there — not the host, not the sentinel, not the name.
    func test_export_writesNothingAboutAConnection() throws {
        var left = pane(["/Users/sender/Backups"])
        left.tabs.append(PanelTabState(path: "/incoming",
                                       driveVolume: "netmount:sftp://alice@files.example.com:2222"))
        var right = pane(["/tmp"])
        right.tabs.append(PanelTabState(path: "/",
                                        driveVolume: "pfxmount:/P/TaskManager.pfxplugin"))
        var ws = workspace(state: state(left: left, right: right))
        ws.stash = WorkspaceStash(items: [StashItem(path: "/Users/sender/Backups/a.txt"),
                                          StashItem(path: "netmount:sftp://alice@files.example.com/x")])

        let (data, report) = try WorkspaceExchange.encode(ws, home: "/Users/sender")
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(report.droppedTabs, 2)
        XCTAssertEqual(report.droppedStashItems, 1)
        for secret in ["files.example.com", "alice", "netmount:", "pfxmount:", "sftp", "2222"] {
            XCTAssertFalse(text.contains(secret), "exported bytes still mention \(secret):\n\(text)")
        }
    }

    func test_export_abbreviatesTheSendersHome() throws {
        let ws = workspace(state: state(left: pane(["/Users/sender/Backups"]),
                                        right: pane(["/Volumes/Disk"])))
        let (data, _) = try WorkspaceExchange.encode(ws, home: "/Users/sender")
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("~/Backups"), text)
        // Everything outside the home is left alone: "/Volumes/Disk" means the same thing over there.
        XCTAssertTrue(text.contains("/Volumes/Disk"), text)
        XCTAssertFalse(text.contains("/Users/sender"), text)
    }

    func test_export_sendsOneStateAndNoCursor() {
        var live = state(left: pane(["/Users/sender/elsewhere"]))
        live.left.tabs[0].cursorName = "secret-report.pdf"
        live.left.tabs[0].marked = ["secret-report.pdf"]
        var ws = workspace(state: state(left: pane(["/Users/sender/Backups"])))
        ws.live = live

        let (out, _) = WorkspaceExchange.forExport(ws, home: "/Users/sender")
        // The saved starting point is what travels, and it travels once: an imported workspace
        // arrives at its baseline, so live and baseline are the same thing in the file.
        XCTAssertEqual(out.live, out.baseline)
        XCTAssertEqual(out.baseline.left.tabs.map(\.path), ["~/Backups"])
        XCTAssertNil(out.baseline.left.tabs[0].cursorName)
        XCTAssertNil(out.baseline.left.tabs[0].marked)
        XCTAssertTrue(out.baseline.left.history.isEmpty)
    }

    func test_export_leavesNoPaneWithoutATab() {
        let onlyRemote = PaneState(tabs: [PanelTabState(path: "/x", driveVolume: "netmount:a")],
                                   activeIndex: 0, viewMode: "details", treeVisible: false,
                                   history: [], historyIndex: 0)
        let (out, report) = WorkspaceExchange.forExport(
            workspace(state: state(left: onlyRemote)), home: "/Users/sender")
        XCTAssertEqual(report.droppedTabs, 1)
        // A pane with no tabs is not a pane the window can open.
        XCTAssertEqual(out.baseline.left.tabs.map(\.path), ["~"])
        XCTAssertEqual(out.baseline.left.activeIndex, 0)
    }

    // MARK: - Arriving on somebody else's Mac

    /// `folders` and `files` are separate because the code under test asks two different questions:
    /// a tab and a scope root are folders, a stash entry is a file. A single predicate hid a defect —
    /// asking "is this a directory?" about `~/report.pdf` answers no, and every stash entry that was
    /// really there came back reported as missing.
    private func importing(_ ws: Workspace, taken: Set<String> = [],
                           home: String = "/Users/receiver",
                           folders: Set<String> = [],
                           files: Set<String> = []) -> (Workspace, WorkspaceExchange.ImportReport) {
        WorkspaceExchange.forImport(ws, taken: taken, home: home,
                                    directoryExists: { folders.contains($0) },
                                    itemExists: { folders.contains($0) || files.contains($0) },
                                    nearestExisting: { _ in home })
    }

    func test_import_landsTildePathsInTheReceiversHome() {
        let ws = workspace(state: state(left: pane(["~/Backups"])))
        let (out, report) = importing(ws, folders: ["/Users/receiver/Backups", "/b"])
        XCTAssertEqual(out.baseline.left.tabs.map(\.path), ["/Users/receiver/Backups"])
        XCTAssertEqual(report.relocatedTabs, 0, "the normal case resolves without a single question")
    }

    func test_import_movesAMissingFolderUpRatherThanKeepingIt() {
        let ws = workspace(state: state(left: pane(["~/NotHere"])))
        let (out, report) = importing(ws, folders: ["/b"])
        XCTAssertEqual(out.baseline.left.tabs.map(\.path), ["/Users/receiver"])
        XCTAssertEqual(report.relocatedTabs, 1)
    }

    func test_import_neverReplacesAWorkspaceAlreadyHere() {
        let ws = workspace(id: "backups", name: "Backups")
        let (out, report) = importing(ws, taken: ["backups"], folders: ["/a", "/b"])
        XCTAssertNotEqual(out.id, "backups")
        XCTAssertEqual(report.renamedTo, out.id)
        XCTAssertEqual(out.name, "Backups", "the name is what the person reads; only the file moves")
    }

    func test_import_keepsStashPathsAndCountsWhatIsMissing() {
        var ws = workspace()
        ws.stash = WorkspaceStash(items: [StashItem(path: "~/a.txt"), StashItem(path: "~/gone.txt")])
        let (out, report) = importing(ws, folders: ["/a", "/b"], files: ["/Users/receiver/a.txt"])
        // Kept, not pruned: a file that is missing because a volume is not mounted must come back.
        XCTAssertEqual(out.stash.items.map(\.path),
                       ["/Users/receiver/a.txt", "/Users/receiver/gone.txt"])
        XCTAssertEqual(report.missingStashItems, 1)
    }

    func test_import_relaxesARefusalRootedSomewhereThatIsNotHere() {
        var ws = workspace()
        ws.scope = WorkspaceScope(root: "~/Backups", enforcement: .refuse)
        let (out, report) = importing(ws, folders: ["/a", "/b"])
        // Kept, so the receiver can see what the sender meant — but asking, because a refusal rooted
        // at a folder that is not here refuses every single operation for a reason nobody can act on.
        XCTAssertEqual(out.scope.root, "/Users/receiver/Backups")
        XCTAssertEqual(out.scope.enforcement, .ask)
        XCTAssertTrue(report.scopeRelaxed)
    }

    func test_import_leavesAScopeAloneWhenItsFolderIsThere() {
        var ws = workspace()
        ws.scope = WorkspaceScope(root: "~/Backups", enforcement: .refuse)
        let (out, report) = importing(ws, folders: ["/Users/receiver/Backups", "/a", "/b"])
        XCTAssertEqual(out.scope.enforcement, .refuse)
        XCTAssertFalse(report.scopeRelaxed)
    }

    func test_file_saysTheArrangementOnceWhenThereIsOnlyOne() throws {
        let ws = workspace(state: state(left: pane(["/a"])))
        let data = try WorkspaceStore.encoder.encode(ws)
        let text = String(decoding: data, as: UTF8.self)
        // No `live` key at all, and it reads back as the baseline. An exported file is always in this
        // shape, so there is no second copy of the arrangement that could quietly disagree.
        XCTAssertFalse(text.contains("\"live\""), text)
        let back = try WorkspaceStore.decoder.decode(Workspace.self, from: data)
        XCTAssertEqual(back.live, ws.baseline)
        XCTAssertEqual(back, ws)
    }

    func test_file_keepsLiveWhenItHasMovedOnFromTheBaseline() throws {
        var ws = workspace(state: state(left: pane(["/a"])))
        ws.live = state(left: pane(["/somewhere/else"]))
        let data = try WorkspaceStore.encoder.encode(ws)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"live\""))
        XCTAssertEqual(try WorkspaceStore.decoder.decode(Workspace.self, from: data), ws)
    }

    /// **Through the bytes**, which is the version that matters and the one that was missing: the
    /// direct `forExport`/`forImport` tests both passed while two encoder gates were quietly dropping
    /// the scope key, because a tilde-abbreviated root is not an *enforceable* one.
    func test_scope_survivesTheWholeRoundTripThroughAFile() throws {
        var ws = workspace()
        ws.scope = WorkspaceScope(root: "/Users/sender/Backups", enforcement: .refuse)
        let (data, _) = try WorkspaceExchange.encode(ws, home: "/Users/sender")
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("~/Backups"),
                      String(decoding: data, as: UTF8.self))

        let arriving = try XCTUnwrap(WorkspaceExchange.decode(data))
        XCTAssertEqual(arriving.scope.root, "~/Backups", "the file keeps the portable form")
        XCTAssertFalse(arriving.scope.isSet, "and it is not enforceable until it has been expanded")

        let (landed, report) = WorkspaceExchange.forImport(
            arriving, taken: [], home: "/Users/receiver",
            directoryExists: { ["/Users/receiver/Backups", "/a", "/b"].contains($0) },
            itemExists: { _ in true }, nearestExisting: { _ in "/Users/receiver" })
        XCTAssertEqual(landed.scope.root, "/Users/receiver/Backups")
        XCTAssertEqual(landed.scope.enforcement, .refuse)
        XCTAssertTrue(landed.scope.isSet)
        XCTAssertFalse(report.scopeRelaxed)
    }

    func test_exchange_roundTripsThroughBytes() throws {
        let ws = workspace(state: state(left: pane(["/Users/sender/Backups"])))
        let (data, _) = try WorkspaceExchange.encode(ws, home: "/Users/sender")
        let back = try XCTUnwrap(WorkspaceExchange.decode(data))
        XCTAssertEqual(back.name, ws.name)
        XCTAssertEqual(back.baseline.left.tabs.map(\.path), ["~/Backups"])
    }

    func test_exchange_decodeRefusesWhatIsNotAWorkspace() {
        // Half of what lands in an open panel is the wrong file, so this returns nil rather than
        // throwing anywhere near the main thread.
        XCTAssertNil(WorkspaceExchange.decode(Data()))
        XCTAssertNil(WorkspaceExchange.decode(Data("{\"hello\": 1}".utf8)))
        XCTAssertNil(WorkspaceExchange.decode(Data("not json at all".utf8)))
    }

    func test_exchange_decodeRefusesAFileFromANewerVersion() throws {
        var ws = workspace()
        ws.formatVersion = Workspace.currentFormatVersion + 1
        let data = try WorkspaceStore.encoder.encode(ws)
        XCTAssertNil(WorkspaceExchange.decode(data))
    }
}
