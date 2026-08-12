# Changelog

All notable changes to Peach Commander are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/) — with the reservation that everything before 1.0 is a beta
and any release may still change behaviour it got wrong.

`docs/distribution/release-and-updates.md` referred to this file before it existed; the releases below
were reconstructed from the git history and the notes in `STATE.md` when it was written.

**Every build so far is unsigned and un-notarized.** macOS will refuse to open it on the first attempt;
`README.md` explains the Control-click route. Signing needs an Apple Developer ID, which the project
does not have.

## [Unreleased]

### Fixed

- **A refreshing list no longer takes your place in it.** Scrolling somewhere in the Task Manager
  drive to read something lasted about two seconds: the automatic refresh dragged the view back to
  the cursor row — or to the very top, if you had not moved the cursor at all. The same happened in
  an ordinary folder whenever something in it changed (a download finishing, a build writing files),
  and after every copy or delete. A refresh now leaves the view and the cursor exactly where they
  are; jumping to a row still happens when *you* move the cursor, search, or come back from another
  folder. If the row under the cursor disappears — a process ends — the cursor keeps its place in
  the list instead of going back to the top.
- **"Quit Process" now actually ends the process.** F8 in the Task Manager drive answered "Files inside
  this archive cannot be deleted" and left the process running: the panel treated everything that is not
  the local disk as an archive, so the plugin's own delete was never called. The same hole made deleting
  a file on an FTP or WebDAV server do nothing. Deleting now goes through whatever the panel is actually
  showing. A second F8 on a process that ignores the polite request still escalates to a force quit.

### Added

- **Open a process and see the files it has open.** A process in the Task Manager drive is now a folder:
  press Enter on it and the panel lists the files that process is holding, as ordinary file rows. From
  there you can view a file (F3), send it to the other panel with *Go to File*, or reveal it in the
  Finder — the question "what is this thing touching?" answered where you can act on the answer.
- **The columns Activity Monitor has and this didn't.** Memory footprint (the number Activity Monitor
  shows, which is not the same as resident size), bytes read and written to disk, and wakeups. Memory has
  its own column now that a process row is a folder, and byte counts are rendered as KB/MB and sorted by
  the number behind them.
- **Who signed each program.** A *Signed* column names Apple, a Developer ID team, an ad-hoc signature or
  no signature at all — readable for every process, including other users', because it comes from the
  program file rather than the running process. The F3 report adds the hardened-runtime flag and the
  program's entitlements. The column fills in over the first few seconds; a blank cell means "not read
  yet", not "unsigned".
- **Other users' processes show numbers too.** CPU and resident size are filled in for root's processes
  as well, which used to be a quarter of the list with every metric blank — no administrator password
  involved. Those two figures come from `ps` and are labelled as such in the process report, because its
  CPU value is a lifetime average rather than a live sample.
- **Find out which processes have a file open.** The Task Manager drive could tell you which process
  was sitting on a TCP/UDP port, but not which one was holding the file you were trying to replace.
  Right-click in the process list, choose *Find Processes by File…*, and every process with that file
  open is coloured by how it holds it: one colour for reading, one for writing, one for both. The path
  is prefilled from the cursor in the other panel, and the cursor jumps to the first process that can
  change the file. *Clear File Highlight* removes the colours; leaving the process list removes them
  too. As with the port search, other users' processes need elevated privileges to inspect.

## [0.6.1] — 2026-08-12

Three user reports, and each of them turned out to be about something the application was
deciding on the user's behalf. It left `.bak` files in folders you curate, with nothing
anywhere to turn that off. It knew the terminal as "the thing in the bottom strip", so
moving it to the side panel left its own menu commands opening an empty strip instead. And
its quick previews could show you a picture but never let you look closer at it.

**Still unsigned and un-notarized.** macOS blocks the first launch; `README.md` explains
how to allow it once.

### Changed

- **The editor no longer leaves `.bak` files behind.** Every save from the built-in text editor, the
  hex editor and the compare window dropped a copy of the previous contents next to the file, and
  there was nothing anywhere to turn it off — so the folders you work in filled up with files you
  then deleted by hand. Saving now simply saves. If you want the copy, switch on *Keep a backup copy
  (.bak) of the previous contents when saving* in Settings ▸ Edit/View; it applies to all three
  windows at once, including the ones already open.

