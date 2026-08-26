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

The assistant is split in two. What ran on your Mac was a chat that could not read a file: measured
against Apple Intelligence, the thirty-two tools it offered the model cost 3442 of the model's 4096
tokens, leaving 473 for your question, the file and the answer together — so it answered in the wrong
language, mistook folders for files, and died on the second message telling you to start a new chat,
which changed nothing. That was the default every new reader landed on.

### Added

- **AI On-Device — five actions that do the work instead of talking about it.** Right-click a file and
  **Summarize**, **Explain**, **Suggest a name** or **Suggest a comment**; right-click the panel
  background and **Organize this folder**. Each one reads what it needs, shows you exactly what it
  proposes, and lets you untick anything you want left alone before a single file is touched. Nothing
  opens a chat, and the model is offered no tools at all — which is what leaves the whole context
  window for your file instead of for a list of things the model may call.

  **Suggest a name** and **Organize this folder** go through the same confirm-then-apply path as any
  other change, so both land in the assistant's action log and **Undo last change** takes them back.
  Renaming a marked selection is one step and one undo, not one per file. Organising asks once what
  folders the set needs and then sorts into those, because sorting file by file produced a folder
  named after the first file with everything else in it.

  It is a plugin and it arrives switched off, alongside the chat and the AI Column. If you had the
  assistant switched on and no cloud model configured, it is switched on for you once, with a note
  saying why.

- **Find by meaning.** Right-click the panel background and **AI ▸ Find by meaning**, describe what
  you are after — "the invoice about the roof" — and the folder is ranked by how close each file is
  to that. No model is involved: it compares meaning with on-device sentence embeddings, so it
  answers instantly and cannot invent a file that is not there. Pick a match to jump to it.

- **Organize** works on what you marked. Mark a few files and it tidies up those; mark nothing and
  it takes the folder, as before.

- **Suggested comments now set real Finder tags.** The tags were being glued onto the end of the
  comment text, where nothing could search or colour them. They are now the tags Finder and
  Spotlight see, added to whatever tags the file already had — and **Undo last change** puts the
  old set back, because the previous tags are recorded with the change.

- **Classify, and rename by what a file is.** Mark a few files and **AI ▸ Classify**: each one gets
  a topic, the date it actually states, and a category worked out across the whole selection — so an
  invoice and a receipt land in one category rather than each in its own. The answers fill three new
  panel columns, **AI Kind**, **AI Topic** and **AI Date**, and they are usable in a multi-rename
  mask: `[=ai_column.ai_topic]-[Y]-[M].[E]` renames a folder of `dokument1.pdf` files by what they
  are. Nothing new was built for that — the rename mask has always resolved `[=provider.field]`
  through the column system, so classifying once is what makes it work.

  A date is only taken when the document states a full one. Asked about "Reisenotizen Kreta, Sommer
  2023" the model offered 12 July 2023; a date invented in a file name outlives every chance of
  noticing it, so the text now has to contain the day and the year or the field stays empty.

- **Make a table** works without a chat, and saves. Put the cursor on a log, a measurement series
  or a badly exported CSV and pick **AI ▸ Make a table**: the columns come from the data's own
  names, the rows from the data, and **Save as CSV…** writes it beside the file — through the same
  confirmed, logged path as any other change. A decimal comma is quoted, so a German file survives
  being opened again as a spreadsheet.

  It reads the beginning of the file, not all of it, and the sheet says so when there is more. A
  few dozen rows is what fits; a database export is not what this is for.

- **Scans and screenshots are readable.** Apple Intelligence cannot see a picture — it takes text
  and nothing else — so the words are read off the image first, on your Mac, and the assistant works
  from those. Nothing new to learn: **Suggest a name** turns `scan_0042.png` into
  `rechnung_meier_2024_03_12.png`, **Classify** files it with the invoices rather than the photos,
  and **Make a table** reads a screenshot of a table back into columns. For a photograph with no
  words on it, what the picture appears to show is used instead.

- **Explain** stopped being a second name for **Summarize**. Summarize reads the whole file and
  folds it, which is right for prose; Explain reads the opening and answers "what is this and what
  would I use it for", which is the right question for a config file, a script or a data dump.

### Changed

- **The AI Assistant chat now needs a cloud model** — any OpenAI-compatible endpoint, which includes a
  local server such as Ollama or LM Studio, not only a paid service. The on-device chat is gone rather
  than fixed: it is the on-device *actions* that work, and pretending otherwise cost people their first
  impression of the feature. The **Settings ▸ AI** page now says which setting belongs to which half.

### Fixed

- **The AI Summary column never showed anything, for anyone.** The column and the assistant each
  worked out their own key for a file and disagreed on both halves of it — one counted seconds from
  2001 and the other from 1970, and they rounded the number differently — so no file ever matched.
  They now share one definition, and the summary appears as soon as an action has read the file.
- **Unticking a line in the assistant's plan did nothing.** 0.7.3 said you could agree to part of a
  plan; the ticks were drawn and collected and then thrown away, so everything ran regardless. They
  are now passed on, which is what that release promised.
- **The tests that use the real on-device model had never run.** The documented way to switch them on
  set a variable the test process could not see, so six checks reported as skipped in every run since
  they were written — including the one that would have caught the defect above.

## [0.7.3] — 2026-08-25

Markdown and HTML leave the core: both formats are now drawn by a plugin that renders
diagrams and mathematics on your Mac, on every surface that shows a file — the viewer, the preview
panel, Quick View and the gallery. Searching inside archives reaches every archive the app can open,
says what it could not read, and no longer leaves extracted copies behind. Amazon S3 joins the drives,
the assistant summarises whole files and looks through your disk for one, and the documentation
website stops reporting its readers to anyone.

### Added

- **Searching inside archives now means every archive the app can open.** Turning on **Search inside
  archives** used to descend into the zip family only, so a `.tar.gz` holding a config file with the
  search term reported nothing found — even though pressing Enter opens that same file. Search, the
  panel's Enter, unpack, Test Archive and archive reload now share one authority for "is this an
  archive and who opens it", so tar, tar.gz/tgz, 7z, rar, xz, zst, iso, cpio, squashfs, single-file
  `.gz` streams, split zips (`name.zip.001`) and anything a packer plugin or the **Extra archive
  extensions** setting adds are all searched wherever they are browsable. Two long-standing gaps
  closed with it: unpacking a plugin-only format (Alt+F9 on a 7z) used to fail with "select an
  archive first" on a file the panel opens happily, and reloading an archive could silently swap a
  plugin's mount for the built-in zip reader.
- **A search that could not look somewhere now says so.** Archives that were unreadable, encrypted,
  over the size ceiling or nested deeper than four levels used to be skipped in silence, which reads
  exactly like "the term is not in there". The status line now ends with how many were not searched.
