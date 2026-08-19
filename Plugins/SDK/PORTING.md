# Porting Total Commander plugins to Peach Commander (PCX/PFX/PLX/PDX)

Peach Commander's plugin ABI mirrors Total Commander's WCX/WFX/WLX/WDX so existing
plugins can be **source-ported** with mechanical changes. This guide covers the
packer type (WCX → PCX) end-to-end; the other types follow the same rules.

The single biggest change: **there is no ANSI/Unicode split and no Win32.**
Everything crossing the ABI is UTF-8 `char *`, sizes/offsets are `int64_t`, and
times are Unix epoch seconds. You delete all the `...W` entry points and keep one
UTF-8 implementation.

## 1. Type map

| Win32 / WCX type        | PCX type (`pc_common.h`)      | Notes |
|-------------------------|-------------------------------|-------|
| `char*` (ANSI) + `WCHAR*` (`...W`) | `char *` (UTF-8) | one entry point, UTF-8 |
| `HANDLE`, `HARC`        | `PC_HANDLE` (`void *`)        | opaque |
| `HWND` (parent window)  | `void *` (an `NSView *`)      | cast in your config fn |
| `DWORD`                 | `uint32_t`                    | |
| `int` / `BOOL`          | `int` (0 = false)             | |
| 32-bit sizes (`DWORD Size`) | `int64_t`                 | no high/low split |
| `FILETIME` / DOS time   | `int64_t` epoch seconds       | see §4 |
| `tHeaderDataExW`        | `PcHeaderDataEx`              | UTF-8 `fileName`, int64 sizes |
| `tOpenArchiveDataW`     | `PcOpenArchiveData`          | |
| `tProcessDataProcW`     | `PcProcessDataProc`          | `int64_t` size arg |
| `tChangeVolProcW`       | `PcChangeVolProc`            | |

## 2. Entry-point map (WCX → PCX)

| WCX (drop the `W` suffix)        | PCX                          | Required |
|----------------------------------|------------------------------|----------|
| `OpenArchiveW`                   | `OpenArchive`                | ✅ |
| `ReadHeaderExW`                  | `ReadHeaderEx`               | ✅ |
| `ProcessFileW`                   | `ProcessFile`                | ✅ |
| `CloseArchive`                   | `CloseArchive`               | ✅ |
| `SetChangeVolProcW`              | `SetChangeVolProc`           | ✅ |
| `SetProcessDataProcW`            | `SetProcessDataProc`         | ✅ |
| `PackFilesW`                     | `PackFiles`                  | optional |
| `DeleteFilesW`                   | `DeleteFiles`                | optional |
| `GetPackerCaps`                  | `GetPackerCaps`              | optional |
| `ConfigurePacker`                | `ConfigurePacker` (NSView*)  | optional |
| `CanYouHandleThisFileW`          | `CanYouHandleThisFile`       | optional |
| `PackSetDefaultParams`           | `PackSetDefaultParams`       | optional |
| `PkSetCryptCallbackW`            | `PkSetCryptCallback`         | optional |
| `GetBackgroundFlags`             | `GetBackgroundFlags`         | optional |
| `GetPackerCaps` bit `PK_CAPS_*`  | `PC_CAP_*`                   | rename constants |
| operation `PK_SKIP/TEST/EXTRACT` | `PC_SKIP/PC_TEST/PC_EXTRACT` | same values |
| error `E_END_ARCHIVE` etc.       | `PC_E_END_ARCHIVE` etc.      | renamed |

## 3. Win32 call → POSIX / Foundation table

| Win32 call                    | Replacement |
|-------------------------------|-------------|
| `CreateFile` / `ReadFile` / `WriteFile` | `open`/`read`/`write` or `fopen`/`fread`/`fwrite` |
| `CloseHandle`                 | `close` / `fclose` |
| `GetFileSize`                 | `fstat` → `st_size` (int64) |
| `SetFilePointer`              | `lseek` |
| `CreateDirectory`             | `mkdir(path, 0755)` |
| `DeleteFile`                  | `unlink` |
| `GetTempPath`                 | `getenv("TMPDIR")` (host also passes a temp dir) |
| `MultiByteToWideChar`/`WideCharToMultiByte` | **delete** — strings are already UTF-8 |
| `MessageBox`                  | host callback / `ConfigurePacker` sheet |
| `lstrcpyn`                    | `strlcpy` |
| `FILETIME` ↔ `SYSTEMTIME`     | `int64_t` epoch (see §4) |

## 4. Time conversion

WCX uses DOS date/time or `FILETIME`. PCX uses `int64_t` Unix epoch seconds.

