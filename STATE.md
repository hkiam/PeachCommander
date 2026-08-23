# STATE — Single Source of Truth for Progress

> Update this file after EVERY completed work unit. Keep it short; move history
> to the bottom log. A new session must be able to resume from this file alone.

## Current status

| Field | Value |
|---|---|
| Phase | **A & B done. C: I14 done; I15 plain FTP LIVE (quick-connect + connection manager, verified vs test.rebex.net; SFTP + explicit-FTPS still pending); I16 lister/content plugins mostly done. D: I17 utilities mostly done; I18 macOS integration MOSTLY DONE (Quick Look Cmd+Y, Share sheet, Open With, Finder Tags: color column + tag-filter (tag:red/#blau), Spotlight metadata in Get Info, Services menu integration, "Open Terminal Here", Full Disk Access onboarding, Go▸Trash, xattr inspector/remove in Change Attributes, privileged "retry as administrator" for chmod+delete done; ACL editing/copy-move-elevation/undo pending). Also F-063 Ctrl+Left/Right open cursor folder in other panel done.; I19 partial (perf targets validated); I20 shipping GROUNDWORK done (DMG script + release CI workflow + hardened-runtime entitlements + RELEASE.md + CHANGELOG + local crash reporting; only Developer-ID signing/notarization and Sparkle auto-update remain — both need Apple creds / update-feed hosting).** |
| Evidence sweep | **Batches 1–24 (2026-08-07/08): 73 rows checked, 33 defects fixed, 87 → 21 rows without evidence; the last 21 were then worked through on 2026-08-09 and the count is now **0** — five of them turned out not to be implemented at all (the window title, the splitter's double-click, sequential transfers, the icon-off mode and the DMG layout).** A follow-up *interpreter sweep* (2026-08-08, after 0.4.0) then went at one defect class on purpose — a string from somewhere else reaching something that interprets it — and found four more: the panel's extract walk wrote above the destination (F-131), an XML file could read your other files through external entities (F-368), previewing a document fetched a remote image and so reported that you opened it (F-116), and the assistant's approval gate was bypassable through `run_command`. See the entry below. Worst: a file name could run a shell command through a user-menu %-token (F-252); a crafted archive wrote outside the chosen folder (F-131); the archive password stood in the process list (F-136); a CRLF code file rendered as one line six million characters wide (F-110); undoing a batch rename did nothing (F-175); Num/ did nothing (F-056); a wildcard selected the *wrong* file (F-055); a Windows-written .sfv verified nothing (F-097). Six defects were one Swift trap — `"\r\n"` is a single Character. New gates: `check-checksums.sh`, `check-pack-formats.sh`, `check-strings-extracted.py`, `check-tests-registered.py`, `check-vm-flags.sh`, plus `check-descript-format.sh` extended. Of the 21 rows left, 8 are blocked externally (Apple credentials, SMB mounts, the Services menu). |
| Current iteration | **0.7.2 — released 2026-08-19** — the Git plugin, assessed and then built out in six stages (F-415…F-423): the four defects the assessment found first (a subdirectory's file reported the parent repository's status, a rename shifted every status after it, a non-ASCII path came back blank, `push` could wait forever on a terminal this process does not have), then the panel with the host's compare window as its diff, the history with a lane graph and blame, branches/stashes/sync with a way out, `.gitignore` management, revert and cherry-pick, a column that follows a linked worktree and a submodule, a conflict resolver on the file's own markers, credential *diagnosis* that stores nothing, "open on the web" without an API, and a rebase bounded to the commits ahead of the upstream. Four things were argued down rather than built: a merge editor with base and result panes, credential storage of any kind, the GitHub/GitLab API, and status *icons* (a glyph instead, since the content ABI returns strings). The host gained asynchronous plugin commands with progress and cancel (F-422), where two traps sat one level apart: every host service asserted it was on the main actor — off-main `assumeIsolated` traps — and awaiting the command merely moved the block from the main thread to its caller. Previously **0.7.1 — released 2026-08-18** — a round of reported defects, four of them losing something rather than looking wrong: a Total Commander `.mnu` that could not be read at all (encoding + CRLF, the same fix for `.bar`/`usercmd.ini`/`wincmd.ini`), a CSV whose first record vanished into the column headers, every valid JSON Lines file reported as broken, and hardlinked files in a cpio/initramfs image listed as 0 bytes while opening with their full contents. Plus the freeze a reader hit while the work was in progress: formatting a 2 MB log with very long lines took 193,934 ms to draw thirty lines, now 126 ms. Previously **0.7.0 — released 2026-08-16** — a read-only plugin that opens filesystem images the way archives open (F-403): SquashFS, ext2/3/4, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT12/16/32, exFAT, NTFS, plus MBR and GPT partition tables. Router firmware with no partition table is carved — the filesystems are found by searching for them and confirmed by opening each one — and the bootloader, kernel and vendor header around them are listed and extractable. Every reader is written here from its published layout rather than vendored, for licence reasons; only zstd's own single-file decoder (BSD-3) is taken in. Reviewing it turned up three integer-overflow crashes reachable from a crafted image, one of them older than the plugin, and a mutation corpus that structurally could not reach the code it was meant to guard. That in turn exposed F-230: the crash guard caught the four faults C code raises and none of the ways Swift fails, so a trapping plugin took the whole app down. Remaining big blocks: I20 Developer-ID signing/notarization + Sparkle auto-update — the workflow exists, four repo secrets are missing. |
| Build status | ✅ builds; app launches |
| Test status | ✅ ALL suites green incl. PCPerfTests after `Tools/make-fixtures.sh` (fixtures at /tmp/pc_fixtures). Perf targets validated 2026-07-23: list 100k < 1s, sort 100k < 150ms, filter 10k < 50ms — all met with wide margin. VM regression: **105 scenarios with reports** (`viewer-esc`, `menu-key-guard`, `swift-outline`, `go-outline`, `markdown-outline` and `html-outline` are new with F-110/F-404/F-405; `find-history` with F-406, `find-seeded-viewer`, `find-seed-off`, `find-text-field` with F-407 and `search-settings` with F-408 and `theme-system` with F-409 — **all six now run on the VM and green**, see the harness entry below for the five measurement defects that run caught) (was 59; the seven `keys-*` scenarios had no file for the guest to wait for and had been writing nothing at all — fixed 2026-08-10, and the first working run found a missing accessibility label). The count is the one `Tools/check-scenario-reports.py` prints, and is worth reading from there rather than counting by hand: this row said 98 until 2026-08-22, six behind the 104 that already existed before `hidden-files-race`. New: `tree-colours`, `surface-colours` (colour audit over every window and plugin view in every palette), `plugin-theme-switch` (a theme change with a plugin view open used to kill the app), `hidden-files-race` (F-435: forty panel/hidden-file commands in a row — the app used to abort partway through, so the report's absence is the failure). The harness now collects crash reports; it used to leave only an empty report and a screenshot of the desktop. **The full run is green again** (117 scenarios, 2026-08-22). It had ended non-zero on two, both measurement rather than application: `surface-colours` pinned a window count that moves, and `tree-colours` read a tree row that can be scrolled out of view while a `.labelColor` fallback made the miss look like black text. Both fixed — see the harness entry of 2026-08-22 — along with the layout conflict that came from one scenario toggling the trees another had set. |
| Parity inventory | Fully re-audited against evidence 2026-08-04: **161 done · 9 partial · 2 todo · 7 n/a-macos · 2 post-1.0** (181 rows as audited; **206 rows** today, F-404 and F-405 added since). The line before this claimed 59/70/43; the audit went through every `todo` row and then every `partial` one at P1, P2 and P3. Of 18 `todo` rows 16 were implemented, of 50 P1 `partial` rows 46 were, and of 19 P2/P3 `partial` rows 16 were — most "missing" sub-parts were missing only from a first grep. **Still open:** F-212 upload resume, F-213 explicit FTPS (needs a transport that can start TLS on a live connection — Network.framework cannot), F-099 privileged copy/move, F-139 non-zip archive targets, F-015 a shared tree, F-216 FXP (P3), F-297 Trash put-back (no public API), F-237 SFTP as a PFX plugin (a design decision), and F-310/F-312 blocked on Apple credentials. 237 `ev:` pointers must resolve for `Tools/check-inventory.py` to pass; **67** older `done` rows still carry none (was 87 before the evidence sweep of 2026-08-07/08 — see the ten batch entries below). **The sweep found a defect behind roughly four of every five rows it checked**, most of them in the same few shapes: a CRLF file from Windows, an input a dialog really receives, an untrusted name reaching a shell, and two names for one file. Where a row held up, that is recorded too. |
| Last updated | 2026-08-23 |
| Released | **0.7.1 (build 12), 2026-08-18** — the defect round above; unsigned, as every build so far. Previously **0.7.0 (build 11), 2026-08-16** — filesystem images browse like archives, including firmware that carries no partition table, with a layout report under Commands. The plugin ships switched off. Alongside it, a crash guard that had been blind to the way Swift plugins actually crash now catches them and quarantines the plugin instead of the app. Unsigned, as every build so far. Previously **0.6.4 (build 10), 2026-08-15** — three requests from one user and the four defects they uncovered. Previously **0.6.2 (build 8), 2026-08-13** — the FTP/SFTP/WebDAV side: an open connection is a drive of its own and can be hung up from its chip, the connection dialog refuses combinations that cannot work, SFTP takes a key file and a passphrase, and three site settings that had round-tripped through ftp-sites.ini and reached nothing (`encoding`, `localDir`) are finally read. Plus the keyboard-shortcut recorder, which took no keys at all. Unsigned, as every build so far. |
| Localization | 🌐 **19 languages COMPLETE** (en, de, fr, zh-Hans, da, nl, it, ko, nb, pl, sv, sk, sl, es, cs, uk, hu, ro, ru). App String Catalog (1383 keys × 19) + all shipping plugins + the **full in-app Help Book (51 topics × 19)**. Coverage gate `docs/scripts/check-translations.py` green — and it prints the numbers above, so read them from there rather than counting by hand (languages=19 · help_topics=51 · ui_strings=1383 · behind=0). Adding a language = 1 UI translations file + `knownRegions` + a `docs/help-<code>/` set (+ optional plugin `<lang>.lproj`). |
| Documentation | 📚 SSOT docs (`docs/content/`) → **Apple Help Book** (`Resources/PeachCommander.help`, 19 lproj) + **MkDocs site** (`build-site.py`, en at root + 18 at `/<code>/`) + generated `FEATURES.md`/overviews. New project **README.md**. Detailed plugin help pages (Git, System Monitor, Task Manager, Uninstaller) added, each with a real **English** screenshot; AI documented as a removable plugin. Screenshots English-only by design (VM harness forces guest locale to en; `pfxmount` verb + demo Git repo/apps/leftovers make the plugin UIs reachable). |

**Harness: two failures that were mine.** A flaky test — `DirectoryWatcher` expectations were fulfilled
twice, because FSEvents coalesces or does not as it sees fit; four of the five positive expectations
lacked `assertForOverFulfill = false` and now have it, with the reason written down. And a whole suite of
empty reports, which I spent half an hour reading as a product defect: I had rebuilt the app *while the
harness was copying it to the guest*, so the VM ran a half-written bundle that launched and then did
nothing at all. `regress.py` now compares the binary before and after the copy and stops with that
sentence rather than letting it look like something else.

## 2026-08-22 (F-435) — "it just crashed": a handler on the wrong thread

Reported from a live session: switching panels started showing the wrong content, then toggling hidden
files took the app down. One cause for both. The crash report puts `-[NSTableView reloadData]` on
`com.apple.root.user-initiated-qos.cooperative` while the main thread was drawing the System Monitor
titlebar; AppKit's layout engine raised an `NSException` nobody catches, and `abort()` followed.

**The annotation that does less than it reads like.** `CommandHandler` is
`@MainActor (CommandContext) async throws -> Void`, and its comment claimed that isolating the *type*
makes "every handler — present and future — run on the main actor automatically". That is true for a
closure **literal** at a `handler:` argument, which infers isolation from the contextual type and hops
on entry — 112 registrations, all of them safe the whole time. It is false for a reference to a
separately declared `func`: that keeps its own isolation, and converting it to a `@MainActor` function
type inserts no hop. All 37 named `cm_*_handler` functions were nonisolated and ran wherever
`CommandRegistry.execute` — a nonisolated `async` method on an actor — had its continuation.

**The compounding half.** `WindowControllerProtocol`'s ~140 requirements were *synchronous* and
nonisolated, while `MainWindowController` is main-actor-isolated implicitly, through
`NSWindowController`. A synchronous nonisolated witness has nowhere to hop, so the witness thunk ran
main-actor AppKit code on the background thread. That is exactly why only window-controller commands
were affected and every panel command was fine: `PanelControllerProtocol`'s requirements are `async`,
and an async witness *can* hop.

Both symptoms fall out of it. `cm_SwitchPanel_handler` → `toggleActivePanel()` → `markActiveViewMode()`
→ `-[NSMenu itemArray]` off the main thread is the wrong panel content; `cm_SwitchHidSys_handler` →
`toggleHiddenFiles()` → `PanelListView.applyHiddenChange` → `reloadData` is the abort.

**Fix.** `@MainActor` on all 37 named handlers, so they hop in their own prologue, and on
`WindowControllerProtocol`, so the compiler holds the rule. Zero call-site churn: a main-actor handler
calling a main-actor protocol method needs no `await`.

**Why the build never said anything, and the gate that now does.** The project compiles in the Swift 5
language mode, where this is a warning at worst. Worse than that: the "conformance … crosses into main
actor-isolated code" warning is only emitted for types annotated `@MainActor` **explicitly**. Three
such warnings existed in the tree and none of them was this one — `MainWindowController` inherits its
isolation from AppKit, so the most dangerous conformance in the codebase was completely silent. So the
rule is mechanical now: `Tools/check-command-handler-isolation.py` fails if a named handler loses its
`@MainActor`, if either protocol loses its own, or if the typealias stops being a `@MainActor` function
type (which would take the 112 closures down with it). Verified by breaking each of the three in turn.

**Evidence, before and after.** An automation script issuing 40 × `cmd cm_SwitchHidSys` interleaved
with `cmd cm_SwitchPanel`, with the plugins copied into the config root so the titlebar monitor keeps
the main thread drawing: the pre-fix binary exits 134 with a fresh `.ips`, the fixed one exits 0 and
runs all forty. On the guest as the `hidden-files-race` scenario — its own directory holding one
visible file and one dotfile, so the report proves the app survived, the panel still shows what it was
on, and hidden files ended up off again. Passes with 0 Auto Layout conflicts.

## 2026-08-22 (F-436) — The three side findings behind F-435

**A crash used to make the next automated run hang rather than fail.** `applicationDidFinishLaunching`
called the crash-report prompt (F-313) and the Full Disk Access prompt (F-299), both `NSAlert.runModal`.
A modal owns the main queue an automation script is driven from, so the script *keeps running* inside
the nested runloop and writes its dumps — and then `quit` never lands. The run looks fine and hangs
forever, and the moment it happens is right after a crash, i.e. exactly when someone is trying to
verify a fix. Both are skipped under `-AutomationScript` now; the crash watermark is deliberately not
advanced, so the report still greets the user on their next ordinary launch. Two runs were spent on
this before it was understood — one of them on the *system's* own "reopen windows?" dialog, which after
two crashes in a row blocks inside `promptToIgnorePersistentStateWithCrashHistory` before any app code
runs and so looks like a launch that died silently. `-ApplePersistenceIgnoreState YES` gets past it;
`/usr/bin/sample` on the hung process names the culprit in one shot.

**The two conformance warnings that were left, and one that was mis-called harmless.**
`PanelControllerProtocol` was written off as safe because its methods are `async` — but it also carries
three *synchronous* `var` requirements (`currentArchiveZipPath`, `currentFileSystem`,
`isOnNetworkFilesystem`), which is the same hazard as F-435 in a shape that is easy to miss when
scanning for `func`. It is `@MainActor` now. `NSServicesMenuRequestor` and `QLPreviewPanelDataSource`
are ObjC protocols carrying no isolation, and their isolation is not ours to change, so those witnesses
are `nonisolated` with a `MainActor.assumeIsolated` body: AppKit and Quick Look only send them from the
main thread, and asserting that is better than reading main-actor state from wherever the call arrives.
A deliberate trade — a violation becomes a loud precondition failure instead of a silent race.

Measured rather than assumed: 26 warnings before, 23 after, exactly those three gone and no new ones.
Full `AllTests` green (PCPerfTests skipped — the `/tmp` fixture flake, not this work).


## 2026-08-22 (F-437) — The docs site opened with the API reference

Reported plainly: the site is hard to digest because it *starts* too hard. The first two
navigation entries were **API reference** and **Developer guide**, *Getting started* came
third, and the user guide, plugins and tutorials were far below. A reference work answers a
question the newcomer does not have yet.

**Nobody decided that order.** `build-site.py` derives the nav from each page's front matter:
`section:` groups, and a section's rank is `min(order)` of its pages. Four sections tied at
`order: 10`, and the tie fell to `sorted(rglob("*.md"))` — alphabetical directory order — so
`developer-guide/` outranked `help/`. The API reference won outright because
`gen-api-reference.py` wrote `order: 5`, the smallest number in the corpus. Measured at the
generated `mkdocs.yml`, not inferred: one of the three exploring passes reasoned it out from
the front matter instead and got it backwards, which is why the artefact was checked.

Second problem, independent of order: **21 sections on one level**, because the nav builder
knew only one level of grouping. Sorted perfectly it would still be unreadable.

**The lever: a new `group:` key rather than rewritten `order:` values.** The obvious move —
renumbering — is expensive, because the same front matter feeds the Apple Help Book and
`docs.yml:87` byte-compares the shipped bundle: every renumbering would mean rebuilding 19
languages and translating 18 sets of section names. `group:` is read by the website only.
Verified at both consumers before writing anything: `check-docs.py` checks required fields
for *presence* and rejects no extra key, and `build-helpbook.py` reads only `title`, `slug`,
`section`, `order`, `related`, `anchor`. Proof after the fact: **`index.html` changed in none
of the 19 lproj bundles**, and `check-translation-drift.py` reports `drifted=0`.

Seven tabs in reading order — Get started · Using Peach Commander · Customise · Plugins ·
Tutorials · Reference & help · Develop — with the 21 former sections as collapsible groups
beneath. Groups holding a single section are flattened, so no tab says "Plugins ▸ Plugins".
`navigation.tabs` is switched on **only** where a group exists: enabling it globally would
have promoted the translated subsites' twelve sections to twelve tabs and changed 18 sites
nobody asked to change. The API reference moved from first to last, by moving its generated
`order:` into a 200-band — those pages live outside `docs/content/help/`, so the Help Book
never reads them.

Landing page: it already existed and was good (hero, six feature cards, a key-cap strip, a
release-aware download button). It gained **three doors** — coming from Total Commander, new
to two-panel managers, here to write a plugin — built from the `## Who it is for` prose that
was buried at position eleven. The plan also said to trim the long tail of list sections;
looking at them, that would have destroyed substantive positioning copy, so they stayed.
`auto-fit` rather than three fixed columns after the picture showed the middle door's title
breaking across three lines: what constrains the cards is the content column, which depends
on the sidebar and the ToC, not on the window.

**Two defects fixed on the way.** `help/filesystem-images.md` and
`plugins/filesystem-images.md` shared a slug; staging is flat, so the developer page
overwrote the user page while the nav kept an entry for each — two titles, one file, and the
user-facing Filesystem Images help was **not on the site at all**. The developer page was the
one renamed, because only `help/` topics are translation-gated. A duplicate slug now aborts
the build. And the site said "MacOS & privacy" because `sec[:1].upper()` ran over every
section label, including ones that were already correct.

Nothing pinned the nav order — no golden file, no check — which is how this could happen at
all. `docs/scripts/check-nav-order.py` now does, wired into `docs.yml` after the quality gate.
It holds the two failure modes `group:` introduces (a page without one becomes a stray
top-level entry; a typo becomes an eighth tab) and the rule the restructure exists for, stated
in the reader's terms rather than as a number: **first tab is where you start, last tab is the
deep end.** Each of the four regression shapes was verified by producing it.

`docs/product/vision.md` was brought in line with the public positioning in the same pass: it
opened with "a Total Commander clone … functional parity as the explicit goal" and claimed
four plugin kinds, against README/website/API-reference saying "not a clone that copies pixels"
and five. Capability parity, not appearance, and the target-user section now names the same
four audiences the website does. It is the file somebody copies marketing copy out of.

## 2026-08-22 (F-438) — 266 dead links in the shipped Help Book

Seven help topics link to each other as `](slug.md)`, which is right for the website. An
Apple Help Book bundle contains no Markdown at all, so each of those was a dead href in the
in-app help: 14 links × 19 languages. `build-helpbook.py` rewrote image paths and never body
links, and `build_index()` always emitted correct `.html` for the table of contents — so the
help *looked* fine from the outside and `check-docs.py` accepts both forms by design.

Fixed in the generator, with anchors preserved (`editing-files.md#formatting-a-file` →
`.html#formatting-a-file`), and a link to an unknown slug now prints a warning instead of
being rewritten into a different dead end — the English corpus is gated by `check-docs.py`,
the 18 translations by nothing at all.

Regenerating surfaced something else: **the committed bundle was stale.** Of 154 changed
topic pages, 152 changed only their link targets; `en/de.lproj/ai-assistant.html` also gained
content, because `62255c0` changed those sources and the bundle was last built in `7a7d3d2`.
The byte-comparison gate should have caught that at the time. Local `markdown 3.9` /
`pygments 2.21.0` match the pins in `docs.yml:30`, so the diff carries no formatting noise.


## 2026-08-22 (F-439) — The other eighteen languages

F-437 gave the English site seven tabs and left the 18 translated Help subsites exactly as
they were: a flat list of twelve sections, and for 17 of the 18 a **three-line** landing page
from `synth_index()` — a heading and the name of the language. For a non-English visitor the
whole point of the restructure had not happened.

**Almost nothing had to be translated.** The subsites hold only `docs/content/help/`, which
spans five of the seven groups — and four of those five contain exactly *one* section, whose
name the translators had already chosen. A group holding one section **is** that section, so
its tab label is derived from the translated `section:` rather than repeated in a second table
that would disagree the moment somebody renames one. That leaves the single umbrella group
("Using Peach Commander", eight sections) as the only thing needing words:
`docs/metadata/nav-groups.yml`, 18 strings, and that file says plainly that they are the one
thing on the translated sites nobody has reviewed.

Placement needs no per-language front matter either: a translated topic's group is looked up
from its English counterpart **by slug**, which `check-translations.py` already gates in both
directions. 918 files untouched.

**The front pages are built from translated prose that already existed.** The lead is the
first paragraph of that language's own `introduction.md` — reviewed text, not a welcome
sentence invented here in eighteen languages — followed by every topic grouped the way the
tabs group them. 3 lines became 97. The hand-written German exception (`DE_INDEX`) is gone;
German now gets the same treatment as the rest.

**What the work uncovered.** Deriving labels from translations only works if the grouping
agrees, and in **16 of 18 languages it did not**: the plugin help was split in two, seven
topics under the translated word and six — `csv-lister`, `decompilers`, `filesystem-images`,
`log-viewer`, `terminal`, `webdav` — left under the English "Plugins". The same six
everywhere, i.e. the later-added plugin pages, whose translations copied the English
`section:` along with the prose. Those readers have been looking at two plugin sections in the
shipped in-app help, one of them untranslated, and no gate anywhere noticed. Fixed in 96
files, which changed the Help Book index for those 16 languages and nothing else — English
untouched but for its `.helpindex`, which the byte gate excludes. `de` and `da` were already
consistent: both use "Plugins" as their own word.

`check-nav-order.py` grew the two rules that would have caught it: a group that is one section
in English must be one section in every language, and an umbrella group needs a label for
every language. Both verified by reproducing the defect.


## 2026-08-22 (F-440) — The bundled plugins, said out loud

"Gerade die bereits enthaltenen sind ein großer USP und das muss rüberkommen." Right: seventeen
plugins ship inside the app — verified in `PeachCommander.app/Contents/PlugIns`, fourteen of
them enabled by default — and the landing page mentioned them in one run-on sentence two thirds
of the way down, under a heading about the *SDK*. The feature card near the top sold the
*ability* to write plugins. Somebody skimming the page would never learn what the thing already
does.

There is now a showcase directly after the six feature cards: a line each for all seventeen,
the three that are off by default (Filesystem Images, and the two decompilers that need an
engine you install yourself) marked as such rather than left to be discovered, the plugins
window as evidence that they are all there and each independently switchable, and Disk Map, Git
and the Uninstaller shown instead of described. Each card links to that plugin's own help page,
so the entry feeds the funnel. The later section keeps the SDK story — five plugin kinds over
one C11 ABI, four of them TC-shaped — and no longer repeats the inventory.

**A measurement worth keeping.** The plugin cards came out two-across when three were intended,
and rather than guess a third time I measured the page: the content column is 826 px, the root
font-size **24 px**. Material sets `html { font-size: 125% }`, so a `rem` track minimum decides
the column count by the reader's font size rather than by available width — `minmax(11.5rem, …)`
was asking for 276 px tracks. Three columns needed 857 px of 826. The same bug had quietly made
the three doors two-across, and the six feature cards, which predate this work. All four grids
now use px minimums; gaps stay in rem, where scaling with type is what you want.


## 2026-08-22 (F-441) — Terminal and Log Viewer, photographed

Two of the most visual bundled plugins had no screenshot at all, so the F-440 showcase could
only name them. Both are now captured through the VM harness (`docs/metadata/screenshot-specs.yml`
+ `Tools/vm/capture.py --only …`), registered in the index, and on the landing page — the strip
carries five pictures instead of three.

**The first terminal shot was wrong and the picture is what said so.** The spec assumed the
shell starts in the panel's directory; `pwd` printed `/Users/admin`, and the caption I had
written ("already in the folder you are looking at") would have shipped as a plain untruth. The
help page has it the other way round: the shell is a *login* shell starting at home, the panel
can be made to follow the shell (off by default, and it needs an OSC 7 snippet in `~/.zshrc`),
and **Go to the Panel's Folder** (`cm_TerminalCdHere`) is the command that connects them. The
spec now runs that command, so the shot shows the feature instead of implying one that does not
exist, and the plugin card on the landing page was corrected the same way — it had claimed the
terminal follows the panel.

Second defect in the same shot: two `termsend`s 1.2 s apart lost the second one, and the first
attempt was a picture of an idle prompt. One command, generously timed.

**A convention I had broken.** The showcase's image strip was hand-written
`<img src="assets/screenshots/…">`, which bypasses two things at once: the builder's
`screenshots/… → assets/screenshots/…` rewrite, and `check-docs.py`'s reference tracking — which
duly reported both new images as unreferenced. The strip is Markdown inside `markdown="1"` now,
one paragraph per picture, and the gate is quiet.

**Both help pages now embed their screenshot, in all 19 languages** — the decision was to do it
in full rather than leave 17 languages behind an allowlist entry. Two things kept the invented
share down: the caption format was read out of each language's existing figure captions rather
than guessed (`*(Abbildung: …)*`, `*(Figure : …)*` with the French space, `*（图：…）*` with
full-width punctuation), and each alt text names the plugin by the title that language's own page
already uses — `Der Log-Betrachter`, `La visionneuse de journaux`, `일지 뷰어`. What remains
genuinely new is 38 alt texts and 38 captions that I wrote and no translator has reviewed. The
image goes in at the same structural position everywhere — directly before the first `##` — which
is why `check-translation-drift.py` still reports `drifted=0`. Help Book rebuilt: exactly 38 topic
pages changed, plus a copy of each PNG per lproj.


## 2026-08-22 (F-442) — Documentation that described itself wrongly

Three leftovers from the site work, plus one claim of mine that did not survive checking.

**`pages.yml` is fine.** I had said an SDK header change regenerates the API reference without
redeploying the site, so the published reference could lag. It cannot: `docs/content/reference/`
is a *committed* artefact and `docs.yml:31-38` fails until it is regenerated and committed — and
that commit touches `docs/**`, which is exactly what triggers the deploy. Adding
`Plugins/SDK/**` to the trigger would only deploy redundantly. Not changed.

**`FEATURES.md` had two `## Archives` sections** because one record of eighty-eight — `zip64` —
carried `category: archives` where every other archive feature says `archive`. `CAT_LABEL` has
no entry for the plural, so `gen-overviews.py` fell back to `cat.title()`, which renders
"archives" as "Archives" — the same label the singular already produces. One mistyped plural,
two identical headings, every gate green. Record fixed, and the generator now exits non-zero on
a category that is not in `features.yml`'s own `meta.categories` list rather than inventing a
label for it. Verified by mistyping one.

**`docs/metadata/navigation.yml` is gone.** A stub containing `nav: []` that nothing has ever
read. The navigation is derived at build time from front matter and `GROUP_ORDER`; there is no
navigation file, and `DOCUMENTATION.md` now says so instead of listing `gen-nav.py` as pending.

**`DOCUMENTATION.md` was describing a different project.** Its §4 table marked
`build-helpbook.py`, `gen-api-reference.py` and `check-docs.py` as _(planned)_ — all three are
built and CI-enforced — and it named two generators that were never written: `gen-features.py`
(the real one is `gen-overviews.py`) and `gen-readme.py` (the README is hand-written, and
`Tools/check-readme.py` checks its checkable claims). §8's "add a feature" recipe told the reader
to run `capture-screenshots.py` and `mkdocs build`, neither of which exists. All corrected, the
two abandoned ideas are marked abandoned rather than left looking pending, and §8 now also says
the thing that actually bites: a new help topic must exist in all 19 languages in the same
commit.


## 2026-08-22 (F-443) — A sync button has to know which side it is

Requested: one click to put the left panel's folder in the right panel, and the other way round. The
app already had `cm_TargetEqualSource` (Ctrl+=), and it is the wrong shape for a button — it is
relative to whichever panel is active, so the *same* button does two different things depending on
where the focus happens to be, and you have to look before you click.

So two absolute commands, named for the panel they change, the way "target = source" is:
`cm_LeftEqualsRight` (30124) and `cm_RightEqualsLeft` (30125), in **Go**, and two buttons on the
default button bar. Both are one line over `leftPanelController` / `rightPanelController`, which
`transferCursorItem(toRight:)` already reaches the same way. Verified against exactly the confusion
they exist to remove: with the **left** panel active, `cm_LeftEqualsRight` changed the **left** one —
target = source would have changed the right.

**No keyboard shortcut, deliberately.** Ctrl+Shift+Left/Right are free in both schemes and in
`menu.txt`, and they still would be the wrong thing to add blind: `PanelListView.keyDown` handles the
arrow keys itself (`case 123/124`) and looks only for Alt there, so that is its own question with
`check-hotkeys.py` as the judge. Both commands are assignable in Settings from the day they exist.

**A default button reaches nobody who has already run the app.** `loadButtonBar` writes
`defaultButtonBar()` only when there is no `default.bar` at all, so on any existing installation the
bar on disk is the one from the release before the button existed — and adding to the template alone
would have shipped a feature that only new users see. Hence `seedSyncBarButtonsIfNeeded`, once, with
`[Layout] SyncBarButtonsSeeded` recording that the offer was made: the flag is set on the first run
whether or not anything was added, so deleting the buttons afterwards sticks. It is called from the
startup path only, *not* from `loadButtonBar`, whose second caller is the Total Commander import — a
bar you just imported from elsewhere is not ours to add to. All three cases run: fresh config seeds
11 buttons, an eight-button bar from before becomes ten, and a hand-emptied bar stays at eight.

**VM.** `menu.txt` regenerated to 220 lines with both items and no key equivalent, and
`check-hotkeys.py` reads that dump: `problems=0` unchanged. `toolbar-drop` went from 10 buttons to 12
(the ten defaults plus the dropped Calculator) and its own assertion — one `Calculator.app` command
line — still holds. The menu titles were checked in the running app in de, fr, ru and zh-Hans rather
than only in the catalogue.

## 2026-08-22 (F-444) — The file said you could click the empty space. You could not.

Reported: the pencil at the right end of the path bar is an 18-point target, and the empty space
beside it means nothing. Make the whole area right of the path open the editor.

`PathBarView.swift`'s own header comment had claimed exactly that behaviour — "Clicking empty space —
or double-clicking anywhere — turns the bar into a free-text edit field" — for as long as the file has
existed. Only the double-click was ever implemented; `mouseDown` navigated on a segment and did
nothing otherwise. So this closed a documented behaviour rather than adding one.

The decision moved to `PCFoundation/PathBarHit.swift` for the same reason `PathSegments` is there — it
decides where a click goes, and the view around it needs a theme, a tracking area and an AppKit event
to ask the question. Segment first, then the trailing area, then nothing: the three-pixel gaps
*between* segments stay inert, because a click that just misses a folder name is a miss and not a
request to type a path. `contentEndX` is nil until the first draw, so a bar nobody has seen cannot be
clicked into edit mode.

**The promise needed the dead property to stop being dead.** `contentTrailingInset` (30 pt) was
written to keep the segments off the pencil and then never read, so a long path drew its deepest
folders underneath the button. Stopping the pen at the limit was not enough either: the segment that
*crossed* the limit still overhung it, its hit rect reached into the trailing area, and the first run
of this showed the bug plainly — a click in the free space of a deep path navigated to a parent
instead of opening the editor. A segment that does not fit *whole* is now not drawn at all, which is
what makes "everything past `contentEndX` is free space" true rather than nearly true. The visible
cost is up to 30 pt less breadcrumb on a path too long for the bar, whose deepest segments were
already being clipped by the right edge.

**A click on a path bar now activates that panel** — it did not, and neither do the tab bar or the
drive bar. Without it the editor could open on the panel that does not have the focus. Order matters
and only works one way round: `activateLeftPanel` makes the file list the first responder, while
`beginEditing` focuses its field on the next runloop tick, so activate first. Confirmed by the
responder: `NSTextView` after the click, on the panel that was inactive when it started.

**And the three indicators over the bar were eating the clicks.** `filterLabel`, `typeAheadLabel` and
`messageLabel` are constrained *over* the path bar, and a plain `NSTextField` answers `hitTest`
whether or not it can use the click. While the quick filter was showing, its indicator sat on the
pencil and **the pencil could not be clicked at all** — older than this change, and invisible, because
the indicator looks like part of the bar. `ClickThroughLabel` returns nil from `hitTest`. The gate is
the new `pathbarclick` verb's `hitTest=` line, asked of the window *before* the click: `NSButton` at
the pencil and `PathBarView` beside it, with the filter up. Asking after the click only ever reported
the edit field, which is how the first version of this check passed while proving nothing.

**Two DEBUG verbs, because there was no other way to look.** `pathbardump` reports whether the bar is
editing, the field's text, the breadcrumb and where the content ends; `pathbarclick <side>|<region>|
<clicks>|<out>` clicks a named region (first/last/gap/trailing/pencil/x:n) with a synthesised
`NSEvent` through `mouseDown`, so the coordinates the bar draws with and the ones it hit-tests against
have to agree — the half a direct call to `pathBarHit` would have assumed. A screenshot cannot say
where the segments ended, which is the only number that matters here.

**VM.** Zero Auto Layout conflicts in `main-window`, `keys-main` and `accessibility`, and the keyboard
loop is still closed: 32 stops, all reachable and all labelled. `ClickThroughLabel` was the thing to
watch there — a view that stops answering `hitTest` could in principle drop out of what a screen reader
reaches by position, and the labels are still in the tree because accessibility traverses subviews, not
hit tests.

## 2026-08-22 (VM) — Two failures in the full suite, both older than this work

The first full run in a while — 117 scenarios — and it ends non-zero on two of them. Neither is caused
by F-443 or F-444, and both were checked rather than assumed.

**`surface-colours` pins a number that has moved.** It expects `windows=32` and measures 40. Built at
`7a710ce3` — this work not applied — and run alone, it measures **40 as well**. So the pin is stale by
however many windows the app has gained since it was set, and `findings=0` (the substantive half: no
bright surface in a dark window, no text too close to its background) holds either way. The comment
above it explains why the count is in the expectation at all — `findings=0` is also true of a run that
audited nothing — so the number wants updating, not deleting.

**`tree-colours` fails only in company.** Run alone it is green in every palette. In the full suite it
reports `got=#000000` for every palette whose text is not black, and that is not a black tree: the
probe reads row 0 with `makeIfNecessary: false` and falls back to `?? .labelColor`, which resolves to
exactly `#000000` outside a dark drawing context (measured). So a probe that finds no row view reports
its own default as if it were the theme's — and the light palette cannot show it, because there `want`
is `#000000` too. The scenario's own comment already says "It passes alone and failed in the full
suite, which is the worst shape a check can have"; that shape is back, one level down.

**The 1 conflict in `surface-colours` is a consequence of the same order.** Alone it reports zero, on
both builds. It appears when `tree-colours` runs first: that scenario *sets* both trees visible, and
`surface-colours` then *toggles* them — so it turns them off, and a zero-width `PanelTreeView` with a
scroll view pinned to both its edges is exactly the conflict AppKit reports. The identical constraint
set is already in the committed log from 2026-08-17. `surface-colours` should use `treevisible …|1`
like `tree-colours` learned to.

**Why none of this was visible before.** The committed artefacts were a patchwork of partial runs:
`report.md` held **one** data row (`hidden-files-race`), and both of these scenarios were last measured
on 2026-08-10 in a commit carrying 19 scenario reports. Their green state had never been established
under the full suite. This run restores `report.md` to all 117 rows, and six scenarios —
`csv-no-header`, `git-no-toolchain`, `jsonl`, `menu-file`, `viewer-long-lines`, `viewer-md-outline` —
get their first committed artefacts at all (14 new report files between them). 117 scenarios ran; the
105 the coverage gate counts are the ones carrying a report assertion, which is a different number and
unchanged.

Nothing is fixed here — the three findings are recorded so they can be argued with rather than
rediscovered. Fixing them is a harness change, not an app change.

## 2026-08-22 (F-445) — A listing that failed wrote the path down anyway

Found while answering "why can't I open ~/Library/Application Support/MobileSync?" — which turned out
to be macOS TCC and not a permission at all: the mode bits say `drwxr-xr-x` and you own it, and the
kernel still answers EPERM. The app said "Could not open MobileSync" and then behaved as though it had
gone there.

**One assignment on the wrong side of the enumeration.** `DirectoryModel.load` set `self.path` first
and `entries` at the end, so a listing that threw left the model holding the new path with the
*previous* directory's entries. `getPath()` has twenty-odd callers, and they then described a folder
whose contents were not on screen. Measured, all four readers at once:

    path=…/Application Support/MobileSync      (the model)
    tabs=*MobileSync                           (the tab)
    crumb=/ > Users > maik1 > … > Application Support   (the path bar — the OLD folder)
    count=97                                   (the list — the parent's 97 entries)

Two readers said one thing, one said another, and the list belonged to neither. Worse, it was
persisted: `Tab0Path=…/MobileSync` reached `session.ini`, so the next launch opened in a folder it
could not list. And child paths are built as `<model path>/<name>`, so Enter on any row addressed a
file that does not exist.

**Fixed in three places.** `DirectoryModel` commits the path and the entries together or not at all
(both overloads — `load(_:lister:)` had the same shape and additionally cleared `entries` up front, so
*its* failure left the new path with an empty list). `loadPath` now reports whether the listing
happened, and the two `loadDirectory` overloads that also record the path into the tab — and through it
the session — return early when it did not. After the fix, on a `chmod 000` directory: model, tab,
breadcrumb, list and `session.ini` all name the folder the panel is actually showing.

**And the message names the cause, because nothing about it is guessable.** A privacy refusal is the
one failure where the folder is visible, belongs to you, and its mode bits say you may read it — and
elevation cannot help, because the gate is on the *application*. `PrivateLocation` (PCVFS) reads the
distinction `VFSError` already carries: `fromErrno` sets `needsElevation` for EPERM and clears it for
EACCES. That name is a poor fit here — elevation is the one thing that does not help — so it is read
for what it records rather than what it is called. EPERM together with mode bits that *would* have
allowed the read is the contradiction only the privacy gate produces; the panel then says "macOS keeps
%@ private — see Commands ▸ Full Disk Access…" instead of the generic line.

**The reproduction is gone from this machine.** Full Disk Access was granted partway through the work,
and `MobileSync` now lists normally, so the numbers above are the recorded ones from before. That is
also why `PrivateLocation` is a pure rule with the `stat` lookup separated out: a protected location
cannot be created for a fixture — the list is macOS's own — so the rule is what gets pinned, over both
refusals and both ownership cases. The model fix is verified against a `chmod 000` directory, which
produces EACCES and therefore takes the ordinary message, exactly as it should.

## 2026-08-22 (VM harness) — The three findings from the full run, fixed

All three were measurement, not application, and the full suite is green again. Reproduced first in a
six-scenario sequence (`terminal-restore`, `terminal-restored`, `terminal-elsewhere`, `terminal-move`,
`tree-colours`, `surface-colours`) rather than by waiting for scenario 61, which is what made the second
one findable at all.

**`tree-colours` was asking for a row that can be scrolled out of view.** The probe read
`view(atColumn: 0, row: 0, makeIfNecessary: false)`, and `NSTableView` only vends views for rows inside
the visible rect. A tree that has revealed the current folder is scrolled — which the panel's tree
almost always is, while the shared one usually still shows "/" at the top. So the panel probe got nil,
and *which* tree failed depended on where the previous scenario had left them.

Nil was not the reported answer, though: the fallback was `?? .labelColor`, which resolves to exactly
`#000000` outside a dark drawing appearance. So "no row" was reported as black, the light palette
*expects* black and passed, and the four dark palettes failed with a number that read as a painting
defect. Two fixes, and the order mattered: the fallback became nil and the dump prints `<no row>`
first — which immediately said *panel*, in every palette including light, instead of *dark, midnight,
norton* — and only then was the scroll position visible as the cause. `panel/opened` had been green all
along, which is the tell nobody could use while the two answers looked alike: the tree had rows and the
right colour, the probe just could not see them. It now reads the first *visible* row.
`makeIfNecessary: false` stays, because reading a row that already existed is the whole point — a
freshly made cell is correctly coloured by construction.

**`surface-colours` pinned a count where it wanted a claim.** `windows=32` is palettes × (visible
windows + hidden plugin views), so it moves whenever a palette, a window or a plugin view is added, and
it had moved to 40 — on a build with none of the work that was suspected of moving it. The dump now
names what it looked at (`audited: Settings`, `audited: side:Git`,
`audited: dock:plugin.terminal.view`, …) and the scenario asserts three surfaces it deliberately puts on
screen. `windows=` stays in the dump, where it is worth reading and costs nothing when it changes.

**`surface-colours` toggled the trees that `tree-colours` had set.** `cm_TreeShared` and `cm_SrcTree`
flip a state the guest's `peachcmd.ini` remembers, so after `tree-colours` switched both trees on these
two switched them off — and a hidden tree is a zero-width `PanelTreeView` with a scroll view pinned to
both its edges, which is the Auto Layout conflict it reported in the full suite and never alone. Now
`treevisible …|1`, the same lesson `tree-colours` had already learned one scenario earlier.

**Left alone, and recorded instead: a system permission dialog sits on the guest during runs.** The
`tree-colours` screenshot has "Allow PeachCommander to find devices on local networks?" over the window
— the app's own `NSLocalNetworkUsageDescription`, triggered by the System Monitor reading interface
counters. Nothing in `regress.py` dismisses or pre-answers it, so it obscures screenshots and can hold
the key window in any scenario. Fixing it is golden-image work (a seeded TCC decision), not a scenario
change.

## 2026-08-22 (F-446) — The assistant could not reach the index the app already uses

Asked to compare against Cmdr, whose headline AI feature is natural-language file search over a
whole-disk index it builds in about four minutes. We do not need that index: the app already queries
**Spotlight** through `NSMetadataQuery` in Find Files. The assistant did not. Its `search` walks a
directory tree, and `semantic_search` is capped at one folder, 300 entries, the first 2 KB of each,
recomputed per query. So the gap was wiring, not indexing — the best value-to-effort ratio of the three
gaps the comparison found.

**The split.** `find_files` takes a *structured* query — name, words inside files, kind, a modification
window, a size range, a scope — and the model translates language into it. Spotlight does the finding.
That is deliberate: nothing in the tool guesses at language, so the fields are inspectable and "nothing
found" reads as "it looked for a PDF named *contract* modified in the last 30 days" instead of being a
shrug. The scope travels back with the result for the same reason — a model cannot otherwise tell "not
anywhere on this disk" from "I looked in one folder", and neither can the reader.

**A relative window instead of dates.** `within_days`, not `modified_after`. The system prompt carries
no date at all, so a model cannot resolve "last month" — and rather than add a date to the context and
a date parser to the tool, the window needs no arithmetic. Both of Cmdr's advertised examples are
expressible without it. Absolute ranges are a second increment; `AutomationContext` deliberately did
*not* grow a `today` field nothing yet consumes.

**Refusals that say something.** An empty query would match the volume, so it is refused with what to
supply rather than answered with a hundred thousand paths. A `kind` that was asked for and not
understood is refused with the list of kinds — silently widening "PDFs" to every file is a wrong answer,
which is worse than a complaint. `Kind` parses loosely ("PDFs", "photos", "video", "folders") because
that is what a model sends; every value maps to a real system UTI, and `kMDItemContentTypeTree` matches
by conformance, so `image` finds a HEIC without anyone naming HEIC.

**Verified against the live index**, at Cmdr's own examples: `node_modules` + kind=folder returns five
real folders, newest first, typed as directories; kind=pdf returns real PDFs with size and date; the
same query with `within_days: 3` narrows 200 hits to 7; and a content search for `cm_LeftEqualsRight`
— a symbol that exists only in this week's own source — returns ten files, which is the capability
`search` never had. `within_days` sent as the string `"3"` gives the same seven, because a model asked
for an integer sometimes sends one quoted.

**A new DEBUG verb, because there was no other way to look.** `aitool <tool>|<json>|<out>` runs one
assistant tool through the Automation Core and writes its payload. Without it a tool can only be
exercised by talking to a model, which makes the tool and the model's willingness to call it one
untestable lump — and a read tool returning the wrong thing looks exactly like a model that phrased the
question badly.

**What this is not.** Not an index of our own: Cmdr builds one because it is going cross-platform, and a
second index here would be permanent maintenance for a worse result than the one macOS keeps current
for free. And Spotlight's limits are inherited rather than papered over — it honours the privacy
exclusions and the places macOS keeps to itself, so an empty answer is never proof of absence (F-445 is
the same wall from the other side), and a file created moments ago may not be indexed, where Find Files
still walks.

**Still open from the same comparison**, in the order I would take them: a natural-language batch rename
that produces a *table* and hands it to the existing Multi-Rename engine rather than looping `rename`;
and a reviewable operation plan — `needsConfirmation` carries one string today, and "clean up my
Downloads" wants a list whose rows can be unticked.

## 2026-08-22 (F-447) — Forty renames, one question, one undo

The second gap the Cmdr comparison found: it advertises natural-language batch rename, and the
assistant could only call `rename` once per file — forty confirmations, forty entries in the action log,
and forty separate things to take back. `rename_batch` takes the whole table.

**The machinery was already here.** `RenameBatchEngine.apply` stages through temporary names, so a swap
or a rotation works, and it reports per-item refusals; `RenameValidator` judges a name. What was missing
is the *shape*: two parallel lists rather than a list of pairs, because that is what a small on-device
model fills in reliably — and the price of that choice, a length mismatch, is caught rather than
silently truncating a batch into "some files renamed".

**All or nothing, unlike the Multi-Rename window.** There, applying what works and reporting what does
not is right: the user wrote the rule and saw the preview. For a table a model proposed, one bad row is
usually a systematic mistake, and half of it applied is a folder to untangle by hand. So
`RenameBatchPlan` refuses the batch with *every* reason at once — two files aimed at one name, a name
already taken by a file that is staying, an unusable name, a missing source — which is also what lets a
model fix it in one more turn instead of ten.

**The defect the first measurement found.** My first version showed the table for approval and validated
afterwards, so a batch naming one file twice was presented as something to agree to and only the
confirmation reported the collision. Asking someone to approve what will then fail spends the one moment
of their attention on a dead end. The Core now has a pre-flight: a gated action that cannot work is
refused instead of proposed, sharing one code path with the check made before applying so the two cannot
drift. Only for what can be decided cheaply and definitely — a copy whose destination fills up halfway
cannot be foreseen, a rename table naming one file twice can.

**Undo is the batch reversed**, which is sound only because the batch is all-or-nothing: every pair
either happened or none did, so swapping the two lists cannot describe a state the folder was never in.
Verified end to end: three files renamed after one question, `undo_last_action` put all three back in one
step, and the panel and the disk agreed at every point.

**The plan is a table, not a count.** "Rename 40 files" is not something anybody can agree to. Capped at
thirty rows with the remainder stated, because a confirmation nobody reads is not a confirmation.

## 2026-08-22 (F-448) — The assistant shipped switched on, and nothing said so

Asked whether the AI plugin is disabled on a first install. It was not: `Plugins/AIAssistant/Info.plist`
carried no `PCPluginEnabledByDefault`, and `PluginManifest` reads that key with a default of `true`. So
a beta assistant whose catalogue holds `write_file`, `delete_permanently` and `run_shell` was on for
everyone who installed, and the help page said only that it *can* be disabled.

**The inconsistency is what settles it.** Three plugins already ship off, and for weaker reasons: the
two decompilers are merely useless without an engine the user installs, and Filesystem Images is
read-only (it is off because its parsers are reachable from a crafted image). By that standard an
assistant that renames, moves, deletes and runs shell commands — each behind a plan, but present — is
the better candidate. Both AI plugins now carry `PCPluginEnabledByDefault` = false, AIColumn along with
the assistant it shares a model with: a column calling that model once per visible row while the
assistant is off would be the inconsistent half.

Worth saying plainly: without an API key the assistant works entirely on-device, so this is about the
*reach* handed over by default and not about anything leaving the machine.

**Verified both directions**, in a bundle holding only these two plugins so the comparison is exact.
Fresh configuration: `list_plugins` returns `[]`, no AI in the menu dump, no view, no column, nothing
about either plugin in the log, no crash. With `[Plugins] Enabled=AI Assistant;AI Column`: both load and
`AI Assistant [plugin.ai.toggle]` is in the menu.

**A consequence that did not bite, and would have.** Several VM scenarios sweep every mounted plugin
view, so `surface-colours` had been auditing the AI tab and counting it — and its expectation used to
pin `windows=32`. Turning the plugin off would have moved that number again and failed the scenario for
a third unrelated reason. It does not, because the same day's harness work had already replaced the
count with the *named* surfaces the scenario deliberately puts on screen (Settings, the Git panel, the
dock's terminal), none of which is the assistant. `regress.py` never names the AI plugin at all.

**Not changed:** the on-device/cloud choice, the autonomy gating, or anything the assistant does once
it is on. Only whether it is there to begin with.

## 2026-08-22 (F-449) — A flag that named a remedy it knew nothing about

`VFSError.permissionDenied(needsElevation: Bool)` was set from `code == EPERM` and read by exactly one
caller, which wanted the errno. So the name promised something the value never carried — and on macOS
the EPERM case is usually the privacy gate, where administrator rights are precisely what cannot help.
A reader following that name would reach for the one remedy that is useless.

Worse than misleading: **redundant**. The question it appeared to answer is answered properly elsewhere,
by `FileWritability.administratorMayHelp`, which looks at the file instead of guessing from a refusal —
and that is what the "retry as administrator" feature actually uses. Checked: nothing outside
`PrivateLocation` ever destructured the flag, and no `switch` over `VFSError` is exhaustive, so the
payload could be changed without a single call-site becoming wrong by silence.

Now `permissionDenied(Refusal)` with `.modeBits` (EACCES) and `.notPermitted` (EPERM) — named for what
`errno` said, which is all it ever recorded. Thirteen sites across six files. And the mapping is pinned
now: `VFSErrorTests` had never existed, so `fromErrno` — five branches that every file operation in the
app depends on — was covered by nothing.

## 2026-08-23 (F-450) — All or nothing was the only answer a plan could take

The third gap the Cmdr comparison found, and the one it advertises as "a list of move/delete suggestions
you can approve/reject". `needsConfirmation` carried one string. For a single action that is the right
shape — "Delete report.pdf" is agreed to or not. For "clean up my Downloads" it is the wrong one: the
answer is usually "yes, except those three", and without rows a user who wants that has to reject the
whole plan and describe the exception in prose for the model to get right on a second attempt.

**The rows are derived from the arguments, not declared by the model.** What the user strikes out has to
be what the tool skips, and that is a property of the arguments and nothing else. `PlanRows.of` produces
them for the tools where a list is meaningful — a batch rename, a multi-file move/copy, a multi-file
trash or delete — and nothing for the rest: striking out the only row of a `write_file` is cancelling,
and offering that as a choice is noise.

**The dangerous case is `rename_batch`, and it is why this is a tested pure function.** Its two lists are
positional, so filtering them separately shifts every pair after the gap onto the wrong name — and the
batch still applies cleanly, renaming the wrong files with no error anywhere. Filtering is pairwise, and
a test pins it: strike `b` out of a→x, b→y, c→z and `c` must still become `z`, never `y`. Verified in the
running app too: three files, one struck out, `renamed: 2`, and `1.txt 3.txt b.txt` on disk.

**Rejecting every row is a cancellation**, reported as one. The alternative — running a `move` with no
sources — reports success for having done nothing, which is worse than a refusal.

**A trap that cost a wrong conclusion.** The concrete `planItems` was written synchronously while the
protocol requirement is `async`. That compiles: an async requirement accepts a sync witness. But the
call site then has two candidates — the actor's own method and the protocol extension's async default —
and `await` picks the async one, which returns `[]`. So every plan looked indivisible, no error appeared
anywhere, and the first end-to-end run "passed" while proving nothing about rows. The requirement is
`async` for the F-435 reason (a synchronous requirement on an actor has nowhere to hop); the witness now
matches it exactly.

**The plugin ABI grew by two entries**, appended, as `contrib.h` documents for exactly this:
`automationPlanItems` and `automationConfirmRejecting`. An older host has neither, and the plugin then
behaves as it did before rows existed — nil rows means "cannot be divided". All three copies of the
header stay in step (`Tools/sync-plugin-sdk.sh`; the gate found the third one).

**What is not finished: there is no picture of the tick list.** The rows, and what striking one out
actually skips, are proved through the host's ABI by `aitool` — for a batch rename and for a multi-file
trash, in the running app. Whether the checkboxes are *on screen* only a picture can show, and nothing in
the automation harness types into that chat, so getting a plan on screen needs a language model to choose
to propose one — which is not something a check can depend on. Drawing is now split from fetching
(`renderPlanRows`) so a harness that can reach it could photograph it. A DEBUG command to render
fabricated rows was written and then removed: contribution commands have to be *declared* in the
plugin's manifest to be dispatched, and a test entry point in a shipping plugin's manifest is a worse
trade than the missing picture.

## 2026-08-23 (F-451) — The fold assumed the summaries would fit

A live test failed, and the first job was to find out whose fault it was. It passed three times today and
failed the fourth, on trees where the only difference was code that does not touch summarising — so the
easy conclusion was "flaky model, retry more". The failure message said otherwise.

**What the model actually answered:** "Die Datei bericht.txt enthält zu viele Token (4091) zum
Zusammenfassen. Die maximale zulässige Größe beträgt 4096." That reads as a wrong summary of the file,
and it sent me looking at the file. It is the model *narrating a window failure back to the reader* —
the log line above it is a real `exceededContextWindowSize` at 4100 tokens — and the number is the tell.
4096 is our own budget.

**The assumption was written down, which is what made it findable.** `summarizeWholeFile` folded every
section summary in one generation, under the comment "the section summaries are short, so they fit in one
window together". The model decides how long a "two or three sentence" summary is. A 38 KB file is ten
sections here, and ten verbose partials plus the fold instructions exceed the window — so the feature
whose whole point is that *length costs time rather than failing* failed on length after all, at the very
last step, and only sometimes.

**Folding now happens in rounds.** `foldGroups` batches consecutive partials up to `foldBudget`, each
batch is folded, and the results are folded again until one remains. Every prompt is bounded however many
sections there were. The grouping keeps neighbours together and in order, because the sections are
consecutive parts of one file and folding section 1 with section 9 would read as though the middle were
missing. A partial over budget on its own becomes its own group: refusing it would drop a section, and a
summary of the wrong file is worse than one long prompt. `foldBudget` is deliberately under `readBudget` —
the fold prompt carries its instructions as well as the partials, and the window counts tokens while the
budget counts bytes.

**The live test keeps the same assertion and gained a sharper one.** It now also fails when the answer
*is* a relayed context-window excuse, in either language, so the next occurrence says which half broke
instead of pointing at the file. Three attempts rather than two, with the reason written down: it drives
a live model whose wording varies, and one word from the file is what counts as an answer — but the thing
that was actually broken is fixed in the fold, not in the retry count.

**Verified**: the test now passes on the first attempt in 17 seconds at `summarize_file:10/10` — the same
ten sections that overflowed — and the summary includes the file's *last* line, which is the part a fold
that dropped sections would lose. Nine unit tests pin the grouping, including the property that matters
most: whatever the budget, no section is ever dropped or reordered.

## 2026-08-18 (VM) — The five new scenarios, on the VM

Run with `--only menu-file,viewer-md-outline,csv-no-header,jsonl,viewer-long-lines`, which is the debt both
of today's commits recorded: they had been verified locally against the Debug build and never on the guest.
**All five pass, every report, and zero Auto Layout conflicts in each.** Worth naming individually, because
each one is a claim a local run cannot make:

* `menu-file` — the external check says `yes`: the `em_` command from a CP1252 + CRLF menu file really ran
  in the guest, with `%P` expanded to the panel's directory.
* `viewer-long-lines` — `line_build=fast` on VM hardware, i.e. the drawing path is linear there too. That
  is the one where the number matters: 193,934 ms against 126 ms locally.
* `jsonl` — a valid file has no problem line, a trailing comma is reported on line 2, and the formatter that
  ran was `JSON Lines`.
* `csv-no-header` — all nine values of a headerless file are *cells* (`label=1`, `label=5`, `label=9`).
* `viewer-md-outline` — the outline opens on the rendered page and the click scrolls it to the heading.

All five are now in `docs/metadata/layout-baseline.json` at zero, so a conflict in any of them is a
regression from here on. The run's report and screenshots are under `/tmp/vm-new-scenarios/` — not recorded
in `docs/generated/layout-regression/`, which is written from *full* runs; this was a five-scenario run and
overwriting the recorded set with it would delete 105 other rows.

## 2026-08-23 (F-452) — Three keys that did the wrong thing quietly on a plugin drive

Groundwork for an S3 plugin, and it turned into a defect round before a line of S3 was written. The
question was only "what does a PFX mount not do yet". The answer was that three of the four write
operations the ABI defines have no route from the keyboard at all, and that all three fail *silently*
on the local disk instead of failing on the server.

**F5 into a mount copied to this Mac and said it had succeeded.** `cm_Copy` chooses between an upload
and a local copy on `inactive.isOnNetworkFilesystem`, which is `fs is ResumableFileUploading`.
`PFXFileSystem` did not conform, so every plugin mount took the local branch — `CopyEngine` against a
path like `/my-bucket/photos/a.jpg`, on this disk. This is F-367 exactly, the defect that was found and
fixed for FTP, still standing for every plugin because the fix was a conformance on one class and PFX
was not that class.

**F7 created a local folder named after the remote path.** `makeDirectory` calls `MkDirEngine.create`,
which is `FileManager`. **F6 and Shift+F6 renamed nothing and blamed the files**: `RenameBatchEngine`
is `FileManager` too, so every rename failed against a path that exists nowhere here, and the failures
were then reported in the "N file(s) were not renamed" dialog as though the files had refused. `PfxMkDir`
and `PfxRenMov` are documented in `pfx.h`, implemented in the shipped WebDAV plugin, translated into
nineteen languages — and unreachable. The same shape as F-445, one level over.

**Why nothing caught it.** The WebDAV plugin had no test for its write half either, and could not have
had one: `Tests/PCPluginHostTests/Fixtures/davserver.py` was read-only, so `PUT`, `MKCOL`, `DELETE` and
`MOVE` had never once been executed against anything. Two gaps that hid each other — the operations were
untested, and the route to them was missing, so neither absence produced a failure anywhere.

**Fix.** `PFXFileSystem` now conforms to `ResumableFileDownloading` and `ResumableFileUploading`. Neither
can actually resume — `PfxGetFile`/`PfxPutFile` take two paths and no offset — so both report
`resumedAt: 0`, which is the protocol's own way of saying the restart was not allowed. Adopting them
anyway is the point: the conformance is what the panel reads to decide whether a keystroke is an upload.
The download side also removes work rather than only routing, because the generic fallback in
`extractNode` goes through `localFileIfAvailable`: materialise in temp, copy to the destination, delete
the temp — three passes over every byte. `PfxGetFile` can write to the destination, so it does.
`makeDirectory` and `performRenames` route a non-`LocalFS` panel to `fs.mkdir`/`fs.rename`, in the shape
`deleteThroughFileSystem` already established: no undo, no comment carry, and a failure that names the
items it happened to. No undo is deliberate — undoing a creation out there is a real unrecoverable
delete, not a trip to the Trash.

**The spec parsing moved rather than being copied.** `MkDirEngine.parse` is now separate from `create`,
because `a/b|c` and the refusal of `..` are not formatting: the `..` rule is the reason a new folder
cannot be talked into appearing outside the directory the panel is showing. Two callers duplicating that
by hand is one of them eventually not having it.

**The progress callback was a stub, and hooking it up has a trap in it.** `PFXHostBridge` answered
`s.progress` with a constant `PC_CONTINUE` ("no host sink yet"), so cancelling a transfer did nothing:
`run` hands the blocking C call to the connection queue and waits, and there is no suspension point
left to cancel at — a 4 GB download finished and only then noticed nobody wanted it. `PFXProgressSink`
is now the channel, and `withTransferCancellation` installs a handler for the duration of one transfer
so a cancelled task makes the next progress report answer `PC_ABORT`. The trap: every sibling callback
in that bridge goes through `MainActor.assumeIsolated`, and the plugin reports progress from its
connection queue — off the main thread `assumeIsolated` traps rather than hops. That is the F-422 lesson
a second time, so `PFXProgressSink` is deliberately not actor-isolated and does its own locking, with
the reason written above it. A plugin that never reports progress still cannot be interrupted; that is a
property of the plugin and is stated rather than papered over.

**Evidence, before and after.** `davserver.py` gained the four write verbs (with containment on `MOVE`'s
`Destination`, and a body that is always read — an unread `PUT` body desynchronises the keep-alive
connection and surfaces as a random protocol failure several operations later). `WebDAVPluginTests` went
from 10 tests to 23: upload, upload-over-existing, upload into a missing collection, download straight
to the destination, download over a stale partial, download of a missing file leaving no file behind,
mkdir, mkdir over something that exists, rename, rename-as-move, delete of a file and a directory, the
two conformances themselves, and a transfer with the sink attached. Four more pin `PFXProgressSink`,
including that reporting from another thread does not trap. **37 tests, 0 failures.** The new string is
in the catalogue in all 18 translations; `check-strings-extracted`, `check-format-specifiers`,
`check-translations`, `check-plugin-translations`, `check-inventory`, `check-tests-registered`,
`check-sdk-headers`, `verify-shipping` and `check-docs` are green.

**Not done here, on purpose.** The channel exists but nothing shows a percentage yet — wiring it to the
Transfer Manager through `OperationKind.custom` is its own piece of work, and so is the fact that the
upload path has no overwrite dialog and no directory recursion for *any* network backend. `openRead`
still loads a whole object into memory, because the ABI has no range read.

## 2026-08-23 (F-453) — Amazon S3 as a drive: the read half, and a signer held to AWS's own numbers

The first wave of the S3 plugin. `S3.pfxplugin` connects to AWS or to anything that speaks S3 —
MinIO, Ceph/RGW, R2, Wasabi, B2, Spaces — and the bucket list is the root of the mount. Read-only on
purpose; `PfxGetCapabilities` returns `PC_PFX_CAP_READ` alone, because advertising write in front of
a `PfxPutFile` that does not exist puts F5 on a key that answers `PC_E_NOT_SUPPORTED`, and to the
user that reads as the *server* refusing.

**No SDK, and the decision is in ADR-012 rather than in a comment.** A PFX plugin is a bare
`swiftc -emit-library` dylib outside the Xcode target graph, so it cannot consume a SwiftPM package
without new build machinery — `soto` and `aws-sdk-swift` are not available to it at any price short
of that. SigV4 over CryptoKit is about 200 lines. Seven sources, one `Tools/build-s3-plugin.sh`
(its own script, because the helper in `build-pfx-plugins.sh` takes exactly one source file), and the
universal build links CryptoKit on both slices with no extra flag.

**The signer is a pure function, which is the only reason it can be trusted.** No clock, no
`URLSession`, no request building: inputs in, signature out. That is what makes AWS's published
"Examples: Signature Calculations" usable — they are exact inputs with an exact expected signature
string, and a signer that reads `Date()` cannot be held against them. All four match:
`f0e8bdb8…` (GET with a Range header), `98ad7217…` (PUT with `$` in the key and a storage class in
the signature), `fea454ca…` (a valueless `?lifecycle`, which signs as `lifecycle=`), `34b48302…`
(two query parameters, sorted by name rather than by insertion). `S3SignerTests` compiles the signer
on its own into a driver and compares the strings.

**The bug the vectors did not catch, and the comment that found it.** `canonicalURI` filtered out
empty path segments, so `/a//b` signed as `/a/b` — while the doc comment three lines above claimed
that S3 is the service which does *not* normalise the path. `a//b` is a real, addressable key; the
signature would have been for a different object, and it would have failed only for the keys a user
is least able to rename. Written down wrongly and fixed because it was written down.

**Two prefix bugs, one cause, found by the tests.** S3 has no directories: a folder is either a
common prefix inferred from the keys under it, or a zero-byte object whose key ends in `/`. The
parser drops the directory's own marker (otherwise the folder appears inside itself, which in a panel
is an endless chain) and drops sub-prefix markers that `CommonPrefixes` already reported (otherwise
each folder shows twice, once as a folder and once as an empty file). Both correct — and both leave
the caller unable to tell "this directory is empty" from "there is no such directory", because after
filtering each answers with zero entries. A prefix holding only its own marker was reported missing,
and `PfxStat` called a real folder absent. `S3ListPage` now also carries `rawCount`, the number of
elements the server actually sent before any filtering, and the two callers ask that instead.

**The fixture verifies signatures rather than accepting them.** `Fixtures/s3server.py` recomputes the
canonical request from the raw path and query — never decoded and re-encoded, because that would hide
exactly the bug it exists to catch — and refuses a mismatch. So every assertion about a listing is
also an assertion that the canonical request, the signed header list and the payload hash were all
right: a signing bug does not produce a subtly wrong listing here, it produces 403 on everything.
One test proves the fixture is really doing this by connecting with a wrong secret and requiring the
failure; without it the whole file could be green against a server that ignores the header.

**Details that are decisions, not defaults.** Pagination is lazy inside `PfxFindNext`, so a bucket
with a hundred thousand keys appears progressively and stops early when the user navigates away —
the host yields to the panel in batches of 128 and checks for cancellation between them, and
fetching every page inside `PfxFindFirst` would throw that away. `encoding-type=url` is always
requested, because a key may contain bytes that are not legal in XML and without it the whole
directory comes back as a document the parser rejects, i.e. as empty. `PfxStat` on a 403 also asks
whether the path is a prefix, since a bucket policy can allow `ListBucket` and deny `HeadObject` —
and then the only question that would have identified a directory answers "denied". Profiles live
under `getContext("configRoot")/s3/`, never a path built from Application Support, and the secret
goes through the host's `crypt` callback; an environment connection is deliberately *not* saved,
because exporting credentials in a shell is not asking for a drive chip.

**A defect the lazy paging created, and the host change that answers it.** `PfxFindNext` returning 0
means "no more entries" and nothing else — the ABI gives it no error channel. For a plugin that
fetches a directory in pages, a connection lost *between* two pages therefore looks exactly like
reaching the end: the panel shows part of the directory and calls it complete, which is worse than an
error because nothing on screen suggests anything is missing. `PFXFileSystem.list` now asks
`PfxLastError` once the enumeration ends and fails the listing when the answer is
`PC_E_CONNECTION_LOST` — only that one, because a plugin reporting something else may be describing a
single entry it skipped, and turning a complete listing into a failure over that would be its own
defect. A plugin that does not track errors answers nil and nothing changes. The fixture grew a
`PC_S3_FIXTURE_DIE_AFTER_LISTINGS` knob so the test arranges this rather than trying to time it.

**Evidence.** `S3PluginTests` — 23 tests through `PFXFileSystem`, the same path the app uses: the
bucket list as the root (and the account's `<DisplayName>` not listed as a bucket), prefixes as
directories, an empty prefix still a directory, a prefix not inside itself, a key called
`odd +name.txt` fetched byte-for-byte (a space must be `%20` and a `+` must be `%2B` in both the URL
and the signature, and form-decoding the `+` would fetch a different key), 40 objects across
fourteen pages with the fixture capped at three keys, a server that dies after the first page
reported as a lost connection rather than as a 3-entry directory, a dead server reported as a lost
connection rather than a missing directory, and the profile list not written anywhere else. Plus
`S3SignerTests` — 2 tests, the four vectors and the encoding rules they do not reach.
**25 tests, 0 failures.**
`verify-shipping`, `check-plugin-translations`, `check-tests-registered`, `check-sdk-headers` and
`check-strings-extracted` are green; the bundle is `x86_64 arm64`.

**`PCPluginIncomplete` is set**, so `verify-shipping.sh` lets development proceed and refuses to
build a DMG. What is missing behind it: all writing, `~/.aws` profiles, region redirects, retry,
Glacier handling, content columns, eighteen translations and a help topic.

**A trap worth recording.** The signer test file first ran as "Executed 0 tests — TEST SUCCEEDED":
a new file under `Tests/` is not in the target until `xcodegen generate` has run, and an absent test
passes silently. `check-tests-registered.py` guards bundles against the scheme, not files against a
target, so the only signal is the count.

## 2026-08-23 (F-454) — Writing to S3, and four tests that were green for the wrong reason

The write half of the S3 plugin: upload (with multipart), new folder, new bucket, delete an object,
delete a folder, delete a bucket, rename and move — including across buckets. `PfxGetCapabilities`
now returns `READ | WRITE | RENAME`, which with F-452 in place means F5, F6, F7 and F8 all reach the
server from the keyboard.

**The three things S3 does not have, and what stands in for each.** No directories: a folder is a
common prefix inferred from keys, or a zero-byte object whose key ends in `/`. So creating one writes
that marker, and deleting one has to delete every key beneath it, because there is nothing else to
delete. No rename: a move is a server-side copy followed by a delete, and a folder move is that for
every key under the prefix — non-atomic by construction, which is why a failure part-way through is
reported rather than retried into a half-moved state. No append, and a 5 GiB ceiling on one PUT:
above that, multipart.

**`PfxDelete` has to decide what something is before touching it.** A DELETE on a key that does not
exist answers 204 — success. So a plugin that treats a folder as an object reports the folder deleted
and removes nothing, and every object inside it is still there. The kind is settled first, with a
`max-keys=1` listing, and only then does anything get deleted.

**Two places where S3 answers 200 and means no.** `CompleteMultipartUpload` keeps the connection open
while it assembles the object and writes an `<Error>` document into a *successful* response;
`CopyObject` does the same. Reading only the status reports an object that does not exist as uploaded
— and for a move, the delete that follows would then lose the original. Both check the body of a 200.

**Orphaned multipart parts are the failure that costs money.** Parts of an upload that was neither
completed nor aborted stay in the bucket, are billed, and appear in no listing. Every failure path
aborts: a refused part, a read error on the source, a cancel, an empty part list, a late failure in
Complete. The fixture grew `GET /<bucket>?uploads` — the real API — so a test can *prove* nothing was
left rather than trust that it was not.

**Batch delete needs Content-MD5, and its result is in the body.** It is the only request in the
plugin that needs MD5 at all (S3 rejects the call outright without it), and it answers 200 even when
it deleted nothing — the per-key outcomes are in `<DeleteResult>`. The fixture enforces both, because
a client that omits the header works against a lenient fixture and fails against AWS.

**CreateBucket's LocationConstraint is the most common way a first bucket fails.** `us-east-1` must
NOT send one and every other region must. Both directions are wrong, and the fixture checks both.

### Four tests that were green for the wrong reason

The run that found these is the more useful half of the day.

**"** TEST SUCCEEDED **" with compiler errors in the log.** `S3Write.swift` was missing from
`Tools/build-s3-plugin.sh` and from the test's own source list. The build script failure was obvious.
The test one was not: the plugin build in `S3PluginTests` turned a non-zero `swiftc` into
`throw XCTSkip`, so every test in the file skipped and the suite reported success. The skip exists for
a machine with no compiler — which `isExecutableFile` has already established by that point. A
compiler that *ran and refused the plugin* is a failure. Fixed here and in the three other files with
the same copied guard (`WebDAVPluginTests`, `PFXFileSystemTests`, `TaskManagerPluginTests`), so none
of them can pass by not running again.

**A new gate for the cause: `Tools/check-plugin-sources.py`.** Plugins are not built by Xcode; each
is a `swiftc` invocation in a shell script with its sources listed by hand. A file in
`Plugins/<Name>/` that no script compiles is simply not in the plugin — and if something needs it the
build fails pointing at the *caller*, which reads as a typo there rather than as an absent file. In
CI, before the build. Writing it found a bug in itself first: the pattern stopped at the first slash
and reported all twenty-nine of FSImage's `Support/` and `Drivers/` sources as missing.

**A multipart test that only ever sent one part.** `partSize` keeps S3's 5 MiB floor, so lowering
`PC_S3_MULTIPART_THRESHOLD` to 1 KiB still put a 20 000-byte file in a single part: the multipart code
ran, produced one part, and proved nothing about reassembly — and the abort test could not fail part
two because there was no part two. `PC_S3_PART_SIZE` is now a separate seam, and the success test
asserts it is really sending more than one part, so it cannot go back to measuring a plain PUT.

**A folder that came back after being deleted.** The fixture stored a prefix marker as an empty
directory, since a file whose name ends in `/` cannot exist. That reads correctly and writes wrongly:
deleting the last object out of a folder left an empty directory, which the key walk then reported as
a marker — so a just-deleted folder was still listed, and so was the source of a just-moved one. Real
S3 has no marker unless one was created, so an emptied prefix stops existing; the fixture now prunes.

**A conformance assertion the compiler answered.** `XCTAssertTrue(fs is ResumableFileUploading)` on a
concrete `PFXFileSystem` is statically true — the compiler says so with a warning — so it would pass
whatever the runtime did. Asked through a `VirtualFileSystem`-typed value now, which is also how
`PanelController` actually holds it.

**Evidence.** `S3PluginTests` is 39 tests and `S3SignerTests` 2 — **41 tests, 0 failures**. New in
this wave: upload, upload-over-existing, upload of a key with a space and a `+`, a five-part multipart
upload whose bytes come back byte-identical, a multipart whose second part is refused leaving no open
upload and no assembled object, new folder, new bucket, delete an object, delete a folder *and* its
contents, delete an empty bucket, a non-empty bucket refused, rename, rename-as-move, rename across
buckets, rename a folder with every key under it, and a bucket rename refused rather than faked.
`check-plugin-sources`, `verify-shipping`, `check-plugin-translations`, `check-tests-registered`,
`check-strings-extracted`, `check-format-specifiers`, `check-inventory` and `check-sdk-headers` green.

**Still behind `PCPluginIncomplete`**: `~/.aws` profiles, region redirects, retry/backoff, Glacier,
content columns, presigned links, the Docker/MinIO conformance suite, eighteen translations and a
help topic.

## 2026-08-20 (F-433) — The assistant's error message named the wrong cause

Reported: the AI assistant answers "um was geht die aktuell markierte Datei?" with "the on-device model
produced an invalid tool call. Try rephrasing it more simply". Reproduced against the real on-device model
in `LiveNativeToolTests`, and the message was wrong in the way that matters — it sent the user off to fix
their phrasing when nothing about the phrasing was the problem.

`AppleNativeToolSession.send` mapped **every** thrown `GenerationError` to that one sentence. The error
actually raised is `unsupportedLanguageOrLocale`: Apple's on-device model screens its *input*, and every
message the chat sends is prefixed by `ChatComposer`'s context header naming the active folder. A header
dominated by an opaque path does not read to it as natural language and the turn is refused before a tool
is ever chosen. Measured: with the folder path in the header, rejected 3/3; the identical German question
without it, answered. Not language-specific — the English question was rejected the same way. Nor is it
exotic: the shape is any temp, DerivedData, or UUID- or hash-named directory.

Two more things were wrong behind it. The retry resent the *identical* prompt into the same session, so a
deterministic input rejection failed twice by construction — the loop existed but could never recover.
And the raw error was logged under `#if DEBUG` only, so a shipped build kept no record of which of the
eight failure kinds had occurred.

The retry now sends a form that can succeed: `ChatComposer.stripPaths` keeps the header's *names* and drops
the paths. That combination was chosen by measurement rather than taste — names kept, paths dropped: 5/5
answered; whole header dropped: accepted by the guardrail but 0/5 answered, the model having nothing left to
read; folder reduced to its last component: accepted, 0/5, the UUID name being no more readable than the
path. Each failure kind now carries its own message (a full context window says start a new chat; assets
still downloading say so; a retry that cannot help is not attempted), and the cause goes to `OSLog` in every
build. Regression test asserts the reported turn recovers *and* answers from the file; 3/3 locally.

## 2026-08-20 (F-434) — The assistant review, implemented

A fachlich/technisch review of the AI plugin (published separately) found the core sound and the
layer above it thin, and named twelve things in priority order. All of them are in, plus three
defects the work uncovered. What the review measured is what drove the order.

**The one that mattered.** `read_file` defaulted to 64 KB into a context window that holds about
4 KB. Measured against the real model: 2 KB and 4 KB slices are summarised correctly, 8 KB and above
throw `exceededContextWindowSize` — so "summarise this file", the most used skill, failed on the
*first* message for any document past about six kilobytes, and the message it failed with told the
user to start a new chat. There is now a `summarize_file` tool that reads a file in 4 KB slices and
folds the slice summaries in Swift, one fresh session per slice, so no generation ever sees more than
a slice. A 38 KB report now comes back summarised **including a sentence planted in its last
section** — the check that distinguishes a real fold from a summary of the first page. Regression
test asserts it live. A conversation that fills the window is folded into a summary and continued
rather than ended.

**Tool parity and gating.** The native (on-device) path offered 24 of the catalogue's 28 tools:
`semantic_search`, `remember`, `recall` and `run_shell` existed only for the cloud path, so the
*default* provider was the poorer one and had no memory at all. The list is now derived from
`AutomationCatalog` and filtered by the session's `PermissionPolicy`, so read-only offers no writes
instead of offering them and refusing them — on a small model, a round of doomed attempts is the
budget for the answer. A test asserts catalogue/native parity so the two cannot drift again.

**Three defects the work turned up, none of them in the review.**
1. `copy` and `move` enqueued a transfer and returned immediately, so the tool reported success
   before a byte moved — and the undo I was building would have taken back a move still in flight.
   Both wait now; `TransferManager.enqueue` grew an `onFinish` because `onComplete` fires only on
   success and a caller waiting on it would wait forever on a failure.
2. The truncation note appended to a `read_file` result broke the JSON the folding parses, so the
   slice loop stopped after one slice and "summarised" the beginning of the file. Found by counting
   `read_file` calls in the live run: one, where ten were expected. Model-facing notes and
   machine-facing payloads are separate calls now (`run` vs `runRaw`).
3. My own first cut of the semantic-search cutoff (`max(best * 0.7, 0.2)`) filtered out the best
   match whenever the whole folder scored low, i.e. it answered "nothing matches" when something
   did. Relative to the best match only, and the best match is always returned.

**What the small model gets wrong, compensated rather than lectured.** Asked "which file is about
the roof repair" it calls `search` with the subject in the *file-name mask* — sometimes in `mask`
and `text` both. The honest answer to that ("no file has that name") is useless. A mask that is a
bare word rather than a pattern is now read as what is being looked for. 3 of 4 live runs answer
correctly; the fourth passed correct arguments and still lost the result, which is the model.

**Trust.** Every executed action is recorded (`aichat/actions.jsonl`) at the single point in
`DefaultAutomationCore` where a tool runs, so the chat, an MCP agent and a plugin tool are all
covered by construction. Refused attempts are recorded too — an attempt to delete that the policy
stopped is exactly what someone opens the log to find. Undo is offered only where an inverse
genuinely exists (rename, move) and states the reason where it does not; the undo does not itself
become undoable, or the button ping-pongs. Both are catalogue tools rather than UI-only, so no new
plugin ABI was needed and the model can be asked to undo.

**The rest, briefly.** Markdown is rendered in the chat (real `NSTextTable` tables — the transcript
had to move to TextKit 1 for that; verified in the running app, screenshot in the review); "Suggest a
name" ends in a Rename button rather than a sentence to retype; an "AI ▸" action runs over a whole
selection with progress and Stop; `SkillStore` is finally wired, so the prompts are editable data;
the file-system tools left the main actor and hashing is streamed; the MCP server takes the autonomy
setting; a model change in Settings rebuilds the chat instead of being ignored until restart; the
event bus emits all eight of its declared kinds (it emitted two); the AI column shows the
assistant's summaries and its language field is no longer called "AI".

**Localisation.** 20 new user-facing strings, all 18 target languages, catalogue and
`Tools/translations/` both. One self-check worth keeping: a scan for CJK characters in non-CJK
languages caught a stray 長 in the Russian string I had just written.

**The one I had deferred, done differently.** A skill the user invents had no way to be *invoked*:
the host builds plugin menus from the bundle's Info.plist without loading the plugin (deliberately),
so a new entry looked like it needed a sidecar manifest and a directory watcher. It does not. A
command declaration can now say its family is open (`acceptsSuffix`), and an id extending it by one
component dispatches to the same plugin — so `plugin.ai.skill.<own-id>` works from the user menu,
the button bar or a keyboard shortcut, three places where a user can already name a command. Opt-in
per declaration, exact matches always win, one level deep only, and the rule lives in `PCPluginHost`
as a pure function with nine tests including one against the shipped manifest. Verified end to end:
a `zaehle-zeilen` skill written into `skills.json` and invoked by id reached the model with the right
file. No ABI change, no watcher, and it composes with three existing customisation mechanisms
instead of adding a fourth.

**Two more of my own, found by measuring rather than reading.** `summarize_file` folds through
prompts written in English, and the model relays the language it is handed: a German file came back
summarised in English **4 of 4 times**, to a user who had asked in German. Asking for "the same
language as the text" did not fix it — it made things worse (one empty answer, one answer *about*
the text) — so the language is detected with `NLLanguageRecognizer` and named: " Write in German."
4 of 4 in German afterwards, pinned by a live test plus deterministic tests for the detection. And
the chat's two-minute watchdog, which is right for a hung model, is wrong for a turn that reads a
40 KB file slice by slice: progress re-arms it now, and the status line counts the slices. That
also turned up three stale entries in the activity map (`write_file`, `merge_files`, `set_comment`
said "working…") and one that could never match, because it named `stat` after the tool had been
renamed to `stat_path`.

**Still not done, and now recorded as such.** The help pages for the other 17 languages describe
the assistant before this work. I had written that "the gate only checks that a page exists per
topic" — that is true of `check-translations.py` and wrong about the project: there is a second gate,
`check-translation-drift.py`, which compares the *structure* of every translated page against the
English one, and my change had turned it red with exactly those 17 pages. It is now green again the
way this project already handles the case: `docs/metadata/translation-drift-allow.json` carries an
entry per language with the reason, counted as accepted rather than hidden (`drifted=0
accepted=102`). The precedent is the Git plugin page, rewritten for 0.7.2 in English and German with
the other languages recorded the same way — so the project has already answered this question, and
its answer is to owe the translation rather than to machine-translate twelve thousand words of prose
nobody here can check. The allow entry lists exactly the 17 that drift: not German, which the same
gate confirms is structurally in step, and no spare languages, because an over-broad entry would
swallow the next real gap.

Worth noting how the German gap was found at all: the page silently missed a whole section because
my insertion anchored on the English heading and I had written that one replacement without an
assertion — the others had one and would have failed loudly.

## 2026-08-19 (F-432) — Why the plugin build warned

Twenty-eight lines, four causes, each printed twice per architecture. Three causes were ours, two of them
mine from the last two days: a `?? true` that could never run (comparing an `Optional<Int32>` with `0`
already yields a Bool, and nil compares unequal — which *is* the "older host, keep going" answer), and two
places handing `PcHostServices` across a queue. That struct is a C table of function pointers and cannot be
made `Sendable` from a plugin; the capture is sound for the reasons F-422 documents, so the reasoning now
sits in one `ServicesBox: @unchecked Sendable` rather than in warnings that become errors under the Swift 6
language mode. The third was older: the decompiler's Save-As panel still used `allowedFileTypes`, deprecated
in macOS 12.

The remaining eight lines are SwiftTerm's, a pinned dependency. Left alone on purpose — suppressing a
dependency's warnings suppresses the next real one too, and it is not ours to police.

## 2026-08-19 (F-431) — "the side panel is not nice in dark mode": it was white

The Git panel *had* an `applyTheme()`. It asked for `theme.listBackground` and `theme.listText` — two keys
the host does not publish (semantic names are `theme.background`/`theme.text`, raw ones
`theme.color.<name>`), so every call failed, the `.controlBackgroundColor` fallback painted it white in all
three dark palettes, and the labels' `.labelColor` went white on top. A silent fallback is how a themed view
ends up unthemed while looking deliberate in code review.

The five Git windows were worse: `PluginTheme.swift` was not compiled into the plugin at all. All six now use
it, and the plugin exports `PcNotifyThemeChanged` — without it a window keeps the palette it opened under,
and the panel would never follow a change.

**The lesson is about the tool, not the colours.** The surface-colour audit had been printing
`GitPanelView bg=#FFFFFF luminance=1.00` and `text=#FFFFFF on #FFFFFF ratio=1.0` since the panel shipped;
nobody had asked it about a view that has to be *mounted* first. The VM scenario now mounts the Git panel
before auditing. Its `windows=32` expectation stays, because `findings=0` on its own is equally true of a run
that audited nothing — mounting a view adds no window.

Second pass, from the audit again: headers and the status line take the primary colour. `secondaryText` on
white is contrast 2.4, and putting every label on it traded a dark-mode defect for a light-mode one.

## 2026-08-19 (F-430) — The review, and the fix that had to be fixed

A high-effort review over everything since the 0.7.2 tag found nine things; all nine held up when checked
against the code, which is worth saying because the reflex is to argue with a reviewer.

**The one that mattered** was semantic, not cosmetic: the icon column's `symbolName\ttext` wire format was
undone where the cell is *drawn*, so the raw string sat in the value cache that sorting, copying, filtering
and the harness dump all read. Sorting a status column by SF Symbol name is the kind of defect nobody
reports because it merely looks arbitrary. It is now split once on the way in, in a tested helper — and
checking that found two consumers the review had missed: a rename placeholder would have put a tab into a
file name, and a Find Files criterion compared against the symbol name.

**The fix that had to be fixed:** the stale "which line was clicked" value. Consuming it on read looked
right until the read path turned out to be the same context menus are evaluated against; clearing it after
`contribInvokeCommand` looked right until `runCommandNamed` turned out to wrap the work in a Task — so the
line was gone before the plugin read it, and the gutter click silently stopped working. Measured, not
reasoned: the compare window simply did not appear. Awaiting the dispatch and clearing afterwards is what
holds.

The rest were the ordinary kind and all real: a PDF left drawn over a folder's icon, a zoom bar surviving a
fallback to Quick Look, a synchronous document read blocking the panel per file, tooltip rects outliving the
annotations that made them, a click hit test that ignored x, and an `@discardableResult` stranded on the
wrong function by an insertion — that last one the compiler had been saying all along.

## 2026-08-19 (F-429) — "PDF is no longer rendered", and a preview nobody could measure

Reported: PDF and DOCX no longer render in the preview, everything looks like markdown. The investigation
was the valuable part, because the answer was **that the old behaviour could not be observed at all**.
Everything except images went through `QLPreviewView`, which renders out of process: `cacheDisplay` returns
a uniform rectangle whether or not a page was drawn, so no measurement from inside the app can tell the two
apart. What could be established: the view was visible, correctly sized and held the right item; the
system's QuickLook renders those files (`qlmanage -t` gives thumbnails); and `FilePreviewView` had not
changed since before 0.7.0. Neither reproduced nor honestly deniable.

So the two formats a file manager is asked about most are now rendered **in process** — PDFKit for PDF (with
the zoom bar the image route already had), AppKit's document reader for Word/OpenDocument/RTF — and
QuickLook keeps the long tail. The point beyond the feature: a PDF page that is mostly ink now reports
`pdfpixels=distinct=2 sample=000000,FFFFFF`, which is proof that it is *drawn*. A preview that cannot be
measured is a preview that cannot be defended.

Made switchable on request: `Viewer.RenderDocumentsInApp` (on by default) in *Configuration ▸ Edit/View*, applied to the previews already open rather than only to the next file.

Two traps for the notebook. PDFKit computes its fitting scale only after it has both the document and the
size, and announces it by notification — without observing that, the level label read 100 % beside a page
drawn at 45 %. And a `//` comment inside a multiline Swift string is *text*: mine went straight into the
harness report, where it sat in the middle of a line of measurements.

And two of my own process errors, both cheap to avoid: a gate's output must not be piped through `tail -1` (that is how the third copy of `pdx.h` reached CI unnoticed — `Sources/CPDX/include/` alongside `Plugins/SDK/` and the plugin SDK package), and the shipped **Help Book has to be rebuilt and committed** when a help page changes. Rebuilding it locally also needs the *pinned* `pygments==2.21.0` from `docs.yml`: with 2.20 every code block re-escapes `"` as `&quot;`, which turns four changed pages into sixty-one. The search indexes are non-deterministic, which is why the workflow compares `':!*.helpindex'` — so they stay out of the commit.

## 2026-08-19 (F-428) — The last two §6 items, and a help page that had drifted further than expected

Localized column headers and the icon field, in one pass because they are the same piece of ABI. The headers
were the interesting half: the field *name* is what the field id is derived from, and that id keys saved
column sets — so the id must not move with the language and the header must. An optional export
(`ContentGetSupportedFieldTitle`) carries the title; absent, the name stays the header, which is what every
existing plugin gets.

**The trap worth remembering:** the host resolves plugin symbols through an allow-list (`PDXSymbols`), so the
new export was invisible until it was listed there. Everything else was right and the header stayed English —
which is exactly the shape of defect that reads as "the feature does not work".

The icon rides on the units string (`"icon"` → value `symbolName\ttext`), following the `"badge"` precedent
Notes already set, and the panel cell has to *clear* the symbol on recycled cells or a conflict marker walks
down the list while scrolling. Git's glyph moved to the status dialog, which is text and where it still helps.

**Found on the way, and bigger than the feature:** `docs/content/help/git.md` still described the
five-command plugin of 0.7.0, including a paragraph that was outright wrong (`git commit -a`, changed in
F-416). English and German are rewritten; the other seventeen are recorded in
`docs/metadata/translation-drift-allow.json` with the reason naming it as debt rather than as a deliberate
deviation — the drift check keeps reporting it, which is the point.

## 2026-08-19 (F-426, F-427) — Blame where the code is, and a menu read as a menu

The last of the three host items the Git plan named: `annotateLines`, a service for putting one line of text
next to every source line. The gutter belongs to the host's editor, so a plugin could never draw blame there
— and the alternative, a plugin shipping its own text view, is a second editor in the same application.

Three decisions worth keeping. The **wire format is the interface** (one record per line, `text\ttooltip`),
so it is parsed in one tested place — and the test earned itself immediately: the first Git side put the
commit subject into the tooltip *with a newline*, which splits a record in two and shifts every annotation
after it against the line it describes. That reads as blame being wrong, not as a format defect. The
**click is a command, not a callback**: the plugin passes a command id, the host invokes it and exposes the
line through `getContext`, so no function pointer crosses the ABI and nothing can call into a plugin that
has gone away. And the host **finds the editor already showing the file** rather than opening a second one.

Then it bit its own author: declaring the click command `"async": true` crashed the app on the first click,
because `MainActor.assumeIsolated` off the main thread traps — which is exactly rule one of the
asynchronous-command section *I wrote* in PORTING.md four commits earlier. The crash report named it in one
line; the fix was removing one key.

F-427 was the leftover polish: every contributed title was checked against every surface that renders one
(the two `Git` submenus — the button-bar editor lists internal names), which made the `Git ` prefix
redundant everywhere it appeared. Ten titles normalized, the menu reordered out of its append order, ten
stale keys pruned from nineteen languages.

## 2026-08-19 (F-424, F-425) — Reviewing the plugin as somebody who has to use it

Asked to check the Git plugin functionally *and* as an interface. Going through it as a user rather than as
its author found one uniform gap and two functional ones.

**The uniform gap: it could only be operated with the left mouse button.** Not one of the six views had a
context menu, none had any keyboard handling, and five of six had no reload — so a commit made in a
terminal left a window quietly stale. Context menus, Return as the primary action and Cmd+R everywhere are
F-424, and the detail that matters is that a right-click now *selects the row under the cursor first*:
without that, a menu acts on the previous selection, which is how somebody reverts the wrong commit.

**Functionally, tags were missing entirely** — the plan said "branch and tag list" in phase 3 and the ref
query only ever asked for `refs/heads refs/remotes`, so releases were invisible. And the **history did not
show where any ref was**, because `%D` was never in the log format. Both are F-425; the decoration is
appended as a seventh field so no existing index moves, since a shifted field is precisely the defect
`parseStatus` had with renames.

Also caught by reading the text rather than the code: the rebase confirmation warned about force-pushing
other people's history, while the list it confirms is `upstream..HEAD` — by construction the commits nobody
else has. A warning that does not apply is one a reader learns to click through.

## 2026-08-18 (F-423) — The bounded rebase, and why it is bounded

The last of the four "out of scope" items, built as the narrow version phase 5 argued for: the commits
ahead of the upstream, with pick/reword/squash/fixup/drop and reordering. The enabling trick is that git
runs `$GIT_SEQUENCE_EDITOR <todo>`, so `cp <ours>` hands it a todo file the window wrote — no editor
process, no terminal — and `GIT_EDITOR=true` accepts the message git pre-filled, which is what a squash
needs. Only one reword per run, stated rather than hidden: each invocation would be handed the same file,
so two rewords would silently give both commits the same message.

Two things worth keeping. The todo file is **oldest first**, the opposite of `log` order — getting that
backwards yields a rebase that succeeds and reorders the branch wrongly, which is the worst failure mode
available here, so it has its own test. And there is **no cancel** for the run: git's sequencer cannot be
killed safely mid-flight, and what it leaves behind is precisely the state Abort undoes — so the
half-finished case became a feature of the same window (Continue / Skip / Abort), which is the part the
reference products tend to leave to the terminal.

## 2026-08-18 (F-422) — Asynchronous plugin commands, and two traps one level apart

§6.3 of the Git plan, which everything else in phase 5d was waiting on. A contributed command ran on the
main thread; for a `push` that means the application stops redrawing until the network gives up. Now a
command can declare `"async": true` and the host runs it on a background thread with three progress
services (`beginProgress`/`updateProgress`/`endProgress`), where `updateProgress` returning 0 is how a
Cancel reaches the plugin. Cooperative by design — the host cannot kill a call inside a plugin, and the
header says so instead of implying otherwise.

**Trap one: the host bridge could not be called off the main thread at all.** Every service was written as
`MainActor.assumeIsolated`, which was an honest assertion while every command ran on main — and off-main it
does not return false or misbehave, it *traps*. The first asynchronous plugin asking for the cursor path
would have taken the whole application down. `ContribHostBridge.onMain` now asserts when already on main
and hops-and-waits when not; that cannot deadlock precisely because an asynchronous command is not the
thing blocking main.

**Trap two, one level up: dispatch must not await the command.** Awaiting felt more honest — the caller
learns when it is over — and it moved the block from the main thread to whoever called dispatch. Measured:
the automation harness sat for five minutes on a push to an unroutable host while the window beside it drew
perfectly. Nobody needs the completion; the progress window is the feedback.

Verification worth keeping: `PCGitExecutable` pointed at a shell script that is slow **only for `push`** and
delegates everything else to the real git — the first attempt was slow for every call, including the
`rev-parse` the columns make, which looks exactly like a hung application. And the harness needed a real
verb (`plugincancel`): a synthesised Escape does not reach a button's `keyEquivalent`, so `keysend escape`
reported success while the command kept running.

## 2026-08-18 (F-420) — The four things that were "out of scope", asked about directly

Asked what I made of interactive rebase, an own merge editor, a credential store and GitHub/GitLab
integration — the four the plan had waved off. Re-examined rather than re-quoted, and two of the four have
a bounded version worth building (plan §5, phase 5).

The first of them is built: **a conflict resolver on the file's own markers** (5a). It closes something
phase 3 left open — the conflict command showed the two sides and then left `<<<<<<<` in the file, so the
resolution itself happened in a terminal. What decided the design was less the UI than the refusals: a
marker set that does not parse is refused rather than guessed at, staging is refused while a region is
still open (git commits markers without complaint), and a non-UTF-8 file is sent to the editor rather than
silently re-encoded by a resolver.

5b and 5c followed the same day (F-421): the credential *report* — transport, helper, and whether an SSH
agent answered and held a key, where `ssh-add -l`'s exit code 1 vs 2 is the difference between "add a key"
and "start an agent" — with exactly one action, setting git's own `credential.helper` to `osxkeychain`; and
"open on the web" for a file, commit or branch, built from the remote URL for the four services whose shape
is known, with the repository page (after asking) for any other host. Worth remembering from the
verification: on this Mac `git config --get credential.helper` answers `osxkeychain` from the *system*
config even though the global one is empty — the report is about what git will really do, which is why it
reads the effective value rather than the global one.

Still deliberately **not** built: a merge editor with base and result panes, credential *storage* of any
kind (note that `PcHostServices.crypt` exists and is still the wrong tool, because git looks credentials up
by URL and owns their lifetime), and the GitHub/GitLab API. 5d — rebase bounded to the commits ahead of the upstream — turned out not to be
blocked by what I assumed: git runs `$GIT_SEQUENCE_EDITOR <todo>`, so `cp <our-todo>` hands it a todo list
with no editor process at all. What it needs is the *in-progress* state (Continue / Skip / Abort) and §6.3.

## 2026-08-18 (F-415…F-419) — The Git plugin, assessed and then built out in five stages

Asked to judge the plugin technically *and* functionally before extending it, so
`docs/analysis/git-plugin-plan.md` came first: what exists, what is wrong with it, what the reference
products (TortoiseGit, GitFinder, Git Extensions) do that matters in a file manager, and five phases that
each ship on their own. Third-party components were allowed if the licence fits — none was needed. git
plumbing (`--porcelain=v2 -z`, `for-each-ref --format`, `blame --porcelain`) is a stable interface, and
libgit2 would have added a dependency to parse output we already parse correctly.

**What that assessment found** was mostly not "missing features": the column reported the parent
repository's status for a file in a subdirectory, a rename shifted every status after it by one record, a
non-ASCII path came back quoted and blank, and `push` could wait forever on a terminal this process does
not have. Those were phase 0.

**Phases 1–3** then added the panel, the history with a lane graph, blame, and branches/stashes/sync —
with the compare window borrowed from the host (`compareFiles`, the one host-side addition) so the
application still has exactly one diff.

**Phase 4** finished it, and two of its five planned bullets were argued down rather than built. Status
*icons* became a leading *glyph*, because the content ABI returns strings and a glyph buys the scanning
benefit without an ABI change. Per-repository settings were dropped outright: git already stores
`pull.ff` and `remote.pushDefault` per repository, and a second place to set them can only disagree with
the first. What phase 4 did build: `.gitignore` from the context menu, revert and cherry-pick with an
up-front refusal on a dirty tree, and the fix behind "submodule and worktree awareness" — `.git` is a
*file* in both, so the cache was watching an index path that does not exist and an outside commit reached
the column only when the TTL expired.

**Two things worth remembering.** A vertical `NSStackView` aligns `.centerX`: every window in this plugin
drew its content in a strip down the middle, and `alignment = .width` alone does not stretch a split or
scroll view — the children that must fill say so explicitly now. And `a11ydump` does not enumerate a
stack view's children, so "the buttons are not in the tree" was not evidence that the buttons were
missing; their frames were.

## 2026-08-18 (F-410…F-413) — Four reports, and the two that were worse than they sounded

Four things asked for in one message. Two were what they looked like; two turned out to be data loss with
a cosmetic-sounding symptom.

**F-410 — the outline for Markdown in the viewer.** Reported as "not expandable in the viewer, expandable
in the editor". The sidebar is built from a text view and the viewer's normal representation for Markdown
is the *rendered page*, so the outline was cleared and the toggle went dead (`symboltoggle=disabled`,
measured). It is built from the source now — which is right there, already bounded by the render cap —
while navigating goes to an element in the page: every heading gets an `id`, produced by the render pass
rather than a second scan (two scans that disagree about a `#` inside a fenced block would send the reader
to the wrong place), and the scroll goes through `evaluateJavaScript`, which the host may run although the
page may not — `allowsContentJavaScript` stays off and the CSP stays `default-src 'none'`. The second
defect was underneath: **`Titel` over `===` was rendered as a paragraph plus a horizontal rule**, so a form
the outline has always read (the repo's own README uses it) offered entries the page had no anchor for.

**F-411 — CSV without a header line.** Not just "the wrong titles": the first line became the column
headers, so **the first record was gone from the table** — not filterable, not sortable, not findable, and
nothing on screen said so or could undo it. There is no marker in the format, so the reader gets a guess
and a checkbox to overrule it. The guess is four rules, each something a header row does not do; what it
deliberately does *not* do is compare the first line's types against the rows below, which reads like the
better rule and fails on the file this exists for — a table of strings only. Parsing and the guess moved to
`Plugins/SDK/PluginCSV.swift`, compiled into the plugin *and* into PCFoundationTests, because reaching the
view through the PLX C ABI is no way to test a decision.

**F-412 — JSON Lines.** Highlighting, the outline, the paths and the transforms already knew the format.
The validator did not: it handed the whole file to a JSON parser, which reports the second record as
garbage after the end of the first, so **every valid `.jsonl` was marked broken**. It validates per record
now and names the first bad one by its own line. And there was no formatter at all — the safer half, since
the JSON one would have pretty-printed the file into something that is no longer JSON Lines;
`JSONLinesFormatter` normalises each record and keeps one per line. The outline names records by the line
they start on rather than counting documents.

**F-413 — the 0-byte suspicion in the filesystem-image plugin**, offered as "I am not sure, test it". It
was right. In cpio/initramfs — the format firmware ships in — `newc` stores the bytes with the *last*
hardlink and writes `filesize 0` in the earlier ones' headers. The driver resolved the data through the
inode, so the file *opened* with its full contents, and kept the 0 as its size: what the status bar sums,
what a copy's progress is measured against and what "larger than" filters on. Found by measuring rather
than by reading: a new sweep walks every image the tests can build — sixteen committed fixtures plus
ext2/3/4 (including `inline_data`, where a small file has no blocks at all), SquashFS gzip/zstd and cpio —
and holds every file's listed size against the bytes it reads. The sweep found **nothing**, which is what
sent the search to what the sample tree has none of. With the fix removed the dedicated test reports 0
against 37 for two of three names.

**F-414 — and then the reader pressed Format on a real 2 MB `.jsonl` and the window froze.** Diagnosed in
the live process: a sample showed the main thread inside scroller tracking, 80% of it in
`String.append(contentsOf:)` under `CodeListerView.attributedLine` — which asked
`String(lineChars[0..<lo]).utf16.count` once per syntax token, copying the line's prefix every time.
Quadratic, in drawing code, on the main thread. The file (a Jira health log: thirty records of ~68,000
characters) needed **193,934 ms to build thirty lines; 126 ms after the fix**, measured both ways by
reverting it. `UTF16OffsetTable` walks a line once and skips the table entirely when every character is one
UTF-16 unit; the diff window's highlighter had the same line and the same fix. Two defects had to line up:
the post-format path also **ignored the size thresholds** the Code representation applies and put any
formatted text into the materialising view. Note what made this findable at all — the JSON Lines formatter
from F-412 is what made Format *work* on that file; before it, the button refused and the freeze was out of
reach.

Verified in the running app, not only by unit test, and four verbs exist now because a dump could not
answer the question: `listersymbol` (drives the viewer's outline and reports where the page ended up),
`editformat` (reports *which* formatter ran — for `.jsonl` the text alone would not say) and
`editvalidate` (reports the problem's line, not the translated sentence) and `listerformat` (formats and
draws, reporting both times *and* the line-building cost — `display()` draws only the visible rect and
would have reported 0 ms for an off-screen window, which is a measurement that looks like a fix). New VM scenarios:
`viewer-md-outline`, `csv-no-header`, `jsonl`. New tests: `MarkdownRendererTests` (+8), `PluginCSVTests`
(14), `JSONLinesTests` (12), two size sweeps and the hardlink case in `FSImagePluginTests`.

## 2026-08-18 (F-257) — The .mnu format was supported on paper, and four things stopped it working

The question was whether Total Commander's `.mnu` main-menu format is fully supported, placeholders
included. The parser, the builder and the editor command were all there and the inventory said `done`;
none of what follows was visible from the outside, which is why I19 T09 had been left as "to reconcile".

* **A `.mnu` from TC never loaded at all.** It was read with `try? String(contentsOf:encoding:.utf8)`,
  and a TC menu file is ANSI (Windows-1252) or UTF-16 with a BOM — so the read returned nil, which this
  code could not tell apart from "the user has no menu file". A German `wcmd_deu.mnu` silently produced
  the built-in menu. `WindowsTextFile` now decodes BOM → UTF-8 → code page, and is used for every format
  shared with TC: `.mnu`, `.bar`, `usercmd.ini`, `wincmd.ini` (whose importer reported "could not be
  read" for perfectly good files) and the referenced-bar path inside the importer.
* **And once decoded it parsed as nothing.** `split(separator: "\n")` does not split a CRLF file in
  Swift, because `"\r\n"` is a single Character — the seventh, eighth, ninth and tenth defects of that
  one trap in this repo. The whole file arrived as one line whose keyword was POPUP: one empty menu. The
  same line stood in `UserCommands` (a TC `usercmd.ini` yielded **no** user commands), `Keymap`,
  `AliasStore` and `FileAssociations`; all five now split on `isNewline`, as `INIDocument` already did.
* **An `em_` menu entry did nothing** — and `em_` is the only way a `%P`/`%N` parameter reaches a menu
  entry, since only user commands carry a command line. `runMenuCommand` sent every name to the cm_
  registry, which logged "Unknown command". The placeholder engine itself (`ParamExpander`, `%P %N %T %M
  %S %L %F %D %W %%`) was complete and is unchanged.
* **An unknown command looked live.** TC has several hundred numeric command ids and this registry ~150,
  so an imported menu file has entries that resolve to nothing. The token was passed through as the
  item's command, where the enable pass ignored it for not starting with `cm_`: an enabled entry that
  swallowed the click. Now such an item has no action and is greyed out, an `em_` name absent from
  `usercmd.ini` likewise, and both are named in the log — as is every line the lenient parser skips
  (`MenuFile.parse` returns a diagnostic per line, so the report says `default.mnu:16: unknownLine`).
* **The Start menu emptied itself under a user `.mnu`.** Its items were injected by looking for a
  submenu titled `"Start"` — a hardcoded English string, while the built-in title is localized
  ("Starter") and a user's menu file can call it anything. The popup is now found by the item carrying
  `cm_ChangeStartMenu`, only the injected items are replaced (`removeAllItems()` deleted the user's own
  entries from their own Start popup), and a rebuild re-injects them instead of leaving the menu bare
  until `usercmd.ini` happened to change.

Deliberately **not** done, and recorded on the F-257 row rather than left to look like an omission: the
`\tF3` accelerator hint in a caption stays ignored, because the keymap is this app's single source for
shortcuts and a label out of the file would state a key that may not be bound; numeric ids stay aligned
with TC's only where a 1:1 command exists (a full TOTALCMD.INC table would be several hundred ids for
commands that do not exist here, and nothing in the app refers to a command by number except this
parser); and there is no Load/Save/Restore dialog like TC's, because `menus/*.mnu` covers dropping a
file in and deleting `default.mnu` restores the built-in menu.

Verified in the running app, not only by unit test: a CP1252 + CRLF `default.mnu` with a renamed
"&Starter" popup, an `em_` command from a CP1252 `usercmd.ini` and a numeric id this app does not have —
`menudump` shows the umlauts intact, `540` resolved to `cm_RereadSource`, `2400` disabled, the unknown
`em_` disabled, the known one enabled, and the user command injected above "Startmenü ändern…" with the
user's own entries untouched. New tests: `WindowsTextFileTests`, `MnuMenuTests` (PCKeyboardTests now
compiles `MnuMenuBuilder`/`KeymapMenu` in, as PCThemeTests does with Theme), plus the diagnostics,
quote-in-caption and CRLF cases in `MenuFileTests` and one CRLF test per parser fixed above.

**A dump cannot prove a click.** `menudump` shows an item's title, command and enabled state — all three
of which were *right* while the item did nothing, because it was wired to the wrong dispatcher. Two verbs
close that: `menuclick <cm_/em_ name>|<out>` invokes an item through its own target and action and reports
`found`/`enabled`/`sent`, and `reloadmenu` performs the re-read that until now only happened when the app
was activated (so a scenario can put a menu file in place and see it applied). The new `menu-file`
scenario in `regress.py` writes a TC menu file with `printf` — Windows-1252 bytes, CRLF, as TC writes it
— reloads, asserts the dump, clicks the `em_` item, and then deletes the file and asserts the built-in
menu is back (which is also the cleanup: a menu file left in `~/pc-cfg` would replace the bar for every
scenario after it). Its external check asks the guest's filesystem whether the program really ran with
`%P` expanded. **Run locally four times against the Debug build (the exact verb list read back out of
`regress.py`), not yet on the VM** — the one miss of five was on a machine loaded by a full test run, and
the wait after the click carries 2.5s for that reason.

## 2026-08-18 (VM harness) — The first full run in a fortnight, and the eight ways it was measuring wrong

The six scenarios written for F-406…F-409 were run on the VM, then the whole suite twice. **No product
defect came out of any of it.** The first full run failed 21 checks across seven scenarios; the last one
failed two, both already fixed by then and since verified. Every failure was the harness measuring the
wrong thing, and five of the eight had been latent for months — which is the point of running it.

* **A scenario claims every report key beginning with its own name and a dash.** `settings` therefore
  adopted all four `settings-search` reports and failed on files it never writes, while the real scenario
  passed later in the same run. Renamed to `search-settings`; the same trap had `editor-filter` adopting
  `editor-filter-dialog` (now `filter-dialog`), which nobody had noticed. `check-scenario-reports.py` now
  refuses the shape — and only a *full* run could ever have shown it, since the claiming scenario has to
  be in the same run.
* **The primary report must be the last file a scenario writes**, because the guest waits for that one and
  the app is stopped when it appears. `menu-key-guard`, `viewer-esc` and `swift-outline` had it in the
  middle; the gate had warned about all three for months, and this run turned the warnings into thirteen
  empty reports at once. Primary swapped in each.
* **A scenario with no report has nothing to wait for.** `toolbar-drop` and `session-save` read a config
  file after a fixed sleep and failed whenever the app was slow to launch — reported as "the drop is
  broken". Both write a report now (new `bardump` verb for the bar), and both pass.
* **`netpanel-watch` could never pass**: it idles sixty seconds on purpose and the guest waits at most
  settle + forty. Settle raised to 70; it now delivers the screenshot it exists for, which shows the macOS
  local-network consent panel up over the app about a minute after launch.
* **`keysend` compared its focus argument with `==`.** Every caller passes `field+menu`, so the field was
  never focused and `menu-key-guard` reported `responder=NSTabView` and `field=[]→[]` — which reads as the
  *dialog* being broken rather than as the harness never having clicked into it. The menu half of the same
  function had always used `contains`. With that one word fixed the scenario passes on the VM for the
  first time since it was written with F-404, all eight reports.
* **`tree-colours` and `theme-system` toggled state the guest remembers.** `cm_SrcTree` and
  `cm_TreeShared` flip; inherit "on" and the scenario turns the tree *off*, then audits a hidden, unpainted
  view and reports the app's colours as wrong. A new `treevisible` verb sets the state instead, and
  `theme-system` states its `Colors.Appearance` rather than inheriting `dark`, which had been
  short-circuiting the branch it exists to check.

Two diagnostics were added while chasing these and are worth keeping: `themestate` (what the theme
resolved to on both sides of the palette/appearance split) and the `focusField`/`focusTaken` lines in
`keysend` — the latter proved the Find dialog's new combo boxes take focus perfectly well, which is what
ruled out the obvious suspect.

**Left open, and not the harness's to fix:** the consent panel takes the key window when it appears, so a
keyboard scenario that runs into it reports `ERROR: no key window`. It is real — screenshots in
`docs/generated/layout-regression/` show it — and `netpanel-watch` now produces the picture that can name
which part of the app asks for the local network. Until that is answered, or the golden image answers the
prompt once, keyboard scenarios remain at its mercy.

The recorded output under `docs/generated/layout-regression/` is the final full run (110 scenarios, zero
Auto Layout conflicts everywhere) with `menu-key-guard` and `tree-colours` re-run afterwards against the
fixed harness; `report.md` counts conflicts only, so it is unaffected by that split.

## 2026-08-17 (F-409) — Switching to System kept the dark palette, and the repaint moved the page

**A named palette poisoned the answer to "is the OS dark" (F-409).** `systemIsDark()` read
`NSApp.effectiveAppearance`, which is the OS's answer only while the app has not overridden it — and
Midnight and Norton do override it. So Light → Midnight → **System** resolved the dark palette one last
time and then told the system to follow the OS: dark panels in a light window, until the next launch.
Light → Midnight → Light never showed it, because `light` is itself a palette and takes its darkness from
the palette. With an override in place the question now goes to the OS (`AppleInterfaceStyle`); clearing
the override and re-reading is not an option, because `effectiveAppearance` lags by a moment — the same lag
`systemAppearanceChanged` already works around. New `themestate` dump: after the switch it reported
`listBackground=#333333` (that is `Theme.dark`) with `appAppearance=follows OS`, and now reports `#FFFFFF`.

**Repainting the Settings sidebar threw the reader back to Layout (F-409).** `applyTheme` reloaded the
source list, and a reload on a list with `allowsEmptySelection = false` drops the selection, so AppKit
re-selected row 0 and the selection change mounted the first page — changing the theme *on the Colors page*
left you on Layout. Measured: row=4/Farben before, row=0/Layout after. The rows never needed the reload
(their text is `labelColor`, which follows the appearance); the search result list, which does paint its
own surface, is repainted on its own. The new `theme-system` scenario checks the invariant rather than a
colour — the palette and the system appearance must be on the same side of light/dark — so it holds
whichever mode the machine running it is in.

## 2026-08-17 (F-408) — Sixteen pages and no way to ask

**The Settings window can be searched by name now (F-408).** A field above both columns; while it has
text, the page area becomes the matches — the setting on one line, the page it lives on underneath —
picked with a click or ↑/↓ and Return, with Esc putting back the page the reader came from. Choosing one
opens its page and tints the control briefly. Two things had to be measured rather than reasoned about: a
focus ring is invisible on a checkbox unless Full Keyboard Access is on, and a tint animated the moment it
is added never appears at all (the animator sets the model alpha at once) — the screenshot said so while
the state said "tinted". The index is harvested from the *built pages* rather than written down beside
them, because a hand-kept name→page table is a second copy of the UI and would be wrong within a release;
it found 103 entries on the first run, including ones nobody would have listed. Notes under a control are
keywords for it rather than results of their own, and so are the words of the action it calls — which is
how "hidden" finds "Versteckte Dateien anzeigen" in a German UI. Matching is substring, deliberately not
the palette's `FuzzyMatch`: with fuzzy matching "hidden" returned "Eine Dateisuche im Betrachter
fortsetzen" and four more results whose only claim was containing h-i-d-d-e-n in order.

## 2026-08-17 (F-407) — A search you had to state twice

**Opening a hit now continues the search in the viewer (F-407).** A content search found the file, the
viewer opened at byte 0 with an empty find box, and the term that produced the window had to be typed
into it again. `ViewerSearchSeed` (PCVFS, so the translation is testable without a window) turns the
finished `SearchTemplate` into a viewer search — term, bytes, case, regex — and the viewer adopts it once:
the find bar shows it, the first hit is selected and on screen, and the keyboard goes back to the content
so the reader's first keystroke scrolls rather than edits the search. Consumed on first use, which is the
whole of "what you type afterwards stands" — no reload, no next file and no representation change puts the
seeded term back. Hex searches carry their parsed bytes while the field still reads `48 65 6C`; a
name-only search seeds nothing rather than prefilling a box with something that never matched; nothing
beeps when the representation on screen does not hold the term, because the term matched the *file* (a
comment match, or past the 16 MB text cap). Off by one checkbox on Settings ▸ Edit/View, applied live.
Verified in the running app on both search backends: line 25 selected in an NSTextView with the term in
the find bar, and a 14 MB log scrolled to byte 12,888,921.

**"Find text" no longer needs a tick box (F-407).** The field is the switch: something in it is searched
for, an empty one searches names only. The checkbox said nothing the field could not, one click later, and
it could disagree with it — "Case sensitive" greyed out with a term sitting right above it. The content
options now follow what is typed, through the field's own change notification; the scenario types through
the field editor on purpose, because assigning `stringValue` posts nothing and would pass with every
option dead. Turning the content search off is clearing the field, which F-406 made undoable in a way
unticking a box never was. The row moved to the same aligned "label: control" shape as the two above it, and the label column is now measured from the longest label rather than the 90 pt that fitted the English one: measured, that column is 94 pt in English, 103 in Russian and 114 in Hungarian, where "Szöveg keresése:" had been cut in half.

## 2026-08-17 (F-406) — The Find dialog forgot every term the moment it closed

**"Search for" and "Find text" now remember, most recently used first (F-406).** Twenty entries each, in a
dropdown on the field itself: both are `NSComboBox` now, which *is* an `NSTextField`, so the templates, the
automation verbs and everything else that reads those fields needed no change. Two lists, not one — a
dropdown offering `*.log` next to `TODO(` makes both fields worse. The list is `RecentLines`, lifted out of
`TextPipeHistory` (F-356) instead of written a second time, so promote-on-reuse and the 0600 permissions
cannot drift apart between the editor's filter history and this one; what somebody searches for is as
telling as the files it finds. Recorded on Start rather than per keystroke, and the content term only when
it took part in the search. No inline completion, deliberately: a field that finishes the word turns `*.s`
into last week's `*.swift`, and the term that ran would be one nobody typed. **Clear History…** on the
Load / Save tab empties both, confirmed first, and deletes the files rather than blanking them. Verified in
the running app, not only in tests: three searches in one dialog, a re-used mask moving back to the top
instead of appearing twice, a freshly opened dialog offering what the previous one recorded, and nothing
left in either dropdown or on disk after Clear. New VM scenario `find-history` covers the same three claims.

## 2026-08-17 (F-110, F-404, F-405) — Two keystrokes that went to the wrong place, and a sidebar that stayed blank

**Esc no longer closed the viewer once you clicked in it (F-110).** `handleKey` sees a key only when it
reaches `ListerContainerView`, and clicking the text, the symbol filter or the marks list moves the first
responder somewhere that consumes the key itself — `NSTextView` maps Esc to `complete:`, a search field
ends its editing session with it. The container now also answers `cancelOperation:`, the responder-chain
form of Esc, which every focusable thing in that window routes up to it; a visible find bar is dismissed
first, because that is the one thing Esc means locally there. Measured before and after with a new
`listeresc` verb: without the fix the text area and the search field both report `closed=no`.

**Del in any text field asked to delete the panel's file (F-404).** Not a stray keyDown — the keymap binds
`DELETE=cm_Delete`, `KeymapMenu.apply` puts it on File ▸ Delete without a modifier, and AppKit matches menu
accelerators app-wide before a keystroke reaches a view. So typing in the Find dialog and pressing Del put
up "1 Objekt(e) in den Papierkorb legen?" for whatever the cursor sat on behind it. The same shape covers
F2…F7 and ⇧F8 — permanent delete, no Trash. `RawKeyboard.menuMayClaim` decides now, asked in one place
(`CommandMenuBar`), and it refuses a bare key when the key window is not the file manager or when the
focused thing wants the keyboard — except the function keys inside the file manager, or F5 would stop
copying whenever the cursor sat in the command line. ⌘/⌃/⌥ chords are untouched. Both halves are in the VM
now: what must stop leaking, and what must not change, including Del on a focused panel still deleting.

**The symbol sidebar was blank for Swift, and its toggle dead (F-405).** The sidebar knew tag queries and
the JSON/YAML/XML scanner and nothing else, so the language this app is written in had no outline at all.
Vendoring grammars was not the cheap answer — each generated `parser.c` here is megabytes, C# alone 31 —
so `DeclarationOutline` scans declarations over a copy of the text with comments and strings blanked out.
Swift, Go, Kotlin, Scala, Dart, C++, Objective-C, PHP, Ruby, Perl, Lua, shell, SQL, TSX, CSS, plus Markdown
headings and the HTML element tree. Three things that only showed up by looking at the output: Objective-C
methods were siblings of their class (an `@interface` opens no brace), a C++ function inside a namespace was
reported as a method, and HTML needed void elements and implied end tags or a `<meta>` swallowed the page.
Along the way, `SyntaxHighlighter.language(forExtension:)` — the app's answer to "is this code?" — turned out
to know none of Java, Rust, C#, Go, Kotlin, Ruby, PHP, SQL, CSS and eight more, four of which tree-sitter
already highlights: a `.go` file was plain text with a dead Code menu item.

## 2026-08-15 (F-363) — The key-view loop, and three ways one wrong sentence broke it

`keys-main` was the one failure the suite kept reporting that nobody had explained. It is fixed, and the
diagnosis is worth more than the fix: every part of it rested on a single sentence in `KeyboardLoop`,
written as fact — *"with the flag set, AppKit keeps the loop up to date as views come and go"*.

**First**, two probes built from keys-main's own dump, each with one extra thing on screen, said which
view breaks the chain: the preview panel *and* the shared tree, both with the same fourteen controls
missing — the entire right panel, the preview-mode switch, the command line, every function-key button.
Both toggles **hide** rather than remove, and AppKit skips hidden views when it builds the loop; un-hiding
one does not make it build a new one. Nine toggles are of that family (the two panels and seven bars) and
all of them now rebuild.

**Second**, that fix exposed a trap of its own making. `enable(for:)` skipped its work when the flag was
already set — "cheap after the first time", resting on the same false sentence. The layout is applied
before the first paint, one element at a time, so the first element to ask for a rebuild set the flag and
the recalculation that runs when the window becomes key — after every element exists — then did nothing.
The loop stayed as it was in the middle of startup. The shortcut is gone; it always recalculates.

**Third**, even then keys-main stayed broken while every other keyboard scenario went green, and the
difference named the cause: the probes toggle at *runtime*, keys-main measures after a *launch*. The
window becomes key while `restoreTabs` is still filling the panels in, so AppKit built the Tab order
around half-built panels and nothing came back afterwards. One rebuild at the end of the restore.

Result: 29 stops, loop closed, nothing unreachable, nothing unlabelled — and `keys-viewer`, `keys-history`
and both new probes green beside it. The probes are permanent gates now (`keys-preview`, `keys-tree`),
because the state they hold is exactly the one that decided, for months, whether `keys-main` passed.

**Method note.** Two of the three steps were only visible because a *passing* scenario stood next to a
failing one: "the probes pass, keys-main does not" is what pointed at startup rather than at toggling. A
single failing scenario would have left the second and third causes untouched.

## 2026-08-15 (VM suite) — Four failures, none of them from this work, and how that was established

The first full suite run since this round of work: **155 reports ok, one wrong, no crashes**, and all
three new scenarios green (`keys-history`, `hex-clipboard` with its three reports, `history-palette` with
its seven, including `bundle.zip` packed in a guest that has no 7z). It takes about six hours — 81
scenarios, each a full app launch with settle time and a VNC capture — which is worth knowing before
starting one.

Four scenarios failed, and the question that mattered was whether they were mine. They were not, and the
sequence that shows it is worth keeping, because "it passes alone" proves nothing on its own:

| run | session-save | keys-main | toolbar-drop | tree-colours |
| --- | --- | --- | --- | --- |
| full suite, this binary | FAIL | FAIL (22 unreachable) | FAIL | FAIL |
| four scenarios, this binary | FAIL | FAIL (13) | ok | ok |
| session-save alone, this binary | **ok** | — | — | — |
| session-save + keys-main, **pre-change** binary (b6b3998) | ok | FAIL (7) | — | — |
| same three predecessors, **pre-change** binary | **FAIL** | — | ok | ok |

So `keys-main` fails with the binary from before this work as well, and `session-save` fails as soon as
anything runs before it — with the old binary too. Both are **state-dependent suite failures that predate
this round**: settings survive in `peachcmd.ini` between scenarios, which STATE has warned about since the
`keys-*` scenarios were fixed, and the unreachable count moving 22 → 13 → 7 with the predecessor list is
the signature of exactly that. `toolbar-drop` and `tree-colours` pass whenever they are not run late in a
long suite.

The committed dumps still show `loopClosed: true` for keys-main, so something between that run and this
one made the main window's loop depend on what came before. That is a real thing to chase — with a
bisect over the scenario *order*, not over the code, since the code from before this work fails the same
way.

Method note: the useful experiment was not "run it alone" but "run it with the same predecessors against
the older binary". The first only says the failure is order-dependent; the second says whose fault it is.
A worktree at the old commit plus `regress.py --app` does that without touching the working tree.

## 2026-08-14 (F-402, follow-up) — A launch is not a visit

Checked the half of persistence that is easy to forget: does a *second* launch read the history back? It
does — both entries returned, the pin with them. And the check found the next thing wrong: they came back
at `uses=2`. Restoring the session re-loads both panels' directories, and every launch was counting that
as a visit.

Left alone it compounds: after a hundred launches the folders you happened to leave open outrank
everything you actually chose, on a count nobody produced. Pinning already exists for "always near the
top". So the restore is bracketed — `beginSessionRestore()` / `endSessionRestore()` around the two
`restoreTabs` calls — and the per-panel history still gets the paths, because there the startup directory
*is* where that panel has been. A flag rather than a scoped closure, and this time that is sound: the
recording it must not see happens inside the awaited sequence, unlike the palette's case where the
navigation arrived long after any flag would have been cleared.

Measured over three launches: `uses=1` before, `uses=1` after, `uses=1` after that.

## 2026-08-14 (F-132) — Packing a zip needed Homebrew, and now it does not

Found by covering the pack path for the history: in the VM the pack produced nothing, because zip *and*
7z both shell out to a `7z` binary and a stock macOS does not carry one. This machine has it through
Homebrew, which is exactly why it had never shown up here. So the most ordinary choice in the Pack dialog
— zip — failed on a clean Mac, visibly (the queued job carries its error text in the transfer manager) but
with no way forward.

There is a pure-Swift `ZipWriter` in PCArchive already, used by the archive *editor*: DEFLATE through the
system Compression framework, no external tool at all. `PackEngine.pack` now uses it for a plain zip when
no `7z`/`7za` is installed, and only then — a password or split volumes still need the tool, and still say
so. Entry names are relative to the items' parent, which is what the 7z route produces (it runs *in* the
parent and passes basenames), so an archive has the same shape whichever wrote it; symbolic links are
followed and their target's bytes stored, which is what `/usr/bin/zip` does by default and the only thing
a writer with no way to record a link can do.

Its one real limit decides the rest: it assembles in memory, so above 512 MB the answer names the tool to
install rather than failing to allocate. Both halves are tested directly — the writer cannot be reached
through `pack` on a machine that *has* 7z, so the tests call it by name — and the **VM scenario now packs a
zip on purpose**: the guest has no 7z, which makes it the one place that proves this works on a stock Mac.

## 2026-08-14 (F-402, harness) — The pack dialog can be answered from a script now

The one claim left standing without a measurement: packing is recorded in the history, and nothing could
prove it. `PackOptionsDialog` runs its own modal session, and `answer` only feeds `InputDialog` — so this
whole path had no end-to-end coverage, for the same reason the F-399 entry gives for every command that
asks a question.

`packanswer <name>` queues the archive name; `runModal` then invokes the *real* `onPack` with the format
and level the Options page supplies and returns. Measured locally: the archive lands in the OTHER panel's
directory (F5-style, which is what Total Commander does), and the history records exactly that —
`operation|bundle.zip packen|/Users/maik1`. Where the archive went was worth checking on its own: had the
history claimed the source folder, the entry would have pointed at a file that is not there.

**And the recording is conditional now**, like extraction: `onComplete` fires whether the queued job
succeeded or not, so a failed pack would have been listed as something that happened. A history that lies
about the past is worse than one that is short.

**Which the guest promptly demonstrated.** In the VM the pack produced nothing and — correctly — nothing
was recorded: zip and 7z both shell out to a `7z` binary, and a stock macOS does not have one (this
machine does, through Homebrew, which is why the local run passed). The failure is not silent, a queued
job that throws carries its `errorText` in the transfer manager, but it does mean **packing a zip on a Mac
without 7z installed cannot work** — worth knowing, and not something this feature can fix.
`packanswer <name>|<format>` therefore names a format, and the scenario packs a **tar**: /usr/bin/tar is on
every machine, which is what makes this path checkable in the guest at all.

## 2026-08-14 (F-131, found through F-402) — The zip-slip guard refused everything under /private

Recording pack and extract in the new history needed a check that something had actually been extracted —
and under `/private/tmp` nothing ever was. Not my code: `PathContainment.isInside`, the rule both the
archive extractor and the panel's extract walk ask, had been refusing every write into a folder under
`/private`, silently, since it was written.

`resolvingSymlinksInPath()` resolves only components that *exist*, and on macOS it also shortens a leading
`/private`. So the two sides of the comparison came apart:

    root  -> /tmp/pc-contain-demo/out          (exists, shortened)
    cand  -> /private/tmp/pc-contain-demo/out/nope.txt   (does not exist yet, keeps /private)

The prefix test then said "outside", `childPath` returned nil, and callers skip a refusal rather than
failing loudly — by design, so that one crafted member does not abandon the honest ones beside it. The
result was an extraction that reported success and wrote nothing. **`/var/folders/…` is such a path**: the
system temp directory every app is handed, which is why the new test fails against the old code on that
one and not on a home-directory path. The VM never saw it, because everything there happens under
`/Users/admin`.

Both sides are now normalised the same way — resolve the deepest existing ancestor, then re-append what is
not there yet. The guard loses nothing: a symlink *inside* the destination exists, so it is still resolved
and still caught, and a traversal is still refused by `isSafeComponent`. Measured with Foundation alone
(above), against the old implementation (the test fails), and end to end in the app: the same archive into
the same folder went from `inside=` to `inside=a.txt,b.txt`.

Worth noting how it surfaced: not by testing extraction, but by making a *history entry* honest. "Only
record what actually happened" turned a silent failure into a visible one.

## 2026-08-14 (harness) — Two modal panels, and only one of them was the blocker

The two new scenarios went into the guest, and the result was the failure shape this project has learned
to distrust: `hex-clipboard` reported everything, `history-palette` wrote **not one file** — six empty
reports, no crash, the app apparently alive. It took four runs to get both green, and the first diagnosis
was wrong, so both are written down.

**What the screenshot showed** (looked at before the log, which was forty thousand lines of espresso and
CoreSpotlight noise): macOS' own consent panel, *"Allow PeachCommander to find devices on local
networks?"*, standing over the panels. It comes from the System Monitor plugin's network module, which
samples interface counters through `getifaddrs`.

**That panel was not the blocker.** It is a *system* panel: it takes the application's activation and
lets the run loop carry on. What it broke was something else entirely — with activation gone,
`NSApp.keyWindow` is nil, `AppMenu.forwardToEditedText` returned false, and ⌘C in the hex editor's Go To
field copied the file's bytes again. The scenario reported that as a wrong expectation rather than as a
blocked run, and it is a real hole in F-401's fix, not a guest artefact: a Spotlight window or a click in
another app does the same to a user. Fixed by falling back the way the keyboard dump does
(`keyWindow ?? mainWindow ?? first visible`), preferring the *attached sheet* — the field being typed in
belongs to the sheet, not to the window under it — and sending the action straight to the text object,
because `to: nil` resolves through the key window's chain and had nowhere to go either. Only undo/redo
still go the indirect way, since the undo manager is what answers those.

**The blocker was our own alert.** `VerifyAfterCopy=1` is seeded in the guest for `bg-copy-verify`, and it
ends every *foreground* copy with an NSAlert — an app-modal session, which is precisely what a script
cannot get past. Every report after the copy step was therefore never written. The scenario now turns the
setting off around its own copy and back on afterwards, through the existing `setbool` verb.

**And one wasted run of my own making:** the first seed that switches the network module off went to
`~/Library/Application Support/PeachCommander`, where the Notes fixture lives, while `regress-guest.sh`
launches with `-ConfigRoot ~/pc-cfg` — which that plugin honours. The run looked exactly like the one
before it. Seeding a plugin's configuration means seeding it where *that* plugin looks, and two plugins
side by side in this app answer that differently.

**Then the expectations turned out to be wrong rather than the app.** Three of them were measured against
a search that was still set to "data", and the scenario never *opened* a file at all — copying one is an
operation, not an open. Fixing that exposed a real defect in the harness: `historytype |<out>` clears the
search, and Swift's `split` drops empty subsequences, so that line had been doing nothing. With the
scenario corrected the guest lists exactly what the session did — `folder|hist-src`, `folder|hist-dst`,
`file|data.txt`, the foreground copy, the repeat that put the file back — and `keys-history` reports a
closed loop with nothing unlabelled and zero conflicts.

**One thing the dump made visible that no test would have.** Two operation rows side by side read
"Copy" and "Copy 1 item(s)": the foreground path had borrowed the *undo* action's label. One operation,
described two ways, in a list a user reads. Both now say what happened.

**Paste is measured at the field editor, not through the menu item.** `to: nil` is what the item does, and
AppKit resolves it against the key window's responder chain — which an application without activation does
not have, and `NSApp.activate` does not take hold by the next line. That the item exists and carries ⌘V is
what the menu dump is for; that the field can paste is what the probe now asks.

**Followed up on 2026-08-15, and the earlier note above was wrong in its conclusion.** Two runs settle
what can be settled: a scenario that does nothing but idle for sixty seconds, and `hex-clipboard`, both
with the plugins in the bundle and the network module seeded off — **no panel in either**. So it is not
time-based (the "about forty seconds after launch" was a coincidence of what those scenarios were doing at
the time), and switching the System Monitor's network module off does what it was meant to.

What remains unproven is whether anything still *asks* quietly. The sighting that produced the suspicion
above was in a run whose probe called `NSApp.activate(ignoringOtherApps:)` — since removed, because it did
not help what it was added for — and activating an application is exactly what makes macOS present a
consent prompt it has queued. So "nothing asks" and "something asks and nothing brings it forward" are
both consistent with today's evidence, and the difference does not matter for the harness: the panel does
not appear, and neither of the two places that depended on activation depends on it any more.

**Rules worth keeping.** When a scenario writes nothing at all, look at its picture before its log. When
it writes the *wrong* thing, do not assume the same cause: here one panel blocked, another only stole
focus, and a third failure was my own expectations. An app-modal alert of our own is a scenario blocker by
construction — `answer` covers `InputDialog`, nothing covers `NSAlert`. And a verb that silently does
nothing is worse than one that fails: three expectations were quietly measured against the wrong state.

## 2026-08-14 (F-402, follow-up) — One action, counted twice

Found by re-reading my own code rather than by a test: opening a folder from the palette counted as
*two* uses. The palette counts the entry it opened, and the navigation it causes reports the same folder
again through `loadPath` — and the "do not record while I do this" flag around that call is useless,
because the navigation is asynchronous and the flag is long reset by the time it arrives. A refresh of
the same directory has the same shape.

The flag is gone. `GlobalHistory.record` now coalesces: two records of the same identity within two
seconds are one use — the timestamp moves, the count does not. That belongs in the model, where it is
testable, rather than in the app, where it would be a guess about timing. Three existing tests recorded
twice in the same instant and had to say what they meant (a *second* visit is ten minutes later); the new
rule has its own test, including that far-enough-apart still counts twice.

## 2026-08-14 (F-402) — A history that is worth opening, and a matcher that was wrong on real paths

Asked for as "a command palette for your own working history": everything recent — folders, files,
operations, commands — findable in one or two seconds by keyboard alone. The model (`GlobalHistory`,
`FuzzyMatch`) is in PCFoundation and fully unit-tested; the recording is a handful of one-line calls at
choke points rather than at each of the places that reach them, which is the same reasoning that keeps
`loadPath` the only place a navigation is recorded.

**Weighting matters more than the list.** Frecency — how recently *and* how often — is what makes the
first row usually the right one; pure recency would make this a log, which is the thing the palette
replaces. Eviction drops the *worst* entry rather than the oldest, or a folder used forty times would
disappear behind a hundred one-off visits.

**The hotkey could not be what was asked for.** ⌘⇧H is Go ▸ Home, ⌘H is macOS "Hide", Ctrl+H is Show
Hidden Files. All three obvious candidates were taken, which `check-hotkeys.py` exists to say — so it is
⌃⌘H, in both schemes and as a Go-menu item, and the deviation is written down rather than quietly made.

**And the fuzzy matcher was wrong in a way only the real app showed.** Unit tests passed; the first run
in the app searched "report" and put `report.txt` *third*, behind two folders. A single greedy pass over
`/private/tmp/…/PeachCommander/…/scratchpad/demo` spends the pattern's "r" and "e" on "p**r**ivat**e**"
and never reaches the file's own name. Fixed by scoring the last path component as a second pass and
taking the better of the two — and deliberately *without* a flat "matched the name" bonus, because that
was tried first and made "adr" in `/xxaxxdxxrxx` beat `/Application Support/dev-report`. Both cases are
now tests, with the actual paths from the run.

**The palette's actions are menu items, not private key handling** — F-401 applied on purpose. Its own
menu bar owns ⌘P, ⌘⌫, ⌥⌘C and the filter keys while it is key, so the panel's commands cannot shadow
them and a screen reader can find them; the Edit menu stays standard, so ⌘C in a search field that
always has focus copies the search text. Copy Path is ⌥⌘C, as in the Finder.

Only copy and move can be repeated. Return on a delete or a rename shows where it happened instead:
repeating a delete should not be one keystroke away in a list somebody is skimming. Repeats go through
the ordinary background queue, so the overwrite dialog, the progress and the undo are the ordinary ones
rather than a second, quieter path.

Verified in the running app, not only in the tests: the recorded copy, the destination emptied by hand,
and the repeat putting the file back (`removed=0` then `data.txt`). Ctrl+Cmd+H claimed by the menu. Key
loop closed with nothing unreachable and nothing unlabelled. Scenario `history-palette`; verbs
`history`, `historytype`, `historyfilter`, `historykey`, `historymenu`, `historyreset`, `historyflush`.

## 2026-08-14 (F-400, F-401) — A sum you should not have to do in your head, and two keys bound to nothing

Two requests from the same place, a hex dump. **Go To took one number**, so `0x1000 + 15 + 1` — a
structure's start, the field's offset, its length prefix — had to be added up by the reader before it
could be typed, and 4112 is exactly the kind of arithmetic that goes wrong silently.
`OffsetExpression` is a small recursive-descent evaluator whose *numbers carry their own base*, so
bases mix in one line and nothing has to be converted first. It went in behind `HexAddress.parse`,
which all four Go To dialogs already called, so the viewer, the hex editor, the binary compare and the
editor's Go to Line gained it in one delegation — and a line number is arithmetic too now, rather than
meaning something different from an offset one mode away.

Two things are refused rather than clamped: a negative result and an overflowing one. A clamp to 0
looks precisely like a deliberate jump to the start of the file, and Int64 arithmetic traps, which is
why every operator is checked. Intermediate values may go negative — `0x10 - 5 - 20 + 10` is a
legitimate way to arrive at 1.

**And the clipboard did not work in that dialog's field**, which turned out to be the more interesting
half. A tool window installs its own menu bar, and four of them build a *tailored* Edit menu: the hex
editor binds ⌘C to "Copy (Hex)", the text compare to "Copy Left Side" — and none of the four listed
Cut, Paste or Select All at all. A menu key equivalent is matched before the responder chain, so ⌘C in
the Go To field copied the **file's bytes** over what the user was trying to copy, and ⌘V was bound to
nothing. Every dialog these windows open is an `InputDialog`, so Go To, Find, Fill Byte and Replace
were all affected — in four windows.

The main window's Edit menu had already been fixed this way once, by routing the standard selectors
through the responder chain; a tailored menu cannot, because the key is spoken for. So the window's own
action asks first (`AppMenu.forwardToEditedText`), and only an *editable* text object wins — a field
editor is, the Lister's read-only content view is not, so ⌘C in the viewer still means "copy what this
viewer is showing" and not "copy the text view's selection".

**A harness gap of the same shape as the last one.** `answer` cannot reach a dialog's field: a scripted
answer means the dialog never appears. The five dialogs of the hex editor and the binary compare were
also app-modal panels with no parent, which `InputDialog` itself documents as the fallback — a modal
session never returns, so a script stopped at one. They are sheets now, and two verbs measure the rest:
`hexgoto` answers `caret=4112` for the expression above, and `hexclip` types into the real field and
uses the window's own actions on it. Both directions, on purpose: with the field focused `copied=COPY-ME`,
with nothing focused `copiedWithoutField=00 01 02 03` — otherwise the fix would have traded one wrong
answer for another. Scenario `hex-clipboard`.

## 2026-08-14 (F-399) — Shift+F5, and the copy that deleted the file

Asked for as a feature: Shift+F5 copies the cursor item with the target field pre-filled, so a name
can be edited into a duplicate. `cm_CopySamepanel` was already bound in both keymaps and registered as
a *stub* that answered "not yet implemented".

**Building it turned up data loss in the existing F5.** Copying a file into the directory it is
already in has target == source, and `copyRegularFile` removes the target before reading the source:
the file is deleted, the read then finds nothing, and the user is told an error about a file that no
longer exists. A directory copied into itself does the same once per file inside it. Reachable
without trying — F5 offers the *other* panel's directory, and both panels showing one folder is an
ordinary place to be. Written as a failing test first, then fixed in `CopyEngine.copyNode`, which is
where every caller passes: F5, F6, background copies and the new command alike. Identity is asked of
the filesystem (device + inode) rather than compared as strings, because case-insensitivity, `//`,
`..` and hard links all make the string answer wrong in the direction that destroys the file.

The feature itself is small once that is in place. The one real decision is what the last component
of the target means, and it differs from F5: there, `/photos/holiday.jpg` is a folder to copy into;
here it is the new name. `CopyAsTarget` holds the rules — trailing slash means a folder, a `*`/`?`
component is a mask, otherwise one item means a name and several mean a folder — and a literal name is
handed on as a wildcard-free `CopyRenameMask`, which expands to exactly itself. No second mechanism.

**And a harness gap that had been hiding features.** Every command that asks a question goes through
`InputDialog`, and a modal session does not return — so a script that ran one stopped there and the
rest of the scenario never happened. That is why this whole class of command had no end-to-end
coverage. `answer <text>` now queues a reply (DEBUG only, consumed one at a time) and `answersleft`
reports whether a queued answer went unused, so a scenario cannot pass because nothing asked.

Verified end to end: a file duplicated under a new name with the original intact, a folder
duplicated with its contents, and the offered value confirmed unchanged refused in the panel's
message strip with the file still there.

## 2026-08-14 (keys-main) — Six controls nobody could Tab to, and the reason

The oldest open item from the VM suite, and it turned out to be one line in two places. `KeyboardLoop`
sets `autorecalculatesKeyViewLoop` and recalculates when a window becomes key — but AppKit does not
notice views mounted *afterwards*, which is why the Settings page swap and the panel view-mode swap
already call `KeyboardLoop.rebuild(for:)` by hand. A plugin view arrives the same way and nobody
called it: `BottomDockView` and `PreviewPanelView` add the plugin's view with `addSubview` and stop
there. So the terminal's controls were outside the loop, and Tab could not reach them at all.

Measured locally instead of in the guest, with the `keyloop` verb and the terminal dropped into the
dock: **without** the fix the loop is five entries and contains neither `TerminalContainerView` nor
`PCTerminalView`; **with** it, seven, and both are in it. The four button controls (shell tab, close,
+, split) only join the loop when Full Keyboard Access is on — it is off on this machine, which is
also why the local `focusRefused` count is large and says nothing. That half is what the VM guest
measures.

Worth noting how it was found: not by reading the accessibility code, but by asking where a view gets
mounted after the window is already up. Three places do it; one of them already knew.

## 2026-08-14 (mounts, checked) — The assumption held for FTP and not for plugins

Claimed at the end of the SFTP work that the new "a lost connection is announced and the panel
leaves it" behaviour covered FTP and plugin mounts for free, because both already map to
`VFSError.connectionLost`. Checked it. **FTP: true** — server dropped mid-listing, panel back on the
local directory, chip gone. **Plugins: false**, and for a reason worth writing down.

`PfxFindFirst` answers NULL and nothing else. A missing directory and a dead connection arrive
identically, so the host guessed — and guessed "not found", which is how a WebDAV server dying
mid-listing left the panel sitting in the mount with the previous directory's rows under the new
path. Neither `PC_E_*` nor the entry point could express it: the error list is Total Commander's
archive-derived set, with no code for a transport that is gone.

Two additions, both purely additive. `PC_E_CONNECTION_LOST` (25), and `PfxLastError(conn)` — "why did
the last call fail", which the host asks only after a handle-returning call answered NULL. Same shape
as `libssh2_session_last_errno`, which the SFTP fix had just used for exactly this. WebDAV records the
reason in `send`, where every request already passes, rather than at each call site.

Also `fsconnect <plugin>` for the harness: `pfxmount` only reaches plugins with a *static* drive, so
a connect-only plugin like WebDAV had no way in from a script — which is why this whole path had no
coverage.

**And a colour audit, from the same root as the quick-search indicator.** `Theme.current.selectedText`
is the *marked-file* colour (red by accident of the default palette, Norton yellow in the NC theme).
Multi-rename used it for a rename that cannot be carried out — an error drawn in the colour that means
"I picked this one" — now `.systemRed`. The filter badge keeps it deliberately, as the palette's only
"pay attention" colour, and now says so, because the next reader would otherwise either copy it or
"fix" it.

**Method note, again.** The first WebDAV check ran against the plugin copy in Application Support,
which was ten hours old — the very trap fixed in `build.sh` that morning, walked into from the other
side. The fresh build lives in the app bundle now.

## 2026-08-14 (SFTP, part two) — Failing is not the same as saying so

Bounding the SFTP session stopped the hang; it did not make anything visible. A failed directory
load was `logger.error` and nothing else, so the user waited, the panel stayed as it was, and there
was still nothing to read — arguably worse than before, because now the session *does* give up.

Underneath were two more things. `libssh2_sftp_open_ex` answers NULL for "no such file" and for
"the socket is gone" alike, and all five call sites assumed the first: a connection dying mid-listing
reported that the directory did not exist. `lastFailure` asks libssh2 instead. And `connectionLost`
was in `VFSError` with **no reader anywhere in the app** — now the panel leaves the dead mount
(`exitArchive` already did the whole retreat), the chip goes, and a sheet names the server.

A sheet, not `runModal`: an app-modal alert stops the other panel too — the one part that kept
working while the connection was dying — and freezes any script driving the app, which is why this
path had no test.

**And the known_hosts finding turned into work.** Connecting appended the server's key to
`~/.ssh/known_hosts` silently: a file outside the app's own configuration, and a trust decision the
user was never shown. It is ssh's question now — fingerprint shown in ssh's own `SHA256:…` spelling,
recorded only on agreement, mismatch still refused outright. The fingerprint test checks against
OpenSSH's own output for the same key rather than against our idea of it.

Also: `Tools/build.sh` built no plugins, so the bundle kept whatever `make-dmg.sh` last left there —
measured at eight hours stale, without the entry point that had just been added. Anyone verifying a
plugin change in the debug app was testing the previous version of it. It builds them now;
`PC_SKIP_PLUGINS=1` opts out.

**One method note.** The first check of the known_hosts change passed for the wrong reason: earlier
runs had already recorded the key, so the connection succeeded and proved nothing. Removing the line
first turned it into a real check. Same shape as the harness traps the day before — a green result
that was never testing what it claimed.

## 2026-08-13 (SFTP, reported) — "the whole app freezes", and what actually froze

Reported as: a busy SFTP server freezes the entire application; presumably the same for other server
volumes; can the other panel at least stay usable. The interesting part is that the premise turned
out to be **half wrong**, and finding out which half took a reproduction rather than an opinion.

**Measured first.** A deliberately slow FTP server (accepts, then stalls on LIST) and later a slow
SFTP server (paramiko, first listing fast so the mount completes, every later one stalling for ever).
With a listing hung and a mount entered:

* the other panel answered in **1.0 s** (FTP) and **6.1 s** (SFTP — the 5 s the script itself waits),
* `sample` showed the main thread **1722 of 1726 samples idle** in the event loop.

So the panel architecture does not freeze, and working in the other panel already works. What does
not work is anything else about that connection, and that is where the real defect is.

**SFTP had no timeout and no cancellation anywhere.** `SFTPSession` runs blocking libssh2 on one
serial queue, and nothing ever called `libssh2_session_set_timeout` — `_libssh2_wait_socket` calls
`select` with no deadline. Sampled during the stall: **1739 of 1739 samples in `__select`**. FTP is
the opposite (Network.framework, bounded, cancellable), which is why the two behave nothing alike.
The consequence is not slowness but permanence: every later call on that session queues behind the
stuck one for ever, `close()` included, so the connection cannot even be hung up.

**And that is what froze the whole app — at quit.** `applicationShouldTerminate` answers
`.terminateLater` and waits for every mount to close before replying, and AppKit spends that wait
inside `-[NSApplication terminate:]` running a restricted event loop. Measured: quit requested,
**still running 41 seconds later**, killable only with `kill -9`. Fixed to ~4 s.

Three changes: `libssh2_session_set_timeout` plus a bounded TCP connect (the kernel's own default is
~75 s per address); `interrupt()`, which shuts the socket down so a blocked `select` returns, used by
`close()` after a grace period so ⏏ works on a dead connection; and `withDeadline` on the quit path.

**Two traps met on the way, both worth remembering.**

* `NSApp.terminate()` called from anywhere on the main *queue* — including `DispatchQueue.main.async`
  and any `Task { @MainActor }` — can never complete when the delegate replies from a MainActor task,
  because libdispatch will not re-enter the main queue while draining it. The harness's `quit` verb
  did exactly that, so it reported "quitting hangs" on **every** build, fixed or not. It now schedules
  a run-loop timer, which is what ⌘Q actually is. Two wrong conclusions were drawn before this was
  understood.
* Connecting to an SSH server **appends to `~/.ssh/known_hosts`** (accept-new). The file comment said
  this was "a later refinement" long after it had been implemented, and a test server with a fresh
  host key per start therefore looks like an attacker at the same address. Test servers need a stable
  key; the comment is corrected.

Cancellation is deliberately not instant: `TransferQueue` cancels tasks when a copy is cancelled, and
a healthy chunk read returns in milliseconds, so cutting the socket on cancellation would have turned
"cancel this download" into "drop the connection". It waits 1.5 s and only then interrupts.

## 2026-08-13 (ideas → five features) — What research did to the list, and what looking did to the result

Five ideas came in as a list; the useful part happened before any code. **Two of the five were already
built**: the folder history (`NavigationHistory`, 50 entries, Alt+←/→, Alt+↓ for the list, persisted
across sessions) and pausing a transfer (`OperationControl.pause/resume/checkpoint`, with per-job
buttons). Two more were half-built — regex existed in the *file* search but not the viewer or editor,
and type-ahead worked but invisibly. And "priority" turned out to be the wrong word for what was
missing: OS priority does nothing for a disk-bound copy, while *queue order* and *a per-job cap* are
the two things a transfer manager is actually asked for. Reading the code first turned a list of five
into a different, smaller, truer list.

What was built: empty-folder search (F-152), a visible quick search with Backspace and Esc (F-060),
queue reordering plus a live per-job speed limit (F-085), and regular expressions in the viewer and
in the editor for both find and replace (F-151).

**Three findings were bigger than the features that uncovered them.**

* `SearchTemplate` is `Codable` with synthesized decoding, which ignores property defaults and throws
  on a missing key — so adding *any* field would have made every saved search fail to load, silently,
  because `SearchTemplateStore.load` answers `[]` for whatever it cannot decode. Decoding is written
  out field by field now.
* The transfer speed limit lived in `CopyOptions`, a value copied into the engine at start. That can
  only answer "slow all copies down". It moved onto `OperationControl`, which the engine already asks
  per chunk, so "slow *this* one down" became expressible at all.
* The editor's native find bar (`NSTextFinder`) cannot do patterns and cannot be taught to — it
  searches on its own behalf and its client protocol supplies text, not a matcher. So the pattern
  search sits beside it and Find Next follows whichever was used last, rather than the bar being
  rebuilt.

**And the method lesson, which is the one worth keeping.** Three separate checks in this session
passed against code that was known to be broken: two versions of the shortcut-recorder UI test, and
the first viewer-regex check, which read a stale offset left behind by the previous search. Each time
the counter was the same and it is cheap: **run the check against the broken build before believing
it**. Twice more, a check that reproduced correctly was still wrong about *why* — a doubled backslash
from a shell heredoc, and `^` not matching line starts.

Then the screen was locked for most of the work, which forced everything through automation and left
four verbs behind that outlive the day: `typeahead` (drives the quick search, `\b`/`\e` for Backspace
and Esc), `listerfind`, `editregex`, and `httpget … hold` for producing a *waiting* transfer list.
When the screen came back, one pass over the five features found **two defects that no test could
see**: the quick-search indicator used `Theme.current.selectedText` for its normal state — the colour
of *marked files*, red in the default palette — so it was red whether or not anything matched and the
red that meant "no match" said nothing; and "Empty folders only" left the content search enabled,
because the edit meant to grey it out matched nothing and did nothing. Headless checks verify state;
they do not see a colour or an enabled flag.

## 2026-08-13 (FTP, reported) — A dialog that offered nonsense, and a connection with no drive

Three reports about the FTP side, and each turned out to have a second defect behind it.

**The port did not follow the protocol.** Switch a site from FTP to SFTP and 21 stayed in the field.
Behind it, `commitForm` assigned the port *before* the protocol, so the port's own fallback ("this
protocol's default") was read from the protocol being replaced — a site with a cleared port field came
out on 21 no matter what it had just been set to.

**The dialog offered every setting for every protocol.** "Anonymous" and passive mode stayed live on
SFTP, which has neither; a proxy could be set on an FTPS site whose transport throws
`tlsThroughProxyUnsupported` on connect; active mode plus a proxy is a data connection nobody can open.
Worst of the set: `ProxyKind.http` was offered for FTP sites and `NWFTPControlTransport` then handshook
it as SOCKS5 — the failure mode worse than refusing, because the error names a protocol nobody chose.
The rules are now one testable place (`FtpConnectionRules`) that the dialog greys controls with, writes
its warning line from, and `connectToSite` refuses with, so the same combination is described the same
way wherever it comes up. The tunnel refuses a kind it does not speak. F-212's inventory row claimed
HTTP proxy support and has been corrected.

**An open connection had no drive of its own.** `enterNetwork` was called with `driveVolume: nil` for
FTP and SFTP, so the bar fell back to matching the panel's path by prefix — and inside a mount the path
is the server's own "/", which by prefix belongs to the startup disk. The bar therefore lit *Macintosh
HD* while the panel was showing a remote server, the tab was titled "/", and the only way to hang up was
a menu command aimed at whichever panel happened to be active. A connection now registers in
`NetworkMountRegistry` and gets a chip like a plugin drive: either panel can enter it, and its ⏏ says
Disconnect and does. Verified against test.rebex.net in the real app — `current=test.rebex.net`,
`chips=…|test.rebex.net:networkConnection:glyph|…`, and after `drivedisconnect` the chip is gone and the
panel is back where it started.

That third fix opened a hole it had to close as well: with a chip, *both* panels can be inside one
session, so "I am leaving" stopped meaning "nobody is using this". `exitArchive` and `resetToLocalFS`
now ask the other panel first — otherwise a tab switch on the left would close the socket the right
panel was listing through.

Also removed: a dangling doc comment for a WebDAV connect function that no longer exists (it read as the
next function's documentation), and "0 bytes free" announced by VoiceOver for every chip whose capacity
is zero — plugin drives have always had that, and a connection would have joined them.

**WebDAV, asked about next, was never broken — it was invisible.** The plugin builds, loads and lists
(verified against a local DAV server: connect, `PROPFIND`, three entries). What it did not do was appear
in the drive bar, for exactly the reason FTP did not: `fsMount` passes `pendingDriveVolume`, which is set
only by a drive-chip click, so *every interactive plugin connect* mounted with no volume — startup disk
lit, tab titled "/", nothing to disconnect from. It now registers in the same registry, named from the
id the plugin gives its connection (`webdav:host` → chip "host", kind WebDAV; the split is
`NetworkConnectionID`, tested for the ids that are not that shape). A drive-chip mount still does *not*
register — TaskManager keeps its one chip, checked.

## 2026-08-13 (F-254, reported) — The shortcut recorder took no keys at all

Reported: the Record sheet opens and then answers nothing, Esc included. It was a lifetime bug, and
the shape is worth remembering. `NSWindowController` retains its window; a window does **not** retain
its controller, and `beginSheet` retains only the panel. `KeyCaptureController` was held in a local in
`recordShortcut`, so it deallocated the moment that method returned — while the sheet stayed on
screen, because AppKit was holding the panel. Its key handler was `[weak self]`, so every keystroke
resolved to nil and did nothing. A dialog that is visibly there and completely dead.

Proved rather than reasoned: a 30-line AppKit probe presenting a sheet from a local controller reports
`sheet still on screen: true` / `controller deallocated: true`, and the same probe in the fixed shape
delivers all three test keys — a letter, a Ctrl chord and Esc. `KeysWindowController` now holds the
capture controller and releases it in the sheet's completion.

Two more found while verifying it in the running app:

* A ⌘ chord could never be recorded. Key equivalents are offered to the key window's views before the
  main menu, and this app's menu is full of them — so ⌘C ran Copy instead of being captured, and the
  sheet went on waiting for a key it would never be given. `KeyCaptureView.performKeyEquivalent` now
  claims the event, but only while it is the first responder.
* The "reassigned" alert ran app-modally from *inside* the key handler, so the capture sheet stood
  behind it still asking for a key that had already been pressed. The sheet is ended before the key is
  reported now.

Verified in the app through the real UI (AX: select a row, click Aufnehmen…, press a key): Esc closes
the sheet and writes nothing; Ctrl+Shift+F9 writes `C+S+F9=cm_BottomArea` to keymap-user.ini, and the
sheet is already gone while the alert is up. The cause was then confirmed by instrumenting the broken
build rather than argued: `makeFirstResponder=true`, `KeyCaptureController deinit`, `view keyDown
hasHandler=true` — and no `handle` line, because the closure's `[weak self]` had gone nil. The first
responder was never the problem.

**And a harness finding worth more than the fix.** The XCUITest written to guard this passes against
the *broken* build. Two versions of it did: one asserting the sheet disappears (it disappears anyway,
once its controller is gone) and one asserting the binding lands in keymap-user.ini — which under
`XCUIElement.typeKey` it does, even with a dead handler, measured against the same binary that fails
when driven by System Events `key code`. The app's own log settles the mechanism: through AX the order
is `beginSheet / controller deinit / keyDown` — no handler left — and under XCUITest it is
`beginSheet / keyDown / handle / controller deinit`, the leaked controller outliving the keystroke by
exactly enough to serve it. Neither `hover()`, nor `click()`, nor seconds of waiting moved the `deinit`
ahead of the key; what decides it is how the button is activated (AXPress vs. injected mouse events)
and AppKit's autorelease nesting for each, which is where the investigation was stopped rather than
guessed at. The test is kept, relabelled as the happy-path smoke test it is, with
that written in its header: **an XCUITest can type into a dialog that is, to a user, completely dead.**
Anything of this class needs the AX route or an outcome check, not a UI-moved check.

## 2026-08-13 (FTP settings) — Three that round-tripped and did nothing, and the SFTP key

**`encoding` is now read.** It went through ftp-sites.ini since the file was defined and reached
neither the listing nor the wire, so a latin-1 server listed "Größe.txt" as mojibake — and a name the
panel cannot spell is one it cannot open, rename or delete either. Both directions are set together
(`FTPControlConnection.setEncoding` → listing decode + `setCommandEncoding` on the transport, an
optional protocol method with a no-op default so mocks are untouched): decoding a listing correctly
and then sending the name back as UTF-8 trades unreadable names for a file the server says is not
there. The decode falls back UTF-8 → latin-1 rather than to replacement characters, because U+FFFD
destroys the byte it stands for and the name can then never be sent back.

**`localDir` is now read.** The site's local folder opens in the *other* panel on connect — the
pairing a transfer wants, and what the key has meant since it was defined. Only when it still exists;
a folder that has been moved should not send the other panel somewhere arbitrary.

**`folder` is kept and still unused,** deliberately: the connection manager is a flat list, so there
is nothing to group by yet, and dropping the key would lose the grouping of anyone who has one.
Recorded here rather than left looking like an oversight.

**SFTP keys.** `auth` could only become `.password` or `.anonymous` from the dialog, so `site.keyFile`
was unreachable however it got into the ini, and `connectToSite` passed `keyPassphrase: nil`. The
ordinary cases were never broken — `SFTPSession.authenticate` tries the ssh-agent first and then
`~/.ssh/id_*` regardless of what the site says — but a key at a path of one's own could not be chosen,
and an encrypted key could not be opened unless the agent held it. There is now a key-file row (SFTP
only, with a chooser that starts in ~/.ssh and shows hidden files), naming a key *is* the choice of
key auth, the one secret field relabels itself "Passphrase:" and is passed to libssh2 as one, and a
key file that is not there is refused rather than silently fallen back from — libssh2 skips a key it
cannot open and tries the default, which surfaces as "authentication failed" against a server the
default key may not even be enrolled at.

Not verified end to end: this machine has no sshd, and setting one up means touching the user's
~/.ssh. The rules and the ini round-trip are unit-tested; the libssh2 call itself is unchanged apart
from which argument the secret goes into.

## 2026-08-13 (PFX, follow-ups) — The WebDAV plugin had no tests at all

It was built, installed and exercised only by someone connecting by hand, so the PROPFIND body, the
XML parse, the href-to-name mapping and the host adapter over them were all trusted rather than
checked. `WebDAVPluginTests` now builds the real plugin the way `build-pfx-plugins.sh` does, points
it at a minimal DAV origin (`Fixtures/davserver.py`, stdlib only) and drives it through
`PFXFileSystem` — connect, enumerate, descend, read bytes, miss a directory, and go inert after a
disconnect. Deliberately a host test rather than a VM scenario: a scenario cannot be run from here,
and this repo has already been bitten by scenarios that silently did nothing.

Writing it surfaced two things. The plugin recorded every connect in its site history including the
test's throwaway localhost URL, once per run, in the *user's* real Application Support directory —
now skipped when the connect came from the `PC_WEBDAV_URL` test hook. And the reason it could: **a PFX
plugin is never told the host's config root.** `PfxHostServices` carries `crypt` for the Keychain and
`parentWindow`, and nothing else, so `-ConfigRoot` does not isolate plugin state at all. That is a
real ABI gap and the next candidate for a considered extension.

Also: a PFX plugin that offers a connect facet but exports no `PfxDisconnect` loads and works and
then leaks whatever `PfxConnect` allocated, once per connection — `PFXSymbols.required` is empty and
every facet is probed. The host has nothing to call and cannot fix it, so it now says so at load
time, which is the most it can honestly do.

## 2026-08-13 (PFX) — Disconnect was in the ABI all along; the host never called it

Asked to make plugins support disconnect, and to extend the ABI if it did not allow it. It does:
`PfxDisconnect(void *conn)` has been in `pfx.h` since it was written, and all three plugins with a
connection implement it properly (TaskManager frees its `Conn`, WebDAV releases its retained object,
SampleFS is a no-op). **No new ABI symbol was added**, and adding a `PfxDisconnectEx` for a reason
code or a failure result would have been surface with no caller — the host offers no way to refuse a
disconnect, and should not: that is how you get a mount you cannot get rid of.

The gap was entirely on the host side, and it was three things:

* `PFXFileSystem` did not conform to `DisconnectableFileSystem`, so `leaveNetworkMount`'s
  `guard fs is DisconnectableFileSystem` made `cm_FtpDisconnect` a **silent no-op on every plugin
  mount** — indistinguishable from a command that does not work.
* The only call was `deinit`, fire-and-forget on the mount's queue. Nothing could await it, and
  `deinit` does not run at process exit — so a plugin holding a socket or a lock file was killed
  with it still open. `applicationShouldTerminate` now closes open mounts, next to the plugin-view
  teardown that was already there.
* Making it explicit is what made it *hard*: `PfxDisconnect` frees the plugin's own state, so a
  disconnect arriving while the object is alive turns every later call into a use-after-free, and
  simply adding the conformance would have made `deinit` free everything a second time.

So the handle is now lock-guarded and **taken** rather than read — exactly-once by construction —
and every call reaches the plugin through `withConnection`, which refuses to run after the handle is
gone (`connectionLost(retryable: false)`) and holds the lock across the C call. That last part also
closes an older hole: content-column reads call the plugin **synchronously from the main thread**
while a listing may be running on the queue, which the ABI's "calls on one connection are
serialised" has always forbidden and nothing enforced. The enumeration runs inside a single
`withConnection`, so a find handle can never outlive its connection; a separate `closing` flag is
what lets a disconnect interrupt a slow remote directory instead of queueing behind it.

The contract is now written into `pfx.h` (all three synced copies) as a promise to plugin authors —
exactly once, never concurrent, find handles closed first, and reached on quit — because a plugin
freeing its state in `PfxDisconnect` is relying on every one of those, and none of them were stated.
`SampleFsDisconnects` in the sample plugin makes them testable; `PFXFileSystemTests` pins
once-only, still-called-when-simply-dropped, and refused-after-disconnect.

Verified in the app: `pfxmount TaskManager` then `cm_FtpDisconnect` now leaves the mount (before:
nothing happened), and the WebDAV chip's Disconnect still does.

**Still unused in `FtpSite` and worth a decision:** `encoding`, `localDir` and `folder` round-trip
through ftp-sites.ini and are read by nothing.

**And a narrower gap than it first looks.** `FtpAuth.agent`/`.keyFile` cannot be chosen anywhere in the
UI, and `connectToSite` reads `keyFile` only when `auth == .keyFile`, which no dialog can set. But
`SFTPSession.authenticate` does not depend on the site saying so: it tries the ssh-agent first, then the
password, then the named key file, then `~/.ssh/id_ed25519`, `id_rsa`, `id_ecdsa`. So the ordinary cases
— an agent, or a default key — work today without any setting. What cannot be reached is a key at a
*custom* path, and any passphrase-protected key when the agent does not hold it: `connectToSite` passes
`keyPassphrase: nil`, which reaches libssh2 as `""`.

## 2026-08-13 (VM suite, cause) — One script looking in the wrong place, four "defects"

Four of the five failures the suite reported were not defects. `build-ai-plugin.sh` looks for
`PCAutomation.framework` via `xcodebuild -showBuildSettings`, which answers with the *default*
DerivedData — empty on a machine that builds through `Tools/build.sh` (`-derivedDataPath build`). The
script exited 1, `set -euo pipefail` in `build-all-plugins.sh` stopped the loop there, and everything
after it in the list — AIColumn, iCloud, WebDAV — was never built either. `regress.py` then copied the
incomplete bundle to the guest without looking at the exit code.

So the guest ran an app with four plugins missing, and the suite reported the consequences:

* `plugin-context-menu` — no AI submenu, because there was no AI plugin.
* `surface-colours` — `windows=28` against a pinned 32, and `findings=0` all along: never a colour
  defect, just four windows that no plugin was there to open.
* `toolbar-drop` and `session-save` — both pass once the bundle is complete.

Fixed at both ends: the script takes the repo's own build tree first (the same fix `resolve_app`
needed), and `regress.py` grew `must()` — the plugin build, the app copy and the demo tree now stop the
run instead of continuing with half a guest. All sixteen plugins build again, and the full suite went
from **11 failures to 4**: `plugin-context-menu`, `surface-colours` and — against my own reading of it
— all five `preview-zoom` reports are green. I had written that one off as "timing on a cold guest";
it was the incomplete bundle as well, and the suite corrected me.

Correction to what this commit first claimed: `toolbar-drop` and `session-save` pass when run alone or
in a small set and fail in the FULL suite, so they are order-dependent rather than fixed. Two
hypotheses worth checking, both about state the per-scenario reset does not clear: `default.bar` is
never reset, so an earlier scenario that fills the button bar leaves no free space for the drop; and
`peachcmd.ini` survives, so a scenario that changes a setting could switch session saving off for
everything after it.

That is the third instance of one shape in this session: a tool that looks where this project does not
put things, under a layer that does not check whether it worked. It is worth grepping the rest of
`Tools/` for the same assumption.

**Still open after this:** `keys-main` — the terminal's six controls (container, view, the zsh tab
button, close, +, split) are outside the key-view loop, in both builds; a real accessibility defect.
`preview-zoom` is timing-marginal on a cold guest, and `tree-colours` flaked once in five runs.

## 2026-08-13 (VM suite) — What the regression found once it was running again

With `resolve_app` fixed and the demo tree provisioned from `regress.py` (it was only ever created by
`capture.py`, so every scenario navigating to `pc-demo` had been looking at an empty panel), the full
suite ran for the first time in a long while: **92 scenarios, 11 failures**. Each failure was then run
again against the app as it was BEFORE this session's work, which splits them cleanly.

**Pre-existing — the same five fail on the old build. Nobody had seen them because the suite was
shipping an app bundle with no binary in it:**

* `toolbar-drop` — dropping an application on the button bar does not reach `default.bar`.
* `session-save` — the panel paths do not arrive in `session.ini`.
* `plugin-context-menu` — the AI plugin's items are missing from the panel context menu.
* `surface-colours` — the pinned window count no longer matches.
* `keys-main` — six elements are unreachable by keyboard.

**Intermittent:** `tree-colours` failed in the full run and passed on repeat. Its symptom is the tree
reading the colour of row 0 and finding no row, so it reports `.labelColor`. Same family as the
navigation race below.

**Timing, not behaviour:** `preview-zoom` (five reports) failed on a cold guest with this build and
passed with the old one — but the identical steps replayed by hand in the same guest pass, and both
builds behave correctly on this machine. Measured locally, this build reaches the first automation verb
in 0.52 s against 0.45 s before (the TaskManager plugin now links Security), and the scenario's fixed
waits are evidently marginal on a cold VM. So: not a defect in the preview, a scenario that measures
the machine as much as the feature.

**The race that keeps showing up.** A reload that captures its path before awaiting can land after a
newer navigation and overwrite it — the signature is a tab that already names the target while the panel
still shows the previous directory. Seen once in five runs of `panel-autorefresh`, and it is the likely
cause of the `tree-colours` flake. Both builds are equally affected; it is not new. The fix is to
serialise a panel's loads so the last one REQUESTED wins rather than the last one to finish, which is a
change to a central path and belongs in its own piece of work, not between two VM runs.

## 2026-08-13 (VM regression) — The new work is measured in the guest, and the guest was measuring nothing

Everything from F-390 to F-398 had been verified by driving the app on this machine, and none of it was
in the VM suite. Two scenarios close that — and getting them to run turned up two things about the
harness that matter more than the scenarios do.

**The suite had not been running an app at all.** `resolve_app` asked `xcodebuild -showBuildSettings`,
which answers with the *default* DerivedData path, while everything in this project builds into
`build/` (Tools/build.sh passes -derivedDataPath). On a machine that has never built through Xcode's
UI that path is an empty directory — and an empty directory is not an error: `build-all-plugins.sh`
created `Contents/PlugIns` inside it, rsync copied that skeleton, and the guest received a bundle with
no binary. Every scenario reported "EMPTY" and every screenshot showed the desktop, which reads exactly
like a broken app. Proved by running `main-window` and `panel-autorefresh` — untouched, long-standing
scenarios — and getting the same desktop. `resolve_app` now takes the repo's own build tree first and
REFUSES anything without an executable in it, with the paths it looked at.

**The guest has no demo tree.** `demo-content.sh` is called by `capture.py` and never by `regress.py`,
so the scenarios that navigate to `/Users/admin/pc-demo` have been looking at an empty panel. The first
version of `process-files` held a file from that tree open and correctly found nobody. It now creates
its own file with `mkfile` and says `holder-running` or `holder-missing`, so a future failure cannot be
read as "the search found nothing" when the truth is "there was nothing to find". The other scenarios
are left alone — that is somebody's decision, not a repair to make in passing.

With that, both are green in a clean guest: `process-files` finds exactly one holder
(`tail (1088)  r  #6FB2FF` — the dark palette's read colour, so the theme is proved too), reports the
row's columns (881 KB footprint, 1.3 MB resident, Apple-signed) and lists what the process holds after
entering it; `panel-place` still sits at `firstVisible=98` after three refresh cycles in a 533-row list.

## 2026-08-13 (F-396, F-398) — Two things the panel was doing to itself

Six pieces of work, and the first one was a defect the review turned up rather than a feature: **F8 "Quit
Process" ended nothing**. `isInArchive` is spelled `!(fs is LocalFS)`, so the process mount — and every FTP
and WebDAV mount — reached the archive branch of the delete path and was told it was a read-only archive.
The plugin's kill, with its SIGTERM→SIGKILL escalation, its own tests and its documentation in nineteen
languages, had no route from the panel at all. Found by asking the running app: the process was still there
afterwards, and `modaldump` read out a dialog about archives. Nothing else in the review would have been
worth much on a mount whose one action was dead.

Reported from an older version — "the view loses my position on every cyclic refresh and I have to
scroll and search again" — and still true. Measured rather than reasoned about, through a new `viewdump`
verb that reports cursor, first visible row and scroll offset: a dump of names cannot tell "the list is
correct" from "I lost my place".

Two causes, both real:

* With the cursor on a row, `focusEntry` called `scrollRowToVisible` on EVERY reload. Scrolled to row
  900 with the cursor at 417, the next refresh pulled the view back: offset 17083 → 7925.
* With the cursor on ".." — where it sits until you move it — `update` reset it to the first row and
  `reloadData` put the offset back to the top: 11383 → -22.

Bringing the cursor into view is what a cursor *move* means, so it became a parameter of `focusEntry`,
false for a refresh; and the scroll offset is captured and restored around `reloadData` when the path
has not changed. A cursor whose row is gone keeps its index rather than jumping to the top — the rows
being looked at are still there.

Not just the volatile mount: the directory watcher reloads through the same call, so a local folder went
to the top whenever anything in it changed, and so did every panel reload after a copy or a delete.
Verified in all three, plus the cases that must NOT change: navigation still lands at the top with the
cursor on "..", and an explicit focus still scrolls to its row.

## 2026-08-13 (F-397) — Aiming the filter, and a column that had been saying nothing

Making the filter match every column (F-395) answered the questions the name could not and created a
new one: "1" matches half the PIDs, "root" matches any command line with /root/ in it. A term can now
name its column — `user:root state:R`, space-separated, all required — while text that names no column
keeps its old meaning EXACTLY: one substring with its spaces, so "Google Chrome" stays one search and
matched 104 rows in the running app. An unknown word before a colon is not a field, which is what keeps
"12:30" and "Notes: draft" ordinary text. The grammar lives in `PanelFilterQuery` with eleven tests,
because it is the part with rules; the panel only resolves values. Aimed terms reach columns that are
not on screen — hiding a column should not remove a question — and the indicator now carries "204/1204",
since three matches and none look identical in a list whose hits are off-screen.

Testing it surfaced two things worth more than the feature:

* **The State column was reporting "R" for 1196 of 1197 processes.** Modern macOS leaves `p_stat` at
  SRUN, so the column had been answering the same thing to every question since the plugin was written.
  It now comes from the `ps` snapshot F-394 already fetches — 594 Ss, 546 S, 19 SN, 5 R and so on — which
  is why `ps` runs on its own interval instead of only when metrics are missing.
* **Half the per-row cost was `getpwuid`**, called once per row for the four users that own anything.
  With a per-connection uid→name cache and each row's signer resolved alongside the snapshot, a full
  column prefetch over 1191 rows went from 8.5 ms to 4.4 ms of main-thread time, every two seconds.

The drift gate learned to count table rows, and immediately earned it twice: four columns had been added
to seventeen translated tables and missed in French and Slovenian — the gate was green, because a table
row is neither a paragraph nor a list item and fell between every measure it had. It also found a
pre-existing split in `keyboard-shortcuts` (English has one row for choosing a scheme, every translation
has two), recorded in the allow-list rather than papered over.

## 2026-08-13 (F-391…F-395) — The Task Manager, reviewed against Process Explorer

The plan's five pieces, on top of the delete fix recorded above — without which the mount's one
action was dead, and none of this would have been worth much:

Then, in the order the plan proposed:

* **A process is a folder** (F-391). Entering it lists the files it holds open, as real file rows — F3
  opens the file, "Go to File" puts it in the other panel. That is the thing a file manager can say about a
  process and Activity Monitor cannot, and it is F-390 read backwards. Row names are the file's path with
  ":" for "/", which is the host's own convention for a name containing a slash (F-100), so a row reads as
  a path and still decodes to somewhere the panel can navigate.
* **The missing columns** (F-392): footprint, disk I/O, wakeups — one `proc_pid_rusage` call, same reach as
  the task info, each field measured for real coverage before it became a column. `PFX_FT_SIZE` finally
  renders as KB/MB, which the SDK header had promised since it was written; splitting display from sort
  value was the price, because "1.2 GB" and "9.9 MB" compare as 1.2 and 9.9.
* **Who signed it** (F-393) — the macOS answer to Process Explorer's Verified Signer, and the only
  attribute readable for *every* process, because it is a property of the file. Cached and read a few per
  refresh: 1.5 ms × 700 binaries is a second of frozen panel otherwise.
* **Other users' numbers without a helper** (F-394). `/bin/ps` is setuid root and costs 52 ms for the whole
  table, so a privileged helper — which would need the Developer ID this project does not have — buys
  nothing. CPU and Resident went from 72% to 100% coverage. The two sources are not the same measurement,
  so Resident is its own column and the report says `[via ps]`.
* **The filter reaches the columns** (F-395): `root` narrows 1217 rows to 205.

Measured, not assumed, and two of the measurements changed the design: `proc_pidinfo` reaches every process
of your own uid (72% of this table), not just this one process as the plugin's own header claimed for a
year; and reading signatures is ~1.5 ms each, which is what made the cache-and-budget design necessary.
Deliberately not built: notarization checking (hashes the whole binary), closing another process's handles
(no macOS equivalent), CPU affinity (no public API), and colouring rows by process state — the row-colour
channel already carries F-390's answer, and two colour systems on one channel is how they come to fight.

## 2026-08-12 (F-390) — Which processes have this file open, and how

The Task Manager mount could say which process was on port 8080 and could not say who was holding
the file you were trying to replace — the question that actually stops work. `PfxLookup` grew a second
query, `file:<path>`, and with it the facet's first *list* answer: one line per process, tagged `r`,
`w` or `b`, coloured in three (a reader, a writer and one doing both are three different problems).

Three things had to be got right and one of them was got wrong first. Identity is the (device, inode)
pair rather than the path text — `/tmp` is `/private/tmp`, a hard link is the same file, and `vip_path`
carries only the tail of a long one, so a string compare answers "nobody has it open" about a file that
is very much open. The access mode is FREAD/FWRITE, not O_ACCMODE: `fi_openflags` is the kernel's f_flag,
which is the O_* flags **plus one**, so the first version reported every reader as a writer and a
read-only handle came back `w`. And the host's lookup buffer went from 2 KiB to 64 KiB, because a list
is what silently loses its tail.

The colour is a text colour, like the by-file-type ones, so it composes with the cursor bar and the
zebra shading — and it is pinned *through* the cursor bar the way a marked file is. That had to be
added: the search puts the cursor on the first writer, and under Norton (which re-colours the cursor
row) that one row was the one row not saying what had been found. Found by reading the drawn colour
back, not by looking: `prochldump` reports the label colour each highlighted cell is actually using,
which a screenshot cannot, since the three colours differ by hue at one lightness.

Verified in the running app against `lsof`: a `tail -f`, a shell holding an append-only fd and one
holding a read-write fd come back `r`, `w` and `b`, the same five processes `lsof` lists, in
`#1D6FD1`/`#C2410C`/`#8E44AD` under the default palette and `#55FF55`/`#FF5555`/`#FF55FF` under Norton.
Not in the VM regression: the scenario would need a process inside the guest holding a file open, which
the fixtures do not provide. Unprivileged this sees the caller's own processes, like the port lookup;
a merely mapped library and the working directory are not fds and are not reported.

## 2026-08-09 — Sweep: what this app writes, read by something that is not this app

The AppleDouble litter in every tar we packed was invisible for one reason: the tool that wrote it and
the reader that read it agreed with each other. `tar -tf` hid the `._` members, our own browser showed
them, and nobody had ever put a third party in between. So the class got swept: every format this app
produces for other programs, handed to a reader that knows nothing about our code.

**Three formats, three times correct — and that is the result, not a disappointment.**

* A zip from ZipWriter: python's `zipfile` verifies the CRCs and reads `Grüße Straße.txt` exactly, with
  the UTF-8 filename flag set as it should be.
* A `.sha256` from ChecksumFile: `shasum -a 256 -c` answers OK for both entries, including the one whose
  name contains a space, which is where a two-column format usually comes apart.
* A CSV from FileListFormatter: python's `csv` module reads back exactly the five names it was given —
  including one containing a comma, one containing a quote, and one containing a CRLF. That last one is
  the "six files, eight lines" defect fixed in 0.4.0, confirmed for the first time by a parser that is
  not ours.

All three are permanent tests now, and the mutations land: with the CRLF comparison put back to `"\n"`
the foreign parser splits the name into two fields, and with the UTF-8 flag cleared python reports
`no-utf8`.

**One thing that looks like a defect and is not.** macOS's bundled Info-ZIP `unzip` (6.00) ignores the
UTF-8 filename flag: it renders that name as `Gr+++?e Stra+?e.txt` and then fails to write the file at
all. I took this for our bug for a while. The archive is correct — the flag is set, and python and 7z
both read the name — so `unzip` is not used as a witness, and the reason is written where the next
person will look.

**And one mistake of mine worth recording:** the first version of this probe ran `unzip -q` inside the
test, which stopped to ask a yes/no question about the name it had mangled. Two test runs hung for
twenty minutes each before I noticed the tool was waiting for input rather than working. Every foreign
tool here now has its standard input on /dev/null.

## 2026-08-09 — Sweep: unbounded work on the main thread

The reported viewer freeze turned out to be one case of a class, so the class got swept: *work whose
size follows the input, performed where the window has to wait for it*. Five instances, and four
surfaces measured and deliberately left alone.

**Found and fixed.**

1. *Binary content in an NSTextView.* Not the character count but the number of **distinct** scalars:
   a 964 KB PNG decodes to 931,257 characters over 3,000+ scalars and CoreText hunts the font cascade
   for each — 2.0 s in a bare view, never finishing in the app. The binary mode's 1,002,648 characters
   over 192 Latin-1 scalars lay out in 12 ms. Same order of characters, 170× apart.
2. *Bracket highlighting* read `NSTextView.layoutManager` on every selection change, which lays the
   whole document out. Bounded to 200k characters.
3. *The symbol outline* asked the virtual view for its text — decoding the entire file — and then
   `SymbolSidebar.load` refused it for exceeding four million characters. The bound existed and was
   applied one call too late: 306 MB of footprint for a 175 MB file, 140 MB after.
4. *The marks panel* did the same to show a handful of line snippets, where the view can hand over one
   line at a time.
5. *Compare Directories with subfolders* walked both trees on the main thread — a `stat` per file,
   ~800 ms for a 40,000-file source tree, so 1.6 s of frozen window for a moderate project.
6. *Copying the whole file* in the viewer built the string before anyone asked how big it was. The app
   already had an answer for text too large for the pasteboard; it was applied after the text existed.

**Measured and left alone**, which is half the value of a sweep: the panel listing (perf tests already
cover 100k entries), the duplicate finder, the checksum engine and the file search (all `actor` or
nonisolated, so `await` really does move them off), the occupied-space calculation, and the sync
scanner. The tree view is the interesting refusal: expanding a node with 30,000 entries costs 222 ms on
the main thread, and moving it off would mean an asynchronous NSOutlineView data source, which the
protocol does not support. Recorded with the number rather than half-changed.

**Two mistakes of mine, both in the instrument rather than the code.** The memory check first read
`ps -o rss` from the harness — but the harness kills the app before the external checks run, so it
measured an empty string and reported it as a pass. Then the threshold: I took it from RSS numbers
(139 idle / 257 fixed / 434 broken) and had the app report `phys_footprint`, which does not count clean
file pages and reads 140 against 306. At 350 the guard passed the broken build. It is 220 now, and the
mutation makes it fail as it should.

## 2026-08-09 — The last 21 rows: from 21 without evidence to none

The inventory had 21 `done` rows carrying no `ev:` pointer. Going through them turned up the usual
split: some were implemented and tested and merely unlabelled, some were implemented and untested, and
five were not implemented at all despite the row saying so.

**Not built, though the row said it was.**

* *F-012, the window title.* `window.title` was assigned the literal "Peach Commander" at startup and
  never touched again. That is the text Mission Control, the Window menu and Cmd-Tab show, so two
  windows on two folders were indistinguishable. Measured before the fix by dumping window titles in
  the VM — one line, `window=Peach Commander`; after it, `window=~/pc-demo`.
* *F-001, double-click the divider for 50 %.* The window used an NSSplitView directly, with no subclass
  and no click handling anywhere; the one function that centres the divider was reached only when the
  panel arrangement changed. AppKit has no "is this point on the divider" question, so that arithmetic
  is ours now and is tested at the edges.
* *F-085, "sequential ops".* "Start all" looped over the held jobs and started every one of them, each
  with its own queue and control — twenty queued downloads became twenty concurrent transfers.
* *F-029, "icon off mode".* The directory check came before the mode switch, so the one mode whose
  point is that nothing is drawn still drew a folder icon on every directory row.
* *F-311, "DMG with layout".* The image was created directly as UDZO, so its window opened at whatever
  size the Finder last used and the two icons could land on top of each other. Now built read-write,
  arranged, then compressed — verified by reading the positions back out of the finished image. There
  is still no background image, and the row says so rather than claiming one.

**Instruments that could not fail.** `testCommandIdsAreUnique` compared the ids coming out of the
registry against the set of them — but the registry stores commands in a dictionary keyed by id, so a
collision had already collapsed to one entry before the test looked. `register` does assert, and that
is compiled out of a release build. It is a count now, plus a gate that reads the source and pins every
name to its id: a renumbering silently makes an imported toolbar button invoke a different action.
Similarly `check-version.sh` compared the tag to the marketing version and nothing else, so "semver +
monotonically increasing build number" — the whole of F-314 — was unchecked.

**Three of my own expectations were wrong**, and each was worth the round trip: a button writes its
path to `.bar` twice (icon and command), each panel path appears in session.ini under more than one
key, and two panels in a window of odd width centre to 504 and 503, not to a difference of zero. The
tolerance now lives in the report as `equal=yes` rather than in a scenario trying to spell it as a
substring. A fourth was subtler: the Quick Look check read window *titles*, and a system panel has
none — so it reported only the main window and passed without showing anything. It asks Quick Look
directly now, and gets `exists=true visible=true item=notes.txt`.

**Genuinely blocked, and now said so in the row rather than left implied:** F-218 needs an SMB server
the guest does not have, and F-315's signing, notarization and appcast need an Apple Developer ID and
somewhere to host a feed. Both are `partial` or annotated instead of quietly `done`.

## 2026-08-08 (F-193) — A server as one side of the synchronisation

The row had been `partial` since I15 with the note "an FTP site or a plugin filesystem may not". The
reason was structural rather than missing work: `SyncScanner` and `SyncExecutor` were entirely
synchronous, and a server is not.

**The safety net first.** Both lived in `SyncWindowController`, and no test bundle imports PCApp — so
the code that decides which files a synchronisation will copy, and the code that copies them, had no
tests at all. Moved to PCOperations unchanged, then covered (mask, subdirectories, hidden components,
content comparison at equal size, a zip side, each action actually happening, and that a file no action
named is left alone), and only then made asynchronous. Breaking the mask filter and the hidden check
fails the right tests, so the net is real.

**Against the protocol, not against FTP.** The side is a `VirtualFileSystem`, because everything a sync
needs of one is already there: list, stat, openRead, openWrite, mkdir, delete. So SFTP and a filesystem
plugin work without the engine knowing either exists — which is what the row asks for, and less code
than an FTP-specific path would have been.

**The listing is the server's to write.** A relative key becomes a local path on the other side, which
is the same shape as a crafted archive member — so the scanner drops a component that is not a name,
and the download checks containment again on the way out. The two are far apart enough that one of them
will be edited alone one day. Removing the first makes the test fail with an entry named `..` offered
as a file to sync.

**Refused rather than half-done:** server-to-server (the bytes would travel down and up through this
machine; moving them directly is FXP, F-216) and archive-with-server. Both are refused before the
window opens, not as a list of per-file errors afterwards. Deleting on a server is permanent — there is
no Trash to honour — and that is said where it happens.

**Proved against a real server.** The unit tests drive the remote side through LocalFS: a genuine
`VirtualFileSystem`, the same code path, but nothing crosses a socket. The `sync-sftp` VM scenario talks
SFTP to the guest's own sshd, and what arrived is asked of `ssh` afterwards — `one two`, read back from
the server, including the file in a subfolder, which required the sync to create that folder remotely.

## 2026-08-08 (interpreter sweep) — Four ways a file could act on the machine

After the release, the second step of the agreed order: go through every place where a string from
somewhere else reaches something that *interprets* it, rather than waiting for the inventory to point
at one. The first sweep found this class three times by accident (a file name in a shell line, a member
name in a path, a password in argv); this one looked for it on purpose.

**What the class covers, and what was cleared.** Shell command lines, the AppleScript that carries a
command to the root shell, regular expressions, CSV/TSV, packer argv, localized format strings, URL
schemes, archive and server listings becoming local paths, XML, and the HTML the viewer renders. Checked
and *dropped*, because assuming would have cost real code: `NSPredicate` (none exist), the regex sites
(deliberate or already escaped), `CopyEngine`/`MoveEngine`/`DeleteEngine` (they list with
`FileManager.contentsOfDirectory`, which never returns `..`), `NSKeyedUnarchiver` (not used anywhere),
`XMLParser` (defaults to not resolving external entities — measured), and `javascript:` links in the
viewer (JavaScript is off, so they do not run).

**Four defects.**

1. *The panel's extract walk wrote above the destination.* The archive extractor refused a member that
   would land outside; the panel's own walk — "copy out of an archive", and the same code when the
   source is FTP — built its paths from the same `fs.list()` entries and refused nothing. Measured, not
   assumed: a zip containing `../escaped.txt` lists as an entry named exactly `..` of kind `.directory`,
   so the walk created `<destination>/..` — the parent — and wrote the payload there, reporting success.
   The rule is one implementation now (`PCFoundation.PathContainment`). Neutering either of its two
   layers leaves the extractor's end-to-end tests green, which is why the new tests pin them separately.

2. *An XML file could read your other files.* `XMLDocument(data:options: [])` resolves external
   entities. Three places parse XML with it — the tree view, XPath, "format XML" — and all three are
   handed a file the user merely opened. A `<!ENTITY x SYSTEM "file:///etc/passwd">` had the contents
   substituted into what the app showed; a `http://` entity made the app fetch a URL. The first reading
   of this was "Foundation does not do that by default", and the probe said otherwise —
   `.nodeLoadExternalEntitiesNever` is what actually stops it, and `.SameOriginOnly` throws for the
   data-based initializer.

3. *Previewing a document told somebody that you opened it.* The viewer's comment said a previewed page
   "cannot run active content or phone home" because JavaScript is disabled. An `<img>` needs no
   JavaScript. Measured with a listening server: the request arrived. Two blocks, because the paths
   differ — a CSP in the generated Markdown document, and a content rule list on the web view for HTML
   files that are not ours to add a header to. One rule per scheme, because WebKit answers
   `^(https?|wss?)://` with "Disjunctions are not supported yet" and a list that fails to compile fails
   *open*.

4. *The assistant's approval gate had a door beside it.* `run_command` invokes any `cm_*`, and its
   capability was `.runCommand`, which is not one of the mutating ones. So `delete_permanently` returned
   a plan to approve and `run_command("cm_DeleteReal")` returned `ok` — the same deletion, nothing to
   approve. Commands are judged by what they change now, classified from the registry's category, with
   an unrecognised category counting as mutating.

**Two claims in comments turned out to be false** ("cannot phone home", "local only"), and one in the
inventory. That is the pattern worth remembering from this sweep: the places where nobody had measured
were exactly the places where a comment said measurement was unnecessary.

**Two new VM scenarios, both mutation-verified**, because neither defect is visible in a screenshot or
in what the app says about itself: `zip-slip` reports what is in the destination *and* in its parent
(and says `escaped.txt` in the parent when the guard is removed), and `viewer-beacon` asks a server on
the guest whether anything arrived — with a self-test request during setup, so "nothing arrived" cannot
pass by the witness being dead. It answers `viewer-fetched` against a build without the blocks.

## 2026-08-08 (evidence sweep, batch 24) — A test that prevents a defect rather than finding one

Four rows (F-153, F-155, F-156, F-254). No defect.

Saved search templates live in one JSON file, and a decode failure becomes an empty list — every saved
template silently gone, with the file still on disk holding all of them. That is one added non-optional
property away, at any time, and the user's reading of it would be "the app forgot my searches".

It holds today: a file written by an earlier version loads, and so does one carrying a field this
version does not know. Both are pinned now, which is the point — the next person to add a property to
`SearchTemplate` gets a failing test instead of a silent data loss in the field. That is the only kind of
test worth writing for code that is already correct.

The keymap (30 tests plus `check-keymap.sh`), search-in-archives and the results listing already had
their coverage; those rows needed pointers recorded.

Rows without evidence: 25 → 21.

## 2026-08-08 (evidence sweep, batch 23) — A limit that changed the answer

Five rows (F-170…F-176), one defect.

**`[=provider.field]` silently expanded to nothing above 500 files.** The values are fetched before the
rename dialog opens, and that fetch was capped "for latency" — so a selection of 600 photos renamed by
their EXIF date got the date left out of every single name. Renaming several hundred photos by a content
field is not an edge case; it is the case the feature exists for.

The cap itself was reasonable: resolving these means a plugin call per file per field, and most renames
never mention them. What was wrong is that it applied *before* the mask was known, so it decided the
result rather than avoiding wasted work. It now applies only when the masks do not ask for the fields;
when they do, the values are fetched however many files there are, once, and the preview refreshes. A
slow dialog is better than a wrong name.

**The engine's half is pinned too**, including the shape the defect took: with the values missing, every
file resolves to the same name, and the collision flag is what stops that batch from running. So the
damage was bounded — but only by a second mechanism, and the user saw a preview full of identical names
with no hint why.

The placeholder engine itself (64 tests) needed pointers recorded, not more tests.

Rows without evidence: 30 → 25.

## 2026-08-08 (evidence sweep, batch 22) — The quoted path was the broken one

Two rows (F-066, F-083), one defect.

**`cd "Zwei Wörter"` did not work, while `cd Zwei Wörter` did.** The quotes ended up inside the resolved
path, so the folder was not found — and that is backwards from every shell a user has ever met, where
quoting is precisely the thing that handles a space. One matching outer pair is stripped now; a name that
genuinely contains a quote is still reachable by not quoting it, which is also what a shell does.

Worth noting what made this findable at all: the unquoted form working is a nicety (the whole rest of the
line is taken as the path), and it is exactly why nobody hit the bug — the habit that fails is the one
people bring *from* the shell, and the habit that works is the one this field taught them.

**F-083 holds.** Trash is the default, Shift+F8 forces a permanent delete even when it is not, the
confirmation says which of the two it is, and the administrator retry is offered only after a permanent
delete has actually left something behind — quoting its paths through the single shell quoter that
batch 9 consolidated.

Rows without evidence: 32 → 30.

## 2026-08-08 (evidence sweep, batch 21) — A file macOS calls hidden was not

Eight rows (F-003, F-004, F-007, F-009, F-014, F-020, F-021, F-028), one defect.

**"Show hidden files" only ever knew about the dot.** `chflags hidden` sets `UF_HIDDEN` — it is how the
system hides `/usr` and `/bin`, and how a user hides a file without renaming it — and such a file stayed
visible with the toggle off. The flag was *already* being read into `bsdFlags` for the attribute column,
where it shows as "h"; it simply was never asked about. The row has promised "dotfiles + hidden flag"
all along. Checked with the system's own `chflags`, so the fixture is what macOS considers hidden rather
than what this code believes it wrote.

**The breadcrumb had no test**, and it decides *where a click navigates* — a wrong cumulative path takes
the panel somewhere the user did not point at, which reads as the app losing its place rather than as a
parsing bug. Moved to `PathSegments` and pinned: doubled and trailing separators collapse to the same
target, and every segment's path is a prefix of the next.

**One hypothesis dropped:** an `smb://` address *would* come apart in that function ("smb:" becomes a
segment). It never gets there — that form is handed to the system to mount, and the panel then shows the
`/Volumes/…` path. Verified before deciding it was not a defect; the reason is now in the comment so the
next reader does not have to repeat it.

The remaining rows in this batch are visual and already carried by the screenshot scenarios; they needed
their pointers recorded, not new tests.

Rows without evidence: 40 → 32.

## 2026-08-08 (evidence sweep, batch 20) — Num/ did nothing

Eight rows (F-050…F-058), one defect, and the engine behind it was never at fault.

**Restoring the selection from before the last operation did nothing at all.** In the panel every
selection operation goes through one helper that saves the current selection to the history first —
correct for every operation except this one, and the restore was routed through it too. So it pushed
the current selection and then popped exactly what it had just pushed. `SelectionState` itself is right
and has 88 tests; the defect lived entirely in two lines of wiring.

**And the scenario I wrote for it passed on the broken build.** The harness checks by substring, and
`marked=1` is a substring of `marked=10` — which is precisely what the unfixed code produced. It only
came out because I ran the mutation and read the *number* rather than the verdict. The expectation now
carries the line break, and `!marked=10` guards the same trap from the other side.

That is the fourth time in this sweep that a check needed checking, and the pattern is consistent: a
test written against the fixed code passes for reasons the author has not examined. Running it against
the defect is not a formality.

Rows without evidence: 47 → 40.

## 2026-08-08 (evidence sweep, batch 19) — The sort was only ever timed

Three rows (F-025, F-027, F-034). No defect — but the comparator every listing in the app goes through
had exactly one test, and it measured *speed*: how fast it sorts 100 000 entries, never whether the
order is right. All four orders and their reverses are pinned now, plus folders-first on and off, the
name fallback for equal sizes, and the natural order (`file2` before `file10`).

**Two hypotheses I chased and dropped**, both worth the time they cost:

  * Names differing only in case — possible on a case-sensitive volume and on every Linux share — would
    reshuffle between refreshes *if* `localizedStandardCompare` called them equal. It does not; it orders
    them deterministically. Measured, then pinned so a future switch to a different comparison cannot
    quietly introduce the flicker.
  * The sort treats an `.appBundle` as a file while the *search* treats it as a directory. That looks
    like drift and is not: they answer different questions — "does it sort with the folders?" and "can
    one walk into it?" — and both answers are right. Changing either would have been the defect.

Branch view walks only true directories, so a symlinked folder is listed rather than descended. Also
deliberate (a link can point back up its own tree), and now written down rather than left to be
rediscovered.

Rows without evidence: 50 → 47.

## 2026-08-08 (evidence sweep, batch 18) — Two decimal separators in one status bar

One row (F-030), two defects, both visible every single day and neither ever reported.

**The unit ladder stopped at gigabytes.** A 4 TB volume's free space read "4096.0 GB", a 16 TB one
"16384.0 GB". It carries on to T and P now.

**And the separator did not match the line it sits in.** `String(format: "%.1f")` writes a decimal point
whatever the language, while `SelectionSummaryFormatter` a few pixels away is locale-aware — so a German
user read "4096.0 GB" next to "2,0 M".

**The second could not be fixed on its own**, and finding out why was the useful part: the Find Files
dialog *writes* these strings into its size fields when a template is loaded and *reads them back* when
the search starts. Producing "1,5 MB" before `parse` accepted a comma would have turned a size filter
into no filter at all — silently. So the parser learned both separators first, and the round trip is now
pinned in three languages.

**Two existing tests then failed, and they were wrong.** They asserted "1.5 KB" while calling the
*machine's* locale, so they passed in CI (English) and failed on a German Mac — they were testing the
runner's language, not the formatter. Given an explicit locale, which is what they meant.

Rows without evidence: 51 → 50.

## 2026-08-08 (evidence sweep, batch 17) — A mask that selected the wrong file

Three rows (F-035, F-055, F-057), one defect — in the single matcher behind select-by-wildcard, the quick
filter, the search's name masks, the sync filter and the type-colour rules.

**It turned a mask into a regular expression by escaping the dot and nothing else.** Every other
metacharacter therefore kept its regex meaning, and file names are full of them. The consequence was not
"finds nothing", which somebody would have noticed:

  * `Bericht (2026).pdf` did **not** match the file of that name, and **did** match `Bericht 2026.pdf`;
  * `a+b.txt` matched `aab.txt`; `[Entwurf].doc` matched `E.doc`; `Preis $5.txt` matched nothing.

Eight of twelve realistic cases were wrong when measured. Select-by-wildcard hands its result straight to
the next operation, so this is a wrong *selection*, not a wrong display. Only `*` and `?` mean anything
now; everything else goes through `escapedPattern`.

**And a gate for a mistake I made four times in one session.** Four new test files — `ContentFieldValues`,
`ParamExpanderQuoting`, `FinderTagWrite`, `WildcardMask` — each sat unexecuted behind a green suite until
I counted the passing test names, because `xcodegen` had not been re-run or the bundle went into an
aggregate target rather than the `AllTests` *scheme*. `Tools/check-tests-registered.py` now fails if a
test file belongs to no bundle, or a unit-test bundle is not in that scheme. It reads `project.yml`
rather than the generated project, because a stale `.xcodeproj` is exactly the failure being guarded
against. Verified against both cases.

Rows without evidence: 54 → 51.

## 2026-08-08 (evidence sweep, batch 16) — Spotlight answers a different question

Four rows (F-159, F-290, F-294, F-299). No defect, one honesty problem.

**Ticking "Use Spotlight" changes what the search means.** The index has no notion of a regular
expression, a depth limit or a selection scope, so those controls simply stop applying — and that was
said only in the checkbox's tooltip, which is no help at the moment it matters, because by then the user
is reading a result list. The status line already named the engine ("… found (Spotlight)"); it now also
names whichever of the three was set and did not apply.

Not a defect, and I nearly treated it as one: the behaviour is deliberate and documented, the fallback
to the walker for non-local folders is there, and the predicate substitutes through `%@` rather than
building a string, so a name mask cannot alter the query. What was missing was telling the user at the
right time.

Rows without evidence: 58 → 54.

## 2026-08-08 (evidence sweep, batch 15) — A red tag that was not red

Two rows (F-291, F-292), one defect — and it is one only a non-English system, or a careful look at the
bytes, would show.

**Reading a Finder tag was always done right.** It resolves the colour from the trailing index of the
`_kMDItemUserTags` attribute, and its own comment explains why: the tag *names* are localized, the index
is not. **Writing did not follow that through.** It went through `URLResourceValues.tagNames`, which
stores a bare name — measured: setting `["Red"]` puts `"Red\n0"` on the file, and index 0 means *no
colour*. So a label applied from this app was a grey dot in its own column, a colourless custom tag in
the Finder, and on a German system a *second* tag sitting beside the "Rot" that was already there.

Matching and writing now go by colour index, through a small `setxattr` that produces what the Finder
actually reads. `FinderTagColor` moved into its own file to be testable at all — the cell drawing around
it pulls in the theme and the icon cache, and neither has anything to do with what a tag is.

**What was not wrong:** the share sheet already drops paths that no longer exist and beeps when nothing
is left. I went looking there first and found it handled.

**And two of my own, both about a test that does not run.** The new bundle went into an aggregate target
instead of the `AllTests` *scheme*, so the suite was green with five tests unexecuted — the third time
this session. Then it would not compile, because `PanelCells.swift` needs half of PCApp; that is what
prompted the extraction, which was the right move anyway.

Rows without evidence: 60 → 58.

## 2026-08-08 (evidence sweep, batch 13) — A CRLF code file was one line six million characters wide

Not a row I set out to check. Six of the sweep's defects had been the same Swift trap, so instead of
another row I grepped the whole tree for it — every `== "\n"`, `== "\r"` and `split(separator: "\n")`.
Twenty hits, most of them harmless, and one that matters a great deal.

**The syntax-highlighted code view built its line ranges from `[Character]`.** A CRLF is one Character
equal to neither `"\r"` nor `"\n"`, so a Windows-style file produced exactly one range. Not merely a
wrong line count: the view sizes its frame by the longest line, so a 6 MiB file became a single line six
million characters wide and the layout never finished. The mutation run proves it — with the old code
the scenario writes no report at all, because the app is still trying.

**Why nobody saw it:** that view is used only between 4 and 16 MiB. Below 4 MiB an `NSTextView` does the
wrapping, and AppKit gets CRLF right. The plain-text view indexes *bytes* and was never affected either.
So it needed a large code file with Windows endings — which is exactly what a generated SQL dump, a
minified bundle or an exported XML is.

**Two of my own on the way there.** My first fixture was 4.0 MB and I read the scenario's silence as the
fix not working — it was *below* the 4 MiB threshold and had quietly exercised the AppKit path instead.
And I guessed the expected line count twice before computing it from the file.

**Three sites in that grep were not defects**, and checking beat assuming: `String.contains("\n")` finds
a CRLF (it is substring matching, not Character comparison), and the structure scanner compares single
UTF-16 units, where `\r` and `\n` genuinely are separate. Had I "fixed" those I would have broken
working code.

Rows without evidence: 64, unchanged — F-110 already carried evidence from the encoding work.

## 2026-08-08 (evidence sweep, batch 11) — Six files, eight lines

Two rows (F-091, F-092), two defects, both in the list this app puts on the clipboard.

**The TSV form had no escaping at all.** Tab-separated values have no quoting mechanism — a tab *is* the
column separator and a line break *is* the row separator — so a file name containing either simply broke
the table: six files came out as eight lines, and a name with a tab in it shifted every column after it.
This is what "copy file details" produces for pasting into a spreadsheet, where a shifted column does
not look wrong. It looks like data.

**And the CSV guard had the CRLF trap in it**, for the sixth time in this sweep: it compared each
Character against `"\n"` and `"\r"`, and in Swift a CRLF is one Character equal to neither, so a name
containing one went through unquoted and split the row.

Escaped rather than stripped, so the original name stays readable — and the backslash is escaped too, or
a file really called `a\tb.txt` and one containing a tab would come out identical and neither could be
read back.

**One thing I got wrong on the way:** my probe reported "6 files, 7 TSV lines" after the fix and I nearly
went looking for another defect. The seventh line is the header, which `format` writes by default. The
measurement was right; my expectation had forgotten a parameter.

Rows without evidence: 67 → 65.

## 2026-08-08 — 136 invisible windows

A leftover VNC window after every run, reported from the outside. The cause is one missing flag:
`tart run --vnc-experimental` **opens** the `vnc://` URL it prints, which launches Screen Sharing — and
nothing ever closes it. Each run left a dead window inside a single Screen Sharing process; **136** of
them had accumulated, one per VM this machine has booted. Invisible, because they are windows in another
app's window list rather than processes, so nothing in a process listing or a VM listing showed it.

`--no-graphics` alongside the VNC flag suppresses the window. Measured before changing anything, because
the harness lives on those screenshots: the log line changes from "Opening vnc://…" to "VNC server is
running at vnc://…" — which the existing parser still matches — and a `vncdo` capture through it returns
the full desktop. A scenario run afterwards added no new connection, where every earlier run had added
one.

Three call sites had the flag missing (`regress.py`, `capture.py`, `run-test.sh`), so
`Tools/check-vm-flags.sh` now checks them all: a one-line rule spread over three files is the kind that
comes back when a fourth is added.

What was *not* wrong: the VMs themselves. Clones are stopped and deleted properly, and `tart list` shows
nothing orphaned — which is why this went unnoticed for so long.

## 2026-08-08 — A harness flake worth naming

Twice in this session a *full* VM run reported a run of scenarios with empty reports — once the two SFTP
ones, once ten in a row — while every one of them passed when run alone, and the next full run was clean.
The app is fine: a scenario log from such a run stops 21 lines after launch, so the guest stalls rather
than the app crashing.

No root cause. Recorded rather than glossed over, because the failure mode is indistinguishable from a
real regression at a glance, and a suite that occasionally reports ten false failures teaches people to
skim its output — which is how a true one gets missed. The rule for now: an empty-report run is not a
result, re-run before believing it. `regress.py` already distinguishes "report empty" from "report
wrong", which is what makes the pattern visible at all.

## 2026-08-08 (evidence sweep, batch 10) — Compare Directories holds

One row (F-191), no defect — worth recording as plainly as the defects are.

The macOS trap this feature is easiest to fail is Unicode normalisation: the same name arrives decomposed
from one volume and composed from another (a Mac and a Linux server), and seen as two files each side is
marked "only here", so a sync copies both ways for ever. It does not happen here, and not by anything
this code does: Swift compares Strings by canonical equivalence, so the lookup already treats the two
spellings as one key. Pinned in a test, because that is invisible in the source and a future rewrite to
compare bytes or UTF-8 views would break it silently.

I expected a defect and did not find one. Checking beats fixing: had I "corrected" this by hand I would
have added normalisation that was already there and possibly broken the case rules beside it.

Rows without evidence: 68 → 67.

## 2026-08-08 (evidence sweep, batch 9) — A file name could run a command

One row (F-252), and the most serious defect the sweep has turned up.

**A toolbar button or a user (Start-menu) command builds a line out of `%`-tokens and hands it to
`/bin/sh -c`.** The values come from the panel, so they are file names — untrusted input, arriving with
a download, an extracted archive or a shared volume. The expander wrapped a value in *double* quotes,
and only when it contained whitespace. Therefore:

  * `$(id).txt` and `` `id`.txt `` went into the line raw and were executed;
  * `a;id;b.txt`, `a|id.txt`, `a&&id.txt` likewise — no whitespace, no quoting;
  * `he said "hi".txt` broke out of the quoting outright.

Double quotes would not have been enough either: a shell substitutes `$(…)` and backticks *inside* them,
and the `.app` branch beside this used exactly that. Every value is single-quoted now, through one shared
`ShellQuoting.quote` that the elevated save and the toolbar path also use — there were three hand-rolled
quoters and only the one guarding the root shell was right.

**The project already knew how to do this.** `PCShellQuoteTests` has run the quoting for the elevated
save through a real shell for a long time, with a test literally called "an injection attempt stays one
argument". The %-expander simply never used it. Two implementations of one rule, and the one nobody was
worried about was the wrong one.

**Sixteen existing tests failed on the fix, and they were right to.** They pinned the old rule — "no
quoting when the value has no spaces", "quotes only names with spaces". The behaviour those tests
described *was* the defect, so the expectations moved; what a program actually receives is now checked
against `/bin/sh` instead.

**And two of my own.** The new test file did not run at all until `xcodegen` had seen it — the same trap
as batch 6, and the suite was green while nine tests sat unexecuted. Then my test template `printf '%s\n'
%S` failed, because `%s` is a token to this expander too: I had written the collision the `%%` escape
exists to avoid.

Rows without evidence: 69 → 68.

## 2026-08-08 (evidence sweep, batch 8) — The config file reformatted itself

Two rows (F-275, F-277), one defect and one design question the existing tests settled for me.

**These files are documented as ones people edit by hand, and the first save reformatted all of them.**
The serializer rebuilt every pair as `key=value`, so `Appearance = dark` became `Appearance=dark` on lines
nobody had touched — a diff nobody asked for, in a file that is meant to invite hand-editing. Untouched
lines are now written back verbatim, and setting a value changes only that line and keeps its spacing.
Every other caller of the serializer — columns, associations, plugin config — is a save path too, so they
all get it.

**Then an existing test told me the change was half right.** `testINIRoundTripsThroughTheProjectsOwnParser`
failed: the *Format* command's whole purpose is to tidy an INI, and a preserving serializer makes it do
nothing. Two callers, two intents — hence `serialized(normalizing:)`. Saving preserves; Format
normalizes. Without that test I would have shipped a Format button that reports "unchanged" on every
file with a space around its equals sign.

**Two things I deliberately did not "fix".** A semicolon stays part of a value — INI has no inline
comments (neither does Windows' own profile API), and a semicolon-separated path list, which is what
these files hold, would be cut at the first one. And everything after the *first* `=` is the value. Both
were already right; treating either as a defect would have made the fix the defect.

F-277 (config root via launch argument or environment) already had tests and is what the VM harness uses
for every scenario; that row only needed its pointers recorded.

Rows without evidence: 71 → 69. 38 VM scenarios, 0 conflicts.

## 2026-08-07 (evidence sweep, batch 7) — A rule nobody checked, and a hole in a gate

One row (F-210), and two findings that are both about *checking* rather than about behaviour.

**"No secret ever reaches ftp-sites.ini" was stated in three comments and verified nowhere.** It holds —
but it is exactly the kind of rule broken by adding one convenient line to a serializer, and the file is
plain text in the config folder, backed up and synced. A test now serializes a site carrying a proxy
password and asserts that neither the value nor a password-shaped *key* appears, while the ordinary
fields still do, so it cannot pass by writing nothing. Verified by adding the one convenient line and
watching it fail. (My first version of that test banned the substring "password" anywhere and failed on
`auth=password`, which names the *method* — the test was wrong, not the code.)

**An authenticated proxy could not be used at all.** The model carried `proxyUser` and `proxyPassword`,
the ini had a `proxyuser` key that round-tripped, and the connection manager offered host, port and type
— no login fields. So the password had nowhere to come from and nowhere to live. Added, with the
password in the Keychain like the site's own and keyed by the proxy rather than the site, since one
proxy usually serves all of them.

**And a hole in the localization gate, found by falling into it.** `check-translations.py` reads the
string catalogue, so it cannot see a string that never reached the catalogue — and a `String(localized:)`
only gets there when somebody runs `extract-strings.sh`. The "%lld file(s) were not renamed" message from
batch 4 shipped untranslated in all nineteen languages with the gate green, and stayed that way for
three commits. `Tools/check-strings-extracted.py` now reads the *source*: every plain literal must be a
key in the catalogue. Interpolated strings are skipped deliberately — they become format keys that cannot
be matched textually, and a gate that cries wolf is one nobody reads.

Rows without evidence: 72 → 71.

## 2026-08-07 (evidence sweep, batch 6) — The password was in the process list

Four rows (F-120, F-134, F-135, F-136), one defect.

**"Test archive" really does test (F-135).** Checked by damaging an archive rather than by reading the
code: one flipped byte inside a member's compressed data is reported, three damaged members come back as
three, and an intact archive is not called damaged. A verifier that always answers "intact" would be
worse than none, because it is the answer someone acts on before deleting the originals.

**But my first attempt at that test reported the product broken, and it was wrong.** It flipped byte 80
of a 140-byte archive — 4000 bytes of repeated text deflate to 32, so byte 80 is in the central
directory and nothing the CRC covers had changed. The test now reads the local header and computes where
the compressed data actually is. Two false alarms of mine in two batches, both from a test that assumed
a layout instead of asking for one.

**The defect: the archive password was passed as `-p<password>` (F-136)** — which puts it in the
process's argument list, where `ps -ww` shows it in full to anything running as the same user for as long
as the archive takes to write. Measured on a running pack, not supposed. `7z -p` with no value reads it
from standard input instead; verified by packing that way, opening the result with the right password and
watching a wrong one be refused. A test now asserts the password never appears in the arguments — for
that, `command(for:…)` is internal rather than private, which is the one thing about this that cannot be
checked from outside.

Nested archives (F-134) and viewing files inside them (F-120) already had tests; those rows only needed
their pointers recorded.

Rows without evidence: 76 → 72.

## 2026-08-07 (evidence sweep, batch 5) — Archives: a dash in a name, and zip slip

Two rows (F-131, F-132), two defects — and one of them is a security hole rather than an inconvenience.

**A file whose name begins with a dash made packing fail completely (F-132).** The packers are driven by
command line and the names went in unguarded, so `-x.txt` was read as a *switch*: `tar` answered "Can't
specify both -x and -c" and the whole operation failed, in every format, with a message from the packer
that says nothing to the person who pressed the button. A file called `-C` would have been worse than a
failure — tar would have changed directory and archived something else. The names go after `--` now,
which both `tar` and `7z` honour (measured, not read).

**A crafted archive could write outside the folder the user chose (F-131).** "Zip slip": a member named
`../../evil.txt`, extracted, landed beside and above the destination while the extraction reported
success. An archive is data from somewhere else and this is the oldest trick there is. Members that
would land outside are skipped; the harmless ones in the same archive still arrive. Absolute member
names were already contained.

**New gate:** `Tools/check-pack-formats.sh` — the archives this app writes, read back by Python's
`zipfile`/`tarfile` and by `7z t`, with the compression level checked by comparing a stored against a
maximum archive so a level that never reaches the tool cannot pass.

**And a false alarm of my own worth writing down.** The zip-slip test asserted against the *system* temp
directory, so on the run after the fix it failed on a file its own earlier, pre-fix run had left there —
and the failure read as "still broken". The test now works two levels down inside its own private
folder. A test that litters a shared directory will eventually lie to you.

Rows without evidence: 78 → 76.

## 2026-08-07 (evidence sweep, batch 4) — Undoing a batch rename did nothing

One row (F-170…F-176), one defect, and it is the one that costs a folder rather than a file.

A batch rename can contain a **cycle**: `a → b` together with `b → a`, or a longer rotation. Renamed one
at a time in the obvious order, the first move destroys the second file. The forward direction knew this
and staged every rename through a unique temporary name — correct, and it had no test.

**Undo did not stage.** Reversing a swap moved `b` back onto the still-present `a`; both moves failed,
the log was consumed, and the user was told the rename had been undone while nothing had changed. Two
phases both ways now, and the 64 existing engine tests were no help here because they all stop at
computing the new *names* — the losing happens afterwards.

The staging moved out of the panel controller into `RenameBatchEngine`, where it can be tested at all,
and the panel keeps what is genuinely its business: carrying each file's comment to the new name,
registering the undo, and — new — **saying when a rename did not happen**. Names the batch could not
deliver (a target occupied by a file outside the batch, an empty name, a name with a separator in it)
used to be dropped without a word.

Verified the way it has to be: by putting the single-phase undo back and watching the swap and rotation
tests fail. Writing the fix and the test together tells you nothing on its own.

Rows without evidence: 78, unchanged — F-175 already carried evidence from batch 1.

## 2026-08-07 (evidence sweep, batch 3) — F7 and the duplicate finder

Two rows, four defects — and this time they are all about a dialog being told something and doing
something else.

**F7 "create folder" (F-082).** Two tests existed, for the two shapes the feature was written for:
`a/b/c` and `one|two|three`. A dialog receives everything else.

  * `../elsewhere` created the folder *outside* the directory the panel is showing. The listing did not
    change, nothing said why, and the obvious response is to try again.
  * `.` reported the parent itself back as freshly created.
  * A whitespace-only entry reported success and created nothing at all.

All three refused now. Deliberately still allowed: a leading `/` means "here" (it is what anyone used to
a shell types, and it was already contained), and a backslash is part of the name — it separates path
components on Windows, not here, and treating it as a separator would make a legal macOS name
unreachable.

**The duplicate finder (F-158).** Symlinks were already safe — a link stats as a link, not a file, so it
never reached the comparison. That is the direction that would have been dangerous, and it holds. But
**two hard links to one file were reported as duplicates**: deleting one frees nothing, so the window
offered reclaimable space that does not exist. Collapsed by device+inode now, and only for a file system
whose paths are real files — `localFileIfAvailable` looks like the general way to ask, but on an archive
it *extracts* the member, so asking per candidate would unpack the whole set to learn nothing.

Rows without evidence: 80 → 78.

## 2026-08-07 (evidence sweep, batch 2) — Copy metadata, clone, verify, links

Four rows (F-087/088/090/093), one defect. A much better yield than batch 1, and that is worth saying:
the copy engine holds up.

**What survives a copy, asked of the file system rather than of Foundation.** `stat`, `xattr` and
`ls -le` as witnesses — `attributesOfItem` is the same layer the engine writes through, so it would
mostly show that one API agrees with itself. Mode (including a 0600 that must not be widened on the way
through a 0644 create), mtime, extended attributes, resource fork, ACL, and symlinks copied *as links*
with relative targets kept verbatim: all correct. The APFS clone path and the streaming path agree, and
the three link kinds really are three things — the hard link shares the target's inode and raises its
link count, the alias carries the "book" magic and still resolves after the target is renamed.

**The one defect: "verify after copy" only applied to foreground copies.** Nothing said so, and the
background queue is exactly what one picks for the large copies where verifying is worth the time. Both
paths now go through one method, so they cannot drift apart again.

**Two mistakes of mine, both in the instruments.** The clone-versus-streaming comparison originally
checked the two runs only against each other — when I turned metadata copying off to see whether the
tests bite, it stayed green, because both runs had lost the same thing. It is anchored to the source now.
And both alias tests reported the product broken because *I* read a bookmark **file** as raw bytes
instead of with `URL.bookmarkData(withContentsOf:)`.

**New in the harness: `modaldump`.** It could keyboard-walk a modal dialog but never read what it *said*,
so an alert with the wrong text — or one that should have appeared and did not — was invisible. It
schedules into the modal run-loop mode and dismisses the alert afterwards, because `runModal` never
returns on its own and the scenario would otherwise write no report at all.

Rows without evidence: 84 → 80. 38 VM scenarios, 0 conflicts.

## 2026-08-07 (evidence sweep, batch 1) — Six defects behind five "done" rows

Started working through the 87 rows the inventory calls `done` with nothing backing them, worst-damage
first. One batch, five rows, six defects — and five of them are the *same* Swift trap.

**`"\r\n"` is one Character.** `split(separator: "\n")` and `$0 == "\n"` therefore do not split a CRLF
file at all. This codebase already carried that scar twice (`INIDocument`, `LineEndings`), and it turned
out to be sitting in four more places, every one of them a format that arrives *from Windows*:

  * **`.sfv` checksum files (F-097)** — 0 entries parsed. A Windows-written .sfv verified nothing at all;
    `.md5` was worse, producing one invented entry whose filename was the rest of the file, so the user's
    intact files were reported missing. A BOM separately swallowed the first line of any digest file.
  * **`.crc` split sidecars (F-095)** — parse failed, so `combine` refused the set outright. `.crc` is a
    Total Commander format, which is precisely why it exists, so this defeated its only purpose.
  * **`descript.ion` (F-023/F-374)** — one comment survived, holding the whole rest of the file as its
    text; every other comment vanished. This is a 4DOS format read and written by TC; CRLF is the
    *ordinary* case. Two rounds of work on this file had never fed it one.
  * **the rename-by-editor list (F-175)** — `components(separatedBy: "\n")` does split a CRLF file, but
    leaves the carriage return on each line, and `.whitespaces` does not contain one. Every renamed file
    got an invisible `\r` at the end of its name. Legal on macOS, so it succeeded quietly and produced
    names that nothing else matches.

**And one that was not about line endings.** `SplitCombineEngine.combine` read each part whole into
memory while the type's own comment claimed "streaming keeps memory flat regardless of file size" — for
the part sizes people actually choose, a CD or a DVD, that is hundreds of megabytes to gigabytes. Now
streamed, and the comment is true.

**What the sweep is actually worth.** Every one of these lay under a row marked `done`, and none was
found by reading — the checksum and descript.ion features both already had unit tests, all written with
LF, which is exactly why the defect survived. Two new gates now feed the real shapes in:
`Tools/check-checksums.sh` (hashlib/zlib plus checksum files written by the system's own `shasum`/`md5`,
in LF and in CRLF+BOM) and an extended `check-descript-format.sh` that now checks what the parser *makes*
of each file, not only that the bytes survive an encoding round trip. Both verified by putting the old
line back and watching them fail.

**A mistake of mine worth keeping.** My first inventory edit appended to `cells[2]` — but a row starts
with `|`, so that is the *feature* column, not the notes. Three rows briefly claimed the wrong thing in
the wrong place. Rows down from 87 to 84.

## 2026-08-07 (last) — The assistant can write a comment (F-380)

The last item from the notes review: let the AI suggest a note for a file. Two tools — `get_comment` and
`set_comment` — and a right-click action **AI ▸ Suggest a comment** that reads the file and proposes one
line. Writing is gated like any other write, and the plan the user approves **quotes the words** rather
than counting them: "write 34 characters to report.csv" is not something anyone can agree to.

**A defect the tools uncovered.** Both go through the host's own comment methods rather than a second
implementation — and reading that one revealed it was reading `descript.ion` as UTF-8. On the UTF-16 file
Total Commander writes (F-374) that does not garble, it *throws*: the code fell through to the Finder
comment and reported "no comment" for every TC-annotated file, while the Comment column beside it showed
the text. Anything asking through the plugin path — the Notes sidebar, now the assistant — was blind to
them. One line, and a VM scenario that fails without it (verified by putting the old line back).

**The plugin contribution surface had never been checked.** `menudump` reads the *main* menu, so every
AI ▸ / Notes / tag entry a plugin adds to the right-click menu was unverified. `plugin-context-menu` now
dumps a file's context menu; it is how I know the new action is actually reachable.

**Two of my own, both about instruments.** A test file added to a bundle does not run until `xcodegen`
has seen it — the suite was green and my nine new tests had not executed. And a scenario silently claims
every report key starting with `<its name>-`, so `notes-sidebar-tc` was adopted by `notes-sidebar` and
checked before it had run: green alone, red in company. Renamed, and the rule written down where the
table is defined.

**And a guard that was not enough.** I have a rule not to write `regress.py` without `ast.parse` first.
It parsed — and the file was broken anyway, because my comment had landed inside `KEYBOARD_REPORTS`,
leaving a bare `KEYBOARD_` expression that is valid Python and a `NameError` at run time. Parsing is not
executing.

## 2026-08-07 (later still) — A note about a *place* in a file (F-379)

Notes were about files. A note about the third line of a config file had to say so in its own text, and
nothing led back from the line to the note. Now a note's key may carry a position — `<path>#L<line>` — and
that is the whole of the storage change: to the note store it is still just a key, so the overview, the
search and the sidebar found it without being told anything.

**The viewer knows nothing about notes.** It asks the Notes plugin for a content field called "Note
lines" — the same mechanism that puts a plugin's column in a panel — and offers whatever comes back as a
group in its marks panel, beside the search hits. Writing one works the same way in reverse: the host
publishes `noteTarget` in the ordinary plugin context and invokes the plugin's own edit command. Uninstall
the plugin and the menu item and the group are simply not there; no code in the viewer changes.

**Four things I had wrong before the build agreed with me.** `ContributionRegistry.invoke` and
`ContentFieldRegistry.shared` do not exist (`dispatch(_:host:)` and a per-window instance do), the two
viewer views have no `firstVisibleLine`, and a stored property cannot live in an extension. Guessing an
API and building is cheap; the point is not to write the *tests* against a guess.

**And one I would not have found by reading.** My hand-rolled "which line is the caret on" was wrong at
the end of the text — the last position counted as a line of its own. `EditorLineIndex` already answers
exactly this question and already has a test for that case, so the right fix was to delete my version.

**A layout conflict that had been waiting for someone to open the panel with a tab in it.** The marks
panel's tab strip is 28 points tall and reserved 17 of them for a scroll bar it never needs, leaving 11
for a 22-point tab; AppKit broke the tab's height and logged it every time. `scrollerStyle = .overlay`.
Found because the new scenario is the first that opens that panel with a group in it.

**The dump now skips hidden views.** It used to report the marks panel's "No marks" placeholder *and*
the group next to it, because the placeholder is hidden rather than removed — so a dump could not be used
to check what is on screen. Both new scenarios read the rendered labels as well as the model behind them.

## 2026-08-07 (later) — FTP listings: a name with two spaces was unopenable (F-378)

Last of the parsers on the list, and the one with no second implementation to compare against — `ftplib`
does not parse listings and `curl` needs a server. So instead of a differential test, a battery of the
shapes real servers actually emit (vsftpd, ProFTPD, wu-ftpd, IIS, MLSD per RFC 3659), run through the
parser to see what it makes of each.

**One defect, and it makes a file unreachable.** The Unix branch split the line into fields and rejoined
the name with single spaces, so `two  spaces.txt` came back as `two spaces.txt` — a name that does not
exist on the server, so the file could not be opened, downloaded or deleted. A listing has no way to quote
a name, so the only reading that can be right is "the rest of the line", taken from the line itself.

**And one defect that was mine, not the app's.** The probe printed an `Int64` with `%12d`, a 32-bit
format, so a 5 GB file appeared as 1 GB and I briefly believed the size parsing truncated. It does not.
Both the real finding and my false one are now tests, the second so the next reader does not repeat it.

Everything else in the battery was already right, including the trap that has bitten three other parsers
in this codebase: `FTPListing.parse` normalizes CRLF *before* splitting and says why in a comment. That
lesson had been learned here already.

## 2026-08-07 — The archive readers agree with an independent one (F-377)

Third corpus, and this time the answer is that the code is right — which is worth as much as a defect,
provided the check could have found one.

The archives are *generated* by the system's own `zip` and `tar` rather than found: this machine has almost
none lying about, and generating them means the awkward cases are actually present instead of hoped for —
stored and deflated members, jar, tar in ustar/GNU/PAX flavours, gzip, a name longer than a ustar header
holds, Unicode names, and 120 members in one directory so an off-by-one in a central-directory walk shows
up. The witness is Python's `zipfile`/`tarfile`: separate implementations that know nothing about this
project. Result: 8 archives, ~1000 entries, **no disagreement on any entry or size**, and three injected
mutations (drop every tenth zip entry, report the compressed size, drop the last tar member) are all
caught.

**The one divergence is a documented decision, not a defect.** By the letter of the zip specification a
member name is CP437 unless bit 11 of the general-purpose flags marks it UTF-8 — but Info-ZIP on macOS
writes UTF-8 bytes *without* setting that flag, and so do most tools on Linux. Python follows the letter
and shows `Gr├╝├ƒe.txt`; this app reads UTF-8 and shows `Grüße.txt`, which is the name the file actually
has. The comparison now puts both readings on the same footing by comparing the bytes, and the reason is
recorded in `ZipReader` so nobody "fixes" it toward the specification and breaks every real archive.

Two mistakes of my own on the way, both in the *comparison*: parsing `tar -tvf` output I took the owner
column for the size, which made every entry look missing; and I read the diff backwards and briefly
believed the app was the one mangling Unicode names. Reading the archives with a library instead of
parsing tool output removed the first, and naming the two sides in the message removed the second.

`Tools/check-archive-listing.sh` keeps it, in CI, verified by breaking `TarReader` on purpose first.

## 2026-08-06 (night) — The encoding detector was wrong about 4 in 300 real files (F-376)

Next corpus, same method: 300 real text files over 64 KB from this machine, each asked "what does the
detector say" against "what does the *whole* file decode as". Two defects, both user-visible, both in the
path every file open takes.

**A UTF-8 file whose 64 KB sample ended mid-character was declared CP1252.** The sample is a fixed cut, so
its last bytes are very often half of a multi-byte character; validating those as well made the check fail.
The editor then showed mojibake and **saved it back that way**. 4 of the 300 files — all German transcripts,
because the more non-ASCII a text is, the likelier the cut lands mid-character. For CJK, where every
character is three bytes, it would be far more common than that. Fixed by trimming the sample to the last
complete character, dropping at most three bytes: a longer run of continuation bytes is genuinely invalid
input and has to stay in, or the check would call a broken file valid.

My first attempt at that fix did nothing, and the probe said so: it stripped only *continuation* bytes,
while the common case is a sample ending on the lead byte itself.

**The byte-order mark was detected and then left in the data.** `String(data:encoding:)` strips it for
UTF-8 and keeps it for UTF-16, so a UTF-16 file opened in the editor began with an invisible U+FEFF —
column 1 on line 1 meant the second character, and saving wrote the marker into the content underneath the
new one. There is now `EncodingDetector.decode` (and `withoutBOM` for the viewer, which decodes line by
line from a memory map and cannot use it).

**The negative cases were the important half.** Trading a false CP1252 for a false UTF-8 would be the worse
bug — a Latin-1 file would then decode to replacement characters instead of to something a user can
recognise and fix with the encoding menu. Latin-1 short and long, a lone high byte at the sample end, and
continuation bytes with no lead are all still CP1252; after the fix, 0 of the 300 files are misdetected.

One limitation left as it is, and now documented: bytes past the 64 KB sample are not examined, so a file
whose first 64 KB is pure ASCII and which turns Latin-1 later is read as UTF-8. That is the nature of a
sample, not a defect introduced here.

**And the harness stopped guessing how long to wait.** Three scenarios failed in one full run with
*every* expectation wrong — the signature of an empty report, not of a content mismatch. Late in a run of
thirty-plus scenarios the guest is slower, the app's own log shows ten seconds of image loading before it
is up, and the fixed settle expired before the automation wrote its file. The guest runner now waits for
the report the scenario is supposed to produce (up to 40 s more, twice a second), and an empty report is
reported as *empty* rather than as thirty wrong expectations. That misreading sent me looking at the wrong
code twice.

## 2026-08-06 (evening) — INIDocument never parsed a CRLF file (F-375)

**The differential sweep the last review recommended, and what it found.** 350 real
`.ini`/`.cfg`/`.properties` files from this machine, checked for the properties a settings file has to
survive: parse → serialize → parse identical, every section/key/value preserved, every comment and blank
line preserved, section order unchanged, and `set`/`remove` touching nothing but their own key.

**First result: my instrument was blind.** With `serialized()` deliberately made to drop every comment, the
probe reported *no findings* — because comparing parse → serialize → parse cannot see a loss that is
consistent. Extended to compare against the original text, it then caught the injected mutations (239
comment findings, 52 blank-line, 2811 section-order) and reported the real corpus clean.

**Second result, and the real one: `INIDocument` never parsed a CRLF file.** `split(separator: "\n")` does
not split at `\r\n`, because in Swift that is a *single Character*. A Windows-written INI came out as one
giant broken line — `[S]\r\na` as a key, every section header lost. Consequences: the Format button turned
such a file into nonsense, and **importing a real `wincmd.ini` from Total Commander silently found
nothing**, since that file always has CRLF. No test had ever used a CRLF fixture.

**And the probe hid it, for the same reason.** It split the original text the same wrong way, so it
compared garbage with garbage. After fixing both, the corrected probe finds exactly 34 findings for the 34
CRLF files in the corpus when the old split is put back — the instrument can now see the defect it missed.
This is the third time this exact trap has been found in this codebase (`LineEndings.lineCount` reporting
"1 line(s)" for a four-line CRLF file was the first).

**Swept the rest of the codebase for the same trap.** Of 23 sites splitting on `"\n"`, three were exposed
and are fixed: the SSE stream parser (the specification allows CR, LF *or* CRLF — a CRLF-delimited reply
arrived as one unparsable line, i.e. an empty answer from a working provider), `known_hosts` (a file that
has been through a Windows editor would have made a known host look unknown), and the editor's filter
history. The rest are correct: PAX tar records are newline-terminated by POSIX, and the others handle text
this app itself just wrote.

**Also fixed while here:** `serialized()` joined with `"\n"` regardless, so formatting a CRLF INI rewrote
every line of it — against the editor's own documented promise that "a line operation never changes the
terminator on its own". The document now remembers the terminator it was read with (the dominant one: a
CRLF file with one stray LF is a CRLF file).

## 2026-08-06 (later still) — descript.ion as Total Commander writes it (F-374)

**Two ways this app could corrupt an interchange format, both silent.**

- **UTF-16.** Total Commander writes UTF-16 with a BOM when a comment needs characters the local codepage
  cannot hold. `CommentStore` decoded unconditionally as UTF-8, so such a file read as replacement
  characters — and writing one comment back rewrote the whole file as UTF-8, destroying every comment in
  that directory, including the ones nobody had touched. The encoding is now detected from the BOM and
  the file is written back in the encoding it had.
- **Line breaks.** The original 4DOS format cannot store one; TC asked the 4DOS authors for an extension
  code and got 0xC2, so a multi-line comment is stored as a literal `\n` with the bytes 0x04 0xC2
  appended to the line. This parser knew nothing about it: the marker bytes came back glued to the end of
  the comment text. Now the escape is decoded *only* when the marker is there — without it, `\n` is two
  characters somebody typed, and rewriting a Windows path in a stranger's comment into line breaks would
  be its own kind of vandalism.

**The gate is an independent decoder, not a round trip.** `Tools/check-descript-format.sh` writes one file
per encoding with the real encoder and hands the bytes to **Python's** codecs, which know nothing about
this project — a round trip verified by the code that produced it only proves the code agrees with itself.
Wired into CI, and verified by breaking the encoder on purpose first.

**And the harness lied to me for two runs.** The scenario fixture was generated on the guest through
python → ssh → sh, which ate one escaping layer and wrote a *real* line break where the format wants a
literal backslash-n. The report then blamed the parser, which was correct all along. The fixture is now
144 committed bytes copied with `scp`, and the scenario prints the fixture it read so the next false
accusation is one line away from being disproved. That is the third time quoting through that chain has
produced the wrong bytes here.

## 2026-08-06 (later) — A comment can be found again (F-373)

**Find Files searches a file's comment.** A checkbox on the General tab, and the comment becomes a second
place the search text may be: "the customer's original", "superseded by the 2026 export" — findable again
even though nothing of the sort is inside the file. Matched by the *same* function the content path uses,
so whole word, case and regular expressions mean exactly one thing; a hex query is not applied to a
comment, because "these bytes" is not a question about text somebody typed. `Not containing` inverts the
whole question — a file is listed when the term is in neither its content nor its comment — which is the
case a naive implementation gets backwards.

**I walked straight into a trap the code already documents.** There are three walk paths, and the mmap
fast path is a nonisolated static scan that cannot await a provider. Routing comment searches through it
meant the provider was never asked and the option found *nothing*; the comment above that dispatch
describes the identical mistake being made once before for `searchPluginText`. Comment searches now leave
the fast path — they keep the memory-mapped scan for the content half and lose only the concurrency, and
the option is opt-in.

**And a note is findable too, without new plumbing.** The Notes plugin's content field returned "●" — a
marker, not text — so a note was visible as a dot and searchable by nothing. It now also exposes the
note's text as an ordinary content field, which means the *existing* content-field condition (F-157) can
filter on it and a panel can show it as a column. I had first written a host-side special case that
reached into the plugin's store; that was the wrong shape, and it is gone.

Small correctness detail from the picture: a comment hit showed "L0" in the results list. There is no line
zero, so the line number is now omitted when the match is not in the file's text.

## 2026-08-06 — A note about a file, in one place (F-372)

**Reviewing the notes feature found three of them.** A note about a file could live in a
`descript.ion` (Ctrl+Z, the Comment column, mirrored into the Finder comment), in the Finder comment
itself, or in the Notes plugin (markdown, `●` column, sidebar, overview) — and the three did not know
about each other. Somebody who typed a comment with Ctrl+Z opened the Notes sidebar and saw an empty
field.

**And none of it survived F6.** Nothing in `Sources/PCOperations/` referenced `CommentStore`: renaming
left the comment under the old name, moving left it in the source directory. Silently. In a file manager
whose two most-used keys are Copy and Move.

**Fixed, in this order:**

1. `CommentStore.carry` plus one call site each in the move engine, the copy engine and the panel's own
   two-phase rename — including its undo, because undoing a rename otherwise left the comment on a name
   that no longer existed. Both engines now report *where* an item landed rather than a Bool: a name
   collision may rename the target, and the comment has to go to the name the file actually got.
   Appending is deliberately excluded — a merge keeps the target's own comment, since it is still that
   file. 13 tests through the real engines, reading the real `descript.ion` afterwards.
2. Two callbacks appended to `PcHostServices` (`getFileComment` / `setFileComment`), so the Notes
   sidebar shows and edits the host's comment above the markdown body. One surface, two stores, each
   keeping what it is good at: the short comment travels with the file in a format Total Commander and
   others read, the markdown stays with this app.

**Three things the measuring turned up on the way.**

- **The VM harness shipped an app with no plugins at all.** A Debug build has no `Contents/PlugIns`, so
  every plugin surface in this app was unverified on screen and a scenario touching one would have passed
  by doing nothing. The harness now builds them into the bundle first, the way `make-dmg.sh` does for a
  release — about a minute for all fifteen. `notes-sidebar` is the first scenario that exercises a plugin.
- **There are three copies of every plugin ABI header, and a gate for it already existed.** I wrote a
  second one (`check-abi-headers.py`) before finding `Tools/check-sdk-headers.sh`, which is strictly
  better: it covers all six app-side copies *and* the `PluginSDK` Swift-package copy I had not noticed,
  and it compiles each header standalone. CI failed on exactly the copy my script did not know about. Mine
  is deleted; the lesson is to look for the gate before building one.
- **My own check for the Comment column read the wrong row.** Row 0 of the table is "..", so the cell of
  the previous file was read — a column that was drawing correctly reported an empty cell. And the first
  version of the same check passed while the column was switched *off*, because it read the model instead
  of the rendered cell.

**And two defects that shipping the plugins into the VM exposed immediately.**

- **F3 on a folder crashed the app.** The viewer's folder summary activated a width constraint against the
  scroll view's clip view *before* assigning `documentView`, so the two were in different view
  hierarchies — `NSInvalidArgumentException`, straight down. It stayed hidden because the viewer scenario
  always had a *file* under the cursor; with a plugin adding a drive-bar volume the cursor landed on a
  folder instead. New scenario `viewer-folder`, and the report is the rendered summary — a crash leaves no
  report at all, which is how this announced itself.
- **A collapsed preview panel logged seven Auto Layout conflicts.** A scroll view pinned to both panel
  edges as a *required* rule cannot also give its scroller 17 pt inside a panel that is legitimately 0
  wide. The same pattern CONVENTIONS.md already describes twice for this very view; the three areas added
  later were never given the 999 the earlier ones have. `preview-panel` now opens, closes and reopens, so
  the collapsed state is covered.

The second one also showed that a scenario must *set* state rather than toggle it: `cmd cm_PreviewPanel`
measured an open panel alone and a closed one in the full run, depending on what the previous scenario had
left in `peachcmd.ini`. There is a `previewpanel on|off` verb now, and `--only` takes a comma-separated
list so a sequence can be reproduced without waiting for all 31 scenarios.

Still open from the review, in order: making comments and notes findable (Find Files does not search
them), reading UTF-16 and multi-line `descript.ion` (Total Commander writes both), resilience against a
rename from *outside* the app (a file-ID index), and notes bound to a position in the viewer.

## 2026-08-05 — Folding, and v0.3.0

**Folding (F-371) — DONE.** ⌥⌘ with the arrows: fold the node at the caret, fold the whole top level,
unfold. Hidden through `NSLayoutManagerDelegate.shouldGenerateGlyphs` with `.null` glyphs, so the text
storage is untouched — the document is exactly what will be saved, undo is unaffected, and Find still
finds text inside a fold. The alternatives all change the document (an attachment, a side buffer) or add
a second text system.

Three rules keep it honest, each measured in the VM: the header line stays visible **and is marked**, an
edit drops every fold (a fold is a pair of offsets and inserting text moves them), and a caret that
lands inside a fold opens it. The gutter needed its own fix: with the glyphs hidden, the line numbers of
folded lines were all drawn at the header line's y, so they piled up on one row. It now skips them, and
the jump in the numbering is what shows something is collapsed.

Two defects the measurement found: `Fold Node` on a leaf folded the *grandparent* (I asked for the
parent of the position before the node, which lands a line earlier — it now walks the enclosing path
outwards), and `LineNumberRuler.isHidden` silently overrode `NSView.isHidden`.

**v0.3.0 cut.** `CHANGELOG.md` created — `docs/distribution/release-and-updates.md` had been referring
to a file that did not exist. 51 new UI strings in 19 languages this cycle, the help section for
JSON/YAML/XML in 19 languages, 1809+ tests, 28 VM scenarios at zero conflicts, all eight keyboard gates
and the hotkey audit green.

## 2026-08-04 — JSON, YAML and XML in the editor (F-368 · F-369 · F-370)

**An outline for JSON, YAML and XML (F-368) — DONE.** The symbol sidebar is driven by tree-sitter
tag queries, and for exactly the three formats an administrator edits most it showed *nothing*:
JSON's grammar has `tagsResource: nil` (JSON has no "definitions"), and YAML and XML have no
grammar at all. A 900-line compose file got a blank sidebar, an empty breadcrumb and no way to
jump to a key. `StructureOutline` is a UTF-16 scanner rather than a parser, for two reasons that
both matter: `JSONSerialization` and `XMLDocument` throw positions away, so their output cannot be
jumped to, and a *broken* document still outlines down to the point where it breaks — which is
when a structure view is most useful.

**Structural navigation, selection, paths (F-369) — DONE.** ⌃⌘ plus the arrow keys as a four-way
move (out, in, previous sibling, next sibling), ⌃⌘A to select the enclosing node (pressing it
again grows outwards), ⌃⌘C to copy the caret's position as an expression the format's own tools
take — `.services.web.ports[0]` for jq/yq, `//server[@id='web-1']/port` as an XPath — and ⌃⌘V to
validate with the caret placed **on the problem**. `StructurePath` records path steps in the
parser (`SymbolNode.pathComponent`) instead of recovering them from the sidebar's labels, which
are shortened and decorated for people; keys that are not identifiers are quoted, because
`.content-type` is a subtraction in jq and `."content-type"` is the key.

**Transformations (F-370) — DONE.** Minify (one line), sort keys recursively, escape/unescape as a
JSON string, JSON → YAML. Minifying is a text walk, not a round trip through
`JSONSerialization`: that loses key order and rewrites numbers, so `1.0` becomes `1` and a 20-digit
id becomes `1.23e+19`. Sorting deliberately *does* round-trip, since sorting is a reordering.
There is no YAML → JSON, and that is a decision recorded in the code and in the help: it needs a
YAML parser the system does not have.

**What the measurements found, in order.**

1. **The outline parser spun forever on any file with more than 5000 nodes.** Past the node limit
   `value()` returned nil, the loops above it broke out *without consuming their container*, and
   the array loop then sat on a `}` in element position — a character the scalar skipper refuses to
   move past. On a background thread, silently, in every large JSON file. Found by running the
   validator over this repository's own vendored tree-sitter grammars, not by a test.
2. **The YAML check cried wolf on valid files.** Measured against Ruby's Psych over 400 real YAML
   files: an apostrophe in prose (`the plugin's settings`) taken for a quote, a plain scalar
   continued on a deeper line, a flow sequence wrapped over two lines, `key: &anchor` treated as a
   value, a list item's keys judged misindented, and an escaped `\"` closing a multi-line quoted
   scalar in the middle of a 200-line licence text. All six shapes are now tests. Final state: 400
   files that Psych accepts, **0** flagged.
3. **…and the reverse check, because a validator that finds nothing also has no false alarms.**
   Over 294 deliberately broken files: tabs 95 found where Psych finds 95, indentation 38 of 61,
   duplicate keys 64 (Psych reports none — it accepts duplicates), and **not one** flag that Psych
   considered valid. JSON: 300 files, agreement with Python's `json` module 297/300 — the three
   differences were **trailing commas**, which `JSONSerialization` accepts and Python, Go and jq
   refuse, so that became a check of its own and agreement is now 300/300. XML: 236 mutated files,
   236/236 agreement with `xmllint`.
4. **The caret sat at the end of the document after opening a file** — the breadcrumb described the
   last key in the file while line 1 was on screen. Assigning `textView.string` leaves the
   selection behind the text.
5. **The status line called a `.json` file "JavaScript".**
6. **My own PCFoundation strings would never have been translated.** `Tools/extract-strings.sh`
   reads PCApp's module only, so the validator's messages — written in PCFoundation — would have
   shipped in English in all 18 languages with no gate saying a word. The validator now returns a
   typed `Reason` and `StructureProblemText` in PCApp produces the words, which is what
   CONVENTIONS.md asked for in the first place.

**New gates.** `editor-yaml-outline`, `editor-xml-outline`, `editor-structure` and
`editor-validate` in `Tools/vm/regress.py` (28 scenarios). The structure scenarios fire the real
**menu items** rather than calling the methods, because an item whose target is wrong is disabled
on screen and works perfectly when called directly. `Tools/check-hotkeys.py` grew
`--window-menu`: the editor installs its own menu bar, and its shortcuts — now 32 of them — were
unchecked until this run. Fixtures moved to `Tools/vm/fixtures/` and are copied with `scp`;
generating YAML through python → ssh → sh → printf is what broke two earlier attempts.

40 new UI strings in 19 languages, a new help section in 19 languages, and 1809 tests green.

## 2026-08-04 — Accessibility & keyboard operation (I19 T06) · ZIP64

**Keyboard operation (F-363) — DONE, and it was broken.** `autorecalculatesKeyViewLoop`
is false for every window created in code, i.e. all of them, so AppKit never linked the
controls: **Settings** reached the page list and nothing else (every checkbox, Close —
unreachable, loop not even closed), **Find Files** could be filled in but Start, View,
Close and the results table were unreachable, the editor's filter prompt reached only
Cancel and Run. `KeyboardLoop.install()` sets the flag for every window centrally;
`KeyboardLoop.rebuild(for:)` covers view *swaps*, which AppKit does not notice — a
Settings page, and a panel's view mode, where switching modes left sixteen controls
unreachable. Eight windows are now gates in `Tools/vm/regress.py` (`keys-*`): loop
closed, nothing unreachable, nothing interactive unlabelled. The modal dialog needed a
Timer in the modal run-loop modes, because `runModal` never returns to the script.

**Accessibility labels — DONE.** Missing on: both file lists, the icon grid, the folder
tree and its outline, the editor's text view, the viewer's text and XML tree, the search
results, the search options tab group, the Settings page list, the Favorites list, the
preview-mode switcher, and icon-only button-bar buttons (which have a tooltip and said
nothing). 10 new UI strings in 19 languages.

**Uploading into a network panel (F-367) + upload resume (F-212 complete) — DONE, and the
old behaviour was wrong rather than missing.** F5 from a local panel into an FTP or SFTP panel
handed the *remote* path string to the local copy engine: no code anywhere checked the target
filesystem, so the copy either failed against a path that does not exist locally or wrote to a
same-named local path and reported success. Now `cm_Copy` asks the target panel whether it
needs an upload and routes to `uploadSelection`, which streams each file through the
filesystem's own upload and resumes a shorter remote file (`REST` before `STOR` for FTP,
`seek64` for SFTP). Server-to-server copying is refused with a sentence rather than routed
through a temp file behind the user's back, and folders are reported as not-yet-uploaded
instead of silently skipped. Verified against the guest's own sshd: 40960 bytes whole, then
`resumedAt=15000` with a 25960-byte tail, and `cmp` over ssh confirms the remote file matches;
with the seek removed it reports "differs". Three more scripted-server tests cover the FTP
side, including the 550-for-SIZE case that is an ordinary first upload.

**SFTP downloads stream and resume (F-366) — DONE.** The same defect as the FTP one, one
file over: `localFileIfAvailable` read the whole file into memory and wrote a temp copy that
was then copied to the target. Now `SFTPSession.download` writes chunks straight to the
destination and `libssh2_sftp_seek64` continues a partial one. Verified in the VM against the
guest's own sshd (key auth, no password): 40960 bytes whole, then `resumedAt=10000` with a
30960-byte tail, and `cmp` over ssh confirms the file is byte-identical to the original.
Verified by breaking it too — with the seek removed, `cmp` reports "differs".

**FTP download resume (F-212) — DONE.** `REST` had been in the control connection from
the start and was never called with an offset: the plumbing existed, nothing was connected
to it, so a download that dropped at 99 % began again at zero. Copying from an FTP panel now
streams straight to the destination and continues a partial file — which also removes
`localFileIfAvailable`'s whole-file-in-memory detour for that path (it read the file into
RAM, wrote a temp copy, then copied that to the target). The resume check asks `SIZE`
instead of `stat`, which listed the entire parent directory for one number. A server that
declines `REST` starts the file over rather than failing, and a refused restart no longer
leaks the data channel it had already opened — found because a test script gave the scripted
server one data channel where the fallback needs two. Uploads do not resume yet; the help
claimed both directions did, in 19 languages, and now says what is true.

**Remote attribute changes (F-364) — DONE.** `SFTPFileSystem.setAttributes` was an *empty
function*: the Attributes dialog reported success, the server never heard about it, and the
file was unchanged. FTP swallowed the `SITE CHMOD` reply with `try?`, so a server that does
not support it also looked successful. SFTP now sets permissions and modification time for
real (`libssh2_sftp_stat_ex` with SETSTAT) and refuses owner/group, which the protocol
carries as numbers only and cannot resolve from a name; FTP reports a refused `SITE CHMOD`.
Also guarded: the privileged chmod retry runs `/bin/chmod` on the *host*, and was reachable
for a remote path only because those filesystems used to report success. Verified end to end
against the guest's own sshd — key auth, no password anywhere in the harness — and read back
with `stat` over ssh. That independent witness caught the first attempt using libssh2's STAT
constant (0) instead of SETSTAT (2): the call returned 0, the app said "applied=ok", the mode
was untouched.

**Hotkeys (Tools/check-hotkeys.py) — NEW GATE, 13 findings fixed.** It reads a dump of
the *running* menu bar plus both schemes: ⇧⌘D was on two menu items (Download from URL
and Go ▸ Desktop — one never fired; download moved to ⇧⌘U), ⌘, was on two, and macOS
injects AutoFill/Dictation/Emoji into any menu titled "Edit" on *each* install of the
cached bar — they had piled up to three copies, one of which AppKit gave the bare letter
**E** as a shortcut. Ctrl+F1…F8 is Full Keyboard Access: the macOS scheme now uses
Cmd+1/2/3 and Alt+Cmd+1…4, TC Classic keeps the original row by decision. 14 accepted
exceptions, each with its reason.

## 2026-08-04 — Editor for power users · startup appearance · panels notice outside changes

**Editor, five items (F-355..359) — DONE.** Line numbers in a gutter (`LineNumberRuler`,
NSRulerView so AppKit keeps it in step). **Filter through a shell command** (⇧⌘\):
`TextPipe` runs `zsh -lc` with the selection on stdin, stdout and stderr kept apart —
stdout replaces the text, stderr is reported, so a `jq` error never lands in the file —
off-main with a 20 s deadline, and the edit is dropped if the text moved meanwhile.
Command history in `editor-filters.txt` (0600, one per line: a command contains `=`,
`#`, `;`). **Read-only awareness** (`FileWritability`): the reason is named at *load*
— read-only volume, another owner, permissions, immutable flag, SIP — a lock in the
title, and the administrator prompt is suppressed where it cannot help. **Line endings**
(`LineEndings`): LF/CRLF/CR shown next to the encoding menu, `(mixed)` when both, one
undoable conversion. **Line operations** (`LineOperations`): sort (numeric-aware),
reverse, dedupe, drop blank lines, trim trailing whitespace, keep/remove matching —
in a toolbar pull-down and the menu bar, from one list so tags cannot drift.
Undo now goes through `shouldChangeText` everywhere: assigning `textView.string`
(as `format()` did) **clears the undo stack**.

**Startup shows the configured appearance in the first frame (F-360) — DONE.**
`ConfigStore` is an actor, so every read suspends, and the window's whole appearance
came from ~50 of them *after* `showWindow`: palette, appearance, bar visibility, panel
arrangement, view modes, keymap, saved frame. New `ConfigSnapshot` reads the same files
synchronously (read-only; the actor stays the writer) and
`applyVisualStateBeforeFirstPaint()` applies them before the window is shown.
`Tools/vm/startup.py --expect` records the state at the moment the window appears and
is the gate — verified by disabling the fix, which reports theme=system,
commandLine=true, panelsVertical=true, fontSize=13.

**Panels notice outside changes (F-361) — DONE.** They never did: `FSEventsWatcher`
polled an mtime every 2 s, logged, and had **no callback**, while
`DirectoryModel.startAutoRefresh()` started one per directory load and never stopped
it. Replaced by a real FSEvents `DirectoryWatcher` behind the VFS seam that already
existed (`watch(_:)` — nil for archives, FTP, plugin mounts, so "local only" is free).
Three properties, each measured against a standalone probe rather than assumed:
`realpath` for the watched path (`URL.resolvingSymlinksInPath()` *strips* `/private`
and silently discarded every event); `FileEvents` for per-item paths (without it a file
change in the folder is indistinguishable from one three levels down); leading-edge
throttling (FSEvents' latency is not a rate limit — 200 files still arrived in 15
batches). Cursor and marks survive. Setting: `[Configuration] WatchDirectories`
(default on) + a Display checkbox. The help documented a 2 s polling interval that
never existed; corrected in 19 languages.

**ZIP64 (F-362) — DONE.** The reader took counts, sizes and offsets from the classic
32-bit fields only, and the *silent* half of that was the reason to fix it: an archive
whose members exceed 4 GB parses without complaint and lists every one of them as
4294967295 bytes, while extraction jumps to offset 0xFFFFFFFF. (Only >65535 entries or a
central directory past 4 GB failed outright, falling through to bsdtar by accident.) Now
the ZIP64 EOCD record + locator and the per-entry extra field (0x0001) are parsed, offsets
are 64-bit, and the file is memory-mapped — ZIP64 exists for archives that do not fit in
memory, so `Data(contentsOf:)` would have made the support meaningless. A ZIP64 record
that cannot be read is refused rather than half-trusted. Fixtures are crafted and
**validated by python reading them back**, after three wrong ones: `force_zip64` leaves the
true values in the classic fields (so the test passed with the code disabled), sentinels
without a ZIP64 EOCD are a shape reference implementations reject, and the header's
extra-field length counts the id and size too.

Gates: 1698 unit tests green · 22 `regress.py` scenarios at **0** Auto Layout conflicts
(new: editor-filter, editor-filter-dialog, editor-lines, panel-autorefresh) ·
docs 19 languages, `drifted=0`, `behind=0`. The 46 Shortcuts strings left untranslated
by earlier work are done.

## 2026-07-30 — Localization to 19 languages · documentation system · README · plugin docs
## 2026-08-01 — Colour themes · button bar programs · Finder-style Info panel · Java decompiler

**Colour themes (F-341..343) — DONE.** Selectable palettes with Norton Commander as
the homage and Midnight as a second built-in; the default view is untouched, which was
the constraint. Users write their own as `themes/*.ini` (`Base = dark` plus overrides).
Plugin views follow the palette through the contrib ABI (`PcNotifyThemeChanged`), and
app-owned windows are repainted while AppKit's own panels are left alone. Golden tests
pin every palette's hex values — generated, not remembered, after guessing them twice
and being wrong twice. v0.2.0 was cut from this.

**Button bar (F-067 ext.) — DONE.** External programs, .app bundles and scripts live on
the bar: drop one on free space to add it, drop files on an icon to pass them, or run it
against the current selection. The bar hides via View ▸ Show button bar.

**Side panel Info page (F-344) — DONE.** Reworked along Finder's info sidebar: a
QLPreviewView filling the width, paging through what QuickLook offers, starting at the
top, and the panel's width draggable from its left edge (persisted as
`[Layout] PreviewWidth`).

**Java decompiler plugin (F-345..349) — DONE, ships disabled.** An optional, fully
removable PLX lister that decompiles nothing itself: it drives engines the user installs
(CFR, Vineflower, Procyon, jadx, javap), described as data so a future format is a
descriptor and not a rewrite. Nothing is downloaded or fetched — the app only names the
engines and their licences. Then five power-user steps: syntax highlighting plus Save
As/Open in Editor, .dex through the same machinery, a disk cache with a remembered engine
and `extends` profiles, a compare panel (two engines, or source next to javap bytecode),
and F3 on a whole .jar/.apk/.dex giving a package tree with search across every class.

**Known and unscheduled:** 15 pre-existing Auto Layout conflicts remain in DriveBarView,
PanelTreeView, PanelView and PathBarView (two others were fixed in StatusBarView and
PreviewPanelView). Still open from before: Developer-ID signing/notarization, Sparkle
auto-update, accessibility (I19 T06), and a translation check that compares *content*
rather than topic existence.



**Localization (I19 T05) — DONE for 19 languages.** The UI String Catalog
(`Sources/PCApp/Localizable.xcstrings`, 991 keys) is translated into all 19
languages, and the entire in-app Help Book is authored/translated per language
(`docs/help-<code>/`, 44 topics each). Placeholder-integrity QA clean; catalog
`--validate` passes for every lproj. `check-translations.py` is the CI gate.

**Help (I19 T08) — DONE.** The whole documentation system is live: SSOT Markdown in
`docs/content/` generates the Apple Help Book (`build-helpbook.py --all`, compiled
into `Resources/PeachCommander.help` for all 19 lproj) and the MkDocs website
(`build-site.py`). Shortcut reference + per-plugin pages included.

**README — DONE.** Replaced the obsolete "PLAN not code" stub with a modern project
README (features, screenshots, plugin system, AI-as-plugin, 19 languages, build,
roadmap, 🍑 name story).

**Docs correctness (backlog task) — DONE.** Fixed the stale generated claim
"No AI/ML features exist" (`gen-overviews.py` + `documentation-report.md`); AI is
now correctly documented everywhere as an optional, removable plugin.

**Plugin docs (backlog task) — DONE.** Added code-derived detailed help pages for
**Git · System Monitor · Task Manager · Uninstaller** + a much-expanded plugins
overview (added AI Column), all in 19 languages, each now with a real **English**
screenshot referenced across all 19 languages. The VM harness (`Tools/vm/capture.py`)
was extended to make those shots reachable: it forces the guest **system** locale to
en (`defaults write -g AppleLanguages/AppleLocale` — plugin bundles follow the OS
locale, not the app's `-AppleLanguages`); a new `pfxmount <volume-name>` automation
verb mounts a pfx volume by name like a drive-bar click (Task Manager); and the demo
content grew a real Git repo (Git Status), sample apps in `~/Applications` +
matching `~/Library` leftovers (Uninstaller picker/review window). Help Book + site
rebuilt; `check-docs.py` 0/0, `check-translations.py` 19·44·991·0.

**Also (earlier this window):** viewer/dialog freeze fixed — `MarkColorDialog` /
`InputDialog` now present as window-modal **sheets** over the parent window instead
of app-modal `runModal` (which froze the whole app when a viewer was full-screen on
another Space).

## Localization (2026-07-25) — in progress

Professional i18n for the whole app + plugins. Source language English; German
shipping; architecture scales to Slovak/Russian/… (add a translations file +
knownRegions + a plugin `<lang>.lproj`).

**App (done, committed):** String Catalog `Sources/PCApp/Localizable.xcstrings`
(614 keys, German complete). Pipeline: `Tools/extract-strings.sh` (build →
`.stringsdata` → `xcstringstool sync`), `Tools/translations/de.json` +
`Tools/apply-translations.py` → catalog. project.yml: `developmentLanguage: en`,
`knownRegions: [en, de]`, PCApp `SWIFT_EMIT_LOC_STRINGS: YES`.

**Plugin mechanism (done, committed):** `Plugins/SDK/PluginLoc.swift` (`L()` via
the plugin's own bundle), convention in `Plugins/SDK/LOCALIZATION.md`. Each plugin
ships `Resources/{en,de}.lproj/Localizable.strings` (both required) and its build
script compiles PluginLoc.swift + copies Resources. Verify headlessly via
`Bundle.preferredLocalizations(from:forPreferences:)` (a bare executable ignores
`-AppleLanguages`).

**Plugins (all shipping plugins done + committed, headlessly verified):**
Uninstaller ✅, Git ✅, Treemap/DiskMap ✅, LogViewer ✅, Notes ✅,
SystemMonitor ✅ (mixed DE/EN literals normalized to English source), WebDAV ✅,
iCloud ✅. Archive = no-op (pure C-ABI packer, zero user-facing strings; the
host renders its messages). Sample/demo plugins intentionally not localized
(excluded from shipping). Every shipping build script now compiles
PluginLoc.swift + copies Resources/{en,de}.lproj; build-all-plugins.sh (used by
make-dmg.sh) dispatches to them, so the DMG ships localized plugins.

**Host tasks — DONE (2026-07-25, verified live in German):** both former "needs
monitor" gaps are closed via `PluginTitleLocalizer.localize(title, bundlePath:)`
(Sources/PCApp/PluginTitleLocalizer.swift), which resolves a title through the
contributing plugin's OWN bundle lproj (so future third-party plugins work too):
- Plugin **menu-item / context titles** — ContributionRegistry menuItems()/
  contextItems() localize each title. Verified: "Disk Map: Aktuellen Ordner
  analysieren", "Notiz bearbeiten…", "Systemmonitor…", Git submenu "Git-Status…".
- Plugin **content-column headers** — loadContentFieldPlugins localizes f.title;
  the field id (qid) stays English so saved column sets keep matching.
- Plugin **view / settings-pane titles** — viewItems() returns pluginId; the
  SystemMonitor settings pane now reads "Systemmonitor".
Each plugin's Localizable.strings gained its Info.plist contribution titles.

**Visual verification (monitor on, app run with `-ConfigRoot <iso> -AppleLanguages
'(de)'`) also caught + fixed 5 app-side misses** the String(localized:) sweep had
skipped: function-key bar (F3 Ansehen…F8 Löschen), built-in column headers
(Name/Erw./Größe/Datum), status-bar free space ("Frei:"), window-title free suffix
("… GB frei"), columns-config buttons. Catalog now 623 keys, de 623/623. Menus,
Settings window, status bar, and plugin title-bar chips (Netz/Akku) all confirmed
German. Localization task COMPLETE.

## Feature backlog verification (2026-07-25)

Worked the "needs-monitor" backlog. NOTE: the Mac locked mid-session
(`pmset` "Display is turned off"; login screen), so GUI/pixel verification is
blocked — `caffeinate -u` wakes the display but a locked session shows no app
window. Done what's headless-verifiable; visual pass pending unlock.

- **cm_UnpackFiles** — was a stub; now implemented (MainWindowController.
  showUnpackFiles → ArchiveExtractor, destination prompt defaulting to the other
  panel, reload + report). Real PCCommand id 30103, removed from stub list.
  PCCommandsTests 96/96, PCArchiveTests 42/42 green. Strings localized.
- **Search results match line/preview** — engine already returned
  SearchHit.matchLine/matchPreview; the Find dialog now renders them (two-line
  result rows). Builds clean.
- **Minimap** — code-verified wired in BOTH EditorWindowController and
  ListerWindow (viewer); collapsible toggle. Visual confirm pending.
- **Diff line numbers + overview bar** — code-verified: line-number gutter +
  DiffOverviewBar (colored ticks + viewport, click-to-jump) present/wired.
  Visual confirm pending.
- **Find-dialog filters + template picker — DONE (visually verified in German).**
  The dialog now exposes hex content search, encoding-aware, size min/max, modified
  after/before date pickers, and a saved-template picker (load repopulates controls;
  "Save as Template…" persists to ConfigPaths.searchTemplates via
  SearchTemplateStore). onStart now emits a SearchTemplate (→ template.makeQuery).
  Verified: hex "68 65 6C 6C 6F" → readme.txt "Z1  hello"; template "Hallo-Hex"
  persisted to JSON. de 644/644.

### Visual verification (all confirmed live, app in German)
minimap (editor + viewer), diff (line-number gutter + overview bar with
click-to-jump), cm_UnpackFiles (extracts + localized result dialog), search match
line/preview, and the full expanded Find dialog. Also re-confirmed app + plugin
localization end-to-end (menus, dialogs, status bar, plugin titles/chips).
Feature-verification backlog COMPLETE.

## Autonomous backlog run (2026-07-25) — in progress

Working the remaining parity blocks autonomously (build+test+commit each; inventory
kept in sync). Isolated GUI verification via `-ConfigRoot <iso>`; `caffeinate -u`
keeps the display awake (Mac may lock — a locked session shows no app window).

**Done this run (committed, verified):**
- F-131 Unpack, F-156 search templates, F-159 Spotlight → inventory reconciled done.
- **F-136** password-protected zips (classic ZipCrypto): ZipReader decrypt +
  ArchiveFS password + app secure prompt; 4 tests; verified entering secret.zip.
  (partial — AES/7z/keychain still pending.)
- **F-176** save/load multi-rename presets (RenamePresetStore + window picker);
  verified persisting a preset. (done)
- **F-096** uuencode/xxencode codecs (UUCodec, 4 tests incl. system cross-check)
  + EncodeDecodeEngine.decodeAuto; the app Decode command now auto-detects
  Base64/uu/xx. (partial — uu/xx *encode* UI still pending.)
- **F-235** install plugins from a .zip: PluginManager.installFromZip (unzip →
  locatePluginBundle honoring pluginst.inf → install); Plugins-window Install
  panel accepts .zip. 5 tests incl. zip→install→discover end-to-end. (done)
- **F-273** per-extension viewer/editor associations: FileAssociations (INI,
  human-editable) + F3/F4 hand off to the configured external app. 2 model tests;
  wiring builds. (partial — Options-page GUI editor pending. Live-verified: F4 on .swift opens TextEdit via association.)
- **F-172** content-plugin field values populated for `[=provider.field]` rename
  masks (enrichRenameInputs → ContentFieldRegistry). Engine tested. (done. Live-verified: [=git.branch] → "HEAD" in rename preview.)
- **F-214 SFTP via libssh2 — DONE, verified END-TO-END live.** Integrated the
  Homebrew libssh2 (CSSH2 clang module, links into PCNet/PCApp). SFTPSession
  (blocking libssh2 on a serial queue, async): socket→handshake→known_hosts check
  (MISMATCH aborts, unknown=TOFU)→auth (agent→password→key file→default ~/.ssh)→
  SFTP list/stat/read/write/mkdir/delete/rename. SFTPFileSystem VFS adapter;
  connectToSite(.sftp) mounts it (so the connection manager AND quick-connect
  sftp:// both work — URL parse was already there+tested). SFTPLiveTests passes
  against test.rebex.net.
  **Distribution: DONE.** Tools/bundle-libssh2.sh embeds libssh2 + openssl@3
  into Contents/Frameworks with @rpath install names + ad-hoc re-sign;
  make-dmg.sh calls it. Verified: no /opt/homebrew refs remain and dyld loads
  all three from the app bundle (DYLD_PRINT_LIBRARIES). SFTP now works on
  machines without Homebrew.
- **F-138** background pack/unpack via the queue: new `.custom` OperationKind runs
  an app closure through TransferQueue; cm_PackFiles/cm_UnpackFiles enqueue instead
  of running inline. 2 tests. (done. Live-verified: transfer manager shows the "…zip packen" job → Abgeschlossen.)
- **F-234** PDX ContentSetValue + ContentCompareFiles: ABI (pdx.h) + PDXPlugin
  host wrappers + SampleContentPlugin (writable xattr "Tag" field, compare by
  size). 6 tests. (done — API+host; app consumers under F-094/F-192.)
- **F-214 SFTP F4-Edit-Write-Back — DONE, live-verified.** Editing a file on a
  writable network FS downloaded only a temp copy and saved it locally (never
  reached the server). Now EditorWindowController.onSaved uploads the edited copy
  via fs.openWrite on each save; showEditorForCursor gates it on the .write
  capability (archives are .read-only). Verified live against a rootless sshd:
  temp download (separate path) edited → server file mutated over SFTP.
- **tar/gz native read in ArchiveFS — DONE.** ArchiveFS now sits on a generic
  ArchiveSource backend (ZipReader adapts; new TarReader for tar + tar.gz via
  ZipReader.inflate, sized from the gzip ISIZE trailer). Enter routes tar/gz/tgz.
  63 PCArchive tests (incl. TarReadTests).
- **F-232 PFX host FsFindFirst — hardened, DONE.** ABI was fully wired; the gaps
  were enumeration robustness: list() now cancels between PfxFindNext calls
  (closes the handle early), streams in 128-entry batches, and reads the
  1024-byte name buffer bounds-safe. New SampleFS fixture plugin + 6
  PFXFileSystemTests (incl. mid-stream cancellation). 126 PCPluginHost tests.
- **F-273 Options Edit/View page — DONE, live-verified.** New "Edit/View" page in
  the Options dialog: a grid editor (Extension | viewer app | editor app) over
  associations.ini. FileAssociations gained a testable Row model (rows /
  init(rows:)); AssociationsPageView (add/remove/pick-app/use-built-in) reports
  changes → host writes the INI (re-parsed on use → instant). Window widened to
  680. 10 new localized strings (de 673/673). 4 FileAssociationsTests. Verified
  live: loads from INI, Remove writes it back.

**Externally BLOCKED — need the user (not doable autonomously):**
- F-310 Developer-ID signing/notarization (Apple credentials).
- F-312 Sparkle 2 auto-update (appcast hosting + EdDSA keys + a signed build).
- F-216 FXP (needs two live FTP servers), F-296 AppleScript / F-316 Homebrew (post-1.0).

**Doable-autonomous, still TODO/partial (rough priority order):**
- P1 mostly cleared: F-232 hardened, F-214 write-back, tar/gz read, and the
  Options pages F-273 Edit/View + F-271 Copy/Delete + F-274 Zip/Packer + F-272
  Language + Tabs + FTP + F-254 Keyboard + Misc ALL done (behavior-wired,
  live-verified; Tabs added locked-tab-opens-new-tab, FTP made keepalive
  enforced, Keyboard consolidates scheme-picker + existing remap grid). The
  Options dialog page set is now essentially complete. F-031 configurable Date
  column format also done (Display page field + live preview, both panels update
  live, persisted; PanelDateFormatter + 4 tests). F-002 horizontal panel
  arrangement done too (View → Horizontal Panels; splitView axis flip, persisted,
  live-verified both ways). F-174 edit-names-in-editor done (cm_RenameByEditor:
  export old<TAB>new → built-in editor → rename on save; RenameByEditor planner +
  7 tests; live-verified). F-194 sync presets done (SyncPresetStore +
  save/load/delete in the sync dialog; 4 tests; live-verified). Next: F-157
  plugin content search ops (partial); F-234 PDX (niche/ABI-heavy, low ROI);
  F-136 AES remainder.
- Headless-only (good while the Mac is locked): F-234 host ABI; codec/engine
  work. NOTE most remaining high-value items are GUI-facing (F-273 Options
  editor, F-138 queue, F-002 horizontal panels, F-031 date column) and want the
  Mac unlocked for live verification.
- P2: F-194 sync presets; F-002 horizontal panels;
  F-031 custom date format; F-172 plugin-field rename placeholders; F-157 plugin
  content-field search operators; F-174 rename-via-external-editor.
- P3/polish: many `partial` option-surface items (F-080/084/086 copy/overwrite
  dialogs, F-270-274 Options pages, F-111/112/113 viewer hex/huge/search).

Next: continue down the P1 doable list. See feature-inventory.md for the full grid.

## Search dialog (2026-07-26)

Two Find-dialog improvements (F-150/151/153):
- **Sensible option gating** (FindFilesWindowController.updateOptionAvailability):
  content sub-options (hex/whole-word/encoding) require "Find text"; hex disables
  regex/whole-word/encoding/case (exact bytes); Spotlight disables everything it
  ignores (regex/depth/selection/size/date/archives/content-refinements). Live.
- **Search inside archives** option: engine opens zip-family files (zip/jar/war/
  ear/apk/aar/ipa/jmod/zipx/xpi/crx/epub) via a FileSearchEngine.ArchiveOpener and
  searches contents; hits show "<archive>/<inner>". Off = opaque. 2 engine tests,
  PCVFS 204/204 green. Dialog greying/checkbox GUI check pending (Mac re-locked).

Also this session: AES-ZIP *reading* (F-136 done — WinZipAES, 4 tests).

## Pack extension (2026-07-26)

Packing now supports multiple formats + encryption + splitting (F-132/F-136),
tested + GUI-verified:
- PackEngine (PCArchive) drives 7z/tar/rar: zip, 7z, tar, tar.gz, tar.bz2,
  tar.xz; RAR when the `rar` binary is installed (absent here → clear error).
- AES-256 password (zip/7z/rar; 7z encrypts headers too), multi-volume split
  (-v), compression level.
- PackOptionsDialog (format/password/split) → PackEngine via the transfer queue.
- 6 PackEngine tests (all formats round-trip, AES right/wrong pw, split
  create+recombine, unsupported/missing-tool errors). PCArchive 52/52 green.
- Live: GUI-packed an AES 7z; wrong pw rejected, right pw verifies.
- NOTE: RAR *create* needs the proprietary `rar` binary (extraction stays via
  unar). Encrypted-zip *reading* is still classic ZipCrypto only (AES read = F-136 remainder).

## Parity-audit reconciliation (2026-07-23)

Reconciled `docs/product/feature-inventory.md` with the actual code (67 status
cells corrected). Biggest remaining gaps by area:
- **I15 network:** live SFTP (no libssh2), explicit FTPS/AUTH-TLS in UI, FTP
  connection-manager UI (cm_FtpConnect is a stub), FXP, WebDAV, bandwidth limit.
- **I16 plugins:** PFX (file-system) plugin host (`FsInit`/`FsFindFirst`) unresolved;
  PDX SetValue/CompareFiles + showing plugin columns in the panel; plugin install
  from .zip/pluginst.inf; SDK package.
- **Archives:** only ZIP (no tar/gz/7z/rar/iso); read-only (no add/delete-in-archive),
  no encryption, no nested archives, cm_TestArchive/cm_UnpackFiles are stubs.
- **Search:** no regex/encodings/whole-word/hex content search, no date/attr filters,
  no archive/selected-files scope, no saved templates.
- **I18 macOS:** QLPreviewPanel (spacebar preview), Finder Tags, Share sheet,
  Spotlight metadata, Trash browsing/put-back, ACL/xattr editor, Full-Disk-Access
  onboarding.
- **I20 shipping (groundwork done):** DMG packaging (Tools/make-dmg.sh, verified),
  tag-triggered release CI (.github/workflows/release.yml), hardened-runtime
  entitlements (Resources/PeachCommander.entitlements), RELEASE.md checklist,
  CHANGELOG.md, local crash reporting (CrashReportCollector). Remaining: real
  Developer-ID signing/notarization (needs Apple creds) and Sparkle auto-update
  (needs update-feed hosting + EdDSA keys + a signed app).
- **I20 shipping (original scope):** code signing/entitlements, notarization, DMG,
  Sparkle auto-update (declared but unlinked), crash reporting, release pipeline.
- Many P2/P3 UI polish items are `partial` (see inventory) — foundations exist,
  full option surfaces pending.

## I17 utilities progress (2026-07-23)

## I16 start (2026-07-23)

**I16-T04 (partial):** ImageInfoProvider [PCVFS] reads image dimensions/color/DPI
via ImageIO (tested); Files > Image Info… surfaces it (works on archive entries
via temp extract). Generic content-field interface landed: ContentField/
ContentFieldProvider/ContentFieldRegistry + built-in `fileinfo` provider (tested).
T06 consumers (engine side) done + tested: multi-rename `[=provider.field]` token
(RenameInput.fields) and ContentFieldPredicate + registry.filter (search by field,
e.g. images width>1000). Remaining is UI/native: async custom-column rendering +
field picker in the panel, the search Plugins-tab UI, `builtin` provider wrap,
and the PLX C host (T01). **`builtin` content provider (T04):** name/size/
extension/modified exposed through the same ContentFieldProvider interface (via
URL resource values), so built-in and plugin columns are fully symmetric in the
registry/search/rename — 7 tests incl. a `builtin.size > 1000` registry search.
**Custom-column-set model (T05 data layer):** `ColumnSet`/`ColumnSpec`/
`ColumnAlignment` [PCFoundation] bind columns to qualified content-field ids with
`ColumnSetStore` INI round-trip (`[ColumnSet.<name>]`, stale-key-safe save; 6
tests). Remaining T05 is the editor UI + Show-menu/auto-switch wiring.

**I16-T01 (PLX lister-plugin C host, done + tested):** `plx.h` C ABI (WLX port,
macOS-modernised — opaque `void*` view handles = NSView* on the app side, UTF-8,
PNG-bytes preview) in both Plugins/SDK + Sources/CPLX (drift-checked). CPLX clang
module + project.yml target wired into PCPluginHost. PluginLibrary `PLXSymbols` +
`.plx` openLibrary branch. `PLXLister` adapter [PCPluginHost] — load / loadNext
(viewer cycling) / close / detectString / searchText / sendCommand / print /
previewBitmap — is IO-free (raw-pointer handles, Swift-friendly PLXShowFlags/
PLXSearchOptions/PLXCommand) and does detect-dispatch through the shared F-238
DetectString engine, so the app owns only the NSView bridging. Verified by a real
SampleLister C "text lister" (.txt/.log; ListLoad/LoadNext/Close/SearchText[case
sens+insens]/SendCommand/Print/GetPreviewBitmap→PNG sig), clang-built at test time
— 6 tests incl. balanced load/close lifecycle via a live-view counter. Remaining
(UI): NSView embedding + viewer cycling in Lister/Quick View; a richer .csv
renderer for T02. All three native plugin C hosts (PCX/PDX/PLX) now exist; PFX
stays FS-plugin/network (I15).

**PLX Lister UI embedding (F3, done + visually verified):** ListerWindowController
[PCApp] gained a `.plugin` mode (key `5`); on F3 / Quick View, MainWindowController
`makeListerPlugins()` opens each enabled `.plx` plugin into a `PLXLister`, the
lister asks each `.handles(DetectContext)` (F-238), loads the claiming plugin, and
embeds the returned NSView* over the content area (Ctrl+F search routed into the
plugin; view closed/released on reload/close; dark-mode flag forwarded), falling
back to built-in text/hex/image/web. Demonstrated by **SampleCSVLister** — a
Swift `.plxplugin` (@_cdecl PLX ABI) whose ListLoad returns a real NSTableView-
backed NSView rendering a CSV (Tools/build-sample-csv-lister.sh installs it into
the app plugins dir; it is enabled by default). 3 swiftc-at-test-time tests drive
it through PLXLister; the embedded table was rendered offscreen to confirm it
displays. 881 tests green.

**F3 on a directory → folder statistics (TODOS #1, fixed):** F3 on a folder used
to open the first *file* in the panel (listerContext filters to files). Now
MainWindowController routes a directory cursor to a `.directory` Lister mode
showing a recursive summary (Name / Files / Folders / Size), computed by the new
`DirectoryStatistics` actor [PCVFS] (walks without following symlinks; 4 tests).

**Viewer improvements (TODOS-driven):** CSV plugin auto-detects the delimiter
(, ; tab | :); Ctrl+G goes to a line (text) or byte offset (hex, via
`HexAddress.parse` — 0x/$/h or decimal); `e` cycles the text encoding
(`TextEncodingChoice`: UTF-8/UTF-16/Latin-1/Win-1252/MacRoman/ASCII, status shows
it); the hex view's right-click menu copies the 16-byte row under the pointer as
Text/Hex/C-array/Python-bytes/Base64 or the offset (`ByteFormatter` [PCFoundation],
reusable by the future hex editor). New engines all unit-tested. 900 tests green.

**Binary/hex file compare (TODOS #7):** `BinaryDiff.compare` [PCVFS] streams two
`ByteSource`s in chunks (multi-GB safe), reporting sizes, first difference,
differing-byte count, and coalesced differing ranges (bounded, with a truncation
flag); 7 tests over in-memory sources. `BinaryCompareWindowController` [PCApp]
shows a synchronized side-by-side hex dump in one virtual NSTableView (one row per
16-byte offset), tinting differing rows, with a summary line and Prev/Next-diff
navigation; wired as `cm_CompareFilesBinary` (File ▸ "Compare by Content (Hex)…").
907 tests green.

**Viewer JSON/XML formatting (TODOS #20/#21):** `StructuredTextFormatter`
[PCFoundation] pretty-prints JSON (sorted keys, via JSONSerialization) and XML
(XMLDocument), with an `autoFormat(preferXML:)` that picks by extension hint;
invalid input returns nil. 6 tests. In the Lister, `f` in text mode formats the
file as JSON/XML into a string-backed TextListerView (status shows "formatted"),
beeping when it parses as neither. 913 tests green.

**Viewer syntax highlighting (TODOS #19):** `SyntaxHighlighter` [PCFoundation] is
a single-pass, language-parameterised lexer emitting comment/string/number/keyword
spans (Swift/C/JS/Python/Shell by extension); pure over a Character array, 8 tests.
`CodeListerView` [PCApp] colours source per token (keyword=purple, string=red,
number=blue, comment=green) using binary-searched token spans per visible line;
the Lister auto-selects `.code` for known-language files (key `6` forces it, `1`
returns to plain text), and `e`/`f`/Ctrl+G work there too. Rendering verified
visually (offscreen render of a Swift sample). 921 tests green.

**Navigation (TODOS #13/#14):** `cm_GotoPath` (File ▸ "Go to Folder…", Cmd+Shift+G)
prompts for a path and navigates the active panel; `PathResolver` [PCFoundation,
6 tests] expands ~, resolves relatives against the current dir, and standardises
`.`/`..` lexically (existence checked by the caller). `cm_OpenTerminal` (File ▸
"Open Terminal Here", Cmd+Opt+T) launches Terminal.app at the current directory
(stub removed). 927 tests green.

**Viewer XPath (TODOS #21):** `XPathQuery.evaluate(xml:query:)` [PCFoundation]
wraps XMLDocument.nodes(forXPath:), returning matched nodes as text (element
markup, or string value for text/attribute nodes) and throwing invalidXML /
invalidQuery; 7 tests. In the Lister, `x` (text/code mode) prompts for an XPath
and shows the matches (status reports the count). 934 tests green.

**Drive/volume buttons (TODOS #9):** `DriveBarModel` [PCVFS, 4 tests] decides which
volumes show (hidden dropped, root first then by name) and which owns a path
(longest mount prefix). `DriveBarView` [PCApp] is a per-panel strip of toggle
buttons above the path bar; clicking navigates the panel to that volume's root and
the current volume shows pressed. Populated once from VolumeManager and re-highlighted
on each navigation (in refreshStatusBar). Bar look verified by an offscreen render;
the panel-layout integration (a new row between tab bar and path bar) is a visual
change worth a glance. 938 tests green.

**Compare polish (TODOS #41/#42):** `BinaryHeuristic.isProbablyBinary` [PCVFS, 5
tests, also now backing ListerWindow.autoMode] lets "Compare by Content…" auto-pick
text vs hex; the two compare items sit together in the File menu. The hex compare
now highlights only the differing bytes (hex pair + ASCII) instead of tinting whole
rows — the engine was already byte-for-byte (proven by a real-FileSlice regression
test), so this fixes the "looks completely different" perception. Byte-precise
render verified offscreen. 944 tests green.

**Roadmap decisions (user, 2026-07-23):** big chunks ordered — (1) Log-Viewer next,
(2) Text/Code-Editor **NSTextView-based** (gives real selection/undo/find, also
resolves viewer #44), (3) rest. Log-Viewer v1 scope = all four: level/timestamp
detect+colour, filter (level + text/regex), live-update + auto-scroll, column sort.
Panel view modes to build = all four: detail list (current), short/multi-column,
icons/thumbnails, gallery.

**Viewer function menu + copy (TODOS #43/#44):** ListerWindowController's content
container now carries a right-click menu listing every viewer function with its
shortcut (mode switches, encoding, format, XPath, find/goto, next/prev file) — the
otherwise keyboard-only features are now discoverable — plus "Copy All Text"
(Cmd+C) backed by a `ViewerTextProviding` conformance on TextListerView/
CodeListerView. Real mouse text-selection is still pending. 944 tests green.

**Log viewer (roadmap #1, done):** `LogViewerWindowController` [PCApp] shows a log
in a Time/Level/Message table coloured per level, with level checkboxes + text/regex
filter (`LogFilter`), click-to-sort by Time/Level, and live-tail via a 0.5s FileHandle
poll (grows past the initial mmap limitation) with optional auto-scroll. Backed by the
tested `LogLineParser`/`LogFilter` engine. Command `cm_ViewAsLog` (File ▸ "View as
Log…"). Rendering verified offscreen (ISO + syslog timestamps, level colours). 955
tests green.

**Text/code editor (roadmap #2, done):** `EditorWindowController` [PCApp] — NSTextView
(selection/undo/copy + system find/replace bar for free), syntax highlighting applied
to the text storage via `SyntaxHighlighter` (debounced re-highlight on edit, capped at
2 M chars; char→UTF-16 prefix-sum map for O(1) range mapping), JSON/XML formatting via
`StructuredTextFormatter`, an encoding picker (`TextEncodingChoice`), and Save with a
an optional one-time `.bak` backup (`Editor.CreateBackups`, off by default — F-387) + dirty
tracking + save-on-close prompt. F4 (`cm_Edit`) and
Shift+F4 (`cm_EditNewFile`) now open this editor instead of the external app. Highlight
verified offscreen. 955 tests green.

**More TODO items:** sort-arrow position fixed via headerRect (#34); Shift+F6 rename
with old name preselected + `RenameValidator` (#40); POSIX-permission checkbox dialog
`AttributesDialog` (#39); panel type-ahead cursor navigation `TypeAheadSearch` (#64);
panel-header "★" Go button → `SpecialDirectories` + hotlist manager (#65); **hex editor**
`HexEditorWindowController` over a tested `HexDocument` (overwrite/insert/delete, undo/redo,
save (through `DocumentFile`, so the `.bak` setting covers it too); File ▸ "Edit as Hex…", #26). All engines unit-tested; UIs verified offscreen.
976 tests green.

**Finder context menu (#11), Shift/Cmd multi-select (#28), SMB/AFP mount (#36,
`NetworkShare`), hex find/replace (`ByteSearch`), XML highlighting + collapsible
XML tree (`XMLTreeParser`, NSOutlineView), inline hotlist favorites in the Go
menu** — all landed; engines unit-tested, UIs verified offscreen. 993 tests green.
Remaining big items (need interactive verification / product input): per-panel
view modes (icons/gallery), the settings dialog (#30); plus optional hex-*viewer*
drag byte-selection (#5, the editor already has caret+find).

**I16-T03 (PDX content-plugin C host, done + tested):** `pdx.h` C ABI mirroring
TC's WDX (ContentGetSupportedField/ContentGetValue, PC_FT_* field+status types on
pc_common.h) in both `Plugins/SDK/` and `Sources/CPDX/` (byte-identical, drift-
checked by check-sdk-headers.sh). CPDX clang module + `project.yml` target wired
into PCPluginHost (SWIFT_INCLUDE_PATHS + dep). PluginLibrary gains `PDXSymbols` and
a `.pdx` `openLibrary` branch. `PDXPlugin` [PCPluginHost] drives the C ABI —
enumerate fields, `PDXFieldKind`-typed decode of values via loadUnaligned /
withMemoryRebound (int32/int64/string) — and `PDXContentProvider: ContentFieldProvider`
bridges plugin fields into the PCVFS registry so they work as columns/search/multi-
rename exactly like the built-in `fileinfo`. Verified end-to-end by a real
SampleContentPlugin C plugin (Size/Name Length/Extension from path+stat), compiled
with clang at test time and loaded via PluginLibrary: enumerate, typed values,
missing-file→.none, and a registry+search bridge (`sample.size > 100`). 859 tests
green (PCPerfTests still need `Tools/make-fixtures.sh`). Remaining for T03: async
value cache + ft_delayed/stop-value on background workers; ContentSetValue/EditValue.

## I17 utilities

Ten I17 utility features landed, engine-tested + wired into the menus:
- **T12 Create links**: LinkMaker (symbolic/hard/alias) [PCVFS] + Files > Create
  Symbolic Link / Hard Link / Alias… (name prompt, target = cursor). Tested.
- **T06 Branch view**: VFSTreeWalker (shared recursive collector) + Commands >
  Branch View (Ctrl+B) / Branch View (Selected) (Ctrl+Shift+B) → flat ResultsFS
  listing. Full-path column set still open.
- **T10 Print/export lists (partial)**: FileListFormatter (TSV/CSV/plain)
  [PCFoundation] shared by Copy Details + Files > Export File List… (filelist.txt)
  + Print File List… (NSPrintOperation). Lister print / format chooser open.
- **T09 Comments (partial)**: DescriptionFile [PCFoundation] + CommentStore
  (descript.ion read/set via VFS) [PCOperations] + Files > Edit Comment… (Ctrl+Z).
  Comment column + Finder-comment backend still open.
- **T01 Change attributes (partial)**: PosixPermissions [PCFoundation] +
  AttributeEngine (chmod/set-date, recursive) [PCOperations] + Files > Change
  Attributes… (octal prompt). Full rwx-matrix/date dialog + subdir toggle open.
- **T11 Occupied space (partial)**: OccupiedSpaceCalculator [PCVFS] + Files >
  Calculate Occupied Space… (total bytes + file/folder counts, local-only).
  Volume-label / system-info dialogs still open.
- **T02 Split/Combine**: SplitInfo (.crc sidecar) [PCFoundation] + SplitCombineEngine
  (streamed .001 parts + CRC-32 verify over VFS) [PCOperations] + Files >
  Split/Combine (ByteSize.parse for part size). Round-trip + corrupt-part tested.
- **T04 Checksums**: ChecksumAlgorithm/Hasher (CRC32 + CryptoKit MD5/SHA-1/256/512)
  + ChecksumFile (.sfv/coreutils) [PCFoundation]; ChecksumEngine (VFS
  compute/create/verify) [PCOperations]; Files > Create/Verify Checksum(s)…
  (SHA-256). Tested vs published vectors + independent shasum. BLAKE3 dropped.
- **T05 Duplicate finder**: DuplicateFinder (size-tier → content-hash) [PCOperations]
  + Files > Find Duplicate Files… (results shown via ResultsFS). Fixture-tested.
- **T03 Encode/Decode**: Base64Codec [PCFoundation] + EncodeDecodeEngine (VFS)
  [PCOperations]; Files > Encode/Decode File (Base64). Tested vs RFC 4648.

Remaining I17 polish: T04 algorithm chooser + verify-after-copy (F-090); T05
Find-Files dialog integration + name/size-only options; T03 uuencode/xxencode.
Other I17 tasks (attrs, split/combine, tree/branch/thumbnails, comments, print,
occupied space, links) still open.

## I15 progress (2026-07-23)

New `PCNet` framework + `SecretStore` (PCFoundation). **A working, tested built-in
FTP client is done end-to-end at the data layer:** LIST parsers (MLSD/UNIX/DOS),
control-reply + PASV/EPSV parsing, full command choreography (`FTPControlConnection`),
a live Network.framework transport (verified over an in-process loopback server,
opt-in `TEST_RUNNER_PC_FTP_LOOPBACK=1`), and a `FTPFileSystem: VirtualFileSystem`
adapter (list/read/write/mkdir/delete/rename, FTP→VFSError mapping). Plus the site
model (ftp-sites.ini)/URL parser and Keychain-only credential store. All covered by
PCNetTests (scripted canned-dialog transport) + SecretStoreTests. See
`docs/iterations/I15.md` "Progress".

**Now reachable from the app:** Net > FTP New Connection… / Ctrl+N (cm_FtpNew,
cm_NetConnect) → URL + secure password prompt → connect → mount FTPFileSystem in
the active panel (`PanelController.enterNetwork`). **Implicit FTPS (`ftpsi://`,
TLS + PBSZ/PROT)** supported.

**Pending (best with a real/dockerized server, or a larger effort):** explicit
FTPS (AUTH TLS — NWConnection lacks STARTTLS upgrade; needs a BSD-socket/NIO
transport); proxies/keep-alive/reconnect (T03 polish); full connection-manager UI
with saved sites + Ctrl+F (T05 UI); SFTP/libssh2 (T04, vendoring ADR needed);
generic `pfx.h` PFX plugin host (T01); transfer integration (T06). Live FTP(S)
best verified against a real server.

## Next action

**I14 is substantially complete** — PCX plugins load, browse, extract, pack, and
delete end-to-end (proven with the SamplePacker), `.pak` archives open in panels,
and the Plugins manager UI installs/enables/removes. Remaining I14 polish (optional):
progress/changevol/crypt callbacks, per-plugin serialized executor + quarantine
check, install-from-.zip + associations-editor UI + Configure button, CI build of
the sample, and the other plugin types (pfx/plx/pdx headers + PCPluginKit Swift
overlay + their hosts) — most belong to I15/I16.

**Next big iteration: I15 — FTP / network (SPEC-011)** or **I16 — content plugins &
custom columns**. Also open: I14 callbacks/executor polish; earlier deferred items
(I12 diff edit-mode/hex, sync presets; I11 presets; I07 media; I05 brief view; I04
drag-drop/Transfer Manager; duplicate finder).

---

**I13 is essentially complete** (T01–T06 all delivered; T06 fully done incl. runtime
routing + Keys editor). Remaining I13 polish (all optional): full TC menu order/
completeness + F-key relabel (F-004/F-251), button-bar Customize dialog + drag/
subbars (F-253), rich Start-menu editor dialog (F-252), wiring the command browser
as the picker inside editors (F-255), TC numeric-id alignment, cmdline aliases (F-256).

**Next big iteration: I14 — Plugin Host & Packer Plugins (PCX)** — C SDK headers +
PCPluginHost (dlopen/dlsym, lifecycle) + PCX→ArchiveFormatProvider adapter + a C
SamplePacker + plugin-manager UI. Heavy native/C-interop iteration; scope carefully.
Other candidates: libarchive (I09-T01);
finish I08 operations/Lister VFS migration + purity gate (T04-T06). Deferred
polish: I12 diff edit-mode + hex/binary (T03), sync filter/context/progress/
presets (F-194), queue-backed sync + zip/FTP (F-193→I15); I11 token buttons +
presets (F-176) + editor round-trip (F-174); I07 media/assoc; I05 brief view;
I04 drag-drop/Transfer Manager; search templates (I10-T06); archive search;
duplicate finder.

## Blockers / escalations

_(none)_

## Audit 2026-07-21 — I03 reality check

Prior sessions marked I03-T01..T06 "COMPLETE" but an audit found they were mostly
non-functional. Corrected scope of remaining work:
- **T01** SelectionState: `invertSelection()` only cleared (not a real invert);
  `selectAll()` used fake `entry_i` paths; no unmark-on-completion hook;
  `getSelectedSize()`/`getCursorPath()` were no-ops. → real logic + honest tests.
- **T02** Key handling: wrong numpad keycodes (81/82/83/84), dead duplicate switch
  cases (Ctrl+Num+ never fired), Escape wrongly toggled mark, **marked rows never
  rendered red** (isHighlight hardcoded false), no Shift+range, no Mark menu / no
  menu bar, command registry not wired to UI. → real wiring + red marking + menu.
- **T03** Select/Unselect dialogs: built but never invoked; delegate only logged,
  never applied masks; no SelectDirs option; no mask history. → wire to Num+/Num-.
- **T04** Status bar: no sizes at all, no TC formatting; never updated on
  selection/cursor change (callbacks unwired). → sizes + TC format + coalesced updates.
- **T05** Icons: fully synchronous, no cache/placeholder/cancel/modes; path bug
  (used bare filename). → async IconLoader with cache, placeholder, modes.
- **T06** Hidden toggle works but wrong keybinding (Cmd+. vs Ctrl+H);
  dir-size-on-Space and Alt+Shift+Enter missing. → async dir sizes + Ctrl+H.
- **T07** Properties dialog (Alt+Enter): entirely missing; no symlink target/arrow.
  → dialog + view model + symlink display.

## Open decisions for the user (non-blocking)

- App display name: plan uses **"PeachCommander"**, bundle id `com.peachcommander.app`.
  Change in `project.yml` + DECISIONS.md ADR-010 if desired.
- Update feed hosting (Sparkle appcast): plan assumes GitHub Releases + GitHub Pages
  (see `docs/distribution/release-and-updates.md`). Needs a repo URL eventually.
- Apple Developer ID account required from iteration I20 (signing/notarization).
  Until then unsigned local builds are fine.

## Deviations from plan

- 2026-07-22 (I09): Implemented archive support with a **dependency-free pure-Swift
  `ZipReader`** (Compression-framework DEFLATE) instead of the libarchive bridge
  (I09-T01) first. Reason: no system-library module-map/linking setup needed;
  fully unit-testable; unlocks the signature "enter a zip" feature immediately.
  libarchive (for tar/gz/bz2/xz/7z/rar-read) remains a later addition; zip64,
  pack/write, passwords, nested archives are still TODO.

## History log (newest first)

- 2026-07-23: Cross-cutting parity sprint (autonomous). I18: Spotlight metadata in
  Get Info (F-294), Finder tag color column + tag: filter (F-291), Services menu
  integration (F-293), Full Disk Access onboarding (F-299), Go▸Trash (F-297),
  xattr inspector/remove in Change Attributes (F-298), privileged "retry as
  administrator" for chmod+delete (F-099). I06: Ctrl+Left/Right open cursor folder
  in other panel (F-063). I10: regex search names+content (F-154). I09: delete &
  rename inside zip via rewrite — new `ArchiveEditor` (F-133 partial; F5 add still
  pending). I20 groundwork: DMG script, release CI, entitlements, RELEASE.md,
  CHANGELOG, crash reporting. Continued 2026-07-24: archive integrity test (F-135),
  verify-after-copy option (F-090), window title shows path + free space (F-012),
  nested archive browsing (F-134, browse-only). Inventory 77 done / 69 partial / 26 todo.

- 2026-07-22: I14 part 2g — Plugins manager UI (T05). `PluginsWindowController`
  (Configuration ▸ Plugins…, cm_ConfigPlugins) lists installed plugins (enabled
  checkbox / name / type / API version / path) with Install from Folder…
  (NSOpenPanel → PluginManager.install, validated with rollback on failure) and
  Remove (PluginManager.remove); the enabled checkbox persists to plugins.ini and
  re-scans. Smoke-verified with a SamplePacker installed. Deferred: install-from-.zip
  (pluginst.inf), associations-editor UI, per-plugin Configure button, and (later
  polish) callbacks/serialized-executor/quarantine + pfx/plx/pdx headers + PCPluginKit.
- 2026-07-22: I14 part 2f — plugin archives browsable in panels. PCApp now depends
  on PCPluginHost; `MainWindowController` owns a `PluginManager` (configPaths
  pluginsDirectory + plugins.ini), discovers plugins at startup, teaches panels the
  enabled packer extensions via `PanelListView.addArchiveExtensions`, and sets
  `PanelController.resolvePluginArchive` so `enterArchive` mounts a `PCXArchiveFS`
  for an associated file (falling back to the built-in zip reader). ConfigPaths
  gains pluginsDirectory + pluginsConfig. Smoke-verified: app launches with a
  SamplePacker.pcxplugin installed + pak→SamplePacker associated. So a `.pak`
  opens in the panel like a zip. Deferred: progress/changevol/crypt callbacks,
  serialized executor + quarantine, Plugins manager UI (T05).
- 2026-07-22: I14 part 2e — plugin-backed VFS. `PCXArchiveFS` (read-only
  VirtualFileSystem, scheme "pcx"): builds an in-memory tree from the plugin's flat
  entry list (synthesizing intermediate dirs) and serves list/stat/openRead/
  localFileIfAvailable by extracting entries through the plugin's ProcessFile.
  Full VFS battery tested against the SamplePacker (root+nested listing, dir
  synthesis, stat, localFileIfAvailable, chunked openRead; non-archive init fails).
  Next: consult PluginManager from PanelController.enterArchive so a .pak opens in
  the panel (needs PCApp→PCPluginHost dependency + dynamic archive-extension set).
- 2026-07-22: I14 part 2d — pack/delete + SamplePacker plugin. `PCXArchive.pack`
  (PackFiles: NUL/double-NUL addList, subPath prefix, move flag) + `delete`
  (DeleteFiles), with `canPack`/`canDelete` from symbol presence. Shipped a real C
  packer `Plugins/SamplePacker/sample_packer.c` (uncompressed `.pak`: all required
  exports + PackFiles/DeleteFiles/GetPackerCaps(NEW|MODIFY|MULTIPLE|DELETE)) and
  `Tools/build-sample-packer.sh` assembling a universal `.pcxplugin` bundle.
  Full round trip verified through the adapter (pack→list→extract+verify→delete→
  list→extract; + subPath). Deferred: progress/changevol/crypt callbacks +
  ArchiveFormatProvider/panel wiring (rest of T03), CI build, serialized executor +
  quarantine (rest of T02), Plugins UI (T05).
- 2026-07-22: I14 part 2c — PCX adapter + C interop. New `CPCX` static-library
  module (module.modulemap exposing pc_common.h/pcx.h to Swift; build copies of the
  headers drift-checked against Plugins/SDK by check-sdk-headers.sh). `PCXArchive`
  drives the PCX C ABI end to end for list + extract (OpenArchive → ReadHeaderEx
  loop → ProcessFile SKIP/EXTRACT → CloseArchive) using @convention(c) casts of the
  dlsym'd symbols, reading the fixed char[1024] header field and mapping attrs/time.
  Verified with a clang-built C fake plugin at runtime (list/extract/missing-entry).
  Deferred: pack/delete, progress/changevol/crypt callbacks, ArchiveFormatProvider
  wiring (rest of T03), C SamplePacker bundle (T04), serialized executor/quarantine,
  Plugins UI (T05).
- 2026-07-22: I14 part 2b — plugin lifecycle + associations. `PluginConfig` (pure
  plugins.ini model: Disabled list + `[PackerAssoc]` ext→plugin, enable/disable,
  dot/case-insensitive lookup, serialize round-trip) + `PluginManager` actor
  (discover + config; `enabledPlugins()`, `packerPlugin(forExtension:)` consulting
  the explicit association first then plugin-declared extensions, persisting
  enable/assoc edits to plugins.ini). Tests: PluginConfig round-trip/enable/assoc +
  a PluginManager temp-dir integration test. Deferred: per-plugin serialized
  executor + quarantine (rest of T02), PCX struct-ABI adapter (T03), SamplePacker
  (T04), Plugins UI (T05).
- 2026-07-22: I14 part 2a — dlopen/dlsym host. `PluginLibrary.open`
  (RTLD_NOW|RTLD_LOCAL) resolves required+optional symbol tables, runs the
  `PcGetApiVersion` handshake (rejecting version mismatches), and dlclose()s on
  deinit only when `PcSafeToUnload` is exported; `PCXSymbols` lists the PCX
  exports; `PluginHost.openLibrary(_:)` opens a DiscoveredPlugin's binary by type.
  Tested headlessly by compiling C fixture dylibs with clang at runtime (7 tests:
  all-resolved, missing-required→error list, version-mismatch, no-handshake-ok,
  unload policy, dlopen-failure). Deferred: enable/disable lifecycle + serialized
  executor + quarantine (rest of T02), PCX adapter (T03), C SamplePacker (T04),
  Plugins UI (T05).
- 2026-07-22: I14 part 1 — Plugin SDK/host foundation. New `PCPluginHost` framework
  module + test target. Pure engines (2 via subagents): `DetectString` parser/
  evaluator (SPEC-012 §6, F-238 done — EXT/SIZE/FORCE/MULTIMEDIA/`[N]` probes,
  `= != < > <= >=`, `& | !`, parens; 35 tests); `PluginManifest`/`PluginType`/
  `PluginManifestParser` (Info.plist validation) + `PluginInstallInfoParser`
  (pluginst.inf) — 21 tests; `PluginHost.discover/load` bundle scan + validation +
  structured `PluginLoadError` (9 fixture tests). C SDK headers `Plugins/SDK/
  pc_common.h`+`pcx.h` (compile-checked by `Tools/check-sdk-headers.sh`) and
  `Plugins/SDK/PORTING.md` (WCX→PCX port guide). Deferred to I14 part 2: dlopen/
  dlsym host + lifecycle + serialized executor, PCX adapter, C SamplePacker + CI,
  Plugins manager UI, pfx/plx/pdx headers + PCPluginKit overlay.
- 2026-07-22: I13 part 3e — Keymap runtime routing + Keys editor (T06 complete,
  F-254 done). `PanelListView.performKeyEquivalent` → `MainWindowController.routeKeymap`
  routes modified chords (Ctrl/Alt/Cmd) that map to an implemented command
  (`KeymapMenu.chord(from: NSEvent)`); bare keys/F-keys stay with the menu + keyDown
  and text fields are skipped, so existing input is unaffected while non-menu
  rebinds now fire. `KeysWindowController` (Configuration ▸ Keyboard Shortcuts…):
  searchable command grid, Record… via a chord-capture sheet (with a displacement
  notice when a chord is reassigned), Clear (suppress), Restore Defaults; edits
  persist to keymap-user.ini (`keymap.userScheme.serialized()`) and re-sync the menu
  immediately.
- 2026-07-22: I13 part 3d — Command browser + cm_/em_ from command line. Typing a
  bare cm_Name/em_Name in the command line now executes it (regex-gated before the
  shell path). `CommandBrowserWindowController` (F-255): searchable list of all
  registered commands (name/category/description filter, greyed placeholders,
  double-click/Run to execute) via Configuration ▸ Command Browser… (cm_CommandBrowser).
  Deferred: wiring the browser as the picker inside toolbar/keymap/Start editors.
- 2026-07-22: I13 part 3c — Command registry completion (T01, F-250). Every cm_
  referenced by a menu item or shipped keyboard scheme is now registered: 3 real
  aliases (cm_SelectAll→markAll, cm_RereadSource→reload, cm_SwitchToTargetPanel→
  toggleActivePanel) and 56 `implemented:false` placeholders in CommandStubs.swift
  (ids 50000+) that show a "not yet implemented" notice on direct invocation and
  are auto-disabled in menus. Added `PCCommand.implemented` flag; menu enablement
  now keys off registered-AND-implemented; `showNotImplemented` on the window
  controller; PCCommandsTests gains registry-uniqueness + implemented-flag tests;
  check-keymap.sh recognises stubs (0 pending). Deferred: full TC numeric-id
  alignment (TOTALCMD.INC) and the searchable command browser dialog (F-255).
- 2026-07-22: I13 part 3b — Menu tree build-out (T05). Expanded AppMenu to the TC
  structure: File (Change Attributes/Unpack/Test Archive/Calc Space/Edit Comment/
  Split/Combine/Checksums), Commands (CD Tree/Branch View/Open Terminal/Volume
  Label/System Info/Run Command Line), new Net menu (FTP Connect/New/Disconnect/
  Hidden, Mount Share), View (Brief/Full/Tree/Thumbnails + Sort By submenu +
  Refresh). Not-yet-implemented items carry their cm_ name and are auto-disabled
  at startup by KeymapMenu.apply (and still show the active scheme's accelerator).
  Deferred: exact TC item order/completeness (Comments/Print/Encode-Decode/
  Associate), F-key bar relabel (F-004), menu snapshot test.
- 2026-07-22: I13 part 3a — Keymap-driven menus + scheme switcher. `KeymapMenu.apply`
  converts KeyChord→NSMenuItem accelerators and syncs every menu item's shortcut
  from the active scheme (numpad chords left as-is), disabling items whose command
  isn't registered (menu.autoenablesItems off). New Configuration menu (Options /
  Customize Toolbar… / Keyboard Scheme ▸ TC Classic·macOS Native) with live scheme
  switching (cm_ConfigKeyClassic/cm_ConfigKeyMacOS persist Configuration/KeyScheme,
  reload the keymap, reapply + checkmark) and cm_ConfigButtonBar. Applied once at
  startup after registration+keymap load, so remapping is effective for all
  menu-backed commands. Deferred: runtime performKeyEquivalent for non-menu chords,
  interactive Keys options page, full TC menu tree build-out.
- 2026-07-22: I13 part 2 — Button-bar strip + Keymap engine. `ButtonBarView`
  renders a TC .bar as a horizontal icon/text strip at the top of the window
  (SF Symbol/file-app icons, text fallback, tooltips, click→cm_/em_/program/dir,
  right-click→Edit Button Bar); a starter `default.bar` is written on first run.
  Keymap (subagent): `Keymap`/`KeymapScheme`/`KeyChord` engine (PCFoundation, 32
  tests, layered user>scheme>builtin precedence + suppression + display lookup) and
  two bundled scheme files `keymap-tc-classic.ini` (80) / `keymap-macos.ini` (81),
  loaded at startup (Configuration/KeyScheme) with `keymap-user.ini` overrides;
  `Tools/check-keymap.sh` lints scheme names vs the registry. ConfigPaths gains
  buttonBar/userKeymap (userCommands added in part 1). Deferred to I13 part 3:
  keymap runtime performKeyEquivalent routing + Keys options page, full menu
  build-out (T05), registry id alignment + command browser (T01), button-bar
  Customize/drag/subbars, Start-menu editor dialog.
- 2026-07-22: I13 part 1 — Commands, User Menu, Copy-Names. Three pure engines
  (PCFoundation, parallel subagents): `ParamExpander` (TC %-parameter expansion
  %P/%N/%T/%M/%S/%L/%F/%D/%W/%%, quoting, cached list-file callback; 20 tests);
  `UserCommands` (usercmd.ini em_ model, ordered round-trip; 14 tests);
  `ButtonBar`/`BarButton` (TC .bar parser+writer round-trip; 18 tests). Config:
  `ConfigPaths.userCommands` (usercmd.ini) + `.buttonBar` (default.bar). Start
  menu (AppMenu) populated from usercmd.ini and reloaded on app reactivation;
  user-command runner builds a ParamContext from the panels, expands params, and
  runs cm_/em_/programs (.app via `open -a`) through ShellExecutor; "Change Start
  Menu…" (cm_ChangeStartMenu) opens usercmd.ini in the default editor. Copy-names
  command set (F-092): cm_CopyNamesToClip / cm_CopyFullNamesToClip /
  cm_CopyNetNamesToClip / cm_CopySrcPathToClip / cm_CopyFileDetailsToClip (TSV),
  wired into the Mark menu (⌘⌃C, ⌘⌃⇧C). Deferred to I13 part 2: registry id
  alignment + command browser (T01), full menu build-out + F-key relabel (T05),
  keymap engine + Keys page + scheme files (T06), button-bar strip UI + Customize
  + drag/subbars, Start-menu editor dialog, em_ from command line.
- 2026-07-22: I12 Compare by Content & Synchronize Dirs. Three pure engines
  (PCFoundation, delivered by parallel subagents): `LineDiff` (Myers O(ND) line
  diff, delete+insert→change coalescing, grapheme intra-line ranges, ignore
  case/whitespace/line-ends; 26 tests); `DirCompareMarker` (files-only
  newer/only-here panel marking with tolerance + case-insensitive; 16 tests);
  `SyncModel.classify` (→/←/=/≠/delete state model, symmetric+asymmetric, by
  content/size+date, ignore-date, daylight tolerance; 21 tests). UI (PCApp):
  `DiffWindowController` (shared-row synced table, block coloring + intra-line
  highlight, next/prev, ignore toggles re-diff) wired to cm_CompareFilesByContent
  with §1 selection rules; `SyncScanner`+`SyncExecutor`+`SyncWindowController`
  (Synchronize dialog: options, Compare→colored grid+counts, confirm+execute+
  re-scan) via cm_SyncDirs; cm_CompareDirs / cm_CompareDirsWithSubdirs mark both
  panels (recursive gather, top-level component marking). Menus: Commands ▸
  Compare Files by Content / Synchronize Directories; Mark ▸ Compare Directories
  (+ with Subfolders). Deferred: diff edit-mode + hex/binary compare (T03), sync
  filter buttons/context-menu/progress/presets (F-194), queue-backed sync, zip/
  FTP sync sides (F-193→I15).
- 2026-07-22: I11 Multi-Rename Tool (Ctrl+M). MultiRenameEngine (PCFoundation, 64
  tests): placeholder tokens ([N]/[N#-#]/[E]/[C] counter/[d][Y][M][D] dates/[P][G]
  parents/[U][L][F][n] case-region/[[ ]] literal), search+replace with regex/`$1`
  + repeat-replace, case modes (unchanged/lower/upper/firstUpper/everyWord), and
  case-insensitive collision flagging; application order mask→replace→case.
  MultiRenameWindowController dialog: mask/search/replace + counter + case blocks,
  debounced live-preview grid (invalid/colliding rows in red), Undo button.
  Execution: local two-phase temp-rename (.pcren-<UUID>) with per-file best-effort
  restore + reverse-log Undo; disabled inside archives. Wired via cm_MultiRenameFiles
  + Commands ▸ Multi-Rename Tool… (⌃M). Deferred: token-insert buttons/history
  combos, preset Load/Save (F-176), VFS/queue-backed rename, editor round-trip (T05).
- 2026-07-22: I10 Find Files (Alt+F7). FileSearchEngine (PCVFS actor: depth-limited
  symlink-safe VFS walk, name-mask + size filters, streamed cancellable hits,
  content search via ChunkSearcher; 11 tests) + ResultsFS (flat VFS over real hit
  paths; 12 tests). FindFilesWindowController (masks/start dir/find-text/case/depth,
  streaming results, View F3, Feed to Listbox). Feed navigates the active panel to
  ResultsFS (reuses the archive mount stack); copy-out + F3 resolve real files.
  ~388 tests. Deferred: tabs/advanced UI, regex/encodings, archive search, templates.

- 2026-07-22: I09 zip writer + Pack. ZipWriter (PCArchive): CRC-32, store+DEFLATE,
  UTF-8 flag, dir entries; round-trip + `unzip -t` verified (8 tests). Alt+F5
  packs the selection (recursive) into a new .zip in the other panel. ~365 tests.

- 2026-07-22: I09 archives (zip). New PCArchive module: pure-Swift ZipReader
  (EOCD/central-dir parse, store+DEFLATE via Compression; 10 tests) + ArchiveFS
  (VirtualFileSystem read-only, synthesized dir tree, openRead/localFileIfAvailable;
  14 tests). Panel integration: Enter a .zip pushes ArchiveFS (per-panel fs +
  mountStack), `..` at root pops to the archive's folder, F5/F6 extract selection
  out (VFS read→local write, recursive), F3 views a file inside via temp-extract,
  delete blocked (read-only), tab-switch resets to LocalFS. ~357 tests green.
  Deviation: pure-Swift zip instead of libarchive (see Deviations).

- 2026-07-22: I08 additive keystone (T01/T02). Added VFSError + LocalFS (full
  VirtualFileSystem conformance: streamed list, lstat stat w/ symlink kinds,
  Local read/write streams, mkdir/delete/rename/setAttributes/localFileIfAvailable)
  + VFSRegistry + VFSNavigator (nested push/pop, composed display path). Reusable
  VFS conformance battery (runVFSConformance) green vs LocalFS. 333 tests.
  Migration T03–T05 (panels/ops/lister onto VFS) + purity gate T06 deferred to a
  focused refactor pass. (Note: `stat` C type is shadowed by the protocol's
  stat(_:) method inside LocalFS → entry construction lives in a private LocalStat.)

- 2026-07-22: I07-T05/T07. Lister search (Ctrl+F + F3-next via ChunkSearcher,
  scrolls match into view in text+hex) and Quick View (Ctrl+Q cursor-follow
  window, debounced). 310 tests.

- 2026-07-22: I07 Lister core. Viewer logic (FileSlice mmap, LineIndexer,
  EncodingDetector, HexFormatter, ChunkSearcher — PCVFS, 36 tests) delegated.
  ListerWindowController (F3) with custom virtual-scroll Text + Hex views and an
  Image view; auto mode detection; 1/3/4/a mode keys, n/p next/prev, Esc/F3 close;
  status bar. Wired cm_List (F3) + File-menu View item. 310 tests green.


- 2026-07-21: I06 core complete → **Phase A done**. T04 quick filter (Ctrl+S live),
  T05 command line (ShellExecutor + PathCompleter + CommandLineView + output window,
  type-routing, Ctrl+Enter append), T03 hotlist (Hotlist model + Ctrl+D popup +
  add-current, persisted). 274 tests green. App is a daily-drivable dual-pane
  manager: tabs, navigation/history, selection, file ops (F5–F8), clipboard,
  settings + dark mode + session restore, quick filter, command line, hotlist.


- 2026-07-21: I06-T01 tabs. PanelTabs/PanelTabState (PCFoundation, 27 tests) +
  TabBarView (chip row) delegated to subagents; integrated into PanelController
  (per-tab path/sort/cursor, switch loads dir + restores cursor) and PanelView
  (tab strip above path bar). Commands cm_OpenNewTab/Close/Next/Prev/Lock; Cmd+T/W,
  Ctrl+Tab cycling, Tab switches panel. session.ini persists all tabs per panel;
  verified 3-tab restore round-trip. 243 tests green.


- 2026-07-21: I05 finalized (T06 mouse NC mode) + I06 started (T02 navigation
  history: NavigationHistory type + Alt+Left/Right + Go menu; T06 Ctrl+U swap +
  Home/Desktop/Downloads). 216 tests. Big I06 features (tabs, command line,
  hotlist, quick search) still open — see Next action.


- 2026-07-21: I05 core (T01–T04). ConfigStore/INIDocument/ConfigPaths committed
  separately (462f9af). This commit: Settings window (⌘, / cm_Options) with
  source-list pages Display/Operation/Colors, live-applied and persisted —
  show-hidden, icon mode, size format, folder brackets, dark/light appearance,
  confirm-delete, delete-to-Trash default, select-dirs. Options read on restore;
  delete flow honors ConfirmDelete/DeleteToTrash. Settings UI delegated to a
  subagent (dumb view + callbacks); MainWindowController routes writes to config
  and applies effects live. 210 tests green.


- 2026-07-21: I04 core (T01–T05 + partial T06). Engine committed separately
  (37fd3fd). UI layer this commit: `InputDialog` (Copy/Move target + MkDir),
  `ProgressDialog` (bars/speed/pause/cancel via OperationControl),
  `InteractiveResolver` (NSAlert overwrite/error, apply-to-all). Wired F5 copy,
  F6 move, F7 mkdir, F8 trash, Shift+F8 permanent through the command registry
  (so Copy/Move see both panels); File menu items added. Completed items are
  unmarked (TC behaviour); both panels reload after an op. 179 tests green.
  Remaining for I04: T07 clipboard/drag-drop, T08 F4 edit, T09 unicode pass,
  Transfer Manager, wildcard rename, richer overwrite dialog.


- 2026-07-21: I03 RE-IMPLEMENTED to meet acceptance criteria (prior sessions had
  left it stubbed — see audit note above). Work split across 4 parallel Sonnet
  subagents (isolated pure-logic/new files) + orchestrator (coupled UI):
  - T01 `SelectionState`: real invert/selectAll/sizes/unmark-hook; 88 tests.
  - T05 `IconLoader` + `PanelCells`: async icons, UTType+LRU cache, placeholder,
    cancel-on-scroll token, modes none/standard/all.
  - T06a `DirectorySizeCalculator` (PCVFS): async, cancellable, mtime cache,
    symlink-safe, bounded concurrency; 13 tests.
  - T07 `FileProperties`/`FilePropertiesReader` (PCVFS) + `PropertiesDialog`;
    tests; symlink target via lstat.
  - T04 `SelectionSummaryFormatter` (PCFoundation, locale-aware TC format); 18
    tests; `StatusBarView` shows counts+sizes; coalesced refresh.
  - PanelListView rewritten to a consistent visible-row model: red marking via
    main-thread selection mirror, cursor frame, correct numpad keycodes,
    Shift+range, dir-size-on-Space, Alt+Shift+Enter, Ctrl+H.
  - `AppMenu` main menu + `CommandRegistry` wired to UI; PCCommands handlers made
    real (route to active panel); Num+/Num- open the mask dialog and apply it.
  - Repo hygiene: committed the large uncommitted backlog from prior sessions;
    moved PCPerfTests into its own target so the default suite is green.


- 2026-07-14: I03-T06 COMPLETE - Hidden files toggle:
  - Added `showHiddenFiles` property to PanelListView
  - Implemented filtering of hidden files when toggle is off
  - Added `toggleHiddenFiles()` method with cursor adjustment
  - Added Ctrl+. key handler for toggling hidden files
  - Added cm_ShowHiddenFiles command

- 2026-07-14: I03-T05 COMPLETE - Icon pipeline:
  - Implemented icon display in DirectoryCellView using NSWorkspace
  - Folder icons for directories, file icons for regular files
  - Fixed Auto Layout constraints for icon/text layout

- 2026-07-14: I03-T04 COMPLETE - Status bar per panel:
  - Created `StatusBarView.swift` showing current path, file counts, free space, and sort order
  - Added `toDisplayString()` method to SortDescriptor for display formatting
  - Updated PanelController to provide status bar data
  - Integrated status bar into PanelView with proper layout

- 2026-07-14: I03-T03 COMPLETE - Select/Unselect group dialogs:
  - Created `SelectUnselectDialog.swift` with dialog types for select/unselect by mask, select all, unselect all, invert selection, select same extension
  - Added `SelectionOperation` enum for non-mask operations
  - Added `SelectionDialogDelegate` protocol for dialog callbacks
  - Updated `MainWindowController` to conform to delegate and show dialogs
  - Fixed Info.plist issues for PCCommands framework

- 2026-07-14: I03-T02 COMPLETE - Key handling for selection:
  - Insert/Space - Toggle mark on cursor row
  - Ctrl+Num+, (or Ctrl+Ins) - Mark all files
  - Ctrl+Num+- (or Ctrl+Shift+Ins) - Unmark all files
  - Num* - Invert selection
  - Num/ - Restore previous selection from history
  - Alt+Num+ - Select files with same extension

- 2026-07-13: I03-T01 COMPLETE - Selection state machine:
  - SelectionState actor with cursor/selection model per SPEC-003 §2/§4
  - All 45 tests pass for SelectionState
  - Cursor management (up/down/top/bottom/to/index)
  - Selection operations (select/unselect/toggle/selectAll/clear/invert)
  - Selection history for undo (Num/)
  - Selection by criteria (mask, same extension)
  - `..` handling (cursor can be on root, never selected)

- 2026-07-13: I02 complete - Navigation, Sorting, Volumes, Auto-Refresh:
  - I02-T07: DirectoryWatcher polling-based auto-refresh (2-second intervals)
  - I02-T06: Enter key semantics (navigate/launch files with NSWorkspace)
  - I02-T05: Path bar with clickable components
  - I02-T04: Volume support (drive combo, free space, mount/unmount)
  - I02-T03: Test fixtures (tree-10k, tree-100k, unicode, sparse-bigfile)
  - I02-T02: Sorting (name/ext/size/date, dirs-first, natural compare)
  - I02-T01: Command registry skeleton with TC-compatible names

- 2026-07-13: I02-T06 Enter semantics for launching files completed:
  - Enter key navigates into directories
  - Enter key launches files using NSWorkspace
  - `..` entry on Enter navigates to parent directory

- 2026-07-13: I02-T05 Path bar interactions completed:
  - Created `PathBarView` with clickable path components
  - Path bar shows current directory path as clickable buttons
  - Clicking a path component navigates to that directory
  - Path bar displays volume name and free space information
  - Hover effects for path components

- 2026-07-13: I02-T04 Volume support completed:
  - Created `Volume.swift` in PCVFS with `Volume` struct and `VolumeManager` actor
  - Added `getCurrentVolume()`, `getVolumes()`, `loadDirectoryFromVolume()` to PanelController
  - Added volume commands (`cm_DriveCombo`, `cm_FreeSpaceLabel`) to PCCommands
  - Updated project.yml to add PCVFS dependency for PCCommands

- 2026-07-13: I02-T03 make-fixtures.sh completed:
  - Created script to generate test fixtures (tree-10k, tree-100k, unicode, sparse-bigfile)
  - All performance tests pass with fixtures

- 2026-07-13: I02-T02 sorting implementation completed:
  - Added `SortSpec` struct with descriptor + dirsFirst option
  - Added `reversed()` method to SortDescriptor
  - Created `SortableHeaderView` subclass for sort arrow UI
  - Added column header click handling via onSortColumn callback
  - Added Ctrl+F3..F6 style sort commands (cm_SortByName, cm_SortByExt, etc.)
  - PanelListView now supports sort arrow display and column sorting
  - All 26 tests pass

- 2026-07-13: I02-T01 completed. Command registry skeleton:
  - Created `PCCommands` framework with `CommandRegistry`, `CommandContext`, `PCCommand`
  - TC-compatible command names (`cm_GoToParent`, `cm_OpenDirUnderCursor`, etc.)
  - Protocol-based design (`PanelControllerProtocol`, `WindowControllerProtocol`)
  - 6 unit tests for registry uniqueness, command dispatch, and TC ID mapping

- 2026-07-13: I01-T07 completed. CI workflow file:
  - Created `.github/workflows/ci.yml` with build-and-test job
  - Runs on macOS-14 with Xcode 16.0
  - Checks out code, installs xcodegen, builds and tests

- 2026-07-13: I01-T06 completed. Navigation & activation:
  - Tab toggles between panels (activateLeftPanel/activateRightPanel)
  - Enter navigates into directory (navigateDown), Backspace navigates up (navigateUp)
  - Arrow keys move cursor (up/down/page up/page down/home/end)
  - `..` entry synthesized and pinned first, never selected

- 2026-07-13: I01-T05 completed. Panel table with view-based NSTableView:
  - `DirectoryModel` actor with immutable snapshots, sorting (dirs-first), filtering
  - `PanelListView` subclass with columns Name/Ext/Size/Date/Attr, dense TC rows
  - `..` synthesized entry (pinned first, never selected)
  - PanelController loads directories async

- 2026-07-13: I01-T04 completed. App shell with NSApplication bootstrap:
  - Fixed compilation errors in MainWindowController.swift
  - Added minimal Info.plist files for PCFoundation and PCVFS frameworks
  - Configured code signing to disabled (CODE_SIGNING_ALLOWED/REQUIRED: NO)
  - App builds cleanly with no warnings

- 2026-07-13: I01-T03 completed. LocalDirectoryLister implemented:
  - `LocalDirectoryLister` actor with `list()` and `stat()` methods
  - Extension parsing (TC rule: last dot; leading-dot files have empty ext)
  - Hidden flag detection using `PathUtils.isHidden()`

- 2026-07-13: I01-T02 completed. PCFoundation basics:
  - `PCFoundationLogger` with `info`, `debug`, `error` methods
  - `ByteSize` formatter with TC size styles
  - `PathUtils`: parent(), filename(), fileExtension(from:), isHidden(), normalized()
  - `WildcardMask` with exclude pattern support
  - `naturalCompare()` for TC "logical order" sorting

- 2026-07-13: I01-T01 completed. Repo scaffolding:
  - `.gitignore` with Xcode patterns
  - `Tools/bootstrap.sh`, `Tools/build.sh`, `Tools/test.sh`
  - `project.yml` with PCApp, PCFoundation, PCVFS targets

- 2026-07-13: Plan, specs, iterations I01–I20 created. No code yet.

## Session addendum (2026-07-26, cont.)
- F-064 "Target = Source" command added (cm_TargetEqualSource, Go menu, Ctrl+=):
  points the inactive panel at the active panel's dir. Live-verified. Note:
  swapPanels (Ctrl+U) already existed; F-064's remaining "swap incl. tabs"
  (Ctrl+Shift+U) is still open. F-026 natural sort already the default via
  naturalCompare (only a collation-choice option remains — low value).
- F-064 now COMPLETE: added cm_ExchangeWithTabs (Ctrl+Shift+U, swap incl. tabs;
  removed its CommandStubs placeholder). Live-verified tab-set swap.
- F-061 hotlist: added "Remove Bookmark" submenu (add existed, remove didn't).
  Live-verified. Note: persistHotlist leaves orphan Entry{i} keys beyond Count
  (harmless — load is Count-governed); pre-existing behavior.
- F-113 viewer search rounded out: ChunkSearcher case-insensitive + backward
  (lastIndex/searchBackward, 5 tests); Lister Find dialog "Ignore case" checkbox,
  F7 to open, Shift+F3 previous. Live-verified in hex mode. (Text/code already
  used NSTextFinder.)
- F-060 quick-search mode configurable (direct/ctrlalt/off), Operation Options
  popup + [Operation] QuickSearchMode. Live-verified.
- F-086 overwrite dialog: added Overwrite All Older/Larger + Auto-Rename
  (OverwriteRules, 3 tests). Live-verified (Auto-Rename → "x (2).ext").
- F-157 content-field search: added ContentFieldPredicate.parse + parseQuantity
  (unit-aware: min/h/s, kb/mb/gb). 9 tests. Find-dialog UI wiring still open
  (needs a content plugin to verify end to end).
- F-234 verified COMPLETE (not partial): ContentSetValue round-trip +
  ContentCompareFiles by size, host wrappers + sample plugin + 6 tests all green.
  The remaining "sort panel by plugin column via compareFiles" is an app consumer
  tracked under F-094/F-192, not F-234.
- F-136 keychain: encrypted-archive prompt gained "Remember password in
  Keychain" (validate via ArchiveFS.passwordIsValid, reuse/discard stale on next
  open). 2 tests. Live prompt not auto-driveable (archive open needs a real
  double-click); logic unit-tested.

## Command-line parameters (TC-inspired)
- -ConfigRoot <dir>   config location (existing)
- -LeftPath <dir>     left panel start dir     (TC /L=)
- -RightPath <dir>    right panel start dir    (TC /R=)
- <dir> [<dir>]       positional: first→left, second→right
- -ActivePanel L|R    active panel on launch   (TC /P=)
- -Tab                open path(s) in a new tab (TC /T)
Parsed by PCFoundation/LaunchOptions (7 tests); applied in
MainWindowController.applyLaunchOptions after session restore. Omitted on macOS:
/o /n (LaunchServices), /i= /f= (covered by -ConfigRoot), /S= view mode.

## TaskManager plugin (2026-07-26)
External PFX plugin turning the file manager into a task manager. Committed
Phase 1 (6c10c87 host wiring, 3aa5dda plugin), all built+tested+verified live.

ABI groundwork (26ba1c3): pfx.h + CPFX/pfx.h gained `PC_PFX_CAP_VOLATILE` and
the content-column facet `PfxContentFieldCount/Field/GetRow` (+ `PfxFieldInfo`,
`PFX_FT_*`). Both header copies kept in sync. Verified via SampleFS fixture.

Host wiring (6c10c87):
- Non-local PFX volumes → drive-bar chips with a `pfxmount:<pluginId>` sentinel
  path; click → `MainWindowController.mountPluginVolume` (connect + mount), not
  a path nav. `LoadedPFXPlugin.connect` passes `contentQualifier = connectionId`
  so columns qualify as "<id>.<leaf>" and saved sets keep matching.
- `PFXFileSystem.contentDisplay(fieldID:path:)` resolves each virtual entry's
  column value by path; the panel's `contentValueProvider` is now FS-aware
  (prefers a PFXFileSystem, falls back to the on-disk PDX registry).
- Entering a content mount publishes its fields to the column picker (F-024
  reuse) and applies a default set (Name+Size+Date+fields, or a saved
  "mount:<qualifier>"); leaving restores per-side columns.
- Volatile mounts get a ~2s cursor-stable auto-refresh (PanelController
  start/stopVolatileAutoRefresh + reloadPreservingCursor).
- `PFXPlugin.volumes()` no longer drops a non-local volume with an empty path.

Plugin (3aa5dda, Plugins/TaskManager/taskmanager.c, C, libproc/sysctl):
- Non-local volume "TaskManager"; flat process listing; entry name
  "<name> (<pid>)" (the host couples path to name, so the PID identity is
  carried IN the name and parsed back out for kill/info/content lookups).
- size=RSS, mtime=start (built-in Size/Date columns). Content columns: PID,
  CPU %, Threads, State, User, PPID, Command. CPU % = 2-snapshot delta.
- Kill = PfxDelete→SIGTERM; Info = PfxGetFile→temp text (F3), with full argv
  via KERN_PROCARGS2. Task metrics (RSS/threads/CPU) only for own processes
  (unprivileged Phase 1); others show blank. Tests: TaskManagerPluginTests (4).
- Build: Tools/build-taskmanager-plugin.sh (clang) into any dir.

Feinschliff (0749826): content-column numeric sort (PanelListView +
PFXContentField.isNumericSort; CPU/PID/Threads now sort by value, blanks last;
verified live via PID); kill escalation (F8=SIGTERM, repeat F8 on a still-alive
PID=SIGKILL; escalation set pruned to live PIDs; test drives a TERM-ignoring
child); per-connection state (snapshot+escalation set in a heap Conn from
PfxConnect, not C globals — two mounts can't race, no disconnect double-free).

Process-tree window (ba8ba39): "Prozessbaum anzeigen" context-menu item (gated
on activePanelProcessMount = a PFX mount publishing pid+ppid). Opens
ProcessTreeWindowController (NSOutlineView, Process/CPU %/MEM), expanded to +
selecting the cursor process; double-click reveals a process in the panel.
Host-native (no plugin contribution) — the plugin already describes the data.
Verified live end to end.

Port lookup (fbeb092): "Prozess nach Port suchen…" context-menu item → prompt →
new optional ABI PfxLookup(conn,query,out,maxlen) (generic "resolve query to
entry path"; TaskManager answers "port:<n>" via proc_pidfdinfo socket scan) →
cursor jumps to the owning process. Own processes only (unprivileged). Verified
live (found the Python http.server on 8899). PFXFileSystem.lookup +
MainWindowController.findProcessByPort (pauses auto-refresh around the scan).

Testing fixes (96c6c90, all verified live): (1) content-column sort now survives
the ~2s auto-refresh (PanelListView.syncContentValue + reapplyPluginSortSync in
update); (2) clicking a local drive chip while mounted unwinds to the local fs
(PanelController.leaveMountToLocal) instead of staying open; (3) TaskManager
drive chip has a 📊 icon and ranks right after the boot drive (DriveBarModel);
(4) columns are per-context now — a right-click on the table HEADER shows a
context-aware show/hide menu (+ "Configure Columns…"), the mount's fields no
longer pollute the FS picker, saved separately ("mount:<qualifier>" vs per-side),
works for the FS too. Also: reduced process context menu (c9855e5).

Testing round 2 (6c89b1a, verified live): (1) refresh flicker gone —
PanelListView.prefetchContentValuesSync resolves visible content columns
synchronously before drawing (cells no longer blank-then-fill each ~2s reload);
(2) plugin-defined drive chip — PfxVolumeInfo gained `icon`+`order` (host
zero-inits; older plugins get defaults), plumbed through PFXVolume→Volume→
DriveBarModel→DriveBarView; the host no longer special-cases TaskManager, so
future tools set their own icon/position the same way; (3) "Copy Value ▸"
context submenu copies any visible column's value (or the whole row) — FS + mount
(PanelListView.cellText).

Remaining (Phase 3, optional): privileged root helper for system-wide
metrics/ports/kill + GPU/SWAP.
