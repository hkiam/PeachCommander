// SPDX-License-Identifier: Apache-2.0
/*
 * sample_lister.c — a minimal Peach Commander PLX lister plugin (SPEC-012 §3, T02).
 *
 * A trivial "text lister": it claims .txt/.log files (via its detect string),
 * loads a file's contents into an opaque view handle, supports case-sensitive/
 * insensitive substring search, a couple of viewer commands, and a stub preview
 * that returns a PNG signature so the window-less preview path can be exercised.
 *
 * View handles here are plain malloc'd structs (not real NSViews) so the host
 * adapter and its choreography can be tested headlessly; a real plugin would
 * return an NSView*. A live-handle counter (SampleGetLiveCount) lets tests assert
 * the load/close memory lifecycle is balanced.
 *
 * It also exports the additive entry points — ListLoadEx, ListGetOutline,
 * ListGotoAnchor, ListGetText — so the host adapter is exercised against a real
 * C plugin *before* any shipping plugin depends on them. That order matters: an
 * ABI designed against one caller tends to fit only that caller.
 *
 * The outline it produces is deliberately trivial (one entry per line beginning
 * with '#'), because what is under test here is the protocol — the two-call
 * sizing, the tab-separated rows, the anchor round-trip — and not anybody's idea
 * of what a heading is.
 */

#include "plx.h"
/* For PcHostServices, so ListLoadEx can actually *read* the context rather than only
 * confirm a pointer arrived. plx.h forward-declares the struct; this completes it. */
#include "contrib.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* Count of currently-open views, for lifecycle tests. */
static int g_live = 0;

typedef struct {
    char  *text;   /* file contents (NUL-terminated)          */
    size_t len;
    /* Where ListGotoAnchor last landed, so a test can see that the call reached the
     * view rather than only that it returned OK. */
    int    scrolledToLine;
    /* Whether the host handed over its services table, and what it said the surface
     * was — the two facts ListLoadEx exists to deliver. */
    int    gotServices;
    char   surface[32];
} SLView;

/* Read a whole file into a freshly-malloc'd, NUL-terminated buffer. */
static char *slurp_text(const char *path, size_t *outLen) {
    FILE *fp = fopen(path, "rb");
    if (!fp) return NULL;
    fseek(fp, 0, SEEK_END);
    long sz = ftell(fp);
    if (sz < 0) { fclose(fp); return NULL; }
    fseek(fp, 0, SEEK_SET);
    char *buf = (char *)malloc((size_t)sz + 1);
    if (!buf) { fclose(fp); return NULL; }
    size_t got = fread(buf, 1, (size_t)sz, fp);
    fclose(fp);
    buf[got] = '\0';
    if (outLen) *outLen = got;
    return buf;
}

/* Case-insensitive substring search (haystack/needle NUL-terminated). */
static const char *ci_strstr(const char *hay, const char *needle) {
    if (!*needle) return hay;
    for (; *hay; hay++) {
        const char *h = hay, *n = needle;
        while (*h && *n && tolower((unsigned char)*h) == tolower((unsigned char)*n)) { h++; n++; }
        if (!*n) return hay;
    }
    return NULL;
}

/* Write at most `maxlen` bytes of `src` into `out`, NUL-terminated, and return the
 * length `src` needs. With out == NULL this is a pure "how much would you need",
 * which is the first half of the ABI's two-call sizing protocol. */
static int sized_copy(const char *src, char *out, int maxlen) {
    int need = (int)strlen(src);
    if (!out) return need;
    if (maxlen <= 0) return -1;
    int n = need < maxlen - 1 ? need : maxlen - 1;
    memcpy(out, src, (size_t)n);
    out[n] = '\0';
    return n;
}

/* The line an anchor names. Anchors here are "h<line>" — opaque to the host by
 * contract, and readable here on purpose: a test that has to decode base64 to see
 * what went wrong is a test nobody reads. */
static int sl_anchor_line(const char *anchor) {
    if (!anchor || anchor[0] != 'h') return 0;
    int want = atoi(anchor + 1);
    return want > 0 ? want : 0;
}

/* ---- required PLX export ------------------------------------------------ */

PC_LISTER_HANDLE ListLoad(PC_LISTER_HANDLE parent, char *fileToLoad, int showFlags) {
    (void)parent; (void)showFlags;
    size_t len = 0;
    char *text = slurp_text(fileToLoad, &len);
    if (!text) return NULL;                 /* cannot display -> host tries next */
    SLView *v = (SLView *)calloc(1, sizeof(SLView));
    if (!v) { free(text); return NULL; }
    v->text = text;
    v->len = len;
    g_live++;
    return (PC_LISTER_HANDLE)v;
}

/* ---- optional PLX exports ----------------------------------------------- */

int ListLoadNext(PC_LISTER_HANDLE parent, PC_LISTER_HANDLE listWin,
                 char *fileToLoad, int showFlags) {
    (void)parent; (void)showFlags;
    SLView *v = (SLView *)listWin;
    if (!v) return PC_LISTER_ERROR;
    size_t len = 0;
    char *text = slurp_text(fileToLoad, &len);
    if (!text) return PC_LISTER_ERROR;
    free(v->text);
    v->text = text;
    v->len = len;
    return PC_LISTER_OK;
}

void ListCloseWindow(PC_LISTER_HANDLE listWin) {
    SLView *v = (SLView *)listWin;
    if (!v) return;
    free(v->text);
    free(v);
    g_live--;
}

void ListGetDetectString(char *detectString, int maxlen) {
    if (!detectString || maxlen <= 0) return;
    const char *ds = "EXT=\"TXT\" | EXT=\"LOG\"";
    strncpy(detectString, ds, (size_t)maxlen - 1);
    detectString[maxlen - 1] = '\0';
}

