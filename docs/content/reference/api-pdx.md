---
title: "API: Content plugins (PDX)"
slug: api-pdx
section: API reference
order: 30
related: [sdk-overview, plugin-architecture-guide]
---

# Content plugins (PDX)

> Source: `Plugins/SDK/pdx.h` — this page is generated from that header by `docs/scripts/gen-api-reference.py`; edit the header, not this page.

pdx.h — Peach Commander content plugins (PDX), a WDX port (SPEC-012 §5, F-233).

 A PDX plugin computes extra, typed "content fields" for a local file — the
 things TC's WDX plugins expose as custom columns, search criteria, and
 multi-rename placeholders (e.g. image width, MP3 bitrate, EXIF date).
 Self-contained C11 on top of pc_common.h.

 Required exports: ContentGetSupportedField, ContentGetValue.
 Optional exports: ContentSetDefaultParams, ContentPluginUnloading,
                   ContentStopGetValue, PcGetApiVersion.

 The host enumerates fields once (ContentGetSupportedField over 0,1,2,… until
 PC_FT_NOMOREFIELDS) and then pulls values per file on background workers. All
 char* are UTF-8; sizes/times are int64_t/epoch, matching pc_common.h.

## Entry points & functions

- `ContentCompareFiles`
- `ContentGetSupportedField`
- `ContentPluginUnloading`
- `ContentSetDefaultParams`
- `ContentStopGetValue`
- `PcGetApiVersion`


## Constants

| Name | Value | Meaning |
|---|---|---|
| `PC_FT_NOMOREFIELDS` | `0` | enumeration end / no such field |
| `PC_FT_NUMERIC_32` | `1` | fieldValue is int32_t |
| `PC_FT_NUMERIC_64` | `2` | fieldValue is int64_t |
| `PC_FT_NUMERIC_FLOATING` | `3` | fieldValue is double |
| `PC_FT_DATE` | `4` | fieldValue is PcContentDate |
| `PC_FT_TIME` | `5` | fieldValue is PcContentTime |
| `PC_FT_BOOLEAN` | `6` | fieldValue is int32_t (0/1) |
| `PC_FT_MULTIPLECHOICE` | `7` | fieldValue is a UTF-8 string |
| `PC_FT_STRING` | `8` | fieldValue is a UTF-8 string |
| `PC_FT_FULLTEXT` | `9` | searchable full text (string) |
| `PC_FT_DATETIME` | `10` | fieldValue is int64_t epoch seconds |
| `PC_FT_NOSUCHFIELD` | `(-1)` | fieldIndex out of range |
| `PC_FT_FILEERROR` | `(-2)` | cannot open / read the file |
| `PC_FT_FIELDEMPTY` | `(-3)` | field not present for this file |
| `PC_FT_ONDEMAND` | `(-4)` | value is expensive; fetch only on demand |
| `PC_FT_DELAYED` | `(-5)` | not ready yet; retry later (see flags) |
| `PC_CONTENT_MATCHCASE` | `0x0001` | ContentSearchText: case-sensitive match |
| `PC_CONTENT_DELAYIFSLOW` | `1` |  |
| `PC_CMP_LESS` | `(-1)` | file1 < file2 by this field |
| `PC_CMP_EQUAL` | `0` | equal |
| `PC_CMP_GREATER` | `1` | file1 > file2 by this field |
| `PC_CMP_NOTSUPPORTED` | `(-2)` | field/plugin can't compare |

## Full header