```c
/* DOS date/time (as in old WCX headers) -> epoch seconds */
#include <time.h>
static int64_t dos_to_epoch(uint16_t dosDate, uint16_t dosTime) {
    struct tm t = {0};
    t.tm_year = ((dosDate >> 9) & 0x7f) + 80;   /* since 1980 -> since 1900 */
    t.tm_mon  = ((dosDate >> 5) & 0x0f) - 1;
    t.tm_mday =  (dosDate       & 0x1f);
    t.tm_hour =  (dosTime >> 11) & 0x1f;
    t.tm_min  =  (dosTime >> 5)  & 0x3f;
    t.tm_sec  = ((dosTime        & 0x1f) * 2);
    return (int64_t)timegm(&t);
}
```
`FILETIME` (100 ns ticks since 1601): `epoch = (filetime - 116444736000000000) / 10000000`.

## 5. Packaging

Ship the plugin as a macOS bundle directory:

```
MyPacker.pcxplugin/
  Contents/
    Info.plist          # PCPluginType=pcx, PCPluginAPIVersion=1, PCPluginName,
                         # PCPluginExtensions=<array or ";"-separated string>
    MacOS/MyPacker       # the dylib (same base name as the bundle)
    Resources/           # optional
```

The host `dlopen`s `Contents/MacOS/<name>` with `RTLD_LOCAL|RTLD_NOW`, resolves the
required symbols, and (if present) calls `PcGetApiVersion()` for a handshake. A
missing required symbol is reported as a load error in the plugin manager; the
plugin is not enabled. Optionally ship a `pluginst.inf` (`[plugininstall]` with
`type=wcx`, `file=…`, `description=…`, `defaultdir=…`) so "Install from .zip" can
name and place it automatically.

## 6. Worked example — a minimal read-only packer

```c
#include "pcx.h"
#include <string.h>
#include <stdlib.h>

typedef struct { /* your archive state */ FILE *fp; /* … */ } MyArc;

PC_HANDLE OpenArchive(PcOpenArchiveData *d) {
    FILE *fp = fopen(d->arcName, "rb");
    if (!fp) { d->openResult = PC_E_EOPEN; return NULL; }
    MyArc *a = calloc(1, sizeof(MyArc));
    a->fp = fp;
    d->openResult = PC_OK;
    return (PC_HANDLE)a;
}

int ReadHeaderEx(PC_HANDLE h, PcHeaderDataEx *hdr) {
    MyArc *a = (MyArc *)h;
    /* read the next index entry from a->fp … */
    if (/* no more entries */ 0) return PC_E_END_ARCHIVE;
    memset(hdr, 0, sizeof(*hdr));
    strlcpy(hdr->fileName, "example.txt", sizeof(hdr->fileName));
    hdr->unpSize = 123;
    hdr->packSize = 123;
    hdr->fileTime = 0;      /* epoch seconds */
    return PC_OK;
}

int ProcessFile(PC_HANDLE h, int op, char *destPath, char *destName) {
    if (op == PC_SKIP) return PC_OK;
    /* op == PC_EXTRACT: write the current entry to destPath/destName */
    return PC_OK;
}

int CloseArchive(PC_HANDLE h) { MyArc *a = (MyArc *)h; if (a){ fclose(a->fp); free(a);} return PC_OK; }
void SetChangeVolProc(PC_HANDLE h, PcChangeVolProc p)   { (void)h; (void)p; }
void SetProcessDataProc(PC_HANDLE h, PcProcessDataProc p){ (void)h; (void)p; }
int  GetPackerCaps(void) { return PC_CAP_MULTIPLE; }      /* read-only, multi-file */
int  PcGetApiVersion(void) { return PC_API_VERSION; }
```

That is a complete, browsable read-only packer. Add `PackFiles` / `DeleteFiles`
and the matching `PC_CAP_NEW|PC_CAP_MODIFY|PC_CAP_DELETE` bits to make it writable.

## 7. Checklist

- [ ] Remove all `...W` duplicate entry points; keep one UTF-8 implementation.
- [ ] Replace `WCHAR`/`TCHAR` with UTF-8 `char *`; delete `MultiByteToWideChar`.
- [ ] Widen 32-bit sizes to `int64_t`.
- [ ] Convert DOS/`FILETIME` times to epoch seconds (§4).
- [ ] Swap Win32 file/dir calls for POSIX (§3).
- [ ] Rename `PK_*`/`E_*` constants to `PC_*` (§2).
- [ ] Cast the `ConfigurePacker` parent to `NSView *` (or ignore it).
- [ ] Package as a `.pcxplugin` bundle with an Info.plist (§5).
- [ ] Verify: `browse → extract → (pack/delete)` through the Peach Commander UI.
```

## Matching the host's colour theme (F-338)

The host can be themed — including a Norton Commander palette whose CGA blue matches no macOS
appearance. A plugin view that hardcodes system colours then looks out of place beside the panels.

Add `Plugins/SDK/PluginTheme.swift` to your swiftc sources and read the colours instead:

```swift
private var theme = PluginTheme.systemFallback

