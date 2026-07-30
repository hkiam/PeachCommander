/*
 * sample_content.c — a minimal Peach Commander PDX content plugin (SPEC-012 §5, T04).
 *
 * Exposes three fields computed purely from the file's path and stat(), so the
 * content-plugin host can be exercised end-to-end (enumerate → typed values)
 * without any image/media dependency:
 *
 *   0  Size         PC_FT_NUMERIC_64  (bytes)  — st_size
 *   1  Name Length  PC_FT_NUMERIC_32           — strlen(basename)
 *   2  Extension    PC_FT_STRING               — text after the last '.'
 *
 * This is sample/reference code: deterministic and dependency-free.
 */

#include "pdx.h"
#include <string.h>
#include <sys/stat.h>
#include <sys/xattr.h>

/* The extended attribute backing the writable "Tag" field (field 3). */
static const char *PC_TAG_XATTR = "com.peachcommander.tag";

/* Return the basename (last '/'-separated component) of a UTF-8 path. */
static const char *basename_of(const char *path) {
    const char *slash = strrchr(path, '/');
    return slash ? slash + 1 : path;
}

int ContentGetSupportedField(int fieldIndex, char *fieldName, char *units, int maxlen) {
    if (!fieldName || !units || maxlen <= 0) return PC_FT_NOMOREFIELDS;
    units[0] = '\0';
    switch (fieldIndex) {
    case 0:
        strncpy(fieldName, "Size", (size_t)maxlen - 1); fieldName[maxlen - 1] = '\0';
        strncpy(units, "bytes", (size_t)maxlen - 1);     units[maxlen - 1] = '\0';
        return PC_FT_NUMERIC_64;
    case 1:
        strncpy(fieldName, "Name Length", (size_t)maxlen - 1); fieldName[maxlen - 1] = '\0';
        return PC_FT_NUMERIC_32;
    case 2:
        strncpy(fieldName, "Extension", (size_t)maxlen - 1); fieldName[maxlen - 1] = '\0';
        return PC_FT_STRING;
    case 3:
        strncpy(fieldName, "Tag", (size_t)maxlen - 1); fieldName[maxlen - 1] = '\0';
        return PC_FT_STRING;   /* writable via ContentSetValue (stored in an xattr) */
    default:
        return PC_FT_NOMOREFIELDS;
    }
}

int ContentGetValue(char *fileName, int fieldIndex, int unitIndex,
                    void *fieldValue, int maxlen, int flags) {
    (void)unitIndex; (void)flags;
    if (!fileName || !fieldValue || maxlen <= 0) return PC_FT_FILEERROR;
    switch (fieldIndex) {
    case 0: {
        struct stat st;
        if (stat(fileName, &st) != 0) return PC_FT_FILEERROR;
        int64_t size = (int64_t)st.st_size;
        memcpy(fieldValue, &size, sizeof(size));
        return PC_FT_NUMERIC_64;
    }
    case 1: {
        int32_t len = (int32_t)strlen(basename_of(fileName));
        memcpy(fieldValue, &len, sizeof(len));
        return PC_FT_NUMERIC_32;
    }
    case 2: {
        const char *base = basename_of(fileName);
        const char *dot = strrchr(base, '.');
        const char *ext = (dot && dot != base) ? dot + 1 : "";
        strncpy((char *)fieldValue, ext, (size_t)maxlen - 1);
        ((char *)fieldValue)[maxlen - 1] = '\0';
        return PC_FT_STRING;
    }
    case 3: {
        ssize_t n = getxattr(fileName, PC_TAG_XATTR, fieldValue, (size_t)maxlen - 1, 0, 0);
        if (n < 0) n = 0;                          /* no tag set → empty string */
        ((char *)fieldValue)[n] = '\0';
        return PC_FT_STRING;
    }
    default:
        return PC_FT_NOSUCHFIELD;
    }
}

/* Only the "Tag" field is writable; it persists in an extended attribute. */
int ContentSetValue(char *fileName, int fieldIndex, int unitIndex,
                    int fieldType, void *fieldValue, int flags) {
    (void)unitIndex; (void)fieldType; (void)flags;
    if (!fileName || !fieldValue) return PC_FT_FILEERROR;
    if (fieldIndex != 3) return PC_FT_NOMOREFIELDS;   /* not writable */
    const char *tag = (const char *)fieldValue;
    if (setxattr(fileName, PC_TAG_XATTR, tag, strlen(tag), 0, 0) != 0) return PC_FT_FILEERROR;
    return PC_FT_STRING;
}

/* Compare by Size (field 0). Other fields are declared not comparable. */
int ContentCompareFiles(int fieldIndex, char *fileName1, char *fileName2, int flags) {
    (void)flags;
    if (fieldIndex != 0) return PC_CMP_NOTSUPPORTED;
    struct stat a, b;
    if (stat(fileName1, &a) != 0 || stat(fileName2, &b) != 0) return PC_CMP_NOTSUPPORTED;
    if (a.st_size < b.st_size) return PC_CMP_LESS;
    if (a.st_size > b.st_size) return PC_CMP_GREATER;
    return PC_CMP_EQUAL;
}

int PcGetApiVersion(void) { return PC_API_VERSION; }
