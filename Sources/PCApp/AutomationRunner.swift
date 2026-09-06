// SPDX-License-Identifier: Apache-2.0
// AutomationRunner.swift - DEBUG-only scripted automation of the running app.
//
// Enabled with the launch flag `-AutomationScript <path>` (DEBUG builds only).
// After the window loads, the script runs one verb per line so tests/tools can
// drive the REAL app deterministically — including the network connect path —
// without fragile GUI clicking. Not compiled into release builds.
//
//   left  <path>          load a directory in the left panel
//   right <path>          load a directory in the right panel
//   active left|right     set the active panel
//   cmd   <cm_Name>       run a registered command by name
//   connect <url>         quick-connect (ftp://user:pass@host/… , sftp://… )
//   disconnect            leave the active panel's network mount
//   drivedisconnect <name>  hang up an open connection from its drive chip, as its ⏏ does
//   typeahead <seq>|<out>   type into the active panel's quick search (\\b = Backspace, \\e = Esc)
//   wait  <ms>            sleep (let an async connect/list settle)
//   inlinerename <newname>        commit an in-cell rename (the details-view path)
//   inlinerenamesleft <out>       whether that name went unused (i.e. no in-cell rename ran)
//   replaceanswer <choice>        answer the rename conflict: overwrite|autorename|skip|cancel
//   replaceanswersleft <out>      whether that answer went unused (i.e. nothing asked)
//   dump  <file>          write the active panel's path + entry names to a file
//   bardrop <path>        add a bar button for <path>, as a drop on free space would
//   drivebardump <file>   write the active panel's path + the drive chip shown as current
//   procfile <path>       highlight the processes holding <path> open (TaskManager mount)
//   prochldump <file>     write the highlighted process rows and their handle kind
//   gotoopenfile          "Go to File" on the cursor row (inside a process)
//   rowdump <file>        every visible column of the cursor row, as id + rendered text
//   sortcol <fieldID>     sort the panel by a plugin content column
//   filter <text>         apply the quick filter to the active panel
//   listershot <out.png>  a PNG of what the viewer window is showing (the rendered page included)
//   listermenudump <out>  the viewer's own document menus (menudump only sees the main bar)
//   listermarkstep <term>|<steps>|<out>  Mark All, then step through the marks; reports where
//   listergoto <expr>|<out>  the viewer's Ctrl+G, answered from the queue; reports the selection
//   listerhexclick <hex|ascii>|<row>|<byte>|<out>  click a column of the hex view, report the byte
//   listerstrings <row|-1>|<out>  open the viewer's strings panel (hex only), wait for the scan,
//                                 write what it holds; a row index also clicks that row and
//                                 reports the byte range the hex view then highlights
//   mainshot <out.png>    a PNG of the key window (the main one, a dialog, or Settings)
//   viewdump <file>       cursor, first visible row and scroll offset of the active panel
//   scrollto <row>        scroll the active panel to a row WITHOUT moving the cursor
//   aitool <tool>|<json>|<out>  run one assistant tool through the Automation Core, write its payload
//   renamemask <mask>|<out>    resolve a multi-rename mask over the active panel, write old -> new
//                               (":confirm" agrees to a gated plan; ":confirm:<id>,<id>" strikes rows out;
//                                ":session" uses the configured policy instead of `.standard`, which is
//                                the only way to exercise a capability switched on in Settings)
//   pathbardump <side>|<out>   the path bar's state: editing, its text, the breadcrumb, where it ends
//   pathbarclick <side>|<region>|<clicks>|<out>   click a path bar region (first/last/gap/trailing/pencil)
//   theme <id>            select a colour palette ("system", "norton", …)
//   quit                  terminate the app
//   # …                   comment / blank lines are ignored

#if DEBUG
import AppKit
import Quartz
import PCFoundation
import PCNet
import PCOperations
import PCAutomation
import PCVFS
import PCArchive   // PackFormat, for the `packanswer` verb

/// Retains editor windows opened by the `editdump` automation verb.
private var automationEditors: [EditorWindowController] = []
/// Retains lister windows opened by the `view` automation verb.
private var automationListers: [ListerWindowController] = []
/// Retains hex editors opened by the `hexgoto` / `hexclip` verbs (F-400, F-401).
private var automationHexEditors: [HexEditorWindowController] = []

/// The viewer window a viewer command should act on: the frontmost one, else the one automation opened,
/// else whichever is up.
///
/// One lookup, so `listerdump` and `listermarks` can never disagree about which window they mean.
///
/// The key window comes first because a scenario may open a *second* viewer — a second hit from the Find
/// dialog (F-407) — and `NSApp.windows` is in no particular order, so "the first lister" silently
/// answered about the previous window and made the second half of the run report the first half's state.
@MainActor
private func currentLister() -> ListerWindowController? {
    if let key = NSApp.keyWindow?.windowController as? ListerWindowController { return key }
    if let opened = automationListers.last { return opened }
    return NSApp.windows.first { $0.windowController is ListerWindowController }?
        .windowController as? ListerWindowController
}
/// Retains sync windows opened by the `syncdemo` automation verb (F-192).
private var automationSyncWindows: [SyncWindowController] = []
/// Retains type-colour editors opened by the `typecolors` verb (F-032).
private var automationTypeColorEditors: [TypeColorsWindowController] = []
private var automationDiffWindows: [DiffWindowController] = []
private var automationProgressDialogs: [ProgressDialog] = []

