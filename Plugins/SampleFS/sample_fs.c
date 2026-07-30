// SPDX-License-Identifier: Apache-2.0
/*
 * sample_fs.c - Minimal PFX (file-system) sample plugin over an in-memory tree.
 *
 * Exists mainly as a test fixture for the PFXFileSystem host adapter: it exercises
 * PfxFindFirst/Next/Close/Stat without any network. A few test-only hooks
 * (SampleFsOpenFinds / SampleFsFindNextCalls) let host tests observe streaming,
 * cancellation and handle cleanup. Read-only.
 */
#include "pfx.h"
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

int PcGetApiVersion(void) { return 1; }
int PfxGetCapabilities(void) { return PC_PFX_CAP_READ | PC_PFX_CAP_VOLATILE; }

/* ---- content-column facet (test fixture for the host pipeline) ---------- */
int PfxContentFieldCount(void) { return 2; }
void PfxContentField(int index, PfxFieldInfo *out) {
    if (!out) return;
    memset(out, 0, sizeof(*out));
    if (index == 0) { strcpy(out->name, "kind");  strcpy(out->title, "Kind");   out->type = PFX_FT_STRING;  out->defaultWidth = 80; }
    else            { strcpy(out->name, "score"); strcpy(out->title, "Score");  out->type = PFX_FT_NUMERIC; out->defaultWidth = 60; }
}
/* Row = "<kind>\t<score>". kind = "dir"/"file"; score = name length. */
int PfxContentGetRow(void *conn, const char *path, char *out, int maxlen) {
    (void)conn;
    if (!path || !out) return 0;
    const char *leaf = strrchr(path, '/'); leaf = leaf ? leaf + 1 : path;
    const char *kind = (strcmp(path, "/") == 0 || strcmp(path, "/sub") == 0 || strcmp(path, "/empty") == 0) ? "dir" : "file";
    snprintf(out, (size_t)maxlen, "%s\t%d", kind, (int)strlen(leaf));
    return 1;
}

/* One static connection token (a non-NULL handle is all the host needs). */
static int g_conn = 1;
void  PfxConnect_unused(void) {}
void *PfxConnect(const PfxHostServices *services) { (void)services; return &g_conn; }
void  PfxDisconnect(void *conn) { (void)conn; }
int   PfxConnectionId(void *conn, char *out, int maxlen) {
    (void)conn; if (out && maxlen > 0) { strncpy(out, "samplefs", (size_t)maxlen - 1); out[maxlen - 1] = 0; }
    return 1;
}

/* ---- in-memory tree ------------------------------------------------------ */

typedef struct { const char *name; int64_t size; int isDir; } Ent;

/* Root: a file, two subdirs (one empty), and a sentinel that emits a name that
 * fills the whole 1024-byte buffer with NO terminator (bounds-safety check). */
#define NONUL_SENTINEL "__nonul__"
static const Ent kRoot[] = {
    { "readme.txt",     12, 0 },
    { "sub",            -1, 1 },
    { "empty",          -1, 1 },
    { NONUL_SENTINEL,    7, 0 },
};
static const Ent kSub[] = {
    { "deep.txt", 5, 0 },
};

enum { DIR_ROOT, DIR_SUB, DIR_EMPTY, DIR_BIG, DIR_NONE };

/* A find handle: which directory + cursor. DIR_BIG is a synthetic 1000-entry
 * directory (names f0000..f0999) with a small per-entry delay so host tests can
 * cancel mid-stream. */
typedef struct { int dir; int index; int count; } Find;

static int g_open_finds = 0;      /* live PfxFindFirst handles (test hook) */
static int g_findnext_calls = 0;  /* total PfxFindNext calls (test hook) */
int SampleFsOpenFinds(void)     { return g_open_finds; }
int SampleFsFindNextCalls(void) { return g_findnext_calls; }
void SampleFsResetCounters(void){ g_findnext_calls = 0; }

static int dir_id(const char *dir) {
    if (!dir) return DIR_NONE;
    if (strcmp(dir, "/") == 0 || dir[0] == 0) return DIR_ROOT;
    if (strcmp(dir, "/sub") == 0)   return DIR_SUB;
    if (strcmp(dir, "/empty") == 0) return DIR_EMPTY;
    if (strcmp(dir, "/big") == 0)   return DIR_BIG;
    return DIR_NONE;
}

void *PfxFindFirst(void *conn, const char *dir) {
    (void)conn;
    int id = dir_id(dir);
    if (id == DIR_NONE) return NULL;   /* not a directory -> host maps to notFound */
    Find *f = (Find *)calloc(1, sizeof(Find));
    if (!f) return NULL;
    f->dir = id;
    f->index = 0;
    switch (id) {
        case DIR_ROOT:  f->count = (int)(sizeof(kRoot) / sizeof(kRoot[0])); break;
        case DIR_SUB:   f->count = (int)(sizeof(kSub)  / sizeof(kSub[0]));  break;
        case DIR_EMPTY: f->count = 0;    break;
        case DIR_BIG:   f->count = 1000; break;
    }
    g_open_finds++;
    return f;
}

int PfxFindNext(void *find, PfxFindData *out) {
    if (!find || !out) return 0;
    Find *f = (Find *)find;
    g_findnext_calls++;
    if (f->index >= f->count) return 0;

    memset(out, 0, sizeof(*out));
    if (f->dir == DIR_BIG) {
        snprintf(out->name, sizeof(out->name), "f%04d", f->index);
        out->size = f->index;
        out->isDir = 0;
        usleep(300);   /* ~0.3ms so a 1000-entry walk is cancellable mid-stream */
    } else {
        const Ent *e = (f->dir == DIR_ROOT) ? &kRoot[f->index] : &kSub[f->index];
        if (strcmp(e->name, NONUL_SENTINEL) == 0) {
            /* Deliberately fill the entire buffer with no NUL terminator. */
            memset(out->name, 'a', sizeof(out->name));
        } else {
            strncpy(out->name, e->name, sizeof(out->name) - 1);
        }
        out->size = e->size;
        out->isDir = e->isDir;
        out->mtime = 1000 + f->index;
    }
    f->index++;
    return 1;
}

void PfxFindClose(void *find) {
    if (!find) return;
    g_open_finds--;
    free(find);
}

int PfxStat(void *conn, const char *path, PfxFindData *out) {
    (void)conn;
    if (!path || !out) return PC_E_NOT_SUPPORTED;
    memset(out, 0, sizeof(*out));
    if (strcmp(path, "/readme.txt") == 0) {
        strncpy(out->name, "readme.txt", sizeof(out->name) - 1);
        out->size = 12; out->isDir = 0; out->mtime = 1000;
        return PC_OK;
    }
    if (strcmp(path, "/sub") == 0 || strcmp(path, "/") == 0) {
        strncpy(out->name, path[1] ? "sub" : "/", sizeof(out->name) - 1);
        out->size = -1; out->isDir = 1;
        return PC_OK;
    }
    return PC_E_EOPEN;
}

/* Read is unused by these tests but keeps the plugin a complete FS. */
int PfxGetFile(void *conn, const char *remote, const char *local) {
    (void)conn; (void)remote; (void)local; return PC_E_NOT_SUPPORTED;
}
