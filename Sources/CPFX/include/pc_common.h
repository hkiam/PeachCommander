// SPDX-License-Identifier: Apache-2.0
/*
 * pc_common.h — Peach Commander plugin SDK, common definitions (SPEC-012 §1, §7).
 *
 * Shared by all plugin types (pcx/pfx/plx/pdx). This header is self-contained
 * C11 — it pulls in only <stdint.h> and needs no Apple frameworks.
 *
 * ABI conventions (mirrors TC's WCX/WFX/WLX/WDX so plugins can be source-ported,
 * but modernised for macOS):
 *   - All strings crossing the ABI are UTF-8, NUL-terminated `char *`.
 *     (TC's ANSI/W dual entry points collapse to a single UTF-8 API.)
 *   - Sizes and offsets are int64_t; there is no 32/64 split.
 *   - Times are Unix epoch seconds as int64_t (TC's FILETIME is gone).
 *   - Booleans are `int` (0 = false, non-zero = true).
 *   - Opaque handles are `void *`; 0 / NULL means "invalid".
 *
 * Threading: the host serialises calls per plugin instance unless the plugin
 * advertises PC_CAP_MULTITHREAD via its caps/background-flags export. See §1.
 *
 * Versioning: the current plugin API version is PC_API_VERSION. A plugin may
 * export `int PcGetApiVersion(void)`; if present the host checks it during load.
 */

#ifndef PC_COMMON_H
#define PC_COMMON_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Current plugin API version. Bump on any incompatible ABI change. */
#define PC_API_VERSION 1

/* ---- Common callback return / operation codes -------------------------- */

/* Progress callback return value: return 0 to abort the running operation. */
#define PC_CONTINUE 1
#define PC_ABORT    0

/* ProcessFile operation codes (PCX). */
#define PC_SKIP     0   /* skip this file (advance the read position only)    */
#define PC_TEST     1   /* test the file (read + verify, no output written)   */
#define PC_EXTRACT  2   /* extract the file to destPath/destName              */

/* Generic plugin error codes (returned by pcx / pfx entry points).          */
#define PC_OK              0
#define PC_E_END_ARCHIVE   10  /* no more headers (ReadHeader reached the end)*/
#define PC_E_NO_MEMORY     11
#define PC_E_BAD_DATA      12  /* CRC / structural error                      */
#define PC_E_BAD_ARCHIVE   13
#define PC_E_UNKNOWN_FMT   14
#define PC_E_EOPEN         15  /* cannot open the source/archive file         */
#define PC_E_ECREATE       16  /* cannot create the target file               */
#define PC_E_ECLOSE        17
#define PC_E_EREAD         18
#define PC_E_EWRITE        19
#define PC_E_SMALL_BUF     20
#define PC_E_EABORTED      21  /* user aborted via the progress callback      */
#define PC_E_NO_FILES      22
#define PC_E_TOO_MANY      23
#define PC_E_NOT_SUPPORTED 24  /* optional operation not implemented          */
/* The connection this plugin was serving is gone — the server stopped answering, the
   socket died, the session timed out. Distinct from PC_E_EOPEN on purpose: that says
   "no such file", and a file-system plugin that reports a dead connection as a missing
   file sends the user looking for something that is exactly where they left it. The
   host treats this one as the end of the mount: it leaves the drive, drops its entry
   from the drive bar, and says which server went away. Return it from any entry point
   once the connection cannot serve another request.                            */
#define PC_E_CONNECTION_LOST 25

/* ---- Capability flags (advertised by GetPackerCaps etc.) --------------- */

#define PC_CAP_NEW        0x0001  /* can create new archives                  */
#define PC_CAP_MODIFY     0x0002  /* can add/move files to an existing archive*/
#define PC_CAP_MULTIPLE   0x0004  /* archive can hold multiple files          */
#define PC_CAP_DELETE     0x0008  /* can delete files from an archive         */
#define PC_CAP_OPTIONS    0x0010  /* has a configuration dialog               */
#define PC_CAP_MEMPACK    0x0020  /* supports the StartMemPack API            */
#define PC_CAP_BY_CONTENT 0x0040  /* CanYouHandleThisFile detects by content  */
#define PC_CAP_SEARCHTEXT 0x0080  /* archive contents are searchable as text  */
#define PC_CAP_HIDE       0x0100  /* do not show as a separate packer         */
#define PC_CAP_ENCRYPT    0x0200  /* supports encryption                      */
#define PC_CAP_MULTITHREAD 0x0400 /* host need not serialise calls            */

/* ---- Common callback typedefs ------------------------------------------ */

/*
 * Progress callback. `fileName` is the item being processed (UTF-8, may be
 * NULL). `size` is a signed byte delta: TC semantics — a positive value adds to
 * the current file's progress, a negative value (-1000..0) is a permille of the
 * total. Return PC_CONTINUE to proceed or PC_ABORT to cancel.
 */
typedef int (*PcProcessDataProc)(char *fileName, int64_t size);

/*
 * Change-volume callback for multi-volume archives. `arcName` is an in/out
 * buffer holding the next volume's path (UTF-8). `mode` is one of the
 * PC_VOL_* values. Return PC_CONTINUE / PC_ABORT.
 */
#define PC_VOL_ASK    0  /* ask the user for the next volume        */
#define PC_VOL_NOTIFY 1  /* just notify that a volume changed       */
typedef int (*PcChangeVolProc)(char *arcName, int mode);

/*
 * Crypto callback: the plugin calls this to ask the host to store/load a
 * password (Keychain-backed). `mode` selects load/save/delete; `store` is the
 * archive/connection name; `password` is an in/out UTF-8 buffer of `maxlen`.
 * Return PC_OK or a PC_E_* code.
 */
#define PC_CRYPT_SAVE_PASSWORD 1
#define PC_CRYPT_LOAD_PASSWORD 2
#define PC_CRYPT_COPY_PASSWORD 3   /* load without prompting                  */
#define PC_CRYPT_DELETE        4
typedef int (*PcCryptProc)(int cryptoNr, int mode,
                           char *store, char *password, int maxlen);

#ifdef __cplusplus
}
#endif

#endif /* PC_COMMON_H */
