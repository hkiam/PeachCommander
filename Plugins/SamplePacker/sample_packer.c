// SPDX-License-Identifier: Apache-2.0
/*
 * sample_packer.c — a minimal Peach Commander PCX packer plugin (SPEC-012 §7, T04).
 *
 * Implements a trivial uncompressed ".pak" container so the plugin host can be
 * exercised end-to-end (browse / extract / pack / delete) exactly like the
 * built-in zip support. Format:
 *
 *   magic  : 4 bytes "PAK1"
 *   repeat : uint32 nameLen | name bytes (UTF-8) | int64 dataLen | data bytes
 *
 * All multi-byte integers are little-endian. This is sample/reference code:
 * simple and memory-based rather than streaming.
 */

#include "pcx.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PAK_MAGIC "PAK1"

/* ---- open-archive iteration state --------------------------------------- */
typedef struct {
    FILE   *fp;
    int64_t curDataOffset;   /* start of the current entry's data          */
    int64_t curDataSize;     /* size of the current entry's data           */
} SPArc;

static int read_u32(FILE *f, uint32_t *out) {
    unsigned char b[4];
    if (fread(b, 1, 4, f) != 4) return 0;
    *out = (uint32_t)b[0] | ((uint32_t)b[1] << 8) | ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
    return 1;
}
static int read_i64(FILE *f, int64_t *out) {
    unsigned char b[8]; uint64_t v = 0;
    if (fread(b, 1, 8, f) != 8) return 0;
    for (int i = 0; i < 8; i++) v |= (uint64_t)b[i] << (8 * i);
    *out = (int64_t)v; return 1;
}
static void write_u32(FILE *f, uint32_t v) {
    unsigned char b[4] = { (unsigned char)(v), (unsigned char)(v >> 8),
                           (unsigned char)(v >> 16), (unsigned char)(v >> 24) };
    fwrite(b, 1, 4, f);
}
static void write_i64(FILE *f, int64_t sv) {
    uint64_t v = (uint64_t)sv; unsigned char b[8];
    for (int i = 0; i < 8; i++) b[i] = (unsigned char)(v >> (8 * i));
    fwrite(b, 1, 8, f);
}

/* ---- required PCX exports ----------------------------------------------- */

PC_HANDLE OpenArchive(PcOpenArchiveData *data) {
    FILE *fp = fopen(data->arcName, "rb");
    if (!fp) { data->openResult = PC_E_EOPEN; return NULL; }
    char magic[4];
    if (fread(magic, 1, 4, fp) != 4 || memcmp(magic, PAK_MAGIC, 4) != 0) {
        fclose(fp); data->openResult = PC_E_BAD_ARCHIVE; return NULL;
    }
    SPArc *a = (SPArc *)calloc(1, sizeof(SPArc));
    a->fp = fp;
    data->openResult = PC_OK;
    return (PC_HANDLE)a;
}

int ReadHeaderEx(PC_HANDLE hArc, PcHeaderDataEx *hdr) {
    SPArc *a = (SPArc *)hArc;
    uint32_t nameLen;
    if (!read_u32(a->fp, &nameLen)) return PC_E_END_ARCHIVE;   /* clean EOF */
    if (nameLen == 0 || nameLen >= sizeof(hdr->fileName)) return PC_E_BAD_DATA;
    memset(hdr, 0, sizeof(*hdr));
    if (fread(hdr->fileName, 1, nameLen, a->fp) != nameLen) return PC_E_BAD_DATA;
    hdr->fileName[nameLen] = '\0';
    int64_t dataLen;
    if (!read_i64(a->fp, &dataLen)) return PC_E_BAD_DATA;
    a->curDataOffset = ftello(a->fp);
    a->curDataSize   = dataLen;
    hdr->unpSize  = dataLen;
    hdr->packSize = dataLen;
    hdr->fileTime = 0;
    return PC_OK;
}

int ProcessFile(PC_HANDLE hArc, int operation, char *destPath, char *destName) {
    (void)destPath;
    SPArc *a = (SPArc *)hArc;
    if (operation == PC_SKIP || operation == PC_TEST) {
        fseeko(a->fp, a->curDataOffset + a->curDataSize, SEEK_SET);
        return PC_OK;
    }
    if (operation == PC_EXTRACT && destName) {
        fseeko(a->fp, a->curDataOffset, SEEK_SET);
        FILE *out = fopen(destName, "wb");
        if (!out) return PC_E_ECREATE;
        int64_t remaining = a->curDataSize;
        char buf[8192];
        while (remaining > 0) {
            size_t chunk = remaining > (int64_t)sizeof(buf) ? sizeof(buf) : (size_t)remaining;
            size_t got = fread(buf, 1, chunk, a->fp);
            if (got == 0) { fclose(out); return PC_E_EREAD; }
            fwrite(buf, 1, got, out);
            remaining -= (int64_t)got;
        }
        fclose(out);
        return PC_OK;
    }
    return PC_OK;
}

int CloseArchive(PC_HANDLE hArc) {
    SPArc *a = (SPArc *)hArc;
    if (a) { if (a->fp) fclose(a->fp); free(a); }
    return PC_OK;
}

void SetChangeVolProc(PC_HANDLE hArc, PcChangeVolProc proc) { (void)hArc; (void)proc; }
void SetProcessDataProc(PC_HANDLE hArc, PcProcessDataProc proc) { (void)hArc; (void)proc; }

/* ---- optional PCX exports: pack / delete / caps ------------------------- */

/* In-memory entry used while rewriting the archive. */
typedef struct { char *name; unsigned char *data; int64_t size; } Entry;

