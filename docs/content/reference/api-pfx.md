---
title: "API: File-system plugins (PFX)"
slug: api-pfx
section: API reference
order: 40
related: [sdk-overview, plugin-architecture-guide]
---

# File-system plugins (PFX)

> Source: `Plugins/SDK/pfx.h` — this page is generated from that header by `docs/scripts/gen-api-reference.py`; edit the header, not this page.

pfx.h — Peach Commander file-system plugins (PFX ↔ Total Commander WFX).

 A PFX plugin exposes a remote/virtual file system to be mounted like a drive.
 It follows TC's WFX model — a flat, synchronous, whole-file C ABI — which is
 why WFX has stayed source-compatible across decades: directory enumeration
 returns metadata only (fast), and file transfer materialises the whole file to
 a local path (GetFile/PutFile). The host adapts this to its streaming
 VirtualFileSystem (openRead = GetFile → temp → stream). Real chunk-streaming
 can be added later as OPTIONAL entry points without breaking this ABI.

 A plugin implements one or both independent facets:
   • Static volumes  — contributes drive-bar entries pointing at local paths
                        (e.g. iCloud Drive). Uses PfxGetVolumeCount/Info only.
   • Connectable FS  — an interactive "connect" (e.g. WebDAV: prompt for URL)
                        that returns a connection handle, then serves file ops.

 Self-contained C11 on top of pc_common.h. All char* are UTF-8; sizes are
 int64; times are Unix epoch seconds; opaque handles are void* (NULL = invalid).
 The host serialises all calls on one connection handle. Version-checked via
 PcGetApiVersion.

 All entry points are OPTIONAL at load time; the host probes which symbols a
 plugin exports to decide its facets. A plugin should export PcGetApiVersion.

## Entry points & functions

- `PfxConnect`
- `PfxConnectionId`
- `PfxContentField`
- `PfxContentFieldCount`
- `PfxContentGetRow`
- `PfxDelete`
- `PfxDisconnect`
- `PfxFindClose`
- `PfxFindFirst`
- `PfxFindNext`
- `PfxGetCapabilities`
- `PfxGetConnectTitle`
- `PfxGetFile`
- `PfxGetVolumeCount`
- `PfxGetVolumeInfo`
- `PfxInit`
- `PfxLookup`
- `PfxMkDir`
- `PfxPutFile`
- `PfxRenMov`
- `PfxStat`


## Callbacks & service members

- `progress`
- `presentInfo`
- `crypt`


## Constants

| Name | Value | Meaning |
|---|---|---|
| `PC_PFX_VOL_LOCAL` | `0x0001` | `path` is a real local path — browse directly |
| `PC_PFX_VOL_REMOVABLE` | `0x0002` | show as removable/ejectable in the drive bar |
| `PC_PFX_CAP_READ` | `0x0001` |  |
| `PC_PFX_CAP_WRITE` | `0x0002` |  |
| `PC_PFX_CAP_RENAME` | `0x0004` |  |
| `PC_PFX_CAP_VOLATILE` | `0x0008` | contents change live; host may auto-refresh the mount |

## Full header

