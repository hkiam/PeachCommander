# STATE — Single Source of Truth for Progress

> Update this file after EVERY completed work unit. Keep it short; move history
> to the bottom log. A new session must be able to resume from this file alone.

## Current status

| Field | Value |
|---|---|
| Phase | **A & B done. C: I14 done; I15 plain FTP LIVE (quick-connect + connection manager, verified vs test.rebex.net; SFTP + explicit-FTPS still pending); I16 lister/content plugins mostly done. D: I17 utilities mostly done; I18 macOS integration MOSTLY DONE (Quick Look Cmd+Y, Share sheet, Open With, Finder Tags: color column + tag-filter (tag:red/#blau), Spotlight metadata in Get Info, Services menu integration, "Open Terminal Here", Full Disk Access onboarding, Go▸Trash, xattr inspector/remove in Change Attributes, privileged "retry as administrator" for chmod+delete done; ACL editing/copy-move-elevation/undo pending). Also F-063 Ctrl+Left/Right open cursor folder in other panel done.; I19 partial (perf targets validated); I20 shipping GROUNDWORK done (DMG script + release CI workflow + hardened-runtime entitlements + RELEASE.md + CHANGELOG + local crash reporting; only Developer-ID signing/notarization and Sparkle auto-update remain — both need Apple creds / update-feed hosting).** |
| Evidence sweep | **Batches 1–24 (2026-08-07/08): 73 rows checked, 33 defects fixed, 87 → 21 rows without evidence.** Worst: a file name could run a shell command through a user-menu %-token (F-252); a crafted archive wrote outside the chosen folder (F-131); the archive password stood in the process list (F-136); a CRLF code file rendered as one line six million characters wide (F-110); undoing a batch rename did nothing (F-175); Num/ did nothing (F-056); a wildcard selected the *wrong* file (F-055); a Windows-written .sfv verified nothing (F-097). Six defects were one Swift trap — `"\r\n"` is a single Character. New gates: `check-checksums.sh`, `check-pack-formats.sh`, `check-strings-extracted.py`, `check-tests-registered.py`, `check-vm-flags.sh`, plus `check-descript-format.sh` extended. Of the 21 rows left, 8 are blocked externally (Apple credentials, SMB mounts, the Services menu). |
| Current iteration | **Editor: JSON/YAML/XML outline, structural navigation, paths, validation and transformations DONE (F-368/369/370)**; I19 T06 accessibility + keyboard operation DONE (see the log below). Docs/i18n complete. **I19 localization + help DONE (19 languages)**; **documentation system live** (SSOT → Apple Help Book + MkDocs site + generated FEATURES/README). Remaining big blocks: I20 Developer-ID signing/notarization + Sparkle auto-update (both need Apple creds / feed hosting); accessibility (I19 T06) **done**. |
| Build status | ✅ builds; app launches |
| Test status | ✅ ALL suites green incl. PCPerfTests after `Tools/make-fixtures.sh` (fixtures at /tmp/pc_fixtures). Perf targets validated 2026-07-23: list 100k < 1s, sort 100k < 150ms, filter 10k < 50ms — all met with wide margin. |
| Parity inventory | Fully re-audited against evidence 2026-08-04: **161 done · 9 partial · 2 todo · 7 n/a-macos · 2 post-1.0** (181 rows). The line before this claimed 59/70/43; the audit went through every `todo` row and then every `partial` one at P1, P2 and P3. Of 18 `todo` rows 16 were implemented, of 50 P1 `partial` rows 46 were, and of 19 P2/P3 `partial` rows 16 were — most "missing" sub-parts were missing only from a first grep. **Still open:** F-212 upload resume, F-213 explicit FTPS (needs a transport that can start TLS on a live connection — Network.framework cannot), F-193 an FTP side for the sync, F-099 privileged copy/move, F-139 non-zip archive targets, F-015 a shared tree, F-216 FXP (P3), F-297 Trash put-back (no public API), F-237 SFTP as a PFX plugin (a design decision), and F-310/F-312 blocked on Apple credentials. 237 `ev:` pointers must resolve for `Tools/check-inventory.py` to pass; **67** older `done` rows still carry none (was 87 before the evidence sweep of 2026-08-07/08 — see the ten batch entries below). **The sweep found a defect behind roughly four of every five rows it checked**, most of them in the same few shapes: a CRLF file from Windows, an input a dialog really receives, an untrusted name reaching a shell, and two names for one file. Where a row held up, that is recorded too. |
| Last updated | 2026-08-08 |
| Localization | 🌐 **19 languages COMPLETE** (en, de, fr, zh-Hans, da, nl, it, ko, nb, pl, sv, sk, sl, es, cs, uk, hu, ro, ru). App String Catalog (1172 keys × 19) + all shipping plugins + the **full in-app Help Book (44 topics × 19)**. Coverage gate `docs/scripts/check-translations.py` green (languages=19 · help_topics=44 · ui_strings=1172 · behind=0). Adding a language = 1 UI translations file + `knownRegions` + a `docs/help-<code>/` set (+ optional plugin `<lang>.lproj`). |
| Documentation | 📚 SSOT docs (`docs/content/`) → **Apple Help Book** (`Resources/PeachCommander.help`, 19 lproj) + **MkDocs site** (`build-site.py`, en at root + 18 at `/<code>/`) + generated `FEATURES.md`/overviews. New project **README.md**. Detailed plugin help pages (Git, System Monitor, Task Manager, Uninstaller) added, each with a real **English** screenshot; AI documented as a removable plugin. Screenshots English-only by design (VM harness forces guest locale to en; `pfxmount` verb + demo Git repo/apps/leftovers make the plugin UIs reachable). |

**Harness: two failures that were mine.** A flaky test — `DirectoryWatcher` expectations were fulfilled
twice, because FSEvents coalesces or does not as it sees fit; four of the five positive expectations
lacked `assertForOverFulfill = false` and now have it, with the reason written down. And a whole suite of
empty reports, which I spent half an hour reading as a product defect: I had rebuilt the app *while the
harness was copying it to the guest*, so the VM ran a half-written bundle that launched and then did
nothing at all. `regress.py` now compares the binary before and after the copy and stops with that
sentence rather than letting it look like something else.

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
one-time `.bak` backup + dirty tracking + save-on-close prompt. F4 (`cm_Edit`) and
Shift+F4 (`cm_EditNewFile`) now open this editor instead of the external app. Highlight
verified offscreen. 955 tests green.

**More TODO items:** sort-arrow position fixed via headerRect (#34); Shift+F6 rename
with old name preselected + `RenameValidator` (#40); POSIX-permission checkbox dialog
`AttributesDialog` (#39); panel type-ahead cursor navigation `TypeAheadSearch` (#64);
panel-header "★" Go button → `SpecialDirectories` + hotlist manager (#65); **hex editor**
`HexEditorWindowController` over a tested `HexDocument` (overwrite/insert/delete, undo/redo,
.bak save; File ▸ "Edit as Hex…", #26). All engines unit-tested; UIs verified offscreen.
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
