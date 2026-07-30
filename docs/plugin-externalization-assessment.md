# Plugin Externalization — Assessment & Staged Plan

## ⚠️ CORRECTION (supersedes the "in-process decision" below)

The target is **true external plugin bundles** loaded at runtime — like
`Plugins/SampleCSVLister` (a separately-`swiftc`-built `.plxplugin` with a C-ABI
`@_cdecl` surface, `dlopen`ed by the host, managed via Configuration ▸ Plugins…:
add / enable / disable / remove at runtime, separately versionable). The goal is a
**slimmer core** with special tools **out of the app target entirely**, behind a
**powerful, robust, version-independent C-ABI**.

My S1–S3 realized the tools as **in-process** Swift protocols still compiled into
the app — that does NOT meet the goal and must be reworked. What is reused, not
wasted: the `ToolPlugin`/`FileSystemPlugin` protocols become the **host-side
adapter** — when the host `dlopen`s a `.ptxplugin`/`.pfxplugin`, it wraps the C
entry points in a `ToolPlugin`/`FileSystemPlugin` so the rest of the app is
unchanged. The concrete in-process tool implementations (`UninstallerToolPlugin`,
`WebDAVFileSystemPlugin`, `ICloudFileSystemPlugin`, `LogViewerToolPlugin`) and the
tools' logic (`AppUninstaller`, `AppUninstallerWindowController`,
`WebDAVFileSystem`, `LogViewerWindowController`) must **move out of the app target
into their plugin bundles** and be deleted from the core.

### Revised steps (true external bundles)
For each tool: (a) define/extend the C-ABI header in `Plugins/SDK`; (b) add the
host loader (PluginType case, symbol table, a typed wrapper like `PLXLister`, and
an adapter to the `ToolPlugin`/`FileSystemPlugin` protocol); (c) create the
`Plugins/<Name>` bundle (Swift `@_cdecl`, its own copy of the logic) + a build
script; (d) **remove** the tool's code from the app target; (e) discover+load it
via `PluginManager`, show it in the Plugins dialog; (f) verify runtime
enable/disable/remove + parity.

Order: **PTX C-ABI first** (`ptx.h`), then Uninstall → `Uninstaller.ptxplugin`;
then PFX C-ABI (`pfx.h`) + WebDAV/iCloud bundles; then Log-Viewer
(`.ptxplugin` returning an `NSView*`/window); then Git/RAR/7z/zst/Treemap.

The C-ABI (C structs + `@convention(c)` functions + `PcGetApiVersion`) is the
version-independent contract — exactly the existing PCX/PLX/PDX model.

---
_(Historical assessment below — the "in-process" decision is superseded by the
correction above.)_


Goal (user directive): move hard-wired first-party tools out of the core and make
them **external plugins via the API + SDK**. Extract, in order, without functional
loss and with ideal non-functional properties (performance, memory), cleaning the
core as we go: **1) Uninstall Application, 2) WebDAV + Cloud, 3) Log Viewer**, then
Git / RAR / 7z / zst / Treemap.

## 1. Current plugin API/SDK — what exists

- **Host** (`PCPluginHost`): loads macOS bundle plugins by `dlopen(RTLD_LOCAL|
  RTLD_NOW)` + `dlsym` into a symbol table, with a `PcGetApiVersion` handshake
  (`PluginLibrary`). Manager UI + enable/disable + associations exist.
- **SDK** (`Plugins/SDK`): headers `pc_common.h`, `pcx.h`, `plx.h`, `pdx.h`;
  `PORTING.md`. Samples: `SamplePacker` (C), `SampleLister` (C), `SampleCSVLister`
  (**Swift**, returns a real `NSView*`), `SampleContentPlugin` (C).
- **Types** (`PluginType`): `pcx/pfx/plx/pdx` ↔ TC `wcx/wfx/wlx/wdx`.
- **Swift plugins work**: `SampleCSVLister` is a Swift `.plxplugin` with `@_cdecl`
  entry points — so first-party tools can be plugins **in Swift** (native AppKit),
  no loss of ergonomics.

### Gaps
- **No `pfx.h` / PFX host adapter** — the file-system (WFX) plugin API is not
  implemented (F-232). Needed for WebDAV/Cloud as a plugin.
- **No action/tool plugin type** — nothing expresses "run an operation on the
  selection" (Uninstall) or "open a tool window/panel" (Log Viewer, Treemap).
  TC itself has **no** such type (its only action extensibility is the Start
  menu = launch external programs). So this is a **novel, custom extension**.

## 2. Per-tool mapping + TC comparison