### Added

- **Zoom a picture — in the quick preview and in the viewer.** The **Info** page of the side panel had
  no zoom at all, so a photograph was however large the panel happened to be. A picture now carries four
  controls in the corner of the preview — zoom out, zoom in, actual size, fit — with the level next to
  them, and pinching or Cmd+scroll works there too. Quick View (Ctrl+Q), which takes over the panel you
  are not using, gets exactly the same controls. The viewer gets the same four as menu items on
  ⌘+, ⌘−, ⌘0 and ⌘9 (the bare +, − and 0 keys still work, and F fits), with the level in the status
  line. A big picture opens fitted; a small one is left at its own size instead of being blown up; and
  *Actual Size* now really means one image pixel per screen point — it used to show a fitted image and
  call it that, which made 1:1 unreachable. Fit stays fit: resize the window or drag the panel wider and
  the picture follows.

- **Show Terminal, in the Terminal menu.** Folding the terminal away and bringing it back was
  *View ▸ Bottom Area* — an item named after the strip it happens to sit in, in a different menu from
  everything else the terminal can do, which is why it was not findable. The new item is the first one
  in the **Terminal** menu, carries a checkmark for whether the terminal is on screen, and follows the
  terminal if you have moved it to the side panel. Hiding it is not closing it: the shells keep
  running and the tabs come back exactly as they were.

- **The drive bar shows what each volume is.** It drew three icons in all — a screen for the startup
  disk, whatever a plugin supplied, and one floppy for everything else — so a network share, a USB
  stick and a mounted disk image were identical in the one place they are listed side by side, which
  is the place you go to choose between them. Every volume now carries its own icon, the same one
  Finder shows, including the custom icon a branded drive ships with. A plugin drive keeps the icon
  its plugin chose, and where there is nothing to ask — a cloud folder is a folder, and the system
  has only the generic folder icon for it — a symbol for the kind stands in. Screen readers are told
  the kind in words, since an icon is nothing to hear.

- **Eject from the drive bar itself.** 0.6.0 added ejecting and gave it one route — a command that
  works out which volume you mean from where the cursor is standing. The place you actually look, the
  button for the volume, did nothing at all on a right-click. It now offers *Eject*, and the button
  carries a small ⏏ you can click directly. Volumes that cannot go are shown greyed out rather than
  hidden, with the reason in the tooltip: an empty menu over the startup disk reads as broken, while
  a disabled entry teaches the rule at a glance.

### Fixed

- **The terminal's commands find it in the side panel.** *Split the Terminal*, *New Terminal Tab*,
  *Close the Terminal Tab*, *Go to the Panel's Folder* and *Insert the Selected File Names* all opened
  the strip across the bottom and looked for the terminal there. Move the terminal to the side panel —
  which its own placement menu offers — and each of them opened that strip **empty** instead, while
  appearing to do nothing at all. They now bring the terminal up wherever you have put it.

- **Moving the terminal to the side panel switches to it.** It arrived behind whichever tab the panel
  was showing, usually *Info*, so the move looked as if it had been ignored or had lost the view. And
  moving it back sometimes left an empty area behind, because the container it was leaving could take
  the view out again just after the new one had taken it in — that was down to timing, which is why it
  only happened sometimes.

- **Moving a plugin view to the place it already sits no longer pins it there.** The move was recorded
  as a decision of yours even when it agreed with what the plugin asked for, so *Reset to Default*
  appeared for views you had never moved, and a plugin update that relocated its own view would have
  been quietly overruled. Where you actually moved something is still remembered, including while its
  plugin is switched off.

- **The terminal is open again after a restart if it was open when you quit.** The state was written
  down all along; the plugins load after the window has been arranged, so the area was opened, found
  nothing in it yet, and shut itself as an empty frame. It now waits for the terminal to arrive — and
  still stays shut if you closed it yourself.

