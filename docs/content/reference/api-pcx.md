---
title: "API: Packer plugins (PCX)"
slug: api-pcx
group: Develop
section: API reference
order: 210
related: [sdk-overview, plugin-architecture-guide]
---

# Packer plugins (PCX)

> Source: `Plugins/SDK/pcx.h` — this page is generated from that header by `docs/scripts/gen-api-reference.py`; edit the header, not this page.

pcx.h — Peach Commander packer plugins (PCX), a WCX port (SPEC-012 §2, F-231).

 A PCX plugin exposes an archive format to Peach Commander so it can be browsed,
 extracted, and (optionally) written exactly like the built-in zip support.
 Self-contained C11 on top of pc_common.h.

 Required exports: OpenArchive, ReadHeaderEx, ProcessFile, CloseArchive,
                   SetChangeVolProc, SetProcessDataProc.
 Optional exports: PackFiles, DeleteFiles, GetPackerCaps, ConfigurePacker,
                   CanYouHandleThisFile, PackSetDefaultParams, PkSetCryptCallback,
                   GetBackgroundFlags, StartMemPack/PackToMem/DoneMemPack.

 The host serialises calls per open archive HANDLE unless GetPackerCaps reports
 PC_CAP_MULTITHREAD. All char* are UTF-8; all sizes/times are int64_t/epoch.

## Entry points & functions

- `CanYouHandleThisFile`
- `CloseArchive`
- `ConfigurePacker`
- `DeleteFiles`
- `GetBackgroundFlags`
- `GetPackerCaps`
- `OpenArchive`
- `PackSetDefaultParams`
- `PcGetApiVersion`
- `PkSetCryptCallback`
- `ProcessFile`
- `ReadHeaderEx`
- `SetChangeVolProc`
- `SetProcessDataProc`


## Constants

| Name | Value | Meaning |
|---|---|---|
| `PC_OM_LIST` | `0` | just list headers (browsing) |
| `PC_OM_EXTRACT` | `1` | list + extract |
| `PC_ATTR_DIR` | `0x10` | entry is a directory |
| `PC_ATTR_READONLY` | `0x01` |  |
| `PC_ATTR_HIDDEN` | `0x02` |  |
| `PC_ATTR_SYMLINK` | `0x40` |  |
| `PC_PK_MOVE_FILES` | `0x01` | delete originals after packing |
| `PC_PK_SAVE_PATHS` | `0x02` | store relative paths |
| `PC_PK_ENCRYPT` | `0x04` |  |

## Full header