static int load_all(const char *path, Entry **outEntries, int *outCount) {
    *outEntries = NULL; *outCount = 0;
    FILE *fp = fopen(path, "rb");
    if (!fp) return 1;               /* absent = empty archive (create on write) */
    char magic[4];
    if (fread(magic, 1, 4, fp) != 4 || memcmp(magic, PAK_MAGIC, 4) != 0) { fclose(fp); return 0; }
    Entry *entries = NULL; int count = 0, cap = 0;
    for (;;) {
        uint32_t nameLen;
        if (!read_u32(fp, &nameLen)) break;
        if (nameLen == 0 || nameLen > 4096) { fclose(fp); return 0; }
        char *name = (char *)malloc(nameLen + 1);
        if (fread(name, 1, nameLen, fp) != nameLen) { free(name); fclose(fp); return 0; }
        name[nameLen] = '\0';
        int64_t dataLen;
        if (!read_i64(fp, &dataLen) || dataLen < 0) { free(name); fclose(fp); return 0; }
        unsigned char *data = (unsigned char *)malloc((size_t)dataLen);
        if (dataLen > 0 && fread(data, 1, (size_t)dataLen, fp) != (size_t)dataLen) {
            free(name); free(data); fclose(fp); return 0;
        }
        if (count == cap) { cap = cap ? cap * 2 : 8; entries = realloc(entries, cap * sizeof(Entry)); }
        entries[count].name = name; entries[count].data = data; entries[count].size = dataLen;
        count++;
    }
    fclose(fp);
    *outEntries = entries; *outCount = count;
    return 1;
}

static void free_all(Entry *entries, int count) {
    for (int i = 0; i < count; i++) { free(entries[i].name); free(entries[i].data); }
    free(entries);
}

static int write_all(const char *path, Entry *entries, int count) {
    FILE *fp = fopen(path, "wb");
    if (!fp) return PC_E_ECREATE;
    fwrite(PAK_MAGIC, 1, 4, fp);
    for (int i = 0; i < count; i++) {
        write_u32(fp, (uint32_t)strlen(entries[i].name));
        fwrite(entries[i].name, 1, strlen(entries[i].name), fp);
        write_i64(fp, entries[i].size);
        if (entries[i].size > 0) fwrite(entries[i].data, 1, (size_t)entries[i].size, fp);
    }
    fclose(fp);
    return PC_OK;
}

/* Read a whole file into a freshly-malloc'd buffer. */
static unsigned char *slurp(const char *path, int64_t *outSize) {
    FILE *fp = fopen(path, "rb");
    if (!fp) return NULL;
    fseeko(fp, 0, SEEK_END); int64_t sz = ftello(fp); fseeko(fp, 0, SEEK_SET);
    unsigned char *buf = (unsigned char *)malloc(sz > 0 ? (size_t)sz : 1);
    if (sz > 0 && fread(buf, 1, (size_t)sz, fp) != (size_t)sz) { free(buf); fclose(fp); return NULL; }
    fclose(fp); *outSize = sz; return buf;
}

static void set_or_add(Entry **entries, int *count, int *cap,
                       const char *name, unsigned char *data, int64_t size) {
    for (int i = 0; i < *count; i++) {
        if (strcmp((*entries)[i].name, name) == 0) {   /* replace existing */
            free((*entries)[i].data); (*entries)[i].data = data; (*entries)[i].size = size; return;
        }
    }
    if (*count == *cap) { *cap = *cap ? *cap * 2 : 8; *entries = realloc(*entries, *cap * sizeof(Entry)); }
    (*entries)[*count].name = strdup(name);
    (*entries)[*count].data = data; (*entries)[*count].size = size;
    (*count)++;
}

int PackFiles(char *packedFile, char *subPath, char *srcPath, char *addList, int flags) {
    (void)flags;
    Entry *entries = NULL; int count = 0;
    if (!load_all(packedFile, &entries, &count)) return PC_E_BAD_ARCHIVE;
    int cap = count;
    for (char *p = addList; *p; p += strlen(p) + 1) {
        char full[4096];
        snprintf(full, sizeof(full), "%s/%s", srcPath, p);
        int64_t sz = 0;
        unsigned char *data = slurp(full, &sz);
        if (!data) { free_all(entries, count); return PC_E_EOPEN; }
        char stored[4096];
        if (subPath && subPath[0]) snprintf(stored, sizeof(stored), "%s/%s", subPath, p);
        else snprintf(stored, sizeof(stored), "%s", p);
        set_or_add(&entries, &count, &cap, stored, data, sz);
    }
    int rc = write_all(packedFile, entries, count);
    free_all(entries, count);
    return rc;
}

int DeleteFiles(char *packedFile, char *deleteList) {
    Entry *entries = NULL; int count = 0;
    if (!load_all(packedFile, &entries, &count) || count == 0) return PC_E_BAD_ARCHIVE;
    int kept = 0;
    for (int i = 0; i < count; i++) {
        int remove = 0;
        for (char *p = deleteList; *p; p += strlen(p) + 1) {
            if (strcmp(entries[i].name, p) == 0) { remove = 1; break; }
        }
        if (remove) { free(entries[i].name); free(entries[i].data); }
        else entries[kept++] = entries[i];
    }
    int rc = write_all(packedFile, entries, kept);
    free(entries);
    return rc;
}

int GetPackerCaps(void) {
    return PC_CAP_NEW | PC_CAP_MODIFY | PC_CAP_MULTIPLE | PC_CAP_DELETE;
}

int PcGetApiVersion(void) { return PC_API_VERSION; }
