# SPEC-012 — Plugin System (PCX / PFX / PLX / PDX)

Covers: F-230..F-238. ADR-004. Mirrors TC's WCX/WFX/WLX/WDX so plugins can be
source-ported. Reference SDKs: https://ghisler.github.io/ (fetch per type when
implementing; function lists summarized below are the contract).

## §1 Packaging & loading

- A plugin = macOS bundle dir: `Name.pcxplugin/Contents/{Info.plist, MacOS/Name.dylib, Resources/}`.
  Info.plist keys: `PCPluginType` (pcx|pfx|plx|pdx), `PCPluginAPIVersion` (int,
  current 1), `PCPluginName`, extension defaults (pcx: `PCPluginExtensions`),
  detect string (plx/pdx: `PCPluginDetectString`), min host version.
- Host: `dlopen(RTLD_LOCAL|RTLD_NOW)`; resolve required symbols; missing
  required symbol → load error surfaced in plugin manager. Version handshake:
  optional export `PcGetApiVersion()`. Unload on disable (`dlclose`) only if
  plugin exports `PcSafeToUnload`; else keep loaded (TC-like pragmatism).
- All strings crossing the ABI: **UTF-8 char***. Sizes/offsets: int64_t.
  Times: Unix epoch seconds (int64). Booleans: int. Handles: opaque void*.
- Threading contract: host serializes calls per plugin instance unless plugin
  reports `PC_CAP_MULTITHREAD` in its caps call (mirrors TC background flags).
- Crash policy: in-process (ADR-004); host installs exception logging; plugin
  name recorded in crash breadcrumbs to blame correctly.

## §2 PCX — packer plugins (WCX port) (F-231)

Required: `OpenArchive(PcOpenArchiveData*)`, `ReadHeaderEx(HANDLE, PcHeaderDataEx*)`,
`ProcessFile(HANDLE, int op, char* destPath, char* destName)`,
`CloseArchive(HANDLE)`, `SetChangeVolProc`, `SetProcessDataProc` (progress cb,
return 0 = abort).
Optional: `PackFiles`, `DeleteFiles`, `GetPackerCaps` (PK_CAPS_NEW/MODIFY/
MULTIPLE/DELETE/OPTIONS/MEMPACK/BY_CONTENT/SEARCHTEXT/HIDE/ENCRYPT),
`ConfigurePacker(parentView)`, `StartMemPack/PackToMem/DoneMemPack`,
`CanYouHandleThisFile(char* name)`, `PackSetDefaultParams`, `PkSetCryptCallback`,
`GetBackgroundFlags`.
Integration: PCArchive format registry consults plugin associations first
(plugins.ini `[PackerAssoc] ext=plugin`), built-ins second.

## §3 PDX — content plugins (WDX port) (F-234)

Required: `ContentGetSupportedField(int idx, char* name, char* units, int maxlen)`
(returns field type: number/date/time/bool/string/multiplechoice/fulltext),
`ContentGetValue(char* file, int fieldIdx, int unitIdx, void* out, int maxlen, int flags)`.
Optional: `ContentGetDetectString`, `ContentSetDefaultParams`, `ContentStopGetValue`,
`ContentGetDefaultSortOrder`, `ContentPluginUnloading`, `ContentGetSupportedFieldFlags`,
`ContentSetValue`, `ContentEditValue`, `ContentSendStateInformation`,
`ContentCompareFiles`, `ContentFindValue`, `ContentGetSupportedOperators`.
Consumers: custom columns (async! host calls on worker, caches, respects
ft_delayed), tooltips, search plugin tab, multi-rename `[=...]`, overwrite
dialog fields, sync compare-by-field (P3).

## §4 PFX — file system plugins (WFX port) (F-232)

Required: `FsInit(int pluginNr, progressProc, logProc, requestProc)`,
`FsFindFirst(char* path, PcFindData*)`, `FsFindNext`, `FsFindClose`.
Optional: `FsGetFile`, `FsPutFile`, `FsRenMovFile`, `FsDeleteFile`, `FsRemoveDir`,
`FsMkDir`, `FsExecuteFile`, `FsSetAttr`, `FsSetTime`, `FsDisconnect`,
`FsStatusInfo`, `FsExtractCustomIcon`, `FsSetDefaultParams`, `FsGetPreviewBitmap`,
`FsLinksToLocalFiles`/`FsGetLocalName` (temp-panel style plugins),
`FsContent*` (same as PDX for plugin-provided columns),
`FsGetBackgroundFlags`, `FsSetCryptCallback`, `FsGetDefRootName`.
Host adapter maps this to `VirtualFileSystem`; mounted under "Network" root
(each plugin one subdir named by FsGetDefRootName). Callbacks: progress →
op engine; request → stdin-style dialogs (user/password/target dir…);
log → connection log window (SPEC-011 §3 reuses it).

## §5 PLX — lister plugins (WLX port) (F-233)

Required: `ListLoad(void* parentView, char* file, int showFlags) -> void* view`
— **parentView is an NSView***; plugin adds its own NSView subview and returns
it (header documents ARC/retain rules; C plugins get a host-provided
convenience to wrap a CALayer/child window).
Optional: `ListLoadNext`, `ListCloseWindow`, `ListGetDetectString`,
`ListSearchText`, `ListSendCommand`, `ListPrint`, `ListNotificationReceived`,
`ListSetDefaultParams`, `ListGetPreviewBitmap`, `ListSearchDialog`.
Used by Lister mode 7 + Quick View + thumbnail providers.

## §6 Detect strings (F-238)

Shared parser (PCPluginHost): grammar `EXT="ZIP" | SIZE>100 & FORCE`,
fields: EXT, SIZE, FORCE, MULTIMEDIA, `[0]`..`[8191]` byte probes, operators
`= != < > & | !` and parentheses. Unit tests with TC-documented examples.

## §7 SDK deliverables (F-236, in `Plugins/SDK/`)

- Headers: `pc_common.h`, `pcx.h`, `pfx.h`, `plx.h`, `pdx.h` (self-contained,
  documented per function, no Apple imports needed except plx view note).
- Swift overlay package `PCPluginKit` (write plugins in Swift with protocol
  wrappers + @_cdecl glue template).
- Sample plugins (built in CI): `SamplePacker` (a trivial .pak concatenation
  format), `SampleFS` (exposes an in-memory tree), `SampleLister` (renders
  .csv as table), `SampleContent` (image dimensions via ImageIO).
- `PORTING.md`: WCX→PCX etc. mapping tables (types: HWND→NSView*, DWORD→
  uint32_t, FILETIME→int64 epoch, ANSI/W dual APIs→single UTF-8), checklist
  of Win32 calls with POSIX/Foundation equivalents.

## §8 Plugin manager UI (F-235)

Options page "Plugins": 4 tabs by type; list: name, version, path, enabled;
buttons: Install from .zip / from folder (reads `pluginst.inf` if present —
TC's install descriptor — else infers), Remove, Configure (calls plugin's
config function), Associations editor (pcx ext map; plx/pdx detect override).
Install copies into config `plugins/` dir. First-run security note: plugins
run unsandboxed; Gatekeeper quarantine flag is respected (warn, `xattr -d`
guidance not auto-applied).

## §9 Tests

- Host: load/unload lifecycle, symbol resolution failures, version mismatch,
  UTF-8 boundary cases, callback bridging, serialization guarantee.
- Each sample plugin: functional tests through its public consumer (pack via
  UI path, list FS via VFS battery, render lister view smoke, content fields
  in columns/search).