extension MainWindowController {
    func runAutomationScript(_ path: String) async {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            NSLog("[automation] cannot read script: \(path)")
            return
        }
        NSLog("[automation] running \(path)")
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            let verb = parts[0].lowercased()
            let arg = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            NSLog("[automation] > \(line)")
            switch verb {
            case "left":       await leftPanelController?.loadDirectory(arg)
            case "right":      await rightPanelController?.loadDirectory(arg)
            case "active":     arg.lowercased().hasPrefix("r") ? activateRightPanel() : activateLeftPanel()
            case "focus":      activePanel?.tableView.focusEntry(named: arg)   // move cursor onto <name>
            case "enter":      activePanel?.tableView.enterUnderCursor()   // descend into the cursor item
            // Enter / double-click on the cursor item — a *different* question from `enter`, which is
            // Ctrl+PageDown and means "open this as an archive whatever it is". The two answers diverge
            // on exactly the files this distinguishes (an .xlsx is a zip), and with only `enter` here the
            // harness could not see the difference at all.
            case "openunder":
                if let p = activePanel { p.tableView.activateVisibleIndex(p.tableView.cursorRow) }
            case "reordertab":                                            // reorder tabs: reordertab <from> <to> (F-008)
                let p = arg.split(separator: " ").compactMap { Int($0) }
                if p.count == 2 { activePanel?.reorderTab(from: p[0], to: p[1]) }
            case "answer":                              // answer <text>: queue a reply for the next input dialog
                // Queued before the command that asks, so a modal prompt never stops the script.
                // Without this every command that asks a question was unreachable from a scenario.
                InputDialog.queueScriptedAnswer(arg)
            case "packanswer":                          // packanswer <archiveName>[|<format>] (F-402)
                // Queues the answer the pack dialog would get. Its own verb rather than `answer`:
                // that one feeds InputDialog, and the two dialogs ask different questions. The format is
                // named by its extension ("tar", "zip", "7z", …) — and in the guest it has to be `tar`,
                // because zip and 7z shell out to a `7z` binary a stock macOS does not carry.
                let pa = arg.split(separator: "|", maxSplits: 1).map(String.init)
                let format = pa.count == 2
                    ? PackFormat.allCases.first(where: { $0.fileExtension == pa[1] }) : nil
                PackOptionsDialog.queueScriptedName(pa[0], format: format)
            case "inlinerename":                        // inlinerename <newname> (F-081)
                // The in-cell rename, the one details view uses. `answer` cannot reach it: that feeds
                // `InputDialog`, and this path builds none — which is exactly why it went untested.
                PanelListView.queueScriptedInlineName(arg)
                if activePanel?.beginInlineRename() != true {
                    NSLog("[automation] inlinerename: the panel refused an in-cell rename")
                }
            case "inlinerenamesleft":                   // inlinerenamesleft <out>
                try? "\(PanelListView.hasScriptedInlineNames)\n".write(toFile: arg, atomically: true,
                                                                       encoding: .utf8)
            case "replaceanswer":                       // replaceanswer overwrite|autorename|skip|cancel (F-081)
                // The rename's "this name is taken" question — the copy conflict dialog, asked about
                // one item. Its own verb rather than `answer`: that one feeds `InputDialog`, and this
                // is an NSAlert, which a script cannot click and which hangs the run if really shown.
                ReplaceConfirmation.queueScriptedAnswer(arg)
            case "replaceanswersleft":                  // replaceanswersleft <out>
                // The other half, for the same reason `answersleft` exists: a build that replaced
                // without asking would otherwise leave exactly the same files behind as one that
                // asked and was told to go ahead.
                try? "\(ReplaceConfirmation.hasScriptedAnswers)\n".write(toFile: arg, atomically: true,
                                                                        encoding: .utf8)
            case "answersleft":                         // answersleft <out>: how many queued answers were NOT used
                // The other half of `answer`: a scenario that expected a prompt and got none would
                // otherwise pass quietly, having tested nothing at all.
                try? "\(InputDialog.hasScriptedAnswers)\n".write(toFile: arg, atomically: true, encoding: .utf8)
            case "cmd":        runCommandNamed(arg)
            case "pfxmount":                                              // pfxmount <volume-name> (e.g. TaskManager): mount a pfx drive volume by name into the active panel
                if let vol = FileSystemPluginRegistry.shared.driveVolumes()
                    .first(where: { $0.name == arg && PFXMountSentinel.parse($0.path) != nil }),
                   let parsed = PFXMountSentinel.parse(vol.path) {
                    // The volume, not just the plugin: a plugin with a chip per saved connection
                    // would otherwise mount whichever of them came first.
                    mountPluginVolume(pluginId: parsed.pluginId, volumeID: parsed.volumeId,
                                      into: activePanel)
                } else { NSLog("[automation] pfxmount: no pfx volume named \(arg)") }
            case "fsconnect":                                             // fsconnect <plugin-id fragment>: run a file-system plugin's interactive connect
                // `pfxmount` only reaches plugins that contribute a *static* drive. A plugin whose
                // whole point is connecting somewhere — WebDAV — has none, so its mount had no way
                // in from a script at all, and everything downstream of it (what a panel does when
                // that connection dies, whether its chip goes) was unreachable too.
                if let plugin = FileSystemPluginRegistry.shared.connectPlugins
                    .first(where: { $0.id.localizedCaseInsensitiveContains(arg) }) {
                    plugin.connect(host: self)
                } else {
                    NSLog("[automation] fsconnect: no connect plugin matching \(arg); have \(FileSystemPluginRegistry.shared.connectPlugins.map(\.id))")
                }
            case "connect":
                if let url = FtpURL.parse(arg) {
                    connectToSite(url.toSite(), password: url.password ?? "")
                } else {
                    NSLog("[automation] bad url: \(arg)")
                }
            case "disconnect": disconnectActivePanelNetwork()
            case "typeahead":           // typeahead <sequence>|<out>
                let a = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if let panel = activePanel, a.count == 2 {
                    panel.tableView.automationTypeAhead(a[0])
                    try? panel.tableView.typeAheadForAutomation
                        .write(toFile: a[1], atomically: true, encoding: .utf8)
                } else {
                    NSLog("[automation] typeahead needs <sequence>|<out> and an active panel")
                }
            case "drivedisconnect":     // drivedisconnect <chip-name>
                // The chip's own ⏏, reached the way the chip reaches it. `disconnect` above is the
                // menu command and aims at the active panel — a different question, and not the one
                // "can I hang this connection up from the drive bar" is asking.
                if let volume = NetworkMountRegistry.shared.volumes().first(where: { $0.name == arg }) {
                    ejectVolume(volume)
                } else {
                    NSLog("[automation] drivedisconnect: no open connection named \(arg)")
                }
            case "wait":
                let ms = UInt64(arg) ?? 500
                try? await Task.sleep(nanoseconds: ms * 1_000_000)
            case "dump":       await dumpActivePanel(to: arg)
            case "navhistdump":                         // navhistdump <out> (F-445): the back/forward stack
                // The per-panel history is otherwise only observable in `session.ini`, which is
                // written at quit — after the harness has taken its report and stopped the app. And
                // the panel's *path* cannot stand in for it: a position left pointing at the wrong
                // entry and a position put back correctly show the same panel, and differ only in
                // where the next press goes.
                if let panel = activePanel {
                    let h = panel.navigationHistory
                    var out = "count=\(h.entries.count)\nindex=\(h.index)\n"
                    for (i, entry) in h.entries.enumerated() { out += "entry\(i)=\(entry)\n" }
                    try? out.write(toFile: arg, atomically: true, encoding: .utf8)
                }
            case "symbols":    dumpSymbols(arg)
            case "editdump":   await editDump(arg)
            case "editfilter": await editFilter(arg)   // editfilter <src>|<command>|<out> (F-356)
            case "editregex":  await editRegex(arg)    // editregex <src>|<pat>|<repl>|<all 0|1>|<out>
            case "editfilterdlg": await editFilterDialog(arg)   // editfilterdlg <src> (F-356)
            case "editformat": await editFormat(arg)    // editformat <src>|<out> (F-412)
            case "editvalidate": await editValidate(arg) // editvalidate <src>|<out> (F-412)
            case "editlines":  await editLines(arg)     // editlines <src>|<out> (F-359)
            case "editstruct": await editStructure(arg) // editstruct <src>|<needle>|<out> (F-369)
            case "editnotes":                           // editnotes <src>|<line>|<out> (F-379)
                // Open `src` in the editor, write a note about `line` (0 = none), and dump what the
                // marks panel then holds. Notes live there rather than in the gutter — see the
                // editor's `annotatedLines`.
                let n = arg.split(separator: "|", maxSplits: 2).map(String.init)
                if n.count == 3 {
                    let win = EditorWindowController(path: n[0])
                    automationEditors.append(win)
                    win.showWindow(nil)
                    win.window?.makeKeyAndOrderFront(nil)
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    var out = ""
                    if let line = Int(n[1]), line > 0 {
                        out += "notekey=\(win.automationNoteKey(forLine: line))\n"
                    }
                    out += await win.automationMarksDump()
                    try? out.write(toFile: n[2], atomically: true, encoding: .utf8)
                }
            case "editsaveas":                          // editsaveas <src>|<text>|<dst>|<out>
                await editSaveAs(arg)
            case "editsave":   await editSave(arg)      // editsave <src>|<text>|<out> (F-387)
            case "setstring":                           // setstring <Section.Key>|<value> (F-409)
                // `setbool`'s counterpart, and needed for the same reason: a scenario that depends on a
                // *setting* has to state it, because the guest's peachcmd.ini carries whatever earlier
                // runs left there. The theme scenario found this the hard way — the guest had
                // `Colors.Appearance=dark`, which short-circuits the code path the scenario exists to
                // check, so it passed while testing nothing.
                let s = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if s.count == 2 { applyStringOption(s[0], s[1]) }
            case "setbool":                             // setbool <Section.Key>|<0|1> (F-387)
                // Through the settings dialog's own callback, so a script changes an option exactly the
                // way a click does — including whatever the host does besides writing the config.
                let b = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if b.count == 2 { applyBoolOption(b[0], b[1] == "1" || b[1].lowercased() == "true") }
            case "sftpget":                             // sftpget <remote>|<local>|<out>|<partial> (F-366)
                await sftpGet(arg)
            case "sftpput":                             // sftpput <local>|<remote>|<out>|<partial> (F-212)
                await sftpPut(arg)
            case "sftpchmod":                           // sftpchmod <path>|<octal>|<out> (F-364)
                await sftpChmod(arg)
            case "widenleft":                           // give the left panel almost the whole window, so a
                // wide opt-in column is actually *in* the screenshot. The report can pass with the column
                // clipped out of view; the picture then proves nothing, which is the whole reason the
                // pictures exist.
                automationWidenLeftPanel()
            case "comment":                             // comment <name>|<text>: set a file's comment the
                // way Ctrl+Z does, so a scenario can put one there without typing into a modal dialog.
                let parts = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if parts.count == 2, let panel = activePanel {
                    panel.tableView.focusEntry(named: parts[0])
                    _ = await panel.setCursorComment(parts[1])
                }
            case "markone":                             // markone <name>: mark exactly that one entry
                if let panel = activePanel {
                    panel.tableView.focusEntry(named: arg)
                    panel.tableView.markNames([arg])
                }
            case "marknames":                           // marknames <a>,<b>,…: mark exactly these
                // One call, because `markNames` clears first: two `markone` lines in a row leave
                // only the second marked. And it marks on a Task, so a `seldump` on the next line
                // reads the old state — put a `wait` in between.
                if let panel = activePanel {
                    let names = arg.split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    panel.tableView.markNames(Set(names))
                }
            case "renamemask":                          // renamemask <mask>|<outfile>: old -> new, resolved
                // The multi-rename dialog's own two steps, with no dialog: resolve every content-field
                // value for the panel's files, then run the mask through MultiRenameEngine. It exists
                // for the `[=provider.field]` tokens — a plugin-contributed field only becomes a rename
                // token if the plugin loaded, the slug matched and a value was found, and none of that
                // is visible from a unit test, which sees neither plugins nor panels. Nothing is
                // renamed; this reports what the dialog's preview column would show.
                let rp = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if rp.count == 2, let panel = activePanel {
                    let (dir, base) = await panel.renameInputs()
                    let inputs = await enrichRenameInputs(base, dir: dir)
                    let spec = RenameSpec(nameMask: rp[0], extMask: "[E]")
                    let results = MultiRenameEngine.compute(inputs, spec: spec)
                    // The resolved fields as well as the names: "the token produced nothing" and "the
                    // token is unknown" look identical in the output alone, and they have different fixes.
                    // `valid` and `collides` as well as the name: the engine already refuses a value
                    // carrying a path separator by marking the row, and the dialog greys it out and
                    // leaves it out of the batch. Reporting only the name hides that — it reads as a
                    // name the app would go on to create, which cost a wrong conclusion here once.
                    var text = "dir=\(dir)\n"
                    for (input, result) in zip(inputs, results) {
                        text += "old=\(input.name) new=\(result.newName)"
                            + " valid=\(result.isValid) collides=\(result.collides)\n"
                        for key in input.fields.keys.sorted() {
                            text += "  field=\(key) value=\(input.fields[key] ?? "")\n"
                        }
                    }
                    try? text.write(toFile: rp[1], atomically: true, encoding: .utf8)
                }
            case "seldump":                             // seldump <outfile>: what is marked, by name
                // The marked *names*, not a count alone: "one is marked" and "the right one is marked"
                // are different claims, and the selection-restore scenario needs the second (F-056).
                let marked = (activePanel?.tableView.selectedItemPaths() ?? [])
                    .map { ($0 as NSString).lastPathComponent }.sorted()
                let text = "marked=\(marked.count)\n" + marked.map { "name=\($0)" }.joined(separator: "\n") + "\n"
                try? text.write(toFile: arg, atomically: true, encoding: .utf8)
            case "sharedtree":                             // sharedtree on|off|select <path> (F-015)
                let a = arg.split(separator: " ", maxSplits: 1).map(String.init)
                switch a.first {
                case "on":  setSharedTreeVisible(true)
                case "off": setSharedTreeVisible(false)
                case "select" where a.count == 2:
                    // The click itself cannot be scripted; this is the callback the tree fires when a
                    // folder is chosen, so a scripted run goes through the same path.
                    sharedTreeAutomationSelect(a[1])
                default: NSLog("[automation] sharedtree needs on|off|select <path>")
                }
            case "listermode":                          // listermode <mode>|<out> (Viewer): switch + time it
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                let ms = currentLister()?.automationSetMode(a[0]) ?? -1
                if a.count == 2 {
                    let kind = currentLister()?.automationContentViewKind ?? "none"
                    // Which view was chosen matters as much as the timing: an NSTextView holding binary
                    // content is the defect, and it is fast only until something asks it to lay out.
                    try? String(format: "mode=%@\nswitch_ms=%.0f\nview=%@\nfast=%@\n",
                                a[0], ms, kind, ms >= 0 && ms < 3000 ? "yes" : "no")
                        .write(toFile: a[1], atomically: true, encoding: .utf8)
                }
            case "memdump":                             // memdump <out> (F-112): this process's memory
                // From the kernel (`phys_footprint`, the number Activity Monitor shows), not from any
                // bookkeeping of ours — the app is not grading its own work here, it is reading a
                // counter. It has to be taken while the app is alive: the harness kills it before the
                // external checks run, which is how the first version of this measured nothing at all.
                var info = task_vm_info_data_t()
                var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
                let kerr = withUnsafeMutablePointer(to: &info) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
                    }
                }
                let mb = kerr == KERN_SUCCESS ? Int(info.phys_footprint) / (1024 * 1024) : -1
                // 220 MB, from measurement rather than from a guess — and the first guess was wrong: it was
                // taken from `ps` RSS (139 idle / 257 fixed / 434 broken) and then applied to
                // `phys_footprint`, which does not count clean file pages and reads 140 fixed / 306
                // broken. At 350 the guard passed the broken build. Both numbers are for the same
                // 175 MB file.
                try? "footprint_mb=\(mb)\nlean=\(mb >= 0 && mb < 220 ? "yes" : "no")\n"
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "listercaret":                         // listercaret <line>: put the viewer's caret there
                currentLister()?.automationSetCaret(line: Int(arg) ?? 1)
            case "listernote":                          // listernote: write a note about the caret's line
                currentLister()?.automationNoteForCurrentLine()
            case "windowdump":                          // windowdump <outfile>: titles of the open windows
                // The note editor belongs to the plugin and is its own window, so the only thing the host
                // can honestly check about the write path is that the right window came up (F-379).
                let titles = NSApp.windows.filter { $0.isVisible && !$0.title.isEmpty }
                    .map { "window=\($0.title)" }.sorted().joined(separator: "\n")
                try? (titles + "\n").write(toFile: arg, atomically: true, encoding: .utf8)
            case "listermarks":                         // listermarks: open the viewer's docked marks panel
                // So the next `listerdump` reads rendered labels, not just the model behind them: a group
                // the panel never draws is not a feature the user has.
                currentLister()?.automationShowMarks()
            case "listerformat":                        // listerformat <out> (F-414): format, then draw, timed
                let out = currentLister()?.automationFormatAndDraw() ?? "ERROR: no lister window\n"
                try? out.write(toFile: arg, atomically: true, encoding: .utf8)
            case "listersymbol":                        // listersymbol <name>|<out> (F-410)
                // Drive the viewer's symbol outline and report where the content went. For a rendered
                // Markdown page that is the only way to tell a working entry from a dead one.
                let s = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if s.count == 2 {
                    let out = await currentLister()?.automationNavigateToSymbol(s[0])
                        ?? "ERROR: no lister window\n"
                    try? out.write(toFile: s[1], atomically: true, encoding: .utf8)
                }
            case "listermenudump":                      // listermenudump <out>
                // The viewer's own document menus, which `menudump` cannot see: it reads the main
                // menu bar, and a document window only installs itself there once it is key — which
                // in a scripted run it never becomes.
                let out = currentLister()?.automationToolMenuDump() ?? "ERROR: no lister window\n"
                try? out.write(toFile: arg, atomically: true, encoding: .utf8)
            case "listermarkstep":                      // listermarkstep <term>|<steps>|<out>
                // Mark All, then Next/Previous Mark that many times. Negative steps go backwards.
                let m = arg.split(separator: "|", maxSplits: 2).map(String.init)
                if m.count == 3 {
                    let out = currentLister()?.automationMarkStep(m[0], steps: Int(m[1]) ?? 1)
                        ?? "ERROR: no lister window\n"
                    try? out.write(toFile: m[2], atomically: true, encoding: .utf8)
                }
            case "listergoto":                          // listergoto <expression>|<out>
                // The viewer's Ctrl+G, answered from the script queue. The hex editor has had this
                // probe since F-400; the viewer's own Go To had none, which is part of why its hex
                // mode could scroll to a row and mark nothing for as long as it did.
                let g = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if g.count == 2 {
                    let out = currentLister()?.automationGoto(g[0]) ?? "ERROR: no lister window\n"
                    try? out.write(toFile: g[1], atomically: true, encoding: .utf8)
                }
            case "listerhexclick":                      // listerhexclick <hex|ascii>|<row>|<byte>|<out>
                // Which byte a click in each half of a hex row selects. The gutter half answered
                // "none" for the life of the feature, and no screenshot could say so.
                let c = arg.split(separator: "|", maxSplits: 3).map(String.init)
                if c.count == 4 {
                    let out = currentLister()?.automationHexClick(c[0], row: Int(c[1]) ?? 0,
                                                                  byte: Int(c[2]) ?? 0)
                        ?? "ERROR: no lister window\n"
                    try? out.write(toFile: c[3], atomically: true, encoding: .utf8)
                }
            case "listerstrings":                       // listerstrings <row|-1>|<out> (F-489)
                // Open the strings panel over the file in the viewer, wait for the scan, and
                // report the list — plus, for a row index, where clicking it put the hex view.
                let s = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if s.count == 2 {
                    let out = await currentLister()?.automationStrings(selectRow: Int(s[0]) ?? -1)
                        ?? "ERROR: no lister window\n"
                    try? out.write(toFile: s[1], atomically: true, encoding: .utf8)
                }
            case "listerdump":                          // listerdump <outfile>: what the viewer window shows
                let out = currentLister()?.automationSummary() ?? "ERROR: no lister window\n"
                try? out.write(toFile: arg, atomically: true, encoding: .utf8)
            case "history":                              // history <out> (F-402): open the palette, dump it
                let out = historyPaletteForAutomation().automationSummary()
                try? out.write(toFile: arg, atomically: true, encoding: .utf8)
            case "historytype":                         // historytype <text>|<out> (F-402)
                // Empty subsequences kept: `historytype |<out>` *clears* the search, and a dropped empty
                // component would silently make that line do nothing at all — which is how three
                // expectations in the VM came to be measured against a query that was still set.
                let h = arg.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                    .map(String.init)
                if h.count == 2 {
                    let palette = historyPaletteForAutomation()
                    palette.automationType(h[0])
                    try? palette.automationSummary().write(toFile: h[1], atomically: true, encoding: .utf8)
                }
            case "historyfilter":                       // historyfilter <0…4>|<out> (F-402)
                let h = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if h.count == 2, let index = Int(h[0]) {
                    let palette = historyPaletteForAutomation()
                    palette.automationSetFilter(index)
                    try? palette.automationSummary().write(toFile: h[1], atomically: true, encoding: .utf8)
                }
            case "historykey":                          // historykey <action>|<out> (F-402)
                // One verb for the palette's keyboard, because the interesting failures are about which
                // *row* an action lands on — and that is the same question for all of them.
                let h = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if h.count == 2 {
                    let palette = historyPaletteForAutomation()
                    switch h[0] {
                    case "down":     palette.automationMove(1)
                    case "up":       palette.automationMove(-1)
                    case "tab":      palette.automationToggleTarget()
                    case "open":     palette.automationOpenSelected()
                    case "show":     palette.automationOpenSelected(showInPanel: true)
                    case "pin":      palette.automationTogglePin()
                    case "remove":   palette.automationRemoveSelected()
                    case "copypath": palette.automationCopyPath()
                    default: break
                    }
                    // After open/show the palette has closed itself, so report the pasteboard and what
                    // the panels are doing instead of a window that is gone.
                    let summary = (h[0] == "open" || h[0] == "show")
                        ? "action=\(h[0])\nclipboard=\(NSPasteboard.general.string(forType: .string) ?? "")\n"
                        : palette.automationSummary()
                        + "clipboard=\(NSPasteboard.general.string(forType: .string) ?? "")\n"
                    try? summary.write(toFile: h[1], atomically: true, encoding: .utf8)
                }
            case "historymenu":                         // historymenu <out> (F-402): the palette's own menu
                let menu = historyPaletteForAutomation().automationMenu()
                var lines: [String] = []
                for item in menu.items {
                    if item.isSeparatorItem { lines.append("----"); continue }
                    let key = item.keyEquivalent.isEmpty ? ""
                        : "  key=" + Self.describe(key: item.keyEquivalent, mask: item.keyEquivalentModifierMask)
                    lines.append("\(item.title)\(key)")
                }
                try? (lines.joined(separator: "\n") + "\n").write(toFile: arg, atomically: true, encoding: .utf8)
            case "historyreset":                        // historyreset (F-402): start from an empty list
                HistoryService.shared.resetForAutomation()
            case "historyflush":                        // historyflush (F-402): let the debounced write land
                await HistoryService.shared.flushForAutomation()
            case "hexgoto":                             // hexgoto <path>|<expr>|<out> (F-400)
                let h = arg.split(separator: "|", maxSplits: 2).map(String.init)
                if h.count == 3 {
                    let out = openHexEditorForAutomation(path: h[0]).automationGoto(h[1])
                    try? out.write(toFile: h[2], atomically: true, encoding: .utf8)
                }
            case "hexstrings":                          // hexstrings <path>|<row|-1>|<out> (F-489)
                // The editor's own strings panel, over the bytes as edited rather than as on disk.
                let h = arg.split(separator: "|", maxSplits: 2).map(String.init)
                if h.count == 3 {
                    let out = await openHexEditorForAutomation(path: h[0])
                        .automationStrings(selectRow: Int(h[1]) ?? -1)
                    try? out.write(toFile: h[2], atomically: true, encoding: .utf8)
                }
            case "hexclip":                             // hexclip <path>|<typed>|<out> (F-401)
                // The clipboard in a *dialog field*, which `answer` cannot reach: a scripted answer
                // means the dialog never appears, and the field is the whole point here.
                let h = arg.split(separator: "|", maxSplits: 2).map(String.init)
                if h.count == 3 {
                    let out = openHexEditorForAutomation(path: h[0]).automationDialogClipboard(h[1])
                    try? out.write(toFile: h[2], atomically: true, encoding: .utf8)
                }
            case "macromanagerdo":                      // macromanagerdo <row>|<action> (F-478)
                // <row> is one-based; 0 means "nothing selected". <action> is one of run, export,
                // import, edit, record, recent, duplicate, delete, up, down, addbutton.
                let parts = arg.split(separator: "|", maxSplits: 1).map(String.init)
                let row = Int(parts.first ?? "") ?? 0
                let action = parts.count > 1 ? parts[1] : ""
                if macroManagerWindow?.performForAutomation(row: row, action: action) != true {
                    NSLog("[automation] macromanagerdo: no manager, or unknown action \(action)")
                }
            case "macromanagerdump":                    // macromanagerdump <out> (F-478)
                let report = macroManagerWindow?.automationReport()
                    ?? "ERROR: the macro manager is not open\n"
                try? report.write(toFile: arg, atomically: true, encoding: .utf8)
            case "closeeditor":                         // closeeditor: shut the text editor windows
                closeEditorWindows()
            case "closelister":                         // closelister: shut the viewer window
                // `closeviews` sounds like it would do this and does not — it tears down plugin view
                // *containers* (F-381). A scenario or a screenshot that opens the viewer and then wants
                // it gone had no way to say so, which is how a documentation shot came back showing
                // report.txt instead of the window it was for.
                currentLister()?.close()
                automationListers.removeAll { $0.window == nil || !($0.window?.isVisible ?? false) }
            case "listeresc":                           // listeresc <text|filter|filtertext|marks|findbar>|<out>
                // Esc closing the viewer is only interesting *after* the focus has moved off the
                // container view, so the verb takes where to click first.
                let e = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                let out = currentLister()?.automationEscape(focusing: e[0]) ?? "ERROR: no lister window\n"
                if e.count == 2 { try? out.write(toFile: e[1], atomically: true, encoding: .utf8) }
                automationListers.removeAll { !($0.window?.isVisible ?? false) }
            case "listerfind":                          // listerfind <pattern>|<regex 0|1>|<out>
                let f = arg.split(separator: "|", maxSplits: 2).map(String.init)
                if f.count == 3 {
                    let out = currentLister()?.automationFind(f[0], regex: f[1] == "1",
                                                              caseInsensitive: false)
                        ?? "ERROR: no lister window\n"
                    try? out.write(toFile: f[2], atomically: true, encoding: .utf8)
                }
            case "mainshot":                            // mainshot <out.png>: a picture of the main window
                // The main window draws with AppKit, so it can hand over its own picture — which the
                // gallery's thumbnails need and no text dump can show. `screencapture` is the obvious
                // alternative and returns a black frame without Screen Recording permission, which a
                // verification run has no business asking a machine for.
                // The key window rather than the main one, so a dialog or the Settings window can be
                // photographed too — which is the only way to see a plugin's own settings pane.
                if let view = (NSApp.keyWindow ?? window)?.contentView,
                   let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    if let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: arg))
                        NSLog("[automation] mainshot: %.0fx%.0f", view.bounds.width, view.bounds.height)
                    } else {
                        NSLog("[automation] mainshot: no png")
                    }
                } else {
                    NSLog("[automation] mainshot: no content view")
                }
            case "listershot":                          // listershot <out.png>: a picture of the viewer's content
                // The one thing about the viewer that cannot be dumped as text. Awaited, because the
                // web view's snapshot is asynchronous and the harness reads the file straight after.
                if let lister = currentLister() {
                    let result = await withCheckedContinuation { (c: CheckedContinuation<String, Never>) in
                        lister.automationContentSnapshot(to: arg) { c.resume(returning: $0) }
                    }
                    NSLog("[automation] listershot: %@", result)
                } else {
                    NSLog("[automation] listershot: no lister window")
                }
            case "listerzoom":                          // listerzoom <in|out|actual|fit|state>|<out> (F-389)
                let z = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if z.count == 2 {
                    let out = currentLister()?.automationZoom(z[0]) ?? "ERROR: no lister window\n"
                    try? out.write(toFile: z[1], atomically: true, encoding: .utf8)
                }
            case "screenclamp":                         // screenclamp <W>x<H>|<out>
                // A screen change cannot be provoked from outside the app, so this provokes it from
                // inside: force the window to a size a smaller display would leave behind, post the
                // notification AppKit posts, and report what came of it — then post it again with
                // the window fitting, which is the "monitor plugged back in" half.
                await screenClampReport(arg)
            case "previewpanel":                        // previewpanel on|off: *set* it, do not toggle
                // A toggle depends on what the previous scenario left behind — this scenario measured a
                // closed panel in the full run and an open one when run alone, which is how a layout
                // conflict hid for as long as it did.
                if let panel = previewPanelForAutomation() {
                    let wantOpen = arg.lowercased() != "off"
                    if panel.frame.width <= 1 || panel.isHidden { if wantOpen { togglePreviewPanel() } }
                    else if !wantOpen { togglePreviewPanel() }
                }
            case "dock":                                // dock on|off (F-381): *set* it, do not toggle
                // Same lesson as `previewpanel`: a toggle depends on what the previous scenario left
                // behind, which is how a layout conflict once passed alone and failed in company.
                setBottomDockVisible(arg.lowercased() != "off")
            case "dockdump":                            // dockdump <out> (F-381)
                dumpBottomDock(arg)
            case "refreshviews":                        // refreshviews (F-381)
                // The exact entry point a plugin being enabled or disabled reaches. Nothing about the
                // *contributions* changes here, which is the whole question: a refresh that changes
                // nothing must destroy nothing.
                ViewContainerRegistry.shared.refresh(host: self)
            case "cmdline":                             // cmdline <text> (F-381): run it, as pressing
                // Return in the command line does — through the same entry point, so whichever route
                // it takes (detached or into the terminal) is the real one.
                runCommandLineForAutomation(arg)
            case "focuscmdline":                        // focuscmdline [container] (F-381)
                focusCommandLineForAutomation(container: arg == "container")
            case "keyequiv", "keyequivmenu":            // keyequiv[menu] <mods><char>|<out> (F-381)
                // Two verbs because there are two paths and they answer different questions.
                // `keyequiv` broadcasts to the view hierarchy, which is what the raw-keyboard rule
                // governs; `keyequivmenu` asks the main menu first, as AppKit does, which is the only
                // way to reach a shortcut that exists solely as a menu item.
                // e.g. "W+c" for Cmd+C, "C+b" for Ctrl+B. Reports whether anything in the window
                // claimed it, plus what the file clipboard holds afterwards — the question is not
                // "did a key arrive" but "did the panel act on a key aimed at something else".
                let a = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if a.count == 2, let chord = KeyChord(parsing: a[0]) {
                    var flags: NSEvent.ModifierFlags = []
                    if chord.cmd { flags.insert(.command) }
                    if chord.ctrl { flags.insert(.control) }
                    if chord.alt { flags.insert(.option) }
                    if chord.shift { flags.insert(.shift) }
                    // BACKQUOTE names a *position*, so it has to be sent as one: the character this
                    // key produces depends on the layout, which is the whole reason the token exists.
                    let isPositional = chord.key == "BACKQUOTE"
                    let claimed = sendKeyEquivalentForAutomation(
                        isPositional ? "`" : chord.key.lowercased(), flags: flags,
                        keyCode: isPositional ? KeymapMenu.backquoteKeyCode : 0,
                        viaMenu: verb == "keyequivmenu")
                    let board = NSPasteboard.general
                    let urls = (board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]) ?? []
                    let text = board.string(forType: .string) ?? ""
                    // Who had the keyboard. Without this a failure here is unreadable: "the panel
                    // did not claim Cmd+C" has two very different causes, and only one is a bug.
                    let responder = window?.firstResponder
                    var out = "responder=\(responder.map { String(describing: type(of: $0)) } ?? "<none>")\n"
                    out += "claimed=\(claimed)\n"
                    out += "fileURLs=\(urls.count)\n"
                    out += "names=\(urls.map { $0.lastPathComponent }.joined(separator: ","))\n"
                    out += "text=\(text.prefix(80))\n"
                    try? out.write(toFile: a[1], atomically: true, encoding: .utf8)
                }
            case "keysend":                             // keysend <chord>|<field|asis>|<out> (F-404)
                // The key goes to whatever window is *key*, not to the main window: the question is what
                // a keystroke aimed at a dialog does to the file panels behind it.
                let k = arg.split(separator: "|", maxSplits: 2).map { String($0).trimmingCharacters(in: .whitespaces) }
                if k.count == 3 {
                    let out = automationSendKey(k[0], focus: k[1])
                    try? out.write(toFile: k[2], atomically: true, encoding: .utf8)
                }
            case "columnsdump":                         // columnsdump <out> (F-428)
                // Column ids next to the titles actually drawn: the id keys saved column sets and must NOT
                // move with the language, the title must. One report shows both halves of that promise.
                let panel = activePanel?.tableView
                let rows = (panel?.tableColumns ?? []).map { column in
                    "id=\(column.identifier.rawValue)\ttitle=\(column.title)"
                }
                try? (rows.joined(separator: "\n") + "\n").write(toFile: arg, atomically: true,
                                                                encoding: .utf8)
            case "gutterclick":                         // gutterclick <line>|<out> (F-426)
                let c = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if c.count == 2, let line = Int(c[0]) {
                    let fired = automationClickGutterAnnotation(line: line)
                    try? "clicked=\(fired ? 1 : 0)\n".write(toFile: c[1], atomically: true,
                                                             encoding: .utf8)
                }
            case "gutterdump":                          // gutterdump <out>[|<path>] (F-426)
                // What a plugin's per-line annotations actually reached: the gutter's width, how many
                // annotations it holds and the first of them. Without this, "blame in the gutter" could
                // only be checked by looking at a screenshot.
                let g = arg.split(separator: "|", maxSplits: 1).map(String.init)
                let text = automationGutterDump(path: g.count > 1 ? g[1] : nil)
                try? text.write(toFile: g[0], atomically: true, encoding: .utf8)
            case "plugincancel":                        // plugincancel <out> (F-422)
                // Press Cancel in the progress window of an asynchronous plugin command. Not `keysend
                // escape`: a synthesised key event does not reach a button's `keyEquivalent`, so that
                // reported success while the command kept running.
                let cancelled = automationCancelPluginProgress()
                try? "cancelled=\(cancelled ? 1 : 0)\n".write(toFile: arg, atomically: true,
                                                              encoding: .utf8)
            case "closeviews":                          // closeviews (F-381)
                // The same teardown path quitting takes, but with the app still running — which is the
                // only way to observe that PcCloseView did anything. After the process exits, every
                // child dies from the pseudo-terminal's master fd closing, so a check made afterwards
                // cannot tell teardown from cleanup.
                ViewContainerRegistry.shared.closeAll()
            case "probe":                               // probe <out>|<command> (F-381)
                // Ask the machine a question while the app is alive. Not the app testifying about
                // itself: the process table is an external fact and the app is only the messenger.
                //
                // The output path comes *first*, which looks backwards next to every other verb here.
                // It has to: the argument is split on its first "|", and a shell command worth asking
                // usually contains pipes of its own. Putting the path last silently truncated the
                // command and wrote nothing at all.
                let a = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if a.count == 2 {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/bin/sh")
                    task.arguments = ["-c", a[1]]
                    let pipe = Pipe()
                    task.standardOutput = pipe
                    task.standardError = FileHandle.nullDevice
                    task.standardInput = FileHandle.nullDevice
                    try? task.run()
                    let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    task.waitUntilExit()
                    try? out.write(toFile: a[0], atomically: true, encoding: .utf8)
                }
            case "quit":                                // quit (F-381)
                // A real quit, not a kill: applicationShouldTerminate is where plugin views are torn
                // down, and the harness's `pkill` never reaches it. Anything testing what happens on
                // exit has to go through this door or it is testing nothing.
                //
                // Scheduled as a run-loop timer, and that detail is the whole of it.
                //
                // `terminate:` answers `.terminateLater` by spinning a nested event loop until the
                // delegate replies, and the delegate replies from a `Task { @MainActor }` — which
                // is a main-queue job. libdispatch will not re-enter the main queue while it is
                // already draining it, so calling `terminate:` from anywhere on that queue (here,
                // or from `DispatchQueue.main.async`) means the reply can never run: the app hangs
                // on *every* build, and the harness reports "quitting is broken" no matter what the
                // code under test does. Both wrong answers were measured before this comment.
                //
                // A timer fires from the run loop itself rather than from a main-queue block, which
                // is where ⌘Q and the Quit menu item come from too. This is the only scheduling that
                // reproduces what a user actually does.
                NSApp.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0)
            case "treecolors":                          // treecolors <out> (F-015)
                dumpTreeColours(arg)
            case "surfacecolors":                       // surfacecolors <out> (F-015)
                dumpSurfaceColours(arg)
            case "treevisible":                         // treevisible <shared|panel>|<0|1> (F-409)
                // Sets the state instead of toggling it. `cm_TreeShared` and `cm_SrcTree` are toggles,
                // and the tree's visibility is persisted in the guest's peachcmd.ini — so a scenario
                // built on toggles gets the state its predecessor happened to leave, and the colour
                // audit read an unpainted, hidden tree while reporting it as the app's own colours.
                let t = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if t.count == 2 {
                    let on = t[1] == "1" || t[1].lowercased() == "true"
                    if t[0] == "shared" { setSharedTreeVisible(on) } else { activePanel?.setTreeVisible(on) }
                }
            case "themestate":                          // themestate <out> (F-409)
                // What the theme *resolved to*, which is the question a screenshot cannot answer on its
                // own: a dark palette under a light window appearance looks like "some areas have the
                // wrong colours", and the numbers say which half is wrong.
                try? themeStateDump().write(toFile: arg, atomically: true, encoding: .utf8)
            case "fkeydump":                            // fkeydump <out> (F-381)
                // Whether the function-key bar is claiming keys it does not have. Reported next to the
                // responder, because "dimmed" only means anything alongside "and this is what has the
                // keyboard".
                let responder = window?.firstResponder.map { String(describing: type(of: $0)) } ?? "<none>"
                try? "responder=\(responder)\nkeysAreOurs=\(functionKeyBarForAutomation()?.keysAreOurs ?? true)\n"
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "panelsdump":                          // panelsdump <out> (F-381)
                // Both panels and which one is active. `dump` reports the *active* panel, so it cannot
                // tell "the left panel navigated" from "the right panel became active" — and those are
                // very different bugs.
                let l = await leftPanelController?.getCurrentPath() ?? "<none>"
                let r = await rightPanelController?.getCurrentPath() ?? "<none>"
                let side = activePanel === leftPanelController ? "left" : "right"
                let responder = window?.firstResponder.map { String(describing: type(of: $0)) } ?? "<none>"
                try? "active=\(side)\nleft=\(l)\nright=\(r)\nresponder=\(responder)\n"
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "aitool":                             // aitool <tool>|<json-args>|<out> (F-446)
                // Run one assistant tool through the Automation Core and write its payload. Without
                // this a tool can only be exercised by talking to a model, which makes the *tool* and
                // the model's willingness to call it one untestable lump — and a read tool that
                // returns the wrong thing looks exactly like a model that phrased the question badly.
                // `omittingEmptySubsequences: false`, or a tool that takes no arguments cannot be
                // called at all: `aitool list_macros||<out>` loses its empty middle field, comes back
                // as two components, and the verb silently does nothing. `get_context` and
                // `list_macros` are exactly that shape.
                let at = arg.split(separator: "|", maxSplits: 2,
                                   omittingEmptySubsequences: false).map(String.init)
                if at.count == 3 {
                    let args = at[1].data(using: .utf8)
                    // `.standard` is the policy the assistant itself runs under, so a read answers and
                    // a write asks — the same answer the model would get.
                    // A ":confirm" suffix on the tool name agrees to the plan straight away, which is
                    // the only way to exercise a gated action from a script — and the plan is written
                    // out either way, so the table a user would have read is still in the report.
                    // "<tool>:confirm" agrees to the whole plan; "<tool>:confirm:<id>,<id>" agrees to
                    // it with those rows struck out, which is the only way to exercise a partial
                    // confirmation without a mouse (F-450).
                    var tool = at[0]
                    var wantsConfirm = false
                    var rejected: Set<String> = []
                    // ":session" runs under the *configured* policy instead of `.standard`. Without it a
                    // capability the user has switched on in Settings — the shell, scripting — cannot be
                    // exercised from a script at all: `.standard` withholds both by construction, so a
                    // run could only ever measure the refusal (F-477).
                    var wantsSessionPolicy = false
                    if let range = tool.range(of: ":session") {
                        wantsSessionPolicy = true
                        tool = tool.replacingCharacters(in: range, with: "")
                    }
                    if let range = tool.range(of: ":confirm") {
                        wantsConfirm = true
                        let tail = String(tool[range.upperBound...])
                        tool = String(tool[..<range.lowerBound])
                        if tail.hasPrefix(":") {
                            rejected = Set(tail.dropFirst().split(separator: ",").map(String.init))
                        }
                    }
                    let policy: PermissionPolicy = wantsSessionPolicy
                        ? await currentAutonomyPolicy() : .standard
                    var outcome = try? await automationCore.invoke(tool: tool, arguments: args,
                                                                   policy: policy)
                    var plan: String?
                    if wantsConfirm, case .needsConfirmation(let p, let token) = outcome {
                        // The rows are reported alongside the plan: a check that strikes one out has to
                        // be able to see what the ids actually were.
                        let rows = await automationCore.planItems(token: token)
                        plan = p + (rows.isEmpty ? "" :
                            "\nrows: " + rows.map { "\($0.id)=\($0.text)" }.joined(separator: " | "))
                        outcome = try? await automationCore.confirm(token: token, rejecting: rejected)
                    }
                    let text: String
                    switch outcome {
                    case .ok(let payload):
                        let body = payload.flatMap { String(data: $0, encoding: .utf8) } ?? "(no payload)"
                        text = plan.map { "confirmed: \($0)\n" + body } ?? body
                    case .needsConfirmation(let plan, _): text = "needsConfirmation: \(plan)"
                    case .refused(let reason):            text = "refused: \(reason)"
                    case .failed(let error):              text = "failed: \(error)"
                    case nil:                             text = "ERROR: the tool threw"
                    }
                    try? (text + "\n").write(toFile: at[2], atomically: true, encoding: .utf8)
                }
            case "pathbardump":                        // pathbardump <left|right>|<out> (F-444)
                // The path bar draws its breadcrumb and handles its own clicks, so whether it is in edit
                // mode is readable nowhere else — not through a control, and not from a screenshot that
                // cannot say where the segments ended.
                let pd = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if pd.count == 2 {
                    let panel = pd[0] == "right" ? rightPanelController : leftPanelController
                    try? (panel?.view.pathBarStateForAutomation ?? "ERROR: no panel\n")
                        .write(toFile: pd[1], atomically: true, encoding: .utf8)
                }
            case "pathbarclick":                       // pathbarclick <side>|<region>|<clicks>|<out> (F-444)
                // Regions: first, last, gap, trailing, pencil, x:<n>. A real synthesised event through
                // `mouseDown`, so the coordinates the bar draws with and the ones it hit-tests against
                // have to agree — the half a direct call to the decision function would assume.
                let pc = arg.split(separator: "|").map(String.init)
                if pc.count == 4, let clicks = Int(pc[2]) {
                    let panel = pc[0] == "right" ? rightPanelController : leftPanelController
                    let hit = panel?.view.pathBarHitTestForAutomation(pc[1]) ?? "<no panel>"   // first
                    let x = panel?.view.clickPathBarForAutomation(pc[1], clickCount: clicks)
                    let at = x.map { String(format: "%.0f", $0) } ?? "<no such region>"
                    try? ("clickedAt=\(at)\nhitTest=\(hit)\n"
                          + (panel?.view.pathBarStateForAutomation ?? ""))
                        .write(toFile: pc[3], atomically: true, encoding: .utf8)
                }
            case "sortcol":                            // sortcol <fieldID> (F-392): sort by a plugin column
                activePanel?.tableView.automationSortByPluginColumn(arg)
            case "filter":                             // filter <text> (F-395): apply the quick filter
                activePanel?.tableView.automationSetFilter(arg)
            case "viewdump":                           // viewdump <out> (F-398): cursor + scroll position
                try? (activePanel?.tableView.automationViewport() ?? "ERROR: no active panel\n")
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "scrollto":                           // scrollto <row> (F-398): scroll, cursor unmoved
                activePanel?.tableView.automationScrollTo(row: Int(arg) ?? 0)
            case "rowdump":                             // rowdump <out> (F-392): the cursor row, column by column
                let cells = activePanel?.tableView.automationCursorRowCells() ?? []
                var out = cells.map { "\($0.field)\t\($0.text)" }.joined(separator: "\n")
                // What the row is *drawing* as an icon (F-428) — a value carrying a symbol name is not
                // proof that an image reached the cell.
                for drawn in activePanel?.tableView.automationCursorRowSymbols() ?? [] {
                    out += "\nsymbol \(drawn.field)\t\(drawn.symbol)"
                }
                try? (out + "\n").write(toFile: arg, atomically: true, encoding: .utf8)
            case "gotoopenfile":                        // gotoopenfile (F-391): "Go to File" on the cursor row
                if let real = activePanel?.tableView.cursorOpenFilePath() {
                    goToOpenFile(real)
                    NSLog("[automation] gotoopenfile → \(real)")
                } else {
                    NSLog("[automation] gotoopenfile: the cursor row is not an open file")
                }
            case "procfile":                            // procfile <path> (F-390)
                // The modal-free half of "Find Processes by File…": `runModal` never returns to a
                // script, so the dialog itself cannot be driven — this is the search it performs.
                let hits = highlightProcesses(holdingFile: arg)
                NSLog("[automation] procfile \(arg) → \(hits) process(es)")
            case "prochldump":                          // prochldump <out> (F-390)
                // Which rows carry the file-handle colour, and which of the three it is. A
                // screenshot cannot answer that: the colours differ by hue at the same lightness,
                // and `dump` reports names only.
                if let table = activePanel?.tableView {
                    let rows = table.fileHandleHighlightRows()
                    let out = "count=\(rows.count)\n"
                        + rows.map { "\($0.name)\t\($0.kind.rawValue)\t"
                            + (table.automationRenderedNameColor(forName: $0.name) ?? "<no cell>") }
                            .joined(separator: "\n")
                        + (rows.isEmpty ? "" : "\n")
                    try? out.write(toFile: arg, atomically: true, encoding: .utf8)
                } else {
                    try? "ERROR: no active panel\n".write(toFile: arg, atomically: true, encoding: .utf8)
                }
            case "drivebardump":                        // drivebardump <out> (F-385)
                // What the panel says it is showing — the current chip, the tab titles and the
                // breadcrumb — next to the path. Only together do they say anything: inside a plugin
                // drive the path is that mount's own "/", so a panel that names the drive and one
                // that claims to be at the startup disk's root report the same path, and one of them
                // is the bug this exists to catch.
                if let panel = activePanel {
                    let index = panel.view.driveBar.highlightedIndex
                    let current = index.flatMap { panel.driveVolumes.indices.contains($0) ? panel.driveVolumes[$0].name : nil }
                    let chrome = panel.view.chromeForAutomation
                    let out = "path=\(await panel.getCurrentPath())\ncurrent=\(current ?? "<none>")\n"
                        + "tabs=\(chrome.tabs)\ncrumb=\(chrome.crumb)\n"
                        // Each chip's kind and where its picture came from (F-386): a bar that draws
                        // one icon for every volume and a bar that tells them apart look the same to
                        // every check that only reads names.
                        + "chips=\(panel.view.driveBar.chipsForAutomation)\n"
                    try? out.write(toFile: arg, atomically: true, encoding: .utf8)
                }
            case "termnotify":                          // termnotify <viewId>|<key>|<value> (F-381)
                // The generic form of `termsend`: any host-context key, which is how the host's own
                // terminal commands (new tab, switch tab) will reach the plugin once they exist.
                let a = arg.split(separator: "|", maxSplits: 2).map(String.init)
                if a.count >= 2 {
                    let sent = ViewContainerRegistry.shared.notifyView(
                        viewId: a[0], key: a[1], value: a.count > 2 ? a[2] : "")
                    NSLog("[automation] termnotify \(a[0]) \(a[1]): \(sent)")
                }
            case "termsend":                            // termsend <viewId>|<text> (F-381)
                // Types into a plugin view's pseudo-terminal through the same channel the host will
                // use for "open terminal here" and for dropping file names at the prompt. "\n" in the
                // text is a real newline: a scenario line cannot carry one.
                let a = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if a.count == 2 {
                    // "\\n" is a real newline and "\\s" a real space: a script line is trimmed of
                    // trailing whitespace before it gets here, so `echo ` arrived as `echo` and the
                    // names inserted after it ran into the command.
                    let text = a[1].replacingOccurrences(of: "\\n", with: "\n")
                                   .replacingOccurrences(of: "\\s", with: " ")
                    let sent = ViewContainerRegistry.shared.notifyView(viewId: a[0], key: "sendText",
                                                                      value: text)
                    NSLog("[automation] termsend \(a[0]): \(sent)")
                }
            case "runshell":                            // runshell <out>|<command> (F-381)
                // The assistant's run_shell, minus the assistant. Everything below the tool call is
                // real: a tab opens, a non-interactive shell runs the line, and what it printed comes
                // back the way the model would receive it. The output path comes first for the same
                // reason `probe`'s does — a command worth running contains pipes.
                let rs = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if rs.count == 2 {
                    let out = (try? await runShellVisibly(rs[1])) ?? "ERROR"
                    try? out.write(toFile: rs[0], atomically: true, encoding: .utf8)
                }
            case "dropview":                            // dropview <container>|<viewId> (F-381)
                // The drop the drag would perform, minus the drag. Everything downstream is real: the
                // "would this do anything" rule, the placement write, opening the container if it was
                // shut, and bringing the view to the front.
                let d = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if d.count == 2 {
                    let ok: Bool
                    switch d[0] {
                    case "sidebar": ok = previewPanelForAutomation()?.dropViewForAutomation(id: d[1]) ?? false
                    case "bottom":  ok = bottomDockForAutomation()?.dropViewForAutomation(id: d[1]) ?? false
                    default:        ok = false
                    }
                    NSLog("[automation] dropview \(d[0]) \(d[1]): \(ok)")
                }
            case "placeview":                           // placeview <viewId>|<container|default> (F-381)
                // The drag cannot be scripted, so this is the entry point the drop and the menu item
                // both call — the same rule as `bardrop`. What matters is the other end anyway: where
                // the view ends up, and whether it survived the trip.
                let a = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if a.count == 2 {
                    let target = a[1] == "default" ? nil : a[1]
                    let moved = ViewContainerRegistry.shared.place(viewId: a[0], in: target, host: self)
                    NSLog("[automation] placeview \(a[0]) -> \(a[1]): \(moved)")
                }
            case "moveview":                            // moveview <viewId>|<container|default> (F-388)
                // The *menu item's* path, as opposed to `placeview`, which is the registry primitive
                // underneath it. The difference is the whole of F-388: placing a view and showing it
                // where it landed are two steps, and only the second one was missing.
                let m = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if m.count == 2 {
                    let item = NSMenuItem()
                    item.representedObject = ViewPlacementRequest(viewId: m[0],
                                                                  container: m[1] == "default" ? nil : m[1])
                    movePluginViewFromMenu(item)
                }
            case "mountdump":                           // mountdump <out> (F-381)
                try? ViewContainerRegistry.shared.automationReport()
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "previewtab":                          // previewtab <title>: pick a preview panel tab
                if let panel = previewPanelForAutomation() {
                    NSLog("[automation] previewtab \(arg): \(panel.automationSelectTab(titled: arg))")
                }
            case "previewtabsdump":                     // previewtabsdump <out> (F-476)
                // Which tabs the side panel offers, whether it has a tab strip at all, and which tab is
                // showing. `sidebardump` cannot answer any of that — it walks text fields, and the strip
                // is a segmented control.
                let report = previewPanelForAutomation()?.automationTabReport()
                    ?? "ERROR: no preview panel view\n"
                try? report.write(toFile: arg, atomically: true, encoding: .utf8)
            case "tccomment":                           // tccomment <dir>|<out> (F-374)
                // Read a `descript.ion` that Total Commander would have written — UTF-16 with a BOM and a
                // multi-line comment — then write one comment back and report what is on disk afterwards.
                // The bytes are what matters: rewriting the file as UTF-8 destroys every comment in it,
                // including the ones nobody touched.
                let a = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if a.count == 2, let panel = activePanel {
                    await panel.loadDirectory(a[0])
                    panel.refreshComments()
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    // The fixture itself, so a failing expectation cannot be blamed on the parser without
                    // looking: quoting a file through python → ssh → sh has produced the wrong bytes
                    // twice in this harness already.
                    let fixture = (try? Data(contentsOf: URL(fileURLWithPath: a[0] + "/descript.ion"))) ?? Data()
                    let fixtureText = DescriptionFile.decode(fixture).text
                    var out = "fixture=\(fixtureText.replacingOccurrences(of: "\n", with: "⏎").replacingOccurrences(of: "\u{04}", with: "<04>"))\n"
                    out += "read16=\(panel.tableView.automationComment(forName: "tc-utf16.txt") ?? "<none>")\n"
                    let multi = panel.tableView.automationComment(forName: "tc-multi.txt") ?? "<none>"
                    out += "readMulti=\(multi.replacingOccurrences(of: "\n", with: "⏎"))\n"
                    panel.tableView.focusEntry(named: "tc-utf16.txt")
                    _ = await panel.setCursorComment("geändert durch die App")
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    let raw = (try? Data(contentsOf: URL(fileURLWithPath: a[0] + "/descript.ion"))) ?? Data()
                    let bom = raw.prefix(2).map { String(format: "%02X", $0) }.joined()
                    out += "bomAfterWrite=\(bom)\n"
                    panel.refreshComments()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    out += "kept=\(panel.tableView.automationComment(forName: "tc-multi.txt")?.replacingOccurrences(of: "\n", with: "⏎") ?? "<none>")\n"
                    out += "written=\(panel.tableView.automationComment(forName: "tc-utf16.txt") ?? "<none>")\n"
                    try? out.write(toFile: a[1], atomically: true, encoding: .utf8)
                }
            case "commentread":                         // commentread <name>|<out> (F-372)
                let parts = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if parts.count == 2, let panel = activePanel {
                    let path = (await panel.getCurrentPath() as NSString).appendingPathComponent(parts[0])
                    panel.refreshComments()
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    let out = "hostComment=\(contribFileComment(path) ?? "<none>")\n"
                        + "column=\(panel.tableView.automationComment(forName: parts[0]) ?? "<none>")\n"
                    try? out.write(toFile: parts[1], atomically: true, encoding: .utf8)
                }
            case "sidebarsetfield":                     // sidebarsetfield <text> (F-372)
                // Type into the *plugin's* comment field and commit it, the way a user leaving the field
                // does. Proving the read direction alone would leave the write path — the one that changes
                // a file on disk — unverified.
                if let panel = previewPanelForAutomation() {
                    NSLog("[automation] sidebarsetfield: \(automationCommitFirstEditableField(in: panel, text: arg))")
                }
            case "sidebardump":                         // sidebardump <outfile> (F-372)
                dumpSidebar(arg)
            case "quickviewzoom":                       // quickviewzoom <in|out|actual|fit|state>|<out> (F-389)
                // The *other* quick preview: the one Ctrl+Q puts into the inactive panel, which is the
                // left one whenever the right is active. Same class, so the same report.
                let q = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if q.count == 2 {
                    guard let area = quickViewForAutomation() else {
                        try? "ERROR: no quick view\n".write(toFile: q[1], atomically: true, encoding: .utf8)
                        break
                    }
                    if q[0] != "state" { NSLog("[automation] quickviewzoom \(q[0]): \(area.automationPressZoom(q[0]))") }
                    try? area.automationZoomReport().write(toFile: q[1], atomically: true, encoding: .utf8)
                }
            case "previewzoom":                         // previewzoom <in|out|actual|fit|state>|<out> (F-389)
                let z = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if z.count == 2, let panel = previewPanelForAutomation() {
                    if z[0] != "state" { NSLog("[automation] previewzoom \(z[0]): \(panel.automationPressZoom(z[0]))") }
                    try? panel.automationZoomReport().write(toFile: z[1], atomically: true, encoding: .utf8)
                }
            case "column":                              // column <fieldID>: switch an opt-in column on
                if let panel = activePanel, !panel.tableView.hasColumn(arg) { toggleColumn(arg, panel: panel) }
            case "commentcarry":                        // commentcarry <dir>|<name>|<newName>|<out> (F-372)
                await commentCarryProbe(arg)
            case "mkfile":                              // mkfile <path> (F-361): create a file the way
                // another program would — not through a panel operation, so nothing asks the panel to
                // reload. If the file shows up, the watcher is what put it there.
                try? "auto\n".write(toFile: arg, atomically: true, encoding: .utf8)
            case "view":       openViewer(arg)
            case "menudump":   dumpMenu(arg)
            case "menuclick":  clickMenuItem(arg)      // menuclick <cm_/em_ name>|<out> (F-257)
            case "reloadmenu":                          // reloadmenu (F-257): re-read .mnu + usercmd.ini
                // What activating the app does, on demand: a scenario writes a menu file and
                // then needs it applied, and it cannot deactivate and reactivate the app.
                reloadUserCommandsFromDisk()
                reloadMenuFileFromDisk()
            case "a11ydump":   dumpAccessibility(arg)   // a11ydump <outfile> (I19 T06)
            case "keyloop":    dumpKeyLoop(arg)         // keyloop <outfile> (I19 T06)
            case "keyloopmodal":                        // keyloopmodal <outfile> (I19 T06)
                // Call *before* opening a modal dialog: `runModal` does not return until the dialog is
                // dismissed, so a `keyloop` line after it never runs. Scheduling in the modal run-loop
                // modes is how the rest of this codebase reaches into a modal session.
                // A delay, and a Timer rather than a queue block: performing immediately dumped the
                // *main* window because the dialog had not opened yet — a false pass, caught only by
                // reading the report. The timer is added to the modal modes so it fires while the
                // dialog is up.
                let target = arg
                let timer = Timer(timeInterval: 1.2, repeats: false) { [weak self] _ in
                    self?.dumpKeyLoop(target)
                }
                RunLoop.main.add(timer, forMode: .modalPanel)
                RunLoop.main.add(timer, forMode: .default)
            case "modaldump":                           // modaldump <outfile>: read a modal alert's text
                // The harness could keyboard-walk a modal but never read what it *said*, so an alert
                // that appeared with the wrong text — or an alert that should have appeared and did not
                // — was invisible to it. Scheduled into the modal run-loop mode for the same reason
                // `keyloopmodal` is, and it dismisses the alert afterwards: `runModal` never returns on
                // its own, so leaving it up means the scenario writes no report at all.
                let out = arg
                let dumpTimer = Timer(timeInterval: 1.5, repeats: false) { _ in
                    MainActor.assumeIsolated {
                        var lines: [String] = []
                        if let window = NSApp.modalWindow ?? NSApp.keyWindow {
                            lines.append("modal=\(NSApp.modalWindow != nil)")
                            func walk(_ view: NSView) {
                                if let field = view as? NSTextField, !field.stringValue.isEmpty {
                                    lines.append("text=\(field.stringValue.replacingOccurrences(of: "\n", with: " ⏎ "))")
                                }
                                view.subviews.forEach(walk)
                            }
                            window.contentView.map(walk)
                        } else {
                            lines.append("ERROR: no modal window")
                        }
                        try? (lines.joined(separator: "\n") + "\n")
                            .write(toFile: out, atomically: true, encoding: .utf8)
                        if NSApp.modalWindow != nil { NSApp.abortModal() }
                    }
                }
                RunLoop.main.add(dumpTimer, forMode: .modalPanel)
                RunLoop.main.add(dumpTimer, forMode: .default)
            case "overwritedlg": showOverwriteDialogForShot()   // screenshot the conflict dialog (F-086)
            case "hotlistmanage": showHotlistManager()   // open the hotlist manager (F-061)
            case "typecolors":                             // open the file-type colour editor (F-032)
                let editor = TypeColorsWindowController(config: arg)
                automationTypeColorEditors.append(editor)
                editor.showWindow(nil); editor.window?.makeKeyAndOrderFront(nil)
            case "syncdemo":                               // syncdemo <left>|<right>[|hidden] (F-192): open sync + compare
                let a = arg.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count >= 2 {
                    let win = SyncWindowController(leftDir: a[0], rightDir: a[1])
                    automationSyncWindows.append(win)
                    win.showWindow()
                    if a.count >= 3, a[2] == "hidden" { win.automationSetIgnoreHidden(true) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { win.compareNow() }
                }
            case "settingspage":                           // open Settings + select a page (F-274)
                // Waits for the window rather than guessing how long it takes. A fixed 0.6 s was
                // enough on the machine this was written on and not in the capture VM, where the
                // window arrived later — `settingsWindow` was still nil, the page was never
                // selected, and the screenshot showed Settings sitting on whatever page it opens
                // with. Silently: there is nothing to fail when the optional is empty.
                showSettings()
                let title = arg
                func selectWhenReady(_ attempt: Int) {
                    guard let window = settingsWindow else {
                        guard attempt < 25 else {          // five seconds, then give up loudly
                            NSLog("[automation] settingspage %@: no settings window", title)
                            return
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            selectWhenReady(attempt + 1)
                        }
                        return
                    }
                    window.showPage(titled: title)
                }
                selectWhenReady(0)
            case "settingspagedump":                       // settingspagedump <out> (F-409)
                try? (settingsWindow?.automationPageDump() ?? "ERROR: no settings window\n")
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "settingsearch":                          // settingsearch <query>|<out> (F-408)
                let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if a.count == 2 {
                    if settingsWindow == nil {
                        showSettings()
                        try? await Task.sleep(nanoseconds: 800_000_000)
                    }
                    let dump = settingsWindow?.automationSearch(a[0]) ?? "ERROR: no settings window\n"
                    try? dump.write(toFile: a[1], atomically: true, encoding: .utf8)
                }
            case "settingsopen":                           // settingsopen <query>|<n>|<out> (F-408)
                let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if a.count == 3 {
                    if settingsWindow == nil {
                        showSettings()
                        try? await Task.sleep(nanoseconds: 800_000_000)
                    }
                    _ = settingsWindow?.automationSearch(a[0])
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    settingsWindow?.automationOpenResult(Int(a[1]) ?? 1)
                    // The reveal lands one run-loop turn later, on purpose: the page has to lay out
                    // before a control can be scrolled to.
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    try? (settingsWindow?.automationRevealState() ?? "ERROR: no settings window\n")
                        .write(toFile: a[2], atomically: true, encoding: .utf8)
                }
            case "settingsdump":                          // settingsdump <out> (F-381)
                // Every string the settings window is showing, the way `sidebardump` reads the
                // sidebar: a plugin's page is a real NSView inside the host's window, so what it
                // displays can be read rather than taken on trust.
                var lines: [String] = []
                func walk(_ view: NSView) {
                    if let field = view as? NSTextField, !field.stringValue.isEmpty {
                        lines.append(field.stringValue)
                    }
                    if let text = view as? NSTextView, !text.string.isEmpty { lines.append(text.string) }
                    if let button = view as? NSButton, !button.title.isEmpty {
                        lines.append("[\(button.state == .on ? "x" : " ")] \(button.title)")
                    }
                    view.subviews.forEach(walk)
                }
                if let root = settingsWindow?.window?.contentView { walk(root) }
                try? (lines.joined(separator: "\n") + "\n")
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "findercomment":                          // findercomment <path>|<text> (F-023): write + read-back
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    FinderComment.write(a[1], to: a[0])
                    NSLog("[automation] finder-comment readback: \(FinderComment.read(a[0]) ?? "<nil>")")
                }
            case "errorlog":   showErrorLogForShot()   // screenshot the operation error log (F-089)
            case "bgcopyverify":                        // bgcopyverify <src>|<dstdir> (F-090)
                // Through the panel's own `startBackgroundCopy`, which is what the F5 dialog calls, so
                // this exercises the real wiring: "verify after copy" applied to foreground copies only,
                // and the background queue is what one picks for the copies worth verifying.
                let v = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if v.count == 2 {
                    activePanel?.startBackgroundCopy(items: [v[0]], dest: v[1], mask: nil,
                                                     onlyNewer: false, queueForLater: false)
                }
            case "bgcopyfail":                          // bgcopyfail <realsrc>|<dstdir> (F-089 background log)
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    let items = [a[0], a[0] + ".missing"]   // one real, one missing → skipped + logged
                    TransferManager.shared.enqueue(.copy(items: items, toDirectory: a[1], options: CopyOptions()),
                                                   title: "Copy demo")
                }
            case "dllist":                                 // dllist <src>|<dstdir> (F-215): enqueue a held download-list job
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    TransferManager.shared.enqueue(.copy(items: [a[0]], toDirectory: a[1], options: CopyOptions()),
                                                   title: "Download \((a[0] as NSString).lastPathComponent)", startHeld: true)
                    showTransferManager()
                }
            case "packplugin":                             // packplugin <archivePath>|<srcDir>|<f1>,<f2> (F-137)
                let a = arg.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 3 {
                    let files = a[2].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    let ok = await activePanel?.resolvePackerPack?(a[0], a[1], files) ?? false
                    NSLog("[automation] packplugin result: \(ok)")
                }
            case "findtab":                                // findtab <index> (F-150): open Find dialog + select an options tab
                showFindFiles()
                let tab = Int(arg) ?? 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.findWindow?.selectTab(tab) }
            case "findrun":                                // findrun <mask> (F-150): open Find + run a search to verify wiring
                showFindFiles()
                let mask = arg.isEmpty ? "*.*" : arg
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.findWindow?.automationStart(mask: mask) }
            case "findsearch":                             // findsearch <mask>|<text> (F-406): a search that records both fields
                let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if a.count == 2 {
                    // Reuse the dialog if one is already up: three searches in *one* dialog is both the
                    // realistic path and the one that shows the dropdown being updated as they run.
                    if findWindow == nil {
                        showFindFiles()
                        try? await Task.sleep(nanoseconds: 700_000_000)
                    }
                    findWindow?.automationStart(mask: a[0], text: a[1])
                }
            case "findtext":                               // findtext <text>|<out> (F-407): type into
                // "Find text" and report which options that turned on — the field is the switch now.
                let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if a.count == 2 {
                    if findWindow == nil {
                        showFindFiles()
                        try? await Task.sleep(nanoseconds: 700_000_000)
                    }
                    findWindow?.automationTypeFindText(a[0])
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    try? (findWindow?.automationOptionsDump() ?? "ERROR: no find window\n")
                        .write(toFile: a[1], atomically: true, encoding: .utf8)
                }
            case "findviewhit":                            // findviewhit <mask>|<text>|<dir>|<out> (F-407)
                // A content search, then View on its first result, then what the viewer's own search
                // holds — the whole point of the feature is that those two are the same search.
                let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if a.count == 4 {
                    if findWindow == nil {
                        showFindFiles()
                        try? await Task.sleep(nanoseconds: 700_000_000)
                    }
                    findWindow?.automationSetDirectory(a[2])
                    findWindow?.automationStart(mask: a[0], text: a[1])
                    try? await Task.sleep(nanoseconds: 2_500_000_000)   // let the walk finish
                    findWindow?.automationViewFirstResult()
                    try? await Task.sleep(nanoseconds: 1_500_000_000)   // let the viewer load + seed
                    try? (currentLister()?.automationSearchState() ?? "ERROR: no viewer\n")
                        .write(toFile: a[3], atomically: true, encoding: .utf8)
                }
            case "listerreload":                           // listerreload <out> (F-407): reload, then dump
                currentLister()?.automationReloadContent()
                try? await Task.sleep(nanoseconds: 500_000_000)
                try? (currentLister()?.automationSearchState() ?? "ERROR: no viewer\n")
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "listerretype":                           // listerretype <text>|<out> (F-407)
                let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if a.count == 2 {
                    currentLister()?.automationRetypeSearch(a[0])
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    try? (currentLister()?.automationSearchState() ?? "ERROR: no viewer\n")
                        .write(toFile: a[1], atomically: true, encoding: .utf8)
                }
            case "findhistory":                            // findhistory <out> (F-406): what the two dropdowns offer
                try? (findWindow?.automationHistoryDump() ?? "ERROR: no find window\n")
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "findhistoryclear":                       // findhistoryclear <out> (F-406): clear, then dump again
                findWindow?.automationClearHistory()
                try? (findWindow?.automationHistoryDump() ?? "ERROR: no find window\n")
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "findcomments":                           // findcomments <mask>|<text>|<dir>|<out> (F-373)
                let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if a.count == 4 {
                    showFindFiles()
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    findWindow?.automationSearchComments(mask: a[0], text: a[1], directory: a[2])
                    try? await Task.sleep(nanoseconds: 2_500_000_000)   // let the walk finish
                    try? (findWindow?.automationResults() ?? "ERROR: no find window\n")
                        .write(toFile: a[3], atomically: true, encoding: .utf8)
                }
            case "findarchives":                           // findarchives <mask>|<text>|<dir>|<out> (F-463)
                let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if a.count == 4 {
                    showFindFiles()
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    findWindow?.automationSearchArchives(mask: a[0], text: a[1], directory: a[2])
                    try? await Task.sleep(nanoseconds: 3_000_000_000)   // let the walk finish
                    // The status line goes into the report too: a search that quietly
                    // skipped an archive is the defect this feature exists to remove, so
                    // "it said so" has to be checkable rather than assumed.
                    let report = "status=" + (findWindow?.automationStatus() ?? "?") + "\n"
                        + "skipped=\(findWindow?.automationSkippedCount() ?? -1)\n"
                        + (findWindow?.automationResults() ?? "ERROR: no find window\n")
                    try? report.write(toFile: a[3], atomically: true, encoding: .utf8)
                }
            case "findfeedarchives":                       // findfeedarchives <mask>|<text>|<dir>|<out> (F-463)
                // Search into archives, then send the results to the panel. A hit inside an
                // archive used to be dropped by ResultsFS without a word, so the panel came
                // up short and said nothing — the dump is how that stays fixed.
                let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if a.count == 4 {
                    showFindFiles()
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    findWindow?.automationSearchArchives(mask: a[0], text: a[1], directory: a[2])
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    findWindow?.automationFeedToListbox()
                    try? await Task.sleep(nanoseconds: 1_500_000_000)   // the mount is a Task
                    await dumpActivePanel(to: a[3])
                }
            case "httpget":                                // httpget <url>|<dir>|<name>[|<sha256>] (F-330)
                let a = arg.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count >= 3 {
                    let sha = a.count >= 4 && a[3] != "hold" ? a[3] : nil
                    // A trailing "hold" queues the job instead of starting it, which is the only way
                    // to get a *waiting* list — and the ▲▼ ordering only exists for waiting jobs.
                    enqueueURLDownload(url: a[0], name: a[2], into: a[1],
                                       options: HTTPDownloadOptions(), expectedSHA256: sha,
                                       held: a.contains("hold"))
                }
            case "dlstart":  TransferManager.shared.startAllQueued()   // F-215: start the whole download list
            case "ctxdump":                                // ctxdump <name>|<outfile> (F-068): dump the context menu tree
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    activePanel?.tableView.focusEntry(named: a[0])
                    let dump = activePanel?.tableView.automationContextMenuDump() ?? ""
                    try? dump.write(toFile: a[1], atomically: true, encoding: .utf8)
                }
            case "rowdrop":                                // rowdrop <row>|<f1>,<f2> (F-067): drop files onto a folder row
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2, let row = Int(a[0]) {
                    let files = a[1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    activePanel?.tableView.automationDropOnRow(row, paths: files, move: false)
                }
            case "zipdelete":                              // zipdelete <zip>|<rel> (F-192): delete an entry from a zip via sync
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    let item = SyncItem(relativePath: a[1], isDirectory: false,
                                        leftSize: nil, leftModified: nil,
                                        rightSize: 0, rightModified: nil)
                    let result = SyncResult(action: .deleteRight, item: item)
                    let errs = await SyncExecutor.execute([result], left: .localDir("/tmp"),
                                                    right: .zip(a[0]), toTrash: false)
                    NSLog("[automation] zipdelete errors: \(errs)")
                }
            case "syncsftp":                               // syncsftp <localdir>|<remotedir>|<out> (F-193)
                await syncOverSFTP(arg)
            case "splitcenter":                            // splitcenter (F-001): as a double-click on the divider
                // The double-click itself cannot be scripted; this is the entry point the split view
                // calls when it sees one, so the scripted run exercises the same path.
                centerDivider()
            case "splitdump":                              // splitdump <out> (F-001): the two panel widths
                let l = Int((leftPanelController?.view.frame.width ?? 0).rounded())
                let r = Int((rightPanelController?.view.frame.width ?? 0).rounded())
                // The verdict, not just the numbers: a window of odd width cannot split into two equal
                // halves, so "centred" is a question with a tolerance and the tolerance belongs here
                // rather than in a scenario trying to express it as a substring. Measured: centring an
                // 1007-point split gives 504 and 503.
                let equal = abs(l - r) <= 2 ? "yes" : "no"
                try? "left=\(l)\nright=\(r)\ndiff=\(abs(l - r))\nequal=\(equal)\n"
                    .write(toFile: arg, atomically: true, encoding: .utf8)
            case "quicklookdump":                          // quicklookdump <out> (F-123)
                // NSApp.windows is the wrong place to look: the Quick Look panel is a system panel and
                // carries no title, so a dump of window titles reported only the main window and the
                // check passed for the wrong reason — it never showed whether the preview opened.
                var report = "exists=\(QLPreviewPanel.sharedPreviewPanelExists())\n"
                if QLPreviewPanel.sharedPreviewPanelExists() {
                    let panel = QLPreviewPanel.shared()
                    report += "visible=\(panel?.isVisible ?? false)\n"
                    let item = panel?.currentPreviewItem?.previewItemURL?.lastPathComponent ?? ""
                    report += "item=\(item)\n"
                }
                try? report.write(toFile: arg, atomically: true, encoding: .utf8)
            case "zipextract":                             // zipextract <zip>|<dest>|<out> (F-131)
                await zipExtract(arg)
            case "subbar":                                 // subbar <barfile> (F-253): descend into a subbar
                runBarButton(BarButton(cmd: arg))
            case "buttondrop":                             // buttondrop <targetdir>|<f1>,<f2> (F-067): drop files on a dir button
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    let files = a[1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    handleButtonDrop(BarButton(cmd: a[0]), files: files)   // a dir-target button
                }
            case "diffdemo":                               // diffdemo <a>|<b> (F-190): open the text diff window
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    let win = DiffWindowController(leftPath: a[0], rightPath: a[1])
                    automationDiffWindows.append(win)
                    win.showWindow()
                }
            case "progressdemo":                           // progressdemo (I04): show a sample transfer progress dialog
                let dlg = ProgressDialog(title: "Copying 128 items…", control: OperationControl())
                automationProgressDialogs.append(dlg)
                dlg.present(over: window)
                dlg.update(OpProgress(filesTotal: 128, filesDone: 47,
                                      bytesTotal: 2_400_000_000, bytesDone: 900_000_000,
                                      currentItem: "vacation.mov", bytesPerSecond: 82_000_000))
            case "help":       NSApplication.shared.showHelp(nil)   // open the Help Book in Help Viewer
            case "automate":   await automateCoreTool(arg)          // drive the Automation Core: automate <tool>|<json>
            case "bardrop":                                // bardrop <path> — as if dropped on free bar space
                // The drag itself cannot be scripted, but everything after it can: this is the
                // exact entry point the bar view calls, so a scripted run exercises the real path.
                addBarButtons(for: [arg], at: 0)
            case "bardump":                               // bardump <out> (F-409): the bar's buttons
                // A file for the guest to wait for, and an assertion of its own: the scenario used to
                // rely on its settle time alone and read the *config* afterwards, so a slow launch left
                // "the button is not in default.bar" — which reads as the drop being broken rather than
                // as the app never having got there.
                try? barButtonsDump().write(toFile: arg, atomically: true, encoding: .utf8)
            case "theme":                                  // theme <id> — select a colour palette (F-2xx)
                // Documentation screenshots of a theme have to be reproducible, and driving the
                // Settings popup by hand is not. Goes through the same sink as the popup, so the
                // screenshot shows exactly what a user gets.
                applyStringOption("Colors.Theme", arg)
            case "presentview": contribPresentSidebarView(viewId: arg, root: NSHomeDirectory())  // mount a plugin sidebar view (verification)
            case "contribcmd": _ = await ContributionRegistry.shared.dispatch(arg, host: self)   // run a plugin contribution command (verification)
            case "quit":       NSApp.terminate(nil)
            default:           NSLog("[automation] unknown verb: \(verb)")
            }
        }
        NSLog("[automation] done")
    }

    /// Diagnostic: present the REAL interactive overwrite-conflict dialog with two
    /// sample files, so a screenshot can confirm the "Append" button (F-086). Both
    /// facts are regular files, so Append is offered.
    private func showOverwriteDialogForShot() {
        // Write real fixtures so the F-086 preview thumbnails render (an image
        // source over a text target).
        let dir = FileManager.default.temporaryDirectory
        let imgURL = dir.appendingPathComponent("pc-owshot.png")
        let txtURL = dir.appendingPathComponent("pc-owshot-old.txt")
        let swatch = NSImage(size: NSSize(width: 96, height: 96))
        swatch.lockFocus(); NSColor.systemOrange.setFill(); NSRect(x: 0, y: 0, width: 96, height: 96).fill()
        NSColor.white.setFill(); NSRect(x: 24, y: 24, width: 48, height: 48).fill(); swatch.unlockFocus()
        if let tiff = swatch.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: imgURL) }
        try? "old contents".data(using: .utf8)?.write(to: txtURL)

        let src = FileFacts(path: imgURL.path, name: "banner.png", size: 2048,
                            modified: Date(timeIntervalSince1970: 1_720_000_000), isDirectory: false)
        let dst = FileFacts(path: txtURL.path, name: "banner.png", size: 1024,
                            modified: Date(timeIntervalSince1970: 1_700_000_000), isDirectory: false)
        let resolver = InteractiveResolver(parentWindow: window)
        Task { _ = await resolver.resolveOverwrite(source: src, target: dst) }
    }

    /// Diagnostic: present the REAL end-of-operation error log (F-089) with sample
    /// skipped-file entries so a screenshot can confirm the summary window.
    private func showErrorLogForShot() {
        let entries = [
            (path: "/Users/me/src/locked.bin", message: "writeFailed(\"/Volumes/Backup/locked.bin\")"),
            (path: "/Users/me/src/secret.key", message: "readFailed(\"/Users/me/src/secret.key\")"),
            (path: "/Users/me/src/huge.iso", message: "cannotCreateFile(\"/Volumes/Backup/huge.iso\")"),
        ]
        ErrorLogWindowController.present(over: window,
                                         summary: String(localized: "\(entries.count) item(s) were skipped due to errors."),
                                         entries: entries)
    }

    /// Diagnostic: run the REAL symbol-outline pipeline on a source file and write the
    /// resulting tree (kind/line/name, flagging blank names) to a file.
    /// Usage: `symbols <srcFile> <outFile>`.
    private func dumpSymbols(_ arg: String) {
        let a = arg.split(separator: " ", maxSplits: 1).map(String.init)
        guard a.count == 2 else { NSLog("[automation] symbols needs <src> <out>"); return }
        let src = a[0], outFile = a[1]
        let ext = (src as NSString).pathExtension.lowercased()
        guard let text = try? String(contentsOfFile: src, encoding: .utf8) else {
            try? "ERROR: cannot read \(src)\n".write(toFile: outFile, atomically: true, encoding: .utf8)
            return
        }
        // The same three sources the sidebar chooses between, in the same order (F-405). Asking only
        // tree-sitter reported "unsupported ext" for every language whose outline comes from a scanner —
        // Swift included, which is the file type this app is written in.
        let roots: [SymbolNode]
        let source: String
        if let h = SymbolOutline.handles(ext: ext) {
            roots = SymbolOutline.parse(text, query: h.query, language: h.language)
            source = "tree-sitter"
        } else if StructureOutline.supports(ext: ext) {
            roots = StructureOutline.parse(text, ext: ext)
            source = "structure"
        } else if DeclarationOutline.supports(ext: ext) {
            roots = DeclarationOutline.parse(text, ext: ext)
            source = "declarations"
        } else {
            try? "ERROR: no outline for .\(ext)\n".write(toFile: outFile, atomically: true, encoding: .utf8)
            return
        }
        var lines: [String] = ["source=\(source)"]
        func walk(_ nodes: [SymbolNode], _ depth: Int) {
            for n in nodes {
                let blank = n.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                lines.append("\(blank ? "BLANK!" : "  ok  ")\(String(repeating: "  ", count: depth))[\(n.kind)] line=\(n.line) name=[\(n.name)]")
                walk(n.children, depth + 1)
            }
        }
        walk(roots, 0)
        try? (lines.joined(separator: "\n") + "\n").write(toFile: outFile, atomically: true, encoding: .utf8)
        NSLog("[automation] symbols of \(src) → \(outFile) (\(lines.count) rows)")
    }

    /// Open the built-in viewer (Lister) directly on a file, for visual checks.
    /// `view <file>` opens normally; `view <file> wrap` forces word-wrap on;
    /// `view <file> binary` forces the binary/fixed-width mode.
    /// Open (or reuse) a hex editor on `path`, key and on screen so its own menu bar is installed.
    private func openHexEditorForAutomation(path: String) -> HexEditorWindowController {
        if let existing = automationHexEditors.last(where: { $0.window?.isVisible == true }) { return existing }
        let wc = HexEditorWindowController(path: path)
        automationHexEditors.append(wc)
        wc.showWindow()
        return wc
    }

    private func openViewer(_ arg: String) {
        // Usage: view <file> [wrap|binary] [search:<term>]
        let tokens = arg.split(separator: " ").map(String.init)
        guard let path = tokens.first else { return }
        Task { @MainActor in
            let plugins = await self.makeListerPlugins()   // load PLX listers so plugin modes work (F-119)
            let lc = ListerWindowController(files: [path], startIndex: 0, plugins: plugins)
            automationListers.append(lc)
            lc.showWindow(nil)
            lc.window?.makeKeyAndOrderFront(nil)
            for token in tokens.dropFirst() {
                if token == "wrap" { lc.automationEnableWrap() }
                else if token == "binary" { lc.automationForceBinary() }
                else if token.hasPrefix("hex:") { lc.automationForceHex(bytesPerRow: Int(token.dropFirst(4)) ?? 16) }
                else if token.hasPrefix("search:") { lc.applyInitialSearch(String(token.dropFirst("search:".count))) }
            }
            NSLog("[automation] view repr items: \(lc.automationReprItems().joined(separator: ", "))")
        }
    }

    /// Dump the top-level menus and their item titles (+ represented command) to a
    /// file, so a driver can assert menu structure/order without opening menus.
    private func dumpMenu(_ file: String) {
        guard let main = NSApp.mainMenu else { return }
        var lines: [String] = []
        for top in main.items {
            guard let sub = top.submenu else { continue }
            lines.append("# \(sub.title)")
            for it in sub.items {
                if it.isSeparatorItem { lines.append("  ----"); continue }
                // The key equivalent belongs in the dump: a shortcut audit that reads the source
                // instead of the built menu is auditing what was meant, not what is bound (I19 T06).
                let key = it.keyEquivalent.isEmpty ? "" : "  key=" + Self.describe(
                    key: it.keyEquivalent, mask: it.keyEquivalentModifierMask)
                let cmd = (it.representedObject as? String).map { "  [\($0)]" } ?? ""
                lines.append("  \(it.title)\(cmd)\(key)\(it.isEnabled ? "" : "  disabled")")
            }
        }
        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] menudump → \(file)")
    }

    /// Invoke a main-menu item the way a click does — through the item's own target and
    /// action — and report what was found: `menuclick <cm_/em_ name>|<outfile>`.
    ///
    /// `menudump` proves an item exists, carries a command and is enabled; it cannot prove
    /// the item is wired to the dispatcher that can run that command. That was the defect
    /// (F-257): an `em_` item in a user `.mnu` went to the cm_ registry, so it looked
    /// perfect in every dump and did nothing at all when clicked. Only sending the action
    /// tests it.
    private func clickMenuItem(_ arg: String) {
        let parts = arg.split(separator: "|", maxSplits: 1).map(String.init)
        let wanted = parts.first ?? ""
        var report = "menuclick \(wanted)\n"
        if let main = NSApp.mainMenu, let item = Self.findMenuItem(command: wanted, in: main) {
            report += "found=1\ntitle=\(item.title)\nenabled=\(item.isEnabled ? 1 : 0)\n"
            if item.isEnabled, let action = item.action {
                report += "sent=\(NSApp.sendAction(action, to: item.target, from: item) ? 1 : 0)\n"
            } else {
                report += "sent=0\n"
            }
        } else {
            report += "found=0\n"
        }
        if parts.count == 2 { try? report.write(toFile: parts[1], atomically: true, encoding: .utf8) }
        NSLog("[automation] menuclick \(wanted)")
    }

    /// The first item anywhere in `menu` whose represented command is `command`.
    private static func findMenuItem(command: String, in menu: NSMenu) -> NSMenuItem? {
        for item in menu.items {
            if (item.representedObject as? String) == command { return item }
            if let submenu = item.submenu, let found = findMenuItem(command: command, in: submenu) {
                return found
            }
        }
        return nil
    }

    /// A shortcut in the scheme files' notation (C=Ctrl A=Alt S=Shift W=Cmd), so the menu dump and the
    /// keymap can be compared without a translation table in the middle.
    static func describe(key: String, mask: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if mask.contains(.control) { parts.append("C") }
        if mask.contains(.option) { parts.append("A") }
        if mask.contains(.shift) { parts.append("S") }
        if mask.contains(.command) { parts.append("W") }
        // An uppercase letter as a key equivalent means Shift, whether or not the mask says so.
        var token = key
        if token.count == 1, let ch = token.first, ch.isUppercase {
            if !parts.contains("S") { parts.append("S") }
            token = token.lowercased()
        }
        let named: [String: String] = ["\u{1b}": "ESC", "\r": "RETURN", "\t": "TAB",
                                      "\u{8}": "BACKSPACE", "\u{7f}": "DELETE", " ": "SPACE",
                                      "\u{f700}": "UP", "\u{f701}": "DOWN", "\u{f702}": "LEFT",
                                      "\u{f703}": "RIGHT", "\u{f704}": "F1", "\u{f705}": "F2",
                                      "\u{f706}": "F3", "\u{f707}": "F4", "\u{f708}": "F5",
                                      "\u{f709}": "F6", "\u{f70a}": "F7", "\u{f70b}": "F8",
                                      "\u{f70c}": "F9", "\u{f70d}": "F10", "\u{f70e}": "F11",
                                      "\u{f70f}": "F12"]
        return (parts + [named[token] ?? token.uppercased()]).joined(separator: "+")
    }

    /// Write what pressing Tab reaches in the key window, and what it cannot (I19 T06).
    ///
    /// A dialog can be perfectly labelled for a screen reader and still be unusable without a mouse: an
    /// element that is not in the key-view loop is never focused, so its label is never read either.
    /// Only the loop the running window actually has can answer that, which is why this is asked of the
    /// app rather than reasoned about from the layout code.
    private func dumpKeyLoop(_ file: String) {
        // A modal window is the only one the user can touch while it is up, so it is the one to report.
        // Front to back, not `windows` order. `windows` is whatever order AppKit happens to hold them
        // in, so when nothing is key — which happens in an automated session more often than in front
        // of a person — this reported the *main* window while a dialog stood open in front of it, and
        // then complained that the dialog's controls were missing from it. `orderedWindows` is the
        // order they are stacked on screen, so its first visible entry is the one being looked at.
        guard let window = NSApp.modalWindow ?? NSApp.keyWindow
                ?? NSApp.orderedWindows.first(where: { $0.isVisible }) else {
            NSLog("[automation] keyloop: no visible window")
            return
        }
        // Which control has focus right now, resolved through the field editor. A text field that is
        // being edited hands first-responder status to a shared NSTextView and *itself* then reports
        // `acceptsFirstResponder == false` — so without this the focused field looks like a control that
        // refuses focus, and its field editor looks like an unreachable stray view. Both readings are
        // wrong, and the first version of this dump made exactly that mistake.
        let fieldEditor = (window.firstResponder as? NSTextView).flatMap { $0.isFieldEditor ? $0 : nil }
        let editing = fieldEditor?.delegate as? NSView
        var lines = ["window: \(window.title)",
                     "fullKeyboardAccess: \(NSApp.isFullKeyboardAccessEnabled)",
                     "focused: " + (editing.map { Self.describe($0) + " (editing)" }
                                    ?? (window.firstResponder as? NSView).map(Self.describe)
                                    ?? String(describing: type(of: window.firstResponder as Any))),
                     // The suspected cause of a loop that reaches nothing: for a window built in code
                     // this is false, so AppKit never links the controls and only accidents are reachable.
                     "autorecalculatesKeyViewLoop: \(window.autorecalculatesKeyViewLoop)",
                     "initialFirstResponder: \(window.initialFirstResponder.map { String(describing: type(of: $0)) } ?? "nil")"]

        // Every view that says it can take focus, in tree order — plus, for the ones that say they
        // cannot, why. "It is not in the loop" and "it refuses focus" are different defects with
        // different fixes, and guessing which one it is has already cost time here.
        var candidates: [NSView] = []
        var refusers: [String] = []
        func collect(_ view: NSView) {
            if view.canBecomeKeyView {
                candidates.append(view)
            } else if view === editing {
                // Focused, hence "refusing": it is being edited this very moment.
                candidates.append(view)
            } else if Self.isInteractive(view) {
                let control = view as? NSControl
                refusers.append("\(Self.describe(view)) "
                    + "accepts=\(view.acceptsFirstResponder) hidden=\(view.isHidden) "
                    + "enabled=\(control?.isEnabled ?? true) "
                    + "refuses=\(control?.refusesFirstResponder ?? false)")
            }
            view.subviews.forEach(collect)
        }
        if let content = window.contentView { collect(content) }
        lines.append("focusRefused: \(refusers.count)")
        for entry in refusers { lines.append("  REFUSES: \(entry)") }

        // The loop as AppKit would walk it.
        var visited: [NSView] = []
        var cursor = (window.initialFirstResponder ?? (window.firstResponder as? NSView))
            ?? candidates.first
        var guardCount = 0
        while let view = cursor, guardCount < 200 {
            if visited.contains(where: { $0 === view }) { break }
            visited.append(view)
            lines.append("  tab[\(visited.count)]: \(Self.describe(view))")
            cursor = view.nextValidKeyView
            guardCount += 1
        }
        lines.append("loopClosed: \(cursor != nil)")

        // A composite control is reached through its owner: focus lands on the NSTabView and the arrow
        // keys drive the segmented control AppKit builds inside it, so counting that segmented control as
        // unreachable is a false alarm — and a report with false alarms in it gets ignored. Only an
        // ancestor that is itself a control counts, or the content view would make everything "reachable".
        func reachable(_ candidate: NSView) -> Bool {
            if visited.contains(where: { $0 === candidate }) { return true }
            var parent = candidate.superview
            while let view = parent {
                if view is NSControl || view is NSTabView, visited.contains(where: { $0 === view }) {
                    return true
                }
                parent = view.superview
            }
            return false
        }
        var missed = candidates.filter { !reachable($0) }
        if let editing, !visited.contains(where: { $0 === editing }) {
            // A control that holds focus is reachable by definition — Tab simply starts from it.
            missed.removeAll { $0 === editing }
        }
        missed.removeAll { $0 === fieldEditor }
        lines.append("unreachable: \(missed.count)")
        for view in missed { lines.append("  MISSED: \(Self.describe(view))") }
        // A focusable control with nothing to announce is the other half of the same problem. Scaffolding
        // — a container, a clip view, a scroller — legitimately has none, so only interactive views count.
        let unlabelled = visited.filter {
            Self.isInteractive($0) && ($0.accessibilityLabel() ?? "").isEmpty && Self.title(of: $0).isEmpty
        }
        lines.append("unlabelled: \(unlabelled.count)")
        for view in unlabelled { lines.append("  UNLABELLED: \(String(describing: type(of: view)))") }

        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] keyloop → \(file) (\(visited.count) stops, \(missed.count) unreachable)")
    }

    /// Whether a screen reader would treat this view as something to operate.
    ///
    /// A static label is an `NSTextField` that is neither editable nor selectable — it is not a control
    /// that refuses focus, it is a caption, and reporting it as a defect only trains people to ignore
    /// the report.
    private static func isInteractive(_ view: NSView) -> Bool {
        // Scrollers are operated by role and value, not by a name; AppKit's own do not carry labels and
        // do not need any.
        if view is NSScroller { return false }
        if let field = view as? NSTextField { return field.isEditable || field.isSelectable }
        if view is NSTextView { return true }
        if view is NSTableView { return true }
        return view is NSControl
    }

    /// A control's own words: its title, its placeholder, or the label it exposes.
    private static func title(of view: NSView) -> String {
        if let button = view as? NSButton, !button.title.isEmpty { return button.title }
        if let field = view as? NSTextField {
            if !field.stringValue.isEmpty { return field.stringValue }
            if let placeholder = field.placeholderString, !placeholder.isEmpty { return placeholder }
        }
        if let popup = view as? NSPopUpButton { return popup.titleOfSelectedItem ?? "" }
        return ""
    }

    private static func describe(_ view: NSView) -> String {
        let kind = String(describing: type(of: view))
        let label = view.accessibilityLabel() ?? ""
        let own = title(of: view)
        let words = [label, own].filter { !$0.isEmpty }.joined(separator: " / ")
        return words.isEmpty ? kind : "\(kind) | \(words)"
    }

    /// Walk the key window's accessibility tree and write what a screen reader would find.
    ///
    /// Asked of the app itself rather than through an accessibility *client*: a client needs the
    /// Accessibility permission, which cannot be granted unattended in a fresh VM, while a process may
    /// always inspect its own tree. That makes "is the drive bar reachable" checkable in the harness
    /// instead of only by hand — which matters, because the failure mode for a hand-drawn control is
    /// not a wrong label but no element at all, and nothing on screen looks different either way.
    ///
    /// Typed calls, not KVC. The first version asked for "accessibilityRole" by key and reflected on a
    /// selector, and it crashed the app inside the automation script — NSView does not answer those
    /// through KVC, and a reflected cast to a Role was never going to be sound.
    private func dumpAccessibility(_ file: String) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
              let root = window.contentView else {
            NSLog("[automation] a11ydump: no visible window")
            return
        }
        var lines = ["window: \(window.title)"]
        // Cycle detection over *views* only, and holding them. Keying a set on ObjectIdentifier while
        // walking freshly created elements was wrong in a way the first dump showed straight away: the
        // hand-drawn chips are built on demand and released as the walk moves on, so the allocator
        // reused an address and the second drive bar's "Favorites" chip was mistaken for one already
        // visited — it silently vanished from the report. Views live as long as the window, so their
        // identity means something.
        var seenViews: [NSView] = []

        func describe(_ node: Any, depth: Int) {
            guard depth < 12 else { return }
            let role: NSAccessibility.Role?
            let label: String?
            let value: Any?
            let children: [Any]
            switch node {
            case let view as NSView:
                role = view.accessibilityRole()
                label = view.accessibilityLabel()
                value = view.accessibilityValue()
                children = view.accessibilityChildren() ?? []
            case let element as NSAccessibilityElement:
                role = element.accessibilityRole()
                label = element.accessibilityLabel()
                value = element.accessibilityValue()
                children = element.accessibilityChildren() ?? []
            default:
                return
            }
            // A view tree can be a graph; visiting one twice would recurse until the stack runs out.
            if let view = node as? NSView {
                guard !seenViews.contains(where: { $0 === view }) else { return }
                seenViews.append(view)
            }
            // Only rows that say something: an unnamed group is scaffolding, not content.
            if role != nil || !(label ?? "").isEmpty {
                var row = String(repeating: "  ", count: depth) + (role?.rawValue ?? "?")
                if let label, !label.isEmpty { row += " | \(label)" }
                if let value, !(value is NSNull) { row += " = \(value)" }
                lines.append(row)
            }
            for child in children { describe(child, depth: depth + 1) }
        }

        describe(root, depth: 0)
        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] a11ydump → \(file) (\(lines.count) rows)")
    }

    /// Open the real editor on a file, let its sidebar parse, and dump the strings
    /// actually rendered into the outline rows (live NSOutlineView path).
    /// Usage: `editdump <srcFile> <outFile>`.
    private func editDump(_ arg: String) async {
        let a = arg.split(separator: " ", maxSplits: 1).map(String.init)
        guard a.count == 2 else { NSLog("[automation] editdump needs <src> <out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        win.automationShowSidebar()                          // visible during the natural load
        try? await Task.sleep(nanoseconds: 1_400_000_000)   // let the background parse + reload settle
        let cells = win.automationRenderedSymbols()          // read live state, no forced reload
        var text = "count=\(cells.count)\n" + cells.enumerated().map { i, s in
            let blank = s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return "\(blank ? "BLANK!" : "  ok  ")[\(i)] \(s)"
        }.joined(separator: "\n") + "\n"
        // The status line as it stands after loading — the caret is at the top, so the breadcrumb must
        // describe the top — and then the path for a caret placed in the middle of the document.
        text += "status=\(win.automationStatusLine())\n"
        text += "crumb@0=\(win.automationBreadcrumb(at: 0))\n"
        let middle = ((try? String(contentsOfFile: a[0], encoding: .utf8))?.utf16.count ?? 0) / 2
        text += "crumb@mid=\(win.automationBreadcrumb(at: middle))\n"
        try? text.write(toFile: a[1], atomically: true, encoding: .utf8)
        NSLog("[automation] editdump \(cells.count) rendered rows → \(a[1])")
    }

    /// Open `src` in the editor, run the structure check, and report it: `editvalidate <src>|<out>`.
    private func editValidate(_ arg: String) async {
        let a = arg.split(separator: "|", maxSplits: 1).map(String.init)
        guard a.count == 2 else { NSLog("[automation] editvalidate needs <src>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        let report = win.automationValidate()
        try? report.write(toFile: a[1], atomically: true, encoding: .utf8)
        NSLog("[automation] editvalidate → \(a[1])")
    }

    /// Open `src` in the editor, press Format, and report the result: `editformat <src>|<out>`.
    ///
    /// The status line is part of the report because it names the formatter that ran. For a `.jsonl` file
    /// the answer that matters is *which* formatter: the JSON one would produce a valid JSON document that
    /// is no longer JSON Lines, and a diff of the text alone would not say which of the two happened.
    private func editFormat(_ arg: String) async {
        let a = arg.split(separator: "|", maxSplits: 1).map(String.init)
        guard a.count == 2 else { NSLog("[automation] editformat needs <src>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 1_200_000_000)   // let the load + highlight settle
        let report = win.automationFormat()
        try? report.write(toFile: a[1], atomically: true, encoding: .utf8)
        NSLog("[automation] editformat → \(a[1])")
    }

    /// Download a file over a real SFTP connection twice: once whole, then — after truncating the local
    /// copy to `partial` bytes — again with resume, reporting what each pass transferred (F-366).
    ///
    /// The second pass is the point: `written` must be the tail only and `resumedAt` the truncation point.
    /// Whether the *result* is correct is not judged here at all; the harness compares the file with the
    /// original over ssh, because a downloader reporting on its own output is no witness.
    private func sftpGet(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 4, let partial = Int64(a[3]) else {
            NSLog("[automation] sftpget needs <remote>|<local>|<out>|<partialBytes>"); return
        }
        let session = SFTPSession()
        let destination = URL(fileURLWithPath: a[1])
        var report = ""
        do {
            // The harness answers the first-connect question itself: there is no one at the
            // keyboard, and the host is this machine.
            try await session.connect(host: "127.0.0.1", port: 22, user: NSUserName(),
                                      password: nil, keyFile: nil, keyPassphrase: nil,
                                      trustingNewHostKey: true)
            let fs = SFTPFileSystem(session: session)
            let path = VFSPath(filesystemId: "sftp", path: a[0])
            let whole = try await fs.downloadFile(path, to: destination, resume: false)
            report += "full=\(whole.written)\n"
            // Simulate a transfer that stopped: keep the first `partial` bytes and ask for the rest.
            let handle = try FileHandle(forWritingTo: destination)
            try handle.truncate(atOffset: UInt64(partial))
            try handle.close()
            let resumed = try await fs.downloadFile(path, to: destination, resume: true)
            report += "resumedAt=\(resumed.resumedAt)\ntail=\(resumed.written)\n"
        } catch {
            report += "error=\(error)\n"
        }
        await session.close()
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] sftpget → \(a[2])")
    }

    /// Upload a file over a real SFTP connection, then truncate the remote copy to `partial` bytes and
    /// upload again with resume — reporting what each pass sent (F-212).
    ///
    /// Truncating the *remote* file is what an interrupted upload leaves behind. Whether the result is
    /// correct is decided by `cmp` in the harness, not here.
    private func sftpPut(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 4, let partial = Int64(a[3]) else {
            NSLog("[automation] sftpput needs <local>|<remote>|<out>|<partialBytes>"); return
        }
        let session = SFTPSession()
        var report = ""
        do {
            // The harness answers the first-connect question itself: there is no one at the
            // keyboard, and the host is this machine.
            try await session.connect(host: "127.0.0.1", port: 22, user: NSUserName(),
                                      password: nil, keyFile: nil, keyPassphrase: nil,
                                      trustingNewHostKey: true)
            let fs = SFTPFileSystem(session: session)
            let source = URL(fileURLWithPath: a[0])
            let remote = VFSPath(filesystemId: "sftp", path: a[1])
            let whole = try await fs.uploadFile(source, to: remote, resume: false)
            report += "full=\(whole.written)\n"
            // Cut the remote copy back: the state an upload that stopped halfway leaves.
            let cut = try await session.read(a[1]).prefix(Int(partial))
            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent("pc-cut-\(UUID().uuidString)")
            try Data(cut).write(to: temporary)
            _ = try await session.upload(temporary, to: a[1], from: 0)
            try? FileManager.default.removeItem(at: temporary)
            let resumed = try await fs.uploadFile(source, to: remote, resume: true)
            report += "resumedAt=\(resumed.resumedAt)\ntail=\(resumed.written)\n"
        } catch {
            report += "error=\(error)\n"
        }
        await session.close()
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] sftpput → \(a[2])")
    }

    /// Change a file's mode over a real SFTP connection and report what the server says afterwards.
    ///
    /// Against the guest's own sshd, authenticated by key — `SFTPSession` finds ~/.ssh/id_ed25519 itself,
    /// so no password appears anywhere in the harness. The point is the read-back: an implementation that
    /// accepts the request and discards it (which is what SFTP did) passes every other kind of check.
    private func sftpChmod(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 3, let mode = UInt16(a[1], radix: 8) else {
            NSLog("[automation] sftpchmod needs <path>|<octal>|<out>"); return
        }
        let session = SFTPSession()
        var report = "requested=\(String(mode, radix: 8))\n"
        do {
            // The harness answers the first-connect question itself: there is no one at the
            // keyboard, and the host is this machine.
            try await session.connect(host: "127.0.0.1", port: 22, user: NSUserName(),
                                      password: nil, keyFile: nil, keyPassphrase: nil,
                                      trustingNewHostKey: true)
            // Only the change is done here. What the mode *is* afterwards is read by the harness with
            // `stat` over ssh — an independent witness, because a wrapper reporting on its own write is
            // exactly the kind of evidence that let the empty implementation pass for so long.
            try await session.setAttributes(a[0], mode: mode)
            report += "applied=ok\n"
        } catch {
            report += "error=\(error)\n"
        }
        await session.close()
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] sftpchmod → \(a[2])")
    }

    /// Synchronise a local folder with a folder on the guest's own sshd, over a real SFTP connection.
    ///
    /// The point is the connection: the unit tests drive the remote side through LocalFS, which is a
    /// genuine VirtualFileSystem and exercises the same code, but says nothing about whether a server
    /// at the other end of a socket behaves — listing formats, a write stream that has to be closed
    /// before the file exists, a path that is not the local one.
    ///
    /// The report says what the sync decided and what it did. Whether the file is really on the server
    /// is asked of `ssh` afterwards, by the harness: a wrapper reporting on its own write is not
    /// evidence.
    private func syncOverSFTP(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 3 else { NSLog("[automation] syncsftp needs <localdir>|<remotedir>|<out>"); return }
        let (localDir, remoteDir, out) = (a[0], a[1], a[2])
        var report = ""
        let session = SFTPSession()
        do {
            // The harness answers the first-connect question itself: there is no one at the
            // keyboard, and the host is this machine.
            try await session.connect(host: "127.0.0.1", port: 22, user: NSUserName(),
                                      password: nil, keyFile: nil, keyPassphrase: nil,
                                      trustingNewHostKey: true)
            let fs = SFTPFileSystem(session: session)
            let right = SyncSide.remote(RemoteSyncSource(fs: fs, path: remoteDir))
            let items = await SyncScanner.scan(left: .localDir(localDir), right: right,
                                               mask: "*.*", withSubdirs: true, byContent: false)
            report += "compared=\(items.count)\n"
            let results = SyncModel.classify(items, options: SyncOptions())
            let actionable = results.filter { $0.action != .none }
            report += "actions=" + actionable.map { "\($0.item.relativePath):\($0.action)" }
                .sorted().joined(separator: ",") + "\n"
            let errors = await SyncExecutor.execute(actionable, left: .localDir(localDir),
                                                    right: right, toTrash: false)
            report += "errors=" + (errors.isEmpty ? "none" : errors.joined(separator: "; ")) + "\n"
        } catch {
            report += "error=\(error)\n"
        }
        await session.close()
        try? report.write(toFile: out, atomically: true, encoding: .utf8)
        NSLog("[automation] syncsftp → \(out)")
    }

    /// Enter `zip` in the panel and copy its whole root out to `dest`, reporting what landed where.
    ///
    /// This drives `extractItems` — the panel's own extract walk, the one the archive extractor's unit
    /// tests do not reach, because nothing in the test suite constructs a MainWindowController. A
    /// crafted member called "../escaped.txt" arrives in the listing as an entry named exactly ".." of
    /// kind `.directory`, and the walk used to create `<dest>/..` — the parent folder — and write the
    /// payload into it.
    ///
    /// The report names what is in `dest` *and* what is in its parent, because the failure is not an
    /// error: the extraction reports success either way, and the only difference is a file appearing one
    /// level up. The parent listing is the witness, so the scenario asserts on where things are rather
    /// than on the walk's own account of itself.
    private func zipExtract(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 3 else { NSLog("[automation] zipextract needs <zip>|<dest>|<out>"); return }
        let (zip, dest, out) = (a[0], a[1], a[2])
        guard let panel = activePanel else { NSLog("[automation] zipextract: no active panel"); return }
        try? FileManager.default.createDirectory(atPath: dest, withIntermediateDirectories: true)

        await panel.enterArchive(zip)
        let fs = panel.currentFileSystem
        var names: [String] = []
        do {
            for try await batch in fs.list(VFSPath(filesystemId: fs.scheme, path: "/")) {
                names += batch.entries.map { "/" + $0.name }
            }
        } catch {
            NSLog("[automation] zipextract list failed: \(error)")
        }
        var report = "listed=" + names.map { ($0 as NSString).lastPathComponent }.sorted()
            .joined(separator: ",") + "\n"

        await panel.extractItems(names, to: dest)

        let fm = FileManager.default
        let parent = (dest as NSString).deletingLastPathComponent
        let destName = (dest as NSString).lastPathComponent
        report += "inside=" + ((try? fm.contentsOfDirectory(atPath: dest)) ?? []).sorted()
            .joined(separator: ",") + "\n"
        report += "parent=" + ((try? fm.contentsOfDirectory(atPath: parent)) ?? [])
            .filter { $0 != destName }.sorted().joined(separator: ",") + "\n"
        try? report.write(toFile: out, atomically: true, encoding: .utf8)
        NSLog("[automation] zipextract → \(out)")
    }

    /// Open `src` in the editor, pipe the whole document through `command`, and write what the editor
    /// shows afterwards to `out` (F-356). The window is left open so the screenshot shows the result.
    private func editFilter(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 3 else { NSLog("[automation] editfilter needs <src>|<command>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 800_000_000)   // let the load and the first highlight settle
        let report = await win.automationFilter(a[1])
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] editfilter \(a[1]) → \(a[2])")
    }

    /// Open `src` in the editor, run every built-in line operation, and report the result (F-359).
    /// Open `src` in the editor and run a pattern search or a Replace All over it (F-151).
    private func editRegex(_ arg: String) async {
        let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard a.count == 5 else { NSLog("[automation] editregex needs <src>|<pat>|<repl>|<all>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 800_000_000)
        let report = win.automationRegex(pattern: a[1], replacement: a[2], caseInsensitive: false,
                                         inSelection: false, replaceAll: a[3] == "1")
        try? report.write(toFile: a[4], atomically: true, encoding: .utf8)
        NSLog("[automation] editregex \(a[1]) → \(a[4])")
    }

    private func editLines(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 2 else { NSLog("[automation] editlines needs <src>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 800_000_000)
        let report = win.automationLineOperations()
        try? report.write(toFile: a[1], atomically: true, encoding: .utf8)
        NSLog("[automation] editlines → \(a[1])")
    }

    /// Open `src` in the editor, type `text` into it and save, then report the folder's answer (F-387).
    private func editSave(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 3 else { NSLog("[automation] editsave needs <src>|<text>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 800_000_000)   // let the load and the first highlight settle
        let report = win.automationSaveAfterTyping(a[1])
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] editsave → \(a[2])")
    }

    /// Open `src`, type, Save As to `dst`, and report that the document *moved* there.
    private func editSaveAs(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 4 else { NSLog("[automation] editsaveas needs <src>|<text>|<dst>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 800_000_000)
        let report = win.automationSaveAs(typing: a[1], to: a[2])
        try? report.write(toFile: a[3], atomically: true, encoding: .utf8)
        NSLog("[automation] editsaveas → \(a[3])")
    }

    /// Open `src`, put the caret on `needle`, and drive the Structure menu (F-369).
    ///
    /// Usage: `editstruct <src>|<needle>|<out>`. The sidebar is shown so the screenshot proves the tree
    /// and the navigation belong to the same document.
    private func editStructure(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 3 else { NSLog("[automation] editstruct needs <src>|<needle>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        win.automationShowSidebar()
        try? await Task.sleep(nanoseconds: 1_400_000_000)      // let the background parse settle
        let report = win.automationStructure(startAt: a[1])
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] editstruct → \(a[2])")
    }

    /// Put `text` into the first editable text field of `root` and commit it as ending an edit does.
    private func automationCommitFirstEditableField(in root: NSView, text: String) -> String {
        func find(_ view: NSView) -> NSTextField? {
            if let field = view as? NSTextField, field.isEditable, !field.isHidden { return field }
            for sub in view.subviews { if let hit = find(sub) { return hit } }
            return nil
        }
        guard let field = find(root) else { return "no editable field" }
        field.stringValue = text
        // The delegate acts on the end of editing, not on every keystroke, so that is what is simulated.
        field.delegate?.controlTextDidEndEditing?(
            Notification(name: NSControl.textDidEndEditingNotification, object: field))
        return "committed"
    }

    /// Report the bottom dock and, more to the point, the layout seam it sits in (F-381).
    ///
    /// "Is the dock visible" is the cheap question and it can pass while the window is wrong. The dock
    /// was inserted between the file panels and the command line by splitting one constraint
    /// (`commandLine.top == splitView.bottom`) into three, so what can actually break is the *stack*:
    /// a dock that opens without the panels giving up the room overlaps them, and a dock that does not
    /// push the command line down hides it behind itself. Neither shows up in a visibility flag.
    ///
    /// So the four edges are measured against each other and the verdict is written next to them. The
    /// numbers stay in the dump because a verdict alone tells you nothing about *how* it went wrong.
    private func dumpBottomDock(_ file: String) {
        guard let dock = bottomDockForAutomation() else {
            try? "ERROR: no dock\n".write(toFile: file, atomically: true, encoding: .utf8)
            return
        }
        let visible = bottomDockVisible
        // AppKit's window coordinates grow upward, so going down the window is going *down* in y:
        // the split view's bottom edge, then the divider, then the dock, then the command line's top.
        let splitBottom = splitViewFrameForAutomation().minY
        let dockTop = dock.frame.maxY
        let dockBottom = dock.frame.minY
        let commandTop = commandLineFrameForAutomation().maxY
        let dividerGap = splitBottom - dockTop        // the resize handle lives here
        let overlap = dockBottom - commandTop         // 0 when they meet exactly
        // A closed dock is zero-height and the two gaps collapse; an open one must be exactly as tall
        // as it claims, with the divider above it and the command line immediately below.
        let stacked = abs(overlap) <= 1
            && abs(dividerGap - (visible ? DockResizeHandle.height : 0)) <= 1
            && (!visible || dock.frame.height >= BottomDockView.minHeight)
        var out = "visible=\(visible)\n"
        out += "height=\(Int(dock.frame.height.rounded()))\n"
        out += "dividerGap=\(Int(dividerGap.rounded()))\n"
        out += "overlap=\(Int(overlap.rounded()))\n"
        out += "stacked=\(stacked ? "yes" : "no")\n"
        out += "panels=\(dock.providerIds.joined(separator: ","))\n"
        out += "selected=\(dock.selectedProviderId ?? "<none>")\n"
        // Is the selected panel's view actually *in* the dock? A panel can be listed, selected and
        // still draw nothing, because moving a view out of a container took it back out of whichever
        // container had just adopted it (F-388) — a state the labels below cannot distinguish from a
        // plugin that renders nothing, and the screenshot cannot distinguish from an empty dock.
        let content = dock.visibleContentView
        out += "attached=\(content == nil ? "none" : (content?.isDescendant(of: dock) == true ? "yes" : "no"))\n"
        out += "terminalShowing=\(terminalIsShowing)\n"
        // What the dock is showing, the way `sidebardump` reads the sidebar: with no plugin mounted
        // here this is the empty-state sentence, which is itself the thing worth asserting — an empty
        // frame and an explained one look the same in a screenshot.
        var labels: [String] = []
        func walk(_ view: NSView) {
            if let field = view as? NSTextField, !field.stringValue.isEmpty, !field.isHidden {
                labels.append(field.stringValue)
            }
            // Button titles too: a plugin's chrome is mostly buttons, and whether a panel is *there*
            // is a steadier thing to ask than where the keyboard happens to be a second later — the
            // find bar's options are visible from the moment it opens, its focus is not.
            if let button = view as? NSButton {
                if !button.title.isEmpty, !button.isHidden { labels.append(button.title) }
                // …and stop. A borderless NSButton keeps its title in an internal NSTextField, so
                // walking into it lists the same "+" twice — which read like a duplicated button in
                // the dump and was not one on screen.
                return
            }
            view.subviews.forEach(walk)
        }
        walk(dock)
        out += "text=\(labels.joined(separator: " | "))\n"
        try? out.write(toFile: file, atomically: true, encoding: .utf8)
    }

    /// Write every string a plugin's sidebar view is *showing* to a file (F-372).
    ///
    /// The preview panel is the host's "sidebar" view container, so a plugin view mounted there is a real
    /// NSView inside the host's window — which means the host can read it, and a claim about what a plugin
    /// displays does not have to be taken on trust. Nothing in the ABI would allow asking the plugin.
    private func dumpSidebar(_ file: String) {
        var lines: [String] = []
        func walk(_ view: NSView, depth: Int) {
            let pad = String(repeating: "  ", count: depth)
            if let field = view as? NSTextField {
                let kind = field.isEditable ? "field" : "label"
                lines.append("\(pad)\(kind)=\(field.stringValue)"
                             + (field.placeholderString.map { " placeholder=\($0)" } ?? ""))
            } else if let text = view as? NSTextView {
                lines.append("\(pad)text=\(text.string.replacingOccurrences(of: "\n", with: "⏎").prefix(120))")
            }
            for sub in view.subviews { walk(sub, depth: depth + 1) }
        }
        if let panel = previewPanelForAutomation() {
            walk(panel, depth: 0)
        } else {
            lines.append("ERROR: no preview panel view")
        }
        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] sidebardump → \(file) (\(lines.count) rows)")
    }

    /// Does a file's comment follow the file through a rename, in the running app (F-372)?
    ///
    /// Usage: `commentcarry <dir>|<name>|<newName>|<out>`. Sets a comment through the panel's own path
    /// (the same one Ctrl+Z uses), renames through the panel's rename, and reports what the *panel* shows
    /// in its Comment column afterwards — not what the store returns. The column is the thing the user
    /// looks at, and it is fed by a separate read.
    private func commentCarryProbe(_ arg: String) async {
        let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard a.count == 4, let panel = activePanel else {
            NSLog("[automation] commentcarry needs <dir>|<name>|<newName>|<out>"); return
        }
        let (dir, name, newName, out) = (a[0], a[1], a[2], a[3])
        await panel.loadDirectory(dir)
        panel.tableView.focusEntry(named: name)
        var report = ""
        let set = await panel.setCursorComment("carried through the rename")
        report += "set=\(set)\n"
        panel.refreshComments()
        try? await Task.sleep(nanoseconds: 500_000_000)
        report += "beforeRename=\(panel.tableView.automationComment(forName: name) ?? "<none>")\n"
        _ = panel.performRenames(dir: dir, pairs: [(old: name, new: newName)])
        try? await Task.sleep(nanoseconds: 900_000_000)      // the carry runs in a detached Task
        await panel.loadDirectory(dir)
        panel.refreshComments()
        try? await Task.sleep(nanoseconds: 500_000_000)
        report += "afterRename=\(panel.tableView.automationComment(forName: newName) ?? "<none>")\n"
        report += "oldName=\(panel.tableView.automationComment(forName: name) ?? "<none>")\n"
        // …and what the cell actually draws, which is not the same claim.
        report += "renderedCell=\(panel.tableView.automationRenderedComment(forName: newName))\n"
        panel.tableView.automationScrollToLastColumn()
        try? report.write(toFile: out, atomically: true, encoding: .utf8)
        NSLog("[automation] commentcarry → \(out)")
    }

    /// Open `src` in the editor and put the filter prompt on screen for a screenshot (F-356).
    private func editFilterDialog(_ arg: String) async {
        let win = EditorWindowController(path: arg)
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 600_000_000)
        win.automationShowFilterDialog()
    }

    /// Write the active panel's current path and visible entry names to `file`, so a
    /// driver can assert on what the panel actually shows (local or remote).
    /// Drive the screen-change clamp and report both halves of it (F-479 follow-up).
    private func screenClampReport(_ spec: String) async {
        let parts = spec.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, let window = self.window else { return }
        let wh = parts[0].split(separator: "x").compactMap { Double($0) }
        guard wh.count == 2 else { return }
        let vf = (window.screen ?? NSScreen.main)?.visibleFrame ?? .zero

        func line(_ label: String) -> String {
            let f = window.frame
            return "\(label)=\(Int(f.width))x\(Int(f.height))@\(Int(f.minX)),\(Int(f.minY))\n"
        }

        var out = "visibleframe=\(Int(vf.width))x\(Int(vf.height))@\(Int(vf.minX)),\(Int(vf.minY))\n"
        let wanted = NSRect(x: vf.minX, y: vf.minY, width: wh[0], height: wh[1])
        window.setFrame(wanted, display: true)
        out += "forced=\(Int(wh[0]))x\(Int(wh[1]))\n"
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification,
                                        object: NSApp)
        out += line("afterchange")
        out += "fits=\(vf.contains(window.frame))\n"
        // The second half: the notification firing again while the window fits must put back what
        // was there before the clamp — that is the whole point of remembering it.
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification,
                                        object: NSApp)
        out += line("afterrestore")
        try? out.write(toFile: parts[1], atomically: true, encoding: .utf8)
        NSLog("[automation] screenclamp → \(parts[1])")
    }

    private func dumpActivePanel(to file: String) async {
        guard let panel = activePanel else {
            try? "ERROR: no active panel\n".write(toFile: file, atomically: true, encoding: .utf8)
            return
        }
        let path = await panel.getCurrentPath()
        let names = panel.tableView.currentVisibleEntries().map { $0.name }
        // A failure message is part of what the panel is *showing*, and without it a dump of a panel
        // that could not open a directory is indistinguishable from one that did — which is how the
        // silent-failure path stayed invisible to the harness for as long as it did.
        let message = panel.view.transientMessageForAutomation.map { "message=\($0)\n" } ?? ""
        // What the cost gate declined to do here (F-479). A gallery on a share is *supposed* to show
        // placeholder icons, and without a number the harness cannot tell that from a gallery whose
        // thumbnails simply have not arrived yet.
        let out = "path=\(path)\ncount=\(names.count)\n"
            + "locality=\(panel.sourceLocality.rawValue)\n"
            + "deferredthumbs=\(panel.view.deferredThumbnails)\n"
            + "thumbsrequested=\(panel.view.thumbnailsRequested)\n"
            + "thumbscached=\(panel.view.thumbnailsFromCache)\n"
            + "thumbcache=\(ThumbnailCache.shared.report.count)/"
            + "\(ThumbnailCache.shared.report.bytes / (1024 * 1024))MB\n" + message
            + names.joined(separator: "\n") + "\n"
        try? out.write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] dumped \(names.count) entries of \(path) → \(file)")
    }

    /// Drive the Automation Core end-to-end against the running app:
    ///   automate <tool>|<json-args>[|auto]
    /// Logs the outcome (ok payload / needs-confirmation plan+token / refused /
    /// failed). `auto` uses an autonomous policy so a gated write actually runs.
    private func automateCoreTool(_ spec: String) async {
        let parts = spec.split(separator: "|", maxSplits: 2).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        guard let tool = parts.first, !tool.isEmpty else {
            NSLog("[automation] automate: missing tool name"); return
        }
        let json: Data? = parts.count > 1 && !parts[1].isEmpty ? Data(parts[1].utf8) : nil
        let policy: PermissionPolicy = (parts.count > 2 && parts[2] == "auto")
            ? PermissionPolicy(autonomy: .autonomous) : .standard
        let line: String
        do {
            let outcome = try await automationCore.invoke(tool: tool, arguments: json, policy: policy)
            switch outcome {
            case .ok(let payload):
                let s = payload.flatMap { String(data: $0, encoding: .utf8) } ?? "(no payload)"
                line = "automate \(tool) -> ok: \(s)"
            case .needsConfirmation(let plan, let token):
                line = "automate \(tool) -> needsConfirmation: \(plan) [token=\(token)]"
            case .refused(let reason):
                line = "automate \(tool) -> refused: \(reason)"
            case .failed(let error):
                line = "automate \(tool) -> failed: \(error)"
            }
        } catch {
            line = "automate \(tool) -> throw: \(error)"
        }
        NSLog("[automation] \(line)")
        // Also append to a file so headless verification can read outcomes reliably.
        let logURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("pc-automate.log")
        if let data = (line + "\n").data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: logURL) {
                h.seekToEndOfFile(); h.write(data); try? h.close()
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
#endif