- **Results found inside archives are usable.** F3 opened them with a beep and **Feed to Listbox**
  dropped them without a word; both now work, as does copying one out with F5, because a hit carries
  the archive chain it came from instead of a path string nothing could resolve.

- **Amazon S3 and S3-compatible storage as a drive.** **Net ▸ Amazon S3 Connect…** connects to Amazon
  S3, MinIO, Ceph, Cloudflare R2, Wasabi, Backblaze B2 or DigitalOcean Spaces, and the bucket list
  becomes the top level of a panel with each bucket a folder below it. Reading, writing, new folders
  and buckets, deleting, renaming and moving all work, and copies happen on the server rather than
  through your Mac. Profiles from the AWS command line are offered if you have them; secret keys go
  into the Keychain. A remembered connection becomes a chip in the drive bar that connects when you
  click it. **Storage Class** and **ETag** are available as panel columns.

  It is a plugin, so you can turn it off or remove it in **Configuration ▸ Plugins…**. The help topic
  **Amazon S3 and S3-compatible storage** describes what to expect of it — including that a bucket
  cannot be renamed, that an archived object must be restored before it can be read, and that unlike a
  disk, every request to a paid service costs money.

- **You can agree to part of the assistant's plan.** When a plan covers several files — renaming a
  folder full of them, clearing out your Downloads — each one is a ticked line above the buttons. Untick
  what you want left alone and press **Confirm & run**: the rest goes ahead and the unticked files are
  not touched. Until now the only answers were all and nothing, so wanting all-but-three meant rejecting
  the plan and describing the exception in words for the assistant to get right on a second try.
  Unticking everything is the same as cancelling, and it says so rather than reporting that it did
  nothing.

- **Ask the assistant to find a file and it looks through your whole disk.** *"Find the PDF invoice from
  last month"*, *"where are all my node_modules folders?"*, *"which file mentions the Aachen contract?"*
  — including words **inside** files, which the ordinary search can only do once you point it at a
  folder. It uses the index macOS already keeps, so there is nothing to build and no waiting for it to
  catch up, and it tells you where it looked: your home folder, the whole computer, or just the folder a
  panel is showing. Two honest limits: macOS keeps some places out of its index, so "nothing found" is
  not proof a file is absent, and a file created moments ago may not be indexed yet — **Find Files**
  walks the folders itself and will still see it.

- **One click puts one panel's folder in the other, and says which side.** **Go ▸ Left = Right** shows
  the right panel's folder on the left, **Go ▸ Right = Left** does the reverse, and both are on the
  button bar by default. *Target = source* (Ctrl+=) has always done this relative to whichever panel is
  active — which is the wrong shape for a button, because the same click then means two different
  things depending on where the focus happens to be. These name the side outright. An existing button
  bar gains the two buttons once; remove them and they stay removed.

- **The whole empty space at the right of a path bar opens the path for typing.** Not just the pencil,
  which is eighteen points wide. Clicking a folder in the breadcrumb still goes there, and the narrow
  gaps between folder names still do nothing, so a click that just misses a name is a miss rather than
  a mode change. A click on a path bar now also makes that panel the active one.

- **The assistant summarises a whole file, however long.** Its on-device model takes in a few
  thousand words at a time, so "summarise this report" failed outright on anything past about six
  kilobytes — measured on this machine: a four-kilobyte slice is answered, an eight-kilobyte one is
  refused, and the assistant was asking for sixty-four. It now reads a long file in slices and folds
  the slice summaries into one, so the length of a file costs time instead of failing. A 38 KB report
  comes back summarised, including what its last page says.

- **What the assistant did, and taking it back.** **Actions ▾** in the chat shows every change it
  made — what was asked of it, how it turned out, and the attempts the autonomy setting refused —
  and takes back the last change that has an inverse: a rename is renamed back, a move is moved back.
  Where nothing can be taken back the list says why, rather than offering a button that would lie.
  An external agent connected over MCP writes to the same log. You can also just ask the assistant
  to undo it.

- **An "AI ▸" action over a whole selection.** Mark forty files and the action runs over all of
  them, one after another, with progress in the status line; Stop ends the run between files. This
  is the part a two-panel file manager was missing: the assistant could only ever act on the file
  under the cursor.

- **Answers you can act on.** The chat renders the model's Markdown: a table is a table, a fenced
  block is a code block, a list is a list, and a path is clickable. *(Make a table* produces a
  well-formed Markdown table by construction, and the chat used to show it as rows of pipe
  characters.) **Suggest a name** now ends in a **Rename** button carrying the proposed name —
  pressing it is the approval, so nothing is asked twice.

- **Your own "AI ▸" actions.** What each action asks the model is a file you can edit
  (`aichat/skills.json`, `aichat/folder-skills.json`), written out with the built-in wording on
  first run — and an action you invent is a real command: name `plugin.ai.skill.<your-id>` in the
  user menu, on the button bar or on a keyboard shortcut and it runs. A plugin can now declare that
  a command family is open to ids it does not itself list, which is what makes this possible without
  the host having to load a plugin to find out what it offers. Name an id that does not exist and
  the assistant says so rather than doing nothing.

- **An AI Summary panel column.** It shows the first line of the summary for each file the assistant
  has already summarised, and stays empty for the rest — the column shows work already done and
  never starts a model itself. The plugin's other column, which detects a text file's language
  without any model, is now called **Language** rather than "AI Language".

- **The Git panel and its windows follow the colour scheme.** In every dark palette the Git panel in the
  side panel was a white rectangle with white labels on it; the history, blame, branches, conflict and rebase
  windows ignored the scheme entirely. They now take their colours from the app — and follow a change while
  they are open.

- **PDFs and Word documents render in the preview, with zoom.** The side panel's preview, Quick View and
  the info page now draw PDFs themselves — page by page, with the same zoom buttons a picture has (zoom in,
  zoom out, actual size, fit) — and show Word, OpenDocument and RTF documents as formatted, selectable text.
  Everything else is still previewed by macOS Quick Look. Reported as "PDF and DOCX are no longer rendered":
  what those formats went through before renders outside the application, where nothing inside it can tell a
  rendered page from a blank one — so this also makes the preview something that can be checked. If you
  prefer the system's preview for everything, switch *Render PDFs and documents in the preview* off in
  **Configuration ▸ Edit/View**.

- **Plugin column headers are translated, and can carry an icon.** *Git Status* and the other plugin columns
  showed English headers in every language; they now use the plugin's own translations — while your saved
  column sets keep working, because only the header changed and not the column's identity. Git's status
  column also shows a real icon next to the word instead of a text glyph.