```c
// SPDX-License-Identifier: Apache-2.0
/*
 * pcx.h — Peach Commander packer plugins (PCX), a WCX port (SPEC-012 §2, F-231).
 *
 * A PCX plugin exposes an archive format to Peach Commander so it can be browsed,
 * extracted, and (optionally) written exactly like the built-in zip support.
 * Self-contained C11 on top of pc_common.h.
 *
 * Required exports: OpenArchive, ReadHeaderEx, ProcessFile, CloseArchive,
 *                   SetChangeVolProc, SetProcessDataProc.
 * Optional exports: PackFiles, DeleteFiles, GetPackerCaps, ConfigurePacker,
 *                   CanYouHandleThisFile, PackSetDefaultParams, PkSetCryptCallback,
 *                   GetBackgroundFlags, StartMemPack/PackToMem/DoneMemPack.
 *
 * The host serialises calls per open archive HANDLE unless GetPackerCaps reports
 * PC_CAP_MULTITHREAD. All char* are UTF-8; all sizes/times are int64_t/epoch.
 */

#ifndef PCX_H
#define PCX_H

#include <stdint.h>
#include "pc_common.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque archive handle returned by OpenArchive. */
typedef void *PC_HANDLE;

/* Open modes for OpenArchive (PcOpenArchiveData.openMode). */
#define PC_OM_LIST       0  /* just list headers (browsing)                   */
#define PC_OM_EXTRACT    1  /* list + extract                                 */

/*
 * OpenArchive input/output. The host fills `arcName` and `openMode`; the plugin
 * sets `openResult` to PC_OK or a PC_E_* code (also reflected by a NULL return).
 */
typedef struct {
    char   *arcName;     /* IN:  archive path (UTF-8)                          */
    int     openMode;    /* IN:  PC_OM_*                                       */
    int     openResult;  /* OUT: PC_OK or PC_E_*                               */
    char   *comment;     /* OUT: optional archive comment buffer (may be NULL) */
    int     commentLen;  /* IN:  capacity of `comment`                         */
} PcOpenArchiveData;

/* File attribute bits reported in PcHeaderDataEx.fileAttr (POSIX-ish subset). */
#define PC_ATTR_DIR       0x10   /* entry is a directory                       */
#define PC_ATTR_READONLY  0x01
#define PC_ATTR_HIDDEN    0x02
#define PC_ATTR_SYMLINK   0x40

/*
 * One archive entry, filled by ReadHeaderEx. Strings are UTF-8. `fileName` is the
 * archive-relative path using '/' separators. Times are Unix epoch seconds.
 */
typedef struct {
    char    fileName[1024]; /* OUT: entry path, '/'-separated, UTF-8           */
    int64_t packSize;       /* OUT: compressed size in bytes                   */
    int64_t unpSize;        /* OUT: uncompressed size in bytes                 */
    int64_t fileTime;       /* OUT: modification time, epoch seconds           */
    uint32_t fileAttr;      /* OUT: PC_ATTR_* bits                             */
    uint32_t fileCRC;       /* OUT: CRC-32 (0 if unknown)                      */
    int     method;         /* OUT: format-specific compression method id      */
    char    reserved[64];   /* reserved; zero-fill                             */
} PcHeaderDataEx;

/* ---- Required entry points --------------------------------------------- */

/* Open an archive; return a handle or NULL (with data->openResult set). */
PC_HANDLE OpenArchive(PcOpenArchiveData *data);

/*
 * Read the next header. Return PC_OK and fill `hdr`, or PC_E_END_ARCHIVE when
 * there are no more entries, or another PC_E_* on error. After a successful
 * ReadHeaderEx the host calls ProcessFile once for that entry.
 */
int ReadHeaderEx(PC_HANDLE hArc, PcHeaderDataEx *hdr);

/*
 * Act on the entry most recently returned by ReadHeaderEx. `operation` is one of
 * PC_SKIP / PC_TEST / PC_EXTRACT. For PC_EXTRACT, `destPath` (may be NULL/"") and
 * `destName` give the output location (UTF-8). Return PC_OK or PC_E_*.
 */
int ProcessFile(PC_HANDLE hArc, int operation, char *destPath, char *destName);

/* Close an archive opened by OpenArchive. Return PC_OK or PC_E_*. */
int CloseArchive(PC_HANDLE hArc);

/* Register the change-volume callback for multi-volume archives. */
void SetChangeVolProc(PC_HANDLE hArc, PcChangeVolProc proc);

/* Register the progress callback (return PC_ABORT from it to cancel). */
void SetProcessDataProc(PC_HANDLE hArc, PcProcessDataProc proc);

/* ---- Optional entry points --------------------------------------------- */

/*
 * Create/append files to an archive. `packedFile` is the archive path; `subPath`
 * is an optional path prefix inside the archive; `srcPath` is the local base dir;
 * `addList` is a UTF-8, NUL-separated, double-NUL-terminated list of relative
 * names. `flags` carries PC_PK_* options. Return PC_OK or PC_E_*.
 */
#define PC_PK_MOVE_FILES 0x01  /* delete originals after packing              */
#define PC_PK_SAVE_PATHS 0x02  /* store relative paths                        */
#define PC_PK_ENCRYPT    0x04
int PackFiles(char *packedFile, char *subPath, char *srcPath,
              char *addList, int flags);

/*
 * Delete entries from an archive. `deleteList` is a UTF-8 double-NUL-terminated
 * list of archive-relative names (a trailing "\\dir\\*.*" style wildcard removes
 * a subtree). Return PC_OK or PC_E_*.
 */
int DeleteFiles(char *packedFile, char *deleteList);

/* Return a bit mask of PC_CAP_* describing what this packer supports. */
int GetPackerCaps(void);

/*
 * Show a configuration UI. `parentView` is an NSView* (cast to void*) supplied by
 * the host; the plugin may present a sheet/child view. May be a no-op.
 */
void ConfigurePacker(void *parentView);

/*
 * Content detection fallback used when the extension does not decide it.
 * Return non-zero if this plugin can handle `fileName`. Only consulted when the
 * plugin advertises PC_CAP_BY_CONTENT.
 */
int CanYouHandleThisFile(char *fileName);

/* Load persisted default parameters (host passes its config dir path, UTF-8). */
void PackSetDefaultParams(char *configDir);

/* Register the crypto (password) callback; `cryptoNr` identifies this plugin. */
void PkSetCryptCallback(PcCryptProc proc, int cryptoNr, int flags);

/* Return background-processing flags (bit 0: unpack in background allowed, …). */
int GetBackgroundFlags(void);

/* Optional API version export checked by the host during load. */
int PcGetApiVersion(void);

#ifdef __cplusplus
}
#endif

#endif /* PCX_H */
```
