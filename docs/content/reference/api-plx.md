---
title: "API: Lister plugins (PLX)"
slug: api-plx
group: Develop
section: API reference
order: 240
related: [sdk-overview, plugin-architecture-guide]
---

# Lister plugins (PLX)

> Source: `Plugins/SDK/plx.h` — this page is generated from that header by `docs/scripts/gen-api-reference.py`; edit the header, not this page.

plx.h — Peach Commander lister plugins (PLX), a WLX port (SPEC-012 §3, F-238).

 A PLX plugin renders a file into a custom view for Lister (F3) and Quick View,
 and can also produce a preview thumbnail without a window. Self-contained C11 on
 top of pc_common.h.

 Required exports: ListLoad.
 Optional exports: ListLoadNext, ListCloseWindow, ListGetDetectString,
                   ListSearchText, ListSendCommand, ListPrint,
                   ListGetPreviewBitmap, ListSetDefaultParams, PcGetApiVersion.

 View handles (PC_LISTER_HANDLE) are opaque `void *`. On macOS they are NSView*
 cast to void*: the host passes the parent container view to ListLoad and the
 plugin returns its own content view, or NULL if it cannot display the file.
 The host owns display; the plugin owns the returned view until ListCloseWindow.
 All char* are UTF-8.

## Entry points & functions

- `ListCloseWindow`
- `ListGetDetectString`
- `ListLoad`
- `ListPrint`
- `ListSearchText`
- `ListSendCommand`
- `ListSetDefaultParams`
- `PcGetApiVersion`


## Constants

| Name | Value | Meaning |
|---|---|---|
| `PC_LCP_WRAPTEXT` | `0x0001` | wrap long lines |
| `PC_LCP_FITTOWINDOW` | `0x0002` | scale image content to the window |
| `PC_LCP_CENTER` | `0x0004` | center the content |
| `PC_LCP_FORCESHOW` | `0x0008` | show even if detection is unsure |
| `PC_LCP_DARKMODE` | `0x0010` | host is in dark appearance |
| `PC_LISTER_OK` | `0` |  |
| `PC_LISTER_ERROR` | `1` |  |
| `PC_LC_COPY` | `1` | copy the selection to the clipboard |
| `PC_LC_SELECTALL` | `2` | select everything |
| `PC_LC_NEWPARAMS` | `3` | ShowFlags changed (parameter = new flags) |
| `PC_LC_FONTPLUS` | `4` | increase the font size |
| `PC_LC_FONTMINUS` | `5` | decrease the font size |
| `PC_LCS_MATCHCASE` | `0x0001` |  |
| `PC_LCS_WHOLEWORDS` | `0x0002` |  |
| `PC_LCS_BACKWARDS` | `0x0004` |  |
| `PC_LCS_FINDFIRST` | `0x0008` |  |

## Full header