- **A drive contributed by a plugin now behaves like a drive.** Picking *TaskManager* in the drive bar
  switched the panel and nothing else: the button stayed selected on the volume you were on before,
  the tab was still called “/” and the path bar claimed you were at the top of the startup disk. All
  three read the folder path, and inside such a drive that path is the drive's own top, which belongs
  to no disk you could point at. The drive itself now decides what they show, so the button stays
  selected while you are in it, the tab carries the drive's name, and the path bar starts at the drive
  instead of at a slash. The tab remembers it, too: switch to another tab and back, or quit and reopen
  the app, and the tab returns to the drive rather than to the startup disk's root — and duplicating
  such a tab duplicates the drive, while a new tab opens where the panel was before you entered it.
  Reported as being impossible to follow, which it was: the bar said one thing and the listing another.

## [0.6.0] — 2026-08-11

A repair release. Everything below came out of one user report — a folder tree that stayed
white under the Midnight palette — because chasing it exposed that of 59 regression
scenarios, not one had ever looked at a colour. The audit built to answer that found a
crash on ordinary use, and the same sweep of the test harness found seven keyboard checks
that had been measuring nothing at all.

**Still unsigned and un-notarized.** macOS blocks the first launch; `README.md` explains
how to allow it once.

### Fixed

- **The local-network prompt on first launch now says what it is for.** macOS asks the moment
  anything enumerates network interfaces, which the title bar's throughput display does to read its
  byte counters — and with no explanation supplied, the prompt appeared before you had done anything
  and looked like an application asking to search your network. It now states the reason, and the
  reason is the whole of it: counters are read, nothing is searched for or connected to.
- **Changing the colour scheme with the Notes or Disk Map panel open no longer quits the app.** The
  two panels kept a reference to a table of host functions that is only valid while the host is
  handing it over; reading it later — which is what a theme change does — corrupted memory and
  killed the app outright. Found by the colour sweep below, not by the crash reports, because
  nothing had ever switched a theme with one of those panels open.
- **The terminal's status line is readable under Norton Commander colours.** It took its grey from a
  colour the palette defines for the path bar, which is black there and sat on a blue background
  here. Plugin panels now derive that grey from the surface they actually draw on, so it follows any
  palette instead of happening to suit some.
- **The folder tree follows the colour scheme.** Both of them — *View ▸ Tree* beside a panel and
  *View ▸ Shared Tree* — used to keep the light default whatever you had chosen, so under Midnight a
  white column of pale, barely readable text stood between two dark panels. The tree knew how to
  repaint itself and was never asked to.
- **Piping a selection through a command that stops reading early no longer quits the app.** `head -1`
  is an ordinary filter — it takes one line and leaves — and the rest of the text then had nowhere to
  go, which ends a program on macOS unless it says otherwise. Affected the editor's filter, the
  external formatters and anything else that pipes text through a tool.

### Added

- **Eject a removable volume without switching to Finder.** Right-click a volume — or anything on it
  — and the menu offers *Eject “name”*; the same command is in **Commands ▸ Eject Volume** and can be
  given a key of your own in the keyboard settings. It works from inside the volume too, not only
  from the folder above it. The startup disk is never offered, a network share says so rather than
  failing silently, and when something still has the volume open, macOS's own explanation of *what*
  is holding it is passed straight through — that sentence is the only thing that tells you what to
  close. This was listed as done and was not built at all: the app read which volumes were ejectable
  and then had no way to eject one.

- **Terminal tabs come back after a restart**, in the folders they were in. The shells cannot come
  back — those processes ended with the app — but three terminals in three checkouts no longer become
  three prompts in your home folder. A tab the assistant opened for one command is deliberately not
  restored.
- **The assistant can run a shell command — off unless you switch it on** (*Settings ▸ AI*), visibly, and only after you agree to each one. It opens a terminal
  tab, so what was run is on screen afterwards next to everything else you ran, and a command that
  asks a question can be answered. The approval quotes the command in full, because that is the whole
  decision. The tab runs a *non-interactive* shell: aliases and functions from your `~/.zshrc` do not
  apply, so the line you approved is the line that runs. A session set to read-only cannot use it at
  all, and it is not offered to external agents over MCP — those confirm their own plans, which is
  the right arrangement for file work they were connected to do and the wrong one for running a
  program of their choosing.