int ListSearchText(PC_LISTER_HANDLE listWin, char *searchString, int options) {
    SLView *v = (SLView *)listWin;
    if (!v || !searchString) return PC_LISTER_ERROR;
    const char *found = (options & PC_LCS_MATCHCASE)
        ? strstr(v->text, searchString)
        : ci_strstr(v->text, searchString);
    return found ? PC_LISTER_OK : PC_LISTER_ERROR;
}

int ListSendCommand(PC_LISTER_HANDLE listWin, int command, int parameter) {
    (void)parameter;
    if (!listWin) return PC_LISTER_ERROR;
    switch (command) {
    case PC_LC_COPY:
    case PC_LC_SELECTALL:
    case PC_LC_NEWPARAMS:
    case PC_LC_FONTPLUS:
    case PC_LC_FONTMINUS:
    case PC_LC_RELOAD:
    case PC_LC_THEMECHANGED:
        return PC_LISTER_OK;
    default:
        return PC_LISTER_ERROR;
    }
}

int ListPrint(PC_LISTER_HANDLE listWin, char *fileToPrint, int printFlags) {
    (void)fileToPrint; (void)printFlags;
    return listWin ? PC_LISTER_OK : PC_LISTER_ERROR;
}

int ListGetPreviewBitmap(char *fileToLoad, int maxWidth, int maxHeight,
                         void *outBuf, int outBufLen) {
    (void)maxWidth; (void)maxHeight;
    /* A real plugin would render a thumbnail; here we emit a PNG signature so the
     * preview plumbing is verifiable. Refuse if the file cannot be opened. */
    FILE *fp = fopen(fileToLoad, "rb");
    if (!fp) return -1;
    fclose(fp);
    static const unsigned char png_sig[8] = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
    if (outBufLen < (int)sizeof(png_sig)) return -1;
    memcpy(outBuf, png_sig, sizeof(png_sig));
    return (int)sizeof(png_sig);
}

/* As ListLoad, plus the services table. Records what the host said the surface was,
 * so a test can prove the context arrived rather than only that the call worked. */
PC_LISTER_HANDLE ListLoadEx(PC_LISTER_HANDLE parent, const char *fileToLoad,
                            int showFlags, const struct PcHostServices *services) {
    SLView *v = (SLView *)ListLoad(parent, (char *)fileToLoad, showFlags);
    if (!v) return NULL;
    v->gotServices = services != NULL;
    v->surface[0] = '\0';
    if (services && services->getContext) {
        /* The whole point of the call: which of the host's four surfaces this view is
         * about to be embedded in. Recorded verbatim so a test asserts the string the
         * host published, not an interpretation of it. */
        if (!services->getContext(services->host, "lister.surface",
                                  v->surface, (int)sizeof(v->surface))) {
            v->surface[0] = '\0';
        }
    }
    return (PC_LISTER_HANDLE)v;
}

/* One outline row per line starting with '#': "<depth>\t<line>\t<anchor>\t<title>". */
int ListGetOutline(PC_LISTER_HANDLE listWin, char *out, int maxlen) {
    SLView *v = (SLView *)listWin;
    if (!v) return -1;
    /* Built into a heap buffer first, because the size has to be known before the
     * caller can be told it — the same reason the ABI asks twice. */
    size_t cap = v->len + 256, used = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) return -1;
    buf[0] = '\0';
    int line = 1;
    const char *p = v->text;
    while (p && *p) {
        const char *eol = strchr(p, '\n');
        size_t n = eol ? (size_t)(eol - p) : strlen(p);
        if (n > 0 && p[0] == '#') {
            int depth = 0;
            while ((size_t)depth < n && p[depth] == '#') depth++;
            const char *title = p + depth;
            size_t tlen = n - (size_t)depth;
            while (tlen > 0 && *title == ' ') { title++; tlen--; }
            /* 32 covers "<depth>\t<line>\th<line>\t" for any plausible file. */
            if (used + tlen + 64 < cap) {
                used += (size_t)snprintf(buf + used, cap - used, "%d\t%d\th%d\t%.*s\n",
                                         depth - 1, line, line, (int)tlen, title);
            }
        }
        if (!eol) break;
        p = eol + 1;
        line++;
    }
    int rc = sized_copy(buf, out, maxlen);
    free(buf);
    return rc;
}

int ListGotoAnchor(PC_LISTER_HANDLE listWin, const char *anchor) {
    SLView *v = (SLView *)listWin;
    if (!v) return PC_LISTER_ERROR;
    int line = sl_anchor_line(anchor);
    if (line <= 0) return PC_LISTER_ERROR;
    v->scrolledToLine = line;
    return PC_LISTER_OK;
}

int ListGetText(PC_LISTER_HANDLE listWin, char *out, int maxlen) {
    SLView *v = (SLView *)listWin;
    if (!v) return -1;
    return sized_copy(v->text, out, maxlen);
}

int PcGetApiVersion(void) { return PC_API_VERSION; }

/* Test-only helpers (not part of the PLX ABI). */
int SampleGetLiveCount(void) { return g_live; }
/* Which line ListGotoAnchor last scrolled to, and whether ListLoadEx got a table —
 * the two effects that are otherwise invisible from outside the plugin. */
int SampleGetScrolledLine(PC_LISTER_HANDLE listWin) {
    SLView *v = (SLView *)listWin;
    return v ? v->scrolledToLine : -1;
}
int SampleGotServices(PC_LISTER_HANDLE listWin) {
    SLView *v = (SLView *)listWin;
    return v ? v->gotServices : -1;
}
/* The `lister.surface` the host published at load time, or "" if it published none. */
const char *SampleGetSurface(PC_LISTER_HANDLE listWin) {
    SLView *v = (SLView *)listWin;
    return v ? v->surface : "";
}