```c
// SPDX-License-Identifier: Apache-2.0
/*
 * pdx.h — Peach Commander content plugins (PDX), a WDX port (SPEC-012 §5, F-233).
 *
 * A PDX plugin computes extra, typed "content fields" for a local file — the
 * things TC's WDX plugins expose as custom columns, search criteria, and
 * multi-rename placeholders (e.g. image width, MP3 bitrate, EXIF date).
 * Self-contained C11 on top of pc_common.h.
 *
 * Required exports: ContentGetSupportedField, ContentGetValue.
 * Optional exports: ContentSetDefaultParams, ContentPluginUnloading,
 *                   ContentStopGetValue, PcGetApiVersion.
 *
 * The host enumerates fields once (ContentGetSupportedField over 0,1,2,… until
 * PC_FT_NOMOREFIELDS) and then pulls values per file on background workers. All
 * char* are UTF-8; sizes/times are int64_t/epoch, matching pc_common.h.
 */

#ifndef PDX_H
#define PDX_H

#include <stdint.h>
#include "pc_common.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ---- Field types (returned by ContentGetSupportedField / ContentGetValue) - */

#define PC_FT_NOMOREFIELDS     0   /* enumeration end / no such field          */
#define PC_FT_NUMERIC_32       1   /* fieldValue is int32_t                    */
#define PC_FT_NUMERIC_64       2   /* fieldValue is int64_t                    */
#define PC_FT_NUMERIC_FLOATING 3   /* fieldValue is double                     */
#define PC_FT_DATE             4   /* fieldValue is PcContentDate              */
#define PC_FT_TIME             5   /* fieldValue is PcContentTime              */
#define PC_FT_BOOLEAN          6   /* fieldValue is int32_t (0/1)              */
#define PC_FT_MULTIPLECHOICE   7   /* fieldValue is a UTF-8 string             */
#define PC_FT_STRING           8   /* fieldValue is a UTF-8 string             */
#define PC_FT_FULLTEXT         9   /* searchable full text (string)            */
#define PC_FT_DATETIME         10  /* fieldValue is int64_t epoch seconds      */

/* ---- Status codes (negative; returned by ContentGetValue instead of a type) */

#define PC_FT_NOSUCHFIELD  (-1)   /* fieldIndex out of range                   */
#define PC_FT_FILEERROR    (-2)   /* cannot open / read the file               */
#define PC_FT_FIELDEMPTY   (-3)   /* field not present for this file           */
#define PC_FT_ONDEMAND     (-4)   /* value is expensive; fetch only on demand  */
#define PC_FT_DELAYED      (-5)   /* not ready yet; retry later (see flags)     */

/* ---- Flags ------------------------------------------------------------- */
#define PC_CONTENT_MATCHCASE  0x0001  /* ContentSearchText: case-sensitive match  */

/* ---- ContentGetValue flags --------------------------------------------- */

/* Ask the plugin to return PC_FT_DELAYED rather than block on a slow value. */
#define PC_CONTENT_DELAYIFSLOW 1

/* Date / time value structs (used by PC_FT_DATE / PC_FT_TIME). */
typedef struct { int16_t year; int16_t month; int16_t day; } PcContentDate;
typedef struct { int16_t hour; int16_t minute; int16_t second; } PcContentTime;

/* ---- Required entry points --------------------------------------------- */

/*
 * Enumerate the fields this plugin offers. The host calls with fieldIndex 0,1,2,…
 * until the return value is PC_FT_NOMOREFIELDS. On success write the field name
 * into `fieldName` (UTF-8, capacity `maxlen`) and an optional '|'-separated list
 * of unit names into `units` (empty string if none), and return the field's
 * PC_FT_* type. Both buffers are host-owned and NUL-terminated on return.
 */
int ContentGetSupportedField(int fieldIndex, char *fieldName, char *units, int maxlen);

/*
 * Compute one field's value for `fileName` (UTF-8). `fieldIndex` selects the
 * field, `unitIndex` selects a unit variant (0 = the field's base unit).
 * Write the value into `fieldValue` (capacity `maxlen`) laid out per the field
 * type (int32/int64/double/struct/UTF-8 string) and return that PC_FT_* type,
 * or a negative PC_FT_* status code. `flags` may carry PC_CONTENT_DELAYIFSLOW.
 */
/* ---- Optional: search a full-text field without moving it -----------------
 *
 * A PC_FT_FULLTEXT field is a whole document, and fetching one through
 * ContentGetValue means copying it into the host's buffer — which caps what the
 * host can search at whatever that buffer happens to be. Export this instead and
 * the search never moves the text at all: the plugin looks inside its own result
 * and answers with the 1-based line number of the first match (0 for no match,
 * negative for "cannot answer").
 *
 * `flags` carries PC_CONTENT_MATCHCASE. `matchLine` receives the matching line's
 * text, truncated to `lineMax` — a line fits any sane buffer, a document does not.
 *
 * Hosts must treat this as optional and fall back to ContentGetValue.           */
int ContentSearchText(char *fileName, int fieldIndex, const char *needle, int flags,
                      char *matchLine, int lineMax);

int ContentGetValue(char *fileName, int fieldIndex, int unitIndex,
                    void *fieldValue, int maxlen, int flags);

/* ---- ContentCompareFiles results --------------------------------------- */
#define PC_CMP_LESS         (-1)  /* file1 < file2 by this field               */
#define PC_CMP_EQUAL          0   /* equal                                     */
#define PC_CMP_GREATER        1   /* file1 > file2 by this field               */
#define PC_CMP_NOTSUPPORTED (-2)  /* field/plugin can't compare                */

/* ---- Optional entry points --------------------------------------------- */

/*
 * Write `fieldIndex`'s value back to `fileName` (UTF-8). `fieldValue` is laid
 * out per `fieldType` exactly as ContentGetValue returns it. Return the written
 * PC_FT_* type on success, PC_FT_NOMOREFIELDS if the field is not writable, or
 * a negative PC_FT_* status code. Optional: host-side edits of plugin fields.
 */
int ContentSetValue(char *fileName, int fieldIndex, int unitIndex,
                    int fieldType, void *fieldValue, int flags);

/*
 * Compare `fileName1` vs `fileName2` by `fieldIndex` (both UTF-8). Return one of
 * PC_CMP_LESS/EQUAL/GREATER, or PC_CMP_NOTSUPPORTED. Optional: used by directory
 * synchronize to order by a plugin field.
 */
int ContentCompareFiles(int fieldIndex, char *fileName1, char *fileName2, int flags);

/* Load persisted default parameters (host passes its config dir path, UTF-8). */
void ContentSetDefaultParams(char *configDir);

/* Called before the plugin is unloaded so it can release cached resources. */
void ContentPluginUnloading(void);

/*
 * Ask the plugin to abandon any in-flight value computation for `fileName`
 * (used to cancel a PC_FT_DELAYED/ondemand fetch when the user scrolls away).
 */
void ContentStopGetValue(char *fileName);

/* Optional API version export checked by the host during load. */
int PcGetApiVersion(void);

#ifdef __cplusplus
}
#endif

#endif /* PDX_H */
```