- **Panels can be dragged between the side panel and the bottom area.** Grab the mode switcher and
  drop it on the other one; the target lights up, and a panel dropped where it already is does
  nothing rather than pretending. The menu route (right-click the switcher) does the same thing and
  remains the one that works from the keyboard.

## [0.5.0] — 2026-08-10

### Security

- Copying files **out of an archive or off an FTP server** could write above the folder you chose. A
  member stored as `../escaped.txt` arrives in the listing as an entry named `..`, and the panel's
  extract walk followed it into the parent directory — silently, while the operation reported success.
  The archive extractor already refused this; the panel's own walk did not, and on an FTP source the
  name is whatever the server decided to send. Both now use one rule.
- **Opening an XML file could read your other files.** Foundation's `XMLDocument` resolves external
  entities, so a document declaring `<!ENTITY x SYSTEM "file:///etc/passwd">` had that file's contents
  substituted into what the app displayed — in the XML tree view, in an XPath result, and after "format
  XML" in the editor. A `http://` entity made the app fetch a URL while you thought you were looking at
  a local file. Nothing needed to be run: opening the file was enough.
- **Previewing a document no longer tells anyone you opened it.** A Markdown or HTML file containing
  `![](http://…/pixel.png?who=you)` fetched that image when the viewer rendered it — a read receipt for
  a file on your own disk. The viewer disabled JavaScript and considered the matter closed; an image
  element does not need JavaScript. Network loads are blocked in the preview now, and images sitting
  next to the document still appear.
- **The assistant's "ask before writing" gate could be walked around.** With the default permissions,
  asking the assistant to delete files presented a plan to approve first — but the same deletion
  invoked as a *command* (`run_command` with `cm_DeleteReal`) ran immediately, because the gate looked
  at which tool was called rather than at what it would do. Commands are now judged by what they
  change, and an unfamiliar command counts as changing something.

### Fixed

- **Keys aimed at a focused panel no longer reach the file list behind it.** Keyboard shortcuts are
  offered to every view in the window — which is how F5 copies wherever the cursor is — and the file
  list stepped aside only for plain text fields. Anything else that takes the keyboard had its keys
  taken: Ctrl+B typed into the command line's own view opened a directory branch instead. The file
  list now asks whatever is focused first.
- **Side-panel plugin views no longer restart when an unrelated plugin is switched on or off.** Every
  change to the set of enabled plugins rebuilt every embedded plugin view from scratch — invisible
  while those views show text, and not invisible at all once one of them holds a running program.
  Views that have not changed are now left alone.

- **The viewer no longer freezes when you look at a binary as text.** Opening an image and switching to
  text mode could stop the app for minutes — long enough to look like a hang, because it was one. The
  content went into the same text view used for source code, and laying out a megabyte of decoded
  binary means asking the system for a font for each of thousands of different characters. Such
  content now uses the view built for large files: the same switch takes about 30 ms. Looking at a
  binary as text still works — that is how you find the strings in one.
- **Opening a large file no longer pulls it into memory.** The viewer's outline asked for the whole
  text of a file it was about to refuse for being too long: a 175 MB file cost 306 MB of memory to
  show, in a view whose entire purpose is that the file need not fit. It costs 140 MB now.
- **Compare Directories with subfolders no longer freezes the window.** Both trees were walked on the
  main thread — about 1.6 seconds for a moderate source tree, far longer for a home folder.
- **tar archives no longer contain hidden `._` companion files.** macOS's tar writes one beside every
  file to carry its extended attributes; `tar -tf` hides them again, so they went unnoticed — but this
  app's own archive browser showed them, and unpacking such a tar on Windows or Linux produced the same
  litter. The trade is that Finder tags are not carried inside a tar.
- **Copying a huge file from the viewer no longer tries to build it in memory.** With nothing selected,
  Copy meant "the whole file"; above 20 MB it now says so instead. A selection is never refused,
  however large the file it came from.
- **Clicking in a large text file no longer stalls.** Highlighting the matching bracket forced the
  whole document to be laid out on every click.
- **The window title now says where you are.** It read "Peach Commander" whatever folder you were in —
  which is the text Mission Control, the Window menu and Cmd-Tab show, so two windows on two folders
  looked the same. The active path is in it now, with free space behind an option.