```c
// SPDX-License-Identifier: Apache-2.0
/*
 * plx.h — Peach Commander lister plugins (PLX), a WLX port (SPEC-012 §3, F-238).
 *
 * A PLX plugin renders a file into a custom view for Lister (F3) and Quick View,
 * and can also produce a preview thumbnail without a window. Self-contained C11 on
 * top of pc_common.h.
 *
 * Required exports: ListLoad.
 * Optional exports: ListLoadNext, ListCloseWindow, ListGetDetectString,
 *                   ListSearchText, ListSendCommand, ListPrint,
 *                   ListGetPreviewBitmap, ListSetDefaultParams, PcGetApiVersion.
 *
 * View handles (PC_LISTER_HANDLE) are opaque `void *`. On macOS they are NSView*
 * cast to void*: the host passes the parent container view to ListLoad and the
 * plugin returns its own content view, or NULL if it cannot display the file.
 * The host owns display; the plugin owns the returned view until ListCloseWindow.
 * All char* are UTF-8.
 */

#ifndef PLX_H
#define PLX_H

#include <stdint.h>
#include "pc_common.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque lister view handle (an NSView* on macOS). NULL means "cannot display". */
typedef void *PC_LISTER_HANDLE;

/* ShowFlags passed to ListLoad / ListLoadNext (bit mask). */
#define PC_LCP_WRAPTEXT     0x0001  /* wrap long lines                          */
#define PC_LCP_FITTOWINDOW  0x0002  /* scale image content to the window        */
#define PC_LCP_CENTER       0x0004  /* center the content                       */
#define PC_LCP_FORCESHOW    0x0008  /* show even if detection is unsure         */
#define PC_LCP_DARKMODE     0x0010  /* host is in dark appearance               */

/* Return codes for the int-returning entry points. */
#define PC_LISTER_OK      0
#define PC_LISTER_ERROR   1

/* Commands for ListSendCommand (`command`). */
#define PC_LC_COPY          1   /* copy the selection to the clipboard          */
#define PC_LC_SELECTALL     2   /* select everything                            */
#define PC_LC_NEWPARAMS     3   /* ShowFlags changed (parameter = new flags)    */
#define PC_LC_FONTPLUS      4   /* increase the font size                       */
#define PC_LC_FONTMINUS     5   /* decrease the font size                       */

/* Search flags for ListSearchText (`options`, bit mask). */
#define PC_LCS_MATCHCASE    0x0001
#define PC_LCS_WHOLEWORDS   0x0002
#define PC_LCS_BACKWARDS    0x0004
#define PC_LCS_FINDFIRST    0x0008

/* ---- Required entry points --------------------------------------------- */

/*
 * Load `fileToLoad` (UTF-8) into a new view under `parent`. `showFlags` carries
 * PC_LCP_* options. Return the plugin's content view handle, or NULL if the
 * plugin cannot (or will not) display this file — the host then tries the next
 * viewer. Detection normally runs first (see ListGetDetectString), but the host
 * may still call ListLoad speculatively, so a NULL return must be cheap.
 */
PC_LISTER_HANDLE ListLoad(PC_LISTER_HANDLE parent, char *fileToLoad, int showFlags);

/* ---- Optional entry points --------------------------------------------- */

/*
 * Reuse an existing lister view for another file (viewer cycling / next file).
 * Return PC_LISTER_OK on success or PC_LISTER_ERROR if the plugin cannot display
 * `fileToLoad` in the existing view (the host then closes it and starts over).
 */
int ListLoadNext(PC_LISTER_HANDLE parent, PC_LISTER_HANDLE listWin,
                 char *fileToLoad, int showFlags);

/* Destroy a lister view returned by ListLoad / reused by ListLoadNext. */
void ListCloseWindow(PC_LISTER_HANDLE listWin);

/*
 * Write the plugin's detect string (UTF-8, SPEC-012 §6 grammar) into
 * `detectString` (capacity `maxlen`, NUL-terminated on return). The host
 * evaluates it against a file to decide whether to offer this plugin.
 */
void ListGetDetectString(char *detectString, int maxlen);

/*
 * Search for `searchString` (UTF-8) in the loaded view; `options` carries PC_LCS_*
 * flags. Return PC_LISTER_OK if a match is found (and selected) or PC_LISTER_ERROR.
 */
int ListSearchText(PC_LISTER_HANDLE listWin, char *searchString, int options);

/* Handle a viewer command (PC_LC_*, with `parameter`). Return PC_LISTER_OK/ERROR. */
int ListSendCommand(PC_LISTER_HANDLE listWin, int command, int parameter);

/* Print `fileToPrint` (UTF-8). `printFlags` is reserved (pass 0). PC_LISTER_OK/ERROR. */
int ListPrint(PC_LISTER_HANDLE listWin, char *fileToPrint, int printFlags);

/*
 * Render a preview thumbnail for `fileToLoad` at up to (maxWidth x maxHeight),
 * writing PNG bytes into `outBuf` (capacity `outBufLen`). Return the number of
 * bytes written, 0 if the plugin has no thumbnail for this file, or a negative
 * value on error. This is the window-less Quick View / preview-bitmap path.
 */
int ListGetPreviewBitmap(char *fileToLoad, int maxWidth, int maxHeight,
                         void *outBuf, int outBufLen);

/* Load persisted default parameters (host passes its config dir path, UTF-8). */
void ListSetDefaultParams(char *configDir);

/* Optional API version export checked by the host during load. */
int PcGetApiVersion(void);

#ifdef __cplusplus
}
#endif

#endif /* PLX_H */
```