| Tool | Nature | TC analog | Needed API |
|---|---|---|---|
| **WebDAV / Cloud** | file system | **WFX** ✓ | **PFX** (port WFX): `FsInit`, `FsFindFirst/Next/Close`, `FsGetFile/PutFile`, `FsRenMovFile`, `FsDeleteFile`, `FsMkDir`, `FsDisconnect`, `FsStatusInfo`; host adapter → `VirtualFileSystem`, mounted under a "Network" root. |
| **Uninstall Application** | action on selection | none | **PTX** (new "tool/action" type): declare actions (title, applies-to predicate), `ToolExecute(selection, host)` with host callbacks (enumerate related files, stage delete via op engine, progress/log). |
| **Log Viewer** | tool window/panel | none | **PTX panel variant**: `ToolMakeView() -> NSView*` (like PLX's `ListLoad`) shown in a host window/sidebar; host feeds it a log stream. |
| **Git** | status column + actions | WDX (status as column) + PTX (add/commit/push/pull actions) | PDX (already exists) for the status column + **PTX** for the actions. |
| **RAR / 7z / zst** | archive (un)packers | **WCX** ✓ | **PCX** (already exists) — bundle a packer plugin per format (libarchive/libzstd inside the plugin). No core API change. |
| **Treemap** | tool window | none | **PTX panel variant** (same as Log Viewer) + read-only VFS walk via host callback. |

**Conclusion:** the API/SDK does **not** suffice today. Two extensions are
required: **(A) PFX** (a straight WFX port — TC precedent exists) and **(B) PTX**,
a *new* "tool/action + panel" plugin type with **no TC precedent** (custom
extension, as the directive anticipates). PCX/PDX already cover RAR/7z and the Git
status column.

## 3. Non-functional analysis (ideal solution)

- **Keep the host-side seams native.** The core already has `VirtualFileSystem`
  (PFX adapter target), `CloudProviderRegistry`, and `CleanupProvider`. Plugins
  should be **thin**: a PFX plugin produces a `VirtualFileSystem`; a PTX action
  plugin implements `CleanupProvider`-like work through host callbacks. This keeps
  hot paths (listing, copy) in native Swift — no per-file ABI marshalling in the
  inner loop beyond what WFX inherently needs.
- **Write first-party plugins in Swift** (proven by SampleCSVLister) so there is
  **no functional loss** and the AppKit UI stays native.
- **Lazy load**: plugins `dlopen` on first use (already the host model), so idle
  memory/CPU cost is ~zero when a tool isn't used — better than the current
  always-linked code.
- **In-process** (ADR-004): no IPC overhead; crash-guard logging already planned.

## 4. Staged plan (no functional loss; clean the core each step)

Each step follows the same safe pattern:
1. Ensure the tool is already behind a host **seam/protocol** (refactor if not).
2. Implement/extend the **plugin API** (header + host adapter + manager wiring).
3. Move the tool's logic into a **plugin bundle** (Swift, `@_cdecl`), shipped
   built-in (auto-registered) but loaded via the plugin host.
4. **Remove** the hard-wired core code + menu wiring that duplicated it; route the
   menu command through the loaded plugin.
5. Verify parity (same behavior) + tests; measure that idle cost dropped.

**Step order**
- **S1 — Uninstall Application → PTX. ✅ DONE.** DECISION: PTX is realized
  **in-process** (Swift `ToolPlugin` protocol + `ToolPluginRegistry` + `ToolHost`
  services), not a C-ABI dylib, for bundled tools — resource-ideal (shared
  frameworks, no ABI marshalling, no code duplication), and a future C-ABI
  `.ptxplugin` loader can wrap the same protocol for third parties.
  `UninstallerToolPlugin` now owns the whole flow; `MainWindowController` only
  dispatches `cm_UninstallApp` and provides `ToolHost`. Hard-wired
  `showUninstallApp`/`performUninstall`/`uninstallerWindow` removed. Parity kept
  (same `AppUninstaller` + review window). Build + suite green.
- **S2 — WebDAV + Cloud → PFX. ✅ DONE (in-process).** Add `pfx.h` + PFX host adapter (`PFXFileSystem:
  VirtualFileSystem`) + a "Network" root. Move WebDAV (and the iCloud provider)
  behind PFX plugins registered into `CloudProviderRegistry`. Keep the native
  `WebDAVFileSystem` as the plugin's implementation (Swift). Remove the
  hard-wired `cm_WebDAVConnect`/registry entries; the mounts come from plugins.
- **S3 — Log Viewer → PTX (tool). ✅ DONE (in-process).** Add the PTX `ToolMakeView` panel variant; move
  the log window into a `LogViewer.ptxplugin`; host feeds the log stream. Remove
  the built-in log window wiring.
- **S4+ — Git (PDX column + PTX actions), RAR/7z/zst (PCX packers), Treemap (PTX
  panel + VFS-walk callback).** Now unblocked by S1–S3's API.

## 5. Risks / decisions to confirm

- **PTX is a custom API extension** (no TC precedent). Its shape (function table,
  host-callback surface for the op engine, panel embedding rules) is a design
  commitment — worth a review before S1 locks it in.
- This is **multi-session** work; each step is a reviewable unit with parity
  tests. Nothing ships half-wired: a step either fully replaces the hard-wired
  path or is not merged.