- **Double-clicking the splitter gives two equal panels again.** It did nothing at all.
- **"Start all" in the transfer manager no longer starts everything at once.** Twenty queued downloads
  began twenty simultaneous transfers; they take turns now, and one failure does not strand the rest.
- **"No icons" now really shows none.** Folder rows kept their icon.
- The disk image opens with the app and the Applications folder side by side on a proper background,
  instead of two icons wherever the Finder last left a window.

### Added

- **Terminal tabs can be closed** — an ✕ on each tab, and *Terminal ▸ Close the Terminal Tab*. If
  something is still running in it you are asked first, naming what it is, because losing an hour-long
  build to a stray click is the mistake you remember.
- **How much scrollback the terminal keeps is yours to set** (*Settings ▸ Terminal*). The default is
  5 000 lines instead of the emulator's 500, which is roughly 1.4 MB per terminal.
- **The terminal's status line only shows what there is to show.** With one tab and one terminal it
  reads `zsh · ~/work · 125×9`; the tab and pane counters appear when there is more than one of them.
- **The terminal has its own menu.** Everything it can do is in one place under *Terminal* — switch
  between the panel and the terminal, a new tab, split it, go to the panel's folder, insert the
  selected file names, run the command line in it. Previously these sat in *View*, wedged between
  "Tree" and "Reset Layout" under a heading called "Bottom Dock" that said nothing about a terminal.
  The area itself is now *View ▸ Bottom Area*, next to *Preview Panel*, which is the same kind of
  thing on the other edge of the window.
- **⌘-click a path in the terminal and the panel shows it** — a name from `ls`, a compiler error, a
  line of `git status`. Relative names resolve against the shell's folder, and a word that is not a
  path does nothing rather than navigating somewhere arbitrary.
- **The F-key bar dims while the terminal has the keyboard**, because F3 and F5 go to whatever is
  running in there and a bar reading "F3 View  F5 Copy" at full strength would be claiming otherwise.
- **⌘F searches the terminal's scrollback.** Edit ▸ Find now goes to whatever is focused, so the
  terminal answers with its own search bar — case, whole-word and regular-expression options included.
- **The file panel can follow the terminal** once you add the two lines the terminal's settings page
  shows you — a shell only reports its folder if asked, and macOS only asks on Apple's Terminal's
  behalf. A folder reported from an `ssh` session on another machine is ignored rather than followed.
- **The terminal has a settings page** with one switch and an explanation. Letting the file panel
  follow the terminal's folder needs your shell to report where it is, which macOS only arranges for
  Apple's Terminal — so the page shows the exact lines to add to your `~/.zshrc` and does not touch the
  file itself. The switch has no effect until you add them.
- **Files dropped on the terminal land at the prompt**, quoted and not executed — a name with a space
  or an apostrophe in it arrives as one argument. The terminal also follows the app's colours instead
  of being a black rectangle in a themed window.
- **The command line can run in the embedded terminal** (*View ▸ Run Command Line in Terminal*, off by
  default). A detached command has no terminal, so anything that asks a question never gets an answer —
  `sudo` prompts for a password where nobody can type it. Run in the terminal the prompt is on screen,
  output arrives as it happens, and a long command can be interrupted.
- **One key moves between the file panels and the terminal** (Ctrl and the key left of the "1"), and
  back to where the cursor was. The terminal stays open either way — closing it is what its close
  button is for. *View ▸ Terminal: Folder of the Active Panel* takes the shell where you are, and
  *Terminal: Insert Selected Names* puts the selected files at the prompt, quoted, without running
  anything.
- **The embedded terminal has tabs and can be split**, and nothing you have running is disturbed by
  either. Each tab is its own shell with its own scrollback; switching tabs, splitting the area into
  two terminals, collapsing back to one, and moving the whole terminal between the side panel and the
  dock all leave every shell exactly where it was. Collapsing a split hides the second terminal rather
  than closing it. A new tab opens in the folder the active panel is showing.
- **Quitting now closes embedded plugin views before the app exits**, so a plugin holding a file, a
  socket or a child process is told to let go instead of having the rug pulled out.
- **Plugin views can be moved between the side panel and the dock**, and put back. Right-click the
  mode switcher (or use the ⋯ button in the dock) to send a view to the other one; *View ▸ Reset
  Layout* puts everything back where it ships, including the dock height and the side panel's width.
  A plugin's manifest now only decides where its view starts out.