- **Blame in the editor's gutter.** `Git ▸ Blame in the Editor` opens the file and writes who last touched
  each line next to the line numbers, with the commit, author, date and subject on hover; clicking a line
  opens that commit against its parent in the compare window. The mechanism is a new host service, so any
  plugin can annotate lines this way — coverage, a linter, anything per line.

- **The bundled plugins are the pitch now, not a footnote.** Seventeen plugins ship inside the
  app and the landing page said so in one run-on sentence, two thirds of the way down, under a
  heading about the SDK — while the feature card above it advertised the *ability* to write
  plugins rather than the fourteen that are switched on the moment you launch. There is now a
  showcase near the top: what each one does in a line, the three that are off by default marked
  as such, the plugins window as proof that every one of them is there and individually
  switchable, and Disk Map, Git and the Uninstaller shown rather than described. The SDK keeps
  its own section further down, where it belongs.

- **Card grids were choosing their column count by font size.** Every grid on the landing page
  used a `rem` track minimum, and Material sets `html { font-size: 125% }` — so 1rem is 20px on
  a default browser and was measured at 24px on another. A `minmax(14rem, …)` meant for three
  columns silently rendered two in an 826px content column. The minimums are in px now; the
  gaps stay in rem, because spacing should scale with type.

- **The terminal and the log viewer are shown, not just listed.** Two of the most visual bundled
  plugins had no screenshot anywhere. Both are captured now — the terminal with the shell sitting
  in the folder the panel above it shows, the log viewer with a service log colour-coded by level
  — and the showcase strip on the landing page carries five pictures instead of three. Both help
  pages embed theirs too, in all nineteen languages, so they are no longer the only plugin pages
  without a picture.

### Changed

- **The AI assistant now arrives switched off.** Turn it on in **Configuration ▸ Plugins…**; leave it
  off and nothing about it appears — no AI ▸ menu, no chat, no column. It is in beta, and it can rename,
  move and delete files and run shell commands for you, each behind a plan you approve. That is a lot of
  reach to hand a new feature by default, and it is the same standard the filesystem-image and
  decompiler plugins already ship under. Without an API key it works entirely on your Mac, so this is
  about the reach and not about anything leaving the machine. The **AI Column** plugin, which fills a
  panel column from the same model, arrives switched off with it.