```c
// SPDX-License-Identifier: Apache-2.0
/*
 * pfx.h — Peach Commander file-system plugins (PFX ↔ Total Commander WFX).
 *
 * A PFX plugin exposes a remote/virtual file system to be mounted like a drive.
 * It follows TC's WFX model — a flat, synchronous, whole-file C ABI — which is
 * why WFX has stayed source-compatible across decades: directory enumeration
 * returns metadata only (fast), and file transfer materialises the whole file to
 * a local path (GetFile/PutFile). The host adapts this to its streaming
 * VirtualFileSystem (openRead = GetFile → temp → stream). Real chunk-streaming
 * can be added later as OPTIONAL entry points without breaking this ABI.
 *
 * A plugin implements one or both independent facets:
 *   • Static volumes  — contributes drive-bar entries pointing at local paths
 *                        (e.g. iCloud Drive). Uses PfxGetVolumeCount/Info only.
 *   • Connectable FS  — an interactive "connect" (e.g. WebDAV: prompt for URL)
 *                        that returns a connection handle, then serves file ops.
 *
 * Self-contained C11 on top of pc_common.h. All char* are UTF-8; sizes are
 * int64; times are Unix epoch seconds; opaque handles are void* (NULL = invalid).
 * The host serialises all calls on one connection handle. Version-checked via
 * PcGetApiVersion.
 *
 * All entry points are OPTIONAL at load time; the host probes which symbols a
 * plugin exports to decide its facets. A plugin should export PcGetApiVersion.
 */

#ifndef PFX_H
#define PFX_H

#include <stdint.h>
#include "pc_common.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Volume flags (PfxVolumeInfo.flags, bit mask). */
#define PC_PFX_VOL_LOCAL      0x0001  /* `path` is a real local path — browse directly */
#define PC_PFX_VOL_REMOVABLE  0x0002  /* show as removable/ejectable in the drive bar   */

/* Filesystem capability flags (PfxGetCapabilities, bit mask). Read is implied. */
#define PC_PFX_CAP_READ    0x0001
#define PC_PFX_CAP_WRITE   0x0002
#define PC_PFX_CAP_RENAME  0x0004
#define PC_PFX_CAP_VOLATILE 0x0008  /* contents change live; host may auto-refresh the mount */

/* Content-column field types (PfxContentField). Values are always returned
 * as display strings by PfxContentGetRow; the type only guides column
 * alignment and sort order in the host. */
#define PFX_FT_STRING    0  /* left-aligned, natural sort              */
#define PFX_FT_NUMERIC   1  /* right-aligned, numeric sort             */
#define PFX_FT_SIZE      2  /* bytes -> KB/MB in the host, numeric sort */
#define PFX_FT_DATETIME  3  /* epoch seconds -> localized date/time     */

/* A static volume the plugin contributes to the drive bar. */
typedef struct {
    char id[128];      /* stable identifier, e.g. "cloud:icloud"                      */
    char name[256];    /* display name, e.g. "iCloud Drive"                           */
    char path[1024];   /* local filesystem path (required for PC_PFX_VOL_LOCAL)       */
    int  flags;        /* PC_PFX_VOL_* bit mask                                       */
    /* Optional presentation (fields the host zero-inits, so older plugins that
       don't set them get host defaults). Lets a plugin own its drive-bar look. */
    char icon[64];     /* emoji shown on the chip (UTF-8), e.g. "📊"; "" = default    */
    int  order;        /* >0 pins the chip right after the boot drive (lower first);
                          0 = ordinary volume, sorted by name                        */
} PfxVolumeInfo;

/* One directory entry (TC's WIN32_FIND_DATA analog). `name` is a leaf, not a path. */
typedef struct {
    char     name[1024];  /* entry name (UTF-8, not a full path)                      */
    int64_t  size;        /* size in bytes; -1 if unknown                             */
    int64_t  mtime;       /* modification time, Unix epoch seconds (0 if unknown)     */
    int      isDir;       /* 1 if a directory                                         */
    uint32_t mode;        /* POSIX permission bits (0 if unknown)                     */
} PfxFindData;

/*
 * Host services a plugin may call. `host` is an opaque token to pass back to each
 * callback. The plugin ships its own connect UI, so services are minimal.
 */
typedef struct PfxHostServices {
    void *host;

    /* Transfer progress for GetFile/PutFile: `pct` is 0..100. Return PC_CONTINUE
       to proceed or PC_ABORT to cancel the transfer. May be NULL. */
    int  (*progress)(void *host, const char *name, int pct);

    /* Show an informational dialog. May be NULL. */
    void (*presentInfo)(void *host, const char *title, const char *message);

    /* Keychain-backed credential store (mode is a PC_CRYPT_* value). `password`
       is an in/out UTF-8 buffer of `maxlen`. Returns PC_OK or a PC_E_* code.
       Lets the plugin persist passwords without linking Security itself. */
    int  (*crypt)(void *host, int mode, const char *store, char *password, int maxlen);

    void *parentWindow;   /* NSWindow* to present connect/config sheets over (may be NULL) */
} PfxHostServices;

/* ---- Lifecycle (optional) --------------------------------------------- */

/* Called once after load; the plugin may retain `services` for later callbacks. */
void PfxInit(const PfxHostServices *services);

/* Capabilities of the file system this plugin serves. Absent ⇒ read-only. */
int  PfxGetCapabilities(void);

/* ---- Static-volumes facet (optional) ---------------------------------- */

int  PfxGetVolumeCount(void);
void PfxGetVolumeInfo(int index, PfxVolumeInfo *out);

/* ---- Connect facet (optional) ----------------------------------------- */

/* Fill `outTitle` with the connect command's menu label; return 1 if this plugin
   offers an interactive connect, else 0. */
int  PfxGetConnectTitle(char *outTitle, int maxlen);

/* Show the connect UI (using services->parentWindow), establish a session, and
   return an opaque connection handle (non-NULL) on success, or NULL on
   cancel/failure. `services` stays valid for the connection's lifetime. */
void *PfxConnect(const PfxHostServices *services);

/* Fill `out` with a short, stable id for `conn` (used as the mount scheme/title,
   e.g. "webdav:host"). Return 1 on success. */
int  PfxConnectionId(void *conn, char *out, int maxlen);

/* Close a connection previously returned by PfxConnect. */
void PfxDisconnect(void *conn);

/* ---- File operations on a connection ---------------------------------- */
/* Paths are absolute within the file system, UTF-8, '/'-separated, "/" = root.  */

/* Begin enumerating `dir`. Return a find handle (non-NULL) on success (the
   directory exists and is accessible), or NULL on error. Entries are then read
   with PfxFindNext; an existing but empty directory yields a handle whose first
   PfxFindNext returns 0. */
void *PfxFindFirst(void *conn, const char *dir);

/* Fill `out` with the next entry. Return 1 if filled, 0 at end of enumeration. */
int  PfxFindNext(void *find, PfxFindData *out);

/* Release a find handle from PfxFindFirst. */
void PfxFindClose(void *find);

/* Stat a single path into `out`. Returns PC_OK or a PC_E_* code. */
int  PfxStat(void *conn, const char *path, PfxFindData *out);

/* Download the whole file at `remotePath` to the local `localPath`. PC_OK/PC_E_*. */
int  PfxGetFile(void *conn, const char *remotePath, const char *localPath);

/* Upload the whole local file at `localPath` to `remotePath`. PC_OK/PC_E_*. */
int  PfxPutFile(void *conn, const char *localPath, const char *remotePath);

/* Create a directory at `path`. PC_OK/PC_E_*. */
int  PfxMkDir(void *conn, const char *path);

/* Delete the file or directory at `path`. PC_OK/PC_E_*. */
int  PfxDelete(void *conn, const char *path);

/* Rename/move `from` to `to` (same connection). `move` is advisory. PC_OK/PC_E_*. */
int  PfxRenMov(void *conn, const char *from, const char *to, int move);

/* ---- Content-column facet (optional) ----------------------------------
 * Lets a file-system plugin publish extra columns for its own entries
 * (e.g. a process list exposing PID/CPU/threads). These become selectable,
 * sortable, persisted columns via the host's normal column machinery.     */

typedef struct {
    char name[128];      /* field id leaf, e.g. "cpu" (host qualifies it) */
    char title[128];     /* column header, e.g. "CPU %"                   */
    int  type;           /* PFX_FT_*                                       */
    int  defaultWidth;   /* suggested column width in px (0 = host default) */
} PfxFieldInfo;

/* Number of content columns this plugin publishes (0 / absent = none). */
int  PfxContentFieldCount(void);

/* Describe column `index` (0..PfxContentFieldCount-1) into `out`. */
void PfxContentField(int index, PfxFieldInfo *out);

/* Write ALL field values for the entry at `path`, tab-separated in field
 * order (no trailing tab), into `out` (NUL-terminated, <= maxlen). One call
 * per entry keeps hundreds of rows cheap. Return 1 on success, 0 if `path`
 * has no row. Missing values are empty between tabs. */
int  PfxContentGetRow(void *conn, const char *path, char *out, int maxlen);

/* ---- Lookup facet (optional) -------------------------------------------
 * Resolve a plugin-defined query to the path of an existing entry, for host
 * "jump to the matching entry" features. The host writes `query`, the plugin
 * writes the entry path (e.g. "/nginx (1234)") into `out` (NUL-terminated,
 * <= maxlen). Return 1 on a hit, 0 on no match. Query syntax is per-plugin;
 * TaskManager understands "port:<n>" — the process owning local TCP/UDP port n.
 *
 * A query may answer with MORE than one entry: one path per line, and a line may
 * carry a tab-separated tag the host understands for that query. TaskManager's
 * "file:<path>" lists every process holding that file open, tagged "r" (read-only
 * handles), "w" (write-only) or "b" (both), which the host colours accordingly.
 * Write whole lines only — never a truncated one — when `out` runs out. */
int  PfxLookup(void *conn, const char *query, char *out, int maxlen);

#ifdef __cplusplus
}
#endif

#endif /* PFX_H */
```