- **A dock across the bottom of the window** (View ▸ Bottom Dock, or Ctrl and the key left of the
  "1"). Plugins can now put a view there instead of in the side panel, which matters for anything that
  needs width: the side panel is 300 points wide and gives a monospaced font 44 columns, while the
  bottom of a 1200-point window gives 176. Nothing ships a view for it yet — this is the room being
  made, and the dock says so plainly when it is empty rather than opening as a blank strip. It starts
  closed, remembers the height you drag it to, and the shortcut is bound to the key's *position*, so it
  is the familiar Ctrl+backtick on a US keyboard without turning into a dead-key gesture on a German
  one.
- **One folder tree for both panels** (View ▸ Shared Tree), alongside the per-panel tree that was
  already there. Choosing a folder moves whichever panel is active.
- **Files can now be copied into tar and 7z archives, not only zip.** Pressing F5 into a `.tar` used to
  report "unreadableArchive", which was wrong twice: the archive was readable, it just was not a zip.
  Where it still cannot be done the message says why — a compressed archive would have to be repacked,
  or the `7z` tool is not installed. Deleting and renaming inside an archive remain zip-only.
- **Copying or moving into a folder you do not own can now be retried as administrator.** Deleting and
  changing permissions already offered this; copying and moving stopped with "permission denied" and
  no way forward. The offer appears only for what actually failed, and only when the destination is a
  folder you cannot write to — a copy that ran out of disk space is not helped by doing it as root.
  You are asked for your password once, however many files there are.
- **Synchronize Directories now works with a server as one side.** A panel connected to FTP or SFTP —
  or to a filesystem plugin — can be compared against a local folder and synchronised in either
  direction, subfolders included. Two servers with each other, and an archive with a server, are
  refused up front rather than partway through. Deleting on a server is permanent: there is no Trash
  there to move things to.

## [0.4.0] — 2026-08-08

Mostly a repair release. A systematic sweep went through the feature inventory looking for rows that
claimed to be done but had nothing verifying them: 73 rows examined, **33 defects found and fixed**.
Several of them could damage data or, in three cases, be used against you. If you are running 0.3.0,
this is the release to take.

### Security

- **A file name could run a shell command.** A toolbar button or a Start-menu command substitutes
  `%N`, `%P` and friends into a line handed to a shell. Those values are file names — they arrive with
  a download, an extracted archive, a shared volume — and they were quoted only when they contained a
  space, and then with double quotes, inside which a shell still substitutes. A file called
  `$(id).txt`, `` `id`.txt `` or `a;id;b.txt` therefore executed when any user-defined command was
  invoked on its folder. Every value is now a single-quoted shell word, through the one quoter that
  already guarded the elevated save.
- **A crafted archive could write outside the folder you chose.** A member named `../../evil.txt`
  landed beside and above the destination while the extraction reported success ("zip slip"). Such
  members are skipped now; the harmless ones in the same archive still arrive.
- **The archive password stood in the process list.** It was passed as `-p<password>` on the packer's
  command line, where `ps` shows it in full to anything running as the same user for as long as the
  archive takes to write. It goes to the packer on standard input now.

### Fixed — data

- **Undoing a batch rename did nothing** when the batch contained a cycle (`a → b` together with
  `b → a`). The forward direction staged through temporary names; the undo did not, so both moves
  failed and you were told the rename had been taken back.
- **A wildcard selected the wrong file.** Masks were turned into regular expressions with only the dot
  escaped, so every other metacharacter kept its regex meaning: `Bericht (2026).pdf` did not match the
  file of that name and *did* match `Bericht 2026.pdf`. This one matcher backs select-by-wildcard, the
  quick filter, the search's name masks, the sync filter and the type-colour rules.
- **`Num /` — restore the selection before the last operation — did nothing at all.**
- **A checksum file written on Windows verified nothing.** `.sfv` parsed to zero entries and `.md5`
  to one invented one, because a CRLF is a single character in Swift and the parser compared against a
  line feed. The same mistake made a Total Commander `.crc` sidecar unreadable, so a split file could
  not be put back together, and made a Windows-written `descript.ion` lose every comment but the first.