- **Markdown and HTML are now drawn by a plugin, and can do much more.** Press F3 on a `.md` or
  `.html` file and you get nested lists, task lists with their boxes, tables with alignment,
  reference links and strikethrough — a real Markdown parser rather than an approximation. Diagrams
  written as ` ```mermaid ` blocks are drawn, and mathematics written between dollar signs is
  typeset. Both happen **on your Mac**: the engines ship inside the plugin, nothing is downloaded,
  and no part of your document is sent anywhere. A document with neither loads neither.

  The same rendering now appears in the **preview panel and Quick View**, so a preview and a full
  view of one file no longer disagree, and the **gallery** shows a small picture of a Markdown
  file's beginning instead of a generic icon. Apple's own Quick Look (Cmd+Y) is unchanged — that
  panel belongs to macOS.

  It is a plugin called **Markdown and HTML**, so you can switch it off in
  **Configuration ▸ Plugins…**; both formats then open as text, with the outline and syntax colouring
  intact. Its own settings page turns diagrams and mathematics on or off separately, sets the size
  above which a file opens as text, and says which engine version is in use and where it came from.
  If you need a different build of Mermaid or KaTeX, you can drop it in a folder and it is used
  instead.

  Two things it will not do, on purpose. A rendered page loads nothing over the network: an image
  whose address begins with `http` stays blank, because fetching it would tell that server when you
  opened the file. And a document's own scripts never run — HTML inside a Markdown file is shown as
  text, and an `.html` file is displayed with scripting switched off.

- **Code blocks in a rendered Markdown file are now coloured.** Press F3 on a `.md` file and the
  Rendered view keeps the language written on each fence — ```` ```swift ````, ```` ```python ```` —
  and colours comments, strings, numbers and keywords the way the editor does. A fence naming
  something the app has no lexer for, such as `mermaid`, stays a plain block rather than failing. The
  rendered page still loads nothing from the network.

- **The assistant is offered only the tools it is allowed to use.** Under "read-only" the write and
  delete tools are no longer offered and then refused: for a model with a few thousand tokens of
  context, a round of attempts that can only fail is the budget for the real answer. Memory
  (`remember`/`recall`) and the semantic search reached only the cloud path before — the on-device
  default, which is what most people run, had no memory at all.

- **"Which file is about X" finds it.** The semantic search ranked file *names* only, with an
  English-only embedding, so a German query fell back to counting shared words and the "semantic"
  part quietly did nothing. It now reads the beginning of each file too, follows the language of the
  query, and returns what is close to the best match instead of the whole folder.

- **A copy or a move is reported as done when it is done.** Both tools queued the transfer and
  returned immediately, so the assistant announced a copy before a byte had moved — and a plan of
  several steps ran against a queue that had not started. They now wait for the transfer, which is
  still an ordinary background job in the Transfer Manager.

- **Reading, hashing and searching no longer block the window.** The automation tools ran on the
  main thread, and "find duplicates" mapped every file into memory there. Hashing is streamed now,
  and the file-system tools run off the main actor.

- **A model change in Settings takes effect at once.** The chat kept the provider and the system
  prompt it was built with, so switching to a cloud model looked like it did nothing until the panel
  happened to be rebuilt.

- **The MCP server follows the autonomy setting.** It was fixed at "confirm changes", so "read-only"
  on the AI page held for the assistant in the window and not for an external agent on the socket —
  both of which are configured on that same page.

- **The Git menu reads like a menu.** Inside a submenu already called *Git*, every entry said "Git" again:
  `Git ▸ Git Status…`. The titles are now `Status…`, `Stage`, `Commit…`, `Push`, `Pull`, `Panel`, `Diff…`,
  `History…` next to `File History…`, `Branches, Stashes & Tags…` and `Blame (list)…` beside the new
  `Blame in the Editor` — and the entries are in a sensible order instead of the order they were added in.

### Fixed

- **Two libraries the app had started using were missing from its attributions.** The Markdown
  plugin's parser — Swift Markdown, and the cmark-gfm it is built on — were pinned as dependencies
  but named nowhere, so **Help ▸ Open Source & Third-Party Software…** did not list them and their
  licences were not shipped. Both are there now, with their full texts. The generator had been
  looking in one place for the licence files while these two are resolved into another, and it warned
  about exactly that on every build without anyone acting on the warning.

- **A large folder now fills in as it loads.** A directory with thousands of entries — a big folder on
  disk, an FTP or SFTP listing, an S3 bucket — showed an empty panel until the very last entry had
  arrived. The rows now appear as they come in. Navigating away while a folder is still loading no
  longer lets the slower listing win, and if a listing fails partway through, the panel goes back to
  showing the folder it was actually in rather than half of the one it could not open.

- **The same bytes now give the same answer inside an archive as on disk.** Content search stopped
  after 16 MB of an archive member while a loose file had no such limit, so a match further into an
  archived log was reported as no match at all. Members past that point are extracted and searched
  exactly as local files.
- **Searching no longer leaves extracted archives behind.** Descending into a nested archive wrote a
  temp directory that nothing ever removed; the extraction now belongs to the descent that made it,
  and an archive mount — built-in or plugin-backed — cleans up everything it extracted when it goes
  away. Anything earlier builds already left behind is cleared out at the next launch.
- **Opening an archive with many files in one folder is no longer quadratic.** A tar holding 20,000
  files in a single directory took 30 seconds to open — an unpacked source tree or a `node_modules`
  tarball is exactly that shape. Under three seconds now. This one is older than the archive-search
  work and surfaced only once its performance budgets were written.
- **A search says which archives it could not read, not just how many.** The new **Details…** button
  in Find Files lists each one with the reason: it could not be opened, it is password protected
  (the names inside were searched, the contents were not), it is larger than a search opens, or it
  is nested deeper than a search descends. The button stays hidden when a run had nothing to report.
- **A password-protected archive is reported instead of quietly passed over.** Its member names were
  always searched and its contents never were, and nothing said so.
- **A condition on the Plugins tab no longer discards every result found inside an archive.** The
  condition was checked against the result's displayed path, which for an archive hit is not a file,
  so those rows were dropped without a word as soon as any condition was set.
- **Editing a file inside an archive says so instead of losing the change.** F4 opened a copy that
  Save wrote into while the archive stayed as it was, and nothing said so. Copy the file out with F5
  and edit the copy. Editing over SFTP, FTP and WebDAV still writes back as before, and a branch view
  still edits the real file.
- **A long search can be stopped while it is opening an archive.** Cancelling checked only between
  archives, so a search that had just started on a large one had to see it through first.
- **Entering an archive twice no longer reads it twice.** An open archive is remembered — up to 32 of
  them, and only while they stay small enough to be worth remembering — so leaving one and going back
  in, or unpacking it afterwards, no longer re-reads the whole directory.
- **Reading a tar is no longer paid for in full.** The reader read whole files into memory before it
  could tell whether they were tars at all — so a large `.xz`, `.zst` or `.7z` was read cover to
  cover only to be handed on, and a `dump.sql.gz` was decompressed entirely before being rejected.
- **Images in an assistant answer are shown as images.** An answer pointing at a picture on your Mac
  used to print the Markdown for it, brackets and all. It now appears, scaled to the width of the chat.
  Only files on this Mac are shown: an image address on the internet is left as visible text and is
  never fetched, because loading one would tell that server when you read the answer.

- **The documentation website no longer tells anyone that you are reading it.** Every page used to
  fetch a font from Google and the repository's star count from GitHub, so opening a page reported
  it to two third parties — and none of the typography worked without a network. Both are gone; the
  site now uses the fonts your Mac already has. The only remaining request is the download button on
  the front page asking GitHub for the newest release, which cannot be known offline and still works
  without JavaScript.

- **`.mdx`, `.mkdn` and `.mdwn` files are now treated as Markdown everywhere.** Three places in the
  app disagreed about which extensions count: one of them gave `.mdx` an outline but would not render
  it, another rendered `.mkdn` but would not reformat it. All three read one list now.

- **Diagrams on the documentation website now render without an internet connection.** The
  architecture pages draw 34 diagrams, and the engine that draws them was fetched from a third-party
  CDN the moment a page was opened — so the diagrams were missing offline, and reading one told that
  CDN which page you were on. The engine now ships with the site.

- **Uploading to a server now shows progress and can be cancelled.** Copying files into an FTP,
  SFTP, WebDAV or plugin panel used to run with no progress window and nothing to press — for one
  large file, an application that looked hung — and reported only a count at the end. It now uses the
  same transfer window as a local copy, with Cancel, pause and the speed limit. On a plugin drive the
  bar moves within a single file; on FTP and SFTP it advances a file at a time.

- **A cancelled download no longer reports success.** Stopping a transfer on a plugin drive could
  report it as complete for a file that was never written.

- **Columns a plugin adds are no longer blank.** A plugin can contribute extra columns for its own
  entries — the Task Manager's CPU and PID, an S3 drive's storage class. For a drive whose name
  contains a dot, which is every server address, the column stayed empty however it was configured.

- **A plugin drive in the drive bar now connects when you click it.** A plugin that offers several
  saved connections showed one chip each, and clicking one opened the connection dialog instead of
  connecting — the chip looked like a shortcut and was not. It connects that saved connection
  directly now. If its password is no longer in the Keychain it says so, rather than quietly
  connecting without one.

- **Copying, creating a folder and renaming now work inside a mounted plugin drive.** On a WebDAV
  server — or any drive a plugin provides — three keys did the wrong thing quietly. F5 into the drive
  handed the remote path to the local copy engine, so the file was written to a same-named folder on
  this Mac and reported as copied. F7 created a local folder named after the remote path. F6 renamed
  nothing and blamed the files. All three now go to the server, and a failure says which item it
  happened to. Cancelling a transfer also reaches the plugin now, instead of being noticed after the
  last byte had already arrived.

- **Summarising a very long file no longer fails at the last step.** The assistant reads a long file in
  slices and combines the results; combining them was itself one request, and for a long enough file —
  or a talkative enough model — that request was too big for the on-device window. It failed only
  sometimes, and when it did the assistant reported it as though the *file* were the problem. The
  combining now happens in rounds, so it stays within the window however long the file is.

- **A folder that cannot be opened no longer moves the panel there.** Opening one that macOS keeps
  private, or that permissions refuse, used to leave the panel claiming to be in it: the tab and the
  path said the new folder, the path bar said the old one, and the file list belonged to neither. The
  folder was even written to the session, so the next launch started somewhere it could not read. The
  panel now stays where it was, and everything on screen agrees about where that is.

- **And it says why, when macOS is the reason.** A location such as your iOS device backups is visible,
  belongs to you, and its permissions say you may read it — and opening it is still refused, because
  macOS gates it on the *app* rather than on you. No amount of administrator rights helps, so "could
  not open" sent you looking for a permission that was never the problem. The panel now names it:
  *macOS keeps <folder> private — see Commands ▸ Full Disk Access…*.

- **`FEATURES.md` listed "Archives" twice.** One feature record of eighty-eight said
  `category: archives` where the rest say `archive`; the label table has no plural, so the
  generator fell back to capitalising the raw value — which produces the same heading the
  singular already produces. The record is fixed, and the generator now refuses a category that
  is not in the registry's own list instead of inventing a heading for it.

- **The other eighteen languages got the same site, and a front page.** The translated help
  was published as a flat list of twelve sections with a three-line stub for a landing page —
  seventeen of the eighteen languages had a heading and the name of their language, nothing
  else. They now have the same five tabs as the English site, named in their own language, and
  a real front page: the opening paragraph of that language's own introduction topic followed
  by every topic grouped the way the tabs group them. No prose was invented for it — all of it
  is text a translator already wrote.

- **Sixteen languages showed a stray English "Plugins" section in the in-app help.** Seven
  plugin topics sat under the translated word and six under the English one, because whoever
  added the later plugin pages copied the English `section:` along with them. Every reader of
  those sixteen languages saw two plugin sections in the Help Book, one of them untranslated.

- **The documentation site opened with the API reference.** The first two navigation entries
  were *API reference* and *Developer guide*; *Getting started* came third, and the user
  guide, the plugins and the tutorials were far below. Nobody had decided that: the site's
  navigation is derived from each page's `order:`, a section ranks by the lowest `order:` of
  its pages, four sections tied at `10` — and the tie fell to alphabetical directory order.
  The API reference won outright because its generator wrote `order: 5`, the smallest number
  in the corpus. The site now has seven tabs in reading order — Get started, Using Peach
  Commander, Customise, Plugins, Tutorials, Reference & help, Develop — with the twenty-one
  former sections as collapsible groups beneath them, so no more than a handful of entries
  is ever on screen at once. The API reference is in the last tab. The landing page opens
  with three doors instead of a wall of prose: coming from Total Commander, new to two-panel
  managers, or here to write a plugin.

  This is a website-only key, so the in-app Help Book keeps its own structure and is
  byte-for-byte unchanged, and the eighteen translated Help subsites are untouched.

- **A user help page was invisible on the website.** `help/filesystem-images.md` and
  `plugins/filesystem-images.md` declared the same slug. Pages are staged flat, so the
  developer page overwrote the user page while the navigation kept an entry for both — two
  titles, one file, and the user-facing Filesystem Images help was not published at all. The
  developer page is renamed, and a duplicate slug now stops the build instead of quietly
  winning. Also: the site said "MacOS & privacy" because section labels were auto-capitalised.

- **266 dead links in the shipped in-app help.** Seven topics link to each other as
  `](slug.md)`, which resolves on the website; an Apple Help Book bundle contains no Markdown
  at all, so every one of them was a dead href — fourteen links in each of the nineteen
  languages. The table of contents was always correct, which is why nothing looked wrong from
  the outside.

- **Toggling hidden files could kill the app, and switching panels showed the wrong thing first.**
  Both commands ran their handler on a background thread and reached straight into AppKit from there:
  `cm_SwitchHidSys` called `NSTableView.reloadData` while the main thread was drawing, and AppKit's
  layout engine raised an exception nobody catches — an abort, mid-session, with the panel already
  showing the wrong directory for a while beforehand through `cm_SwitchPanel`. The cause was one
  annotation that does less than it reads like: `CommandHandler` is a `@MainActor` function type, but
  that only isolates the closure *literals* written at a `handler:` argument. A reference to a
  separately declared `func` keeps its own isolation, so all 37 named `cm_*_handler` functions were
  running wherever the command registry's continuation happened to be. They are main-actor-isolated
  in their own right now, and `WindowControllerProtocol` says so too, so the compiler will hold the
  rule instead of a comment claiming it. `Tools/check-command-handler-isolation.py` is the gate: the
  build could not catch this one, because the project compiles in the Swift 5 language mode and the
  conformance that crashed produced no warning at all.

- **Two panel properties and two macOS callbacks crossed the same boundary.**
  `PanelControllerProtocol` looked safe because its methods are `async` — an async witness hops — but
  it also had three synchronous `var` requirements that did not. `NSServicesMenuRequestor` and
  `QLPreviewPanelDataSource` are ObjC protocols with no isolation of their own, so their witnesses
  now assert the main thread they are actually called on rather than assuming it quietly.

- **A crash used to make the next automated run hang instead of report.** The launch-time crash-report
  prompt and the Full Disk Access prompt are both modal, and a modal owns the main queue an automation
  script is driven from: the script ran on inside the nested runloop, wrote its files, and then never
  quit. Both are skipped under `-AutomationScript`. The crash watermark is deliberately left alone, so
  the report still greets the user on their next ordinary launch.

## [0.7.2] — 2026-08-19

The Git plugin, from a first pass into something worth reaching for — and the host change that
made the last of it possible.

### Added

- **The Git plugin grew from two columns and five commands into something worth reaching for.** A
  **panel** with the working tree's changes, staging, unstaging, discarding and committing (amend
  included), and any file's diff opening in the app's own compare window — no second diff
  implementation. A **history** window: commits with a lane graph, what each one changed, a diff per
  file, and the same window for one file's history. **Blame** as a table, each line's commit openable
  as a diff. **Branches and stashes**: switch, create, merge, delete, stash push/pop/drop, and
  fetch/pull/push that can be cancelled instead of appearing to hang — credentials are left entirely to
  the SSH agent and git's own credential helper, and a conflicted file opens as *ours* against *theirs*.
  **`.gitignore` from the context menu** (this file, this file type, this folder), and **revert** or
  **cherry-pick** a commit from the history window, each refusing up front when the working tree is not
  clean rather than stopping half-way through.

- **Tags.** The Branches window has a third list: create a tag (typing a message makes it annotated),
  delete it, switch to it — with a plain warning that a tag is not a branch and HEAD ends up detached — and
  **push a tag**, which is its own action because `git push` does not carry tags. Previously the plugin
  showed branches and stashes and no tags at all.

- **The history shows where the branches and tags are.** A commit row now names the refs pointing at it:
  `● main`, `↗ origin/main`, `⚑ v1.0`.

- **Right-click, Return and Cmd+R work in every Git window.** Each list has a context menu with its own
  actions, right-clicking selects the row under the cursor first, Return does what a double-click does, and
  Cmd+R reloads — a commit made in a terminal used to leave a Git window quietly out of date with no way to
  refresh it. You can also copy what these windows are actually asked for: a commit hash, a subject, a file
  path, a blamed line, a branch or tag name. And Push/Pull are in the Git panel, next to the commit.

- **Tidy up the commits you have not pushed yet.** `Rebase…` lists the commits ahead of the upstream and
  lets you squash, fix up, drop, reorder or reword them, then rewrites the branch — with a plain refusal
  when something is in the way (uncommitted changes, an open conflict, no upstream) instead of git's
  terminal wording. If a rebase stops in a conflict, the same window becomes Continue / Skip / Abort, so a
  half-finished branch is not something you have to finish in a terminal.

- **A conflict can now be resolved in the app.** `Resolve Conflict…` used to show *ours* against *theirs*
  and leave the conflict markers in the file — the actual resolution happened somewhere else. It now opens
  a list of the file's conflicted regions with a decision per region (take ours, take theirs, take both,
  leave open), writes the file and stages it. It refuses to stage while a region is still open, because
  git will happily commit `<<<<<<<`, and it refuses to touch a file whose markers it cannot read rather
  than guessing at them. Not a merge editor: for a region that needs both sides interleaved by hand, the
  editor is one button away.

- **A plugin command that talks to the network no longer freezes the window.** A plugin can now declare a
  command long-running; the app then runs it in the background, shows a small progress window with the
  command's own output, and lets you cancel it — which actually stops the work rather than just closing the
  window. Git's Push and Pull use it: an unreachable server used to lock the whole application up for as
  long as the network took to give up.

- **A push that fails for want of a password now has somewhere to look.** `Credentials…` says what this
  repository authenticates with — SSH or HTTPS, whether a credential helper is configured, whether an SSH
  agent is running and actually holds a key — and offers one action: let git keep credentials in the macOS
  Keychain. The plugin never asks for, shows or stores a passphrase; it configures git's own helper and
  otherwise points at the SSH agent.

- **"Open on the Web" for a file, a commit or a branch.** Built from the remote's URL — GitHub, GitLab,
  Bitbucket, Azure DevOps — with no API, no token and no account. A file link points at the branch your
  colleagues can actually see. For a host whose link layout is unknown it offers the repository page rather
  than guessing at a URL that would 404.

### Fixed

- **A summary of a German file is in German.** `summarize_file` folds a long file through prompts
  of its own, and those were written in English — so a German report was summarised in English four
  times out of four, and the assistant relayed that to a user who had asked in German. The file's
  language is now detected and named in those prompts (naming it is what this model follows;
  "answer in the same language as the text" did not work at all). Four of four in German afterwards.

- **A long read is no longer cut off as "too slow".** The chat gives a turn two minutes before it
  frees the interface, which is right for a model that has hung and wrong for one reading a
  40-kilobyte file section by section. Progress now re-arms that timer, and the status line counts
  the sections ("reading section 3 of 10…") instead of showing an unchanging spinner. While there:
  writing a file, merging files and setting a comment reported "working…" rather than "preparing
  changes…", and the entry for inspecting a file never matched at all — it named a tool that had
  been renamed.

- **The assistant's messages say what actually went wrong, in your language.** Every failure of the
  on-device model produced one sentence about an invalid tool call, whatever had happened, and only
  in English. A full context window now says to start a new chat, a model still downloading says so,
  and each message is translated like the rest of the application. A conversation that fills the
  window is folded into a summary and continues instead of ending.

- **The assistant no longer refuses a plain question with the wrong reason.** Asked "um was geht die aktuell
  markierte Datei?", the on-device assistant answered "the on-device model produced an invalid tool call" and
  suggested rephrasing — advice that could not help, because the model had rejected the *input* before ever
  choosing a tool. Every message the assistant sends carries a context header naming the active folder, and
  Apple's on-device model screens what it is given: a header dominated by an opaque path — a temp folder, a
  UUID- or hash-named directory — does not read as natural language and the whole turn is refused. The retry
  then resent exactly the same text, so it failed identically. A rejected turn is now retried with the paths
  in that header reduced to plain names, which the model accepts and answers from (measured on the on-device
  model: five of five, where dropping the header wholesale was accepted but answered none). The remaining
  failure kinds each say what actually happened — a full context window asks you to start a new chat, a model
  still downloading says so — and the real cause is now written to the system log in every build, not only in
  debug ones, which is what made this diagnosable at all.

- **The Git status column no longer lies inside a linked worktree or a submodule.** There `.git` is a
  file rather than a directory, so the plugin was watching an index file that does not exist: a commit or
  a `git add` made outside the app reached the column only after a delay. It now asks git where its
  directory really is. The column also leads with a small glyph — `● Modified`, `⚠ Conflict`,
  `? Untracked` — so a listing can be scanned rather than read.

- **A Git plugin window drew its content in a narrow strip down the middle.** An 820-point window held
  a 436-point commit list, with the header floating in the centre. All four windows now fill.

## [0.7.1] — 2026-08-18

A round of reported defects, four of which were losing something rather than merely looking wrong.

### Fixed

- **A Total Commander menu file (`.mnu`) now actually loads.** It was read as strict UTF-8, so a file
  written on Windows — ANSI, or UTF-16 with a BOM — failed to decode, and the app could not tell that
  apart from "there is no menu file": you got the built-in menu and no explanation. Windows line endings
  were the second half; a CRLF file parsed as a single empty menu. The same two fixes apply to `.bar`
  button bars, `usercmd.ini` and the `wincmd.ini` import, which reported "the file could not be read" for
  perfectly good files. Beyond that: an `em_` entry in a menu file now runs its user command (that is the
  only way a `%P`/`%N` parameter reaches a menu entry, and it did nothing at all), a command this app does
  not have is greyed out instead of looking live and swallowing the click, and your own Start-menu entries
  survive a custom menu file instead of being replaced.

- **A CSV or TSV whose first line is data keeps that line.** It was always taken as the column titles, so
  the first record vanished from the table — you could not filter, sort or find it. The first line is now
  guessed, and a checkbox beside the filter bar overrules the guess either way.

- **JSON Lines files (`.jsonl`, `.ndjson`) are no longer reported as broken.** The structure check handed
  the whole file to a JSON parser, which stops at the second record — so every valid JSON Lines file failed
  it. Each record is checked on its own now, and a bad one is named by its line. Formatting works on them
  too, one record per line, which is what the format is; the outline lists records by the line they start
  on.

- **Formatting a large file no longer freezes the window.** Pressing Format on a 2 MB log with very long
  lines locked the app up for minutes at a time while scrolling: the code view converted character
  positions to text offsets by re-copying the line for every syntax token. Building thirty lines of such a
  file took over three minutes and now takes a tenth of a second. Formatted output also respects the size
  limits the normal Code view has, instead of always using the heaviest one.

- **Files in a firmware image no longer show 0 bytes when they have content.** In cpio and initramfs
  images, a hardlinked file (busybox under thirty names, typically) carries its bytes with the last link;
  the earlier ones were listed as empty while opening them showed the whole file. The size shown is the
  real one now — which is what the status bar totals, what a copy's progress is measured against and what
  "select files larger than" uses.

- **The symbol outline works on a rendered Markdown document.** In the viewer it could not even be opened
  for Markdown, which is the one representation Markdown is normally read in; picking a heading now scrolls
  the page to it. Underlined headings (`Title` over `===`) are drawn as headings rather than as a paragraph
  followed by a line.

- **Esc closes the viewer again** once you have clicked into its content, and **Del in a text field no
  longer offers to delete the file under the panel's cursor** — that also covered F2…F7 and Shift+F8, the
  last of which deletes without the Trash. Switching the theme to **System** no longer keeps the dark
  palette until the next launch, and changing it no longer throws the Settings window back to the first
  page.

- **A plugin that crashes no longer takes the app down.** The guard caught the four ways C code fails and
  none of the ways Swift does.

### Added

- **A symbol outline for twenty more languages**, Swift among them — the sidebar was empty and its button
  dead for everything without a bundled grammar: Swift, Go, Kotlin, Scala, Dart, C++, Objective-C, PHP,
  Ruby, Perl, Lua, shell, SQL, CSS and more, plus Markdown headings and the HTML element tree.

- **The Find dialog remembers what you searched for** — the last 20 entries per field, most recent first,
  emptied on request — and a text search **continues in the viewer**: opening a hit no longer comes up at
  the top of the file with an empty search box. The tick box in front of "Find text" is gone; the field
  decides.

- **Search the settings by name.** A search field above both columns of the Settings window finds an option
  across all sixteen pages and the plugins', shows which page it lives on, and takes you there with the
  control highlighted.

## [0.7.0] — 2026-08-16

### Added

- **Filesystem images open like archives.** Put the cursor on a `rootfs.squashfs`, an SD-card dump or
  a firmware file, press Enter, and the panel is inside it — the lister, the search and copying all
  work as they do in a folder. SquashFS, ext2/3/4, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT12/16/32,
  exFAT and NTFS are read, and a disk image with an MBR or GPT partition table lists one folder per
  partition. Nothing is ever written to an image. The plugin ships **switched off**: turn it on under
  Settings ▸ Plugins if you examine device images.

- **Firmware with no partition table is taken apart.** A file pulled off a router or a camera is
  usually a vendor header, a bootloader, a kernel and a rootfs written one after another at offsets
  recorded nowhere — such a file used to be refused. It now opens as one entry per part, each named by
  the offset it starts at: `0x00230044-squashfs` is a filesystem to step into, `0x00030040-kernel.uimage`
  a file to copy out. The parts are found by searching for the filesystems themselves and confirming
  each by opening it, so a byte pattern that matched by chance is discarded instead of becoming an
  invented entry, and a file holding no filesystem is still declined and opens as it always would have.

- **The space outside the partitions is listed too.** A Raspberry Pi keeps its bootloader in the
  megabytes ahead of partition 1, and U-Boot on most ARM boards at a fixed offset in the same unclaimed
  space. Those runs now appear beside the partitions and can be copied out, instead of an image that
  plainly contains a bootloader appearing not to.

- **Commands ▸ Scan Image Layout.** Writes what the scan found as a text file beside the image and puts
  the cursor on it: every region with its offset, its size and what it turned out to be, plus the
  partition table if there is one. That table is usually what a teardown or a ticket actually wants,
  and rebuilding it by walking a panel and copying numbers by hand is tedious.

### Fixed

- **A crashing plugin written in Swift now stops at the plugin, not at the app.** The in-process crash
  guard caught the four faults C code raises and none of the ways Swift fails — an integer overflow, an
  index out of range, a nil force-unwrap and `fatalError` all arrive as a different signal, which the
  guard passed straight through. Every plugin in Peach Commander is written in Swift, so the guard was
  covering the rare case and missing the common one: such a plugin took the whole app down exactly as
  if there were no guard at all. It is now caught, the plugin is quarantined for the session, and the
  app carries on.

## [0.6.4] — 2026-08-15

### Added

- **Arithmetic in "Go to".** The viewer's Ctrl+G, the hex editor, the binary compare and the editor's
  Go to Line now take an expression instead of a single number: `0x1000 + 15 + 1` goes to 4112. Bases
  mix freely in one line — `0x…`, `$…`, `…h`, `0b…`, `0o…` and decimal — with `+ - * /`, parentheses
  and `_` to group digits. A result that would be negative, overflow or divide by zero is refused
  rather than quietly turned into 0.

- **A global history, on Ctrl+Cmd+H.** One window that remembers where you have been and what you
  did: folders visited, files opened, copies and moves carried out, commands run. It opens with the
  search field focused, matches loosely as you type (`proj rep` finds `~/Projects/annual-report.txt`),
  and ranks by how recently *and* how often you used something. Arrow keys move, Return opens,
  Option+Return shows the entry in the panel, Tab switches which panel that is, Cmd+1…Cmd+9 open the
  most relevant entries directly, Cmd+P pins, Cmd+Delete removes. A copy or move can be run again
  from the list; a delete or a rename never is — Return shows you where it happened instead. Filters
  for folders, files, operations and favorites are on Option+1…Option+5. The list survives restarts,
  and Settings ▸ Misc sets its size and after how many days entries are forgotten. Not Cmd+Shift+H,
  which is already Go ▸ Home.

### Fixed

- **Packing a zip no longer needs 7-Zip installed.** Zip and 7z both handed the work to a `7z` binary,
  which macOS does not ship — so the most ordinary choice in the Pack dialog failed on a clean Mac. A
  plain zip is now written by Peach Commander itself. A password or split volumes still need 7z, and say
  so, and so does anything over 512 MB.
- **Tab reached only half the window.** With the preview panel or the folder tree switched on — and after
  every launch, whatever the layout — the Tab order stopped at the left panel: the right panel, the command
  line and the whole function-key bar could not be reached from the keyboard. Three separate causes, all
  fixed; the window is fully Tab-navigable again.
- **Extracting into a temporary folder did nothing.** The rule that keeps a crafted archive member from
  writing outside the folder you picked was refusing *every* write under `/private` — which includes
  `/var/folders/…`, the temporary directory macOS hands every app. The extraction reported success and
  produced no files. Both sides of that comparison are now resolved the same way.
- **Copy and paste in the viewer's and hex editor's dialogs.** In the hex editor's "Go to Address"
  field, Cmd+C copied the file's bytes and Cmd+V did nothing at all: those windows install their own
  menu bar, took Cmd+C for a document action and listed no Cut or Paste whatsoever. A field being
  edited now gets the key, the missing items are there, and the dialogs of both windows are sheets —
  so they appear over the window they belong to instead of freezing the app.

## [0.6.3] — 2026-08-14

### Added

- **Find empty folders.** Search ▸ "Only empty folders" lists the directories that hold nothing —
  and only those. A folder containing just a hidden `.DS_Store` counts as empty, because that is
  what you meant. Settings the search cannot use in this mode are greyed out rather than accepted
  and ignored.
- **The quick search in the file list is visible now.** Typing to jump to a file always worked and
  showed nothing, so a mistyped letter looked like the cursor had simply stopped moving. The prefix
  now appears with a match count — `⌕ re  1/3` — Backspace shortens it instead of leaving the
  folder, and Esc ends it. Red means nothing matches.
- **Order and speed per transfer.** Waiting jobs can be moved up and down the queue, and each job
  has its own speed limit: hold a large copy to 1 MB/s while a small one goes at full speed, and
  change it while it runs. A running or paused job stays where it is — the queue reorders around it.
- **Regular expressions in the viewer and the editor.** The viewer searches patterns over a file of
  any size without loading it. The editor gets pattern search *and* replace, with capture groups in
  the replacement (`(\w+) (\d+)` → `$2=$1`), optionally within the selection only, and the whole
  replacement undoes in one step. `^` and `$` match line boundaries, as everywhere else.

### Fixed

- **A busy SFTP server no longer leaves the app unquittable.** An SFTP session had no timeout
  anywhere: a server that accepted the connection and then stopped answering left the session
  waiting for ever, so the connection could not even be hung up — and because quitting waits for
  open connections to close, the whole application then refused to quit and had to be force-quit.
  Operations are bounded now, ⏏ works on a dead connection, and quitting gives up after three
  seconds. (Browsing the other panel always kept working, and still does.)
- **A lost connection says so, instead of looking like a hang.** A failed listing was written to
  the log and nowhere else, so the panel simply sat there. Worse, a connection dying mid-listing was
  reported as "not found" — the directory is right where you left it. The panel now leaves a dead
  mount, its drive button disappears, and a message says which server went away.
- **New SSH servers ask before they are trusted.** Connecting to an SFTP server for the first time
  used to append its key to `~/.ssh/known_hosts` silently. It now shows the key's fingerprint, in
  the same `SHA256:…` form `ssh-keygen` prints, and records it only if you agree. A key that has
  *changed* is still refused outright.
- **The quick search indicator was always red**, whatever matched, because it used the colour meant
  for marked files.
- **Saved searches would have been lost** the next time a search option was added: the whole file
  was discarded if a single field was missing, and the failure was silent.

### Plugins

- **Plugins are told where the configuration is.** `PfxInit` — documented in the SDK since the
  beginning and never actually called by the host — is now called, and host services gained
  `getContext`, which answers `"configRoot"`. A plugin that keeps settings can follow the host when
  it is pointed at a different configuration directory, instead of writing into the real one during
  a test run. Existing plugins keep working: the field is appended, and an older plugin never looks
  at it.

## [0.6.2] — 2026-08-13

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

- **An open connection is a drive of its own now.** Connecting to an FTP, SFTP or WebDAV server used
  to leave the drive bar showing your startup disk as the current one, with the tab titled "/" — the
  panel was on a remote server and nothing on screen said so. A connection now gets its own button in
  the drive bar for as long as it lasts: click it from either panel to go back to that server, and
  right-click it to disconnect. Walking up out of the mount, the Disconnect command and quitting the
  app all hang the connection up properly as well.
- **The keyboard-shortcut recorder took no keys at all.** Configuration ▸ Edit Shortcuts ▸ Record put
  up a sheet asking for a key and then ignored every one of them, Esc included, so the only way out
  was to quit. It records again, ⌘ combinations included — those used to run the menu command instead
  of being captured — and the "reassigned" note no longer appears on top of a sheet that is still
  asking for a key.
- **The connection dialog no longer offers settings that cannot work.** Switching a site from FTP to
  SFTP left port 21 in the field, so it could not connect. "Anonymous" and passive mode stayed
  available for SFTP, which has neither; a proxy could be set on an FTPS site that cannot use one; and
  an HTTP proxy was offered for FTP and then spoken to as if it were SOCKS5. Settings that do not
  apply to the chosen protocol are greyed out, the port follows the protocol unless you typed one
  yourself, and whatever is left that cannot work is named in the dialog instead of surfacing later as
  a connection error.
- **A plugin drive can be disconnected like any other connection.** "FTP Disconnect" did nothing at
  all on a WebDAV or Task Manager mount, and a plugin was never told to close its connection when the
  app quit — it was simply killed with the connection still open.

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
- **A filter you can aim.** In the process list the quick filter searches the columns as well as the
  name, and a term can say which column it means: `user:root state:R` asks what root is running right
  now. Terms are separated by spaces and all of them have to match. Text that names no column behaves
  exactly as before — one plain search, spaces and all — and the filter indicator now shows how many
  rows survived out of how many.
- **The State column says something again.** It reported "R" for practically every process, because
  that is all modern macOS puts in the field this plugin was reading. It now shows what `ps` shows —
  sleeping, running, stopped, zombie, with the usual suffixes for session leaders and foreground
  processes.
- **Find out which processes have a file open.** The Task Manager drive could tell you which process
  was sitting on a TCP/UDP port, but not which one was holding the file you were trying to replace.
  Right-click in the process list, choose *Find Processes by File…*, and every process with that file
  open is coloured by how it holds it: one colour for reading, one for writing, one for both. The path
  is prefilled from the cursor in the other panel, and the cursor jumps to the first process that can
  change the file. *Clear File Highlight* removes the colours; leaving the process list removes them
  too. As with the port search, other users' processes need elevated privileges to inspect.

- **SFTP with a key of your own.** The connection dialog has a key-file field (with a chooser that
  starts in ~/.ssh), and the password field becomes a passphrase field when a key is named — so an
  encrypted key, or a key kept somewhere other than ~/.ssh, can be used at all. An ssh-agent and the
  usual ~/.ssh/id_* keys worked before and still do without any setting. A key file that is not there
  is refused with a clear message rather than silently falling back to a different key.
- **Servers that do not speak UTF-8.** A site can be set to latin-1, and that setting is finally read:
  names in listings are decoded that way *and* sent back that way. Before, it round-tripped through
  the configuration file and reached nothing, so names on such a server came out as mojibake — and a
  name the panel cannot spell is one it cannot open, rename or delete either.
- **A site can open a local folder beside it.** The "Local dir" of a connection opens in the other
  panel when you connect — the pairing a transfer wants. This too had been stored and ignored.

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

[0.6.2]: https://github.com/hkiam/PeachCommander/releases/tag/v0.6.2
[0.6.1]: https://github.com/hkiam/PeachCommander/releases/tag/v0.6.1
[0.6.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.6.0
[0.5.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.5.0
[0.4.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.4.0
[0.3.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.3.0
[0.2.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.2.0
[0.1.0]: https://github.com/hkiam/PeachCommander/releases/tag/v0.1.0