func applyTheme() {
    theme = PluginTheme(services)          // or PluginTheme(svc) if you keep the struct by value
    layer?.backgroundColor = theme.background.cgColor
    label.textColor = theme.text
    needsDisplay = true
}
```

Semantic colours: `background`, `windowBackground`, `text`, `secondaryText`, `accent`, `separator`,
`selectionBackground`, `selectionText`, `markedText`, `controlBackground`, `controlText`, plus
`isDark` and `id`. Any host panel colour is available raw via `hostColor("statusBarBackground",
fallback: …)` — the same names a user theme file uses.

Every property falls back to the system colour, so a plugin using the helper against a host that
predates the theme keys renders exactly as it did before. `hostSuppliesTheme` tells you which case
you are in.

**Follow changes.** For a view from `PcMakeView`, the host calls
`PcNotifyView(view, "theme", <themeId>)`. For your own windows, export the optional entry point:

```swift
@_cdecl("PcNotifyThemeChanged")
public func PcNotifyThemeChanged() { myWindow?.applyTheme() }
```

**Where theming is right, and where it is not.** Theme a view that sits *in the panel area* — the
sidebar and preview containers. Do **not** theme a view in the `titlebar` or `settings` container,
or a standalone window: those are macOS chrome, and system colours are correct there. The shipped
plugins follow exactly that split — Treemap's disk map, Notes' sidebar and the AI chat are themed;
the System Monitor's titlebar chips and every settings pane are not.

If you theme text, theme its background in the same pass. A themed foreground on an unthemed
background is how you get cyan on white.

## Long-running commands: `"async": true`, progress and cancel (F-422)

A contributed command runs on the host's main thread by default, which is right for anything that opens a
window or reads a cached value and wrong for anything that talks to a network: the application stops
redrawing for as long as the call takes, and a `push` to an unreachable host is indistinguishable from a
crash.

Declare such a command asynchronous in the manifest:

```xml
<dict>
    <key>id</key><string>plugin.example.push</string>
    <key>title</key><string>Push</string>
    <key>async</key><true/>
</dict>
```

The host then calls `PcRunCommand` on a background thread, and three rules follow from that:

1. **Do not touch AppKit directly.** Build no windows, run no `NSAlert`. The host services may be called
   from your thread — they hop to the main actor themselves — but your own AppKit calls may not.
2. **Report through the progress services**, which exist only for this case:
   `beginProgress(host, title)` returns an opaque handle (NULL means the host will not show one — cope with
   it), `updateProgress(host, handle, fraction, text)` sets the bar (`fraction < 0` = indeterminate) and
   returns **0 once the reader pressed Cancel**, and `endProgress(host, handle)` closes the window. Call
   `endProgress` on every path out, including your error paths.
3. **Cancellation is cooperative.** The host cannot kill your command; a plugin that never calls
   `updateProgress` cannot be cancelled. If you run a child process, keep it and `terminate()` it when
   `updateProgress` returns 0.

A synchronous command sees no change: the flag is opt-in, and its absence means the old contract.

## Annotating lines in the host's editor: `annotateLines` (F-426)

A plugin often knows something about every line of a file — who last touched it, whether a test covered it,
what a linter said — and cannot draw it: the gutter belongs to the host's editor, and a plugin shipping its
own text view would be a second editor in the same application. So the plugin sends text and the host draws
it:

```c
int shown = svc->annotateLines(svc->host, "/path/to/file.swift",
                               "a1b2c3d4  Ada\tadds the parser\n"   /* line 1 */
                               "\n"                                 /* line 2: nothing */
                               "ffffffff  Linus\tfixes it\n",       /* line 3 */
                               "Blame", "plugin.example.showcommit");
```

* **One record per source line**, in order from line 1, separated by `\n`; each record is `text` or
  `text\ttooltip`. An empty record leaves that line blank, and a short list annotates only what it covers.
  Neither field may contain a tab or a newline — a newline inside a record splits it in two and shifts
  every annotation after it against the line it describes.
* **The host finds or opens the editor** for that path, so the plugin does not have to know whether the
  reader has the file open. It returns 0 when it could not (an older host, or a file it cannot edit) —
  worth reporting, because a command that silently does nothing reads as broken.
* **The click is a command, not a callback.** Pass a command id and the host invokes it when an annotation
  is clicked; that command reads which line through `getContext("gutterAnnotationLine")`. No function
  pointer crosses the ABI, so there is no way for the host to call into a plugin that has gone away.
* **Clear** with `NULL` or `""`.

One rule bears repeating here, because writing this service was where it bit its own author: a command that
opens a window **must not** be declared `"async": true`. `MainActor.assumeIsolated` off the main thread does
not fail politely, it traps — see the asynchronous-command section above.