- **A file whose name begins with a dash could not be packed** — in any format. The packers read it as
  a switch; `tar` answered "Can't specify both -x and -c" and the whole operation failed.
- **Renaming more than 500 files with a `[=plugin.field]` placeholder** left the field out of every
  name. The values were fetched before the dialog opened, under a cap meant to save work, which instead
  decided the result.
- **A failed plugin upgrade took the working plugin with it.** The old bundle was removed before the
  new one was copied in, and a new one that would not load was then deleted too.
- **A rename that could not happen was not reported.** Names the batch could not deliver — a target
  held by a file outside the batch, an empty name — were dropped without a word.

### Fixed — things that were quietly wrong

- **A code file with Windows line endings between 4 and 16 MB rendered as a single line** six million
  characters wide, and the view never finished laying it out. Go-to-line, the marks panel and per-line
  notes all pointed at nothing.
- **A Finder colour label applied here was not the colour.** It was written without its colour index,
  so it showed as a grey dot in the panel and as a colourless custom tag in the Finder — and on a
  German system it did not merge with the "Rot" already on the file.
- **A file macOS itself calls hidden was shown** with "show hidden files" switched off: only the
  leading dot was consulted, never the `UF_HIDDEN` flag that `chflags hidden` sets.
- **The free-space display stopped at gigabytes** ("4096.0 GB" for a 4 TB volume) and wrote a decimal
  point whatever the language, next to a locale-aware number in the same status bar.
- **Copying file details to the clipboard broke the table** when a name contained a tab or a line
  break: six files came out as eight rows, with every column after the tab shifted.
- **`cd "Zwei Wörter"` did not work** while the unquoted form did — the quotes ended up inside the path.
- **The configuration files reformatted themselves.** The first save rewrote every line as `key=value`,
  including lines nobody had touched, in files documented as ones you edit by hand.
- **`F7` with `../name` created the folder outside the directory the panel was showing**, invisibly;
  `.` reported the parent back as newly created; a whitespace-only entry reported success and did
  nothing.
- **Two hard links to one file were listed as duplicates**, so the duplicate finder offered space that
  deleting one would not free.
- **An invalid regular expression in Find Files reported "no results"** rather than saying the pattern
  would not compile — indistinguishable from "the term is not in these files".
- **Verifying after a copy applied to foreground copies only**, and the background queue is what one
  picks for the large copies where verifying is worth the time.
- Spotlight searches now say which of your settings — regular expressions, depth limit, selection
  scope — the index could not apply.

### Added

- **A note can be about a line of a file**, not just about the file. The viewer offers the annotated
  lines in its marks panel and writes new ones for the line under the cursor; the note itself lives with
  all the others, so the overview and Find Files see it like any other.
- **The AI assistant can read and write a file's comment**, with a new **AI ▸ Suggest a comment**
  action. The plan it asks you to approve quotes the words it wants to attach.
- An authenticated proxy can finally be configured for FTP: the model and the ini always supported one,
  the dialog had no fields for it. The password goes to the Keychain like the site's own.

### Internal

- New gates in CI, each written after the defect that justified it: checksums and written archives
  against independent readers, every user-facing string against the catalogue, every test file against
  the project (four new test files had silently never run), and the VM harness flags — `tart` was
  opening a Screen Sharing window per run and never closing it; 136 had accumulated.
- 33 of the fixes above carry a test or a VM scenario that was verified by restoring the defect and
  watching it fail.

## [0.3.0] — 2026-08-05

### Added

- **Structure view for JSON, YAML and XML in the editor.** The symbol sidebar lists the keys of a JSON
  or YAML document and the elements of an XML one, nested as the document is; elements are named by
  their `id`, `name` or `key` attribute. A file that does not parse still gets an outline down to the
  point where it breaks. Covers the XML-based formats too — `.plist`, `.svg`, `.csproj`,
  `.storyboard`.
- **Structural navigation and selection** (Ctrl+Cmd with the arrow keys): out to the enclosing node, in
  to the first child, and between siblings — stepping over the whole block in between. Ctrl+Cmd+A
  selects the enclosing node and grows outwards on each press.
