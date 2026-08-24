// SPDX-License-Identifier: Apache-2.0
/*
 * plx.h — Peach Commander lister plugins (PLX), a WLX port (SPEC-012 §3, F-238).
 *
 * A PLX plugin renders a file into a custom view for Lister (F3) and Quick View,
 * and can also produce a preview thumbnail without a window. Self-contained C11 on
 * top of pc_common.h.
 *
 * Required exports: ListLoad.
 * Optional exports: ListLoadEx, ListLoadNext, ListCloseWindow, ListGetDetectString,
 *                   ListSearchText, ListSendCommand, ListPrint,
 *                   ListGetPreviewBitmap, ListGetOutline, ListGotoAnchor,
 *                   ListGetText, ListSetDefaultParams, PcGetApiVersion.
 *
 * View handles (PC_LISTER_HANDLE) are opaque `void *`. On macOS they are NSView*
 * cast to void*: the host passes the parent container view to ListLoad and the
 * plugin returns its own content view, or NULL if it cannot display the file.
 * The host owns display; the plugin owns the returned view until ListCloseWindow.
 * All char* are UTF-8.
 *
 * ---- Everything below the required export is additive ----------------------
 *
 * A lister used to serve exactly one surface — the F3 window — because that is
 * all `ListLoad(parent, path, showFlags)` can describe. The host has three more
 * that want the same renderer: the side panel's Info page, the embedded Quick
 * View, and the gallery's thumbnails. The additions below are what those four
 * surfaces need, and deliberately nothing else: each one is here because a
 * surface that exists in the host today would otherwise lose a feature.
 *
 * They are all OPTIONAL. A plugin exporting only ListLoad keeps working exactly
 * as before and simply does not gain the capability it does not export — the
 * host checks each symbol before calling it.
 *
 * Extensibility lives in ListLoadEx's `services` table, not in this header: a
 * lister can read any context key the host publishes (see contrib.h getContext),
 * so the next piece of context costs a key rather than an ABI break.
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

/* The host services table, defined in contrib.h and passed to ListLoadEx.
 *
 * Declared rather than included on purpose: this header must compile standalone
 * as C11 (Tools/check-sdk-headers.sh proves it on every run), and a lister that
 * ignores `services` should not have to know what is in it. A plugin that wants
 * to read it includes contrib.h as well — the two declarations agree. */
struct PcHostServices;

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
#define PC_LC_RELOAD        6   /* re-read the file from disk (the viewer's reload)  */
#define PC_LC_THEMECHANGED  7   /* the host's colour theme changed; re-read theme.* */

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
 * As ListLoad, and preferred over it when exported: the host also hands over its
 * services table, so a lister gets the same context every contribution plugin
 * already has — `configRoot`, the `theme.*` colours, and the keys below.
 *
 * The host calls this when the symbol is present and falls back to ListLoad
 * otherwise, so exporting both is unnecessary; exporting only ListLoad stays
 * valid forever.
 *
 * Keys the host answers for a lister, in addition to the usual ones:
 *
 *   lister.surface   "viewer"   — the F3 window
 *                    "preview"  — the side panel's Info page
 *                    "quickview"— the embedded Quick View (Ctrl+Q)
 *   lister.width     width of the container, in points, as decimal text
 *   lister.height    height of the container, in points
 *
 * The surface is why this exists: a renderer that puts a filter row and a
 * toolbar above its content is right in a window and wrong in a 200-point
 * column, and `showFlags` has no room to say which one it is.
 *
 * `services` may be NULL — a host that has no table to offer still loads the
 * file — so every read of it must be guarded.
 */
PC_LISTER_HANDLE ListLoadEx(PC_LISTER_HANDLE parent, const char *fileToLoad,
                            int showFlags, const struct PcHostServices *services);

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

/*
 * The structure of the loaded document, for the viewer's symbol sidebar: one
 * entry per line, tab-separated, no trailing tab —
 *
 *     <depth>\t<sourceLine>\t<anchor>\t<title>\n
 *
 * `depth` is 0-based nesting, `sourceLine` is 1-based (0 when the plugin has no
 * line to name), `anchor` is an opaque token this plugin will accept back in
 * ListGotoAnchor, and `title` is what the sidebar shows. Line-oriented rather
 * than JSON because that is what the host's own outline dumps already compare,
 * so a plugin's outline and a built-in one are diffable against each other.
 *
 * Called with `out` NULL to ask for the required size (excluding the NUL), which
 * is the only way a caller can size a buffer for a document it has not read.
 * Returns the number of bytes written (or required), or a negative value on
 * error. A plugin without an outline returns 0 and writes nothing.
 */
int ListGetOutline(PC_LISTER_HANDLE listWin, char *out, int maxlen);

/*
 * Scroll the loaded view to an `anchor` that came from ListGetOutline. Return
 * PC_LISTER_OK if the anchor was found, PC_LISTER_ERROR otherwise.
 *
 * Separate from the outline because the two happen at different times and the
 * host holds nothing in between: it asks for the structure once per file and
 * navigates whenever the reader clicks a row.
 */
int ListGotoAnchor(PC_LISTER_HANDLE listWin, const char *anchor);

/*
 * The plain text of what the view is showing, for the parts of the host that
 * work on text rather than pixels: the find bar's match count, Copy All, Mark
 * All and Print. Without it those are limited to what ListSearchText can answer,
 * which is "found" or "not found" and nothing else.
 *
 * As ListGetOutline: `out` NULL asks for the required size, the return value is
 * bytes written (or required) or negative on error, and 0 means "no text",
 * which is the honest answer for a plugin showing an image.
 */
int ListGetText(PC_LISTER_HANDLE listWin, char *out, int maxlen);

/* Load persisted default parameters (host passes its config dir path, UTF-8). */
void ListSetDefaultParams(char *configDir);

/* Optional API version export checked by the host during load. */
int PcGetApiVersion(void);

#ifdef __cplusplus
}
#endif

#endif /* PLX_H */
