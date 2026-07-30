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
 */

#include "plx.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* Count of currently-open views, for lifecycle tests. */
static int g_live = 0;

typedef struct {
    char  *text;   /* file contents (NUL-terminated)          */
    size_t len;
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

int PcGetApiVersion(void) { return PC_API_VERSION; }

/* Test-only helper (not part of the PLX ABI): number of open views. */
int SampleGetLiveCount(void) { return g_live; }