- **Copy Structural Path** (Ctrl+Cmd+C) puts the cursor's position on the clipboard in the notation the
  format's own tools take: `.services.web.ports[0]` for `jq`/`yq`, `//server[@id='web-1']/port` as an
  XPath. Keys that are not plain identifiers are quoted, because `.content-type` is a subtraction in
  `jq` and `."content-type"` is the key.
- **Validate Document** (Ctrl+Cmd+V) checks the file and puts the cursor *on the problem*. JSON and XML
  are checked by a real parser; YAML has none on the system, so the check covers what can be decided
  without one — a tab used to indent, indentation that lines up with nothing, a duplicate key, an
  unterminated quote — and says that it is not a full parse.
- **Two problems nothing else in the toolchain reports:** a duplicate key, which every JSON parser
  accepts silently while discarding one of the two values, and a trailing comma, which Apple's parser
  accepts and Python, Go and `jq` refuse.
- **Transformations:** minify to one line, sort keys recursively, escape/unescape as a JSON string, and
  JSON → YAML. Minifying keeps key order and the exact spelling of every number, since `1.0` and `1`
  are not the same version. There is deliberately no YAML → JSON: it needs a YAML parser the system
  does not have.
- **Folding.** Option+Cmd with the arrow keys collapses the node at the cursor, the whole top level, or
  restores everything. Nothing is removed from the document — the text is only not drawn, so saving,
  undo and Find are unaffected. The header line stays visible and is marked, the line numbers skip what
  is hidden, and a cursor placed inside a fold opens it.
- Uploading into an FTP or SFTP panel with F5, with resume (previously the remote path was handed to
  the local copy engine, which either failed or wrote to a same-named local path and reported success).
- Panels notice changes another program makes, through FSEvents rather than polling.
- ZIP64 archives can be read: entries and archives above 4 GB, and more than 65 535 entries.
- Editor: filter the selection through a shell command, line operations (sort, deduplicate, trim),
  line-ending conversion and awareness of a read-only file at open time rather than at save time.

### Changed

- The window's appearance is read from the configuration *before the first frame*: the first paint no
  longer shows the built-in defaults and then corrects itself.
- A `.json` file is reported as JSON in the status line, not as JavaScript.
- The caret is at the start of a file after opening it. It used to be left behind the text, so the
  breadcrumb described the last key in the file while line 1 was on screen.

### Fixed

- The structure parser hung on any document with more than 5 000 nodes — on a background thread,
  silently, in every large JSON file.
- SFTP downloads stream to disk and resume by seeking; they used to be assembled in memory from the
  start.
- Attribute changes over SFTP reach the server. The function that was supposed to apply them was empty
  while the dialog reported success.
- Remote file listings and the copy engine no longer disagree about which side is remote.
- Keyboard operation: `autorecalculatesKeyViewLoop` is false for every window created in code, so Tab
  reached almost nothing. Settings reached the page list and no further; Find Files could be filled in
  but not started.
- `.gitignore` matched `Tools/vm/fixtures/` as well as the generated `Fixtures/` at the root, so the VM
  harness's own fixtures were never committed.

## [0.2.0] — 2026-07-30

### Added

- Decompiler plugins for Java/Android and .NET, inside the Commander rather than beside it: a
  searchable tree for a whole JAR, APK or dex, two engines side by side, results cached on disk.
- A VM regression harness (`Tools/vm/regress.py`) that drives the real app over VNC, counts Auto Layout
  conflicts against a baseline of zero and photographs every standard view.
- Accessibility: labels for every list, tree and hand-drawn control, plus a per-window keyboard gate.
- 19 languages for the UI and the complete in-app Help Book.

### Fixed

- Every Auto Layout conflict in the standard views, measured rather than guessed.
- Search inside archives reaches the plugin.

## [0.1.0] — 2026-07-14

First public beta: dual-pane browsing, the file operation engine, archives, the viewer and editor, FTP,
plugins, and the settings.

[0.6.1]: https://github.com/hkiam/PeachCommander/releases/tag/v0.6.1
[0.6.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.6.0
[0.5.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.5.0
[0.4.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.4.0
[0.3.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.3.0
[0.2.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.2.0
[0.1.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.1.0
